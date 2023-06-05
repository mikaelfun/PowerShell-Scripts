<# 

Reference:
https://docs.microsoft.com/en-us/graph/api/bitlocker-list-recoverykeys?view=graph-rest-beta&tabs=http

# Input: device group ID targeted by BitLocker policy.
# Output: Devices in the group that don't have any recovery key uploaded in AAD.

#>


function ConnectToGraph
{
    if (Get-Module -ListAvailable -Name Microsoft.Graph.Intune) 
    {
    } 
    else {
        Write-Host "Microsoft.Graph.Intune Module does not exist, installing..."
        Install-Module -Name Microsoft.Graph.Intune
    }

    $yourUPN = "xxxxxx"
    $password = ConvertTo-SecureString 'xxxx' -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential ($yourUPN, $password)

    #Connect-MSGraph -PSCredential $creds
    
    Connect-MSGraph
}


function GetBitlockerRecoveryKeyList 

{
    # AAD Graph Authentication
    $tenantid = "xxx"
    $secret = "xxx"
    $clientid = "xxx"
    $scope = "https://graph.microsoft.com/.default"
    $username="xxx"
    $password = "xxx"
    $grant_type="password"
    $Cred  = @{grant_type=$grant_type;client_id=$clientid;scope=$scope;username=$username;password=$password;client_secret=$secret}
    $oauth = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantid/oauth2/v2.0/token" -Body $Cred


    # Call BitLocker Graph API to get Recovery Key info.
    $Header= @{'Authorization'="$($oauth.token_type) $($oauth.access_token)";
    "ocp-client-name"="My Friendly Client";"ocp-client-version"="1.2"}

    $graphApiVersion = "beta"
    $Resource = "informationProtection/bitlocker/recoveryKeys"

    #CAll Graph API to trigger BitLocker rotation for devices
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
    Write-Verbose $uri
    $Data = Invoke-RestMethod -Headers $Header -Uri $uri -Method Get
    $DevicesResponse = Invoke-RestMethod -Headers $Header -Uri $uri -Method Get


    $DevicesNextLink = $DevicesResponse."@odata.nextLink"

    $ALLDevices = $DevicesResponse.value

    while ($DevicesNextLink -ne $null)
    {
        $DevicesResponse = (Invoke-RestMethod -Uri $DevicesNextLink –Headers $Header –Method Get)
        $DevicesNextLink = $DevicesResponse."@odata.nextLink"
        $ALLDevices += $DevicesResponse.value
    }


    return $ALLDevices

}

function main 
{
    ConnectToGraph
    Update-MSGraphEnvironment -SchemaVersion 'beta'
    
    $TargetGroup = Read-Host -Prompt 'Input your Group Object ID'
    #$TargetGroup = "xxx"
    $groupMembers = Get-Groups_Members -groupId "$TargetGroup" | Get-MSGraphAllPages
    
    $BitlockerDeviceList = GetBitlockerRecoveryKeyList

    $NoBitLockerKey = @()

    foreach ($eachAADDevice in $groupMembers)
    {
        if ($eachAADDevice.DeviceID -notin $BitlockerDeviceList.deviceId)

        {
            $NoBitLockerKey += $eachAADDevice
        }
    }
    
    $NoBitLockerKey | select displayName, deviceId | format-table
    #$NoBitLockerKey | Export-Csv  -Path C:\Temp\NoBitlockerDeviceList.csv
}

main