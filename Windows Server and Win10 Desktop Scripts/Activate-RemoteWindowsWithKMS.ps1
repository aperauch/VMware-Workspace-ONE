$INPUT_FILE = "Windows_Servers_List.txt"

# Get creds if they don't exist already to establish remote PS session
if (!$creds) { 
    $creds = Get-Credential -Message "Enter your domain admin credentials.  Example username: domain\jsmith_admin"
}

# Open list of servers
$serversList = Get-Content $INPUT_FILE

# For each server in the list...
foreach ($server in $serversList) {
    Write-Host "`nConnecting to $server..."

    # Start a remote PowerShell session
    $session = New-PSSession -ComputerName $server -Credential $creds

    # Execute the following commands on the remote server
    Invoke-Command -Session $session -ScriptBlock {
        # Variables
        $ETH0 = "Ethernet0*"
        $DNS1 = "10.100.18.21"
        $DNS2 = "10.100.18.22"
        $W16_KEY = "CB7KF-BWN84-R7R2Y-793K2-8XDDG"
        $W19_KEY = "WMDGN-G9PQG-XVVXX-R3X43-63DFG"
        $W16_BUILD = 14393
        $W19_BUILD = 17763
        $KMS_SERVER = "kms-server.company.com:1688"

        # Verify DNS settings are correct and DNS server is reachable (needed for KMS activation)
        $dnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -imatch $ETH0 } | Select-Object -ExpandProperty ServerAddresses

        # Set DNS settings if current values are not the expected values
        if (($dnsServers[0] -ne $DNS1) -or ($dnsServers[1] -ne $DNS2)) {
            Write-Host "Changing DNS servers from $($dnsServers[0]) and $($dnsServers[1]) to $DNS1 and $DNS2."
            Set-DnsClientServerAddress -InterfaceAlias $ETH0 -ServerAddresses $DNS1, $DNS2

            # Get updated DNS settings for confirmation
            $dnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -imatch $ETH0 } | Select-Object -ExpandProperty ServerAddresses
        }
        Write-Host "DNS servers are $($dnsServers[0]) and $($dnsServers[1])."

        ### Begin KMS activation
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
    }

    # Remmove remote PS session
    Remove-PSSession $session
}