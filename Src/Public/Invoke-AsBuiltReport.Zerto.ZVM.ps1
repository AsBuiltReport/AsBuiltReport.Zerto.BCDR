function Invoke-AsBuiltReport.Zerto.ZVM {
    <#
    .SYNOPSIS
        PowerShell script to document the configuration of Zerto infrastucture in Word/HTML/Text formats
    .DESCRIPTION
        Documents the configuration of Zerto infrastucture in Word/HTML/Text formats using PScribo.
    .NOTES
        Version:        0.2.0
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
        Credits:        Iain Brighton (@iainbrighton) - PScribo module
                        Wes Carroll (@WesCarrollTech) - Zerto API Wrapper module
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Zerto.ZVM
    #>

    param (
        [String[]] $Target,
        [PSCredential] $Credential
    )

    # Check if the required version of Zerto API Wrapper is installed
    $RequiredVersion = '1.5.3'
    $RequiredModule = Get-Module -ListAvailable -Name 'ZertoApiWrapper' | Sort-Object -Property Version -Descending | Select-Object -First 1
    $ModuleVersion = "$($RequiredModule.Version.Major)" + "." + "$($RequiredModule.Version.Minor)"
    if ($null -eq $ModuleVersion)  {
        Write-Warning -Message "Zerto API Wrapper $RequiredVersion or higher is required to run the Zerto ZVM As Built Report. Run 'Install-Module -Name ZertoApiWrapper -MinimumVersion $RequiredVersion' to install the required modules."
        break
    }
    elseif ($ModuleVersion -lt $RequiredVersion) {
        Write-Warning -Message "Zerto API Wrapper $RequiredVersion or higher is required to run the Zerto ZVM As Built Report. Run 'Update-Module -Name ZertoApiWrapper -MinimumVersion $RequiredVersion' to update the module."
        break
    }

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
        Connect-ZertoServer -zertoServer $ZVM -credential $Credential -zertoPort $ZertoPort -ErrorAction Stop

        #region API Collections
        $LocalSite = Get-ZertoLocalSite
        $PeerSites = Get-ZertoPeerSite | Sort-Object PeerSiteName
        $VirtualizationSites = Get-ZertoVirtualizationSite | Sort-Object VirtualizationSiteName
        $VMHosts = Get-ZertoVirtualizationSite -siteIdentifier $($LocalSite.SiteIdentifier) -hosts
        $VirtualMachines = Get-ZertoVirtualizationSite -siteIdentifier $($LocalSite.SiteIdentifier) -vms

        <#
        $ServiceProfiles = Get-ZertoServiceProfile
        $Vpgs = Get-ZertoVpg | Sort-Object VpgName
        $Vras = Get-ZertoVra | Sort-Object VraName
        $ProtectedVms = Get-ZertoProtectedVm | Sort-Object VmName
        $Volumes = Get-ZertoVolume | Where-Object {$null -ne $_.VPG.Name} | Sort-Object -Property @{Expression = {$_.VPG.Name}},@{Expression = {$_.Path.Full}}
        #$Datastores = Get-ZertoDatastore | Sort-Object DatastoreName
        $License = Get-ZertoLicense
        $Datastores = Get-ZertoVirtualizationSite -siteIdentifier $($LocalSite.SiteIdentifier) -datastores | Sort-Object DatastoreName
        $DatastoreClusters = Get-ZertoVirtualizationSite -siteIdentifier $($LocalSite.SiteIdentifier) -datastoreClusters
        $HostClusters = Get-ZertoVirtualizationSite -siteIdentifier $($LocalSite.SiteIdentifier) -hostClusters
        $Networks = Get-ZertoVirtualizationSite -siteIdentifier $($LocalSite.SiteIdentifier) -networks
        #>
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
            # Site Dashboard
            Get-AbrZvmDashboard

            # Local Site Information
            Get-AbrZertoLocalSite

            # Peer Site Information
            Get-AbrZertoPeerSite

            # VRAs
            Get-AbrZertoVra

            # Service Profiles
            Get-AbrZertoServiceProfile

            # VPGs
            Get-AbrZertoVpg

            # Protected VMs
            Get-AbrZertoProtectedVM

            # Datastores
            Get-AbrZertoDatastore

            # Volumes
            Get-AbrZertoVolume
        }
        #endregion ZVM Heading 1
    }
    #endregion foreach $ZVM in $Target
}