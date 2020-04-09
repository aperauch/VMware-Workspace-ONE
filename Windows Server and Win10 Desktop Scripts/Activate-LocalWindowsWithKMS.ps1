# Must run as admin

$W16_KEY = "CB7KF-BWN84-R7R2Y-793K2-8XDDG"
$W19_KEY = "WMDGN-G9PQG-XVVXX-R3X43-63DFG"
$W16_BUILD = 14393
$W19_BUILD = 17763
$KMS_SERVER = "kms-server.company.com:1688"

# Get Windows Server OS version build number
$OSVersion = [System.Environment]::OSVersion.Version

# Select KMS client activation key based on reported OS version build number
$kmsKey = $null
switch ($OSVersion.Build) {
    $W16_BUILD { $kmsKey = $W16_KEY ; break } #W16 LTSC
    $W19_BUILD { $kmsKey = $W19_KEY ; break } #W19 LTSC
    default { Write-Host "Unknown Windows Server Version for $(hostname):  $($OSVersion)" ; break }
}

# If the OS version build number was known, attempt to activate with the specified KMS client key
if ($kmsKey) {
    Write-Host "Activating $(hostname) with OS version build $($OSVersion.Build) using KMS client key $($kmsKey)."
    cscript c:\windows\system32\slmgr.vbs /skms $KMS_SERVER
    cscript c:\windows\system32\slmgr.vbs /ipk $kmsKey
    cscript c:\windows\system32\slmgr.vbs /ato
}