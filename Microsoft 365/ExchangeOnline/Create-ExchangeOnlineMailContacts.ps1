<#PSScriptInfo
.VERSION 
    0.0.1
.GUID
    f3e3ff46-f9c6-4de6-a755-39d07cefd33c
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
    Create Mail Contacts in Exchange Online. 
#> 

Param()

Connect-ExchangeOnline

$contacts = 

foreach ($contact in $contacts) {

    $fullName = $contact.split("@")[0]
    $firstName = $fullName.split(".")[1]
    $lastName = $fullName.Split(".")[0]
    
    New-MailContact -Name "$($firstName) $($lastName)" -ExternalEmailAddress "$($contact)"

}
