<#



Author:

#>

$apiVersion = "beta"

function ConnectToGraph
{
    if (Get-Module -ListAvailable -Name Microsoft.Graph.Intune) 
    {
    } 
    else {
        Write-Host "Microsoft.Graph.Intune Module does not exist, installing..."
        Install-Module -Name Microsoft.Graph.Intune
    }
    
    
    Connect-MSGraph
}


function Get_GraphURL($URL)
{
    for ($CallCount =0; $CallCount -lt 30; $CallCount++) 
    {
        Try # graph call will sometimes return 503 service unavailable due to dense requests.
        {
            $Response = invoke-MSGraphRequest -HttpMethod GET -Url $URL
			return $Response
        }
        Catch 
        {
			Write-Host($_)
            Continue
        }
    }
    return $null
}


function Post_GraphURL($URL, $Body)
{
    Try
    {
        invoke-MSGraphRequest -HttpMethod POST -Url $URL -Content $Body
        return $TRUE
    }
    Catch 
    {
        Write-Host($_)
        return $FALSE
    }
    return $FALSE
}



function main
{
    ConnectToGraph
    $URL = "https://graph.microsoft.com/beta/deviceManagement/detectedApps"

    $allDetectedApps = Get_GraphURL($URL)
    $AppList = $allDetectedApps.value
    $appNum = $allDetectedApps.value.Length
    
    $curIndex = 0
    $num = $allDetectedApps.'@odata.count'
    while ($allDetectedApps.'@odata.nextLink')
    {
        $allDetectedApps = Get_GraphURL($allDetectedApps.'@odata.nextLink')
        $AppList += $allDetectedApps.value
        $appNum += $allDetectedApps.value.Length
        
        $curIndex++
        $i1 = [int]($curIndex * 50 / $num * 100)
        Write-Progress -Activity "Detected Apps in Progress" -Status "$i1% Complete" -PercentComplete $i1;
    }

    $InterestedAppPool = 'Android Setup','mlp'
    
    $filteredAppList = $AppList | Where-Object -FilterScript {($_.displayName -in $InterestedAppPool)} | select id,displayName, version

    $output = @()
    $num = $AppList.Length
    $curIndex = 0
    foreach ($eachDetectedApp in $AppList)
    {
        $URL = “https://graph.microsoft.com/beta/deviceManagement/detectedApps/"+$eachDetectedApp.id+"/managedDevices"
        
        $CurrentDevices = Get_GraphURL($URL)# Get-DeviceManagement_DetectedApps_ManagedDevices -detectedAppId $eachDetectedApp.id #
        if ( (Get-Member -InputObject $CurrentDevices -Name "Value") -eq $null)
        {
            $DeviceList = $CurrentDevices
            $DeviceNum = 1
            $inner_num = 1
        }
        else
        {
            $DeviceList = $CurrentDevices.value
            $DeviceNum = $CurrentDevices.value.Length
            $inner_num = [int]($CurrentDevices.'@odata.count')
        }
    
        $inner_index = 0
        while ($CurrentDevices.'@odata.nextLink' -ne $null)
        {
            $CurrentDevices = Get_GraphURL($CurrentDevices.'@odata.nextLink')
            $DeviceList += $CurrentDevices.value
            $DeviceNum += $CurrentDevices.value.Length
        
            $i2 = [int]($inner_index * 50 / $inner_num * 100)
            Write-Progress -Activity "$eachDetectedApp.displayName: Detected App Device search in Progress" -Status "$i2% Complete" -PercentComplete $i2;
            $inner_index++
        }


        foreach ($eachdevice in $DeviceList)
        {
            $Result = "" | Select AppName, AppVersion, DeviceName, User, lastSync
            $Result.AppName = $eachDetectedApp.displayName
            $Result.AppVersion = $eachDetectedApp.version
            $Result.DeviceName = $eachdevice.deviceName
            $Result.User = $eachdevice.emailAddress
            $Result.lastSync = $eachdevice.lastSyncDateTime
            $output += $Result
        }
        $curIndex++
        $i3 = [int]($curIndex / $num * 100  )
        Write-Progress -Activity "Detected Apps Report in Progress" -Status "$i3% Complete" -PercentComplete $i3;
    }

    $output | Export-Csv -Path "C:\temp\AllDetectedApps.csv"
    $output | Format-Table
    

    Read-Host 'Press Enter to exit…'
}


main