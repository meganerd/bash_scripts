<#
.SYNOPSIS
Restarts one mouse, trackpad, touchpad, or TrackPoint on Windows.

.DESCRIPTION
Finds likely physical pointing devices, filters obvious remote and virtual
devices, and lets the user choose exactly one device to restart. The script
prefers the built-in PnPUtil restart command on Windows 10 version 2004 and
newer. On older systems, it safely falls back to disabling and re-enabling the
selected device.

The script supports Windows PowerShell 5.1 and PowerShell 7. It must run as an
administrator to restart a device. If needed, it asks Windows to relaunch it
with administrator privileges.

.PARAMETER ListOnly
Lists detected pointing devices without changing anything.

.PARAMETER DeviceInstanceId
Selects one exact Plug and Play instance ID instead of showing the menu.

.PARAMETER NoPause
Does not wait for Enter before closing.

.EXAMPLE
.\reset-windows-pointing-device.ps1

Shows a numbered list and restarts the selected device after confirmation.

.EXAMPLE
.\reset-windows-pointing-device.ps1 -ListOnly

Lists likely mice and trackpads without requesting administrator privileges.

.EXAMPLE
.\reset-windows-pointing-device.ps1 -WhatIf

Shows which device would be restarted without changing it.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$ListOnly,
    [ValidateLength(1, 1024)]
    [string]$DeviceInstanceId,
    [switch]$NoPause,
    [Parameter(DontShow = $true)]
    [switch]$Confirmed
)

$ErrorActionPreference = 'Stop'

function Wait-ForUser {
    if (-not $NoPause -and [Environment]::UserInteractive) {
        [void](Read-Host 'Press Enter to close this window')
    }
}

function Stop-WithMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [int]$Code = 1
    )

    Write-Host ''
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    Wait-ForUser
    return $Code
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function ConvertTo-QuotedProcessArgument {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    if ($Value.Contains('"')) {
        throw 'An argument contains an unsupported quote character.'
    }

    return '"' + $Value + '"'
}

function Start-ElevatedCopy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SelectedInstanceId
    )

    Write-Host 'Windows needs administrator permission to restart the device.'
    Write-Host 'A User Account Control window will appear next.'
    Write-Host ''

    $hostPath = (Get-Process -Id $PID).Path
    $arguments = @(
        '-NoProfile'
        '-File'
        (ConvertTo-QuotedProcessArgument -Value $PSCommandPath)
    )

    $arguments += '-DeviceInstanceId'
    $arguments += (ConvertTo-QuotedProcessArgument -Value $SelectedInstanceId)
    $arguments += '-Confirmed'
    if ($NoPause) {
        $arguments += '-NoPause'
    }

    try {
        $process = Start-Process -FilePath $hostPath -ArgumentList $arguments `
            -Verb RunAs -Wait -PassThru
        return $process.ExitCode
    }
    catch {
        return Stop-WithMessage -Message (
            'Administrator permission was not granted. No device was changed.'
        )
    }
}

function Get-PointingKind {
    param(
        [string]$Name,
        [Nullable[uint16]]$PointingType
    )

    if ($Name -match '(?i)touch[ -]?pad|trackpad|clickpad|glidepoint|precision touch') {
        return 'Trackpad'
    }
    if ($Name -match '(?i)trackpoint|pointing stick') {
        return 'TrackPoint'
    }
    if ($null -ne $PointingType) {
        switch ([int]$PointingType) {
            5 { return 'TrackPoint' }
            6 { return 'Trackpad' }
            7 { return 'Trackpad' }
        }
    }
    return 'Mouse'
}

function Add-PointingCandidate {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Candidates,
        [Parameter(Mandatory = $true)]
        $PnpDevice,
        [Nullable[uint16]]$PointingType,
        [string]$DetectedBy,
        [string]$DeviceIdentityText,
        [string]$ContainerId,
        [string]$Manufacturer,
        [string]$BusDescription,
        [string]$Location
    )

    $instanceId = [string]$PnpDevice.InstanceId
    $name = [string]$PnpDevice.FriendlyName
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = [string]$PnpDevice.Name
    }
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = 'Unnamed pointing device'
    }

    $excludedText = "$name $instanceId"
    if ($excludedText -match '(?i)remote desktop|terminal server|virtual|vmware|vmbus|citrix') {
        return
    }
    if ([string]::IsNullOrWhiteSpace($instanceId)) {
        return
    }

    $key = $instanceId.ToUpperInvariant()
    $kind = if ($DeviceIdentityText -match '(?i)UP:000D_U:0005') {
        'Trackpad'
    }
    else {
        Get-PointingKind -Name $name -PointingType $PointingType
    }
    $score = 0
    if ($DetectedBy -match 'Precision Touchpad HID usage') { $score += 100 }
    if ($DetectedBy -match 'Windows pointing-device inventory') { $score += 50 }
    if ($DetectedBy -match 'PnP Mouse class') { $score += 30 }
    if ($DetectedBy -match 'PnP trackpad name') { $score += 20 }
    if ([string]$PnpDevice.Status -eq 'OK') { $score += 5 }

    if ($Candidates.ContainsKey($key)) {
        if ($Candidates[$key].DetectedBy -notmatch [regex]::Escape($DetectedBy)) {
            $Candidates[$key].DetectedBy += ", $DetectedBy"
        }
        if ($kind -ne 'Mouse') {
            $Candidates[$key].Kind = $kind
        }
        return
    }

    $Candidates[$key] = [pscustomobject]@{
        Name       = $name
        Kind       = $kind
        InstanceId = $instanceId
        Status     = [string]$PnpDevice.Status
        DetectedBy = $DetectedBy
        ContainerId = $ContainerId
        Manufacturer = $Manufacturer
        BusDescription = $BusDescription
        Location = $Location
        Score = $score
        RelatedEntries = 0
    }
}

function Get-PointingDevices {
    Import-Module PnpDevice -ErrorAction Stop

    $candidates = @{}
    $allPnpDevices = @(Get-PnpDevice -PresentOnly -ErrorAction Stop)

    $wmiDevices = @()
    try {
        $wmiDevices = @(Get-CimInstance -ClassName Win32_PointingDevice `
            -ErrorAction Stop)
    }
    catch {
        Write-Warning 'Windows pointing-device details were unavailable; using PnP data only.'
    }

    $wmiById = @{}
    foreach ($wmiDevice in $wmiDevices) {
        $id = [string]$wmiDevice.PNPDeviceID
        if (-not [string]::IsNullOrWhiteSpace($id)) {
            $wmiById[$id.ToUpperInvariant()] = $wmiDevice
        }
    }

    foreach ($pnpDevice in $allPnpDevices) {
        $name = [string]$pnpDevice.FriendlyName
        $isMouseClass = [string]$pnpDevice.Class -eq 'Mouse'
        $deviceKey = ([string]$pnpDevice.InstanceId).ToUpperInvariant()
        $wmiDevice = if ($wmiById.ContainsKey($deviceKey)) {
            $wmiById[$deviceKey]
        }
        else {
            $null
        }
        $identityText = ''
        $deviceProperties = @{}
        if ([string]$pnpDevice.Class -eq 'HIDClass' -or
            $isMouseClass -or $null -ne $wmiDevice) {
            try {
                $identityProperties = @(Get-PnpDeviceProperty `
                    -InstanceId $pnpDevice.InstanceId `
                    -KeyName 'DEVPKEY_Device_HardwareIds',
                        'DEVPKEY_Device_CompatibleIds',
                        'DEVPKEY_Device_ContainerId',
                        'DEVPKEY_Device_Manufacturer',
                        'DEVPKEY_Device_BusReportedDeviceDesc',
                        'DEVPKEY_Device_LocationInfo' `
                    -ErrorAction Stop)
                foreach ($property in $identityProperties) {
                    $deviceProperties[[string]$property.KeyName] = $property.Data
                }
                $identityText = [string]::Join(' ', @(
                    $deviceProperties['DEVPKEY_Device_HardwareIds']
                    $deviceProperties['DEVPKEY_Device_CompatibleIds']
                ))
            }
            catch {
                $identityText = ''
            }
        }
        $isPrecisionTouchpad = $identityText -match '(?i)UP:000D_U:0005'
        $isNamedTrackpad = (
            [string]$pnpDevice.Class -eq 'HIDClass' -and
            $name -match '(?i)touch[ -]?pad|trackpad|clickpad|glidepoint|precision touch|trackpoint|pointing stick|synaptics|elan|alps'
        )

        if ($isMouseClass -or $isNamedTrackpad -or
            $isPrecisionTouchpad -or $null -ne $wmiDevice) {
            $sources = @()
            if ($null -ne $wmiDevice) {
                $sources += 'Windows pointing-device inventory'
            }
            if ($isMouseClass) { $sources += 'PnP Mouse class' }
            if ($isPrecisionTouchpad) {
                $sources += 'Precision Touchpad HID usage'
            }
            if ($isNamedTrackpad) { $sources += 'PnP trackpad name' }

            Add-PointingCandidate -Candidates $candidates -PnpDevice $pnpDevice `
                -PointingType $(if ($null -ne $wmiDevice) {
                    $wmiDevice.PointingType
                } else { $null }) `
                -DetectedBy ($sources -join ', ') `
                -DeviceIdentityText $identityText `
                -ContainerId ([string]$deviceProperties['DEVPKEY_Device_ContainerId']) `
                -Manufacturer ([string]$deviceProperties['DEVPKEY_Device_Manufacturer']) `
                -BusDescription ([string]$deviceProperties['DEVPKEY_Device_BusReportedDeviceDesc']) `
                -Location ([string]$deviceProperties['DEVPKEY_Device_LocationInfo'])
        }
    }

    $groupedCandidates = @($candidates.Values | Group-Object -Property {
        if ([string]::IsNullOrWhiteSpace($_.ContainerId)) {
            "INSTANCE:$($_.InstanceId)"
        }
        else {
            "CONTAINER:$($_.ContainerId)"
        }
    })

    $physicalDevices = foreach ($group in $groupedCandidates) {
        $bestMatch = $group.Group | Sort-Object Score -Descending | Select-Object -First 1
        $bestMatch.RelatedEntries = $group.Count - 1
        $bestMatch
    }

    return @($physicalDevices | Sort-Object Kind, Name, InstanceId)
}

function Show-PointingDevices {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Devices
    )

    Write-Host 'Detected mouse and trackpad devices:' -ForegroundColor Cyan
    Write-Host ''
    for ($index = 0; $index -lt $Devices.Count; $index++) {
        $device = $Devices[$index]
        Write-Host ("  {0}. [{1}] {2}" -f ($index + 1), $device.Kind, $device.Name)
        Write-Host ("     Status: {0}" -f $device.Status) -ForegroundColor DarkGray
        $details = @($device.Manufacturer, $device.BusDescription) |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
        if ($details.Count -gt 0) {
            Write-Host ("     Hardware: {0}" -f ($details -join ' - ')) `
                -ForegroundColor DarkGray
        }
        if (-not [string]::IsNullOrWhiteSpace($device.Location)) {
            Write-Host ("     Location: {0}" -f $device.Location) `
                -ForegroundColor DarkGray
        }
        if ($device.RelatedEntries -gt 0) {
            Write-Host ("     {0} related duplicate entry or entries hidden" -f `
                $device.RelatedEntries) -ForegroundColor DarkGray
        }
        Write-Host ("     ID: {0}" -f $device.InstanceId) -ForegroundColor DarkGray
    }
    Write-Host ''
}

function Select-PointingDevice {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Devices
    )

    while ($true) {
        $answer = Read-Host ("Type a number from 1 to {0}, or Q to quit" -f $Devices.Count)
        if ($answer -match '^(?i:q|quit)$') {
            return $null
        }

        $choice = 0
        if ([int]::TryParse($answer, [ref]$choice) -and
            $choice -ge 1 -and $choice -le $Devices.Count) {
            return $Devices[$choice - 1]
        }

        Write-Host 'That was not a valid choice. Please try again.' -ForegroundColor Yellow
    }
}

function Restart-WithPnpUtil {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstanceId
    )

    $pnpUtil = Join-Path ([Environment]::SystemDirectory) 'pnputil.exe'
    if (-not (Test-Path -LiteralPath $pnpUtil)) {
        return $false
    }

    Write-Host 'Restarting the selected device with Windows PnPUtil...'
    & $pnpUtil '/restart-device' $InstanceId
    if ($LASTEXITCODE -eq 0) {
        return $true
    }

    Write-Warning 'PnPUtil could not restart this device. Trying compatibility mode.'
    return $false
}

function Restart-WithDisableEnable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstanceId
    )

    $disabled = $false
    try {
        Write-Host 'Temporarily disabling the selected device...'
        Disable-PnpDevice -InstanceId $InstanceId -Confirm:$false -ErrorAction Stop
        $disabled = $true
        Start-Sleep -Seconds 2
    }
    finally {
        if ($disabled) {
            Write-Host 'Re-enabling the selected device...'
            Enable-PnpDevice -InstanceId $InstanceId -Confirm:$false -ErrorAction Stop
        }
    }
}

function Invoke-Main {
    if ($env:OS -ne 'Windows_NT') {
        return Stop-WithMessage `
            -Message 'This script runs only on Windows 10 or Windows 11.' -Code 2
    }

    Write-Host '=== Windows Mouse and Trackpad Reset ===' -ForegroundColor Cyan
    Write-Host 'This tool restarts one selected pointing device.'
    Write-Host 'You can use the keyboard throughout this process.'
    Write-Host ''

    try {
        $devices = @(Get-PointingDevices)
    }
    catch {
        return Stop-WithMessage -Message (
            "Could not inspect Windows devices: {0}" -f $_.Exception.Message
        )
    }

    if ($devices.Count -eq 0) {
        return Stop-WithMessage -Message (
            'No local mouse or trackpad was detected. No device was changed.'
        )
    }

    Show-PointingDevices -Devices $devices

    if ($ListOnly) {
        Write-Host '[OK] Device detection completed. Nothing was changed.' -ForegroundColor Green
        Wait-ForUser
        return 0
    }

    $selectedDevice = $null
    if ($DeviceInstanceId) {
        $selectedDevice = $devices | Where-Object {
            $_.InstanceId -eq $DeviceInstanceId
        } | Select-Object -First 1

        if ($null -eq $selectedDevice) {
            return Stop-WithMessage -Message (
                'The requested device ID is not a detected local mouse or trackpad.'
            ) -Code 2
        }
    }
    else {
        $selectedDevice = Select-PointingDevice -Devices $devices
        if ($null -eq $selectedDevice) {
            Write-Host 'Cancelled. Nothing was changed.'
            Wait-ForUser
            return 0
        }
    }

    Write-Host ''
    Write-Host ("Selected: [{0}] {1}" -f $selectedDevice.Kind, $selectedDevice.Name)
    Write-Host ("Device ID: {0}" -f $selectedDevice.InstanceId) -ForegroundColor DarkGray

    if ($WhatIfPreference) {
        [void]$PSCmdlet.ShouldProcess(
            "$($selectedDevice.Kind) '$($selectedDevice.Name)'",
            'Restart selected pointing device'
        )
        Wait-ForUser
        return 0
    }

    if (-not $Confirmed) {
        $confirmation = Read-Host 'Restart this device now? [y/N]'
        if ($confirmation -notmatch '^(?i:y|yes)$') {
            Write-Host 'Cancelled. Nothing was changed.'
            Wait-ForUser
            return 0
        }

        if (-not $PSCmdlet.ShouldProcess(
                "$($selectedDevice.Kind) '$($selectedDevice.Name)'",
                'Restart selected pointing device'
            )) {
            Wait-ForUser
            return 0
        }
    }

    if (-not (Test-IsAdministrator)) {
        return Start-ElevatedCopy -SelectedInstanceId $selectedDevice.InstanceId
    }

    try {
        $restarted = Restart-WithPnpUtil -InstanceId $selectedDevice.InstanceId
        if (-not $restarted) {
            Restart-WithDisableEnable -InstanceId $selectedDevice.InstanceId
        }

        Write-Host ''
        Write-Host '[OK] The selected device was restarted.' -ForegroundColor Green
        Write-Host 'Try the mouse wheel or trackpad now.'
        Wait-ForUser
        return 0
    }
    catch {
        Write-Host ''
        Write-Host '[ERROR] Windows could not complete the device restart.' `
            -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ''
        Write-Host 'The selected device may currently be disabled.' -ForegroundColor Yellow
        Write-Host 'Restart Windows, or use Device Manager to enable it:'
        Write-Host '  1. Press Windows+X, then choose Device Manager.'
        Write-Host '  2. Open Mice and other pointing devices.'
        Write-Host '  3. Right-click the device and choose Enable device.'
        Wait-ForUser
        return 1
    }
}

$result = Invoke-Main
[Environment]::ExitCode = $result
