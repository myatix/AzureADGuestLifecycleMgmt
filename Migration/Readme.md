This PowerShell script queries your log analytics wokspace for guest user invitations and populates the guest inviter as the manager of the guest account in Azure AD.

It's intended as a migration tool to onboard the Azure AD Guest Review solution.

Post deployment stepsPermalink

Authorize ‘Office 365 Outlook’ API Connection in the Azure Portal with the Account you want to send your notification e-mails: Authorize Office 365 API Connection

Add the Azure functions from the PowerShell scripts Add azure function
Repeat the steps for all three functions
Grab & paste the function URL for the “fetchLastSigninAndManager” & “updateGuestManagementMeta” function in the logic app

Create an action group for your log analytics workspace to trigger the Azure Function: ‘PopulateGuestInviterAsManager’
Make sure to enable the common alert schema

Create Action Group
Add a new alert rule to your log analytics workspace which triggers the previously created action group


Create Alert Rule
Choose severity level 4 (which refers to verbose) and not 0 like I did

Custom log search query:
  AuditLogs
  | where OperationName == 'Invite external user' and Result == 'success'
