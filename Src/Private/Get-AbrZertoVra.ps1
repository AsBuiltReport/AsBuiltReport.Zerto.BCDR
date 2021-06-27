function Get-AbrZertoVra {
    <#
    .SYNOPSIS
    Used by As Built Report to retrieve Zerto ZVM VRA information
    .DESCRIPTION

    .NOTES
        Version:        0.1.0
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
    .EXAMPLE

    .LINK

    #>
    [CmdletBinding()]
    param (
    )

    begin {
        Write-PScriboMessage "Collecting ZVM VRA information."
    }

    process {
        $Vras = Get-ZertoVra | Sort-Object VraName
        if (($VRAs) -and ($InfoLevel.VRA -gt 0)) {
            Section -Style Heading2 'VRAs' {
                # Collect VRA information
                $VRAInfo = foreach ($VRA in $VRAs) {
                    [PSCustomObject] @{
                        'Host Address' = $VMHostLookup."$($VRA.HostIdentifier)"
                        'Host Version' = $VRA.HostVersion
                        'VRA Name' = $VRA.VraName
                        'VRA ID' = $VRA.VraIdentifier
                        'VRA Status' = Switch ($VRA.Status) {
                            0 { 'Installed' }
                            1 { 'Unsupported ESX Version' }
                            2 { 'Not Installed' }
                            3 { 'Installing' }
                            4 { 'Removing' }
                            5 { 'Installation Error' }
                            6 { 'Host Password Changed' }
                            6 { 'Updating IP Settings' }
                            8 { 'During Change Host' }
                            default { 'Unknown' }
                        }
                        <#
                        'VRA Status' = Switch ($VRA.Status) {
                            'NotInstalled' { 'Not Installed' }
                            'UnSupportedEsxVersion' { 'Unsupported ESX Version' }
                            'InstallationError' { 'Installation Error' }
                            'HostPasswordChanged' { 'Host Password Changed' }
                            'UpdatingIpSettings' { 'Updating IP Settings' }
                            'DuringChangeHost' { 'During Change Host' }
                            default { $VRA.Status }
                        }
                        #>
                        'VRA Version' = $VRA.VraVersion
                        'VRA RAM' = "$($VRA.MemoryInGB) GB"
                        'VRA IP Configuration' = $VRA.VraNetworkDataApi.VraIPConfigurationTypeApi
                        'VRA IP Address' = $VRA.VraNetworkDataApi.VraIPAddress
                        'VRA Subnet Mask' = $VRA.VraNetworkDataApi.SubnetMask
                        'VRA Default Gateway' = $VRA.VraNetworkDataApi.DefaultGateway
                        'VRA Group' = $VRA.VraGroup
                        'Datastore' = $VRA.DatastoreName
                        'Datastore Cluster' = Switch ($VRA.DatastoreClusterName) {
                            $null { '--' }
                            default { $VRA.DatastoreClusterName }
                        }
                        'Number of Protected VMs' = $VRA.ProtectedCounters.VMs
                        'Number of Protected Volumes' = $VRA.ProtectedCounters.Volumes
                        'Number of Protected VPGs' = $VRA.ProtectedCounters.Vpgs
                        'Number of Recovery VMs' = $VRA.RecoveryCounters.VMs
                        'Number of Recovery Volumes' = $VRA.RecoveryCounters.Volumes
                        'Number of Recovery VPGs' = $VRA.RecoveryCounters.Vpgs
                        <#
                        'Datastore Cluster Identifier' = $VRA.DatastoreClusterIdentifier
                        'Datastore Identifier' = $VRA.DatastoreIdentifier
                        'Link' = $VRA.Link
                        'Memory In GB' = $VRA.MemoryInGB
                        'Network Identifier' = $VRA.NetworkIdentifier
                        'Network Name' = $VRA.NetworkName
                        'Progress' = $VRA.Progress
                        'Self Protected Vpgs' = $VRA.SelfProtectedVpgs
                        'IP Assignment' = $VRA.VraIPConfigurationTypeApi
                        #>
                    }
                }
                # Check InfoLevels, if 2 show individual tables, else show a single summarised table
                if ($InfoLevel.VRA -ge 2) {
                    $VRAInfo | ForEach-Object {
                        $VRA = $_
                        Section -Style Heading3 $($VRA.'VRA Name') {
                            $TableParams = @{
                                Name = "VRA $($VRA.'VRA Name') - $ZVM"
                                List = $true
                                ColumnWidths = 50, 50
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $VRA | Table @TableParams
                        }
                    }
                } else {
                    $TableParams = @{
                        Name = "VRAs - $ZVM"
                        Columns = 'Host Address','Host Version','VRA Name','VRA Status','VRA IP Address','VRA Version'
                        ColumnWidths = 25, 10, 25, 13, 17, 10
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $VRAInfo | Table @TableParams
                }
            }
        }
    }

    end {
    }
}