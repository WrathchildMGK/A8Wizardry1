# Run an ATR in a private Altirra, press keys at given frames by poking CH
# ($2FC), dump memory at a frame and render the screen from the dump.
# No window focus or SendKeys; it never touches another running Altirra
# (/nosingleinstance, own settings file in test\out).
#   -Keys '700:0C','900:2A'   frame:keycode (hex, Atari KBCODE; 0C = RETURN)
#   -Hook auto                key breakpoints on WIZHI's VBI handler (once per
#                             frame, full speed) instead of per instruction
#   -Pre  'debugger cmd',...  extra lines; {N} = their breakpoint number,
#                             {HOOK} = the hook address
param([string]$Atr = "$PSScriptRoot\..\build\wizardry.atr", [string]$Out = "$PSScriptRoot\out\shot.png",
      [string[]]$Keys = @(), [int]$DumpFrame = 900, [int]$Timeout = 90, [string[]]$Pre = @(),
      [string]$Hw = '130xe', [string]$MemSize = '128K', [string]$Hook = '')
$Dir = Split-Path $Out
New-Item -ItemType Directory -Force $Dir | Out-Null
$Ini = "$PSScriptRoot\out\alt_$Hw.ini"
if (-not (Test-Path $Ini)) { Copy-Item "$PSScriptRoot\altirra.template.ini" $Ini }
$log = "$Dir\run.log"; $dump = "$Dir\run.bin"; $bat = "$Dir\run.txt"
Remove-Item $log, $dump -ErrorAction SilentlyContinue
if ($Hook -eq 'auto') { $Hook = & "$PSScriptRoot\hook.ps1" }
$Pre = @($Pre | ForEach-Object { $_.Replace('{HOOK}', $Hook) })
# key breakpoints first, so their numbers (0..) don't depend on -Pre
$lines = @(".logopen $log")
$n = 0
foreach ($k in $Keys) {
    $f, $c = $k.Split(':')
    $cond = if ($Hook) { "pc=$Hook and @frame>$f" } else { "@frame>$f" }
    $lines += "bx -n `"$cond`" `"e 2fc $c; bc $n`""
    $n++
}
foreach ($p in $Pre) { $lines += $p.Replace('{N}', "$n"); $n++ }
$lines += "bx `"@frame>$DumpFrame`" `".writemem $dump 0 L10000; r; .logclose`""
$lines += 'g'
Set-Content -Encoding ascii $bat $lines
$Atr = (Resolve-Path $Atr).Path
$argv = "/portablealt:$Ini /hardware:$Hw /memsize:$MemSize /nobasic /siopatch /nosingleinstance /debug /debugcmd:`".batch $bat`" `"$Atr`""
$p = Start-Process -FilePath 'D:\altirra\altirra64.exe' -ArgumentList $argv -PassThru -WindowStyle Minimized
$t = 0
while (-not (Test-Path $dump) -and $t -lt $Timeout) { Start-Sleep -Seconds 1; $t++ }
Start-Sleep -Seconds 1
Stop-Process -Id $p.Id -ErrorAction SilentlyContinue
if (-not (Test-Path $dump)) { "timeout: no dump"; exit 1 }
& 'E:\Python\python.exe' -I "$PSScriptRoot\render.py" $dump $Out
