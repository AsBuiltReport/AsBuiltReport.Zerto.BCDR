function Get-AbrZertoLocalSite {
    <#
    .SYNOPSIS
    Used by As Built Report to retrieve Zerto ZVM local site information
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
        Write-PScriboMessage "Collecting ZVM local site information."
    }

    process {
        $LocalSite = Get-ZertoLocalSite
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
                        Columns = 'Site Name', 'Site Type', 'IP Address', 'Version'
                        ColumnWidths = 25, 25, 25, 25
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $LocalSiteInfo | Table @TableParams
                }

                # Throttling
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

                # Licensing
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
            }
        }
    }

    end {
    }
}