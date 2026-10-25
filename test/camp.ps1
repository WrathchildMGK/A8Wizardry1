# Camp setup: play party2.ps1 -Priest (fighter A, mage B, priest C) into
# the maze and save the state at the CAMP menu, before L)eave, as
# out\camp.atstate2.  Drive camp spells from it with fromstate.ps1.
$o = "$PSScriptRoot\out"
$k = & "$PSScriptRoot\party2.ps1" -Priest
$keys = $k.Keys[0..($k.Keys.Count - 3)]          # drop L)eave and N
$save = $k.Stairs - 750                          # where L)eave would be
$pre = @("bx -n `"pc={HOOK} and @frame>$save`" `".savestate $o\camp.atstate2; bc {N}`"")
& "$PSScriptRoot\altrun.ps1" -Out "$o\camp.png" -Keys $keys -Hook auto -Pre $pre -DumpFrame ($save + 10) -Timeout 600
