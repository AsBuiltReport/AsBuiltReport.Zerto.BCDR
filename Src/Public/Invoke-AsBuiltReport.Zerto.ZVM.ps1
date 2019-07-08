function Invoke-AsBuiltReport.Zerto.ZVM {
    <#
.SYNOPSIS  
    PowerShell script to document the configuration of Zerto infrastucture in Word/HTML/XML/Text formats
.DESCRIPTION
    Documents the configuration of Zerto infrastucture in Word/HTML/XML/Text formats using PScribo.
.NOTES
    Version:        0.1
    Author:         Richard Gray
    Twitter:        @goodgigs
    Github:         richard-gray
    Credits:        Iain Brighton (@iainbrighton) - PScribo module
                    Jake Rutski (@jrutski) - VMware vSphere Documentation Script Concept
                    Tim Carman (@tpcarman) - Base implmentation
                    Joshua Stenhouse (joshuastenhouse@gmail.com) - Zerto Info Script
.LINK
    https://github.com/tpcarman/As-Built-Report
    https://github.com/iainbrighton/PScribo
#>

    #region Configuration Settings
    #---------------------------------------------------------------------------------------------#
    #                                    CONFIG SETTINGS                                          #
    #---------------------------------------------------------------------------------------------#

    param (
        [String[]] $Target,
        [PSCredential] $Credential,
        [String]$StylePath
    )

    # Import JSON Configuration for Options and InfoLevel
    $InfoLevel = $ReportConfig.InfoLevel
    $Options = $ReportConfig.Options

    # If custom style not set, use default style
    if (!$StylePath) {
        & "$PSScriptRoot\..\..\AsBuiltReport.Zerto.ZVM.Style.ps1"
    }
    
    ##################

    # Passed by the Parent, Check number of targets

    $script:ZertoServer = $Target 
    $script:ZertoUser = $Credential.UserName
    $script:ZertoPassword = $Credential.GetNetworkCredential().Password
    #endregion Configuration Settings

    #region Script Functions
    #---------------------------------------------------------------------------------------------#
    #                                    SCRIPT FUNCTIONS                                         #
    #---------------------------------------------------------------------------------------------#

    #endregion Script Functions

    #region Script Body
    #---------------------------------------------------------------------------------------------#
    #                                         SCRIPT BODY                                         #
    #---------------------------------------------------------------------------------------------#

    # Script Variables
    ##### Pull this out int report j


    #region Get Zerto data and create custom Powershell object 

    # Set Cert Policy
    add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate,WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

    # Setup API headers and login to zerto
    $script:baseURL = "https://" + $ZertoServer + ":" + ($Options.Port) + "/v1/"
    $script:baseURL = "https://" + $ZertoServer + ":9669/v1/"
    $xZertoSessionURL = $baseURL + "session/add"
    $authInfo = ("{0}:{1}" -f $ZertoUser, $ZertoPassword)
    $authInfo = [System.Text.Encoding]::UTF8.GetBytes($authInfo)
    $authInfo = [System.Convert]::ToBase64String($authInfo)
    $headers = @{Authorization = ("Basic {0}" -f $authInfo) }
    $sessionBody = '{"AuthenticationMethod": "1"}'
    $script:ContentType = "application/JSON"
    $xZertoSessionResponse = Invoke-WebRequest -Uri $xZertoSessionURL -Headers $headers -Method POST -Body $sessionBody -ContentType $ContentType
    $xZertoSession = $xZertoSessionResponse.headers.get_item("x-zerto-session")
    $script:zertosessionHeader = @{"x-zerto-session" = $xZertoSession; "Accept" = "application/JSON"; "Content-Type" = "application/JSON" }

    # Function for Zerto API GET queries 
    function get-zerto($url) {
        return Invoke-RestMethod -Uri ($BaseURL + $url)  -TimeoutSec 100 -Headers $zertosessionHeader -ContentType $ContentType -Method GET
    }

    # Setup Zerto Powershell Object
    $zerto = New-Object System.Object
    $zerto | Add-Member -Type NoteProperty -Name LocalSite -Value @()
    $zerto | Add-Member -Type NoteProperty -Name virtualizationsite -Value @()
    $zerto | Add-Member -Type NoteProperty -Name ServiceProfile -Value @()
    $zerto | Add-Member -Type NoteProperty -Name VPG -Value @()
    $zerto | Add-Member -Type NoteProperty -Name VRA -Value @()
    $zerto | Add-Member -Type NoteProperty -Name VM -Value @()

    # Get the localsite information
    $localsite = Get-zerto("localsite")
    $localsiteObject = New-Object PSObject -Property @{ 
        "Name"                           = $localsite.SiteName
        "Type"                           = $localsite.SiteType
        "UTC Offset (Hours)"             = ($localsite.UtcOffsetInMinutes / 60)
        "Address"                        = $localsite.Location
        "ZVM Ip Address"                 = $localsite.IpAddress
        "Contact Phone Number"           = $localsite.ContactPhone
        "Contact Name"                   = $localsite.ContactName
        "Contact Email Address"          = $localsite.ContactEmail
        "Zerto Version"                  = $localsite.Version
        "Is Replication To Self Enabled" = $localsite.IsReplicationToSelfEnabled
        "Identifier"                     = $localsite.SiteIdentifier
    }
    $zerto.localsite += $localsiteObject

    #Virtualizationsites information
    $virtualizationsites = Get-zerto("virtualizationsites") 
    $virtualizationsites | ForEach-Object {
        $virtualizationsitesObject = New-Object PSObject -Property @{
            "Identifier"  = $_.SiteIdentifier 
            "Description" = $_.VirtualizationSiteName
        }
        $zerto.virtualizationsite += $virtualizationsitesObject 
    }

    # Service Profile Information
    $ServiceProfile = Get-zerto("serviceprofiles")
    $ServiceProfile | ForEach-Object {
        $ServiceProfileObject = New-Object PSObject -Property @{
            "Identifier"              = $_.ServiceProfileIdentifier 
            "Name"                    = $_.ServiceProfileName
            "History"                 = $_.History
            "Journal Warning %"       = $_.JournalWarningThresholdInPercent
            "MaxJournalSizeInPercent" = $_.MaxJournalSizeInPercent
            "RPO"                     = $_.Rpo
            "Test Interval"           = $_.TestInterval
            "Description"             = $_.Description
        }
        $zerto.ServiceProfile += $ServiceProfileObject 
    }

    # VPG Information
    $VPGs = Get-zerto("vpgs")
    $VPGs | ForEach-Object {
        $VPGIdentifier = $_.VpgIdentifier
        $VPGsObject = New-Object PSObject -Property @{
            'Active Processes'          = $_.ActiveProcessesApi
            'Actual RPO'                = $_.ActualRPO
            'Backup Enabled'            = $_.BackupEnabled
            'Configured Rpo Hours'      = [math]::Round($_.ConfiguredRpoSeconds / 60 / 60)
            'Entities'                  = $_.Entities
            'Fail Safe History'         = $_.FailSafeHistory
            'History Status'            = $_.HistoryStatusApi
            'IOPs'                      = $_.IOPs
            'Last Test'                 = $_.LastTest
            'Link'                      = $_.Link
            'Organization Name'         = $_.OrganizationName
            'Priority'                  = $_.Priority
            'Progress Percentage'       = $_.ProgressPercentage
            'ProtectionSite'            = $_.ProtectedSite
            'Provisioned StorageIn GB'  = [math]::Round($_.ProvisionedStorageInMB / 1024)
            'RecoverySite'              = $_.RecoverySite
            'Service Profile'           = $_.ServiceProfile
            'Service ProfileIdentifier' = $_.ServiceProfileIdentifier
            'Service Profile Name'      = $_.ServiceProfileName
            'Protection Site'           = $_.SourceSite
            'Status'                    = $_.Status
            'SubStatus'                 = $_.SubStatus
            'Recovery Site'             = $_.TargetSite
            'Throughput In MB'          = $_.ThroughputInMB
            'UsedStorage In GB'         = [math]::Round($_.UsedStorageInMB / 1024)
            'Number of VMs'             = $_.VmsCount
            'Identifier'                = $_.VpgIdentifier
            'Name'                      = $_.VpgName
            'Zorg'                      = $_.Zorg
        }
        $zerto.VPG += $VPGsObject
        $VPGVMs = Get-zerto("vpgs/" + $VPGIdentifier + "/checkpointvms")
        $zerto.VPG | Where-Object { $_.Identifier -eq $VPGIdentifier } | Add-Member -Type NoteProperty -Name VM -Value @()
        $VPGVMs | ForEach-Object {
            $VPGVMsObject = New-Object PSObject -Property @{
                'Identifier' = $_.VmIdentifier
                'Name'       = $_.VmName
            }
            ($zerto.VPG | Where-Object { $_.Identifier -eq $VPGIdentifier }).VM += $VPGVMsObject
        }
        $CommaCount = 0; 
        $VMlist = ""
        $VPGVMs | Sort-object VMName | ForEach-Object {
            $VMlist += $_.VMName
            If ($CommaCount -lt $VPGVMs.count - 1) {
                $VMlist += ", " 
            }
            $CommaCount++
        }
        $zerto.VPG | Where-Object { $_.Identifier -eq $VPGIdentifier } | Add-Member -Type NoteProperty -Name "VM List" -Value $VMlist
    }

    # VRA Information
    $VRAs = Get-zerto("vras")
    $VRAs | ForEach-Object {
        $VRAsObject = New-Object PSObject -Property @{
            'Datastore Cluster Identifier' = $_.DatastoreClusterIdentifier
            'Datastore Cluster Name'       = $_.DatastoreClusterName
            'Datastore Identifier'         = $_.DatastoreIdentifier
            'Datastore Name'               = $_.DatastoreName
            'Host Identifier'              = $_.HostIdentifier
            'Host Version'                 = $_.HostVersion
            'Link'                         = $_.Link
            'Memory In GB'                 = $_.MemoryInGB
            'Network Identifier'           = $_.NetworkIdentifier
            'Network Name'                 = $_.NetworkName
            'Progress'                     = $_.Progress
            'Protected Counters'           = $_.ProtectedCounters
            'Number of VMs'                = $_.ProtectedCounters.VMs
            'Number of Volumes'            = $_.ProtectedCounters.volumes
            'Number of VPGs'               = $_.ProtectedCounters.VPGs
            'Recovery Counters'            = $_.RecoveryCounters
            'Self Protected Vpgs'          = $_.SelfProtectedVpgs
            'Status'                       = $_.Status
            'VRA Group'                    = $_.VraGroup
            'VRA Identifier'               = $_.VraIdentifier
            'Name'                         = $_.VraName
            'Default Gateway'              = $_.VraNetworkDataApi.DefaultGateway
            'Subnet Mask'                  = $_.VraNetworkDataApi.SubnetMask
            'IP Address'                   = $_.VraNetworkDataApi.VraIPAddress
            'IP Assignment'                = $_.VraIPConfigurationTypeApi
            'VRA Version'                  = $_.VraVersion
        }
        $zerto.VRA += $VRAsObject
    }

    # VM Information
    $VMs = Get-zerto("vms")
    $VMs | ForEach-Object {
        Switch ($_.Status) {
            0 { $status = "Initializing" }
            1 { $status = "Meeting SLA" }
            2 { $status = "Not Meeting SLA" }
            3 { $status = "RPO Not Meeting SLA" }
            4 { $status = "History Not Meeting SLA" }
            5 { $status = "Failing Over" }
            6 { $status = "Moving" }
            7 { $status = "Deleting" }
            8 { $status = "Recovered" }
            default { $status = "Unknown" }
        }
        Switch ($_.SubStatus) {
            0 { $SubStatus = "None" }
            1 { $SubStatus = "InitialSync" }
            2 { $SubStatus = "Creating" }
            3 { $SubStatus = "Volume Initial Sync" }
            4 { $SubStatus = "Sync" }
            5 { $SubStatus = "Recovery Possible" }
            6 { $SubStatus = "Delta Sync" }
            7 { $SubStatus = "Needs Configuration" }
            8 { $SubStatus = "Error" }
            9 { $SubStatus = "Empty Protection Group" }
            10 { $SubStatus = "Disconnected From Peer No Recovery Points" }
            11 { $SubStatus = "Full Sync" }
            12 { $SubStatus = "Volume Delta Sync" }
            13 { $SubStatus = "Volume Full Sync" }
            14 { $SubStatus = "Failing Over Committing" }
            15 { $SubStatus = "Failing Over Before Commit" }
            16 { $SubStatus = "Failing Over Rolling Back" }
            17 { $SubStatus = "Promoting" }
            18 { $SubStatus = "Moving Committing" }
            19 { $SubStatus = "Moving Before Commit" }
            20 { $SubStatus = "Moving Rolling Back" }
            21 { $SubStatus = "Deleting" }
            22 { $SubStatus = "Pending Remove" }
            23 { $SubStatus = "Bitmap Sync" }
            24 { $SubStatus = "Disconnected From Peer" }
            25 { $SubStatus = "Replication Paused User Initiated" }
            26 { $SubStatus = "Replication Paused System Initiated" }
            27 { $SubStatus = "Recovery StorageProfile Error" }
            #28{$SubStatus = ""} Does not exist in API documentation
            29 { $SubStatus = "Rolling Back" }
            30 { $SubStatus = "Recovery Storage Error" }
            31 { $SubStatus = "Journal Storage Error" }
            32 { $SubStatus = "Vm Not Protected Error" }
            33 { $SubStatus = "Journal Or Recovery Missing Error" }
            34 { $SubStatus = "Added Vms In Initial Sync" }
            35 { $SubStatus = "Replication Paused For Missing Volume" }
            default { $SubStatus = "Unknown" }
        }
        Switch ($_.Priority) {
            0 { $Priority = "Low" } 
            1 { $Priority = "Medium" } 
            2 { $Priority = "High" } 
            default { $Priority = "Unknown" }
        }
        $VMsObject = New-Object PSObject -Property @{
            'Actual RPO'                 = $_.ActualRPO
            'Enabled Actions'            = $_.EnabledActions
            'Entities'                   = $_.Entities
            'Hardware Version'           = $_.HardwareVersion
            'IOPs'                       = $_.IOPs
            'Is Vm Exists'               = $_.IsVmExists
            'Journal Hard Limit'         = $_.JournalHardLimit
            'Journal Used Storage GB'    = [math]::Round($_.JournalUsedStorageMb / 1024)
            'Journal Warning Threshold'  = $_.JournalWarningThreshold
            'Last Test'                  = $_.LastTest
            'Link'                       = $_.Link
            'Organization Name'          = $_.OrganizationName
            'Outgoing Bandwidth in Mbps' = $_.OutgoingBandWidthInMbps
            'PriorityID'                 = $_.Priority
            'Priority'                   = $Priority
            'Protected Site'             = $_.ProtectedSite
            'Provisioned Storage in GB'  = [math]::Round($_.ProvisionedStorageInMB / 1024)
            'Recovery Host Identifier'   = $_.RecoveryHostIdentifier
            'RecoverySite'               = $_.RecoverySite
            'Protection Site'            = $_.SourceSite
            'Status ID'                  = $_.Status
            'Status'                     = $status
            'Sub Status ID'              = $_.SubStatus
            'Sub Status'                 = $SubStatus
            'Recovery Site'              = $_.TargetSite
            'Throughput In MB'           = $_.ThroughputInMB
            'Used Storage In GB'         = [math]::Round($_.UsedStorageInMB / 1024)
            'Identifier'                 = $_.VmIdentifier
            'Name'                       = $_.VmName
            'Volumes'                    = $_.Volumes
            'VpgIdentifier'              = $_.VpgIdentifier
            'VPG Name'                   = $_.VpgName
        }
        $zerto.VM += $VMsObject   
    }

    # For each site
    $zerto.virtualizationsite | ForEach-Object {    
        # Get information on unprotected VMs
        $SiteIdentifier = $_.Identifier

        $unprotectedvm = Get-zerto("virtualizationsites/" + $SiteIdentifier + "/vms") 
        $zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier } | Add-Member -Type NoteProperty -Name UnprotectedVm -Value @()
        $unprotectedvm | ForEach-Object {
            $unprotectedVmObject = New-Object psobject -Property @{
                "Identifier" = $_.VmIdentifier   
                "Name"       = $_.VmName 
            }
            ($zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier }).UnprotectedVm += $unprotectedVmObject 
        }
        # Get platform specific information
        # Check if site runs vCD
        $Orgvdcs = Get-zerto("virtualizationsites/" + $SiteIdentifier + "/orgvdcs")
        if (!$Orgvdcs) {
            # This IS NOT a vCD Site
            # Get vSphere specific information

            # Tag this site as vSphere
            $zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier } | Add-Member -Type NoteProperty -Name Type -Value "vSphere"

            # vSphere Datastore Information
            $vSphereDatastore = Get-zerto("virtualizationsites/" + $SiteIdentifier + "/datastores")
            $zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier } | Add-Member -Type NoteProperty -Name Datastore -Value @() -Force
            $vSphereDatastore | ForEach-Object {
                $vSphereDatastoreObject = New-Object psobject -Property @{
                    "Identifier" = $_.DatastoreIdentifier   
                    "Name" = $_.DatastoreName 
                    "Datastore List" = $_.DatastoreName
                }
                ($zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier }).Datastore += $vSphereDatastoreObject 
            }
    
            # vSphere Datastore Cluster Information
            $vSphereDatastoreCluster = Get-zerto("virtualizationsites/" + $SiteIdentifier + "/datastoreclusters")
            $zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier } | Add-Member -Type NoteProperty -Name DatastoreCluster -Value @() -Force
            $vSphereDatastoreCluster | ForEach-Object {
                $vSphereDatastoreClusterObject = New-Object psobject -Property @{
                    "Identifier" = $_.DatastoreClusterIdentifier   
                    "Name"       = $_.DatastoreClusterName 
                }
                ($zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier }).DatastoreCluster += $vSphereDatastoreClusterObject 
            }

            # vSphere Host Information
            $vSphereHost = Get-zerto("virtualizationsites/" + $SiteIdentifier + "/hosts")
            $zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier } | Add-Member -Type NoteProperty -Name Host -Value @() -Force
            $vSphereHost | ForEach-Object {
                $vSphereHostObject = New-Object psobject -Property @{
                    "Identifier" = $_.HostIdentifier   
                    "Name"       = $_.VirtualizationHostName 
                }
                ($zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier }).Host += $vSphereHostObject 
            }

            # vSphere Host Cluster information
            $vSphereHostCluster = Get-zerto("virtualizationsites/" + $SiteIdentifier + "/hostclusters")
            $zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier } | Add-Member -Type NoteProperty -Name HostCluster -Value @() -Force
            $vSphereHostCluster | ForEach-Object {
                $vSphereHostClusterObject = New-Object psobject -Property @{
                    "Identifier" = $_.ClusterIdentifier   
                    "Name"       = $_.VirtualizationClusterName 
                }
                ($zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier }).HostCluster += $vSphereHostClusterObject 
            }

            # vSphere Network information
            $vSphereNetwork = Get-zerto("virtualizationsites/" + $SiteIdentifier + "/networks")
            $zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier } | Add-Member -Type NoteProperty -Name Network -Value @() -Force
            $vSphereNetwork | ForEach-Object {
                $vSphereNetworkObject = New-Object psobject -Property @{
                    "Identifier" = $_.NetworkIdentifier   
                    "Name" = $_.VirtualizationNetworkName
                    "Network List" = $_.VirtualizationNetworkName
                }
                ($zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier }).Network += $vSphereNetworkObject 
            }
            $CommaCount = 0; 
            $NetworkList = ""
            ($zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier }).Network | Sort-object Name -Unique | ForEach-Object {
                $NetworkList += $_.Name
                If ($CommaCount -lt ($zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier }).Network.count - 1) {
                    $NetworkList += ", " 
                }
                $CommaCount++
            }
            $zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier } | Add-Member -Type NoteProperty -Name "Network List" -Value $NetworkList

        }
        else {
            # This IS a vCD site
            # Get vCD specific information
        
            # Tag the site as vCD
            $zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier } | Add-Member -Type NoteProperty -Name Type -Value "vCloud Director"

            # vCD Network information
            $OrgvdcsNetworks = Get-zerto("virtualizationsites/" + $SiteIdentifier + "/orgvdcs/" + $Orgvdcs.Identifier + "/networks")
            $zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier } | Add-Member -Type NoteProperty -Name Network -Value @() -Force
            $OrgvdcsNetworks | ForEach-Object {
                $OrgvdcsNetworksObject = New-Object psobject -Property @{
                    "Identifier" = $_.NetworkIdentifier   
                    "Name"       = $_.VirtualizationNetworkName 
                }
                ($zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier }).Network += $OrgvdcsNetworksObject 
            }

            # vCD Storage Policy information
            $OrgvdcsStoragePolices = Get-zerto("virtualizationsites/" + $SiteIdentifier + "/orgvdcs/" + $Orgvdcs.Identifier + "/storagepolicies")
            $zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier } | Add-Member -Type NoteProperty -Name StoragePolicy -Value @() -Force
            $OrgvdcsStoragePolices | ForEach-Object {
                $OrgvdcsStoragePolicesObject = New-Object psobject -Property @{
                    "Identifier" = $_.StoragePolicyIdentifier   
                    "Name"       = $_.StoragePolicyName
                    "Enabled"    = $_.IsEnabled 
                }
                ($zerto.virtualizationsite | Where-Object { $_.Identifier -eq $SiteIdentifier }).StoragePolicy += $OrgvdcsStoragePolicesObject 
            }
        }

    }
    #endregion

    If ($InfoLevel.SiteDetails._Section) {
        Section -Style Heading1 "Site Details" { 
            If ($InfoLevel.SiteDetails.LocalSite) {
                Section -Style Heading2 "Local Site" { 
                    Section -Style Heading3 "Overview" { 
                        $zerto.localsite | Select-object Name, Address, "ZVM Ip Address", "Zerto Version", "UTC Offset (Hours)", Type | Table -Name "Local site"
                    }
                    If ($InfoLevel.SiteDetails.LocalSiteContacts) {
                        Section -Style Heading3 "Contacts" { 
                            $zerto.localsite | Select-object "Contact Phone Number", "Contact Name", "Contact Email Address" | Table -Name "Local site contacts"
                        }
                    }  
                    If ($InfoLevel.SiteDetails.LocalSiteNetworks) {
                        Section -Style Heading3 "Networks" { 
                            ($zerto.virtualizationsite | Where-Object { $_.Identifier -eq $zerto.localsite.identifier }).Network | Select-object "Network List" | Get-Unique | Sort-Object | Table -Name "Local site Networks"
                        }
                    }    
                    If ($InfoLevel.SiteDetails.LocalSiteDatastores) {
                        Section -Style Heading3 "Datastores" { 
                            ($zerto.virtualizationsite | Where-Object { $_.Identifier -eq $zerto.localsite.identifier }).Datastore | Select-object "Datastore List" | Get-Unique | Sort-Object | Table -Name "Local site Datastores"
                        }
                    }  
                }
            }
            If ($InfoLevel.SiteDetails.RemoteSites) {
                Section -Style Heading2 "Remote Sites" { 
                    $zerto.virtualizationsite | Where-Object { $_.Identifier -ne $zerto.localsite.identifier } | Select-object Description, Type | Table -Name "Remote site"
                }
            }
        }
    }   
    If ($InfoLevel.VRAs._Section) {
        Section -Style Heading1 'Virtual Replication Appliances' { 
            If ($InfoLevel.VRAs.Overview) {
                Section -Style Heading2 'Overview' { 
                    $zerto.VRA | Sort-Object Name | Select-Object Name, "VRA Group", "VRA Version", 'Number of VMs', 'Number of Volumes' , 'Number of VPGs' | Table -Name 'VRAs' 
                }
            }
            If ($InfoLevel.VRAs.Network) {
                Section -Style Heading2 'Network' { 
                    $zerto.VRA | Sort-Object Name | Select-Object Name, "IP Address", "Subnet Mask", "Default Gateway", "Network Name" | Table -Name 'VPGs Network'
                }
            }
            If ($InfoLevel.VRAs.Storage) {
                Section -Style Heading2 'Storage' { 
                    $zerto.VRA | Sort-Object Name | Select-Object Name, "Datastore Name", "Datastore Cluster Name" | Table -Name 'VPGs Storage'
                }
            }
        }
    }
    If ($InfoLevel.VPGs) {
        Section -Style Heading1 'Virtual Protection Groups' { 
            Section -Style Heading2 'Overview' { 
                $zerto.VPG | Sort-Object Name | Select-Object Name, "Protection Site", "Recovery Site", "Number of VMs", "Provisioned StorageIn GB" | Table -Name 'VPGs'
            }
        }
    }
    If ($InfoLevel.VMs._Section) {
        Section -Style Heading1 'Virtual Machines' { 
            If ($InfoLevel.VMs.VPGs) {
                Section -Style Heading2 'VPG' { 
                    $zerto.VM | Sort-Object Name | Select-Object Name, "VPG Name", "Protection Site", "Recovery Site", "Provisioned Storage In GB" | Table -Name "VMs VPG Information"
                }
            }
            If ($InfoLevel.VMs.Hardware) {
                Section -Style Heading2 'Hardware and Status' { 
                    $zerto.VM | Sort-Object Name | Select-Object Name, "Hardware Version", "Status", "Sub Status", "Throughput In MB" | Table -Name "VM Status"
                }
            }
            If ($InfoLevel.VMs.Network) {
                Section -Style Heading2 'Network' { 
                    $zerto.VM | Sort-Object Name | Select-Object Name, "Network ", "Protection Site", 'Recovery Site', 'Provisioned Storage In GB' | Table -Name 'VMs'
                }
            }
        }
    }
}