<#PSScriptInfo
.VERSION 
	0.0.1
.GUID
	0a1b1da5-e8f6-475b-8bdd-b51dabc7f9cb
.AUTHOR 
	Florian Gerber
.TAGS 
	Exchange Online
.RELEASENOTES
	Initial Release
#>

#Requires -Module ExchangeOnlineManagement

<#
.NOTES 
	Currently this is not a real Module or Script, it's just a collection of single Commands, will change in futur.
.DESCRIPTION 
	Set Common Settings on Shared or User Mailboxes like, the timezone, language, SendItem Copy SentAs and enable AutoExpandingArchive. 
#> 
Param()



# Set Single Mailbox to W. Europe Standard Time and language German
Set-MailboxRegionalConfiguration -Identity user@domain.tld -TimeZone "W. Europe Standard Time" -Language de-de -LocalizeDefaultFolderName

# Set All Shared Mailboxes to W. Europe Standard Time and language German
Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails Sharedmailbox | ForEach-Object { Set-MailboxRegionalConfigurationcipalName -TimeZone "W. Europe Standard Time" -Language de-de -LocalizeDefaultFolderName }

# Enables the Copy to sendItem when send on bahalf or sent as | This realy should be default from MS Site
Set-Mailbox user@domain.tld -MessageCopyForSentAsEnabled $true -MessageCopyForSendOnBehalfEnabled $true

# Enables the Copy to sendItem when send on bahalf or sent as for all Shared Mailboxes | This realy should be default from MS Site
Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails Sharedmailbox | ForEach-Object { Set-mailbox -Identity $_.UserPrincipalName -MessageCopyForSendOnBehalfEnabled $true -MessageCopyForSentAsEnabled $true }

# Get informations to wich mailbox user has access
Get-Mailbox -ResultSize:Unlimited | Get-MailboxPermission | Select-Object identity, user, accessrights  | Where-Object { ($_.User -like 'user@domain.tld') }

# Enable Autoexpand Arcive, this can't be reverted
Enable-Mailbox user@domain.tld -AutoExpandingArchive
#Validate
Get-Mailbox user@domain.tld | Format-List AutoExpandingArchiveEnabled