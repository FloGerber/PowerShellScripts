# Check for Service Bus or Event Grid use for async messaging
function Check-MessagingServicesAudit {
    try {
        $serviceBusItems = @()
        $eventGridItems = @()

        # --- Service Bus Namespaces ---
        try {
            $busNamespaces = Get-AzServiceBusNamespace
            foreach ($ns in $busNamespaces) {
                $serviceBusItems += [PSCustomObject]@{
                    Type         = "ServiceBus"
                    Namespace    = $ns.Name
                    Location     = $ns.Location
                    Sku          = $ns.Sku.Name
                    ResourceGroup= $ns.ResourceGroupName
                }
            }
        } catch {}

        # --- Event Grid Topics ---
        try {
            $topics = Get-AzEventGridTopic
            foreach ($topic in $topics) {
                $eventGridItems += [PSCustomObject]@{
                    Type         = "EventGrid"
                    TopicName    = $topic.Name
                    Location     = $topic.Location
                    ResourceGroup= $topic.ResourceGroupName
                    ProvisioningState = $topic.ProvisioningState
                }
            }
        } catch {}

        $messaging = $serviceBusItems + $eventGridItems

        return [PSCustomObject]@{
            Result = ($messaging.Count -gt 0)
            Summary = @{
                ServiceBusNamespaces = $serviceBusItems.Count
                EventGridTopics      = $eventGridItems.Count
            }
            Details = $messaging
        }

    } catch {
        return [PSCustomObject]@{
            Result = $false
            Summary = "🚨 Failed to evaluate messaging services"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-MessagingServicesAudit