<#PSScriptInfo
.VERSION 
	0.0.1
.GUID
	f4a4a7c6-003a-4d80-9c35-ac1f0422cc57
.AUTHOR 
	Florian Gerber
.TAGS 
	Exchange Online
.RELEASENOTES
	Initial Release
#>

#Requires -Module ExchangeOnlineManagement

<# 
.DESCRIPTION 
	Retriev the current calendar permissions for all mailboxes in Microsoft 365 Tenant. 
#> 
Param()


Connect-ExchangeOnline

$ModulesLoaded = Get-Module | Select-Object Name
If (!($ModulesLoaded -match "ExchangeOnlineManagement")) {
	Write-Host "Please connect to the Exchange Online Management module and then restart the script"; break
}

$Mailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox | Select-Object UserPrincipalName
foreach ($mailbox in $Mailboxes) {
    
	# WARNING: IF YOU DONT HAVE ALL THE MAILBOXES IN GERMAN THIS WONT DELIVER ANYTHING
	# To use for English Mailboxes change the :\Kalender to :\Calendar
	Get-MailboxFolderPermission -Identity "$($mailbox.UserPrincipalName):\Kalender" | Select-Object @{Name = "UserPrincipalName"; Email = { $mailbox.UserPrincipalName } }, FolderName, User, AccessRights 
	#|
	#Export-Csv C:\PS\Calendar_report.csv -NoTypeInformation -Append
}
