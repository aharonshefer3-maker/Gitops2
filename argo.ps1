# ==============================================================================
# ArgoCD Auto-Login & Root App Deployer
# ==============================================================================

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   ArgoCD Auto-login & Root Deployer    " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# --- 1. ווידוא שפורט-פורוורד פעיל ל-ArgoCD ---
Write-Host "`n[1/4] Checking Port-Forward connection to ArgoCD (localhost:8080)..." -ForegroundColor Yellow
$PortCheck = Test-NetConnection -ComputerName "127.0.0.1" -Port 8080 -WarningAction SilentlyContinue

if (-not $PortCheck.TcpTestSucceeded) {
    Write-Host "Port-Forward is down. Starting port-forward on port 8080..." -ForegroundColor Gray
    Get-Process | Where-Object { $_.ProcessName -eq "kubectl" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Process kubectl -ArgumentList "port-forward svc/argocd-server -n argocd 8080:80" -WindowStyle Hidden
    Start-Sleep -Seconds 4
}

# --- 2. שליפת הסיסמה באופן אוטומטי מ-Kubernetes ---
Write-Host "`n[2/4] Retrieving ArgoCD initial admin password from secret..." -ForegroundColor Yellow
$passEncoded = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="`{.data.password`}" 2>$null

if (-not $passEncoded) {
    Write-Error "Could not find 'argocd-initial-admin-secret'. If you already updated the password, please verify credentials."
    exit 1
}

$AutoPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($passEncoded))
Write-Host "Password retrieved successfully!" -ForegroundColor Green

# --- 3. התחברות אוטומטית ל-ArgoCD CLI ---
Write-Host "`n[3/4] Logging into ArgoCD CLI..." -ForegroundColor Yellow
try {
    argocd login localhost:8080 --username admin --password $AutoPassword --insecure --grpc-web
    Write-Host "Successfully authenticated with ArgoCD CLI as admin!" -ForegroundColor Green
} catch {
    Write-Error "Failed to log in to ArgoCD CLI with retrieved password."
    exit 1
}

# --- 4. החלת ה-Root App והפעלת Sync ---
Write-Host "`n[4/4] Deploying Root Application (bootstrap/root-app.yaml)..." -ForegroundColor Yellow

$RootAppPath = "bootstrap/root-app.yaml"
if (-not (Test-Path $RootAppPath) -and (Test-Path "root-app.yaml")) {
    $RootAppPath = "root-app.yaml"
}

if (Test-Path $RootAppPath) {
    kubectl apply -f $RootAppPath

    Write-Host "Triggering ArgoCD Sync for root-app..." -ForegroundColor Gray
    argocd app sync root-app --async --grpc-web 2>$null
} else {
    Write-Error "Could not find root-app.yaml in 'bootstrap/' or current working directory!"
    exit 1
}

# --- 5. המתנה לסנכרון ועליית כל הפודים ---
Write-Host "`nWaiting for all application pods across all namespaces to stabilize..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

$AllReady = $false
while (-not $AllReady) {
    $NonRunningPods = kubectl get pods --all-namespaces --no-headers 2>$null | Where-Object { $_ -notmatch "Running|Completed" }

    if (-not $NonRunningPods) {
        $AllReady = $true
        Write-Host "All applications are fully synced and all pods are running!" -ForegroundColor Green
    } else {
        Write-Host "Waiting for pods to reach Ready state..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
}

Write-Host "`n==================================================" -ForegroundColor Green
Write-Host "✅ ROOT APP DEPLOYED AND ALL PODS ARE UP!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green