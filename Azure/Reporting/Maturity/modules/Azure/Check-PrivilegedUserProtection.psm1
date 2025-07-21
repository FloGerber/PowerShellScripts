
function Check-PrivilegedUserProtection {
    try {
        $privilegedRoles = @('Owner', 'Contributor', 'User Access Administrator')
        $assignments = Get-AzRoleAssignment | Where-Object {
            $_.RoleDefinitionName -in $privilegedRoles
        }

        $aadUsers = @()
        foreach ($assignment in $assignments) {
            if ($assignment.SignInName) {
                $user = Get-MgUser -UserId $assignment.SignInName
                if ($user) {
                    $aadUsers += $user
                }
            }
        }

        # Check Conditional Access policies enforcing MFA
        $caPolicies = Get-MgIdentityConditionalAccessPolicy
        $mfaRequiredPolicies = $caPolicies | Where-Object {
            $_.GrantControls.BuiltInControls -contains 'mfa'
        }

        # Check if Security Defaults are enabled
        $securityDefaultsEnabled = (Get-MgPolicyIdentitySecurityDefaultEnforcementPolicy).IsEnabled

        $protectedCount = 0
        $unprotectedUsers = @()

        foreach ($user in $aadUsers) {
            $methods = Get-MgUserAuthenticationMethod -UserId $user.Id -all

            $hasMFA = $methods | Where-Object {
                $_.AdditionalProperties["@odata.type"] -match "softwareOathAuthenticationMethod" -or
                $_.AdditionalProperties["@odata.type"] -match "fido2AuthenticationMethod" -or
                $_.AdditionalProperties["@odata.type"] -match "microsoftAuthenticatorAuthenticationMethod" -or
                $_.AdditionalProperties["@odata.type"] -match "windowsHelloForBusinessAuthenticationMethod"
            }

            $isPolicyEnforced = ($mfaRequiredPolicies.Count -gt 0 -or $securityDefaultsEnabled)

            if ($hasMFA.Count -gt 0 -and $isPolicyEnforced) {
                $protectedCount += 1
            } else {
                $unprotectedUsers += $user.UserPrincipalName
            }
        }

        return [PSCustomObject]@{
            Result = ($unprotectedUsers.Count -eq 0)
            Summary = @{
                ProtectedUsers         = $protectedCount
                UnprotectedUsers       = $unprotectedUsers.Count
                ConditionalAccessMFA   = $mfaRequiredPolicies.Count
                SecurityDefaultsActive = $securityDefaultsEnabled
            }
            Details = @{
                UnprotectedUsers           = $unprotectedUsers
                ConditionalAccessEnforced = $mfaRequiredPolicies
            }
        }

    } catch {
        return [PSCustomObject]@{
            Result  = $false
            Summary = "⚠️ Failed to assess privileged user protection"
            Details = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Check-PrivilegedUserProtection