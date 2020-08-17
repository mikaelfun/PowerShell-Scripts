<#

This script is used to bulk add devices to specific device security group.
Based on graph URL: 
https://graph.microsoft.com/beta/devices
https://graph.microsoft.com/v1.0/groups/$inputgroupID/members

This script assumes that:
1. Device names are stored in Sheet1 in xlsx file
2. Device names are located from A1 to An

This script takes in 2 parameters:
1. xlsx file full path
2. target group ID

Author:
Kun Fang

#>

$apiVersion = "V1.0" # "beta"

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


function ImportDevicesFromXLSX($filePath)
{
    $excel = new-object -com excel.application
    $wb = $excel.workbooks.open($filePath)
    $WorkSheet = $wb.Sheets.Item("Sheet1")
    $WorksheetRange = $WorkSheet.UsedRange
    Write-Host("Reading Excel row count...")
    $RowCount = $WorksheetRange.Rows.Count
    Write-Host("Found $RowCount devices in excel")
    $OutputDeviceNames = @()

    for ($i = 1; $i -le $RowCount; $i++)
    {
        $OutputDeviceNames += $WorkSheet.cells.Item($i,1).text
    }

    $excel.Workbooks.Close()
    return $OutputDeviceNames
}


function GetDeviceObjectIdByDisplayName($DisplayName)
{
    $DeviceURL = "https://graph.microsoft.com/$apiVersion/devices`?`$filter=startswith(displayName,'$DisplayName')"

    $device = Get_GraphURL($DeviceURL)
    if ($device -eq $null -or -Not $device.value)
    {
        Write-Host("Device $DisplayName not found in Azure AD devices!")
        return $null
    }

    $DeviceObjectId = $device.value[0].id # [0] in case multiple results with same displayName
    return $DeviceObjectId
}


function BulkAddDevices($DeviceList, $inputgroupID)
{
    $GroupURL = "https://graph.microsoft.com/$apiVersion/groups/$inputgroupID"

    $groupObject = Get_GraphURL $GroupURL
    if ($groupObject -eq $null)
    {
        Write-Host("Group with ID $inputgroupID not found!")
        exit 1
    }
    $GroupMemberAddURL = "https://graph.microsoft.com/$apiVersion/groups/$inputgroupID/members/`$ref"
    foreach ($EachDevice in $DeviceList)
    {
        $objID = GetDeviceObjectIdByDisplayName($EachDevice)
        if ($objID -eq $null)
        {
            continue
        }
        $Body = @"
        {
            "@odata.id": "https://graph.microsoft.com/$apiVersion/directoryObjects/$objID"
        }
"@
        $result = Post_GraphURL $GroupMemberAddURL $Body
        if ($result -eq $TRUE)
        {
            Write-Host("Added $EachDevice to target group")
        }
        else
        {
            Write-Host("Failed to add $EachDevice to target group")
        }
    }
}

function main
{
    ConnectToGraph
    
    $inputgroupID = Read-Host -Prompt 'Input your Group ID'
    $inputfilePath = Read-Host -Prompt 'Input the xlsx file full path (eg. C:\test.xlsx)'

    $DeviceList = ImportDevicesFromXLSX $inputfilePath
    
    BulkAddDevices $DeviceList $inputgroupID
    Read-Host 'Press Enter to exit…'
}


main