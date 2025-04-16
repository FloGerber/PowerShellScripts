<#PSScriptInfo
.VERSION 
	0.0.1
.GUID
	0ee87c93-9be4-4c0f-abf2-a197705a9062
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
	Create SPF, DKIM and DMARC Records for each Exchange Online Domain. 
.EXAMPLE
    Create-SPF-DKIM-Dmarc -TenantName test.onmicrosoft.com -AggregateMailbox aggregate@example.org -ForensicMailbox forensic@example.org
#>

[CmdletBinding()]
param (
	[Parameter(Mandatory = $true)]
	[String[]]
	$TenantName,
	[Parameter(Mandatory = $true)]
	[String[]]
	$AggregateMailbox,
	[Parameter(Mandatory = $true)]
	[String[]]
	$ForensicMailbox
)

Connect-ExchangeOnline

$ModulesLoaded = Get-Module | Select-Object Name
If (!($ModulesLoaded -match "ExchangeOnlineManagement")) {
	Write-Host "Please connect to the Exchange Online Management module and then restart the script"; break
}

$Domains = Get-Mailbox -ResultSize Unlimited | Select-Object EmailAddresses -ExpandProperty EmailAddresses | Where-Object { $_ -like "smtp*" } | ForEach-Object { ($_ -split "@")[1] } | Sort-Object -Unique
$Domains

# Verify DKIM and DMARC records.
Write-Output "-------- DKIM and DMARC DNS Records Report --------"
Write-Output ""

$Result = foreach ($Domain in $Domains) {
	Write-Output "---------------------- $Domain ----------------------"
	Write-Output "DKIM Selector 1 CNAME Record:"
	nslookup -q=cname selector1._domainkey.$Domain | Select-String "canonical name"
	Write-Output ""
	Write-Output "DKIM Selector 2 CNAME Record:"
	nslookup -q=cname selector2._domainkey.$Domain | Select-String "canonical name"
	Write-Output ""
	Write-Output "DMARC TXT Record:"
    (nslookup -q=txt _dmarc.$Domain | Select-String "DMARC1") -replace "`t", ""
	Write-Output ""
	Write-Output "SPF TXT Record:"
    (nslookup -q=txt $Domain | Select-String "spf1") -replace "`t", ""
	Write-Output "-----------------------------------------------------"
	Write-Output ""
	Write-Output ""
}
$Result | Clip

$Result = "Protection`tDomain`tTyp`tHost name`tValue`tTTL`n"

foreach ($Domain in $Domains) {
	$Result += "SPF`t$Domain`tTXT`t@`tv=spf1 include:spf.protection.outlook.com -all`t3600`n"
	$Result += "DKIM`t$Domain`tCNAME`tselector1._domainkey`tselector1-$($Domain -replace "\.", "-")._domainkey.$TenantName`t3600`n"
	$Result += "DKIM`t$Domain`tCNAME`tselector2._domainkey`tselector2-$($Domain -replace "\.", "-")._domainkey.$TenantName`t3600`n"
	$Result += "DMARC`t$Domain`tTXT`t_dmarc`tv=DMARC1; p=reject; pct=100; rua=mailto:$AggregateMailbox$Domain; ruf=mailto:$ForensicMailbox$Domain; fo=1; aspf=s; adkim=s; ri=604800; sp=reject`t3600`n"
}

$Result | Clip