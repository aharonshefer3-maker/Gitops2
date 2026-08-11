#!/bin/bash
set -e

# לוג שירכז את כל פלט ההתקנה
exec > >(tee -a /var/log/user-data.log) 2>&1

echo "=== 1. Updating packages & tools ==="
apt-get update -y
apt-get install -y unzip curl wget

echo "=== 2. Installing K3s ==="
curl -sfL https://get.k3s.io | sh -s -
systemctl daemon-reload
systemctl enable --now k3s

# הגדרת נתיב הקונפיגורציה ל-root כדי שכל פקודת kubectl תכיר את K3s
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
mkdir -p /root/.kube
cp /etc/rancher/k3s/k3s.yaml /root/.kube/config

echo "=== 3. Installing Promtail ==="
PROM_VERSION="2.9.4"
wget -q "https://github.com/grafana/loki/releases/download/v$${PROM_VERSION}/promtail-linux-amd64.zip"
unzip -o promtail-linux-amd64.zip
mv promtail-linux-amd64 /usr/local/bin/promtail
chmod +x /usr/local/bin/promtail

mkdir -p /etc/promtail
cat <<EOT > /etc/promtail/config.yaml
server:
  http_listen_port: 9080
clients:
  - url: ${loki_url}
    basic_auth:
      username: "${loki_user}"
      password: "${grafana_token}"
scrape_configs:
- job_name: system
  static_configs:
  - targets: [localhost]
    labels:
      job: varlogs
      env: ${env_name}
      __path__: /var/log/*.log
EOT

cat <<EOT > /etc/systemd/system/promtail.service
[Unit]
Description=Promtail Log Collector Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable --now promtail

echo "=== 4. Waiting for K3s API to be ready ==="
until kubectl get nodes &>/dev/null; do
    echo "Waiting for K3s cluster..."
    sleep 3
done

echo "=== 5. Installing ArgoCD ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "=== 6. Configuring ArgoCD Service & HTTP mode ==="
# המתנה עד שה-Service נוצר בפועל ב-Kubernetes API
until kubectl get svc argocd-server -n argocd &>/dev/null; do
    echo "Waiting for argocd-server service to be created..."
    sleep 2
done

# עדכון ה-NodePort מהמשתנה של Terraform
kubectl patch svc argocd-server -n argocd -p "{\"spec\": {\"type\": \"NodePort\", \"ports\": [{\"name\": \"http\", \"port\": 80, \"targetPort\": 8080, \"nodePort\": ${argocd_node_port}}]}}"

# ביטול TLS כדי לעבוד ב-HTTP נקי
#kubectl env deployment/argocd-server -n argocd ARGOCD_SERVER_INSECURE=true
kubectl set env deployment/argocd-server -n argocd ARGOCD_SERVER_INSECURE=true
echo "=== 7. Waiting for ArgoCD Rollout ==="
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo "=== 8. Applying Root Application ==="
kubectl apply --validate=ignore -f https://raw.githubusercontent.com/aharonshefer3-maker/Gitops2/master/bootstrap/root-app.yaml

echo "=================================================="
echo "🚀 ALL SERVICES PROVISIONED SUCCESSFULLY!"
echo "ArgoCD URL: http://<PUBLIC_IP>:${argocd_node_port}"
echo "=================================================="