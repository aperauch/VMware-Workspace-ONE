function Test-Cred {
           
    [CmdletBinding()]
    [OutputType([String])] 
       
    Param ( 
        [Parameter( 
            Mandatory = $false, 
            ValueFromPipeLine = $true, 
            ValueFromPipelineByPropertyName = $true
        )] 
        [Alias( 
            'PSCredential'
        )] 
        [ValidateNotNull()] 
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()] 
        $script:Credentials
    )
    $Domain = $null
    $Root = $null
    $script:Username = $null
    $script:Password = $null
      
    If($script:Credentials -eq $null)
    {
        Try
        {
            $script:Credentials = Get-Credential "domain\$env:username" -ErrorAction Stop
        }
        Catch
        {
            $ErrorMsg = $_.Exception.Message
            Write-Warning "Failed to validate credentials: $ErrorMsg "
            Pause
            Break
        }
    }
      
    # Checking module
    Try
    {
        # Split username and password
        $Username = $credentials.username
        $Password = $credentials.GetNetworkCredential().password
  
        # Get Domain
        $Root = "LDAP://" + ([ADSI]'').distinguishedName
        $Domain = New-Object System.DirectoryServices.DirectoryEntry($Root,$UserName,$Password)
    }
    Catch
    {
        $_.Exception.Message
        Continue
    }

    If(!$domain)
    {
        Write-Warning "Something went wrong, can't find domain"
        Break
    }
    Else
    {
        If ($domain.name -ne $null)
        {
            Set-Variable -Name "auth" -Value 1
            Write-Host $auth
            Write-Host "Authenticated"
           
        }
        Else
        {
            Set-Variable -Name "auth" -Value 0
            Write-Host $auth
            Write-Host "Not authenticated"
            Break
        }
    }
}