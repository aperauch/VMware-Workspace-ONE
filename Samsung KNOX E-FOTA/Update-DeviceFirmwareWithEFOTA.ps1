
<#
.SYNOPSIS
    Performs a device firmware update using the Samsung KNOX E-FOTA API against a list of device serial numbers.

.DESCRIPTION
    The script requires an .ini file containing all the necessary script parameters such as the list of device serial numbers to update.
    The script removes any serial numbers that are not registered or enrolled in E-FOTA, and then issues a firmware update command to
    update the devices to the specified target firmware version.  If the .ini file does not contain the E-FOTA client secret, then this
    value must be passed as a parameter to the script (see first example).

.EXAMPLE
    PS C:\> Update-DeviceFirmwareWithEFOTA.ps1 -IniFile "C:\path\to\file.ini" -EfotaClientSecret 123456-abcdef-7890-ghijk
    Example of running the script with the required.ini file and providing the E-FOTA client secret.

.EXAMPLE
    PS C:\> Update-DeviceFirmwareWithEFOTA.ps1 -IniFile "C:\path\to\file.ini"
    Example of running the script with a specified file that contains a list of device serial numbers to target for a firmware update.

.EXAMPLE
    PS C:\> Update-DeviceFirmwareWithEFOTA.ps1 -IniFile "C:\path\to\file.ini" -Verbose
    Example of running the script with verbose logging which can be helpful for troubleshooting and debugging.

.PARAMETER IniFile
    Required text file containing all of the necessary script parameter values.

.PARAMETER EfotaClientSecret
    The account client secret used for authentication to the E-FOTA API to obtain an OAuth 2.0 access token.  The client secret can be provided with this parameter or through the .ini file.

.OUTPUTS
    Outputs a log file called "Update-DeviceFirmwareWithEFOTA_Log.txt" in the working directory where the script is executed from.
    The log file can be used for troubleshooting the script.

.LINK
    Troubleshooting Samsung KNOX E-FOTA guide:  https://docs.samsungknox.com/dev/knox-e-fota/error-codes.htm

    GitHub Repo:  https://github.com/aperauch/VMware-Workspace-ONE

.NOTES
    Author: Aron Aperauch
#>



[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [string] $IniFile,
    [string] $EfotaClientSecret
)

Function Write-Log {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string] $Output,
        [ValidateSEt("INFO", "WARN", "ERROR", "DEBUG", "VERBOSE")]
        [string] $Level = "INFO",
        [bool] $Overwrite,
        [string] $File = "Update-DeviceFirmware_Log.txt",
        [bool] $NoNewLine
    )

    if ($Overwrite) {
        Out-File $File -Force
    }

    [string] $msg = "$(Get-Date -UFormat '%F %T') [$Level]:  $Output"
    if ($NoNewLine) {
        Add-Content -Path $File -Value $msg -NoNewline
    }
    else {
        Add-Content -Path $File -Value $msg
    }

    switch ($Level) {
        "WARN" { Write-Host $msg -ForegroundColor Yellow; Break }
        "ERROR" { Write-Host $msg -ForegroundColor Red; Exit }
        "DEBUG" { Write-Debug $msg; Break }
        "VERBOSE" { Write-Verbose $msg; Break }
        Default { Write-Host $msg }
    }
}

Function Get-IniFile {
    Param (
        [parameter(Mandatory = $true)]
        [string] $File
    )

    $anonymous = "NoSection"
    $sectionRegEx = "^\[(.+)\]$"
    $commentRegEx = "^(;.*)$"
    $keyRegEx = "(.+?)\s*=\s*(.*)"

    $ini = @{ }
    switch -regex -file $File {

        $sectionRegEx {
            $section = $matches[1]
            $ini[$section] = @{ }
            $CommentCount = 0
        }

        $commentRegEx {
            if (!($section)) {
                $section = $anonymous
                $ini[$section] = @{ }
            }
            $value = $matches[1]
            $CommentCount = $CommentCount + 1
            $name = "Comment" + $CommentCount
            $ini[$section][$name] = $value
        }

        $keyRegEx {
            if (!($section)) {
                $section = $anonymous
                $ini[$section] = @{ }
            }
            $name, $value = $matches[1..2]
            $ini[$section][$name] = $value
        }
    }

    return $ini
}

Function Get-DeviceSerialNumbersFromFile {
    Param (
        [Parameter(Mandatory = $true)]
        [string] $File
    )

    if (Test-Path $File) {
        [string[]] $serialNumberArray = Get-Content $File
        
        if ($serialNumberArray.Count -eq 0) {
            Write-Log "No serial numbers were found in file $File." -Level ERROR
        }
        elseif ($serialNumberArray.Count -ge 1) {
            Write-Log "Found $($serialNumberArray.Count) serial number(s) in file $File."
        }
        else {
            Write-Log "An error occurred when getting the serial numbers from file $File." -Level ERROR
        }

        return $serialNumberArray
    }
    else {
        Write-Log "Unable to find file $File.  Exiting script." -Level ERROR
    }
}

Function Format-SerialNumbersAsXml {
    Param (
        [Parameter(Mandatory = $true)]
        [string[]] $SerialNumberArray
    )

    [string] $xmlStr = $null
    foreach ($sn in $SerialNumberArray) {
        $xmlStr += "<serialNumber>$sn</serialNumber>"
    }

    return $xmlStr
}

Function Format-XML {
    Param (
        [Parameter(Mandatory = $true)]
        [xml] $Xml,
        [int] $Indent = 4
    )

    $StringWriter = New-Object System.IO.StringWriter
    $XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter
    $xmlWriter.Formatting = "indented"
    $xmlWriter.Indentation = $Indent
    $xml.WriteContentTo($XmlWriter)
    $XmlWriter.Flush()
    $StringWriter.Flush()

    return $StringWriter.ToString()
}

Function Compare-DevicesLists {
    Param (
        [xml] $AbnormalDevicesXML,
        [string[]] $TargetedSNs
    )

    $abnormalCategory = $AbnormalDevicesXML.B2bAbnormalDeviceListVO.abnormalCategoryList.abnormalCategoryItem.abnormalCategoryTitle
    $abnormalDevices = $AbnormalDevicesXML.B2bAbnormalDeviceListVO.abnormalCategoryList.abnormalCategoryItem.abnormalDeviceList.serialNumber

    if ($snArray.Count -gt 0 -and $abnormalDevices.Count -gt 0) {
        Write-Log "The following $($abnormalDevices.Count) devices are marked as $abnormalCategory in E-FOTA:  $($abnormalDevices -join ", ")" -Level WARN

        $diff = Compare-Object -ReferenceObject $snArray -DifferenceObject $abnormalDevices

        if ($diff.InputObject.Count -eq 0) {
            Write-Log "There are no devices in the file $DeviceToUpdateFile that are enrolled in E-FOTA.  Devices must be registered with E-FOTA before a firmware update can be forced.`nExiting script." -Level ERROR
        }
        elseif ($diff.InputObject.Count -eq 1) { 
            Write-Log "Device with serial number $($diff.InputObject) will be targeted for firmware update."
        }
        elseif ($diff.InputObject.Count -ge 2) {
            Write-Log "The following $($diff.InputObject.Count) devices will be updated to firmware version ($efotaTargetFirmware): $($diff.InputObject -join ', ')" -Level WARN
        }
        else {
            Write-Log "There was an error getting the difference of targeted devices and abnormal devices.  Exiting script." -Level ERROR
        }

        return $diff.InputObject
    }
    return $TargetedSNs
}

Function Debug-ExceptionMessage {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        $ErrorObject
    )

    Begin {
        [string] $msg = "An error occurred.  Please see the API call details below.
                        `n`tHTTP Status Code: {0}
                        `n`tHTTP Status: {1}
                        `n`tHTTP Status Description: {2}
                        `n`tError Message: {3} `n" -f $ErrorObject.Exception.Response.StatusCode.value__, $ErrorObject.Exception.Response.StatusCode, $ErrorObject.Exception.Response.StatusDescription, $ErrorObject.ErrorDetails.Message

        [string] $unknownErrorMsg = "An unexpected error occurred.  The error has been saved to a variable called `$help.  Enter `$help in a PowerShell window to see more about the error details.  Re-run the script with the -Verbose option to see more output for troubleshooting."
    }

    Process {
        if ($ErrorObject.Exception.Response.StatusCode.value__ -eq 407) {
            $msg += "RECOMMENDATION: Determine if proxy is required.  If required, determine if proxy $Proxy is reachable by this server and if credentials used to authenticate to the proxy are correct."
        }
        elseif ($ErrorObject.ErrorDetails.Message) {
            if ($ErrorObject.ErrorDetails.Message.StartsWith("{") -and $ErrorObject.ErrorDetails.Message.EndsWith("}")) {

                $jsonObj = $ErrorObject.ErrorDetails.Message | ConvertFrom-Json -ErrorAction Stop

                if ($jsonObj.error -ieq "invalid_request") {
                    $msg += "RECOMMENDATION: Unable to authenticate to the E-FOTA API OaAth 2.0 access token due to $($jsonObj.error) '$($jsonObj.error_description)'.  Ensure the OAuth 2.0 access token is valid and has not expired."
                }
                elseif ($jsonObj.error -ieq "invalid_client") {
                    $msg += "RECOMMENDATION: Unable to get E-FOTA API OaAth 2.0 access token due to $($jsonObj.error) error.  Ensure the Client ID '$ClientID' and client secret used for authentication to the E-FOTA API is correct."
                }
                elseif ($jsonObj.error_description -ieq "Missing grant_type") {
                    # POST body or Content-type is wrong
                    $msg += "RECOMMENDATION: The E-FOTA API was able to read or parse the HTTP body contents properly.  Ensure the HTTP body and content-type are correct."
                }
                elseif ($jsonObj.error_description -ieq "Missing access token") {
                    # uri is wrong
                    $msg += "RECOMMENDATION: Ensure the E-FOTA API URL is correct."
                }
                else {
                    $msg += $unknownErrorMsg
                }
            }
            elseif ($ErrorObject.ErrorDetails.Message -imatch "Policy Falsified") {
                # no json was return; ensure uri is correct
                $msg += "RECOMMENDATION: The E-FOTA API response body is empty.  Ensure the E-FOTA PI URL is correct."
            }
            elseif ($ErrorObject.ErrorDetails.Message -imatch "FUD_[0-9]+") {
                # received a documented Samsung KNOX ERROR
                $fudError = ($ErrorObject.ErrorDetails.Message -split "(FUD_[0-9]+)")[1]
                $fudComDot = ($ErrorObject.ErrorDetails.Message -split "(FUD_[0-9]+)")[2]
                $samsungKNOXErrorCodeURL = "https://docs.samsungknox.com/dev/knox-e-fota/error-codes.htm"
                $msg += "RECOMMENDATION: Received Samsung KNOX E-FOTA error $fudError for $fudComDot.  Please lookup error details using the Samsung KNOX Troubleshooting guide at the following site:  $samsungKNOXErrorCodeURL"
            }
            else {
                $msg += $unknownErrorMsg
            }
        }
        elseif ($Proxy -and $ErrorObject.Exception.Message -ieq "This operation is not supported for a relative URI.") {
            $msg += "RECOMMENDATION: The script .ini file is configured to use the $Proxy proxy server when making API calls.  The proxy server must be in a URL form instead of DNS or FQDN (e.g., http://myproxy.server.com)."
        }
        else {
            $msg += $unknownErrorMsg
        }
    }

    End {
        Write-Log $msg -Level ERROR
    }
}

Function Get-SamsungKnoxApiOAuthToken {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string] $ClientID,
        [Parameter(Mandatory = $true)]
        [string] $ClientSecret
    )

    Begin {
        [string] $method = "POST"
        [string] $uri = "https://eu-api.samsungknox.com/iam/auth/oauth/v2/token"
        [string] $contentType = "application/x-www-form-urlencoded"
        [string] $body = "client_id=$ClientID&client_secret=**********&grant_type=client_credentials"
        [string] $logStr = "Attempting to make API call with the following parameters:
                            `n`tURI: {0}
                            `n`tMethod: {1}
                            `n`tContent-Type: {2}
                            `n`tBody: {3}" -f $uri, $method, $contentType, $body
        
        $body = $body.Replace("**********", $ClientSecret)
    }

    Process {

        if (!$ClientID -or !$ClientSecret) {
            Write-Log "The E-FOTA client ID is missing." -Level ERROR
        }

        if (!$ClientSecret) {
            Write-Log "The E-FOTA client secret is missing." -Level ERROR
        }

        try {
            if ($Proxy -and $ProxyCredential) {
                $logStr += "`n`tProxy: {0}
                            `n`tProxy Credentials: {1}" -f $Proxy, $ProxyCredential.UserName
                $response = Invoke-WebRequest -Method Post -Uri $uri -ContentType $contentType -Body $body -Proxy $Proxy -ProxyCredential $ProxyCredential
            }
            elseif ($Proxy) {
                $logStr += "`n`tProxy: {0}
                            `n`tProxy Credentials: Default" -f $Proxy
                $response = Invoke-WebRequest -Method Post -Uri $uri -ContentType $contentType -Body $body -Proxy $Proxy -ProxyUseDefaultCredentials
            }
            else {
                $logStr += "`n`tProxy: None"
                $response = Invoke-WebRequest -Method Post -Uri $uri -ContentType $contentType -Body $body
            }
        }
        catch {
            $Global:help = $_
            Write-Log $logStr
            Debug-ExceptionMessage -ErrorObject $Global:help
        }
    }

    End {
        Write-Log $logStr -Level VERBOSE

        if ($response.StatusCode -eq 200) {
            $jsonObj = $response.Content | ConvertFrom-Json
            [string] $msg = "Received OAuth 2.0 access token.
                            `n`tToken Type: {0}
                            `n`tToken Scope: {1}
                            `n`tToken Lifetime: {2} seconds" -f $jsonObj.token_type, $jsonObj.scope, $jsonObj.expires_in
            Write-Log $msg -Level VERBOSE

            return $jsonObj
        }
        else {
            [string] $msg = "Received an unexpected HTTP status code.
                            `n`tStatus Code: {0}
                            `n`tStatus Description: {1}
                            `n`tResponse Content:
                            `n`t{2}
                            `n`tResponse Headers: {3}
                            `n`tRaw Response:
                            `n`t{4}" -f $response.StatusCode, $response.StatusDescription, $response.Content, ($response.Headers | Format-Table | Out-String), $response.RawContent
            Write-Log $msg -Level WARN

            try {
                $jsonObj = $response.Content | ConvertFrom-Json

                return $jsonObj
            }
            catch {
                $Global:help = $_
                Debug-ExceptionMessage -ErrorObject $Global:help
            }
        }
    }
}

Function Invoke-EfotaRestMethod {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]    
        [string] $Uri,
        [Parameter(Mandatory = $true)]
        [string] $Body,
        [Parameter(Mandatory = $true)]
        $Headers,
        [string] $LogMessage
    )

    Begin {
        if ($LogMessage) {
            Write-Log $LogMessage -Level VERBOSE
        }

        [string] $method = "POST"
        [string] $contentType = "application/xml"
        [string] $logStr = "Attempting to make API call with the following parameters:
                            `n`tURI: {0}
                            `n`tMethod: {1}
                            `n`tContent-Type: {2}
                            `n`tBody: {3}" -f $Uri, $method, $contentType, $Body
    }

    Process {
        try {
            if ($Proxy -and $ProxyCredential) {
                $logStr += "`n`tProxy: {0}
                            `n`tProxy Credentials: {1}" -f $Proxy, $ProxyCredential.UserName
                $response = Invoke-WebRequest -Method $method -Uri $Uri -Headers $Headers -ContentType $contentType -Body $Body -Proxy $Proxy -ProxyCredential $ProxyCredential
            }
            elseif ($Proxy) {
                $logStr += "`n`tProxy: {0}
                            `n`tProxy Credentials: Default" -f $Proxy
                $response = Invoke-WebRequest -Method $method -Uri $Uri -Headers $Headers -ContentType $contentType -Body $Body -Proxy $Proxy -ProxyUseDefaultCredentials
            }
            else {
                $logStr += "`n`tProxy: NONE"
                $response = Invoke-WebRequest -Method $method -Uri $Uri -Headers $Headers -ContentType $contentType -Body $Body
            }
        }
        catch {
            $Global:help = $_
            Write-Log $logStr
            Debug-ExceptionMessage -ErrorObject $Global:help
        }
    }

    End {
        Write-Log $logStr -Level VERBOSE

        if ($response.StatusCode -eq 200) {
            $xmlObj = [xml] $response.Content
            Write-Log "Response from API call:`n$(Format-Xml $xmlObj)"

            return $xmlObj
        }
        else {
            [string] $msg = "Received an unexpected HTTP status code or response content type.  Raw Response:`n$($response.RawContent)"
            Write-Log $msg -Level WARN
            
            try {
                $xmlObj = [xml] $response.Content

                return $xmlObj
            }
            catch {
                $Global:help = $_
                Debug-ExceptionMessage -ErrorObject $Global:help
            }
        }
    }
}

# Start Script
Write-Log "Starting script." -Overwrite $true

# Load .ini file
if (Test-Path $IniFile) {
    $ini = Get-IniFile -File $IniFile
}
else {
    Write-Log "No .ini file specified.  This is needed for script parameters.  Either specify the complete file path to the .ini or change the working directory of the current PowerShell session to directory where the .ini file is kept." -Level ERROR
}

# Map .ini parameters with script variables
if ($ini) {
    [string] $DeviceToUpdateFile = $ini.Device.DeviceTargetUpdateListFile
    [string] $TargetFirmwareVersion = $ini.Device.DeviceTargetFirmwareVersion
    [string] $EfotaClientID = $ini.Efota.EfotaClientID
    [string] $EfotaMdmID = $ini.Efota.EfotaMdmID
    [string] $EfotaCustomerID = $ini.Efota.EfotaCustomerID
    [string] $EfotaLicense = $ini.Efota.EfotaLicense
    [string] $EfotaDeviceModelName = $ini.Efota.EfotaDeviceModelName
    [string] $EfotaSalesCode = $ini.Efota.EfotaSalesCode
    [string] $EfotaNetworkType = $ini.Efota.EfotaNetworkType
    [string] $Proxy = $ini.Proxy.ProxyServerURL

    if ($EfotaClientSecret) {
        Write-Log "E-FOTA API Client Secret was provided as a command line parameter." -Level VERBOSE
    }
    elseif ($ini.Efota.EfotaClientSecret) {
        Write-Log "E-FOTA API Client Secret was provided from $IniFile file." -Level VERBOSE
        $EfotaClientSecret = $ini.Efota.EfotaClientSecret
    }
    else {
        Write-Log "An E-FOTA API Client Secret was not provided to authenticate and obtain an OAuth 2.0 access token." -Level ERROR
    }

    if ($Proxy) {
        if ($ini.Proxy.ProxyUseDefaultCredentials -eq $true) {
            Write-Log "Using default credentials for proxy server authentication to the $Proxy server." -Level VERBOSE
        }
        elseif ($ini.Proxy.ProxyCredential -eq $true) {
            if ($ProxyCredential) {
                Write-Log "Using existing specified credentials for username $($ProxyCredential.Username) to authenticate to the $Proxy server." -Level VERBOSE
            }
            else {
                Write-Log "No proxy credentials are known.  Prompting for username and password to authenticate to the $Proxy server."
                $ProxyCredential = Get-Credential
            }
        }
        else {
            Write-Log "An error occurred when trying to determine proxy server authentication credentials in the $IniFile file.  Ensure the proxy settings in the .ini file are correct." -Level ERROR
        }
    }
}

# Get Samsung KNOX API OAuth access token
$efotaToken = Get-SamsungKnoxApiOAuthToken -ClientID $EfotaClientID -ClientSecret $EfotaClientSecret
$headers = @{"Authorization" = "Bearer $($efotaToken.access_token)" }

# Get E-FOTA license information
$uri = "https://eu-api.samsungknox.com/b2bfota/v2/licenseInfo"
$body = "<B2bLicenseInfoVO><mdmId>$EfotaMdmID</mdmId><customerId>$EfotaCustomerID</customerId><license>$EfotaLicense</license></B2bLicenseInfoVO>"
$efotaLicenseInfo = Invoke-EfotaRestMethod -Uri $uri -Headers $headers -Body $body -LogMessage "Getting E-FOTA license information."

# Get E-FOTA list of firmware updates available for a specified device model (e.g., SM-T830)
$uri = "https://eu-api.samsungknox.com/b2bfota/v2/firmwareList"
$body = "<B2bFirmwareInfoListVO><mdmId>$EfotaMdmID</mdmId><customerId>$EfotaCustomerID</customerId><license>$EfotaLicense</license><deviceModelName>$EfotaDeviceModelName</deviceModelName><salesCode>$EfotaSalesCode</salesCode></B2bFirmwareInfoListVO>"
$efotaAvailableFirmwareListForDeviceModel = Invoke-EfotaRestMethod -Uri $uri -Headers $headers -Body $body -LogMessage "Getting list of available firmware update for device model $EfotaDeviceModelName."

# Get targeted device serial numbers from file
[string[]] $snArray = Get-DeviceSerialNumbersFromFile -File $DeviceToUpdateFile
$snXML = Format-SerialNumbersAsXml -SerialNumberArray $snArray

# Get list of device serial numbers that are not enrolled into E-FOTA
$uri = "https://eu-api.samsungknox.com/b2bfota/v2/abnormalDeviceList"
$body = "<B2bAbnormalDeviceListVO><mdmId>$EfotaMdmID</mdmId><customerId>$EfotaCustomerID</customerId><license>$EfotaLicense</license><deviceList>$snXML</deviceList></B2bAbnormalDeviceListVO>"
$abnormalXML = Invoke-EfotaRestMethod -Uri $uri -Headers $headers -Body $body -LogMessage "Getting list of E-FOTA un-enrolled (abnormal) device serial numbers.  All devices must be enrolled or registered in E-FOTA before the firmware update command can be issued successfully."
$diff = Compare-DevicesLists -AbnormalDevicesXML $abnormalXML -TargetedSNs $snArray

# Send update command to the diff list of device serial numbers
[string] $targetedSN = Format-SerialNumbersAsXml -SerialNumberArray $diff
$uri = "https://eu-api.samsungknox.com/b2bfota/v2/forceUpdate"
$body = "<B2bForceUpdateVO><mdmId>$EfotaMdmID</mdmId><customerId>$EfotaCustomerID</customerId><license>$EfotaLicense</license><deviceModelName>$EfotaDeviceModelName</deviceModelName><salesCode>$EfotaSalesCode</salesCode><networkType>$EfotaNetworkType</networkType><targetFirmwareVersion>$TargetFirmwareVersion</targetFirmwareVersion><deviceList>$targetedSN</deviceList></B2bForceUpdateVO>"
$updateResponse = Invoke-EfotaRestMethod -Uri $uri -Headers $headers -Body $body -LogMessage "Issuing firmware update command."
$updateId = $updateResponse.B2bForceUpdateVO.forceUpdateId 
Write-Log "Device firmware update request successful.  Firmware update ID: $updateId."

# Get firmware update summary from the update ID
$uri = "https://eu-api.samsungknox.com/b2bfota/v2/forceUpdateSummary"
$body = "<B2bForceUpdateSummaryVO><mdmId>$EfotaMdmID</mdmId><customerId>$EfotaCustomerID</customerId><license>$EfotaLicense</license><forceUpdateId>$updateId</forceUpdateId></B2bForceUpdateSummaryVO>"
$updateSummaryResponse = Invoke-EfotaRestMethod -Uri $uri -Headers $headers -Body $body -LogMessage "Getting update summary for update ID $updateId."

# Get firmware update details from the update ID
$uri = "https://eu-api.samsungknox.com/b2bfota/v2/forceUpdateDetail"
$body = "<B2bForceUpdateDetailVO><mdmId>$EfotaMdmID</mdmId><customerId>$EfotaCustomerID</customerId><license>$EfotaLicense</license><forceUpdateId>$updateId</forceUpdateId></B2bForceUpdateDetailVO>"
$updateDetailsResponse = Invoke-EfotaRestMethod -Uri $uri -Headers $headers -Body $body -LogMessage "Getting update details for update ID $updateId."


Write-Log "Script completed." -NoNewLine $true