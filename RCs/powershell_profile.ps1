# PowerShell Profile
# Install: Copy this file to $PROFILE (usually at C:\Users\<you>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1)
#   cp ~/src/bash_scripts/RCs/powershell_profile.ps1 $PROFILE

function fc { ch -WhatIf @args }

function lsl {
    param([string]$Path = '.')
    Get-ChildItem -Force $Path | ForEach-Object {
        if ($_.LinkType) {
            "{0}  {1} -> {2}" -f $_.Mode, $_.Name, ($_.Target -join ', ')
        } else {
            "{0}  {1}" -f $_.Mode, $_.Name
        }
    }
}
