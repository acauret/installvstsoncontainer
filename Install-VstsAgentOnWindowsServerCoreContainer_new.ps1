param (

    [Parameter(Mandatory=$true,
               HelpMessage="Name of the Visual Studio Team Services Account (VSTS), e.g. https://<VSTSAccountName>.visualstudio.com")]
    [ValidateNotNullOrEmpty()]
    [string]$VSTSAccountName,

    [Parameter(Mandatory=$true,
               HelpMessage="PAT token generated by the user who is configuring the container to be used by VSTS.")]
    [ValidateNotNullOrEmpty()]
    [string]$PATToken,

    [Parameter(Mandatory=$false,
               HelpMessage="Prefix of the name of the agent shown on the VSTS portal.")]
    [ValidateNotNullOrEmpty()]
    [string]$AgentNamePrefix,

    [Parameter(Mandatory=$false,
               HelpMessage="Name of the Agent pool. It defaults to the ""Default"" pool when not defined.")]
    [ValidateNotNullOrEmpty()]
    [string]$PoolName="Default",

    [Parameter(Mandatory=$false,
    HelpMessage="Use this parameter to decide if a specific version of Terraform should be installed.")]
    [ValidateNotNullOrEmpty()]
    [string]$SpecificVersion   = "0.14.6"

)

#region Functions

    function Install-PowerShellModules {
        param (
            [array]$RequiredModules
        )

        if (-not (Get-PackageProvider -Name "Nuget" -ListAvailable -ErrorAction SilentlyContinue))
        {
            $NewPackageProvider = Find-PackageProvider -Name "Nuget"
            $NewPackageProviderVersion = $NewPackageProvider.Version.ToString()
            Write-Output "Installing Nuget package provider ($NewPackageProviderVersion)..."

            Install-PackageProvider -Name Nuget -Force -Confirm:$false | Out-Null

            Write-Output "Waiting 10 seconds..."
            Start-Sleep -Seconds 10
        }

        foreach ($Module in $RequiredModules)
        {
            if (-not (Get-Module $Module -ErrorAction SilentlyContinue))
            {
                $NewModule = Find-Module $Module
                $NewModuleVersion = $NewModule.Version.ToString()

                Write-Output "Installing $Module ($NewModuleVersion) module..."
                
                Install-Module -Name $Module -Force -Confirm:$false -SkipPublisherCheck
            }
        }

    }


    function Install-Microsoft365Dsc {
        Write-Output "Checking for Microsoft365Dsc module"


        if (-not (Get-PackageProvider -Name "Nuget" -ListAvailable -ErrorAction SilentlyContinue))
        {
            $NewPackageProvider = Find-PackageProvider -Name "Nuget"
            $NewPackageProviderVersion = $NewPackageProvider.Version.ToString()
            Write-Output "Installing Nuget package provider ($NewPackageProviderVersion)..."

            Install-PackageProvider -Name Nuget -Force -Confirm:$false | Out-Null

            Write-Output "Waiting 10 seconds..."
            Start-Sleep -Seconds 10
        }        
        #
        $psGallery = Find-Module Microsoft365Dsc
        $localModule = Get-Module Microsoft365Dsc -List

        if ($localModule.Version -ne $psGallery.Version)
        {
            $M365DscPath = 'C:\Program Files\WindowsPowerShell\Modules\Microsoft365Dsc'
            if (Test-Path -Path $M365DscPath)
            {
                Write-Output "Removing old version of Microsoft365Dscdule"
                Remove-Item -Path $M365DscPath -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\AzureAD' -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\AzureADPreview' -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\DSCParser' -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\ExchangeOnlineManagement' -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Microsoft.Graph.Authentication' -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Microsoft.Graph.Groups.Planner' -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Microsoft.Graph.Identity.ConditionalAccess' -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Microsoft.Graph.Intune' -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Microsoft.Graph.Planner' -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Microsoft.PowerApps.Administration.PowerShell' -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\MicrosoftTeams' -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\MSCloudLoginAssistant' -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\ReverseDSC' -Force -Recurse -ErrorAction SilentlyContinue
                Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\SharePointPnPPowerShellOnline' -Force -Recurse -ErrorAction SilentlyContinue
            }
            

            Write-Output "Installing Microsoft365Dsc"
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
            Install-Module -Name Microsoft365Dsc -AllowClobber
        }
    }

    function Install-Terraform {

        param (

        [Parameter(Mandatory=$false,
                   HelpMessage="Use this parameter to decide if the absolute latest or the latest stable Terraform release should be installed.")]
        [ValidateNotNullOrEmpty()]
        [bool]$SkipNonStableReleases = $true,

        [Parameter(Mandatory=$false,
                   HelpMessage="Use this parameter to decide if a specific version should be installed.")]
        [ValidateNotNullOrEmpty()]
        [string]$SpecificVersion   = ""      

        )

        # Get the list of available Terraform versions
        $Response = Invoke-WebRequest -Uri "https://releases.hashicorp.com/terraform" -UseBasicParsing

        # Find the latest version
        if ($SkipNonStableReleases -eq $true)
        {
            $Links = $Response.Links | Where-Object {$_.href.Split("/")[2] -match "^(\d|\d\d)\.(\d|\d\d)\.(\d|\d\d)$"}
            $LatestTerraformVersion = $Links[0].href.Split("/")[2]
        }
        else
        {
            $LatestTerraformVersion = $Response.Links[1].href.Split("/")[2]
        }
        #
        # If the SpecificVersion is defined then set it
        If ([string]::IsNullorEmpty($SpecificVersion)){
          $Version = $LatestTerraformVersion
        }
        else {
          $Links = $Response.Links | Where-Object {$_.href -match $SpecificVersion} 
          $LatestTerraformVersion = $Links[0].href.Split("/")[2]
          $Version = $LatestTerraformVersion
        }


        # Find the download URL for the latest version
        $Response = Invoke-WebRequest -Uri "https://releases.hashicorp.com/terraform/$Version" -UseBasicParsing
        $RelativePath = ($Response.Links | Where-Object {$_.href -like "*windows_amd64*"}).href

        # URL will be similar to this: "https://releases.hashicorp.com/terraform/0.11.8/terraform_0.11.8_windows_amd64.zip"
        $URL = "https://releases.hashicorp.com$RelativePath"

        # Create folder
        $FileName = Split-Path $url -Leaf
        $FolderPath = "C:\terraform"
        $FilePath = "$FolderPath\$FileName"
        New-Item -ItemType Directory -Path $FolderPath -ErrorAction SilentlyContinue | Out-Null

        # Download and extract Terraform, remove the temporary zip file
        Write-Output "Downloading Terraform ($Version) to $FolderPath..."
        Invoke-WebRequest -Uri $URL -OutFile $FilePath -UseBasicParsing
        Expand-Archive -LiteralPath $FilePath -DestinationPath $FolderPath
        Remove-Item -Path $FilePath

        # Setting PATH environmental variable for Terraform
        Write-Output "Setting PATH environmental variable for Terraform..."
        # Get the PATH environmental Variable
        $Path = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
        # Create New PATH environmental Variable
        $NewPath = $Path + ";" + $FolderPath
        # Set the New PATH environmental Variable
        Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $NewPath
        $env:Path += $NewPath

        # Verify the Path
        # (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path

    }

    function Install-Json2Hcl {

        # Get the list of available Terraform versions
        $Response = Invoke-WebRequest -Uri "https://github.com/kvz/json2hcl/releases" -UseBasicParsing

        # Find the latest version
        $RelativePathToLatestVersion = (($Response.Links | Where-Object {$_.href -like "*windows_amd64*"}).href)[0]
        $Version = $RelativePathToLatestVersion.Split("/")[-2]

        # URL will be similar to this: "https://github.com/kvz/json2hcl/releases/download/v0.0.6/json2hcl_v0.0.6_windows_amd64.exe"
        $URL = "https://github.com/$RelativePathToLatestVersion"

        # Create folder
        $FileName = Split-Path $url -Leaf
        $FolderPath = "C:\json2hcl"
        $FilePath = "$FolderPath\$FileName"
        New-Item -ItemType Directory -Path $FolderPath -ErrorAction SilentlyContinue | Out-Null

        # Download and extract Json2HCL
        Write-Output "Downloading Json2HCL ($Version) to $FolderPath..."
        Invoke-WebRequest -Uri $URL -OutFile $FilePath -UseBasicParsing
        Rename-Item -Path $FolderPath\$FileName -NewName "json2hcl.exe"

        # Setting PATH environmental variable for Terraform
        Write-Output "Setting PATH environmental variable for Json2HCL..."
        # Get the PATH environmental Variable
        $Path = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
        # Create New PATH environmental Variable
        $NewPath = $Path + ";" + $FolderPath
        # Set the New PATH environmental Variable
        Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $NewPath
        $env:Path += $NewPath

    }

    function Install-VstsAgent {
        # Downloads the Visual Studio Online Build Agent, installs on the new machine, registers with the Visual
        # Studio Online account, and adds to the specified build agent pool
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)][string]$vstsAccount,
            [Parameter(Mandatory=$true)][string]$vstsUserPassword,
            [Parameter(Mandatory=$true)][string]$agentName,
            [Parameter(Mandatory=$false)][string]$agentNameSuffix,
            [Parameter(Mandatory=$true)][string]$poolName,
            [Parameter(Mandatory=$true)][string]$windowsLogonAccount,
            [Parameter(Mandatory=$true)][string]$windowsLogonPassword,
            [Parameter(Mandatory=$true)][ValidatePattern("[c-zC-Z]")][ValidateLength(1, 1)][string]$driveLetter,
            [Parameter(Mandatory=$false)][string]$workDirectory,
            [Parameter(Mandatory=$true)][boolean]$runAsAutoLogon
        )

        Write-Output "Installing VSTS Agent..."

        ###################################################################################################

        # if the agentName is empty, use %COMPUTERNAME% as the value
        if ([String]::IsNullOrWhiteSpace($agentName))
        {
            $agentName = $env:COMPUTERNAME
        }

        # if the agentNameSuffix has a value, add this to the end of the agent name
        if (![String]::IsNullOrWhiteSpace($agentNameSuffix))
        {
            $agentName = $agentName + $agentNameSuffix
        }

        #
        # PowerShell configurations
        #

        # NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
        #       This is necessary to ensure we capture errors inside the try-catch-finally block.
        $ErrorActionPreference = "Stop"

        # Ensure we set the working directory to that of the script.
        Push-Location $PSScriptRoot

        # Configure strict debugging.
        Set-PSDebug -Strict

        ###################################################################################################

        #
        # Functions used in this script.
        #

        function Show-LastError
        {
            [CmdletBinding()]
            param(
            )

            $message = $error[0].Exception.Message
            if ($message)
            {
                Write-Host -Object "ERROR: $message" -ForegroundColor Red
            }

            # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
            # returns exit code zero from the PowerShell script when using -File. The workaround is to
            # NOT use -File when calling this script and leverage the try-catch-finally block and return
            # a non-zero exit code from the catch block.
            exit -1
        }

        function Test-Parameters
        {
            [CmdletBinding()]
            param(
                [string] $VstsAccount,
                [string] $WorkDirectory
            )

            if ($VstsAccount -match "https*://" -or $VstsAccount -match "visualstudio.com")
            {
                Write-Error "VSTS account '$VstsAccount' should not be the URL, just the account name."
            }

            if (![string]::IsNullOrWhiteSpace($WorkDirectory) -and !(Test-ValidPath -Path $WorkDirectory))
            {
                Write-Error "Work directory '$WorkDirectory' is not a valid path."
            }
        }

        function Test-ValidPath
        {
            param(
                [string] $Path
            )

            $isValid = Test-Path -Path $Path -IsValid -PathType Container

            try
            {
                [IO.Path]::GetFullPath($Path) | Out-Null
            }
            catch
            {
                $isValid = $false
            }

            return $isValid
        }

        function Test-AgentExists
        {
            [CmdletBinding()]
            param(
                [string] $InstallPath,
                [string] $AgentName
            )

            $agentConfigFile = Join-Path $InstallPath '.agent'

            if (Test-Path $agentConfigFile)
            {
                Write-Error "Agent $AgentName is already configured in this machine"
            }
            else
            {
                write-output "agent is not configured as yet"
            }
        }

        function Get-AgentPackage
        {
            [CmdletBinding()]
            param(
                [string] $VstsAccount,
                [string] $VstsUserPassword
            )

            # Create a temporary directory where to download from VSTS the agent package (agent.zip).
            $agentTempFolderName = Join-Path $env:temp ([System.IO.Path]::GetRandomFileName())
            New-Item -ItemType Directory -Force -Path $agentTempFolderName | Out-Null

            $agentPackagePath = "$agentTempFolderName\agent.zip"
            $serverUrl = "https://$VstsAccount.visualstudio.com"
            $vstsAgentUrl = "$serverUrl/_apis/distributedtask/packages/agent/win-x64?`$top=1&api-version=3.0"
            $vstsUser = "AzureDevTestLabs"

            $maxRetries = 3
            $retries = 0
            do
            {
                try
                {
                    $basicAuth = ("{0}:{1}" -f $vstsUser, $vstsUserPassword)
                    $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
                    $basicAuth = [System.Convert]::ToBase64String($basicAuth)
                    $headers = @{ Authorization = ("Basic {0}" -f $basicAuth) }

                    $agentList = Invoke-RestMethod -Uri $vstsAgentUrl -Headers $headers -Method Get -ContentType application/json
                    $agent = $agentList.value
                    if ($agent -is [Array])
                    {
                        $agent = $agentList.value[0]
                    }
                    Invoke-WebRequest -Uri $agent.downloadUrl -Headers $headers -Method Get -OutFile "$agentPackagePath" -UseBasicParsing | Out-Null
                    break
                }
                catch
                {
                    $exceptionText = ($_ | Out-String).Trim()

                    if (++$retries -gt $maxRetries)
                    {
                        Write-Error "Failed to download agent due to $exceptionText"
                    }

                    Start-Sleep -Seconds 1
                }
            }
            while ($retries -le $maxRetries)

            return $agentPackagePath
        }

        function New-AgentInstallPath
        {
            [CmdletBinding()]
            param(
                [string] $DriveLetter,
                [string] $AgentName
            )

            [string] $agentInstallPath = $null

            # Construct the agent folder under the specified drive.
            $agentInstallDir = $DriveLetter + ":"
            try
            {
                # Create the directory for this agent.
                $agentInstallPath = Join-Path -Path $agentInstallDir -ChildPath $AgentName
                New-Item -ItemType Directory -Force -Path $agentInstallPath | Out-Null
                write-Host "agent install path: $($agentInstallPath)"
            }
            catch
            {
                $agentInstallPath = $null
                Write-Error "Failed to create the agent directory at $installPathDir."
            }

            return $agentInstallPath
        }

        function Get-AgentInstaller
        {
            param(
                [string] $InstallPath
            )

            $agentExePath = [System.IO.Path]::Combine($InstallPath, 'config.cmd')

            if (![System.IO.File]::Exists($agentExePath))
            {
                Write-Error "Agent installer file not found: $agentExePath"
            }

            return $agentExePath
        }


        function Set-MachineForAutologon
        {
            param(
                $Config
            )

            if ([string]::IsNullOrWhiteSpace($Config.WindowsLogonPassword))
            {
                Write-Error "Windows logon password was not provided. Please retry by providing a valid windows logon password to enable autologon."
            }

            # Create a PS session for the user to trigger the creation of the registry entries required for autologon
            $computerName = "localhost"
            $password = ConvertTo-SecureString $Config.WindowsLogonPassword -AsPlainText -Force

            if ($Config.WindowsLogonAccount.Split("\").Count -eq 2)
            {
                $domain = $Config.WindowsLogonAccount.Split("\")[0]
                $userName = $Config.WindowsLogonAccount.Split('\')[1]
            }
            else
            {
            $domain = $Env:ComputerName
            $userName = $Config.WindowsLogonAccount
            }

            $credentials = New-Object System.Management.Automation.PSCredential("$domain\\$userName", $password)
            Enter-PSSession -ComputerName $computerName -Credential $credentials
            Exit-PSSession

            try
            {
                # Check if the HKU drive already exists
                Get-PSDrive -PSProvider Registry -Name HKU | Out-Null
                $canCheckRegistry = $true
            }
            catch [System.Management.Automation.DriveNotFoundException]
            {
                try
                {
                    # Create the HKU drive
                    New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
                    $canCheckRegistry = $true
                }
                catch
                {
                    # Ignore the failure to create the drive and go ahead with trying to set the agent up
                    Write-Warning "Moving ahead with agent setup as the script failed to create HKU drive necessary for checking if the registry entry for the user's SId exists.\n$_"
                }
            }

            # 120 seconds timeout
            $timeout = 120

            # Check if the registry key required for enabling autologon is present on the machine, if not wait for 120 seconds in case the user profile is still getting created
            while ($timeout -ge 0 -and $canCheckRegistry)
            {
                $objUser = New-Object System.Security.Principal.NTAccount($Config.WindowsLogonAccount)
                $securityId = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
                $securityId = $securityId.Value

                if (Test-Path "HKU:\\$securityId")
                {
                    if (!(Test-Path "HKU:\\$securityId\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run"))
                    {
                        New-Item -Path "HKU:\\$securityId\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run" -Force
                        Write-Host "Created the registry entry path required to enable autologon."
                    }

                    break
                }
                else
                {
                    $timeout -= 10
                    Start-Sleep(10)
                }
            }

            if ($timeout -lt 0)
            {
                Write-Warning "Failed to find the registry entry for the SId of the user, this is required to enable autologon. Trying to start the agent anyway."
            }
        }

        function Install-Agent
        {
            param(
                $Config
            )

            try
            {
                # Set the current directory to the agent dedicated one previously created.
                Push-Location -Path $Config.AgentInstallPath

                if ($Config.RunAsAutoLogon)
                {
                    Set-MachineForAutologon -Config $Config

                    # Arguements to run agent with autologon enabled
                    $agentConfigArgs = "--unattended", "--url", $Config.ServerUrl, "--auth", "PAT", "--token", $Config.VstsUserPassword, "--pool", $Config.PoolName, "--agent", $Config.AgentName, "--runAsAutoLogon", "--overwriteAutoLogon", "--windowslogonaccount", $Config.WindowsLogonAccount
                }
                else
                {
                    # Arguements to run agent as a service
                    $agentConfigArgs = "--unattended", "--url", $Config.ServerUrl, "--auth", "PAT", "--token", $Config.VstsUserPassword, "--pool", $Config.PoolName, "--agent", $Config.AgentName, "--runasservice", "--windowslogonaccount", $Config.WindowsLogonAccount
                }

                if (-not [string]::IsNullOrWhiteSpace($Config.WindowsLogonPassword))
                {
                    $agentConfigArgs += "--windowslogonpassword", $Config.WindowsLogonPassword
                }
                if (-not [string]::IsNullOrWhiteSpace($Config.WorkDirectory))
                {
                    $agentConfigArgs += "--work", $Config.WorkDirectory
                }
                & $Config.AgentExePath $agentConfigArgs
                if ($LASTEXITCODE -ne 0)
                {
                    Write-Error "Agent configuration failed with exit code: $LASTEXITCODE"
                }
            }
            finally
            {
                Pop-Location
            }
        }

        ###################################################################################################

        #
        # Handle all errors in this script.
        #

        trap
        {
            # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
            #       script, unless you want to ignore a specific error.
            Show-LastError
        }

        ###################################################################################################

        #
        # Main execution block.
        #

        try
        {
            Write-Host 'Validating agent parameters'
            Test-Parameters -VstsAccount $vstsAccount -WorkDirectory $workDirectory

            Write-Host 'Preparing agent installation location'
            $VSTSagentInstallPath = New-AgentInstallPath -DriveLetter $driveLetter -AgentName $agentName
            write-host $VSTSagentInstallPath
            
            Write-Host 'Checking for previously configured agent'
            Test-AgentExists -InstallPath $VSTSagentInstallPath -AgentName $agentName

            Write-Host 'Downloading agent package'
            $agentPackagePath = Get-AgentPackage -VstsAccount $vstsAccount -VstsUserPassword $vstsUserPassword

            Write-Host 'Extracting agent package contents'
            Expand-Archive -LiteralPath $agentPackagePath -DestinationPath $VSTSagentInstallPath

            Write-Host 'Getting agent installer path'
            $agentExePath = Get-AgentInstaller -InstallPath $VSTSagentInstallPath
            write-output "agent installer path:$($agentExePath)"

            # Call the agent with the configure command and all the options (this creates the settings file)
            # without prompting the user or blocking the cmd execution.
            Write-Host 'Installing agent'
            $config = @{
                AgentExePath = $agentExePath
                AgentInstallPath = $VSTSagentInstallPath
                AgentName = $agentName
                PoolName = $poolName
                ServerUrl = "https://$VstsAccount.visualstudio.com"
                VstsUserPassword = $vstsUserPassword
                RunAsAutoLogon = $runAsAutoLogon
                WindowsLogonAccount = $windowsLogonAccount
                WindowsLogonPassword = $windowsLogonPassword
                WorkDirectory = $workDirectory
            }
            write-output "with these parameters:$($config)"
            Install-Agent -Config $config
            Write-Host 'Done'
        }
        finally
        {
            Pop-Location
        }

    }

    function Get-SystemData {
        # Get available Volume size
        $LogicalDisk = Get-WmiObject -Class win32_logicaldisk -Property *
        $FreeSpace = $LogicalDisk.FreeSpace / 1GB
        $Size = $LogicalDisk.Size / 1GB
        $PublicIP = (Invoke-WebRequest ifconfig.me/ip -UseBasicParsing).Content.trim()
        Write-Output "$($FreeSpace.ToString("#.##")) of $($Size.ToString("#.##")) GB disk space available"
        Write-Output "Public IP address is $($PublicIP)"
    }

    function Watch-VstsAgentService {
        Write-Output "This container will keep running as long as the Azure DevOps agent (vstsagent) service in it is not interrupted for longer than 3 minutes."
        $TryCount = 0
        while ($true)
        {
            if ((Get-Service "cexecsvc*").Status -eq "Running")
            {
                Start-Sleep -Seconds 60 | Out-Null
                # Test-Connection -ComputerName localhost -Quiet -Delay 60 | Out-Null
            }
            else
            {
                $TryCount++
            }
            if ($TryCount -gt 3)
            {
                break
            }
        }
    }
#===================================
Function GET-Temppassword() {

 Param(

 [int]$length=10,

[string[]]$sourcedata

 )

 For ($loop=1; $loop -le $length; $loop++) {

  $TempPassword+=($sourcedata | GET-RANDOM)
}

return $TempPassword

 }
#endregion

#region Main

    # Record start time
    $StartDate = Get-Date
    Write-Host "Configuration started at $StartDate"

    # Set SSL version preference
    [Net.ServicePointManager]::SecurityProtocol = "Tls12, Tls11, Tls" # Original: Ssl3, Tls

    # Install Terraform
    #Install-Terraform -SpecificVersion $SpecificVersion
    $TerraformInstallEnd = Get-Date
    $TerraformInstallDuration = New-TimeSpan -Start $StartDate -End $TerraformInstallEnd
    Write-Host "Terraform installation took $($TerraformInstallDuration.Hours.ToString("00")):$($TerraformInstallDuration.Minutes.ToString("00")):$($TerraformInstallDuration.Seconds.ToString("00")) (HH:mm:ss)"


    # Install Powershell Modules
    #Install-PowerShellModules -RequiredModules $RequiredPowerShellModules
    $Microsoft365DscInstallEnd = Get-Date
    #Install-Microsoft365Dsc
    $PoShModulelInstallEnd = Get-Date
    $PoShModulelInstallDuration = New-TimeSpan -Start $Microsoft365DscInstallEnd -End $PoShModulelInstallEnd
    Write-Host "PowerShell module installation took $($PoShModulelInstallDuration.Hours.ToString("00")):$($PoShModulelInstallDuration.Minutes.ToString("00")):$($PoShModulelInstallDuration.Seconds.ToString("00")) (HH:mm:ss)"

    # Install and VSTS Agent
    $ascii=$NULL;For ($a=33;$a –le 126;$a++) {$ascii+=,[char][byte]$a}
    $replace = $ascii -replace '[^a-zA-Z0-9]', ''
    $password = GET-Temppassword -length 12 -sourcedata $replace
       
    #Create Local user
    invoke-command -scriptblock {cmd /c "net user useradmin $($password) /add /passwordreq:yes /passwordchg:no"} 
    invoke-command -scriptblock {cmd /c "NET LOCALGROUP Administrators useradmin /ADD"} 
    # Set SSL version preference
    [Net.ServicePointManager]::SecurityProtocol = "Tls12" # Original: Ssl3, Tls
    # Set MaxEnvelopeSizekb
    invoke-command -scriptblock {cmd /c 'winrm set winrm/config @{MaxEnvelopeSizekb="8192" }'}
    #

    $hostname = (Get-ComputerInfo).csname

    $Date = Get-Date -Format yyyyMMdd-HHmmss
    $AgentName = "$AgentNamePrefix-$Date"
    Install-VstsAgent -vstsAccount $VSTSAccountName -vstsUserPassword $PATToken  -agentName $AgentName -poolName $PoolName -windowsLogonAccount "$($hostname)\useradmin" -windowsLogonPassword "$($password)" -driveLetter "C" -runAsAutoLogon:$false
    $AgentInstallEnd = Get-Date
    $AgentInstallDuration = New-TimeSpan -Start $PoShModulelInstallEnd -End $AgentInstallEnd
    Write-Host "Agent installation took $($AgentInstallDuration.Hours.ToString("00")):$($AgentInstallDuration.Minutes.ToString("00")):$($AgentInstallDuration.Seconds.ToString("00")) (HH:mm:ss)"

    # Calculate duration
    $OverallDuration = New-TimeSpan -Start $StartDate -End (Get-Date)
    Write-Host "It took $($OverallDuration.Hours.ToString("00")):$($OverallDuration.Minutes.ToString("00")):$($OverallDuration.Seconds.ToString("00")) (HH:mm:ss) to install the required components."
    Write-Host "Installation finished at $(Get-Date)"
    Write-Host "Container successfully configured." # Do NOT change this text, as this is the success criteria for the wrapper script.

    # Keep the container running by checking if the VSTS service is up
    Watch-VstsAgentService

#endregion
