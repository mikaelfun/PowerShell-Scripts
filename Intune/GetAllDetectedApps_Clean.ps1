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
    $inputReportPath = Read-Host -Prompt 'Input the path you want to generate the report(eg.c:\folder)'

    ConnectToGraph


    $URL = "https://graph.microsoft.com/beta/deviceManagement/manageddevices"

    $allDevices = (Get_GraphURL($URL)).value | select deviceName, id, ownerType

    $output = @()

    foreach ($eachDevice in $allDevices)
    {
        $URL = "https://graph.microsoft.com/beta/deviceManagement/manageddevices/"+$eachDevice.id+"?`$expand=detectedApps"
        $CurrentDevice = Get_GraphURL($URL)
        $DetectedApps = $CurrentDevice.detectedApps
        if (!$DetectedApps)
        {
            continue
        }
        foreach ($eachDetectedApp in $DetectedApps)
        {
            
            $Result = "" | Select Device, Ownership, AppName, AppVersion
            $Result.Device = $CurrentDevice.deviceName
            $Result.Ownership = $CurrentDevice.ownerType
            $Result.AppName = $eachDetectedApp.displayName
            $Result.AppVersion = $eachDetectedApp.version
            $output += $Result
        }
    }

    $output | Export-Csv -Path "$inputReportPath\AllDetectedApps.csv"
    $output | Format-Table
    

    Read-Host 'Press Enter to exit…'
}


main