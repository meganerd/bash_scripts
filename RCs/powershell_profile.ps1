# PowerShell Profile (Windows PowerShell 5.x + PS7)
# Canonical copy -- edit HERE, then install to both $PROFILE locations.
#
# Install: Copy this file to $PROFILE
#   PS5: C:\Users\<you>\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
#   PS7: C:\Users\<you>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
#   cp ~/src/bash_scripts/RCs/powershell_profile.ps1 $PROFILE
#
# Keep this file pure ASCII (no em-dashes, smart quotes, box characters).
# It is saved without a BOM, and a no-BOM file is decoded as the ANSI codepage by
# PS 5.1 but as UTF-8 by PS7 -- so any non-ASCII byte round-trips into mojibake on
# one of the two. That already happened once: the em-dash in winfind's help came
# back as "a-hat euro" in the PS7 copy. ASCII-only sidesteps it without needing a BOM.

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

New-Alias -Force vim "C:\Program Files\Vim\vim92\vim.exe"

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

function fc-win {
    [CmdletBinding()]
    param([int]$ID = ((Get-History).Count))   # default = most recent command

    $cmd = (Get-History -Id $ID -ErrorAction Stop).CommandLine
    $tmp = Join-Path $env:TEMP ("fc_{0}.ps1" -f [guid]::NewGuid())
    Set-Content -LiteralPath $tmp -Value $cmd -Encoding UTF8

    $editor = if ($env:EDITOR) { $env:EDITOR } else { 'notepad' }
    Start-Process -FilePath $editor -ArgumentList "`"$tmp`"" -Wait   # blocks until editor closes

    $edited = (Get-Content -LiteralPath $tmp -Raw).Trim()
    Remove-Item -LiteralPath $tmp -Force
    if ($edited) {
        Write-Host "> $edited" -ForegroundColor DarkGray
        Invoke-Expression $edited                                    # run the buffer
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

function winfind {
    <#
    .SYNOPSIS
        GNU find equivalent for Windows - recursively list files matching a wildcard pattern.
    .PARAMETER Path
        Starting directory (default: current directory).
    .PARAMETER Name
        Wildcard pattern (`*`, `?`) applied to filenames (default: `*` = all files).
    .EXAMPLE
        winfind . *.ps1
        winfind .\ *filestring*.ps1
        winfind C:\Windows\System32 *.dll
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Path = ".",
        [Parameter(Position = 1)]
        [string]$Name = "*"
    )
    Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue -Filter $Name |
        Select-Object -ExpandProperty FullName
}

New-Alias -Force winf winfind

function Set-ClipboardFromFile {
    <#
    .SYNOPSIS
        Copy a file's TEXT contents to the clipboard. Portable across PS 5.1 and PS7.
    .DESCRIPTION
        Set-Clipboard -Path / -LiteralPath / -AsHtml exist ONLY in Windows PowerShell 5.1.
        They were dropped when the cmdlet went cross-platform, so on PS7 you get:
            Set-Clipboard: A parameter cannot be found that matches parameter name 'Path'.
        -Value is the only parameter common to both, so this reads the file and pipes text.

        Note: 5.1's -Path places the FILE on the clipboard (an Explorer-pasteable file
        drop) rather than its text. This function always does TEXT. For the file-drop
        behaviour use Set-ClipboardFileDrop / clipdrop below -- that is what you want for
        binaries (.7z, .zip, .msi), where copying the text is meaningless.
    .PARAMETER LiteralPath
        File(s) to read. Aliased to -Path so `-Path <file>` muscle memory still works.
        Accepts pipeline input, including Get-ChildItem output (via -FullName alias).
    .PARAMETER Append
        Add to the existing clipboard contents instead of replacing them.
    .PARAMETER Encoding
        Optional passthrough to Get-Content -Encoding. Worth setting explicitly for
        non-ASCII files with no BOM: 5.1 defaults to the ANSI codepage, PS7 to UTF-8,
        so the same file decodes differently on each. Not validated here on purpose --
        the accepted value names differ between versions.
    .EXAMPLE
        Set-ClipboardFromFile $env:TEMP\mot-11924-readonly.txt
    .EXAMPLE
        clipfile -Path .\notes.md -Encoding UTF8
    .EXAMPLE
        Get-ChildItem *.ps1 | clipfile
    .EXAMPLE
        clipfile .\secrets.txt -WhatIf   # show what would be copied, touch nothing
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('PSPath', 'Path', 'FullName')]
        [string[]]$LiteralPath,

        [switch]$Append,

        [string]$Encoding
    )
    begin { $chunks = [System.Collections.Generic.List[string]]::new() }
    process {
        foreach ($p in $LiteralPath) {
            $gc = @{ LiteralPath = $p; Raw = $true; ErrorAction = 'Stop' }
            if ($PSBoundParameters.ContainsKey('Encoding')) { $gc['Encoding'] = $Encoding }
            # Get-Content -Raw returns $null (not '') for a 0-byte file, in both versions.
            $chunks.Add([string](Get-Content @gc))
        }
    }
    end {
        if ($chunks.Count -eq 0) { return }
        $text = $chunks -join [Environment]::NewLine
        # Version split, verified on 5.1.26100 and 7.6.3:
        #   Set-Clipboard -Value ''    -> 5.1 THROWS ArgumentNullException ('text'); PS7 fine.
        #   Set-Clipboard -Value $null -> both fine (clears the clipboard).
        # So an empty result must be sent as $null, never as ''.
        if ([string]::IsNullOrEmpty($text)) {
            if (-not $Append) { Set-Clipboard -Value $null }   # nothing to append
        } else {
            Set-Clipboard -Value $text -Append:$Append
        }
    }
}

New-Alias -Force clipfile Set-ClipboardFromFile

function Set-ClipboardFileDrop {
    <#
    .SYNOPSIS
        Copy FILE(S) to the clipboard as an Explorer-pasteable file drop. PS 5.1 and PS7.
    .DESCRIPTION
        This is what Windows PowerShell 5.1's `Set-Clipboard -Path` does: the file itself
        goes on the clipboard (CF_HDROP), so Ctrl+V in Explorer, Outlook, Teams, etc.
        pastes the file. -Path was dropped when Set-Clipboard went cross-platform, so PS7
        has no built-in equivalent -- and clipfile (above) copies a file's TEXT, which is
        not the same thing and is useless for binaries.

        Verified equivalent to 5.1's `Set-Clipboard -Path`: both leave the clipboard
        advertising the same formats -- FileDrop, FileNameW, FileName -- checked on
        5.1.26100.8875 and 7.6.3.

        Implementation is [System.Windows.Forms.Clipboard]::SetFileDropList(): Windows
        only, and it requires an STA thread. pwsh 7.6 starts STA, but earlier 7.x defaulted
        to MTA and `pwsh -MTA` still exists, so when the current thread is MTA the call is
        marshalled onto a temporary STA runspace. SetFileDropList flushes to the OLE
        clipboard (SetDataObject copy:$true), so the data outlives that runspace -- and
        even the process that set it.
    .PARAMETER LiteralPath
        File(s) or folder(s) to place on the clipboard. Aliased to -Path so `-Path <file>`
        muscle memory still works, but there is NO wildcard expansion (same as clipfile) --
        pipe Get-ChildItem for that. Relative paths are resolved to full paths, which
        Explorer requires. Missing paths are a non-terminating error and are skipped.
    .PARAMETER Append
        Add to the file drop list already on the clipboard instead of replacing it.
        Duplicate paths are skipped.
    .PARAMETER PassThru
        Emit the resulting file drop list, read back from the clipboard.
    .EXAMPLE
        clipdrop C:\builds\20260811-152315-develop\jumpbox-windows.7z
        # then Ctrl+V into an Explorer window, or into an email
    .EXAMPLE
        Get-ChildItem *.7z | clipdrop -PassThru
    .EXAMPLE
        clipdrop .\extra.log -Append
    .EXAMPLE
        clipdrop .\big.iso -WhatIf   # show the target, leave the clipboard alone
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('PSPath', 'Path', 'FullName')]
        [string[]]$LiteralPath,

        [switch]$Append,

        [switch]$PassThru
    )
    begin { $files = [System.Collections.Generic.List[string]]::new() }
    process {
        foreach ($p in $LiteralPath) {
            # Explorer needs absolute paths; this also copes with PSDrive-relative input.
            $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p)
            if (-not (Test-Path -LiteralPath $full)) {
                Write-Error "Not found: $full"
                continue
            }
            $files.Add($full)
        }
    }
    end {
        if ($files.Count -eq 0) { return }
        $target = if ($files.Count -eq 1) { $files[0] } else { "$($files.Count) items" }
        if (-not $PSCmdlet.ShouldProcess($target, 'Copy to clipboard as file drop')) { return }

        # Runs either inline (already STA) or inside the STA runspace below, so it must be
        # self-contained -- hence the Add-Type here rather than at profile load.
        $worker = {
            param([string[]]$Paths, [bool]$DoAppend)
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            $sc = [System.Collections.Specialized.StringCollection]::new()
            if ($DoAppend) {
                foreach ($e in [System.Windows.Forms.Clipboard]::GetFileDropList()) { $null = $sc.Add($e) }
            }
            foreach ($p in $Paths) { if (-not $sc.Contains($p)) { $null = $sc.Add($p) } }
            [System.Windows.Forms.Clipboard]::SetFileDropList($sc)
            , @([System.Windows.Forms.Clipboard]::GetFileDropList())
        }

        if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA') {
            $result = & $worker $files.ToArray() $Append.IsPresent
        } else {
            $rs = [runspacefactory]::CreateRunspace()
            $rs.ApartmentState = 'STA'
            $rs.ThreadOptions = 'ReuseThread'
            $rs.Open()
            $ps = [powershell]::Create()
            try {
                $ps.Runspace = $rs
                $null = $ps.AddScript($worker.ToString()).AddArgument($files.ToArray()).AddArgument($Append.IsPresent)
                $result = $ps.Invoke()
                if ($ps.Streams.Error.Count) { throw $ps.Streams.Error[0] }
            } finally { $ps.Dispose(); $rs.Dispose() }
        }
        if ($PassThru) { $result }
    }
}

New-Alias -Force clipdrop Set-ClipboardFileDrop
