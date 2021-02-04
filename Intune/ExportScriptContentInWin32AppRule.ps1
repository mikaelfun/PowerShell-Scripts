
<#PSScriptInfo

.VERSION 1.0

.GUID eb6ab125-3a78-4221-807d-926d88d78a4d

.AUTHOR Yihzhu@microsoft.com

.COMPANYNAME 

.COPYRIGHT 

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

#Requires -Module Microsoft.Graph.Intune

<# 

.DESCRIPTION 
 Script used to export script insert in Intune Win32 app 

#> 

Param()


###################################################
#
#
#This script is used to export Scirpt insert in Intune Win32 app which used for detection/requirement rule
#
#
##################################################


#detect if Intune PowerShell module installed
 if (Get-Module -ListAvailable -Name Microsoft.Graph.Intune) 
    {
        
    } 
    else {
        Write-Host "Microsoft.Graph.Intune Module does not exist, installing..."
        Install-Module -Name Microsoft.Graph.Intune 
    }

#connect to Intune Graph. Need to manually enter credential
connect-MSGraph

#Win32 app Id, you can find it in the address bar when accessing Win32 app on MEM portal like https://endpoint.microsoft.com/#blade/Microsoft_Intune_Apps/SettingsMenu/0/appId/{id}
$WinAppId = Read-Host “Please put the Win32 app id”

$winAppConfiguraiton = @()

#get App info
$winAppConfiguraiton = Get-DeviceAppManagement_MobileApps -mobileAppId $WinAppId 


if($winAppConfiguraiton)
{
    $appName = $winAppConfiguraiton.displayName
    Write-host "Win32 app name:$appName"

    if($winAppConfiguraiton.rules)
    {

        
        $winAppConfiguraiton.rules | ForEach-Object {
        
        $ruleType = $PSItem.ruleType
        write-host "get script for rule: $ruleType"

                if($PSItem.scriptContent)
                {
                   $scriptContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($PSItem.scriptContent))

                    Write-Host "Script content: $scriptContent"
                    Write-Host

                     #export script as PS1 file to C:\temp folder
                             $path = "c:\temp"
                             $append = "_$(Get-Date -f m)"
                     
                             if(! (Test-Path -Path $path -PathType Container)){
                                            New-Item -Path $path -ItemType Directory
                                }

                        
                          
                                  $scriptContent | Out-File -FilePath $(Join-Path -Path $path -ChildPath "$($appName+$ruleType+$append).ps1")
                                  Write-Host ("PS1 file created at {0} for rule $ruleType..." -f $path, $append)
                                  Write-Host
                     }

                   
                      write-Host
        }  
                      Write-Host
        }
        else{
         Write-Host "This app is not Win32 app"
        }
    
    }
    else
    {
        Write-Host "cannot find specific app"
    }




