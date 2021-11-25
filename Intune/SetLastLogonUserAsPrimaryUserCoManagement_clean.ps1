<#


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

function Patch_GraphURL($URL, $Body)
{
    Try
    {
        invoke-MSGraphRequest -HttpMethod PATCH -Url $URL -Content $Body
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
    
    $devices = $Response.value | Where-Object deviceEnrollmentType -eq "windowsCoManagement"
    
    #$device = $devices[-1]
   
    Foreach ($device in $devices)
    {
        $deviceID = $device.id
        $PrimaryUserURL = "https://graph.microsoft.com/$apiVersion/deviceManagement/managedDevices/$deviceID/users"
        $Response = Get_GraphURL($PrimaryUserURL)
        if ($Response.value)
        {
            Write-Host("Primary User found for device: " + $device.deviceName)
            continue
        }

        $deviceURL = "https://graph.microsoft.com/$apiVersion/deviceManagement/managedDevices/$deviceID/users/`$ref"
        if (!$device.usersLoggedOn)
        {
            Write-Host("Skiping empty users last logged on: " + $device.deviceName)
        }
        else
        {
            $userID = $device.usersLoggedOn[-1].userID
            $body = @"
                {"@odata.id":"https://graph.microsoft.com/beta/users/$userID"}
"@

            $Response = Post_GraphURL $deviceURL $body
            Write-Host("updated primary user to last user logged on for device: " + $device.deviceName)
        }

    }
    Read-Host 'Press Enter to exit…'
}


main