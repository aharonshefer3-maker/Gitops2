#!/bin/bash
set -e

# הגדרת נתיב ה-Kubeconfig למשתמש sudo (מונע שגיאות הרשאה למול ה-Cluster)
export KUBECONFIG=${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml} # עדכן לפי המיקום של ה-kubeconfig אצלך (למשל /home/ubuntu/.kube/config)

echo "=== Starting ArgoCD & Root App Provisioning ==="

# 1. התקנת ArgoCD
echo "Installing ArgoCD..."
sudo kubectl create namespace argocd --dry-run=client -o yaml | sudo kubectl apply -f -
sudo kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml


NODE_PORT=${1:-30007}

# שינוי ה-Service ל-NodePort והגדרת הפורט הגלוי
kubectl patch svc argocd-server -n argocd --type='json' -p="[
  {\"op\": \"replace\", \"path\": \"/spec/type\", \"value\": \"NodePort\"},
  {\"op\": \"replace\", \"path\": \"/spec/ports/0/nodePort\", \"value\": $NODE_PORT}
]"

# המתנה לעליית השרת
echo "Waiting for ArgoCD server deployment..."
sudo kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

# 3. שפעול Root Application
echo "Applying Root Application..."
sudo kubectl apply --validate=ignore -f https://raw.githubusercontent.com/aharonshefer3-maker/Gitops2/master/bootstrap/root-app.yaml

# 4. הפעלת Port-Forward ברקע לפורט 30007
echo "Setting up background port-forward on port 30007..."
sudo pkill -f "port-forward.*30007" || true
sudo nohup kubectl port-forward svc/argocd-server -n argocd 30007:80 --address 0.0.0.0 > /var/log/argocd-port-forward.log 2>&1 &

# שליפת הסיסמה הראשונית
PASS_ENCODED=$(sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null || true)

echo ""
echo "=================================================="
echo "🚀 ArgoCD Provisioning Complete!"
echo "URL:      http://localhost:30007"
echo "Username: admin"

if [ -n "$PASS_ENCODED" ]; then
    INITIAL_PASS=$(echo "$PASS_ENCODED" | base64 --decode)
    echo "Password: $INITIAL_PASS"
else
    echo "Password: (Secret not found - check if already deleted)"
fi
echo "=================================================="