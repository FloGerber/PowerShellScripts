<#PSScriptInfo
.VERSION 
	0.0.1
.GUID
	5948c7db-8311-45ef-865c-fed5487a4326
.AUTHOR 
	Florian Gerber
.TAGS 
	Exchange Online
.RELEASENOTES
	Initial Release
#>

#Requires -Module ExchangeOnlineManagement
#Requires -Module Microsoft.Graph.Entra

<#
.SYNOPSIS
    Creating an App Registration in EntraID and Assign RBAC Access for SharedMailbox.
.DESCRIPTION 
	Create an Entra ID App Registration and grands Access to SharedMailbox via RBAC.
.PARAMETER permissions
    Input for the Permission for the Application, Multiple allowed, Valid Permissions "Mail.ReadWrite", "Mail.Send", "Mail.Read".
.PARAMETER appName
    Application Name, for identification within EntraID and Exchange.
.PARAMETER sharedMailbox
    The SharedMailbox wich should be accessed.
.EXAMPLE
    SharedMailbox-RBAC.ps1 -permissions Mail.ReadWrite -appName Test -sharedMailbox test@test.com
.EXAMPLE
    SharedMailbox-RBAC.ps1 -permissions "Mail.ReadWrite", "Mail.Send", "Mail.Read" -appName Test -sharedMailbox test@test.com
#> 

[CmdletBinding()]
Param
(
	[Parameter(Mandatory = $true,
		ValueFromPipelineByPropertyName = $true)]
	[String[]]
	[ValidateSet("Mail.ReadWrite", "Mail.Send", "Mail.Read")]
	$permissions,
	[Parameter(Mandatory = $true,
		ValueFromPipelineByPropertyName = $true)]
	[String[]]
	$appName,
	[Parameter(Mandatory = $true,
		ValueFromPipelineByPropertyName = $true)]
	[String[]]
	$sharedMailbox
)

begin {

	Write-Output "Start connecting to EntraID and Exchange Online."

	Connect-Entra -Scopes 'Application.ReadWrite.All', 'Directory.ReadWrite.All'
	Connect-ExchangeOnline

	[hashtable]$permissionLookUpTable = @{
		"Mail.Send"      = "b633e1c5-b582-4048-a93e-9f11b44c7e96"
		"Mail.ReadWrite" = "e2a3a72e-5f79-4c64-b1b1-878b674786c9"
		"Mail.Read"      = "810c84a8-4a9e-49e6-bf7d-12d183f40d01"
	}

	# Define the resourceAccess list
	$resourceAccess = @()

	# Check if any options in the validSet are provided
	foreach ($permission in $permissions) {
		$resourceAccess += @{
			"id"   = "$($permissionLookUpTable[$permission])"
			"type" = "Role"
		}
	}

	$requiredResourceAccess = @(
		@{
			"resourceAppId"  = "00000003-0000-0000-c000-000000000000"  # Example resource app ID for Microsoft Graph
			"resourceAccess" = $resourceAccess
		}
	)
}
    
process {

	try {
		Write-Output "Try creating the Entra Application and Service Principal."
		$appRegistration = New-EntraApplication -DisplayName "$($appName)"
		$servicePrincipal = New-EntraServicePrincipal -AppId $appRegistration.AppId
	}
	catch {
		Write-Error "Could not create Entra Applicatation or Service Principal !" -Exception $_ -ErrorAction Stop
	}

	try {
		Write-Output "Try creating the Secret for the Application"
		$passwordCredential = New-Object Microsoft.Open.MSGraph.Model.PasswordCredential
		$passwordCredential.StartDateTime = Get-Date
		$passwordCredential.EndDateTime = ((Get-Date).AddMonths(24))
		$passwordCredential.CustomKeyIdentifier = [System.Text.Encoding]::UTF8.GetBytes("$($appName)_ClientSecret")
		$passwordCredential.Hint = 'Generatet Secret by Script'
		$passwordCredential.DisplayName = "$($appName)_ClientSecret"

		$secretValue = New-EntraApplicationPassword -ApplicationId $appRegistration.Id -PasswordCredential $passwordCredential
	}
	catch {
		Write-Error "Could not create the Application Secret !" -Exception $_ -ErrorAction Stop
	}
    
	try {
		Write-Output "Try granting the Required API Access for the Application"
		Set-EntraApplication -ObjectId $appRegistration.ObjectId -RequiredResourceAccess $requiredResourceAccess
	}
	catch {
		Write-Error "Could not assign the required permissions, please check in Entra ID Portal !" -Exception $_ 
	}
    
	Write-Output "Sleep for 30 Seconds, Entra needs some time for replicating the Service Principal befor we continue setting up Exchange Site."
	Start-Sleep -Seconds 30
 
	try {
		Write-Output "Try creating the Exchange Service Principal for the App Registration."
		New-ServicePrincipal -AppId $servicePrincipal.AppId -ObjectId $servicePrincipal.Id -DisplayName "$($appName) - EXO Service Principal"
	}
	catch {
		Write-Error "Could not create the Exchange Service Principal !" -Exception $_ -ErrorAction Stop
	}
    
	try {
		Write-Output "Try setting up the Required Management Scope and adding the required Permissions."
        
		$managementScopeParameter = @{ 
			Name                       = "$($appName) - ManagementScope" 
			RecipientRestrictionFilter = "RecipientTypeDetails -eq 'SharedMailbox' -and PrimarySmtpAddress -eq `'$sharedMailbox`'"
		}
    
		$managementScope = New-ManagementScope @managementScopeParameter
    
		foreach ($permision in $permisions) {
			New-ManagementRoleAssignment -App $appRegistration.AppId -Role "Application $($permision)" -CustomResourceScope "$($managementScope.Name)"
		}
	}
	catch {
		Write-Error "Could not create the Management Scope or adding the Permission !" -Exception $_ -ErrorAction Stop
	}

	Test-ServicePrincipalAuthorization -Resource $sharedMailbox -Identity $appRegistration.AppId

	Write-Host "Client ID: $($appRegistration.AppId)"
	Write-Host "Tenant ID: $($(Get-EntraTenantDetail).Id)"
	Write-Host "Client Secret: $($secretValue.SecretText)"

}
    
end {
	Disconnect-Entra
	Disconnect-ExchangeOnline
}
