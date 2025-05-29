Connect-AzureAD
Add-Type -AssemblyName System.Web

$customers = "<Customer Number>"

$serviceAccountGroup = (Get-AzureADGroup -Filter "DisplayName eq 'SVC_Accounts'").ObjectId
$groups = $serviceAccountGroup

foreach ($customer in $customers) {

    $userName = "svc-$customer-001"
    $domain = "<Domain>"

    $passwordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
    $password = ([System.Web.Security.Membership]::GeneratePassword(34, 10))
    $passwordProfile.Password = $password
    $passwordProfile.ForceChangePasswordNextLogin = $false

    Write-Output "Start creating user: $userName `n"

    New-AzureADUser -DisplayName "$customer SQL SVC Account" -PasswordProfile $passwordProfile -UserPrincipalName "$userName@$domain" -AccountEnabled $true -MailNickName "$userName"

    $userObjectID = (Get-AzureADUser -Filter "userPrincipalName eq '$userName@$domain'").ObjectId

    Write-Output "New User was created: `n"
    Write-Output "Username: $userName@$domain"
    Write-Output "Password: $Pass `n"

    foreach ($group in $groups) {
        Write-Output "Start adding user: $userName to Group: $group `n"

        Add-AzureADGroupMember -ObjectId $group -RefObjectId $userObjectID

        Write-Output "User: $userName successfully added to Group: $group `n"
    }
}