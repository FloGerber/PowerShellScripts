<#PSScriptInfo
.VERSION 
	0.0.1
.GUID
	93c2a95f-495a-4a6e-ad33-cc09def3d1eb
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
	Create Security Groups in Entra ID. 
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
        Connect-MgGraph -Scopes "Group.ReadWrite.All"
    }
}

process {

    $InformationPreference = 'Continue'

	$groupParamenter = @{
		DisplayName     = $displayName
        Description     = $description
        MailEnabled     = $false
        MailNickname    = $mailNickname
        SecurityEnabled = $true
	}

	$securityGroup = New-MgGroup -BodyParameter $groupParamenter
	$securityGroupID = $securityGroup.Id

	if ($_.OwnerUPN) {
        $userId = (Get-MgUser -Filter "userPrincipalName eq '$($_.OwnerUPN)'").Id
        $ownerParams = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/users/$userId" }
        New-MgGroupOwnerByRef -GroupId $securityGroup.Id -BodyParameter $ownerParams
    }

    Write-Host "Created group: $($securityGroup.DisplayName)"

}
end {
    Disconnect-MgGraph
}


