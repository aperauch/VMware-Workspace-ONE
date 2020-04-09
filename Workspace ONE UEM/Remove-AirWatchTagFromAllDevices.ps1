# Authentication credentials
$credentials = Get-Credential

# Variables
$awTenant = "https://cn135.awmdm.com/api/mdm/tags/"
$tagID = "INPUT_TAG_ID_HERE" #"14920"

# Construct REST API URLs
$findDevicesWithTagURL = $awTenant + $tagID + "/devices"
$removeDevicesURL = $awTenant + $tagID + "/removedevices"

# HTTP Headers needed for REST APIs
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("aw-tenant-code", "INSERT_REST_API_KEY_HERE")
$headers.Add("Accept", "application/json")

# Get all devices by their AirWatch device ID that have the given tag
$devicesWithTag = Invoke-RestMethod -Uri $findDevicesWithTagURL -Headers $headers -Credential $credentials

# Parse out device IDs from HTTP response
$deviceIDs = $devicesWithTag.Device.DeviceID

# If no devices have the tag, then quit
if ($deviceIDs.Length -eq 0) {
    Write-Output "No devices have tag ID $tagID."
    break
}

# Prepare JSON message for HTTP POST call
$messageBody = @{
    BulkValues=
        @{
            Value=@(
                $deviceIDs
            )
        }
}
$json = $messageBody | ConvertTo-Json

# Call the REST API and output result
$result = Invoke-RestMethod -Uri $removeDevicesURL -Headers $headers -Credential $credentials -Method Post -Body $json -ContentType "application/json"

# Change color of output text if there was a failure
$color = "Green"
if ($result.FailedItems -ne 0) {
    $color = "Red"

    # Get list of failed devices
    $errorCheck = Invoke-RestMethod -Uri $findDevicesWithTagURL -Headers $headers -Credential $credentials
}

# Output results
Write-Host "Removed tag ID $tagID from" $result.AcceptedItems "out of" $result.TotalItems "device(s)." -ForegroundColor $color
Write-Host "Failed to remove tag from" $result.FailedItems "device(s)." -ForegroundColor $color
$result

# Output list of failed devices if any
if ($errorCheck) {
    Write-Host "The following devices still have tag ID $tagID..." -ForegroundColor $color
    $errorCheck.Device
}