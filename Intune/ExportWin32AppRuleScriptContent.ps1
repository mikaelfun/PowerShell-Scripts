
connect-MSGraph


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




