# 1. קבלת סיסמה דינמית מהמשתמש (קלט מאובטח בכוכביות)
$SecurePassword = Read-Host -AsSecureString "Enter your desired Argo CD Admin Password"
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
$PlainAdminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

param (
    [string]$RootAppPath = "k8s/root-application.yaml"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " 1. Installing Official Argo CD" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# יצירת ה-Namespace והתקנת ה-Manifest המקורי
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host " 2. Patching Service to NodePort 30007" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# דריסת ה-Service ל-NodePort 30007
$PatchJson = '{"spec": {"type": "NodePort", "ports": [{"name": "http", "port": 80, "targetPort": 8080, "nodePort": 30007}, {"name": "https", "port": 443, "targetPort": 8080, "nodePort": 30008}]}}'
kubectl patch svc argocd-server -n argocd -p $PatchJson

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host " 3. Updating Admin Password Dynamically" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# עדכון ה-Secret ב-Kubernetes עם הסיסמה שהוזנה
$SecretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
type: Opaque
stringData:
  admin.password: "$PlainAdminPassword"
  admin.passwordMtime: "$(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")"
"@
$SecretYaml | kubectl apply -f -

# אתחול ה-Server כדי לקלוט את הסיסמה
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd --timeout=60s

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host " 4. Deploying Root Application (App-of-Apps)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# יצירת/החלת אפליקציית השורש
if (Test-Path $RootAppPath) {
    kubectl apply -f $RootAppPath
    Write-Host "Root Application deployed successfully!" -ForegroundColor Green
} else {
    Write-Host "Warning: Root application manifest not found at $RootAppPath" -ForegroundColor Red
}

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host " Local Setup Completed Successfully!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Argo CD UI: http://localhost:30007" -ForegroundColor Yellow
Write-Host "User: admin" -ForegroundColor Yellow