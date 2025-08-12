param(
  [Parameter(Mandatory=$true)][string]$SubscriptionId,
  [Parameter(Mandatory=$true)][string]$ResourceGroup,
  [Parameter(Mandatory=$true)][string]$Location
)
Set-AzContext -Subscription $SubscriptionId
New-AzResourceGroup -Name $ResourceGroup -Location $Location -Force | Out-Null
New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroup -TemplateFile ./infra/bicep/main.bicep -location $Location
Write-Host "Linking workspace to dedicated cluster can take up to ~2 hours. Data export starts afterward."
