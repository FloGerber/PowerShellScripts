<#PSScriptInfo
.VERSION 
    0.0.1
.GUID
    05bdc02e-20fa-499e-b8ba-4b65b4e17773
.AUTHOR 
    Florian Gerber
.TAGS 
    Entra ID
.RELEASENOTES
    Initial Release
#>

#Requires -Module AzureAD
<# 
.DESCRIPTION 
    Get Empty Entra ID Groups for cleanup.
#> 
Param()

$entraIdGroups = Get-AzADGroup
foreach ($entraIdGroup in $entraIdGroups) {
    $WarningPreference = "silentlycontinue"
    $groupMembers = Get-AzADGroupMember -ObjectId $entraIdGroup.Id 

    if (($groupMembers).count -lt 1) {

        Write-Output "$($entraIdGroup.DisplayName)"

    }
}