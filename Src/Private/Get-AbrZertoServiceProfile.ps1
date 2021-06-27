function Get-AbrZertoServiceProfile {
    <#
    .SYNOPSIS
    Used by As Built Report to retrieve Zerto ZVM service profile information
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
        Write-PScriboMessage "Collecting ZVM service profile information."
    }

    process {
        $ServiceProfiles = Get-ZertoServiceProfile
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
    }

    end {
    }
}