$appName = "AzureDGuestLifecycleMgmt" # Maximum 32 characters
$adalUrlIdentifier = "https://mindcore.dk/AzureADGuestLifecycleMgmt"
$appReplyUrl = "https://www.mindcore.dk"
#$pwd = Read-Host -Prompt 'Enter a secure password for your certificate!'


do {
    $pwd = Read-Host "-ENTER A SECURE CERTIFICATE PASSWORD-`n`nYour password must meet the following requirements:  
`n`nAt least one upper case letter [A-Z]`nAt least one lower case letter [a-z]`nAt least one number [0-9]`nAt least one special character (!,@,%,^,&,$,_)`nPassword length must be 7 to 25 characters.`n`n`nEnter a certificate password"

    if(($pwd -cmatch '[a-z]') -and ($pwd -cmatch '[A-Z]') -and ($pwd -match '\d') -and ($pwd.length -match '^([7-9]|[1][0-9]|[2][0-5])$') -and ($pwd -match '!|@|#|%|^|&|$|_')) 
{ 
    Write-Host "`nYour certificate had been saved with your selected password!`n"
    $validPwd = "True"
} 
else
{ 
    Write-Host "`nThe password you entered is invalid!`n"
    
}

} until (
 $validPwd -eq "True"
)


$certStore = "Cert:\CurrentUser\My"
$currentDate = Get-Date
$endDate = $currentDate.AddYears(10) # 10 years is nice and long
$thumb = (New-SelfSignedCertificate -DnsName "mindcore.dk" -CertStoreLocation $certStore -KeyExportPolicy Exportable -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" -NotAfter $endDate).Thumbprint
$thumb > certificate\cert-thumb.txt # Save to file
$pwd = ConvertTo-SecureString -String $pwd -Force -AsPlainText
Export-PfxCertificate -cert "$certStore\$thumb" -FilePath .\certificate\AzureADGuestLifecycleMgmt.pfx -Password $pwd
$path = (Get-Item -Path ".\certificate\").FullName
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate("$path\AzureADGuestLifecycleMgmt.pfx", $pwd)
$keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())

#Install AzureAD PowerShell Module
Install-Module AzureAD -Force
Import-Module AzureAD

# Connect to Azure AD as an admin account
Connect-AzureAD 

# Store tenantid
$tenant = Get-AzureADTenantDetail
$tenant.ObjectId > certificate\tenantid.txt

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

# Create Azure Active Directory Application (ADAL App)
$application = New-AzureADApplication -DisplayName "$appName" -IdentifierUris $adalUrlIdentifier -ReplyUrls $appReplyUrl -RequiredResourceAccess $reqGraph
New-AzureADApplicationKeyCredential -ObjectId $application.ObjectId -CustomKeyIdentifier "$appName" -Type AsymmetricX509Cert -Usage Verify -Value $keyValue -StartDate $currentDate -EndDate $endDate.AddDays(-1)

Start-Sleep 10 # Give it time to create App Registration

# https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-permissions-and-consent
$consentUri = "https://login.microsoftonline.com/$($tenant.ObjectId)/adminconsent?client_id=$($application.AppId)&state=12345&redirect_uri=$appReplyUrl"
$consentUri | clip
Write-Host "Consent URL is copied to your clipboard - paste it into a browser, and ignore the redirect" -ForegroundColor Green
Write-Host $consentUri -ForegroundColor Blue
Read-Host -Prompt "Press ENTER after consenting to the Security popup."

$sp = Get-AzureADServicePrincipal | ? AppId -eq $application.AppId
if (-not $sp) {
    # Create the Service Principal and connect it to the Application
    $sp = New-AzureADServicePrincipal -AppId $application.AppId 
}
 
$azureDirectoryWriteRoleId = ( Get-AzureADDirectoryRoleTemplate | Where-Object DisplayName -eq "Directory Writers").ObjectId
try {
    Enable-AzureADDirectoryRole -RoleTemplateId $azureDirectoryWriteRoleId 
}
catch { }

# Give the application read/write permissions to AAD
Add-AzureADDirectoryRoleMember -ObjectId (Get-AzureADDirectoryRole | Where-Object DisplayName -eq "Directory Writers" ).Objectid -RefObjectId $sp.ObjectId

$appId = $application.AppId
$appId > certificate\appid.txt

Start-Sleep 10 # give it some seconds before connecting
Connect-AzureAD -TenantId $tenant.ObjectId -ApplicationId  $Application.AppId -CertificateThumbprint $thumb

[Microsoft.Open.Azure.AD.CommonLibrary.AzureSession]::AccessTokens["AccessToken"]

#---------------------------------------------------------------------------------------------------------------------------------------------

#Install-Module -Name Az -AllowClobber
Import-Module -Name Az
#Clear-AzContext
Connect-AzAccount
# Create a New Resource Group for AzureADGuestLifecycleMgmt
Write-Host "Creating Azure resource group." -ForegroundColor Green

$rgName = "RG_"+$appName
$rgLocation = "West Europe"
New-AzResourceGroup -Name $rgName -Location $rgLocation

Write-Host "Starting ARM template deployment." -ForegroundColor Green
New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateUri "https://raw.githubusercontent.com/myatix/AzureADGuestLifecycleMgmt/master/guestLifecycleMgmt.json" -TemplateParameterUri "https://raw.githubusercontent.com/myatix/AzureADGuestLifecycleMgmt/master/guestLifecycleMgmt.parameters.json" -Verbose

# Add Certificate to Azure Key Vault.
Write-Host "Adding certificate to Azure Key Vault." -ForegroundColor Green

$keyVaultName = "AzureADGuestLifecycleMgmt"
$certificateName = $appName
$certPwd = Read-Host -Prompt "Enter the password you chose for "+$appName+".pfx"
$certPwd = ConvertTo-SecureString -String $pwd -AsPlainText -Force
Import-AzureKeyVaultCertificate -VaultName "$keyVaultName" -Name "$certificateName" -FilePath ".\AzureADGuestLifecycleMgmt.pfx" -Password $certPwd


      