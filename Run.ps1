param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("Enable", "Disable")]
    [string]$Action,
    
    [switch]$EnableLogging
)

if ($EnableLogging) {
    $logDir = Split-Path -Path $MyInvocation.MyCommand.Path
    $logFile = Join-Path -Path $logDir -ChildPath "\logs\$(Get-Date -Format "yyyy-MM-dd").log"
    Start-Transcript -Path $logFile -Append
}

### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ###

<#
    .SYNOPSIS
        Returns all targeted devices for this script
#>
function Get-BluetoothDevices {

    # Search
    $matchingClass = "Bluetooth"
    $matchingName = "*Microsoft*Enumerator*"
    $devices = Get-PnpDevice | Where-Object { $_.Class -eq $matchingClass -and $_.FriendlyName -like $matchingName }

    # Found the devics
    if (-not $devices) {
        Write-Error "Could not find any device matching the class '$matchingClass' and name like '$matchingName'"
    }
    
    return $devices
}

<#
    .SYNOPSIS
        Either enable/disable the targeted device

    .PARAMETER Device
        The pnp-device to target.
        Object should be received via Get-PnpDevice

    .PARAMETER Action
        What action to take with the device.
        Either 'Enable' to call Enable-PnpDevice or 'Disable' to call Disable-PnpDevice

#>
function Set-BluetoothDeviceState {
    param(
        [Parameter(Mandatory=$true)]
        [PSObject]$Device,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Enable", "Disable")]
        [string]$Action
    )

    # Enable/Disable the Bluetooth device
    try {
        if ($Action -eq "Enable") {
            Enable-PnpDevice -InstanceId $Device.InstanceId -Confirm:$false
            Write-Host "Enabled device: $($Device.FriendlyName)"
        } elseif ($Action -eq "Disable") {
            Disable-PnpDevice -InstanceId $Device.InstanceId -Confirm:$false
            Write-Host "Disabled device: $($Device.FriendlyName)"
        }
    } catch {
        Write-Error "Failed to $Action device: $($Device.FriendlyName)"
    }
}

### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ###

# Change each device into targeted state
foreach ($device in Get-BluetoothDevices) {
    Set-BluetoothDeviceState -Device $device -Action $Action
}

if ($EnableLogging) {
    Stop-Transcript
}