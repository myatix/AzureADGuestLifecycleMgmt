#Connect to Azure
$appName = "AzureADGuestLifecycleMgmt"
$TenantID = "a5a88e02-5135-48de-8b5c-80fc960d192c"
Connect-AzAccount -Tenant $TenantID
Import-Module -Name Az.Resources

Write-Warning "You are about to delete the $appName." -WarningAction Inquire

$appName = "AzureADGuestLifecycleMgmt"
# Delete Service Principle Name
$svcPrincipal = (Get-AzADServicePrincipal -SearchString $appName)
if ($svcPrincipal -eq $null){
   Write-Host "No Service Principle Found!" -ForegroundColor Yellow
   }
else {
    Write-Host "Deleting Service Principle Name" -ForegroundColor Green
    Remove-AzADServicePrincipal -ApplicationId $svcPrincipal.ApplicationId -Force -PassThru
  }

  # Delete AzureAD Appregistration
  $app = (Get-AzADApplication -DisplayName "$appName")
  if ($app -eq $null){
     Write-Host "No Azure Application found!" -ForegroundColor Yellow
     }
  else {
        Write-Host "Deleting Azure Application" -ForegroundColor Green
        Remove-AzADApplication -ApplicationId $app.ApplicationId -Force -PassThru

    }

    # Delete Azure Resources for AzureAD Guest Lifecycle Management.
    $resourceGroup = (Get-AzResourceGroup -Name "RG_$appName" -Erroraction 'silentlycontinue')
    if ($resourceGroup -eq $null){
       Write-Host "No Azure Resource Group found!" -ForegroundColor Yellow
       }
    else {
    
        Write-Host "Deleting Azure Resources for $appName - Please Wait!" -ForegroundColor Green
        Get-AzResourceGroup -Name "RG_$appName" | Remove-AzResourceGroup -Force
  
      }

      Write-Warning "You are about to delete the supporting files including certificates." -WarningAction Inquire
      Remove-Item .\certificate\* -Recurse -Force

      # Clear All Variables and Refresh Session
      Remove-Variable * -ErrorAction SilentlyContinue; Remove-Module *; $error.Clear();