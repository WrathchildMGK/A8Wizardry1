# Run keys from a saved state, dumping at frame -Dump; output in out\<Name>\.
# Altirra's @frame restarts near 0 when a state is loaded, so key frames
# count from the load (-Start only offsets them).
#   .\fromstate.ps1 inspect out\chest.atstate2 '100:0D','160:1F' -Dump 400
param([string]$Name, [string]$State, [string[]]$Keys = @(), [int]$Start = 0,
      [int]$Dump = 400, [string[]]$Pre = @())
$o = "$PSScriptRoot\out\$Name"
New-Item -ItemType Directory -Force $o | Out-Null
$abs = $Keys | ForEach-Object { $f, $c = $_.Split(':'); "$($Start + [int]$f):$c" }
& "$PSScriptRoot\altrun.ps1" -Out "$o\$Name.png" -Keys $abs -Hook auto -State $State -Pre $Pre `
    -DumpFrame ($Start + $Dump) -Timeout 300
