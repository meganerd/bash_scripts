# PowerShell $PROFILE stub -- the ONLY thing that belongs in $PROFILE.
# Dot-sources powershell_profile.ps1 (sibling of this file), so edits to that file are
# live in the next shell of either version. Nothing else should be added here; put new
# functions and aliases in powershell_profile.ps1.
#
# Install: copy this file to BOTH $PROFILE locations
#   PS5: C:\Users\<you>\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
#   PS7: C:\Users\<you>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
#
#   cp ~/src/bash_scripts/RCs/powershell_profile_stub.ps1 $PROFILE
#
# On a machine where the repo lives elsewhere, swap the literal path below for:
#   $CanonicalProfile = Join-Path $HOME 'src\bash_scripts\RCs\powershell_profile.ps1'
#
# Notes on the guard, which is bash's `[ -e f ]`:
#   - Test-Path with no -PathType matches a file OR directory, same as -e.
#     -PathType Leaf is `-f`, -PathType Container is `-d`.
#   - -LiteralPath, not -Path: -Path treats [ ] * ? as wildcards and would silently
#     miss a path containing them.
#   - if/else, not bash's `[ -e f ] && . f` short-circuit: && is PS7-only and is a
#     syntax error in Windows PowerShell 5.1, which has to run this same stub.
#   - Write-Warning rather than letting the dot-source fail: a missing repo then gives
#     one yellow line explaining why the aliases are gone, not a red unrecognized-term
#     error at every shell start.
#
# Keep this file pure ASCII, for the no-BOM decoding reason documented in
# powershell_profile.ps1.

$CanonicalProfile = 'C:\Users\GustinJohnson\src\bash_scripts\RCs\powershell_profile.ps1'
if (Test-Path -LiteralPath $CanonicalProfile) {
    . $CanonicalProfile
} else {
    Write-Warning "Canonical profile not found, aliases/functions unavailable: $CanonicalProfile"
}
