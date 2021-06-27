function Get-AbrZertoPeerSite {
    <#
    .SYNOPSIS
    Used by As Built Report to retrieve Zerto ZVM peer site information
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
        Write-PScriboMessage "Collecting ZVM peer site information."
    }

    process {
        $PeerSites = Get-ZertoPeerSite | Sort-Object PeerSiteName
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
    }

    end {
    }
}