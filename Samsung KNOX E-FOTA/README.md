## SYNOPSIS
Performs a device firmware update using the Samsung KNOX E-FOTA API against a list of device serial numbers.

## DESCRIPTION
The script requires an .ini file containing all the necessary script parameters such as the list of device serial numbers to update.  The script removes any serial numbers that are not registered or enrolled in E-FOTA, and then issues a firmware update command to update the devices to the specified target firmware version.  If the .ini file does not contain the E-FOTA client secret, then this value must be passed as a parameter to the script (see first example).

## EXAMPLES
```
PS C:\> Update-DeviceFirmwareWithEFOTA.ps1 -IniFile "C:\path\to\file.ini" -EfotaClientSecret 123456-abcdef-7890-ghijk
```
Example of running the script with the required.ini file and providing the E-FOTA client secret.

```
PS C:\> Update-DeviceFirmwareWithEFOTA.ps1 -IniFile "C:\path\to\file.ini"
```
Example of running the script with a specified file that contains a list of device serial numbers to target for a firmware update.

```
PS C:\> Update-DeviceFirmwareWithEFOTA.ps1 -IniFile "C:\path\to\file.ini" -Verbose
```
Example of running the script with verbose logging which can be helpful for troubleshooting and debugging.

## PARAMETERS
#### -IniFile
Required text file containing all of the necessary script parameter values.

#### -EfotaClientSecret
The account client secret used for authentication to the E-FOTA API to obtain an OAuth 2.0 access token.  The client secret can be provided with this parameter or through the .ini file.

## OUTPUTS
Outputs a log file called "Update-DeviceFirmwareWithEFOTA_Log.txt" in the working directory where the script is executed from.  The log file can be used for troubleshooting the script.

## LINKS
* Troubleshooting Samsung KNOX E-FOTA guide:  https://docs.samsungknox.com/dev/knox-e-fota/error-codes.htm
* GitHub Repo:  https://github.com/aperauch/VMware-Workspace-ONE

## NOTES
Author: Aron Aperauch

## POSTMAN
[![Run in Postman](https://run.pstmn.io/button.svg)](https://app.getpostman.com/run-collection/6666273fd3603aa6c45b#?env%5BE-FOTA%20Env%20Vars%5D=W3sia2V5IjoiZWZvdGFfY2xpZW50X2lkIiwidmFsdWUiOiIiLCJlbmFibGVkIjp0cnVlfSx7ImtleSI6ImVmb3RhX2NsaWVudF9zZWNyZXQiLCJ2YWx1ZSI6IiIsImVuYWJsZWQiOnRydWV9LHsia2V5IjoiZWZvdGFfdG9rZW5fZW5kcG9pbnQiLCJ2YWx1ZSI6Imh0dHBzOi8vZXUtYXBpLnNhbXN1bmdrbm94LmNvbS9pYW0vYXV0aC9vYXV0aC92Mi90b2tlbiIsImVuYWJsZWQiOnRydWV9LHsia2V5IjoiZ3JhbnRfdHlwZSIsInZhbHVlIjoiY2xpZW50X2NyZWRlbnRpYWxzIiwiZW5hYmxlZCI6dHJ1ZX0seyJrZXkiOiJlZm90YV9zY29wZSIsInZhbHVlIjoiZWZvdGEiLCJlbmFibGVkIjp0cnVlfSx7ImtleSI6ImVmb3RhX2FjY2Vzc190b2tlbl9leHBpcnkiLCJ2YWx1ZSI6IjE1ODQ3Mjg1OTYzMzciLCJlbmFibGVkIjp0cnVlfSx7ImtleSI6ImVmb3RhX2N1cnJlbnRfYWNjZXNzX3Rva2VuIiwidmFsdWUiOiIiLCJlbmFibGVkIjp0cnVlfSx7ImtleSI6ImVmb3RhX21kbUlkIiwidmFsdWUiOiJBUFE3OFdPTllDIiwiZW5hYmxlZCI6dHJ1ZX0seyJrZXkiOiJlZm90YV9jdXN0b21lcklkIiwidmFsdWUiOiIiLCJlbmFibGVkIjp0cnVlfSx7ImtleSI6ImVmb3RhX2xpY2Vuc2UiLCJ2YWx1ZSI6IiIsImVuYWJsZWQiOnRydWV9LHsia2V5IjoiZWZvdGFfZ3JvdXBJZCIsInZhbHVlIjoiIiwiZW5hYmxlZCI6dHJ1ZX0seyJrZXkiOiJlZm90YV9kZXZpY2VfU05fMSIsInZhbHVlIjoiIiwiZW5hYmxlZCI6dHJ1ZX1d)