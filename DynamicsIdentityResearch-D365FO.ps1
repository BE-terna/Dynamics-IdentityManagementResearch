[CmdletBinding()]
Param(
    [string]
    $aadDomain = "domain.si"
    ,
    [string]
    $d365foUrl = "https://???.sandbox.operations.dynamics.com"
    ,
    [string]
    $clientId = $env:CLIENTID
    ,
    [string]
    $clientSecret = $env:CLIENTSECRET
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

if (!$clientId -or $clientSecret) {
    $cred = Get-Credential -Message "Please enter Application/Client id and secret for $d365foUrl"
    $clientId = $cred.UserName
    $clientSecret = $cred.GetNetworkCredential().Password
}

$d365foPrefix = "$d365foUrl/data"

$authBody = @{
    grant_type = 'client_credentials'
    resource = $d365foUrl
    client_id = $clientId
    client_secret = $clientSecret
}
$authResponse = Invoke-RestMethod "https://login.microsoftonline.com/$aadDomain/oauth2/token" -Method Post -Body $authBody

$headers = @{
    "Accept" = "application/json"
    'Authorization' = "$($authResponse.token_type) $($authResponse.access_token)"
    'OData-Version' = '4.0'
    'OData-MaxVersion' = '4.0'
}
$restParams = @{
    Headers = $headers
    #Proxy = "http://localhost:8888"
    ResponseHeadersVariable = "rhv"
    UseBasicParsing = $true
    #MaximumRetryCount = 2
    #RetryIntervalSec  = 20
}

$sysUsers = Invoke-RestMethod -Method Get "$d365foPrefix/SystemUsers" -Body @{'$top' = 10; '$select' = 'UserID,Alias,UserName,Enabled' } @restParams
$sysUsers.value | ft

$createUserBody = @{
    'UserID' = 'testIDM';
    'Alias' = 'testIDM@eles.si';
    'UserName' = 'Testing IDM';
    "NetworkDomain" = "https://sts.windows.net/";
    'UserInfo_language' = 'sl';
    'Helplanguage' = 'en-US';
}
$createdUser = Invoke-RestMethod -Method Post "$d365foPrefix/SystemUsers" -Body (ConvertTo-Json $createUserBody) -ContentType application/json @restParams

"Test: Delete user"
$null = Invoke-RestMethod -Method Delete "$d365foPrefix/SystemUsers(UserID='testIDM')" @restParams

# list workers
$workers = Invoke-RestMethod -Method Get "$d365foPrefix/BaseWorkers" -Body @{'$top' = 10; '$select' = 'PersonnelNumber,PartyNumber,Name' } @restParams
$workers.value | ft

# list user-worker mapping
$personUsers = Invoke-RestMethod -Method Get "$d365foPrefix/PersonUsers" -Body @{'$top' = 10; 'select' = 'UserID,PartyNumber' } @restParams
$personUsers.value | ft


# add user-worker mapping
$personUserAddBody = @{
    UserId = 'teja.ticar';
    PartyNumber = '000015474';
    ValidFrom = '2020-12-31T23:00:00Z';
}
$personUserAddResponse = Invoke-RestMethod -ResponseHeadersVariable personUserAddResponseHeaders -Method Post "$d365foPrefix/PersonUsers" -Body (ConvertTo-Json $personUserAddBody) -ContentType application/json @restParams
$personUserAddResponse | ft
$createdEntityUrl = $personUserAddResponseHeaders.Location
$createdEntityUrl # /PersonUsers(UserId='teja.ticar',PartyNumber='000015474',ValidFrom=2020-12-31T23:00:00Z)

# get specific mapping 
$personUserDetail = Invoke-RestMethod -Method Get "$d365foPrefix/PersonUsers(UserId='teja.ticar',PartyNumber='000015474',ValidFrom=2020-12-31T23:00:00Z)" @restParams
$personUserDetail

# close user-worker mapping
$personUserCloseBody = @{
    ValidTo = '2023-12-31T23:59:59Z'
}
$null = Invoke-RestMethod -Method Patch "$d365foPrefix/PersonUsers(UserId='teja.ticar',PartyNumber='000015474',ValidFrom=2020-12-31T23:00:00Z)" -Body (ConvertTo-Json $personUserCloseBody) -ContentType application/json @restParams

# remove user-worker mapping
$null = Invoke-RestMethod -Method Delete "$d365foPrefix/PersonUsers(UserId='teja.ticar',PartyNumber='000015474',ValidFrom=2020-12-31T23:00:00Z)"  @restParams
