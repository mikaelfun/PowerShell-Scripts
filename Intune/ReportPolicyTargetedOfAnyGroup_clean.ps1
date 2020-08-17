<#
This script is used to display device configuration policies targetting to the provided group ID.
Based on graph URL: 
https://graph.microsoft.com/beta/deviceManagement/deviceConfiguration
https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/configID/assignments
https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations
https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies
https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations
https://graph.microsoft.com/beta/deviceAppManagement/targetedManagedAppConfigurations
https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections
https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections
https://graph.microsoft.com/beta/deviceAppManagement/windowsInformationProtectionPolicies
https://graph.microsoft.com/beta/deviceAppManagement/mdmWindowsInformationProtectionPolicies


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

function Get_ConfigurationPolicyOfGroupID($GroupID)
{
    Try
    {
        $curgroup = invoke-MSGraphRequest -HttpMethod GET -Url "https://graph.microsoft.com/beta/groups/$GroupID"
        $curgroupName = $curgroup.displayName
    }
    Catch 
    {
        Write-Host("Group not exist: " + $GroupID)
        Read-Host 'Please use correct Group ID, press enter to exit...'
        exit 1
    }
    
    
    $DeviceConfigURL = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations"
    $DeviceConfigList = Get_GraphURL($DeviceConfigURL)
    if ($DeviceConfigList -eq $null)
    {
        Write-Host("Error calling graph: '$DeviceConfigURL'")
        exit 1
    }

    
    $Output = @()
    $curIndex = 0
    $configNum = $DeviceConfigList.value.Length
    
    foreach ($eachConfig in $DeviceConfigList.value)
    {
        $configID = $eachConfig.id
        
        $DeviceConfigAssignmentURL = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$configID/assignments"
        $allAssignment = Get_GraphURL($DeviceConfigAssignmentURL)
        if ($allAssignment -eq $null)
        {
            Write-Host("Error calling graph: '$DeviceConfigAssignmentURL'")
            exit 1
        }
        
    
        if ($allAssignment.value)
        {
            $Excluded = $false
            foreach ($eachAssignment in $allAssignment.value)
            {
                if ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.exclusionGroupAssignmentTarget") #exclusion takes precedence
                {
                    if ($eachAssignment.target.groupId -eq $inputgroupID)
                    {
                        $Excluded = $true
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.groupAssignmentTarget") #include
                {
                    if (($eachAssignment.target.groupId -eq $inputgroupID) -and (-Not $Excluded))
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachConfig.displayName
                        $Result.PolicyType = $eachConfig.'@odata.type'.Substring(17)
                        $Result.AssignType = "Group: $curgroupName"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allDevicesAssignmentTarget") #all device
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachConfig.displayName
                        $Result.PolicyType = $eachConfig.'@odata.type'.Substring(17)
                        $Result.AssignType = "All Device"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allLicensedUsersAssignmentTarget") #all user
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachConfig.displayName
                        $Result.PolicyType = $eachConfig.'@odata.type'.Substring(17)
                        $Result.AssignType = "All User"
                        $Output += $Result
                    }
                }
                else
                {
                    $eachConfig.displayName
                    $eachAssignment.target.'@odata.type'
                }
            }
        }
        else
        {
            # do nothing
        }
        $curIndex ++
        $i = [int]($curIndex / $configNum * 100)
        Write-Progress -Activity "Configuration Policy Search in Progress" -Status "$i% Complete" -PercentComplete $i;
    }

    # Admin template profile

    $AdminTemplateURL = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations"
    $AdminTemplateList = Get_GraphURL($AdminTemplateURL)
    if ($AdminTemplateList -eq $null)
    {
        Write-Host("Error calling graph: '$AdminTemplateURL'")
        exit 1
    }

  
    $curIndex = 0
    $adminTemplateNum = $AdminTemplateList.value.Length
    
    foreach ($eachConfig in $AdminTemplateList.value)
    {
        $configID = $eachConfig.id
        
        $AdminTemplateAssignmentURL = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$configID/assignments"
        $allAssignment = Get_GraphURL($AdminTemplateAssignmentURL)
        if ($allAssignment -eq $null)
        {
            Write-Host("Error calling graph: '$AdminTemplateAssignmentURL'")
            exit 1
        }
        
    
        if ($allAssignment.value)
        {
            $Excluded = $false
            foreach ($eachAssignment in $allAssignment.value)
            {
                if ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.exclusionGroupAssignmentTarget") #exclusion takes precedence
                {
                    if ($eachAssignment.target.groupId -eq $inputgroupID)
                    {
                        $Excluded = $true
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.groupAssignmentTarget") #include
                {
                    if (($eachAssignment.target.groupId -eq $inputgroupID) -and (-Not $Excluded))
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachConfig.displayName
                        $Result.PolicyType = "Windows 10 Administrative Template"
                        $Result.AssignType = "Group: $curgroupName"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allDevicesAssignmentTarget") #all device
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachConfig.displayName
                        $Result.PolicyType = "Windows 10 Administrative Template"
                        $Result.AssignType = "All Device"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allLicensedUsersAssignmentTarget") #all user
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachConfig.displayName
                        $Result.PolicyType = "Windows 10 Administrative Template"
                        $Result.AssignType = "All User"
                        $Output += $Result
                    }
                }
                else
                {
                    $eachConfig.displayName
                    $eachAssignment.target.'@odata.type'
                }
            }
        }
        else
        {
            # do nothing
        }
        $curIndex ++
        $i = [int]($curIndex / $adminTemplateNum * 100)
        Write-Progress -Activity "Administrative Template Profile Search in Progress" -Status "$i% Complete" -PercentComplete $i;
    }

    

    return $Output
}

function Get_CompliancePolicyOfGroupID($GroupID)
{
    Try
    {
        $curgroup = invoke-MSGraphRequest -HttpMethod GET -Url "https://graph.microsoft.com/beta/groups/$GroupID"
        $curgroupName = $curgroup.displayName
    }
    Catch 
    {
        Write-Host("Group not exist: " + $GroupID)
        Read-Host 'Please use correct Group ID, press enter to exit...'
        exit 1
    }

    $DeviceComplianceURL = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies"
    $DeviceComplianceList = Get_GraphURL($DeviceComplianceURL)
    if ($DeviceComplianceList -eq $null)
    {
        Write-Host("Error calling graph: '$DeviceComplianceURL'")
        exit 1
    }

    
    $Output = @()
    $curIndex = 0
    $conplianceNum = $DeviceComplianceList.value.Length
    
    foreach ($eachCompliance in $DeviceComplianceList.value)
    {
        $complianceID = $eachCompliance.id
        
        $DeviceComplianceAssignmentURL = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/$complianceID/assignments"
        $allAssignment = Get_GraphURL($DeviceComplianceAssignmentURL)
        if ($allAssignment -eq $null)
        {
            Write-Host("Error calling graph: '$DeviceComplianceAssignmentURL'")
            exit 1
        }
        
    
        if ($allAssignment.value)
        {
            $Excluded = $false
            foreach ($eachAssignment in $allAssignment.value)
            {
                if ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.exclusionGroupAssignmentTarget") #exclusion takes precedence
                {
                    if ($eachAssignment.target.groupId -eq $inputgroupID)
                    {
                        $Excluded = $true
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.groupAssignmentTarget") #include
                {
                    if (($eachAssignment.target.groupId -eq $inputgroupID) -and (-Not $Excluded))
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachCompliance.displayName
                        $Result.PolicyType = $eachCompliance.'@odata.type'.Substring(17)
                        $Result.AssignType = "Group: $curgroupName"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allDevicesAssignmentTarget") #all device
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachCompliance.displayName
                        $Result.PolicyType = $eachCompliance.'@odata.type'.Substring(17)
                        $Result.AssignType = "All Device"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allLicensedUsersAssignmentTarget") #all user
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachCompliance.displayName
                        $Result.PolicyType = $eachCompliance.'@odata.type'.Substring(17)
                        $Result.AssignType = "All User"
                        $Output += $Result
                    }
                }
                else
                {
                    $eachConfig.displayName
                    $eachAssignment.target.'@odata.type'
                }
            }
        }
        else
        {
            # do nothing
        }
        $curIndex ++
        $i = [int]($curIndex / $conplianceNum * 100)
        Write-Progress -Activity "Compliance Policy Search in Progress" -Status "$i% Complete" -PercentComplete $i;
    }
    return $Output
}


function Get_ManagedDeviceAppConfigPolicyOfGroupID($GroupID)
{
    Try
    {
        $curgroup = invoke-MSGraphRequest -HttpMethod GET -Url "https://graph.microsoft.com/beta/groups/$GroupID"
        $curgroupName = $curgroup.displayName
    }
    Catch 
    {
        Write-Host("Group not exist: " + $GroupID)
        Read-Host 'Please use correct Group ID, press enter to exit...'
        exit 1
    }

    $ManagedDeviceAppConfigPolicyURL = "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations"
    $ManagedDeviceAppConfigPolicyList = Get_GraphURL($ManagedDeviceAppConfigPolicyURL)
    if ($ManagedDeviceAppConfigPolicyList -eq $null)
    {
        Write-Host("Error calling graph: '$ManagedDeviceAppConfigPolicyURL'")
        exit 1
    }

    
    $Output = @()
    $curIndex = 0
    $ManagedDeviceAppConfigPolicyNum = $ManagedDeviceAppConfigPolicyList.value.Length
    
    foreach ($eachAppConfig in $ManagedDeviceAppConfigPolicyList.value)
    {
        $AppConfigID = $eachAppConfig.id
        
        $ManagedDeviceAppConfigPolicyAssignmentURL = "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations/$AppConfigID/assignments"
        $allAssignment = Get_GraphURL($ManagedDeviceAppConfigPolicyAssignmentURL)
        if ($allAssignment -eq $null)
        {
            Write-Host("Error calling graph: '$ManagedDeviceAppConfigPolicyAssignmentURL'")
            exit 1
        }
        
    
        if ($allAssignment.value)
        {
            $Excluded = $false
            foreach ($eachAssignment in $allAssignment.value)
            {
                if ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.exclusionGroupAssignmentTarget") #exclusion takes precedence
                {
                    if ($eachAssignment.target.groupId -eq $inputgroupID)
                    {
                        $Excluded = $true
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.groupAssignmentTarget") #include
                {
                    if (($eachAssignment.target.groupId -eq $inputgroupID) -and (-Not $Excluded))
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachAppConfig.displayName
                        $Result.PolicyType = $eachAppConfig.'@odata.type'.Substring(17)
                        $Result.AssignType = "Group: $curgroupName"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allDevicesAssignmentTarget") #all device
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachAppConfig.displayName
                        $Result.PolicyType = $eachAppConfig.'@odata.type'.Substring(17)
                        $Result.AssignType = "All Device"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allLicensedUsersAssignmentTarget") #all user
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachAppConfig.displayName
                        $Result.PolicyType = $eachAppConfig.'@odata.type'.Substring(17)
                        $Result.AssignType = "All User"
                        $Output += $Result
                    }
                }
                else
                {
                    $eachConfig.displayName
                    $eachAssignment.target.'@odata.type'
                }
            }
        }
        else
        {
            # do nothing
        }
        $curIndex ++
        $i = [int]($curIndex / $ManagedDeviceAppConfigPolicyNum * 100)
        Write-Progress -Activity "Managed Device App Config Policy Search in Progress" -Status "$i% Complete" -PercentComplete $i;
    }
    return $Output
}



function Get_ManagedAppAppConfigPolicyOfGroupID($GroupID)
{
    Try
    {
        $curgroup = invoke-MSGraphRequest -HttpMethod GET -Url "https://graph.microsoft.com/beta/groups/$GroupID"
        $curgroupName = $curgroup.displayName
    }
    Catch 
    {
        Write-Host("Group not exist: " + $GroupID)
        Read-Host 'Please use correct Group ID, press enter to exit...'
        exit 1
    }

    $ManagedAppAppConfigPolicyURL = "https://graph.microsoft.com/beta/deviceAppManagement/targetedManagedAppConfigurations"
    $ManagedAppAppConfigPolicyList = Get_GraphURL($ManagedAppAppConfigPolicyURL)
    if ($ManagedAppAppConfigPolicyList -eq $null)
    {
        Write-Host("Error calling graph: '$ManagedAppAppConfigPolicyURL'")
        exit 1
    }

    
    $Output = @()
    $curIndex = 0
    $ManagedAppAppConfigPolicyNum = $ManagedAppAppConfigPolicyList.value.Length
    
    foreach ($eachAppConfig in $ManagedAppAppConfigPolicyList.value)
    {
        $AppConfigID = $eachAppConfig.id
        
        $ManagedAppAppConfigPolicyAssignmentURL = "https://graph.microsoft.com/beta/deviceAppManagement/targetedManagedAppConfigurations/$AppConfigID/assignments"
        $allAssignment = Get_GraphURL($ManagedAppAppConfigPolicyAssignmentURL)
        if ($allAssignment -eq $null)
        {
            Write-Host("Error calling graph: '$ManagedAppAppConfigPolicyAssignmentURL'")
            exit 1
        }
        
    
        if ($allAssignment.value)
        {
            $Excluded = $false
            foreach ($eachAssignment in $allAssignment.value)
            {
                if ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.exclusionGroupAssignmentTarget") #exclusion takes precedence
                {
                    if ($eachAssignment.target.groupId -eq $inputgroupID)
                    {
                        $Excluded = $true
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.groupAssignmentTarget") #include
                {
                    if (($eachAssignment.target.groupId -eq $inputgroupID) -and (-Not $Excluded))
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachAppConfig.displayName
                        $Result.PolicyType = "Targeted App Configurations"
                        $Result.AssignType = "Group: $curgroupName"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allDevicesAssignmentTarget") #all device
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachAppConfig.displayName
                        $Result.PolicyType = "Targeted App Configurations"
                        $Result.AssignType = "All Device"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allLicensedUsersAssignmentTarget") #all user
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachAppConfig.displayName
                        $Result.PolicyType = "Targeted App Configurations"
                        $Result.AssignType = "All User"
                        $Output += $Result
                    }
                }
                else
                {
                    $eachConfig.displayName
                }
            }
        }
        else
        {
            # do nothing
        }
        $curIndex ++
        $i = [int]($curIndex / $ManagedAppAppConfigPolicyNum * 100)
        Write-Progress -Activity "Targeted App Config Policy Search in Progress" -Status "$i% Complete" -PercentComplete $i;
    }
    return $Output
}



function Get_AppProtectionPolicyOfGroupID($GroupID)
{
    Try
    {
        $curgroup = invoke-MSGraphRequest -HttpMethod GET -Url "https://graph.microsoft.com/beta/groups/$GroupID"
        $curgroupName = $curgroup.displayName
    }
    Catch 
    {
        Write-Host("Group not exist: " + $GroupID)
        Read-Host 'Please use correct Group ID, press enter to exit...'
        exit 1
    }

    $MAMiOSURL = "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections"
    $MAMAndroidURL = "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections"
    $WIPWEURL = "https://graph.microsoft.com/beta/deviceAppManagement/windowsInformationProtectionPolicies"
    $WIPURL = "https://graph.microsoft.com/beta/deviceAppManagement/mdmWindowsInformationProtectionPolicies"


    $MAMiOSPolicyList = Get_GraphURL($MAMiOSURL)
    if ($MAMiOSPolicyList -eq $null)
    {
        Write-Host("Error calling graph: '$MAMiOSURL'")
        exit 1
    }
    $MAMAndroidPolicyList = Get_GraphURL($MAMAndroidURL)
    if ($MAMiOSPolicyList -eq $null)
    {
        Write-Host("Error calling graph: '$MAMAndroidURL'")
        exit 1
    }
    $WIPWEPolicyList = Get_GraphURL($WIPWEURL)
    if ($MAMiOSPolicyList -eq $null)
    {
        Write-Host("Error calling graph: '$WIPWEURL'")
        exit 1
    }
    $WIPPolicyList = Get_GraphURL($WIPURL)
    if ($MAMiOSPolicyList -eq $null)
    {
        Write-Host("Error calling graph: '$WIPURL'")
        exit 1
    }

    
    $Output = @()
    $iOSPolicyNum = $MAMiOSPolicyList.value.Length
    $AndroidPolicyNum = $MAMAndroidPolicyList.value.Length
    $WIPWEPolicyNum = $WIPWEPolicyList.value.Length
    $WIPPolicyNum = $WIPPolicyList.value.Length
    
    $curIndex = 0
    foreach ($eachPolicy in $MAMiOSPolicyList.value)
    {
        $PolicyID = $eachPolicy.id
        
        $AssignmentURL = "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections/$PolicyID/assignments"
        $allAssignment = Get_GraphURL($AssignmentURL)
        if ($allAssignment -eq $null)
        {
            Write-Host("Error calling graph: '$AssignmentURL'")
            exit 1
        }
        
    
        if ($allAssignment.value)
        {
            $Excluded = $false
            foreach ($eachAssignment in $allAssignment.value)
            {
                if ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.exclusionGroupAssignmentTarget") #exclusion takes precedence
                {
                    if ($eachAssignment.target.groupId -eq $inputgroupID)
                    {
                        $Excluded = $true
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.groupAssignmentTarget") #include
                {
                    if (($eachAssignment.target.groupId -eq $inputgroupID) -and (-Not $Excluded))
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachPolicy.displayName
                        $Result.PolicyType = "iOS MAM"
                        $Result.AssignType = "Group: $curgroupName"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allDevicesAssignmentTarget") #all device
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachPolicy.displayName
                        $Result.PolicyType = "iOS MAM"
                        $Result.AssignType = "All Device"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allLicensedUsersAssignmentTarget") #all user
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachPolicy.displayName
                        $Result.PolicyType = "iOS MAM"
                        $Result.AssignType = "All User"
                        $Output += $Result
                    }
                }
                else
                {
                    $eachConfig.displayName
                }
            }
        }
        else
        {
            # do nothing
        }
        $curIndex ++
        $i = [int]($curIndex / $iOSPolicyNum * 100)
        Write-Progress -Activity "iOS MAM Policy Search in Progress" -Status "$i% Complete" -PercentComplete $i;
    }

    $curIndex = 0
    foreach ($eachPolicy in $MAMAndroidPolicyList.value)
    {
        $PolicyID = $eachPolicy.id
        
        $AssignmentURL = "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections/$PolicyID/assignments"
        $allAssignment = Get_GraphURL($AssignmentURL)
        if ($allAssignment -eq $null)
        {
            Write-Host("Error calling graph: '$AssignmentURL'")
            exit 1
        }
        
        if ($allAssignment.value)
        {
            $Excluded = $false
            foreach ($eachAssignment in $allAssignment.value)
            {
                if ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.exclusionGroupAssignmentTarget") #exclusion takes precedence
                {
                    if ($eachAssignment.target.groupId -eq $inputgroupID)
                    {
                        $Excluded = $true
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.groupAssignmentTarget") #include
                {
                    if (($eachAssignment.target.groupId -eq $inputgroupID) -and (-Not $Excluded))
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachPolicy.displayName
                        $Result.PolicyType = "Android MAM"
                        $Result.AssignType = "Group: $curgroupName"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allDevicesAssignmentTarget") #all device
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachPolicy.displayName
                        $Result.PolicyType = "Android MAM"
                        $Result.AssignType = "All Device"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allLicensedUsersAssignmentTarget") #all user
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachPolicy.displayName
                        $Result.PolicyType = "Android MAM"
                        $Result.AssignType = "All User"
                        $Output += $Result
                    }
                }
                else
                {
                    $eachConfig.displayName
                }
            }
        }
        else
        {
            # do nothing
        }
        $curIndex ++
        $i = [int]($curIndex / $AndroidPolicyNum * 100)
        Write-Progress -Activity "Android MAM Policy Search in Progress" -Status "$i% Complete" -PercentComplete $i;
    }

    
    $curIndex = 0
    foreach ($eachPolicy in $WIPWEPolicyList.value)
    {
        $PolicyID = $eachPolicy.id
        
        $AssignmentURL = "https://graph.microsoft.com/beta/deviceAppManagement/windowsInformationProtectionPolicies/$PolicyID/assignments"
        $allAssignment = Get_GraphURL($AssignmentURL)
        if ($allAssignment -eq $null)
        {
            Write-Host("Error calling graph: '$AssignmentURL'")
            exit 1
        }
        
        if ($allAssignment.value)
        {
            $Excluded = $false
            foreach ($eachAssignment in $allAssignment.value)
            {
                if ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.exclusionGroupAssignmentTarget") #exclusion takes precedence
                {
                    if ($eachAssignment.target.groupId -eq $inputgroupID)
                    {
                        $Excluded = $true
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.groupAssignmentTarget") #include
                {
                    if (($eachAssignment.target.groupId -eq $inputgroupID) -and (-Not $Excluded))
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachPolicy.displayName
                        $Result.PolicyType = "WIP without enrollment"
                        $Result.AssignType = "Group: $curgroupName"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allDevicesAssignmentTarget") #all device
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachPolicy.displayName
                        $Result.PolicyType = "WIP without enrollment"
                        $Result.AssignType = "All Device"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allLicensedUsersAssignmentTarget") #all user
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachPolicy.displayName
                        $Result.PolicyType = "WIP without enrollment"
                        $Result.AssignType = "All User"
                        $Output += $Result
                    }
                }
                else
                {
                    $eachConfig.displayName
                }
            }
        }
        else
        {
            # do nothing
        }
        $curIndex ++
        $i = [int]($curIndex / $WIPWEPolicyNum * 100)
        Write-Progress -Activity "WIP without enrollment Policy Search in Progress" -Status "$i% Complete" -PercentComplete $i;
    }

    
    $curIndex = 0
    foreach ($eachPolicy in $WIPPolicyList.value)
    {
        $PolicyID = $eachPolicy.id
        
        $AssignmentURL = "https://graph.microsoft.com/beta/deviceAppManagement/mdmWindowsInformationProtectionPolicies/$PolicyID/assignments"
        $allAssignment = Get_GraphURL($AssignmentURL)
        if ($allAssignment -eq $null)
        {
            Write-Host("Error calling graph: '$AssignmentURL'")
            exit 1
        }
        
        if ($allAssignment.value)
        {
            $Excluded = $false
            foreach ($eachAssignment in $allAssignment.value)
            {
                if ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.exclusionGroupAssignmentTarget") #exclusion takes precedence
                {
                    if ($eachAssignment.target.groupId -eq $inputgroupID)
                    {
                        $Excluded = $true
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.groupAssignmentTarget") #include
                {
                    if (($eachAssignment.target.groupId -eq $inputgroupID) -and (-Not $Excluded))
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachPolicy.displayName
                        $Result.PolicyType = "WIP with enrollment"
                        $Result.AssignType = "Group: $curgroupName"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allDevicesAssignmentTarget") #all device
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachPolicy.displayName
                        $Result.PolicyType = "WIP with enrollment"
                        $Result.AssignType = "All Device"
                        $Output += $Result
                    }
                }
                elseif ($eachAssignment.target.'@odata.type' -eq "#microsoft.graph.allLicensedUsersAssignmentTarget") #all user
                {
                    if (-Not $Excluded)
                    {
                        $Result = "" | Select PolicyName,PolicyType,AssignType
                        $Result.PolicyName = $eachPolicy.displayName
                        $Result.PolicyType = "WIP with enrollment"
                        $Result.AssignType = "All User"
                        $Output += $Result
                    }
                }
                else
                {
                    $eachPolicy.displayName
                }
            }
        }
        else
        {
            # do nothing
        }
        $curIndex ++
        $i = [int]($curIndex / $WIPPolicyNum * 100)
        Write-Progress -Activity "WIP with enrollment Policy Search in Progress" -Status "$i% Complete" -PercentComplete $i;
    }

    return $Output
}

function main
{
    ConnectToGraph
    $inputgroupID = Read-Host -Prompt 'Input your Group ID'
    $inputReportPath = Read-Host -Prompt 'Input the path you want to generate the report(eg.c:\folder)'
    
    #$inputgroupID = "xxx"  # hard code for testing
    #$inputReportPath = "C:" # hard code for testing

    $ConfigReport = Get_ConfigurationPolicyOfGroupID($inputgroupID)
    $ComplianceReport = Get_CompliancePolicyOfGroupID($inputgroupID)
    $ManagedDeviceAppConifgReport = Get_ManagedDeviceAppConfigPolicyOfGroupID($inputgroupID)
    $ManagedAppAppConifgReport = Get_ManagedAppAppConfigPolicyOfGroupID($inputgroupID)
    $AppProtectionReport = Get_AppProtectionPolicyOfGroupID($inputgroupID)

    $SummaryReport = $ConfigReport + $ComplianceReport + $ManagedDeviceAppConifgReport + $ManagedAppAppConifgReport + $AppProtectionReport
    if (-Not $SummaryReport)
    {
        Read-Host 'No policy target for this group. Press Enter to exit…'
        exit 0
    }
    $SummaryReport | Export-Csv -Path "$inputReportPath\PolicyAssignmentReportofGroup.csv"
    
    $SummaryReport | Format-Table

    Read-Host 'Press Enter to exit…'
}

main