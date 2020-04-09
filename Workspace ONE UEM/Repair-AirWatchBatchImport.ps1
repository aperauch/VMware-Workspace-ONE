<#
.SYNOPSIS
Script changes the device friendly name, asset number, OG, and adds tags based on given batch import csv file.
.DESCRIPTION
Script will parse the specified CSV file, look for devices based on the Serial Number found in the CSV, and then change the friendly name, asset number, move OG, and add tags as specified in the CSV record.
.PARAMETER AirWatchTenant
The Domain name of the AirWatch tenant (e.g., cn135.awmdm.com).
.PARAMETER GroupID
The Organization Group ID (GID) from which to search.  Use the topmost or root GID in most cases.  Please note the GID is not the same as the name of the OG.  The GID is what is used when enrolling a device (e.g., CompanyName-BYOD).
.PARAMETER APIKey
The API Key or AirWatch Tenant Code (aw-tenant-code) used for authorizing AirWatch API calls.
.PARAMETER Filename
The batch import CSV file to reference.
.PARAMETER Credential
The PSCredential object containing the username and secure password used for authenticating AirWatch API calls.  The account must exist in the AirWatch Console and have full pemissions to the AirWatch REST API.
.EXAMPLE
Use the default parameter values for the script.  The script will ask for credentials and look for the CSV file from the current directory.
Repair-AirWatchBatchImport
.EXAMPLE
Provide saved credentials or credentials from the current PowerShell session.
$cred = Get-Credential
Repair-AirWatchBatchImport -Credential $cred
.EXAMPLE
Use custom values for all parameters.
Repair-AirWatchBatchImport -AirWatchTenant aw.company.com -GroupID CorpOwned -Filename c:\path\to\batch_import.csv -APIKey abcdefJ48dJanpLLWend123456= -Credential $cred
.EXAMPLE
Run the script with verbose output for troubleshooting purposes.
Repair-AirWatchBatchImport -Credential $cred -Verbose
.NOTES
Update the default parameter values for your AirWatch environment by modifying this script.
#>
function Repair-AirWatchBatchImport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String] $AirWatchTenant,
        [Parameter(Mandatory=$true)]
        [String] $GroupID,
        [Parameter(Mandatory=$true)]
        [String] $APIKey,
        [Parameter(Mandatory=$true)]
        [String] $Filename,
        [Parameter(Mandatory=$true,ValueFromPipeline)]
        [pscredential] $Credential
    )

    # Functions
    function Invoke-AirWatchAPIAndSendHTTPBody {
        [CmdletBinding()]
        Param ([String]$Uri, [HashTable]$Headers, [String]$Method="Put", [String]$ContentType="application/json", [String]$Body="", [PSCredential]$Credential) 
        try {
            $r = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method $Method -ContentType $ContentType -Body $Body -Credential $Credential
            return $r
        } catch {
            Write-APIErrorResponse $_
        }
    }

    function Invoke-AirWatchAPI {
        [CmdletBinding()]
        Param ([String]$Uri, [HashTable]$Headers, [String]$Method="Get", [String]$ContentType="application/json", [PSCredential]$Credential) 
        try {
            $r = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method $Method -ContentType $ContentType -Credential $Credential
            return $r
        } catch {
            Write-APIErrorResponse $_
        }
    }

    function Write-APIErrorResponse {
        [CmdletBinding()]
        Param ($e)

        $httpStatusCode = $e.Exception.Response.StatusCode.value__
        $errorResponseMessage =  $e.ErrorDetails.Message #| ConvertFrom-Json | Select-Object -ExpandProperty Message
        
        Write-Verbose "$errorResponseMessage."

        switch ($httpStatusCode) {
            400 { Write-Verbose "The HTTP request completed with a client side error.  Ensure the HTTP request is formatted correctly." }
            401 { Write-Verbose "Ensure the username and password is correct." }
            403 { Write-Verbose "Ensure the correct API Key (aw-tenant-code) has been provided for your AirWatch tenant $AirWatchURL and that the account you are authenticating with has full API permissions.  The API key that is being used is $APIKey" }
            404 { Write-Verbose "Resource not found.  Ensure the API URL is correct or that the resource exists." }
            500 { Write-Verbose "This is a server side error; however, the API call may be incorrect and causing the error." }
        }
    }

    function Get-TagIDs {
        [CmdletBinding()]
        param ([String[]] $TagNameArray)
        
        [String[]] $tagIDs = @()

        foreach ($tagName in $TagNameArray) {
            # Get the tag ID based on the given tag name via REST API
            $getTagIDByTagNameURL = $AirWatchURL + "/api/mdm/tags/search?organizationgroupid=$lgID&name=$TagName"
            $getTagIDByTagName = Invoke-AirWatchAPI -Uri $getTagIDByTagNameURL -Headers $headers -Credential $Credential
            $tagID = $getTagIDByTagName.Tags.ID.Value

            # If tag was found, add tag ID to array
            if ($tagID) {
                $tagIDs += $tagID
            }
        }

        return $tagIDs
    }

    function Add-TagsToDevice {
        [CmdletBinding()]
        param ([String[]] $TagIDs, [String] $DeviceID)
        
        # Prepare JSON message for HTTP POST call
        $messageBody = @{BulkValues=@{Value=@($DeviceID)}}
        $json = $messageBody | ConvertTo-Json

        foreach ($id in $TagIDs) {
            $uri = $AirWatchURL + "/api/mdm/tags/$id/adddevices"
            $result = Invoke-AirWatchAPIAndSendHTTPBody -Uri $uri -Headers $headers -Method "Post" -Body $json -Credential $Credential

            if ($result.FailedItems -ne 0) {
                $errorMsg = $result.Faults.Fault[0].Message
                Write-Verbose "Failed to add tag ID $id to device ID $DeviceID.  Error message:  $errorMsg."
            }
        }
    }

    function Exit-Script {
        Write-Host "Script completed."
        Pause
        Exit
    }

    # Get authentication credentials if none exist already
    if ($Credential -eq $null) {
        $Credential = Get-Credential
    }

    # HTTP Headers needed for V1 REST APIs
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("aw-tenant-code", $APIKey) 
    $headers.Add("Accept", "application/json")

    # HTTP Headers needed for V2 REST APIs
    $headersV2 = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headersV2.Add("aw-tenant-code", $APIKey) 
    $headersV2.Add("Accept", "application/json;version=2")

    # Properly format the AirWatch DNS name into an HTTPS URI
    $AirWatchTenant = $AirWatchTenant.Trim() # remove leading or trailing whitespace
    $AirWatchTenant = $AirWatchTenant.TrimEnd("/") # remove trailing '/'
    if ($AirWatchTenant -ilike "https://*") {
        $AirWatchURL = $AirWatchTenant
    } elseif ($AirWatchTenant -ilike "http://*") {
        $AirWatchTenant = $AirWatchTenant -ireplace "http://"
        $AirWatchURL = "https://" + $AirWatchTenant
    } else {
        $AirWatchURL = "https://" + $AirWatchTenant
    }
    
    # Get the Location Group ID of the given OG name via REST API
    $getLocGroupURL = $AirWatchURL + "/api/system/groups/search?groupid=$GroupID"
    $locGroup = Invoke-AirWatchAPI -Uri $getLocGroupURL -Headers $headersV2 -Credential $Credential

    # If nothing was returned, then authentication might have failed
    if ($locGroup -eq $null) {
        Write-Host "Nothing returned from the first API call.  Ensure the correct username, password, and URL was provided in the API call.  Exiting." -ForegroundColor Red
        Exit-Script
    }

    # If the LGID is null, then the GID was not found in the previous API call
    $lgID = $locGroup.OrganizationGroups.Id
    if ($lgID -eq $null) {
        Write-Host "Unable to find the Location Group ID for the Organization Group ID $GroupID.  Please enter the correct Group ID for the target AirWatch Organization Group.  Exiting." -ForegroundColor Red
        Exit-Script
    }

    # Check if CSV file can be found and quit program if not
    if (!(Test-Path $Filename)) {
        Write-Host "Unable to find CSV file $Filename.  Exiting." -ForegroundColor Red
        Exit-Script
    }

    # Open CSV file
    $deviceRecords = Import-Csv $Filename
    if(!$deviceRecords) {
        Write-Host "CSV file was empty or there was an error opening the $Filename.  Exiting." -ForegroundColor Red
        Exit-Script
    }

    # For each device record in the CSV
    foreach ($deviceRecord in $deviceRecords) {

        # Get device info by SN
        $deviceSN = $deviceRecord.'Device Serial Number'
        $getDeviceDetailsBySerialNumberURL = $AirWatchURL + "/api/mdm/devices?searchBy=Serialnumber&id=$deviceSN"
        $deviceDetails = Invoke-AirWatchAPI -Uri $getDeviceDetailsBySerialNumberURL -Headers $headers -Credential $Credential

        # If a device was found
        if($deviceDetails) {
            $deviceID = $deviceDetails.Id.Value
            
            # Set device asset number given in the CSV
            $oldAN = $deviceDetails.AssetNumber
            $newAN = $deviceRecord.'Device Asset Number'
            $deviceDetails.AssetNumber = $deviceRecord.'Device Asset Number'
            $updatedAN = $deviceDetails.AssetNumber
            Write-Verbose "Changing AN from $oldAN to $newAN.  The new AN should be $updatedAN."

            # Add tags from CSV to device
            $tagNameArray = $deviceRecord.Tags.Split(":")
            $tags = Get-TagIDs -TagNameArray $tagNameArray
            
            # Ensure all tags were found
            if ($tagNameArray.Count -ne $tags.Count) {
                Write-Verbose "Unable to find one or more tag IDs for this device.  Device has these tags in the CSV: $tagNameArray.  Tag IDs are $tags."
            }
            $addTagsToDevice = Add-TagsToDevice -TagIDs $tags -DeviceID $deviceID

            # Check if the device friendly name needs to be changed
            $currentDeviceFN = $deviceDetails.DeviceFriendlyName 
            $expectedDeviceFN = $deviceRecord.'Device Asset Number' + "-" + $deviceSN
                
            $deviceDetails.DeviceFriendlyName = $expectedDeviceFN
            $json = $deviceDetails | ConvertTo-Json
            $updateDeviceDetailsURL = $AirWatchURL + "/api/mdm/devices/$deviceID"
            $r = Invoke-AirWatchAPIAndSendHTTPBody -Uri $updateDeviceDetailsURL -Headers $headers -Credential $Credential -Method "Put" -Body $json -ContentType "application/json"
            
            if ($r.Length -eq 0) {
                Write-Verbose "Device Friendly Name changed from $currentDeviceFN to $expectedDeviceFN for device with SN: $deviceSN"
            }
            
            # Get destination OG info to compare to current OG (using a Version 2 of the AW System API)
            $currOG = $deviceDetails.LocationGroupName
            $destOG = $deviceRecord.'GroupID*'
            $groupsAPI = "/api/system/groups"
            $getDestGroupIdURL = $AirWatchURL + $groupsAPI + "/search?groupid=" + $destOG
            $destGroupId = Invoke-AirWatchAPI -Uri $getDestGroupIdURL -Headers $headersV2 -Credential $Credential
            
            if ($destGroupId.Length -eq 0) {
                Write-Host "Failed to get destination Group ID. Unable to move device $expectedDeviceFN from $currOG OG to $destOG OG.  Skipping." -ForegroundColor Red
                Break
            }
            
            # Check if the device is in the correct Organization Group (i.e., Location Group ID)
            $destGID = $destGroupId.OrganizationGroups.Id
            if ($deviceDetails.LocationGroupId.Id.Value -ne $destGID) {
                $changeOGURL = $AirWatchURL + "/api/mdm/devices/$deviceID/commands/changeorganizationgroup/$destGID"
                $r = Invoke-AirWatchAPI -Uri $changeOGURL -Headers $headers -Credential $Credential -Method "Put" 
    
                if ($r.Length -eq 0) {
                    Write-Verbose "Moved device $expectedDeviceFN from the '$currOG' OG to the '$destOG' OG."
                }
            }
        } else {
            Write-Host "Unable to get device details for SN:  $deviceSN." -ForegroundColor Red
        }
    }

    # Exit
    Exit-Script
}

Repair-AirWatchBatchImport -Verbose