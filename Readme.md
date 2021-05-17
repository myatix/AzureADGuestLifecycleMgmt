Automated solution which offers an Azure AD Access review like user experience to get regular approval for guest accounts.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmyatix%2FAzureADGuestLifecycleMgmt%2Fmaster%2FguestLifecycleMgmt.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fmyatix%2FAzureADGuestLifecyclemgmt%2Fmaster%2FguestLifecycleMgmt.json)

## Notable features

* The 'Manager' attribute of your guest users get's automatically populated with the identity of the inviter
* All Azure AD app registration information is stored in Azure Key Vault
* Almost zero touch deployment with ARM templates
* You can integrate existing guest users into this solution by populating the manager attribute in Azure AD
* You can configure the approval frequency for guest accounts
* Approval frequency respects last approval date for each guest account

## Prerequisites

* Azure Subscription
* Azure AD Audit & Sign-In Log forwarding to a log analytics workspace
* Azure AD App Registration
    * Required permissions: `Directory.ReadWrite.All`, `AuditLog.Read.All`

## Post deployment steps

* Authorize 'Office 365 Outlook' API Connection in the Azure Portal with the Account you want to send your notification e-mails
* Create an action group for your log analytics workspace to trigger the Azure Function: 'PopulateGuestInviterAsManager'
* Add an alert rule to your log analytics workspace which triggers the action group

Query for the alert rule:

```
AuditLogs
| where OperationName == 'Invite external user' and Result == 'success'
```

## Deployment via Az PowerShell

```powershell
# Create new resource group
$rgName = "RG_AzureADGuestLifecycleMgmt"
$rgLocation = "West Europe"
New-AzResourceGroup -Name $rgName -Location $rgLocation

# Deploy ARM Template with app registration details in parameters.json file
New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateFile "C:\Repos\GitHub\AzureADGuestManagement\03-LogicApp\template.json" -TemplateParameterFile "C:\Repos\GitHub\AzureADGuestManagement\03-LogicApp\template.parameters.json" -Verbose  
```

