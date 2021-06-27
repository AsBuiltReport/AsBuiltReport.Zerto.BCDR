function Get-AbrZertoProtectedVM {
    <#
    .SYNOPSIS
    Used by As Built Report to retrieve Zerto ZVM Protected VM information
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
        Write-PscriboMessage "Collecting ZVM Protected VM information."
    }

    process {
        $ProtectedVms = Get-ZertoProtectedVm | Sort-Object VmName
        ## TODO: VM NIC Count
        if (($ProtectedVms) -and ($InfoLevel.VM -gt 0)) {
            Section -Style Heading2 'Protected VMs' {
                # Collect VM information
                $VmInfo = foreach ($ProtectedVm in $ProtectedVms) {
                    [PSCustomObject] @{
                        'VM Name' = $ProtectedVm.VmName
                        'VPG Name' = $ProtectedVm.VpgName
                        'Direction' = Switch ($ProtectedVm.SourceSite) {
                            "$($LocalSite.SiteName)" { 'Outgoing' }
                            default { 'Incoming' }
                        }
                        'Protected Site Type' = Switch ($ProtectedVm.Entities.Protected) {
                            0 { 'VC' }
                            1 { 'vCD' }
                            2 { 'vCD' }
                            3 { 'N/A' }
                            4 { 'Hyper-V' }
                            default { 'Unknown' }
                        }
                        'Protected Site' = $VirtualizationSiteLookup."$($ProtectedVm.ProtectedSite.Identifier)"
                        'Recovery Site Type' = Switch ($ProtectedVm.Entities.Recovery) {
                            0 { 'VC' }
                            1 { 'vCD' }
                            2 { 'vCD' }
                            3 { 'N/A' }
                            4 { 'Hyper-V' }
                            default { 'Unknown' }
                        }
                        'Recovery Site' = $VirtualizationSiteLookup."$($ProtectedVm.RecoverySite.Identifier)"
                        'Priority' = Switch ($ProtectedVm.Priority) {
                            0 { 'Low' }
                            1 { 'Medium' }
                            2 { 'High' }
                            default { 'Unknown' }
                        }
                        'Protection Status' = Switch ($ProtectedVm.Status) {
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
                        'Sub Status' = Switch ($ProtectedVm.SubStatus) {
                            0 { 'None' }
                            1 { 'InitialSync' }
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
                            20 { 'Moving Rolling Back' }
                            21 { 'Deleting' }
                            22 { 'Pending Remove' }
                            23 { 'Bitmap Sync' }
                            24 { 'Disconnected From Peer' }
                            25 { 'Replication Paused User Initiated' }
                            26 { 'Replication Paused System Initiated' }
                            27 { 'Recovery StorageProfile Error' }
                            #28 {''} Does not exist in API documentation
                            29 { 'Rolling Back' }
                            30 { 'Recovery Storage Error' }
                            31 { 'Journal Storage Error' }
                            32 { 'Vm Not Protected Error' }
                            33 { 'Journal Or Recovery Missing Error' }
                            34 { 'Added Vms In Initial Sync' }
                            35 { 'Replication Paused For Missing Volume' }
                            default { 'Unknown' }
                        }
                        'Actual RPO' = Switch ($ProtectedVm.ActualRPO) {
                            -1 { 'RPO Not Calculated' }
                            default { "$($ProtectedVm.ActualRPO) seconds" }
                        }
                        'VM Hardware Version' = ($ProtectedVm.HardwareVersion).TrimStart('vmx-')
                        'File Level Recovery' = Switch ($ProtectedVm.EnabledActions.IsFlrEnabled){
                            $true { 'Enabled' }
                            $false { 'Disabled' }
                        }
                        'Provisioned Storage'  = "$([math]::Round($ProtectedVm.ProvisionedStorageInMB / 1024)) GB"
                        'Used Storage' = "$([math]::Round($ProtectedVm.UsedStorageInMB / 1024)) GB"
                        'Journal Used Storage' = "$([math]::Round($ProtectedVm.JournalUsedStorageMb / 1024)) GB"
                        #'Is Vm Exists' = $ProtectedVm.IsVmExists
                        #'Journal Hard Limit' = $ProtectedVm.JournalHardLimit
                        #'Journal Warning Threshold' = $ProtectedVm.JournalWarningThreshold
                        #'Last Test' = $ProtectedVm.LastTest
                        #'Organization Name' = $ProtectedVm.OrganizationName
                        #'IOPs' = $ProtectedVm.IOPs
                        #'Outgoing Bandwidth (Mbps)' = $ProtectedVm.OutgoingBandWidthInMbps
                        #'Throughput (MB)'           = $ProtectedVm.ThroughputInMB
                    }
                }
                # Check InfoLevels, if 2 show individual tables, else show a single summarised table
                if ($InfoLevel.VM -ge 2) {
                    $VmInfo | ForEach-Object {
                        $ProtectedVm = $_
                        Section -Style Heading3 $($ProtectedVm.'VM Name') {
                            $TableParams = @{
                                Name = "Protected VM $($ProtectedVm.'VM Name') - $ZVM"
                                List = $true
                                ColumnWidths = 50, 50
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $ProtectedVm | Table @TableParams
                        }
                    }
                } else {
                    $TableParams = @{
                        Name = "Protected VMs - $ZVM"
                        Columns = 'VM Name','Protected Site','Recovery Site','Priority','Protection Status','VPG Name'
                        ColumnWidths = 23, 13, 13, 14, 14, 23
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $VmInfo | Table @TableParams
                }
            }
        }
    }

    end {
    }

}