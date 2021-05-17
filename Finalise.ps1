$keyVaultName = "AzureADGuestLifecycleMgmt"
$certificateName = "AzureADGuestLifecycleMgmt"
$certPwd = Read-Host -Prompt 'Enter the password you chose for your certificate!'
$certPwd = ConvertTo-SecureString -String $pwd -AsPlainText -Force
Import-AzureKeyVaultCertificate -VaultName "$keyVaultName" -Name "$certificateName" -FilePath ".\AzureADGuestLifecycleMgmt.pfx" -Password $certPwd


      