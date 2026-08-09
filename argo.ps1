kubectl create namespace argocd
echo "argocd created "
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml


kubectl wait --for=condition=Redy pod --all -n argocd
kubectl port-forward svc/argocd-server -n argocd 8080:443
$pass = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>$null
#.if ([string]::IsNullOrWhiteSpace($pass)) {
#    Write-Host "" -ForegroundColor Red
#    kubectl get pods -n argocd
#} else {
#    $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($pass))
#    Write-Host "✅  $decoded" -ForegroundColor Green
#}
echo "https://localhost:8080"
echo "your pass is :  "$pass