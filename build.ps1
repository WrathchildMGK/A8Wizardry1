# Wizardry I for the Atari: full build -> build\wizardry.atr
#   .\build.ps1              build
#   .\build.ps1 -Run         build and boot it in Altirra as a 130XE
#   .\build.ps1 -Run -Mem64  boot as a 64K 800XL (overlays reload from disk)
#
# Order matters: each step's MADS header (.hea) is read by the next.
#   1 imp/        import units for overlays           tools/mkimports.py
#   2 WIZHI       high resident, under the OS ROM     res/wizhi.pas
#   3 WIZRES      low resident, autoruns              res/wizres.pas
#   4 overlays    one library per AP segment          ovl/*.pas
#   5 data        SCENARIO.DAT / SCENARIO.MSG from the v3.2 scenario disk
#                 (tools/apdisk.py, gen_atari_portraits.py, mkscen.py)
#   6 disk        LiteDOS ATR, data files contiguous above the directory
param([switch]$Run, [switch]$Mem64)

$ErrorActionPreference = 'Stop'
$Atari   = $PSScriptRoot
$Root    = Resolve-Path "$Atari\.."
$Bin     = "$Root\bin"
$Tools   = "$Root\tools"
$MPLib   = 'C:\cygwin64\home\mgkea\Mad-Pascal\lib'
$MPBase  = 'C:\cygwin64\home\mgkea\Mad-Pascal\base'
$Python  = 'E:\Python\python.exe'
$Altirra = 'D:\altirra\altirra64.exe'
$ScenDsk = "$Root\apple\Wizardry-Proving-Grounds-v3.2-18-Mar-2026\Wizardry-Proving-Grounds-v3.2-Scenario-18-Mar-2026.dsk"
$Out     = "$Atari\build"
$Combat   = 'cinit', 'cutil', 'cact', 'cast', 'swing'
$Overlays = 'specials', 'castle', 'shops', 'utilitie', 'roller', 'runner', 'rewards', 'cinit', 'camp', 'cutil', 'cact', 'cast', 'swing'

New-Item -ItemType Directory -Force $Out | Out-Null

function Step($exe, [string[]]$argv) {
    # stderr is progress output, not failure (PS 5.1 would turn it into a
    # terminating error under 'Stop' when redirected): only the exit code counts
    $ErrorActionPreference = 'Continue'
    & $exe @argv 2>&1 | ForEach-Object { "$_" } |
        Where-Object { $_ -notmatch 'Note:|Case difference|Warning for unit' } | Write-Host
    if ($LASTEXITCODE -ne 0) { throw "$(Split-Path -Leaf $exe) failed ($LASTEXITCODE)" }
}
function Py([string[]]$argv) { Step $Python (@('-I') + $argv) }
function Mads($a65, [string[]]$extra) {
    Step "$Bin\mads.exe" (@($a65, '-x', "-i:$MPBase") + $extra)
}

Push-Location $Atari
try {
    # 1 imports
    Py @("$Tools\mkimports.py", $Atari)

    # 2 WIZHI: code $D800.., data $C000.. (below $E000: MADS rejects some
    #   var-record parameter code above it).  Data below code trips MP's
    #   "DATA memory overlap" assertion, which does not apply here.
    Step "$Bin\mp.exe" @("$Atari\res\wizhi.pas", '-target:a8', '-data:C000', "-ipath:$Atari\res", "-ipath:$Atari", "-ipath:$MPLib", "-o:$Out\wizhi.a65")
    Py @("$Tools\ptrfield.py", "$Out\wizhi.a65")      # mpbugs/bug15: P.F through a pointer
    (Get-Content "$Out\wizhi.a65") | Where-Object { $_ -notmatch "ert DATAORIGIN<@end" } | Set-Content -Encoding ascii "$Out\wizhi.a65"
    Mads "$Out\wizhi.a65" @('-hm', "-o:$Out\wizhi.xex")
    Py @("$Tools\heaalias.py", "$Out\wizhi.hea", "$Out\wizhi.hea", 'SCREEN', 'HIUTIL')
    Py @("$Tools\xexcheck.py", "$Out\wizhi.xex", 'C000-C7FF', 'D800-F7FF')   # GLOBALS 2 at $C800

    # 3 WIZRES: code $1080.. (LiteDOS MEMLO) below the overlay window ($4000); data at
    #   $9A40.. between GLOBALS block 1 and the screen (PROGRAMSTACK marks
    #   its true end: zeroed variables are not in the file)
    Step "$Bin\mp.exe" @("$Atari\res\wizres.pas", '-target:a8', '-code:1080', '-data:9A40', "-ipath:$Atari\res", "-ipath:$Atari", "-ipath:$Out", "-ipath:$MPLib", "-o:$Out\wizres.a65")
    Py @("$Tools\ptrfield.py", "$Out\wizres.a65")
    Mads "$Out\wizres.a65" @('-hm', "-o:$Out\wizres.xex")
    Py @("$Tools\heaalias.py", "$Out\wizres.hea", "$Out\wizres.hea", 'LOUTIL')
    Py @("$Tools\xexcheck.py", "$Out\wizres.xex", '1080-3FFF', '9A40-9FFF')
    Py @("$Tools\heacheck.py", "$Out\wizres.hea", 'MAIN.GLOBALS.G_END1<=9A40', 'MAIN.GLOBALS.G_END2<=D000', 'PROGRAMSTACK<=A000')

    # 4 overlays: imp\ first, so UTIL / SCREEN are the residents' externals
    foreach ($o in $Overlays) {
        Step "$Bin\mp.exe" @("$Atari\ovl\$o.pas", '-target:a8', "-ipath:$Atari\imp", "-ipath:$Atari", "-ipath:$Out", "-ipath:$MPLib", "-o:$Out\$o.a65")
        Py @("$Tools\ptrfield.py", "$Out\$o.a65")
        Mads "$Out\$o.a65" @("-o:$Out\$o.xex")
        # GLOBALS block 1 at $9000; the combat overlays leave $8800.. to COMBATG
        $lim = if ($Combat -contains $o) { '0x8800' } else { '0x9000' }
        Py @("$Tools\mkovl.py", "$Out\$o.xex", "$Out\$o.ovl", '--limit', $lim)
    }

    # 5 data
    Py @("$Tools\apdisk.py", $ScenDsk, 'SCENARIO.DATA', "$Out\SCENARIO.APL")
    Py @("$Tools\apdisk.py", $ScenDsk, 'SCENARIO.MESGS', "$Out\SCENARIO.MSG")
    Py @("$Tools\gen_atari_portraits.py", "$Out\SCENARIO.APL", "$Out\SCENARIO.ATP")
    Py @("$Tools\mkscen.py", '--src', "$Out\SCENARIO.ATP", '--out', "$Out\SCENARIO.DAT")

    # 6 disk: the game reads the data files by computed sector number, so
    #   they must be contiguous: a pad fills sectors 24..359 so they land
    #   above the directory (360..368); the pad is then removed and the
    #   rest fills the space below.  atrfs splits if=/of= at ':', so it
    #   runs in $Out with relative names.
    Push-Location $Out
    try {
        [IO.File]::WriteAllBytes("$Out\pad.bin", (New-Object byte[] (336 * 253)))
        Copy-Item "$Bin\BlankDisk.atr" 'disk.atr' -Force
        $adds = @(@('pad.bin', 'PAD.BIN'), @('SCENARIO.DAT', 'SCENARIO.DAT'), @('SCENARIO.MSG', 'SCENARIO.MSG'))
        foreach ($a in $adds) {
            Step "$Bin\atrfs.exe" @('add', $a[0], 'if=disk.atr', 'of=disk.tmp', '--name', $a[1])
            Move-Item 'disk.tmp' 'disk.atr' -Force
        }
        Step "$Bin\atrfs.exe" @('remove', 'PAD.BIN', 'if=disk.atr', 'of=disk.tmp')
        Move-Item 'disk.tmp' 'disk.atr' -Force
        $adds = @(, @('wizres.xex', 'WIZARDRY.AU0'))
        $adds += , @('wizhi.xex', 'WIZHI.XEX')
        foreach ($o in $Overlays) { $adds += , @("$o.ovl", "$($o.ToUpper()).OVL") }
        foreach ($a in $adds) {
            Step "$Bin\atrfs.exe" @('add', $a[0], 'if=disk.atr', 'of=disk.tmp', '--name', $a[1])
            Move-Item 'disk.tmp' 'disk.atr' -Force
        }
        Remove-Item 'pad.bin'
        Move-Item 'disk.atr' 'wizardry.atr' -Force
        Py @("$Tools\atrcheck.py", 'wizardry.atr', 'SCENARIO.DAT', 'SCENARIO.MSG')
        Step "$Bin\atrfs.exe" @('list', 'wizardry.atr')
    }
    finally { Pop-Location }

    if ($Run) {
        # Portable settings file so the user's Altirra configuration is untouched.
        $hw = if ($Mem64) { '/hardware:800xl', '/memsize:64K' } else { '/hardware:130xe', '/memsize:128K' }
        Start-Process $Altirra -ArgumentList (@("/portablealt:$Out\altirra.ini") + $hw + @('/nobasic', "`"$Out\wizardry.atr`""))
    }
}
finally { Pop-Location }
