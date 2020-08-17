
function Read-HostYesNo ([string]$Title, [string]$Prompt, [boolean]$Default)
{
    # Set up native PowerShell choice prompt with Yes and No
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    
    # Set default option
    $defaultChoice = 0 # first choice = Yes
    if ($Default -eq $false) { # only if it was given and is false
        $defaultChoice = 1 # second choice = No
    }

    $result = $Host.UI.PromptForChoice($Title, $Prompt, $options, $defaultChoice)
    
    if ($result -eq 0) { # 0 is yes
        return $true
    } else {
        return $false
    }
}
####################################################

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
    $yourUPN = "xxx@kunintune.onmicrosoft.com"
    $password = ConvertTo-SecureString 'xxxxx' -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential ($yourUPN, $password)
    #>

    #Connect-MSGraph -PSCredential $creds
    
    connect-MSGraph
}

########################################################

function filterDevicebyserialNumber ($serialnumbers, $personalDevice)
{
    $FinallOutput = @()
       foreach($serialnumber in $serialnumbers)
       {
         $device = $personalDevice | Where-Object {$_.serialNumber -eq $serialnumber.Serialnumber}
         $FinallOutput += $device
       }

    return $FinallOutput
}
#######################################################



########################################################


#######################################################

#ConnectToGraph
connect-MSGraph
#read CSv
# When entering a CSV path, "" is unnecessary even if there is a space in the file path.
$CSVPath = Read-Host("CSV Enter the file path")
$CSVDevices = Import-Csv -Path $CSVPath -Header "Serialnumber"


#all Autopilot devices
$Allpersonaldevices = Get-IntuneManagedDevice |Where-Object {$_.managedDeviceOwnerType -eq "personal"} | Get-MSGraphAllPages | select id, managedDeviceOwnerType,serialNumber
 

$matchdevice = filterDevicebyserialNumber -serialnumbers $CSVDevices -personalDevice $Allpersonaldevices| Sort-Object -Property id -Unique

$matchdevice | Format-Table



if($matchdevice)
{
$displayTable = Read-HostYesNo -Prompt "Do you want to modify above device's ownership to corporate?" -Default $true

  if ($displayTable)
    {
    foreach ($Device in $matchdevice)
    {
     Update-DeviceManagement_ManagedDevices -managedDeviceId $Device.id -managedDeviceOwnerType company
     Write-Host "device with serila number" + $Device.serialNumber + " is updated to corporated"
    }


    }
}else 
{
Write-Host "no device match"
}
