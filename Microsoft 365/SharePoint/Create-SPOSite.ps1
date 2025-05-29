<#PSScriptInfo
.VERSION 
	0.0.1
.GUID
	ae46cbf7-65a6-4f20-b613-d7a14e5b2d71
.AUTHOR 
	Florian Gerber
.TAGS 
	SharePoint Online
.RELEASENOTES
	Initial Release
#>

#Requires -Module Microsoft.Graph

<# 
.DESCRIPTION 
	Create SharePoint Online Sites. 
#> 

[CmdletBinding()]
Param
(
	[Parameter(Mandatory = $true,
		ValueFromPipelineByPropertyName = $true)]
	[String[]]
	$displayName,
	[Parameter(Mandatory = $false,
		ValueFromPipelineByPropertyName = $true)]
	[String[]]
	$description,
	[Parameter(Mandatory = $true,
		ValueFromPipelineByPropertyName = $true)]
	[String[]]
	$mailNickname,
	[Parameter(Mandatory = $true,
		ValueFromPipelineByPropertyName = $true)]
	[String[]]
	$ownerUPN
)

begin {
	if (!(Get-MgContext -ErrorAction SilentlyContinue)) { 
		Write-Warning -Message "Not connected to MGGraph, trying to connect now."
		Connect-MgGraph -Scopes "Sites.Manage.All", "Group.ReadWrite.All", "Directory.ReadWrite.All"
	}
}

process {

	$client = @{
		Name = "Test"
	}

	# Define site details
	$sitePayload = @{
		displayName    = "$($client.Name) Document Center"
		description    = "Dedicated SharePoint site for $($client.Name)"
		siteCollection = @{
			"template" = "STS#3"
		}
	}

	# Create site using Graph API
	$siteResponse = Invoke-MgGraphRequest -Method Post -Uri "https://graph.microsoft.com/v1.0/sites" -Body ($sitePayload | ConvertTo-Json -Depth 10)
	Write-Output "✅ Created SharePoint site (ID: $($siteResponse.Id))"

	try {
		New-MgSitePermission -SiteId $siteId -Roles @("write") -GrantedToIdentities @(@{Id = $groupId })
		Write-Output "✅ Assigned security group to SharePoint site"
	}
 catch {
		Write-Output "❌ Failed to assign security group for $($client.Name): $_"
	}

}