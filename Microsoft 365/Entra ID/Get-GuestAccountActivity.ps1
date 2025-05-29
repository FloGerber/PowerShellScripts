
Connect-ExchangeOnline
AzureADPreview\Connect-AzureAD 

$modulesLoaded = Get-Module | Select-Object Name
If (!($modulesLoaded -match "ExchangeOnlineManagement")) {
    Write-Host "Please connect to the Exchange Online Management module and then restart the script"; break
}
If (!($modulesLoaded -match "AzureADPreview")) {
    Write-Host "Please connect to the Azure AD Preview module and then restart the script"; break
}
#If (!($ModulesLoaded -match "AzureAD")) {Write-Host "Please connect to the Azure AD Preview module and then restart the script"; break}
# OK, we seem to be fully connected to Exchange Online and Azure AD

# Start by finding all Guest Accounts
Write-Host "Finding Guest Accounts"
[array]$guestAccounts = (Get-AzureADUser -Filter "UserType eq 'Guest'" -All $True | Select-Object Displayname, UserPrincipalName, Mail, ObjectId | Sort-Object DisplayName)
If (!($guestAccounts)) {
    Write-Host "No guest accounts can be found - exiting" ; break 
}
$auditLogLookupDate = Get-Date(Get-Date).AddDays(-90) #For audit log
$messageTraceLookupDate = Get-Date(Get-Date).AddDays(-10) #For message trace
$endDate = Get-Date; $active = 0; $emailActive = 0; $inactive = 0; $auditRecord = 0; $GNo = 0
$report = [System.Collections.Generic.List[Object]]::new() # Create output file for report
Clear-Host; $GNo = 0
Write-Host $guestAccounts.Count "guest accounts found. Checking their activity..."
ForEach ($guest in $guestAccounts) {
    $GNo++
    $ProgressBar = "Processing guest " + $guest.DisplayName + " (" + $GNo + " of " + $guestAccounts.Count + ")" 
    Write-Progress -Activity "Checking Azure Active Directory Guest Accounts for activity" -Status $ProgressBar -PercentComplete ($GNo / $guestAccounts.Count * 100)
    $lastAuditRecord = $Null; $groupNames = $Null; $lastAuditAction = $Null; $i = 0; $reviewFlag = $False
    # Search for audit records for this user
    [array]$records = (Search-UnifiedAuditLog -UserIds $guest.Mail, $guest.UserPrincipalName -Operations UserLoggedIn, SecureLinkUsed, TeamsSessionStarted -StartDate $auditLogLookupDate -EndDate $endDate -ResultSize 1)
    If ($records) {
        # We found some audit records
        $lastAuditRecord = $records[0].CreationDate; $lastAuditAction = $records[0].Operations; $auditRecord++
    }
    Else {
        $lastAuditRecord = "None found"; $lastAuditAction = "N/A" 
    }
    # Check email tracking logs because guests might receive email through membership of Outlook Groups. Email address must be valid for the check to work
    If ($Null -ne $guest.Mail) {
        $emailRecords = (Get-MessageTrace -StartDate $messageTraceLookupDate -EndDate $endDate -Recipient $guest.Mail)
    }           
    If ($emailRecords.Count -gt 0) {
        $emailActive++
    }

    # Find what Microsoft 365 Groups the guest belongs to
    $groupNames = $Null
    $distinguishedName = (Get-ExoRecipient -Identity $G.UserPrincipalName).DistinguishedName
    If ($distinguishedName -like "*'*") {
        $distinguishedNameNew = "'" + "$($distinguishedName.Replace("'","''''"))" + "'"
        $command = "Get-Recipient -Filter 'Members -eq '$distinguishedNamenew'' -RecipientTypeDetails GroupMailbox | Select DisplayName, ExternalDirectoryObjectId"
        $guestGroups = Invoke-Expression $command
    }
    Else {
        $guestGroups = (Get-Recipient -Filter "Members -eq '$distinguishedName'" -RecipientTypeDetails GroupMailbox | Select-Object DisplayName, ExternalDirectoryObjectId) 
    }
    If ($Null -ne $guestGroups) {
        $groupNames = $guestGroups.DisplayName -join ", " 
    }

    # Figure out the domain the guest is from so that we can report this information
    $domain = $guest.Mail.Split("@")[1]
    # Figure out age of guest account in days using the creation date in the extension properties of the guest account
    $creationDate = (Get-AzureADUserExtension -ObjectId $guest.ObjectId).get_item("createdDateTime") 
    $accountAge = ($creationDate | New-TimeSpan).Days
    # Find if there's been any recent sign on activity
    $userLastLogonDate = $Null
    $userObjectId = $guest.ObjectId
    $userLastLogonDate = (Get-AzureADAuditSignInLogs -Top 1  -Filter "userid eq '$userObjectId' and status/errorCode eq 0").CreatedDateTime 
    If ($Null -ne $userLastLogonDate) {
        $userLastLogonDate = Get-Date ($userLastLogonDate) -format g 
    }
    Else {
        $userLastLogonDate = "No recent sign in records found" 
    }
    # Flag the account for potential deletion if it is more than a year old and isn't a member of any Office 365 Groups.
    If (($accountAge -gt 365) -and ($Null -eq $groupNames)) {
        $reviewFlag = $True
    } 
    # Write out report line     
    $reportLine = [PSCustomObject]@{ 
        Guest               = $guest.Mail
        Name                = $guest.DisplayName
        Domain              = $domain
        Inactive            = $reviewFlag
        Created             = $creationDate 
        AgeInDays           = $accountAge       
        EmailCount          = $emailRecords.Count
        "Last sign-in"      = $userLastLogonDate
        "Last Audit record" = $lastAuditRecord
        "Last Audit action" = $lastAuditAction
        "Member of"         = $groupNames 
        UPN                 = $guest.UserPrincipalName
        ObjectId            = $guest.ObjectId 
    } 
    $report.Add($reportLine) 
    # Update Azure AD with details.
    $activeText = "Active"
    If ($reviewFlag -eq $True) {
        $activeText = "inactive" 
    }
    $text = "Guest account reviewed on " + (Get-Date -format g) + " when account was deemed " + $activeText
    Set-MailUser -Identity $G.Mail -CustomAttribute1 $text
} 
# Generate the output files
$report | Sort-Object Name | Export-CSV -NoTypeInformation c:\temp\GuestActivity.csv   
$report | Where-Object { $_.Inactive -eq $True } | Select-Object ObjectId, Name, UPN, AgeInDays | Export-CSV -NotypeInformation c:\temp\InActiveGuests.CSV
Clear-Host    
$active = $auditRecord + $emailActive  
# Figure out the domains guests come from
$domains = $report.Domain | Sort
$domainsCount = @{}
$domains | ForEach-Object { $domainsCount[$_]++ }
$domainsCount = $domainsCount.GetEnumerator() | Sort-Object -Property Value -Descending
$domainNames = $domains | Sort-Object -Unique

$percentInactive = (($guestAccounts.Count - $active) / $guestAccounts.Count).toString("P")
Write-Host ""
Write-Host "Statistics"
Write-Host "----------"
Write-Host "Guest Accounts           " $guestAccounts.Count
Write-Host "Active Guests            " $active
Write-Host "Audit Record found       " $auditRecord
Write-Host "Active on Email          " $emailActive
Write-Host "InActive Guests          " ($guestAccounts.Count - $active)
Write-Host "Percent inactive guests  " $percentInactive
Write-Host "Number of guest domains  " $domainsCount.Count
Write-Host ("Domain with most guests   {0} ({1})" -f $domainsCount[0].Name, $domainsCount[0].Value)
Write-Host " "
Write-Host "Guests found from domains " ($domainNames -join ", ")
Write-Host " "
Write-Host "The output file containing detailed results is in c:\temp\GuestActivity.csv" 
Write-Host "A CSV file containing the User Principal Names of inactive guest accounts is in c:\temp\InactiveGuests.csv"
