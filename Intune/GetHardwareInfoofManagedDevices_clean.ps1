<#


#>

$apiVersion = "beta"

function ConnectToGraph
{
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
    $URL = "https://graph.microsoft.com/$apiVersion/deviceManagement/managedDevices"
    $Response = Get_GraphURL($URL)
    $devices = $Response.value.id
    $Output = @()
    Foreach ($deviceID in $devices)
    {
        $deviceURL = "https://graph.microsoft.com/$apiVersion/deviceManagement/managedDevices/$deviceID`?select=deviceName,id,userPrincipalName,hardwareInformation"
        $Response = Get_GraphURL($deviceURL)
        $CurResult = "" | Select deviceName,id,userPrincipalName,operatingSystemEdition
        $CurResult.deviceName = $Response.deviceName
        $CurResult.id = $Response.id
        $CurResult.userPrincipalName = $Response.userPrincipalName
        $CurResult.operatingSystemEdition = $Response.hardwareInformation.operatingSystemEdition
        $Output += $CurResult
    }
    $Output | Format-Table
    $Output | Export-Csv -Path "C:\DeviceOSEditions.csv"
    Read-Host 'Press Enter to exit…'
}


main