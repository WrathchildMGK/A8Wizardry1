# Chest cases from out\chest.atstate2 (made by chest.ps1), run in parallel.
# Each pokes REWARDS' TRAPTYPE / TRAP3TYP just after the load, then plays
# its keys; results in out\<case>\ (screens at -Shot frames, run.bin at end).
param([string[]]$Only = @())
$st = "$PSScriptRoot\out\chest.atstate2"
# REWARDS variables (addresses from build\rewards.a65; they move per build)
$lst = Get-Content "$PSScriptRoot\..\build\rewards.lst"
$D = [Convert]::ToInt32((($lst | Select-String '^\s*\d+\s+([0-9A-F]{4})\s+DATAORIGIN\s*$' | Select-Object -Last 1).Matches[0].Groups[1].Value), 16)
$a65 = Get-Content "$PSScriptRoot\..\build\rewards.a65"
function RwAddr($n) { $m = $a65 | Select-String "^$n`t= DATAORIGIN\+\`$([0-9A-F]+)" | Select-Object -First 1
                   '{0:X4}' -f ($D + [Convert]::ToInt32($m.Matches[0].Groups[1].Value, 16)) }
$TT = RwAddr 'TRAPTYPE'; $T3 = RwAddr 'TRAP3TYP'
$cases = [ordered]@{
    open0    = @{ Poke = '';                          Keys = '60:08','120:1F';                          Shot = 200, 400 }
    poison   = @{ Poke = "e $TT 01 00";               Keys = '60:08','120:1F';                          Shot = 160, 400 }
    crossbow = @{ Poke = "e $TT 03 00; e $T3 00 00";  Keys = '60:08','120:1F';                          Shot = 160, 400 }
    alarm    = @{ Poke = "e $TT 07 00";               Keys = '60:08','120:1F';                          Shot = 160, 400 }
    teleport = @{ Poke = "e $TT 04 00";               Keys = '60:08','120:1F';                          Shot = 160, 400 }
    look2    = @{ Poke = '';                          Keys = '60:0D','120:1F','400:0D','460:1F';        Shot = 200, 500 }
    disarm   = @{ Poke = "e $TT 02 00";               Keys = '60:3A','120:1F','180:3D','210:3F','240:3E','270:21','300:15','330:08','360:25','390:15','420:0C'
                  Shot = 480, 700 }
}
$jobs = foreach ($name in $cases.Keys) {
    if ($Only -and $Only -notcontains $name) { continue }
    $c = $cases[$name]; $o = "$PSScriptRoot\out\$name"
    $pre = @()
    if ($c.Poke) { $pre += "bx -n `"pc={HOOK} and @frame>5`" `"$($c.Poke); bc {N}`"" }
    foreach ($s in $c.Shot) { $pre += "bx -n `"pc={HOOK} and @frame>$s`" `".writemem $o\s$s.bin 0 L10000; bc {N}`"" }
    Start-Job -ArgumentList $PSScriptRoot, $name, $st, $c.Keys, ($c.Shot[-1] + 60), $pre -ScriptBlock {
        param($dir, $n, $st, $k, $d, $pre)
        & "$dir\fromstate.ps1" $n $st $k -Dump $d -Pre $pre
    }
}
$jobs | Wait-Job -Timeout 300 | Receive-Job | Out-Null
$jobs | Remove-Job -Force
foreach ($name in $cases.Keys) {
    if ($Only -and $Only -notcontains $name) { continue }
    $o = "$PSScriptRoot\out\$name"
    foreach ($s in $cases[$name].Shot) {
        if (Test-Path "$o\s$s.bin") { & E:\Python\python.exe "$PSScriptRoot\render.py" "$o\s$s.bin" "$o\s$s.png" | Out-Null }
    }
    if (Test-Path "$o\run.bin") { "$name : " + (& E:\Python\python.exe "$PSScriptRoot\rwvars.py" "$o\run.bin" TRAPTYPE) -join ' | ' }
    else { "$name : no dump" }
}
