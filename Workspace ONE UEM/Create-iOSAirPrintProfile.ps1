Clear-Host

$url = 'https://as420.awmdm.com/api/mdm/profiles/platforms/apple/create'
$urlMethod = 'Post'

$urlTest = 'https://as420.awmdm.com/api/mdm/profiles/48805'


# Credentials
$username = 'aronapi'
$password = 'a8hdfvrM5h9Hj4eCCvNS'
#$cred = Get-Credential -UserName $username
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, ($password | ConvertTo-SecureString -AsPlainText -Force)

# Built-In HTTP Headers
$contentTypeHeader = 'application/json'

# Custom HTTP Headers
$apiKey = 'CjCbOdWlbOVWP9SPikaZ2BUjxgPW9piZSF6NctVKGC4='
$acceptHeader = 'application/json;version=2'
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add('aw-tenant-code', $apiKey)
$headers.Add('Accept', $acceptHeader)

# HTTP Message Body to send in POST
$jsonBody = '{"WebClips":{"FullScreen":false,"Icon":0,"Removable":true,"Label":"cnn","PrecomposedIcon":false,"URL":"http://www.cnn.com"},"General":{"ProfileId":0,"Name":"aron-API-TEST3-WebClip","Description":"","Version":1,"AssignmentType":"Auto","ProfileContext":"Unknown","EnableProvisioning":false,"IsActive":true,"IsManaged":true,"Password":"","AllowRemoval":"Always","AssignedSmartGroups":[{"SmartGroupId":9907,"Name":"All Devices"}],"ExcludedSmartGroups":[],"ManagedLocationGroupID":7434,"AssignedSchedule":[]}}'

# Clear previous responses
$response = 'No response yet.'

# Make HTTP Call
$response = Invoke-RestMethod $url -Headers $headers -Credential $cred -Method Post -ContentType $contentTypeHeader -Body $jsonBody
#$response = Invoke-RestMethod $urlTest -Headers $headers -Credential $cred
$response