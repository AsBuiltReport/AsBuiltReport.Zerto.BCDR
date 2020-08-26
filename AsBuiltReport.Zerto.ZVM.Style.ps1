# Zerto Default Document Style

# Configure document options
DocumentOption -EnableSectionNumbering -PageSize A4 -DefaultFont 'Arial' -MarginLeftAndRight 71 -MarginTopAndBottom 71 -Orientation $Orientation

# Configure Heading and Font Styles
Style -Name 'Title' -Size 24 -Color 'BA0C25' -Align Center
Style -Name 'Title 2' -Size 18 -Color '1D2137' -Align Center
Style -Name 'Title 3' -Size 12 -Color '1D2137' -Align Left
Style -Name 'Heading 1' -Size 16 -Color 'BA0C25' 
Style -Name 'Heading 2' -Size 14 -Color 'BA0C25' 
Style -Name 'Heading 3' -Size 12 -Color 'BA0C25' 
Style -Name 'Heading 4' -Size 11 -Color 'BA0C25' 
Style -Name 'Heading 5' -Size 10 -Color 'BA0C25'
Style -Name 'Normal' -Size 10 -Color '565656' -Default
Style -Name 'Caption' -Size 10 -Color '565656' -Italic -Align Center
Style -Name 'Header' -Size 10 -Color '565656' -Align Center
Style -Name 'Footer' -Size 10 -Color '565656' -Align Center
Style -Name 'TOC' -Size 16 -Color 'BA0C25' 
Style -Name 'TableDefaultHeading' -Size 10 -Color 'FFFFFF' -BackgroundColor '1D2137'
Style -Name 'TableDefaultRow' -Size 10 -Color '565656'
Style -Name 'Critical' -Size 10 -BackgroundColor 'F74541'
Style -Name 'Warning' -Size 10 -BackgroundColor 'FFC822'
Style -Name 'Info' -Size 10 -BackgroundColor '2398F1'
Style -Name 'OK' -Size 10 -BackgroundColor '459E1E'

# Configure Table Styles
$TableDefaultProperties = @{
    Id = 'TableDefault'
    HeaderStyle = 'TableDefaultHeading'
    RowStyle = 'TableDefaultRow'
    BorderColor = '1D2137'
    Align = 'Left'
    CaptionStyle = 'Caption'
    CaptionLocation = 'Below' 
    BorderWidth = 0.25
    PaddingTop = 1
    PaddingBottom = 1.5
    PaddingLeft = 2
    PaddingRight = 2
}

TableStyle @TableDefaultProperties -Default
TableStyle -Id 'Borderless' -HeaderStyle Normal -RowStyle Normal -BorderWidth 0

# Zerto Cover Page Layout
# Header & Footer
if ($ReportConfig.Report.ShowHeaderFooter) {
    Header -Default {
        Paragraph -Style Header "$($ReportConfig.Report.Name) - v$($ReportConfig.Report.Version)"
    }

    Footer -Default {
        Paragraph -Style Footer 'Page <!# PageNumber #!>'
    }
}

# Set position of report titles and information based on page orientation
if (!($ReportConfig.Report.ShowCoverPageImage)) {
    $LineCount = 5
}
if ($Orientation -eq 'Portrait') {
    BlankLine -Count 11
    $LineCount = 32 + $LineCount
} else {
    BlankLine -Count 7
    $LineCount = 15 + $LineCount
}

# Zerto Logo Image
if ($ReportConfig.Report.ShowCoverPageImage) {
    Image -Text 'Zerto Logo' -Align 'Center' -Percent 35 -Base64 "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"
}

# Add Report Name
BlankLine -Count 2
Paragraph -Style Title $ReportConfig.Report.Name

if ($AsBuiltConfig.Company.FullName) {
    # Add Company Name if specified
    BlankLine -Count 2
    Paragraph -Style Title2 $AsBuiltConfig.Company.FullName
    BlankLine -Count $LineCount
} else {
    BlankLine -Count ($LineCount + 1)
}
Table -Name 'Cover Page' -List -Style Borderless -Width 0 -Hashtable ([Ordered] @{
        'Author:' = $AsBuiltConfig.Report.Author
        'Date:' = (Get-Date).ToLongDateString()
        'Version:' = $ReportConfig.Report.Version
    })
PageBreak

# Add Table of Contents
TOC -Name 'Table of Contents'
PageBreak