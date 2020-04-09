<#
.SYNOPSIS
    Demonstrates requesting and renewing an OAuth 2.0 access token for authentication to VMware Workspace ONE (WS1) UEM REST API.

.DESCRIPTION
    The ccript will check if an existing access token exists from a previous session (i.e., if the token exists in the program's memory).
    If the token exists, the script will parse the JWT access token to determine if the token has expired (tokens have a 3600 second lifetime).
    If the token does not exist or the token has expired, a new access token will be requested from the specificed UEM region.
    Finally, an API call to fetch the UEM server system details will be made to demonstrate authentication with the access token.

    To run this script, an OAuth client ID and client secrete must first be manually created from the UEM admin console using and 
    administrator account that has the appropriate role permissions (e.g., the AirWatch Administrator role).
    Create the WS1 UEM OAuth client ID and secret from UEM admin console > Groups & Settings > Configurations > OAuth Client Management.
    Direct URL Example:  https://ws1-uem-admin-console.company.com/AirWatch/aa/#/configurations/oauth-clients

    In addition, an API key must be created or copied from UEM and supplied as a header when performing the actual WS1 UEM REST API call example.
    The API key is required to be passed as the value for the aw-tenant-code header when making the API call example to fetch the UEM system info.
    Create the WS1 UEM API key from UEM admin console > Groups & Settings > All Settings > System > Advanced > API > REST API.
    The API key must be of type Admin.
    Direct URL Example:  https://ws1-uem-admin-console.company.com/AirWatch/#/AirWatch/Settings/RESTApi

.PARAMETER ClientID
    The OAuth client ID created from the WS1 UEM admin console.

.PARAMETER ClientSecret
    The OAuth client secret created from the WS1 UEM admin console.

.PARAMETER APIKey
    The API key to be passed as the aw-tenant-code header value when making the WS1 UEM REST API call.

.PARAMETER UEMServerDNS
    Enter the DNS of the UEM API server (e.g., as135.awmdm.com or ws1-admin-console.company.com).

.PARAMETER UEMRegion
    Enter the region where WS1 UEM is hosted.  The OAuth access token service URL is region specific for purposes of GDPR.

.EXAMPLE
    Basic example of script using the UAT
    PS C:\> Get-OAuthAccessTokenForWS1UEM -ClientID "1234567890abcdefghij" -ClientSecret "0987654321abcdefghij" -APIKey "a1b2c3d4e5f6g7h8i9j0" -UEMServerDNS "as135.awmdm.com" -UEMRegion "UAT"

.EXAMPLE
    Example of running script with debug output
    PS C:\> Get-OAuthAccessTokenForWS1UEM -ClientID "1234567890abcdefghij" -ClientSecret "0987654321abcdefghij" -APIKey "a1b2c3d4e5f6g7h8i9j0" -UEMServerDNS "as135.awmdm.com" -UEMRegion "UAT" -Debug
    
.NOTES
    Author: Aron Aperauch
    Last Edit: 2020-02-17
    Version 1.0 - initial release
#>

[cmdletbinding()]
Param(
    [string] $ClientID,    
    [string] $ClientSecret,
    [string] $APIKey,
    [string] $UEMServerDNS = "as135.awmdm.com",
    [ValidateSet("UAT", "NA", "EMEA", "APAC")]
    [string] $UEMRegion = "UAT"
)

Function Parse-JWTtoken {
    [cmdletbinding()]
    param([Parameter(Mandatory=$true)][string]$token)
 
    # Validate as per https://tools.ietf.org/html/rfc7519
    # Access and ID tokens are fine, Refresh tokens will not work
    if (!$token.Contains(".") -or !$token.StartsWith("eyJ")) { Write-Error "Invalid token" -ErrorAction Stop }
 
    ### Header
    $tokenheader = $token.Split(".")[0].Replace('-', '+').Replace('_', '/')
    # Fix padding as needed, keep adding "=" until string length modulus 4 reaches 0
    while ($tokenheader.Length % 4) { Write-Debug "Invalid length for a Base-64 char array or string, adding ="; $tokenheader += "=" }
    Write-Debug "Base64 encoded (padded) header:"
    Write-Debug $tokenheader
    $hdr = [System.Text.Encoding]::ASCII.GetString([system.convert]::FromBase64String($tokenheader)) | ConvertFrom-Json # Convert from Base64 encoded string to PSObject
    Write-Debug "Decoded header:`n$hdr"
 
    ### Payload
    $tokenPayload = $token.Split(".")[1].Replace('-', '+').Replace('_', '/')
    # Fix padding as needed, keep adding "=" until string length modulus 4 reaches 0
    while ($tokenPayload.Length % 4) { Write-Debug "Invalid length for a Base-64 char array or string, adding ="; $tokenPayload += "=" }
    Write-Debug "Base64 encoded (padded) payoad:`n$tokenPayload"
    $tokenByteArray = [System.Convert]::FromBase64String($tokenPayload) # Convert to Byte array
    $tokenArray = [System.Text.Encoding]::ASCII.GetString($tokenByteArray) # Convert to string array
    Write-Debug "Decoded array in JSON format:`n$tokenArray"
    $tokobj = $tokenArray | ConvertFrom-Json # Convert from JSON to PSObject
    Write-Debug "Decoded Payload:`n$tokobj"
    
    return $tokobj
}

# Request an access token
Function Get-AccessTokenObject {
    # Regional Token Request URIs
    #Ensure there is no trailing '/' otherwise a 404 will be returned
    $access_token_url = $null
    Switch ($UEMRegion) {
        "UAT"   { $access_token_url = "https://uat.uemauth.vmwservices.com/connect/token";  Break }
        "NA"    { $access_token_url = "https://na.uemauth.vmwservices.com/connect/token";   Break }
        "EMEA"  { $access_token_url = "https://emea.uemauth.vmwservices.com/connect/token"; Break }
        "APAC"  { $access_token_url = "https://apac.uemauth.vmwservices.com/connect/token"; break }
        Default { Write-Host "The UEM region is unknown.  Exiting."; Exit }
    }

    $body = @{
        grant_type = "client_credentials"
        client_id = $ClientID
        client_secret = $ClientSecret
    }
    $token = Invoke-WebRequest -Method Post -Uri $access_token_url -Body $body
    $token_object = $token | ConvertFrom-Json

    return $token_object
}

### BEGIN ###
# Check if an access token exists and if not expired
if ($token) {
    $jwt = Parse-JWTtoken $token.access_token

    $dotNET_date = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($jwt.exp))
    if((Get-Date) -gt $dotNET_date) {
        Write-Host "Token has expired.  Requesting a new access token."
        $token = Get-AccessTokenObject
    } else {
        Write-Host "Token is still valid.  Using existing token."
    }
} else {
    Write-Host "An existing token was not found or does not exist.  Requesting a new access token."
    $token = Get-AccessTokenObject
}

# Perform WS1 UEM API call with access token
$headers = @{
    "aw-tenant-code" = $APIKey
    Authorization = "$($token.token_type) $($token.access_token)"
    Accept = "application/json"
}
$api_url = "https://$UEMServerDNS/API/system/info"
Write-Host "Authenticating to API $api_url with the token..."
Invoke-RestMethod -Uri $api_url -Method Get -Headers $headers
