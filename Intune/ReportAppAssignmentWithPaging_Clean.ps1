<#

This script is used to display Intune application assignment status.
Based on graph URL: 
https://graph.microsoft.com/beta/deviceAppManagement/mobileApps
and 
https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/appID/assignments

NA means no assignment is set.

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
    $yourUPN = "xxx.onmicrosoft.com"
    $password = ConvertTo-SecureString 'xxx' -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential ($yourUPN, $password)
    

    Connect-MSGraph -PSCredential $creds
    #>
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

function Get_ApplicationAssignmentStatus
{
    $AppListURL = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps"
    $AppListPage = Get_GraphURL($AppListURL)
    if ($AppListPage -eq $null)
    {
        Write-Host("Error calling graph: '$AppListURL'")
        exit 1
    }
    $AppList = $AppListPage.value
    $appNum = $AppListPage.value.Length
    
    while ($AppListPage.'@odata.nextLink')
    {
        $AppListPage = Get_GraphURL($AppListPage.'@odata.nextLink')
        $AppList += $AppListPage.value
        $appNum += $AppListPage.value.Length
    }

    $Output = @()
    $curIndex = 0
    
    foreach ($eachApp in $AppList)
    {
        $AppID = $eachApp.id
        $AppCreateDate = $eachApp.createdDateTime

        $AssignmentURL = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$AppID/assignments"
        $allAssignment = Get_GraphURL($AssignmentURL)
        
        if ($allAssignment -eq $null)
        {
            Write-Host("Error calling graph: '$AssignmentURL'")
            exit 1
        }
        $Result = "" | Select AppName,AppID,AppType,CreateDate,TargetGroup,Intent,Mode
        if ($allAssignment.value)
        {
            foreach ($eachAssignment in $allAssignment.value)
            {
                $Result = "" | Select AppName,AppID,AppType,CreateDate,TargetGroup,Intent,Mode
                if ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.exclusionGroupAssignmentTarget") #exclusion takes precedence
                {
                    $groupid = $eachAssignment.target.groupId
                    $GroupURL = "https://graph.microsoft.com/beta/groups/$groupid"
                    $thisGroup = Get_GraphURL($GroupURL)
        
                    if ($thisGroup -eq $null)
                    {
                        Write-Host("Error calling graph: '$GroupURL'")
                        exit 1
                    }

                    $Result.TargetGroup = $thisGroup.displayName
                    $Result.Mode = "Exclude"
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allLicensedUsersAssignmentTarget") #all user
                {
                    $Result.TargetGroup = "All User"
                    $Result.Mode = "Include"
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allDevicesAssignmentTarget") #all device
                {
                    $Result.TargetGroup = "All Device"
                    $Result.Mode = "Include"
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.groupAssignmentTarget") #group based
                {
                    $groupid = $eachAssignment.target.groupId
                    $GroupURL = "https://graph.microsoft.com/beta/groups/$groupid"
                    $thisGroup = Get_GraphURL($GroupURL)
        
                    if ($allAssignment -eq $null)
                    {
                        Write-Host("Error calling graph: '$GroupURL'")
                        exit 1
                    }

                    $Result.TargetGroup = $thisGroup.displayName
                    $Result.Mode = "Include"
                }
                else
                {
                    Write-Host("Unknown Assignment type!!")
                    $Result.TargetGroup = "Unknown"
                    $Result.Mode = "Unknown"
                    $eachApp.displayName
                    $eachAssignment.target.'@odata.type'
                }
                $Result.AppID = $AppID
                $Result.CreateDate = $AppCreateDate
                $Result.AppName = $eachApp.displayName
                $Result.AppType = $eachApp.'@odata.type'.Substring(17)
                $Result.Intent = $eachAssignment.intent
                $Output += $Result
            }
        }
        else
        {
            $Result.AppName = $eachApp.displayName
            $Result.AppType = $eachApp.'@odata.type'.Substring(17)
            $Result.TargetGroup = "NA"
            $Result.AppID = $AppID
            $Result.CreateDate = $AppCreateDate
            $Result.Intent = "NA"
            $Result.Mode = "NA"
            $Output += $Result
        }
        $curIndex ++
        $i = [int]($curIndex / $appNum * 100)
        Write-Progress -Activity "App Search in Progress" -Status "$i% Complete" -PercentComplete $i;
    }

    return $Output
}

function main
{
    ConnectToGraph
    $inputReportPath = Read-Host -Prompt 'Input the path you want to generate the report(eg.c:\folder)'
    $report = Get_ApplicationAssignmentStatus
    $report | Export-Csv -Path "$inputReportPath\AppAssignmentReportWithAppIDandCreateDate.csv"
    $report | Format-Table
    Read-Host 'Press Enter to exit…'
}

main