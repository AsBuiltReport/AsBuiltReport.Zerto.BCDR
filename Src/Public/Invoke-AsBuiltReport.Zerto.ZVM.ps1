function Invoke-AsBuiltReport.Zerto.ZVM {
    <#
    .SYNOPSIS  
        PowerShell script to document the configuration of Zerto infrastucture in Word/HTML/Text formats
    .DESCRIPTION
        Documents the configuration of Zerto infrastucture in Word/HTML/Text formats using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         Richard Gray / Tim Carman
        Twitter:        @goodgigs / @tpcarman
        Github:         richard-gray / tpcarman
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
        #region API Collections
        $LocalSite = Get-ZertoApi -Uri '/localsite'
        $PeerSites = Get-ZertoApi -Uri '/peersites'
        $VirtualizationSites = Get-ZertoApi -Uri '/virtualizationsites'
        $ServiceProfiles = Get-ZertoApi -Uri '/serviceprofiles'
        $VPGs = Get-ZertoApi -Uri '/vpgs'
        $VRAs = Get-ZertoApi -Uri '/vras'
        $VMs = Get-ZertoApi -Uri '/vms'
        $Volumes = Get-ZertoApi -Uri '/volumes'
        $Datastores = Get-ZertoApi -Uri '/datastores'
        $FLRs = Get-ZertoApi -Uri '/flrs'
        $License = Get-ZertoApi -Uri '/license'
        #endregion API Collections

        #region Lookups
        # Virtualization Hashtable Lookup, matches Site Id to Site Name
        $VirtualizationSiteLookup = @{}
        foreach ($VirtualizationSite in $VirtualizationSites) {
            # API Collection for VirtualizationSites
            # Check if site runs vCloud Director
            $Orgvdcs = Get-ZertoApi -Uri ('/virtualizationsites/' + $($VirtualizationSite.SiteIdentifier) + '/orgvdcs')
            # If not vCD, collect information for vCenter Server
            if (!$Orgvdcs) {
                $vSphereDatastores = Get-ZertoApi -Uri ('/virtualizationsites/' + $($VirtualizationSite.SiteIdentifier) + '/datastores')
                $vSphereDatastoreClusters = Get-ZertoApi -Uri ('/virtualizationsites/' + $($VirtualizationSite.SiteIdentifier) + '/datastoreclusters')
                $vSphereHosts = Get-ZertoApi -Uri ('/virtualizationsites/' + $($VirtualizationSite.SiteIdentifier) + '/hosts')
                $vSphereHostCluster = Get-ZertoApi -Uri ('/virtualizationsites/' + $($VirtualizationSite.SiteIdentifier) + '/hostclusters')
                $vSphereNetwork = Get-ZertoApi -Uri ('virtualizationsites/' + $($VirtualizationSite.SiteIdentifier) + '/networks')
            } else {
                $OrgvdcsNetworks = Get-ZertoApi -Uri ('/virtualizationsites/' + $($VirtualizationSite.SiteIdentifier) + '/orgvdcs/' + $Orgvdcs.Identifier + '/networks')
                $OrgvdcsStoragePolices = Get-ZertoApi -Uri ('/virtualizationsites/' + $($VirtualizationSite.SiteIdentifier) + '/orgvdcs/' + $Orgvdcs.Identifier + '/storagepolicies')
            }
            $VirtualMachines = Get-ZertoApi -Uri ('/virtualizationsites/' + $($VirtualizationSite.SiteIdentifier) + '/vms')

            # Site Hashtable Lookup, matches Site Id to Site Name
            $VirtualizationSiteLookup.($VirtualizationSite.SiteIdentifier) = $VirtualizationSite.VirtualizationSiteName
        }

        # VM Hashtable Lookup, matches VM Id to VM Name
        $VirtualMachineLookup = @{}
        foreach ($VirtualMachine in $VirtualMachines) {
            $VirtualMachineLookup.($VirtualMachine.VmIdentifier) = $VirtualMachine.VmName
        }

        # vSphere Host Hashtable Lookup, matches Host Id to Host Name
        $vSphereHostLookup = @{}
        foreach ($vSphereHost in $vSphereHosts) {
            $vSphereHostLookup.($vSphereHost.HostIdentifier) = $vSphereHost.VirtualizationHostName
        }
        #endregion Lookups

        #region ZVM Heading 1
        Section -Style Heading1 $ZVM {
            #region Local Site Information
            if ($LocalSite) {               
                Section -Style Heading2 'Local Site Information' {
                    $LocalSiteInfo = [PSCustomObject]@{
                        'Site Name' = $LocalSite.SiteName
                        'Site Type' = $LocalSite.SiteType
                        'IP Address' = $LocalSite.IpAddress
                        'Version' = $LocalSite.Version
                        'Replication To Self' = Switch ($LocalSite.IsReplicationToSelfEnabled) {
                            $true { 'Enabled' }
                            $false { 'Disabled' }
                        }
                        'UTC Offset' = "$($LocalSite.UtcOffsetInMinutes / 60) hours"
                        'Location' = $LocalSite.Location
                        'Contact Name' = $LocalSite.ContactName
                        'Contact Email' = $LocalSite.ContactEmail
                        'Contact Phone' = $LocalSite.ContactPhone
                    }
                    $TableParams = @{
                        Name = "Site Information - $ZVM"
                        List = $true
                        ColumnWidths = 50, 50
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $LocalSiteInfo | Table @TableParams

                    #region Throttling
                    Section -Style Heading3 'Throttling' {
                        $Throttling = [PSCustomObject]@{
                            'Bandwidth Throttling' = "$($LocalSite.BandwidthThrottlingInMBs) MB/sec"
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
                            $LicenseInfo = [PSCustomObject]@{
                                'License' = $License.Details.LicenseKey
                                'License Type' = $License.Details.LicenseType
                                'Expiry Date' = [datetime]$License.Details.ExpiryTime
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
                        $EmailConfig = [PSCustomObject]@{
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

            #region Sites
            if ($PeerSites) {
                Section -Style Heading2 'Sites' {
                    $PeerSiteInfo = foreach ($PeerSite in $PeerSites) {
                        [PSCustomObject]@{
                            'Site Name'= $Peersite.PeerSiteName
                            'Location' = $Peersite.Location
                            'Hostname / IP' = $Peersite.HostName
                            'Network' = $Peersite.OutgoingBandwidth
                            'Provisioned Storage' = $Peersite.ProvisionedStorage
                            'Used Storage' = $Peersite.UsedStorage
                            'Site Type' = $Peersite.SiteType
                            'Port' = $Peersite.Port
                            'Version' = $Peersite.Version
                        }
                    }
                    $TableParams = @{
                        Name = "Sites - $ZVM"
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $PeerSiteInfo | Table @TableParams
                }
            }
            #endregion Sites

            #region VRAs
            if (VRAs) {
                Section -Style Heading2 'VRAs' {
                    $VRAInfo = foreach ($VRA in $VRAs) {
                        [PSCustomObject] @{
                            'Host Address' = $vSphereHostLookup."$($VRA.HostIdentifier)"
                            'Host Version' = $VRA.HostVersion
                            'VRA Name' = $VRA.VraName
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
                            'Number of Protected VPGs' = $VRA.ProtectedCounters.VPGs
                            'Number of Recovery VMs' = $VRA.RecoveryCounters.VMs
                            'Number of Recovery Volumes' = $VRA.RecoveryCounters.Volumes
                            'Number of Recovery VPGs' = $VRA.RecoveryCounters.VPGs
                            <#
                            'Datastore Cluster Identifier' = $VRA.DatastoreClusterIdentifier
                            'Datastore Identifier' = $VRA.DatastoreIdentifier
                            'Link' = $VRA.Link
                            'Memory In GB' = $VRA.MemoryInGB
                            'Network Identifier' = $VRA.NetworkIdentifier
                            'Network Name' = $VRA.NetworkName
                            'Progress' = $VRA.Progress
                            'Self Protected Vpgs' = $VRA.SelfProtectedVpgs                           
                            'VRA Identifier' = $VRA.VraIdentifier
                            'IP Assignment' = $VRA.VraIPConfigurationTypeApi
                            #>
                        }
                    }
                    $TableParams = @{
                        Name = "VRAs - $ZVM"
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $VRAInfo | Table @TableParams
                }
            }
            #endregion VRAs

            #region Service Profiles
            if ($ServiceProfiles) {
                Section -Style Heading2 'Service Profiles' {
                    $ServiceProfileInfo = foreach ($ServiceProfile in $ServiceProfiles) {
                        [PSCustomObject]@{
                            "Service Profile" = $ServiceProfile.ServiceProfileName
                            "Description" = $ServiceProfile.Description
                            "History" = $ServiceProfile.History
                            "Journal Warning %" = $ServiceProfile.JournalWarningThresholdInPercent
                            "MaxJournalSizeInPercent" = $ServiceProfile.MaxJournalSizeInPercent
                            "RPO" = $ServiceProfile.Rpo
                            "Test Interval" = $ServiceProfile.TestInterval
                            
                        }
                    }
                    $TableParams = @{
                        Name = "Service Profiles - $ZVM"
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $ServiceProfileInfo | Table @TableParams
                }
            }
            #endregion Service Profiles

            #region VPGs
            if ($VPGs) {
                Section -Style Heading2 'VPGs' {
                    $VpgInfo = foreach ($VPG in $VPGs) {
                        $VPGVMs = @{}
                        $VPGVMs = Get-ZertoApi -Uri ('/vpgs/'+ $($VPG.VPGIdentifier) + '/checkpointvms')
                        [PSCustomObject]@{
                            'VPG Name' = $VPG.VpgName
                            'Protected Site Type' = Switch ($VPG.Entities.Protected) {
                                0 { 'VC' }
                                1 { 'vCD' }
                                2 { 'vCD' }
                                3 { 'N/A' }
                                4 { 'Hyper-V' }
                                default { 'Unknown' }
                            }
                            'Protected Site' = $VirtualizationSiteLookup."$($VPG.ProtectedSite.Identifier)"
                            'Recovery Site Type' = Switch ($VPG.Entities.Recovery) {
                                0 { 'VC' }
                                1 { 'vCD' }
                                2 { 'vCD' }
                                3 { 'N/A' }
                                4 { 'Hyper-V' }
                                default { 'Unknown' }
                            }
                            'Recovery Site' = $VirtualizationSiteLookup."$($VPG.RecoverySite.Identifier)"
                            'Peer Site' = $VPG.TargetSite
                            'Priority' = Switch ($VPG.Priority) {
                                0 { 'Low' }
                                1 { 'Medium' }
                                2 { 'High' }
                                default { 'Unknown' }
                            }
                            'Protection Status' = Switch ($VPG.Status) {
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
                            'SubStatus' = Switch ($VPG.SubStatus) {
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
                            'Target RPO ' = "$([math]::Round($VPG.ConfiguredRpoSeconds / 60 / 60)) hours"
                            'Actual RPO' = Switch ($VPG.ActualRPO) {
                                -1 { 'RPO Not Calculated' }
                                default { "$($VPG.ActualRPO) seconds" }
                            }
                            'Provisioned Storage'  = "$([math]::Round($VPG.ProvisionedStorageInMB / 1024)) GB"
                            'Used Storage' = "$([math]::Round($VPG.UsedStorageInMB / 1024)) GB"
                            'Number of VMs'             = $VPG.VmsCount
                            'Journal History' = "$([math]::Round($VPG.HistoryStatusApi.ConfiguredHistoryInMinutes / 60)) hours"
                            'VMs' = ($VPGVMs.VmName | Sort-Object) -join ', '
                            #'IOPs'                      = $VPG.IOPs
                            #'Last Test'                 = $VPG.LastTest
                            #'Organization Name'         = $VPG.OrganizationName
                            #'Progress' = "$($VPG.ProgressPercentage)%"
                            #'Service Profile ID' = $VPG.ServiceProfileIdentifier
                            #'Service Profile Name'      = $VPG.ServiceProfileName
                            #'Protection Site'           = $VPG.ProtectedSite.Identifier
                            #'Throughput In MB'          = $VPG.ThroughputInMB
                            #'Identifier'                = $VPG.VpgIdentifier
                            #'Zorg'                      = $VPG.Zorg.Identifier
                        }
                    }
                    $TableParams = @{
                        Name = "VPGs - $ZVM"
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $VpgInfo | Table @TableParams
                }
            }
            #endregion VPGs

            #region VMs
            if ($VMs) {
                Section -Style Heading2 'VMs' {
                    $VmInfo = foreach ($VM in $VMs) {
                        [PSCustomObject] @{
                            'VM Name' = $VM.VmName
                            'VPG Name' = $VM.VpgName
                            'Protected Site Type' = Switch ($VM.Entities.Protected) {
                                0 { 'VC' }
                                1 { 'vCD' }
                                2 { 'vCD' }
                                3 { 'N/A' }
                                4 { 'Hyper-V' }
                                default { 'Unknown' }
                            }
                            'Protected Site' = $VirtualizationSiteLookup."$($VM.ProtectedSite.Identifier)"
                            'Recovery Site Type' = Switch ($VM.Entities.Recovery) {
                                0 { 'VC' }
                                1 { 'vCD' }
                                2 { 'vCD' }
                                3 { 'N/A' }
                                4 { 'Hyper-V' }
                                default { 'Unknown' }
                            }
                            'Recovery Site' = $VirtualizationSiteLookup."$($VM.RecoverySite.Identifier)"
                            'Peer Site' = $VM.TargetSite
                            'Recovery Host' = $VM.RecoveryHostIdentifier # Needs a lookup of VM Hosts at recovery site
                            'Priority' = Switch ($VM.Priority) {
                                0 { 'Low' }
                                1 { 'Medium' }
                                2 { 'High' }
                                default { 'Unknown' }
                            }
                            'Protection Status' = Switch ($VM.Status) {
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
                            'Sub Status' = Switch ($VM.SubStatus) {
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
                            'Actual RPO' = Switch ($VM.ActualRPO) {
                                -1 { 'RPO Not Calculated' }
                                default { "$($VM.ActualRPO) seconds" }
                            }
                            'VM Hardware Version' = ($VM.HardwareVersion).TrimStart('vmx-')
                            'File Level Recovery' = Switch ($VM.EnabledActions.IsFlrEnabled){
                                $true { 'Enabled' }
                                $false { 'Disabled' }
                            }
                            'Provisioned Storage'  = "$([math]::Round($VM.ProvisionedStorageInMB / 1024)) GB"
                            'Used Storage' = "$([math]::Round($VM.UsedStorageInMB / 1024)) GB"
                            'IOPs' = $VM.IOPs

                            'Is Vm Exists' = $VM.IsVmExists
                            'Journal Hard Limit' = $VM.JournalHardLimit
                            'Journal Used Storage GB' = [math]::Round($VM.JournalUsedStorageMb / 1024)
                            'Journal Warning Threshold' = $VM.JournalWarningThreshold
                            'Last Test' = $VM.LastTest
                            'Organization Name' = $VM.OrganizationName
                            'Outgoing Bandwidth in Mbps' = $VM.OutgoingBandWidthInMbps
                            
                            'Throughput In MB'           = $VM.ThroughputInMB
                            'Used Storage In GB'         = [math]::Round($VM.UsedStorageInMB / 1024)
                            'Volumes'                    = $VM.Volumes
                        }
                    }
                    $TableParams = @{
                        Name = "VMs - $ZVM"
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $VmInfo | Table @TableParams
                }
            }
            #endregion VMs

            #region Datastores
            if ($Datastores) {
                Section -Style Heading2 'Datastores' {
                    $DatastoreInfo = foreach ($Datastore in $Datastores) {
                        [PSCustomObject]@{
                            'Datastore' = $Datastore.DatastoreName
                            'Status' = $Datastore.Health.Status
                            'Type' = $Datastore.Config.Type
                            'Devices' = ($Datastore.Config.Devices | Sort-Object) -join ', '
                            'Cluster' = Switch ($Datastore.Config.OwningDatastoreCluster) {
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
                    $TableParams = @{
                        Name = "Datastores - $ZVM"
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $DatastoreInfo | Table @TableParams
                }
            }
            #endregion Datastores

            #region Volumes
            if ($Volumes) {
                Section -Style Heading2 'Volumes' {
                    $VolumeInfo = foreach ($Volume in $Volumes) {
                        [PSCustomObject]@{
                            'Volume Type' = $Volume.VolumeType 
                            'Protected Volume Location' = $Volume.Path.Full
                            #'Recovery Volume Location' = ''
                            'VM' = $Volume.OwningVM.Name 
                            'Datastore' = $Volume.Datastore.Name
                            'Provisioned Storage' = $Volume.Size.ProvisionedInBytes
                            'Used Storage' = $Volume.Size.UsedInBytes
                            'Thin Provisioned' = Switch ($Volume.IsThinProvisioned) {
                                $true { 'Yes' }
                                $false { 'No' }
                            }
                            'VPG' = $Volume.VPG.Name
                        }
                    }
                    $TableParams = @{
                        Name = "Volumes - $ZVM"
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $VolumeInfo | Table @TableParams
                }
            }
            #endregion Volumes
        }
        #endregion ZVM Heading 1
    }
    #endregion foreach $ZVM in $Target
}