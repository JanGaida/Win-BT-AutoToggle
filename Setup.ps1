$ErrorActionPreference = "Stop"

<#
    .SYNOPSIS
        Returns the absolute-path to the run-script
#>
function Get-RunScriptPath {
    param(
        [Parameter()]
        [string]$ScriptPath
    )
    $scriptDir = Split-Path -Path $ScriptPath
    $runScript = Join-Path -Path $scriptDir -ChildPath "Run.ps1"

    if (-not (Test-Path $runScript)) {
        Write-Error "Could not find the 'Run.ps1'-script at path '$runScript'."
    }

    return $runScript
}

<#
    .SYNOPSIS
        Returns the date formatted
#>
function Get-CreateDate {
    return Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
}

<#
    .SYNOPSIS
        Returns current username
#>
function Get-UserName {
    return $env:USERNAME
}

<#
    .SYNOPSIS
        Ensures that admin-priveleges are available.
        Required since the run-script needs to be schedule with admin-privelegs to enable/disable devices
#>
function Ensure-Admin {
    param(
        [Parameter()]
        [string]$ScriptPath
    )

    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Administrator privileges are required to schedule tasks with the highest privileges." -ForegroundColor Red
        Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`"" -Verb RunAs
        exit
    }
}

### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ###

# Enforce admin-priveleges
Ensure-Admin -ScriptPath $MyInvocation.MyCommand.Path

# Disable-Task:
$ShutdownTaskName = "Disable Bluetooth Enumeration"
$ShutdownTaskXml = @"
<Task xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <RegistrationInfo>
        <Date>$(Get-CreateDate)</Date>
        <Author>$(Get-UserName)</Author>
        <Description>Task triggered on user logout to disable the bluetooth-discovery</Description>
    </RegistrationInfo>
    <Principals>
        <Principal id="Author">
            <LogonType>InteractiveToken</LogonType>
            <RunLevel>HighestAvailable</RunLevel>
        </Principal>
    </Principals>
    <Triggers>
        <EventTrigger>
            <Subscription>
                <![CDATA[
                <QueryList>
                    <Query Id="0" Path="System">
                        <Select Path="System">*[System[EventID=1074]]</Select>
                    </Query>
                </QueryList>
                ]]>
            </Subscription>
        </EventTrigger>
    </Triggers>
    <Actions>
        <Exec>
            <Command>powershell.exe</Command>
            <Arguments>-WindowStyle Hidden -File "$(Get-RunScriptPath $MyInvocation.MyCommand.Path)" -Action "Disable" -EnableLogging</Arguments>
        </Exec>
    </Actions>
    <Settings>
        <Enabled>true</Enabled>
        <AllowStartOnDemand>true</AllowStartOnDemand>
        <AllowHardTerminate>true</AllowHardTerminate>
    </Settings>
</Task>
"@

# Enable-Task:
$LogonTaskName = "Enable Bluetooth Enumeration"
$LogonTaskXml = @"
<Task xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <RegistrationInfo>
        <Date>$(Get-CreateDate)</Date>
        <Author>$(Get-UserName)</Author>
        <Description>Task triggered on user logon to (re-)enable the bluetooth-discovery</Description>
    </RegistrationInfo>
    <Principals>
        <Principal id="Author">
            <LogonType>InteractiveToken</LogonType>
            <RunLevel>HighestAvailable</RunLevel>
        </Principal>
    </Principals>
    <Triggers>
        <LogonTrigger>
            <Enabled>true</Enabled>
            <UserId>$(Get-UserName)</UserId>
        </LogonTrigger>
    </Triggers>
    <Actions>
        <Exec>
            <Command>powershell.exe</Command>
            <Arguments>-WindowStyle Hidden -File "$(Get-RunScriptPath $MyInvocation.MyCommand.Path)" -Action "Enable" -EnableLogging</Arguments>
        </Exec>
    </Actions>
    <Settings>
        <Enabled>true</Enabled>
        <AllowStartOnDemand>true</AllowStartOnDemand>
        <AllowHardTerminate>true</AllowHardTerminate>
    </Settings>
</Task>
"@

# Unregister any existing tasks
if (Get-ScheduledTask | Where-Object { $_.TaskName -eq $LogonTaskName }) {
    Unregister-ScheduledTask -TaskName $LogonTaskName -Confirm:$false
}
if (Get-ScheduledTask | Where-Object { $_.TaskName -eq $ShutdownTaskName }) {
    Unregister-ScheduledTask -TaskName $ShutdownTaskName -Confirm:$false
}
# Register the new tasks
Register-ScheduledTask -Xml $LogonTaskXml -TaskName $LogonTaskName | Out-Null
Register-ScheduledTask -Xml $shutdownTaskXml -TaskName $ShutdownTaskName | Out-Null
