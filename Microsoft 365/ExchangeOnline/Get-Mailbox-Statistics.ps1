<#PSScriptInfo
.VERSION 
	0.0.1
.GUID
	9a404a62-488a-4b45-a92f-2771805be9a3
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
	Get Exchange Online Mailbox Statistics from multiple mailboxes in an specific time range. 
#> 
Param()

Connect-ExchangeOnline

$moduleLoaded = Get-Module | Select-Object Name
If (!($moduleLoaded -match "ExchangeOnlineManagement")) {
	Write-Host "Please connect to the Exchange Online Management module and then restart the script"; break
}

$startDate = Get-Date(Get-Date).AddDays(-7)
$endDate = Get-Date; $GNo = 0

# Input the list of mailboxes, "hr@domain.com", "marketing@domain.com"
$mailboxes = 

Clear-Host; $GNo = 0
$output = ForEach ($mailbox in $mailboxes) {

	$GNo++
	$progressBar = "Processing mailbox " + $mailbox + " (" + $GNo + " of " + $mailboxes.count + ")" 

	Write-Progress -Activity "Check E-Mail Activity" -Status $progressBar -PercentComplete ($GNo / $mailboxes.Count * 100)

	$mailboxstats = Get-EXOMailboxStatistics -Identity $mailbox -IncludeSoftDeletedRecipients

	$mailboxfolderstats = Get-EXOMailboxFolderStatistics -Identity $mailbox -FolderScope Inbox | Where-Object { $_.Name -EQ "Posteingang" -or $_.Name -EQ "Inbox" } #| Select-Object -Property Identity, ItemsInFolder, ItemsInFolderAndSubfolders, FolderSize, FolderAndSubfolderSize #| Select-Object {$_.VisibleItemsInFolder, $_.HiddenItemsInFolder, $_.ItemsInFolder, $_.ItemsInFolderAndSubfolders}

	$inboundMessageTrace = Get-MessageTrace -StartDate $startDate -EndDate $endDate -RecipientAddress $mailbox
	$outboundMessageTrace = Get-MessageTrace -StartDate $startDate -EndDate $endDate -SenderAddress $mailbox

	Write-Output ""
	write-Output  $mailboxstats.Displayname
	Write-Output  ""
	Write-Output  "Statistics"
	Write-Output  "----------"
	Write-Output  ""
	Write-Output  "Inbound Message                      : $($inboundMessageTrace.Count) "
	Write-Output  "Outbound Message                     : $($outboundMessageTrace.Count)" 
	Write-Output  "Mailbox Items in Inbox               : $($mailboxfolderstats.ItemsInFolder)"
	Write-Output  ""

}

$output
