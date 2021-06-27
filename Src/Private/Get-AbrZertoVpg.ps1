function Get-AbrZertoVpg {
    <#
    .SYNOPSIS
    Used by As Built Report to retrieve Zerto ZVM VPG information
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
        Write-PscriboMessage "Collecting ZVM VPG information."
    }

    process {
        $Vpgs = Get-ZertoVpg | Sort-Object VpgName
        if (($Vpgs) -and ($InfoLevel.Vpg -gt 0)) {
            Section -Style Heading2 'VPGs' {
                # Collect VPG information
                $VpgInfo = foreach ($Vpg in $Vpgs) {
                    $VpgSettingsIdentifier = New-ZertoVpgSettingsIdentifier -vpgIdentifier $vpg.VpgIdentifier
                    $VpgSettings = Get-ZertoVpgSetting -vpgSettingsIdentifier $VpgSettingsIdentifier

                    [PSCustomObject] @{
                        'VPG Name' = $Vpg.VpgName
                        #'Identifier' = $Vpg.VpgIdentifier
                        'Direction' = Switch ($Vpg.SourceSite) {
                            "$($LocalSite.SiteName)" { 'Outgoing' }
                            default { 'Incoming' }
                        }
                        'Protected Site Type' = Switch ($Vpg.Entities.Protected) {
                            0 { 'VC' }
                            1 { 'vCD' }
                            2 { 'vCD' }
                            3 { 'N/A' }
                            4 { 'Hyper-V' }
                            default { 'Unknown' }
                        }
                        'Protected Site' = $VirtualizationSiteLookup."$($Vpg.ProtectedSite.Identifier)"
                        'Recovery Site Type' = Switch ($Vpg.Entities.Recovery) {
                            0 { 'VC' }
                            1 { 'vCD' }
                            2 { 'vCD' }
                            3 { 'N/A' }
                            4 { 'Hyper-V' }
                            default { 'Unknown' }
                        }
                        'Recovery Site' = $VirtualizationSiteLookup."$($Vpg.RecoverySite.Identifier)"
                        'Priority' = Switch ($Vpg.Priority) {
                            0 { 'Low' }
                            1 { 'Medium' }
                            2 { 'High' }
                            default { 'Unknown' }
                        }
                        'Protection Status' = Switch ($Vpg.Status) {
                            0 { 'Initializing' }
                            1 { 'Meeting SLA' }
                            2 { 'Not Meeting SLA' }
                            3 { 'RPO Not Meeting SLA' }
                            4 { 'History Not Meeting SLA' }
                            5 { 'Failing Over' }
                            6 { 'Moving' }
                            7 { 'Deleting' }
                            8 { 'Recovered' }
                            default { 'Unknown' }
                        }
                        'Sub Status' = Switch ($Vpg.SubStatus) {
                            0 { 'None' }
                            1 { 'Initial Sync' }
                            2 { 'Creating' }
                            3 { 'Volume Initial Sync' }
                            4 { 'Sync' }
                            5 { 'Recovery Possible' }
                            6 { 'Delta Sync' }
                            7 { 'Needs Configuration' }
                            8 { 'Error' }
                            9 { 'Empty Protection Group' }
                            10 { 'Disconnected From Peer No Recovery Points' }
                            11 { 'Full Sync' }
                            12 { 'Volume Delta Sync' }
                            13 { 'Volume Full Sync' }
                            14 { 'Failing Over Committing' }
                            15 { 'Failing Over Before Commit' }
                            16 { 'Failing Over Rolling Back' }
                            17 { 'Promoting' }
                            18 { 'Moving Committing' }
                            19 { 'Moving Before Commit' }
                            20 { 'Moving Rolling Commit' }
                            21 { 'Deleting' }
                            22 { 'Pending Remove' }
                            23 { 'Bitmap Sync' }
                            24 { 'Disconnected From Peer' }
                            25 { 'Replication Paused User Initiated' }
                            26 { 'Replication Paused System Initiated' }
                            27 { 'Recovery Storage Profile Error' }
                            #28 {''} Does not exist in API documentation
                            29 { 'Rolling Back' }
                            30 { 'Recovery Storage Error' }
                            31 { 'Journal Storage Error' }
                            32 { 'VM Not Protected' }
                            33 { 'Journal Or Recovery Missing Error' }
                            34 { 'Added VMs Initial Sync' }
                            35 { 'Replication Paused For Missing Volume' }
                            36 { 'Stopping For Failover' }
                            37 { 'Rolling Back Failover Live Failure' }
                            38 { 'Rolling Back Move Failure' }
                            39 { 'Splitting Committing' }
                            40 { 'Prepare Preseed' }
                            default { 'Unknown' }
                        }
                        'Target RPO ' = "$([math]::Round($Vpg.ConfiguredRpoSeconds / 60 / 60)) hours"
                        'Actual RPO' = Switch ($Vpg.ActualRPO) {
                            -1 { 'RPO Not Calculated' }
                            default { "$($Vpg.ActualRPO) seconds" }
                        }
                        'Provisioned Storage' = "$([math]::Round($Vpg.ProvisionedStorageInMB / 1024)) GB"
                        'Used Storage' = "$([math]::Round($Vpg.UsedStorageInMB / 1024)) GB"
                        'Number of VMs' = $Vpg.VmsCount
                        'Journal History' = "$([math]::Round($Vpg.HistoryStatusApi.ConfiguredHistoryInMinutes / 60)) hours"
                        'WAN Compression' = Switch ($VpgSettings.Basic.UseWanCompression) {
                            $true { 'Enabled' }
                            $false { 'Disabled' }
                        }
                        #'VMs' = ($VpgVMs.VmName | Sort-Object) -join ', '
                        #'IOPs'                      = $Vpg.IOPs
                        #'Last Test'                 = $Vpg.LastTest
                        #'Organization Name'         = $Vpg.OrganizationName
                        #'Progress' = "$($Vpg.ProgressPercentage)%"
                        #'Service Profile ID' = $Vpg.ServiceProfileIdentifier
                        #'Service Profile Name'      = $Vpg.ServiceProfileName
                        #'Protection Site'           = $Vpg.ProtectedSite.Identifier
                        #'Throughput In MB'          = $Vpg.ThroughputInMB
                        #'Zorg'                      = $Vpg.Zorg.Identifier
                    }
                }
                # Check InfoLevels, if 2 show individual tables, else show a single summarised table
                if ($InfoLevel.Vpg -ge 2) {
                    $VpgInfo | ForEach-Object {
                        $Vpg = $_
                        Section -Style Heading3 $($Vpg.'VPG Name') {
                            $TableParams = @{
                                Name = "VPG $($Vpg.'VPG Name') - $ZVM"
                                List = $true
                                ColumnWidths = 50, 50
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $Vpg | Table @TableParams
                        }
                    }
                } else {
                    $TableParams = @{
                        Name = "VPGs - $ZVM"
                        Columns = 'VPG Name','Recovery Site','Priority','Protection Status'
                        ColumnWidths = 30, 30, 20, 20
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $VpgInfo | Table @TableParams
                }
            }
        }
    }

    end {
    }

}