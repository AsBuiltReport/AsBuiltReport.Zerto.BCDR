function Get-AbrZertoDashboard {
    <#
    .SYNOPSIS
    Used by As Built Report to retrieve Zerto ZVM dashboard information
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
        Write-PscriboMessage "Collecting ZVM dashboard information."
    }

    process {
        $Vpgs = Get-ZertoVpg | Sort-Object VpgName
        $ProtectedVms = Get-ZertoProtectedVm | Sort-Object VmName
        if ($InfoLevel.Dashboard -ge 1) {
            Section -Style Heading2 'Dashboard' {
                $ZertoDashboard = [PSCustomObject] @{
                    'VPGs' = ($Vpgs).Count
                    'Protected VMs' = ($ProtectedVms).Count
                    'Data Protected (TB)' = [math]::Round((($ProtectedVms).ProvisionedStorageInMB | Measure-Object -Sum).Sum / 1024 / 1024, 0)
                    'Average RPO (secs)' = [math]::Round(((($vpgs.actualrpo | Measure-Object -Sum).Sum) / ($Vpgs).Count), 0)
                }
                $TableParams = @{
                    Name = "Dashboard - $ZVM"
                    ColumnWidths = 25, 25, 25, 25
                }
                if ($Report.ShowTableCaptions) {
                    $TableParams['Caption'] = "- $($TableParams.Name)"
                }
                $ZertoDashboard | Table @TableParams

                if ($InfoLevel.Dashboard -ge 2) {
                    Section -Style Heading3 'VPG Status' {
                        $VpgStatus = [PSCustomObject] @{
                            'Meeting SLA' = ($Vpgs | Where-Object {$_.Status -eq 1}).Count
                            'RPO Not Meeting SLA' = ($Vpgs | Where-Object {$_.Status -eq 3}).Count
                            'History Not Meeting SLA' = ($Vpgs | Where-Object {$_.Status -eq 4}).Count
                            'Not Meeting SLA' = ($Vpgs | Where-Object {$_.Status -eq 2}).Count
                            'Processing' = ($Vpgs | Where-Object {$_.Status -eq 0}).Count
                        }
                        $TableParams = @{
                            Name = "VPG Status - $ZVM"
                            ColumnWidths = 20, 20, 20, 20, 20
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $VpgStatus | Table @TableParams
                    }

                    Section -Style Heading3 'Site Topology' {
                        $SiteTopology = [PSCustomObject] @{
                            'Incoming VPGs' = ($Vpgs | Where-Object {$_.SourceSite -ne $($LocalSite.SiteName)}).Count
                            'Outgoing VPGs' = ($Vpgs | Where-Object {$_.SourceSite -eq $($LocalSite.SiteName)}).Count
                        }
                        $TableParams = @{
                            Name = "Site Topology - $ZVM"
                            ColumnWidths = 50, 50
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $SiteTopology | Table @TableParams
                    }

                    Section -Style Heading3 'Monitoring' {
                        $ZertoAlerts = Get-ZertoAlert
                        $ZertoEvents = Get-ZertoEvent -startDate (Get-Date).AddHours(-24)
                        $ZertoMonitoring = [PSCustomObject] @{
                            'Alerts' = $ZertoAlerts.Count
                            'Events (in last 24 hours)' = $ZertoEvents.Count
                        }
                        $TableParams = @{
                            Name = "Monitoring - $ZVM"
                            ColumnWidths = 50, 50
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $ZertoMonitoring | Table @TableParams
                    }
                }
            }
        }
    }

    end {
    }

}