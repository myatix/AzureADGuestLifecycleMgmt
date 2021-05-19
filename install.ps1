# Run this script as an administrator
Start-Transcript -Path ".\Logs" -NoClobber -Append
# region Include required files
#
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
try {
    . ("$ScriptDirectory\functions.ps1")
}
catch {
    Write-Host "Error while loading supporting PowerShell Scripts" 
}
#endregion

# --- config start
$adminUser = "admin@M365x439370.onmicrosoft.com"
$appName = "AzureADGuestLifecycleMgmt" # The Application name bust be a maximum of 32 characters
$adalUrlIdentifier = "https://mindcore.dk/AzureADGuestLifecycleMgmt"
$appReplyUrl = "https://mindcore.dk"
$dnsName = "M365x439370.onmicrosoft.com" # Your DNS name
$password = "Mindcore2021#" # Certificate password
#$password = StrongPassword
$folderPath = ".\certificate" # Where do you want the files to get saved to? The folder needs to exist.
$fileName = "AzureADGuestLifecycleMgmt" # What do you want to call the cert files? without the file extension
$currentDate = Get-Date # Get todays date
$yearsValid = 10 # Number of years until you need to renew the certificate
$keyVaultName = "guestlifecyclemgmt" # Key Vault Name as specified in ARM Templates.
$rgLocation = "West Europe" # Azure Resource Group Location 
# --- config end
$certStoreLocation = 'cert:\LocalMachine\My'
$expirationDate = (Get-Date).AddYears($yearsValid)

$certificateThumb = (New-SelfSignedCertificate -DnsName $dnsName -CertStoreLocation $certStoreLocation -NotAfter $expirationDate -KeyExportPolicy Exportable -KeySpec Signature).Thumbprint
$certificateThumb > $folderPath'\certificate-thumb.txt'
$certificatePath = $certStoreLocation + '\' + $certificateThumb
$filePath = $folderPath + '\' + $fileName
$securePassword = ConvertTo-SecureString -String $password -Force -AsPlainText
Export-Certificate -Cert $certificatePath -FilePath ($filePath + '.cer')
Export-PfxCertificate -Cert $certificatePath -FilePath ($filePath + '.pfx') -Password $securePassword
$path = (Get-Item -Path $folderPath).FullName
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate("$path\$fileName.pfx", $securePassword)
$keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())
$keyValue > certificate\pfx-encoded.txt

#Install AzureAD PowerShell Module
Install-Module -Name AzureAD -Force
Import-Module AzureAD

# Connect to Azure AD as an admin account
Connect-AzureAD -AccountId $adminUser

# Store tenantid
$tenant = Get-AzureADTenantDetail
$tenant.ObjectId > $folderPath\tenantid.txt

# Add AuditLog.Read.All access
$svcPrincipal = Get-AzureADServicePrincipal -All $true | ? { $_.DisplayName -eq "Microsoft Graph" }
$appRole = $svcPrincipal.AppRoles | ? { $_.Value -eq "AuditLog.Read.All" }
$appPermission = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "$($appRole.Id)", "Role"

#Add Directory.ReadWrite.All access
$appRole2 = $svcPrincipal.AppRoles | ? { $_.Value -eq "Directory.ReadWrite.All" }
$appPermission2 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "$($appRole2.Id)", "Role"

$reqGraph = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
$reqGraph.ResourceAppId = $svcPrincipal.AppId
$reqGraph.ResourceAccess = $appPermission, $appPermission2

# Create Azure Active Directory Application (ADAL)
$application = New-AzureADApplication -DisplayName $appName -IdentifierUris $adalUrlIdentifier -ReplyUrls $appReplyUrl -RequiredResourceAccess $reqGraph
#Add AzureAD App Key Credential
New-AzureADApplicationKeyCredential -ObjectId $application.ObjectId -CustomKeyIdentifier "$appName" -Type AsymmetricX509Cert -Usage Verify -Value $keyValue -StartDate $currentDate -EndDate $expirationDate.AddDays(-1)
#Add AzureAD App ClientSecret (Not tested)
New-AzureADApplicationPasswordCredential -ObjectId $application.ObjectId -CustomKeyIdentifier "$appName" -StartDate $currentDate -EndDate $expirationDate.AddDays(-1)

Write-Host "A browser window will open shortly, please login and consent to the security popup and then close the browser window." -ForegroundColor Green
Start-Sleep 20 # Give it time to create App Registration

# https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-permissions-and-consent
$consentUri = "https://login.microsoftonline.com/$($tenant.ObjectId)/adminconsent?client_id=$($application.AppId)&state=12345&redirect_uri=$appReplyUrl"
$consentUri | clip
#Write-Host "Please make sure you have consented to the Security popup. If not the URL has been copied to your clipboard - paste it into a browser and consent to the popup." -ForegroundColor Green
Write-Host $consentUri -ForegroundColor Blue
Start-Process "$consentUri"
Write-Warning "Please make sure you have consented to the Security popup. If not the URL has been copied to your clipboard - paste it into a browser and consent to the popup. Have you approved the consent Popup?" -WarningAction Inquire

$appId = $application.AppId
$appId > $folderPath\appid.txt

Start-Sleep 10 # Give it time before connecting
Connect-AzureAD -TenantId $tenant.ObjectId -ApplicationId  $Application.AppId -CertificateThumbprint $certificateThumb

[Microsoft.Open.Azure.AD.CommonLibrary.AzureSession]::AccessTokens["AccessToken"]

Disconnect-AzureAD

###################################################################################################################
# Start ARM Template Deployment

Write-Warning "Do you wish to continue the deployment and setup the application in Azure?" -WarningAction Inquire

#Install AZ PowerShell Modules
Import-Module -Name Az -Force
#Clear-AzContext
Connect-AzAccount -Tenant $tenant.ObjectId

# Create a New Resource Group for AzureADGuestLifecycleMgmt
Write-Host "Creating the Azure resource group." -ForegroundColor Green
$rgName = "RG_"+$appName
New-AzResourceGroup -Name $rgName -Location $rgLocation

# Start Azure Resource Manager Template Deployment
Write-Host "Starting ARM template deployment." -ForegroundColor Green
New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateUri "https://raw.githubusercontent.com/myatix/AzureADGuestLifecycleMgmt/master/guestLifecycleMgmt.json" -TemplateParameterUri "https://raw.githubusercontent.com/myatix/AzureADGuestLifecycleMgmt/master/guestLifecycleMgmt.parameters.json" -Verbose

#Set Key Vault Access Policies
#$objectID = $application.ObjectId
Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ServicePrincipalName $appId -PermissionsToSecrets get -PermissionsToCertificates get
Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -UserPrincipalName $adminUser -PermissionsToSecrets all -PermissionsToCertificates all -PermissionsToKeys all

# Add Certificate to Azure Key Vault.
Write-Host "Adding certificate to Azure Key Vault." -ForegroundColor Green
Import-AzKeyVaultCertificate -VaultName $keyVaultName -Name $fileName -FilePath ($filePath + '.pfx') -Password $securePassword

Stop-Transcript
Write-Host "Installation Complete" -ForegroundColor Green