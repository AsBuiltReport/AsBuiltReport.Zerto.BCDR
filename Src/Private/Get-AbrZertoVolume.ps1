function Get-AbrZertoVolume {
    <#
    .SYNOPSIS
    Used by As Built Report to retrieve Zerto ZVM volume information
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
        Write-PScriboMessage "Collecting ZVM volume information."
    }

    process {
        $Volumes = Get-ZertoVolume | Where-Object {$null -ne $_.VPG.Name} | Sort-Object -Property @{Expression = {$_.VPG.Name}},@{Expression = {$_.Path.Full}}
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
    }

    end {
    }

}