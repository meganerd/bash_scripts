# PowerShell Profile (Windows PowerShell 5.x + PS7)
# Install: Copy this file to $PROFILE
#   PS5: C:\Users\<you>\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
#   PS7: C:\Users\<you>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
#   cp ~/src/bash_scripts/RCs/powershell_profile.ps1 $PROFILE

function windush {
      param([string]$Path = ".")
      $total = 0
      Get-ChildItem -Path $Path -Directory | ForEach-Object {
          $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
          $total += $size
          "{0,10:N2} MB  {1}" -f ($size/1MB), $_.Name
      } | Sort-Object
      ""
      "{0,10:N2} MB  TOTAL" -f ($total/1MB)
  }

  function time {
      param([scriptblock]$Command)
      $sw = [System.Diagnostics.Stopwatch]::StartNew()
      & $Command
      $sw.Stop()
      ""
      "Elapsed: {0}" -f $sw.Elapsed.ToString("mm\:ss\.fff")
  }
  function pbcopy_windows {
      $data = @($input) -join "`n"
      $data | Set-Clipboard
      $data
  }

New-Alias -Force gvim "C:\Program Files\Vim\vim92\gvim.exe"

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

Function Copy-HistoryCommand {

    [CmdletBinding(SupportsShouldProcess)]
    [alias("ch")]
    [outputtype("None", "System.String")]
    Param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [int]$ID = $(Get-History).Count,
        [switch]$Passthru)

    Begin {
        Write-Verbose "[BEGIN  ] Starting: $($MyInvocation.Mycommand)"
    } #begin

    Process {
        Write-Verbose "[PROCESS] Getting commandline from history item: $id"
        $cmdstring = (Get-History -Id $id).CommandLine
        If ($PSCmdlet.ShouldProcess("ID #$id [$cmdstring]")) {
            $cmdstring | Microsoft.PowerShell.Management\Set-Clipboard

            If ($Passthru) {
                #write the command to the pipeline
                $cmdstring
            } #If passthru
        }
    } #process

    End {
        Write-Verbose "[END    ] Ending: $($MyInvocation.Mycommand)"
    } #end

} #close function
