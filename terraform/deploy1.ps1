param(
    [string]$KeyPath = "C:\Users\USER\Downloads\MY_KEY.pem",
    [string]$ServerIP = "98.86.118.31",
    [string]$User = "ubuntu"
)

Write-Host "=== Terraform Init and Apply ===" -ForegroundColor Cyan
Set-Location "environments\test"
terraform init
terraform apply -auto-approve

Write-Host "=== Getting ArgoCD Password ===" -ForegroundColor Cyan
$RemoteCommand = "sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
$argocdPassword = ssh -i $KeyPath ($User + "@" + $ServerIP) $RemoteCommand
Write-Host "ArgoCD Password: $argocdPassword" -ForegroundColor Green

Write-Host "=== Opening Port Forwarding Tunnels ===" -ForegroundColor Cyan
Write-Host "Keep this terminal open while working!" -ForegroundColor Yellow

