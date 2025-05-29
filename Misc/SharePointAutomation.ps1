# Install Microsoft Graph PowerShell module
Install-Module Microsoft.Graph -Scope CurrentUser -Force
Import-Module Microsoft.Graph

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Sites.Manage.All", "Group.ReadWrite.All", "Directory.ReadWrite.All"

# Define customer names
$customers = @("Customer1", "Customer2", "Customer3")

foreach ($customer in $customers) {
    Write-Output "Processing: $customer"

    # 🏗 Step 1: Create Microsoft 365 Group
    $groupPayload = @{
        displayName = "$customer_SharePoint_Group"
        securityEnabled = $true
        description = "Security group for $customer's SharePoint access"
    }
    $groupResponse = New-MgGroup -BodyParameter $groupPayload
    $groupId = $groupResponse.Id
    Write-Output "✅ Created security group: $customer_SharePoint_Group"

    # 🏗 Step 2: Create SharePoint Site
    $sitePayload = @{
        displayName = "$customer Document Center"
        description = "Dedicated SharePoint site for $customer"
        siteCollection = @{ "template" = "STS#3" }
    }
    $siteResponse = Invoke-MgGraphRequest -Method Post -Uri "https://graph.microsoft.com/v1.0/sites" -Body ($sitePayload | ConvertTo-Json -Depth 10)
    $siteId = $siteResponse.Id
    Write-Output "✅ Created SharePoint site for $customer"

    # 🏗 Step 3: Assign Security Group to SharePoint Site
    New-MgSitePermission -SiteId $siteId -Roles @("write") -GrantedToIdentities @(@{Id=$groupId})
    Write-Output "✅ Assigned security group to SharePoint site"
}
Write-Output "🏁 All customers set up!"


# Define folder structure
$folders = @("Invoices", "Receipts", "Tax Returns", "Contracts")

foreach ($customer in $customers) {
    $siteUrl = "https://graph.microsoft.com/v1.0/sites/yourtenant.sharepoint.com:/sites/$customer"
    $driveId = (Invoke-MgGraphRequest -Method Get -Uri "$siteUrl/drives") | Select-Object -ExpandProperty id

    foreach ($folder in $folders) {
        $folderPayload = @{ name = $folder; folder = @{} }
        Invoke-MgGraphRequest -Method Post -Uri "$siteUrl/drives/$driveId/root/children" -Body ($folderPayload | ConvertTo-Json -Depth 10)
        Write-Output "✅ Created folder: $folder for $customer"
    }
}
Write-Output "🏁 Folder setup complete!"


# Install Microsoft Graph Intune module
Install-Module Microsoft.Graph.Intune -Scope CurrentUser -Force
Import-Module Microsoft.Graph.Intune

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All"

# Define the universal policy for SharePoint drive mapping
$policyPayload = @{
    displayName = "Universal SharePoint Drive Mapping Policy"
    description = "Maps client-specific SharePoint sites based on security group membership"
    settings = @(@{
        name = "MappedDrive"
        value = @{ letter = "Z:"; remotePath = "%GroupSiteURL%"; persistent = $true }
    })
}

# Create the policy
try {
    $policyResponse = New-MgDeviceManagementConfigurationPolicy -BodyParameter $policyPayload
    $policyId = $policyResponse.Id
    Write-Output "✅ Created universal Intune policy (ID: $policyId)"
} catch {
    Write-Output "❌ Failed to create Intune policy: $_"
}
