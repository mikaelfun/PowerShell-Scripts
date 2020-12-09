<#
Duplicate existing WIP/WIP MDM policy
Major settings and network boundaries can be duplicated

Notes:
Exempt apps cannot be duplicated because graph response is null
Applocker protectedapps cannot be duplicated because graph response does not contain
Assignments cannot be duplicated

Author:
Kun Fang

#>

$apiVersion = "V1.0" # "beta"
#$apiVersion = "beta"

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


function Duplicate_WIPMDM()
{
    $Resource = "deviceAppManagement/mdmWindowsInformationProtectionPolicies"
    $URL = "https://graph.microsoft.com/$apiVersion/$($Resource)"

    $Response = Get_GraphURL($URL)
    
    $i = 0

    foreach ($eachWIP in $Response.value)
    {     
        $k = $i+1
        Write-Host ("$k" + ": " + $eachWIP.displayName)
        $i++
    }
    
    Write-Host ("")
    $j = Read-Host -Prompt "Select a WIP MDM policy number to duplicate from, enter 0 to skip"

    if ($j -eq 0)
    {
        return
    }

    $WIPbody = $Response.value[$j-1]

    $WIPbody.PSObject.properties.remove('createdDateTime')
    $WIPbody.PSObject.properties.remove('lastModifiedDateTime')


    $WIPbody.displayName = $WIPbody.displayName + " copy"

    $json = $WIPbody | ConvertTo-Json -Depth 5

    $body =  @"

            $json

"@

    $result = Post_GraphURL $URL $body
    
    Write-Host ("")
    Write-Host ("MDM WIP Policy Duplicated!")
    Write-Host ("")
}


function Duplicate_WIP()
{
    $Resource = "deviceAppManagement/WindowsInformationProtectionPolicies"
    $URL = "https://graph.microsoft.com/$apiVersion/$($Resource)"

    $Response = Get_GraphURL($URL)
    
    $i = 0

    foreach ($eachWIP in $Response.value)
    {     
        $k = $i+1
        Write-Host ("$k" + ": " + $eachWIP.displayName)
        $i++
    }
    
    Write-Host ("")
    $j = Read-Host -Prompt "Select a WIP policy number to duplicate from, enter 0 to skip"
    
    if ($j -eq 0)
    {
        return
    }

    $WIPbody = $Response.value[$j-1]

    $WIPbody.PSObject.properties.remove('createdDateTime')
    $WIPbody.PSObject.properties.remove('lastModifiedDateTime')


    $WIPbody.displayName = $WIPbody.displayName + " copy"

    $json = $WIPbody | ConvertTo-Json -Depth 5

    $body =  @"

            $json

"@

    $result = Post_GraphURL $URL $body
    Write-Host ("")
    Write-Host ("WIP Policy Duplicated!")
    Write-Host ("")
}

function main
{
    ConnectToGraph
   
    Duplicate_WIPMDM
    Duplicate_WIP
    Read-Host 'Press Enter to exit…'
}


main