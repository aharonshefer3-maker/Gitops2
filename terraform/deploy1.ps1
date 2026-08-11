param(
    [string]$KeyPath = "C:/path/to/your-key.pem",
    [string]$ServerIP = "98.86.118.31",
    [string]$User = "ubuntu"
)

Write-Host "=== שלב א': הרצת Terraform (Init & Apply) ===" -ForegroundColor Cyan
terraform init
terraform apply -auto-approve

Write-Host "`n=== שלב ב': איתור סיסמת ה-ArgoCD מהשרת ===" -ForegroundColor Cyan
$argocdPassword = ssh -i $KeyPath "$User@$ServerIP" "sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
Write-Host "הסיסמה הראשונית ל-ArgoCD היא: " -NoNewline; Write-Host "$argocdPassword" -ForegroundColor Green

Write-Host "`n=== שלב ג': פתיחת צינורות Port Forwarding (QW, Redis, Prometheus, Grafana, ArgoCD) ===" -ForegroundColor Cyan
Write-Host "התעלות נפתחות ברקע. אל תסגור את חלון הטרמינל הזה כל עוד אתה עובד!" -ForegroundColor Yellow

# פתיחת תעלת SSH אחת עם כל הניתובים במקביל:
# - QuakeWatch (NodePort 30085 -> Local 5000)
# - Grafana (NodePort 30001 -> Local 30001)
# - Prometheus (NodePort 30002 -> Local 30002)
# - ArgoCD (NodePort 30007 -> Local 30007)
# - Redis (Cluster Port 6379 -> Local 6379)

ssh -i $KeyPath -N `
    -L 5000:localhost:30085 `
    -L 30001:localhost:30001 `
    -L 30002:localhost:30002 `
    -L 30007:localhost:30007 `
    -L 6379:localhost:6379 `
    "$User@$ServerIP"