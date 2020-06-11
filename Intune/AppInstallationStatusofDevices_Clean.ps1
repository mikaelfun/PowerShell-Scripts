<#
This script is used to get the target app installation status of devices enrolled by users within a target user group.
Input: 
App Name
Group ID

Output:
App installation status table

Based on graph API: 
Get-IntuneManagedDevice
"https://graph.microsoft.com/beta/users/$userID/mobileAppIntentAndStates/$deviceID"

Author:
Kun Fang

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
    <#
    $yourUPN = "xxx@xxx.onmicrosoft.com"
    $password = ConvertTo-SecureString 'xxxxx' -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential ($yourUPN, $password)
    #>

    #Connect-MSGraph -PSCredential $creds
    
    connect-MSGraph
}




function Get_IntuneManagedDeviceWithRetry($user_id)
{
    for ($CallCount =0; $CallCount -lt 30; $CallCount++) 
    {
        Try # graph call will sometimes return 503 service unavailable due to dense requests.
        {
            $allDeviceIDforthisUser = Get-IntuneManagedDevice | Get-MSGraphAllPages | Where-Object {$_.userId -eq "$user_id"} | select id, userId, deviceName
            return $allDeviceIDforthisUser
        }
        Catch 
        {
            Write-Host($_)
            Continue
        }
    }
    Write-Host("Calling Get_IntuneManagedDeviceWithRetry Failed!")
    return "NULL"
}


function Get_InstallStatus($userID, $deviceID)
{
    $URL = "https://graph.microsoft.com/beta/users/$userID/mobileAppIntentAndStates/$deviceID"
    $result = invoke-MSGraphRequest -HttpMethod GET -Url $URL
    return $result
}

function main
{
    ConnectToGraph
    
    $TargetGroup = Read-Host -Prompt 'Input your Group ID'
    

    $TargetApp = Read-Host -Prompt 'Input your App Name'


    $groupMembers = Get-Groups_Members -groupId $TargetGroup -Select id, userPrincipalName | Get-MSGraphAllPages

    Write-Output("")

    $Output = @()

    foreach ($eachUser in $groupMembers)
    {
        $curDeviceList = Get_IntuneManagedDeviceWithRetry $eachUser.id

        foreach ($eachDevice in $curDeviceList)
        {
            $curAppInstallStatus = Get_InstallStatus $eachUser.id $eachDevice.id
            $appMatch = $curAppInstallStatus.mobileAppList | Where-Object {$_.displayName -eq $TargetApp}
            if ($appMatch)
            {
                $Result = "" | Select App,User,Device,InstallStatus
                $Result.App = $appMatch.displayName
                $Result.User = $eachUser.userPrincipalName
                $Result.Device = $eachDevice.deviceName
                $Result.InstallStatus = $appMatch.installState
                $Output += $Result
            }
        }
    }
    
    $Output | Format-Table
    
    Read-Host 'Press Enter to exit…'
}

main



