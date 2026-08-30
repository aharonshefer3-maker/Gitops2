param(
    [string]$KeyPath = "C:\Users\USER\Downloads\MY_KEY.pem",
    [string]$User = "ubuntu"
)

Write-Host "=== Terraform Init and Apply ===" -ForegroundColor Cyan
Set-Location "environments\test"
terraform init
terraform apply -auto-approve

# 1. קבלת ה-IP הדינמי מ-Terraform
$ServerIP = (terraform output -raw server_ip).Trim()
Write-Host "Target Server IP: $ServerIP" -ForegroundColor Green

# 2. המתנה עד ש-ArgoCD יהיה מוכן
Write-Host "=== Waiting for ArgoCD to be ready... ===" -ForegroundColor Yellow
$Ready = $false
while (-not $Ready) {
    Write-Host "Checking connection..."
    $check = ssh -i $KeyPath -o ConnectTimeout=5 -o StrictHostKeyChecking=no ($User + "@" + $ServerIP) "sudo kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-server"
    if ($check -match "Running") {
        $Ready = $true
    } else {
        Start-Sleep -Seconds 10
    }
}

# תוספת: המתנה קטנה נוספת לוודא שה-Secrets והשירותים יציבים לגמרי אחרי שהפוד עלה
Write-Host "ArgoCD pod is running. Waiting 15 seconds for services to stabilize..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# 3. שליפת סיסמת ה-ArgoCD
$RemoteCommand = "sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
$argocdPassword = ssh -i $KeyPath -o StrictHostKeyChecking=no ($User + "@" + $ServerIP) $RemoteCommand

# 4. בדיקת רדיס (לוודא שהוא חי)
Write-Host "=== Testing Redis Connection ===" -ForegroundColor Cyan
$RedisCmd = "sudo kubectl -n default exec -l app=redis -- redis-cli ping 2>/dev/null"
$RedisTest = ssh -i $KeyPath -o StrictHostKeyChecking=no ($User + "@" + $ServerIP) $RedisCmd

Write-Host "------------------------------------------------" -ForegroundColor Cyan
Write-Host "ArgoCD is READY!" -ForegroundColor Green
Write-Host "Direct Access URL: https://$ServerIP:30007" -ForegroundColor Yellow
Write-Host "ArgoCD Password: $argocdPassword" -ForegroundColor Green
if ($RedisTest -match "PONG") {
    Write-Host "Redis Status: ALIVE (PONG)" -ForegroundColor Magenta
} else {
    Write-Host "Redis Status: Check manually (Output: $RedisTest)" -ForegroundColor Red
}
Write-Host "------------------------------------------------" -ForegroundColor Cyan

# 5. פתיחת מנהרות (Port Forwarding) לפורטים האחרים בלבד
Write-Host "=== Opening Port Forwarding Tunnels (Grafana, Prometheus, QuakeWatch) ===" -ForegroundColor Cyan
Write-Host "Mapping: 30001, 30002, 30085 -> localhost" -ForegroundColor Yellow