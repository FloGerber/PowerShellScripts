<#PSScriptInfo
.VERSION 
    0.0.1
.GUID
    bc409110-5dc1-46ed-9eea-9dfb52f5e62b
.AUTHOR 
    Florian Gerber
.TAGS 
    Entra ID
.RELEASENOTES
    Initial Release
#>

#Requires -Module Microsoft.Graph

<# 
.DESCRIPTION 
    Reviews Disabled user in EntraID and deletes them. 
.SYNOPSIS
    Check Dissabled Users.
.DESCRIPTION
    Check if user is Disabled and Password was changed within the last 14 Days in Entra ID and delete them if true.
.NOTES
    Exit Code 0: Everything was fine
    Exit Code 1: There where some Problem durring operation
#> 
Param()

begin {
    if (!(Get-MgContext -ErrorAction SilentlyContinue)) { 
        Write-Warning -Message "Not connected to MGGraph, trying to connect now."
        Connect-MgGraph -Scopes "User.ManageIdentities.All", "Directory.AccessAsUser.All", "User.ReadWrite.All", "Directory.ReadWrite.All"
    }
}

process {

    $InformationPreference = 'Continue'

    $date = (Get-Date).AddDays(-14).ToString("yyyy:MM:dd")
    $users = Get-MgUser -Filter 'accountEnabled eq false' -all

    if ($users.count -eq 0) {
        Write-Information -MessageData "No disabled User found."
        exit 0
    }
    else {
        Write-Information -MessageData "Found $($users.count) disabled User Accounts."
    }

    # Check last Password Change Timestamp and Deletion Mark
    foreach ($user in $users) {
        $lastPasswortChangeTimestamp = (Get-MgUser -UserId $user.Id -Select "LastPasswordChangeDateTime" | Select-Object -ExpandProperty LastPasswordChangeDateTime).ToString("yyyy:MM:dd")
        
        $postalCode = Get-MgUser -UserId $user.Id -Select "PostalCode" | Select-Object -ExpandProperty PostalCode
        
        if (($null -eq $lastPasswortChangeTimestamp -Or $lastPasswortChangeTimestamp -lt $date) -And $postalCode -ne "UserMarkedforDeletion" ) {
            Write-Information -MessageData "The User: $($user.UserPrincipalName), is dissabled but the Password wasn't changed within the last 14 days and the Deletion Mark is not Set, the Password will now be set to a Random String and Deletion Mark will be set."
           
            $charlist = [char]94..[char]126 + [char]65..[char]90 + [char]47..[char]57
            $passwordLength = (1..10 | Get-Random) + 33  
            $passwordList = @()
            For ($i = 0; $i -lt $passwordlength; $i++) {
                $passwordList += $charList | Get-Random
            }
            $password = -join $passwordList

            $passwordProfile = @{
                Password                             = $password
                ForceChangePasswordNextSignIn        = $false
                ForceChangePasswordNextSignInWithMfa = $false
            }

            Update-MgUser -UserId $user.Id -PostalCode "UserMarkedforDeletion" -PasswordProfile $passwordProfile

        }
        elseif (($date -gt $lastPasswortChangeTimestamp -Or $lastPasswortChangeTimestamp -eq $date) -And $postalCode -eq "UserMarkedforDeletion" ) {
            Write-Information -MessageData "Will delete the User: $($user.UserPrincipalName), which is disabled since 14 Days"

            ## was intendet for cleaning up FSLogix profiles in an Azure Hosting environment.
            # $username = $user.UserPrincipalName.Split('@')[0]
            # $customerNumber = $username.Substring(1, 6)

            # try {
            #     ProfileCleanUp -Username $username -CustomerNumber $customerNumber -WhatIf
            # }
            # catch {
            #     Write-Error "Exception caught : $_" -ErrorAction Inquire
            # }
            Remove-MgUser -UserId $user.Id
        }
        else {
            Write-Information -MessageData "Currently there is no Users to be deleted"
            exit 0
        }
    }
}
end {
    Disconnect-MgGraph
}
