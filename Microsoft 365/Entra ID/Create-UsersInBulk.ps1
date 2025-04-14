<#PSScriptInfo
.VERSION 
    0.0.1
.GUID
    f9f5f0df-fa5b-4a51-bb95-dfde963c2d25
.AUTHOR 
    Florian Gerber
.TAGS 
    Entra ID
.LICENSEURI
    https://github.com/FloGerber/PowerShellScripts/blob/main/LICENSE
.RELEASENOTES
    Initial Release
#>

#Requires -Module AzureAD

<#
.DESCRIPTION 
    Bulk create users bases on an List of Names.
#>
Param()

# Fill the Users Variable with names and run it. Example: "John Doe", "Jane Doe"
# UPN will be Lastname.Firstname@Domain.co,

$users = 

foreach ($user in $users) {

    $domain = ""
    $firstName = $user.Split(" ")[1]
    $lastName = $user.Split(" ")[0]
    $userPrincipalName = $lastName + "." + $firstName + "@" + $domain
    $displayName = $firstName + " " + $lastName

    Write-Host $UPN

    $password = "Welcome" + $firstName[0] + $lastName[0] + (Get-Date -Format "yyyy") + "!"

    $passwordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
    $passwordProfile.Password = $password

    New-AzureADUser -DisplayName $displayName -PasswordProfile $passwordProfile -UserPrincipalName $userPrincipalName -AccountEnabled $true -MailNickName $displayName

}