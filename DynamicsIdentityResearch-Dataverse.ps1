[CmdletBinding()]
Param(
    [string]
    $aadDomain = "domain.si"
    ,
    [string]
    $d365foUrl = "https://???.crm4.dynamics.com"
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

$dataversePrefix = "$dataverseUrl/api/data/v9.2"

$authBody = @{
    grant_type = 'client_credentials'
    resource = $dataverseUrl
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

$bu = Invoke-RestMethod -Method Get "$dataversePrefix/businessunits" -Body @{'$top' = 10; '$select' = 'name,businessunitid,_parentbusinessunitid_value' } @restParams
$bu.value

$sysUsers = Invoke-RestMethod -Method Get "$dataversePrefix/systemusers" -Body @{'$top' = 10; '$select' = 'fullname,systemuserid,domainname,_businessunitid_value' } @restParams
$sysUsers.value | ft

$testBu = $bu.value[0]

$teamsBody = @{
    '$top' = 10;
    '$select' = 'name,teamid';
    # '$filter' = "_businessunitid_value eq '$($testBu.businessunitid)'";
    '$filter' = "_businessunitid_value ne 58742692-7e6c-ec11-8943-000d3a46c0f0";
    #'$filter' = 'teamtype eq 0' # 0 = Owner, 1 = Access https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/reference/team?view=dataverse-latest#properties
}

$teams = Invoke-RestMethod -Method Get "$dataversePrefix/teams" -Body $teamsBody @restParams
$teams.value

$testUser = $sysUsers.value[0]
$testTeam = $teams.value[0]

"Test: Team details, members for '$($testTeam.name)'"
# https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/web-api-functions-actions-sample
$teamDetails = Invoke-RestMethod -Method Get "$dataversePrefix/teams($($testTeam.teamid))" @restParams

$teamMembersBody = @{
    '$select' = 'name';
    '$count' = 'true';
    '$expand' = 'teammembership_association($select=fullname,systemuserid,domainname)';
}
$teamDetailsWithExpandedMembers = Invoke-RestMethod -Method Get "$dataversePrefix/teams($($testTeam.teamid))" -Body $teamMembersBody @restParams
$teamDetailsWithExpandedMembers
$teamDetailsWithExpandedMembers.teammembership_association.Length
$teamDetailsWithExpandedMembers.teammembership_association | ft

"Test: AddMembersTeam: Add user '$($testUser.domainname)' to the team '$($testTeam.name)'"
$teamAddUserBody = @{
    'Members' = @(
        @{
            'systemuserid' = $testUser.systemuserid;
        }
    )
} 
$null = Invoke-RestMethod -Method Post "$dataversePrefix/teams($($testTeam.teamid))/Microsoft.Dynamics.CRM.AddMembersTeam" -Body (ConvertTo-Json $teamAddUserBody) -ContentType application/json @restParams

"Test: RemoveMembersTeam: Remove user '$($testUser.domainname)' from the team '$($testTeam.name)'"
$teamRemoveUserBody = @{
    'Members' = @(
        @{
            'systemuserid' = $testUser.systemuserid;
        }
    )
}
$null = Invoke-RestMethod -Method Post "$dataversePrefix/teams($($testTeam.teamid))/Microsoft.Dynamics.CRM.RemoveMembersTeam " -Body (ConvertTo-Json $teamRemoveUserBody) -ContentType application/json @restParams



