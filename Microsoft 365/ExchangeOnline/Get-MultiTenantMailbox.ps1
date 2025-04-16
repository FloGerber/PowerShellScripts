<#PSScriptInfo
.VERSION 
	0.0.1
.GUID
	2e804623-9a1c-4a1a-bff0-86035f74896c
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
	Get all Mailboxes and some statistict from Exchange Online and multiple Tenants.
	Data gets exported to csv file. 
#> 
Param()

$result = @() #Result array

# Input the Exchange Online Admin Account to gather all Mailboxes, comma seperated list "one@abc.com", "two@xyz.com"
$adminUser =

foreach ($admin in $adminUser) {

	Connect-ExchangeOnline -UserPrincipalName $admin

	$moduleLoaded = Get-Module | Select-Object Name
	If (!($moduleLoaded -match "ExchangeOnlineManagement")) {
		Write-Host "Please connect to the Exchange Online Management module and then restart the script"; break
	}

	$mailboxes = Get-Mailbox -ResultSize Unlimited | Select-Object DisplayName, UserPrincipalName, RecipientTypeDetails

	foreach ($mailbox in $mailboxes) {
		$mailboxStats = Get-MailboxStatistics $mailbox.UserPrincipalName | Select-Object TotalItemSize, TotalDeletedItemSize, ItemCount, DeletedItemCount, LastUserActionTime
    
		$result += New-Object PSObject -property $([ordered]@{

				UserName             = $mailbox.DisplayName
				UserPrincipalName    = $mailbox.UserPrincipalName
				Type                 = $mailbox.RecipientTypeDetails
				TotalItemSize        = $mailboxStats.TotalItemSize
				TotalDeletedItemSize = $mailboxStats.TotalDeletedItemSize
				ItemCount            = $mailboxStats.ItemCount
				DeletedItemCount     = $mailboxStats.DeletedItemCount
				LastUserActionTime   = $mailboxStats.LastUserActionTime  

			})
	}
}

$result | Export-CSV "C:\Temp\Mailboxes.CSV" -Delimiter ';' -NoTypeInformation -Encoding UTF8
