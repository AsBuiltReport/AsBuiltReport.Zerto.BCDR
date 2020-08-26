function Get-ZertoApi {

    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [String] $Uri
    )

    Begin { 
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
    if ($ReportConfig.Options.ZvmPort) {
        $BaseUrl = "https://" + $ZVM + ":" + ($ReportConfig.Options.ZvmPort) + "/v1"
    } else {
        $BaseUrl = "https://" + $ZVM + ":9669/v1"
    }
    $xZertoSessionURL = $BaseUrl + "/session/add"
    $authInfo = ("{0}:{1}" -f $($Credential.UserName),$($Credential.GetNetworkCredential().Password))
    $authInfo = [System.Text.Encoding]::UTF8.GetBytes($authInfo)
    $authInfo = [System.Convert]::ToBase64String($authInfo)
    $headers = @{Authorization = ("Basic {0}" -f $authInfo) }
    $ContentType = "application/json"
    $sessionBody = '{"AuthenticationMethod": "1"}'
    $xZertoSessionResponse = Invoke-WebRequest -Uri $xZertoSessionURL -Headers $headers -Method POST -Body $sessionBody -ContentType $ContentType
    $xZertoSession = $xZertoSessionResponse.headers.get_item("x-zerto-session")
    $zertosessionHeader = @{"x-zerto-session" = $xZertoSession; "Accept" = "application/json"; "Content-Type" = "application/json" }
    }

    Process {
        Try {
            Invoke-RestMethod -Method GET -Uri ($BaseUrl + $Uri) -TimeoutSec 100 -Headers $zertosessionHeader -ContentType $ContentType
        } Catch {
            Write-Verbose -Message "An error occurred while processing the API request for $($BaseUrl + $Uri)"
            Write-Verbose -Message $_
        }
    }

    End { }
}