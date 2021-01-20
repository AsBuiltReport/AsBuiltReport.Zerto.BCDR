function Invoke-AsBuiltReport.Zerto.ZVM {
    <#
    .SYNOPSIS  
        PowerShell script to document the configuration of Zerto infrastucture in Word/HTML/Text formats
    .DESCRIPTION
        Documents the configuration of Zerto infrastucture in Word/HTML/Text formats using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         Tim Carman / Richard Gray
        Twitter:        @tpcarman / @goodgigs
        Github:         tpcarman / richard-gray
        Credits:        Iain Brighton (@iainbrighton) - PScribo module
                        Joshua Stenhouse (@joshuastenhouse) - Zerto Info Script
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Zerto.ZVM
    #>

    param (
        [String[]] $Target,
        [PSCredential] $Credential
    )

    # Import Report Configuration
    $Report = $ReportConfig.Report
    $InfoLevel = $ReportConfig.InfoLevel
    $Options = $ReportConfig.Options
    # Used to set values to TitleCase where required
    $TextInfo = (Get-Culture).TextInfo
    
    #region foreach $ZVM in $Target
    foreach ($ZVM in $Target) {
        if ($Options.ZvmPort) {
            $ZertoPort = $Options.ZvmPort
        } else {
            $ZertoPort = '9669'
        }
        Connect-ZertoServer -zertoServer $ZVM -Credential $Credential -ZertoPort $ZertoPort -ErrorAction Stop
        
        #region API Collections
        $LocalSite = Get-ZertoLocalSite
        $PeerSites = Get-ZertoPeerSite | Sort-Object PeerSiteName
        $VirtualizationSites = Get-ZertoVirtualizationSite | Sort-Object VirtualizationSiteName
        $ServiceProfiles = Get-ZertoServiceProfile
        $Vpgs = Get-ZertoVpg | Sort-Object VpgName
        $Vras = Get-ZertoVra | Sort-Object VraName
        $ProtectedVms = Get-ZertoProtectedVm | Sort-Object VmName
        $Volumes = Get-ZertoVolume | Where-Object {$null -ne $_.VPG.Name} | Sort-Object -Property @{Expression = {$_.VPG.Name}},@{Expression = {$_.Path.Full}}
        #$Datastores = Get-ZertoDatastore | Sort-Object DatastoreName
        $License = Get-ZertoLicense
        $Datastores = Get-ZertoVirtualizationSite -siteIdentifier $($LocalSite.SiteIdentifier) -datastores | Sort-Object DatastoreName
        $DatastoreClusters = Get-ZertoVirtualizationSite -siteIdentifier $($LocalSite.SiteIdentifier) -datastoreClusters
        $VMHosts = Get-ZertoVirtualizationSite -siteIdentifier $($LocalSite.SiteIdentifier) -hosts
        $HostClusters = Get-ZertoVirtualizationSite -siteIdentifier $($LocalSite.SiteIdentifier) -hostClusters
        $Networks = Get-ZertoVirtualizationSite -siteIdentifier $($LocalSite.SiteIdentifier) -networks
        $VirtualMachines = Get-ZertoVirtualizationSite -siteIdentifier $($LocalSite.SiteIdentifier) -vms
        #endregion API Collections

        #region Lookups
        # Virtualization Hashtable Lookup, matches Site Id to Site Name
        $VirtualizationSiteLookup = @{}
        foreach ($VirtualizationSite in $VirtualizationSites) {
            $VirtualizationSiteLookup.($VirtualizationSite.SiteIdentifier) = $VirtualizationSite.VirtualizationSiteName
        }

        # VM Hashtable Lookup, matches VM Id to VM Name
        $VirtualMachineLookup = @{}
        foreach ($VirtualMachine in $VirtualMachines) {
            $VirtualMachineLookup.($VirtualMachine.VmIdentifier) = $VirtualMachine.VmName
        }

        # Peer Site Hashtable Lookup, matches Peer Site ID to Peer Site Name
        $PeerSiteLookup = @{}
        foreach ($PeerSite in $PeerSites) {
            $PeerSiteLookup.($PeerSite.SiteIdentifier) = $PeerSite.PeerSiteName
        }
        # VM Host Hashtable Lookup, matches Host Id to Host Name
        $VMHostLookup = @{}
        foreach ($VMHost in $VMHosts) {
            $VMHostLookup.($VMHost.HostIdentifier) = $VMHost.VirtualizationHostName
        }
        #endregion Lookups

        #region ZVM Heading 1
        Section -Style Heading1 $ZVM {
            #region Site Dashboard
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
            #endregion Site Dashboard

            #region Local Site Information
            if (($LocalSite) -and ($InfoLevel.LocalSite -gt 0)) {               
                Section -Style Heading2 'Local Site' {
                    # Collect Local Site information
                    $LocalSiteInfo = [PSCustomObject] @{
                        'Site Name' = $LocalSite.SiteName
                        'Site ID' = $LocalSite.SiteIdentifier
                        'Location' = $LocalSite.Location
                        'Site Type' = $LocalSite.SiteType
                        'IP Address' = $LocalSite.IpAddress
                        'Version' = $LocalSite.Version
                        'Replication To Self' = Switch ($LocalSite.IsReplicationToSelfEnabled) {
                            $true { 'Enabled' }
                            $false { 'Disabled' }
                        }
                        'UTC Offset' = "$($LocalSite.UtcOffsetInMinutes / 60) hours"
                        'Contact Name' = $LocalSite.ContactName
                        'Contact Email' = $LocalSite.ContactEmail
                        'Contact Phone' = $LocalSite.ContactPhone
                    }
                    # Check InfoLevels, if 2 show individual tables, else show a single summarised table
                    if ($InfoLevel.LocalSite -ge 2) {
                        $TableParams = @{
                            Name = "Local Site - $ZVM"
                            List = $true
                            ColumnWidths = 50, 50
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $LocalSiteInfo | Table @TableParams
                    } else {
                        $TableParams = @{
                            Name = "Local Site - $ZVM"
                            Columns = 'Site Name','Site Type','IP Address','Version'
                            ColumnWidths = 25, 25, 25, 25
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $LocalSiteInfo | Table @TableParams
                    }

                    #region Throttling
                    Section -Style Heading3 'Throttling' {
                        $Throttling = [PSCustomObject] @{
                            'Bandwidth Throttling' = Switch ($LocalSite.BandwidthThrottlingInMBs) {
                                -1 { 'Disabled' }
                                default { "$($LocalSite.BandwidthThrottlingInMBs) MB/sec" }
                            }
                        }
                        $TableParams = @{
                            Name = "Throttling - $ZVM"
                            List = $true
                            ColumnWidths = 50, 50
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $Throttling | Table @TableParams
                    }
                    #endregion Throttling

                    #region Licensing
                    if ($License) {
                        Section -Style Heading3 'Licensing' {
                            $LicenseInfo = [PSCustomObject] @{
                                'License' = Switch ($Options.ShowLicense) {
                                    $true { $License.Details.LicenseKey }
                                    $false { 'License key not displayed' }
                                    $null { 'License key not displayed' }
                                }
                                'License Type' = $License.Details.LicenseType
                                'Expiry Date' = Switch ($License.Details.ExpiryTime) {
                                    $null { 'N/A' }
                                    default { [datetime]$License.Details.ExpiryTime }
                                }
                                'Quantity' = $License.Details.MaxVms
                                'Total VMs Count' = $License.Usage.TotalVmsCount
                            }
                            $TableParams = @{
                                Name = "Licensing - $ZVM"
                                List = $true
                                ColumnWidths = 50, 50
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $LicenseInfo | Table @TableParams
                        }
                    }
                    #endregion Licensing

                    <#
                    #region Policies
                    Section -Style Heading3 'Policies' {
                    }
                    #endregion Policies

                    #region Email Settings
                    Section -Style Heading3 'Email Settings' {
                        $EmailConfig = [PSCustomObject] @{
                            'SMTP Server Address' = ''
                            'SMTP Server Port' = ''
                            'Sender Account' = ''
                            'To' = ''
                        }
                        $TableParams = @{
                            Name = "Email Settings - $ZVM"
                            List = $true
                            ColumnWidths = 50, 50
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $EmailConfig | Table @TableParams
                    }
                    #endregion Email Settings

                    #region Reports
                    Section -Style Heading3 'Reports' {
                    }
                    #endregion Reports

                    #region Cloud Settings
                    Section -Style Heading3 'Cloud Settings' {
                    }
                    #endregion Cloud Settings

                    #region LTR Settings
                    Section -Style Heading3 'LTR Settings' {
                    }
                    #endregion LTR Settings
                    #>
                } 
            }
            #endregion Local Site Information

            #region Peer Site Information
            if (($PeerSites) -and ($InfoLevel.PeerSite -gt 0)) {
                Section -Style Heading2 'Peer Sites' {
                    # Collect Peer Site information
                    $PeerSiteInfo = foreach ($PeerSite in $PeerSites) {
                        [PSCustomObject] @{
                            'Site Name'= $Peersite.PeerSiteName
                            'Site ID' = $PeerSite.SiteIdentifier 
                            'Location' = $Peersite.Location
                            'Site Type' = $Peersite.SiteType
                            'Hostname / IP' = $Peersite.HostName
                            'Port' = $Peersite.Port
                            'Version' = $Peersite.Version
                            'Provisioned Storage' = "$([math]::Round($Peersite.ProvisionedStorage / 1024 / 1024)) TB"
                            'Used Storage' = "$([math]::Round($Peersite.UsedStorage / 1024 / 1024)) TB"
                        }
                    }
                    # Check InfoLevels, if 2 show individual tables, else show a single summarised table
                    if ($InfoLevel.PeerSite -ge 2) {
                        $PeerSiteInfo | ForEach-Object {
                            $PeerSite = $_
                            Section -Style Heading3 $($PeerSite.'Site Name') {    
                                $TableParams = @{
                                    Name = "Peer Site $($PeerSite.'Site Name') - $ZVM"
                                    List = $true
                                    ColumnWidths = 50, 50
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $PeerSite | Table @TableParams
                            }
                        }
                    } else {
                        $TableParams = @{
                            Name = "Peer Sites - $ZVM"
                            Columns = 'Site Name','Location','Hostname / IP','Site Type','Version'
                            ColumnWidths = 25, 25, 20, 15, 15
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $PeerSiteInfo | Table @TableParams
                    }
                }
            }
            #endregion Peer Site Information

            #region VRAs
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
            #endregion VRAs

            #region Service Profiles
            if (($ServiceProfiles) -and ($InfoLevel.ServiceProfile -gt 0)) {
                Section -Style Heading2 'Service Profiles' {
                    # Collect Service Profile information
                    $ServiceProfileInfo = foreach ($ServiceProfile in $ServiceProfiles) {
                        [PSCustomObject] @{
                            'Service Profile' = $ServiceProfile.ServiceProfileName
                            'Description' = $ServiceProfile.Description
                            'History' = $ServiceProfile.History
                            'Journal Warning %' = $ServiceProfile.JournalWarningThresholdInPercent
                            'MaxJournalSizeInPercent' = $ServiceProfile.MaxJournalSizeInPercent
                            'RPO' = $ServiceProfile.Rpo
                            'Test Interval' = $ServiceProfile.TestInterval
                        }
                    }
                    # Check InfoLevels, if 2 show individual tables, else show a single summarised table
                    if ($InfoLevel.ServiceProfile -ge 2) {
                        $ServiceProfileInfo | ForEach-Object {
                            $ServiceProfile = $_
                            Section -Style Heading3 $($ServiceProfile.'Service Profile') {    
                                $TableParams = @{
                                    Name = "Service Profile $($ServiceProfile.'Service Profile') - $ZVM"
                                    List = $true
                                    ColumnWidths = 50, 50
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $ServiceProfile | Table @TableParams
                            }
                        }
                    } else {
                        $TableParams = @{
                            Name = "Service Profiles - $ZVM"
                            Columns = 'Service Profile','Description','RPO','Test Interval'
                            ColumnWidths = 30, 40, 15, 15
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $ServiceProfileInfo | Table @TableParams
                    }
                }
            }
            #endregion Service Profiles

            #region VPGs
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
            #endregion VPGs

            #region VMs
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
            #endregion VMs

            #region Datastores
            if (($Datastores) -and ($InfoLevel.Datastore -gt 0)) {
                Section -Style Heading2 'Datastores' {
                    # Collect Datastore information
                    $DatastoreInfo = foreach ($Datastore in $Datastores) {
                        $Datastore = Get-ZertoDatastore -datastoreIdentifier $Datastore.DatastoreIdentifier
                        [PSCustomObject] @{
                            'Datastore' = $Datastore.DatastoreName
                            'Datastore ID' = $Datastore.DatastoreIdentifier
                            'Status' = $Datastore.Health.Status
                            'Type' = $Datastore.Config.Type
                            'Devices' = ($Datastore.Config.Devices | Sort-Object) -join ', '
                            'Datastore Cluster' = Switch ($Datastore.Config.OwningDatastoreCluster) {
                                $null { '--' }
                                default { $Datastore.Config.OwningDatastoreCluster }
                            }
                            'Number of Protected VMs' = $Datastore.Stats.NumOutgoingVMs
                            'Number of Incoming VMs' = $Datastore.Stats.NumIncomingVMs
                            'Number of VRAs' = $Datastore.Stats.NumVRAs
                            #'Recovery Size' = ''
                            #'Journal Size' = ''
                        }
                    }
                    # Check InfoLevels, if 2 show individual tables, else show a single summarised table
                    if ($InfoLevel.Datastore -ge 2) {
                        $DatastoreInfo | ForEach-Object {
                            $Datastore = $_
                            Section -Style Heading3 $($Datastore.'Datastore') { 
                                $TableParams = @{
                                    Name = "Datastore $($Datastore.'Datastore') - $ZVM"
                                    List = $true
                                    ColumnWidths = 50, 50
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $Datastore | Table @TableParams
                            }
                        }
                    } else {
                        $TableParams = @{
                            Name = "Datastores - $ZVM"
                            Columns = 'Datastore','Status','Type','Datastore Cluster','Number of Protected VMs','Number of VRAs'
                            Headers = 'Datastore','Status','Type','Datastore Cluster','# Protected VMs','# VRAs'
                            ColumnWidths = 24, 13, 13, 24, 13, 13
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $DatastoreInfo | Table @TableParams
                    }
                }
            }
            #endregion Datastores

            #region Volumes
            ## TODO: VM Volume Settings - VolumeIsSWAP
            if (($Volumes) -and ($InfoLevel.Volume -gt 0)) {
                Section -Style Heading2 'Volumes' {
                    # Collect Volume information
                    $VolumeInfo = foreach ($Volume in $Volumes) {
                        [PSCustomObject] @{
                            'VM' = $Volume.OwningVM.Name
                            'Datastore' = $Volume.Datastore.Name
                            'Protected Volume Location' = $Volume.Path.Full
                            #'Recovery Volume Location' = ''
                            'Provisioned Storage' = "$([math]::Round($Volume.Size.ProvisionedInBytes / 1GB)) GB"
                            'Provisioned Storage (GB)' = [math]::Round($Volume.Size.ProvisionedInBytes / 1GB)
                            'Used Storage' = "$([math]::Round($Volume.Size.UsedInBytes / 1GB)) GB"
                            'Thin Provisioned' = Switch ($Volume.IsThinProvisioned) {
                                $true { 'Yes' }
                                $false { 'No' }
                            }
                            'Volume Type' = $Volume.VolumeType 
                            'VPG' = $Volume.Vpg.Name
                        }
                    }
                    # Check InfoLevels, if 2 show individual tables, else show a single summarised table
                    if ($InfoLevel.Volume -ge 2) {
                        $VolumeInfo | ForEach-Object {
                            $Volume = $_
                            Section -Style Heading3 $($Volume.'Datastore') { 
                                $TableParams = @{
                                    Name = "Volume $($Volume.'Datastore') - $ZVM"
                                    List = $true
                                    Columns = 'VM','Datastore','Volume Type','Protected Volume Location','Provisioned Storage','Used Storage','Thin Provisioned','VPG'
                                    ColumnWidths = 50, 50
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $Volume | Table @TableParams
                            }
                        }
                    } else {
                        $TableParams = @{
                            Name = "Volumes - $ZVM"
                            Columns = 'VM','Datastore','Volume Type','Provisioned Storage (GB)','Thin Provisioned','VPG'
                            Headers = 'VM','Datastore','Volume Type','Provisioned (GB)','Thin','VPG'
                            ColumnWidths = 20, 20, 14, 14, 12, 20
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $VolumeInfo | Table @TableParams
                    }
                }
            }
            #endregion Volumes
        }
        #endregion ZVM Heading 1
    }
    #endregion foreach $ZVM in $Target
}