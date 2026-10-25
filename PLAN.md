# Wizardry I for the Atari 8-bit: status and plan

The Apple Pascal v3.2 source (`../apple/Wizardry_v3-2/Wiz1A..D.DSK/*.TEXT.txt`)
and the v3.2 scenario disk
(`../apple/Wizardry-Proving-Grounds-v3.2-18-Mar-2026/`) are the authority.
Built with Mad Pascal 1.7.9 and MADS into a LiteDOS ATR for a 130XE, with a
64K fallback. Tested in Altirra (`D:\altirra\altirra64.exe`).

Last updated: 2026-10-25.

## Status

These play end to end on a 130XE in Altirra:

- **Boot:**
  - Boots from LiteDOS (`WIZARDRY.AU0`).
  - DOS isn't needed after load: WIZHI and the overlays are read by following sector links.
  - RESET cold-boots.
- **Town:**
  - Castle, Training Grounds and character creation (v3.2 rules, no passwords).
  - Gilgamesh's Tavern (adding to the party) and the Edge of Town.
- **Maze:**
  - Camp, the 3-D view clipped to the Apple's 82×79 picture box (frame borders intact), turning, moving and "OUCH!".
  - The stairs prompt.
- **Combat:**
  - Monster portraits in colour.
  - Party options; melee with the v3.2 hit-probability text and damage.
  - Monsters die, and REWARDS gives the correct EXP and gold.
  - Party spells: all 50 cast by `..\tests\altirra\sweep.ps1` (2026-10-25); every result matches the Apple CASTASPE code. KANDI isn't found in combat, as on the Apple: the table's hash is 1885, the code's constant 1185.
  - Enemy spells: LVL 1 PRIESTs cast BADIOS, a LVL 1 MAGE casts KATINO on the party.
  - A friendly encounter (F)ight or L)eave), and a party wipe leading to the cemetery.
- **Camp:** all 50 spells swept. The 14 that CAMP accepts work (heals, DUMAPIC, MILWA/LOMILWA, DIALKO, LATUMOFIS, MAPORFIC, DI/KADORTO's "NOT DEAD", and the KANDI/MALOR prompts); the rest give "WHAT?", as on the Apple.
  - Returns to the maze afterwards.
- **Demo:** `..\tests\altirra\altdemo.ps1` plays all of this by itself, for recording.

### Not yet exercised

- **Combat:**
  - Breath attacks (CREEPING COIN, enemy 12), and enemy spells above level 1.
  - Spell effects that need a set-up: DI/KADORTO on a dead character, KANDI's search, a MALOR jump from camp, ZILWAN on undead, DIALKO on paralysis.
  - Parry, run, use item, dispel.
  - Parties of 2–6 and several enemy groups.
  - Leaving the cemetery after a party wipe.
  - Level drain.
- **REWARDS:** treasure chests (open, inspect, disarm, traps) and the chest and gold pictures (PIC2SCRN, now wired up).
- **Camp:** items.
- **Town:** Boltac's (buy, sell, identify), Temple of Cant.
- **Saving:** a character persisting across a reboot.
- **Natural encounters:** only the forced CHSTALRM encounter is tested.
- **64K (800XL) mode:** not tested since combat was split into overlays. It reloads overlays from disk every time, so it will be slow.

### Known issues

- **WIZHI:** 7 bytes free below $F800. Make room before adding resident code.
- **UTILITIE overlay:** about 180 bytes free.
- **Intermittent crash:** seen once in early ROLLER testing and not reproduced since. It was probably one of the memory corruptions fixed below.
- **Cemetery tombstone:** its glyphs (character-set block 2) look cramped, squeezed from 7 to 4 pixels. Only block 1 has hand-made 4×8 glyphs. The layout matches the Apple.
- **Build tools outside the repo:** `build.ps1` uses `../tools/`:
  - `mkimports.py`, `mkovl.py`, `mkscen.py`
  - `apdisk.py`, `gen_atari_portraits.py`
  - `ptrfield.py` and the check scripts

  These, and `../mpbugs/`, are outside this repository.

## Resume here

Combat and camp spells, 2026-10-25 (not committed yet):

- **Fixed:** `SCNTOC.SPELLS` was never usable. MP 1.7.9 compiles a `^record` field of a GLOBALS record as its `.var` symbol, so the resident's store went to its own data and CACT/CAMP read the field's address. Every spell name was "not found". Lookups now use `@SPELBLK_DATA`; `tools/ptrfield.py` fails the build on the pattern.
- **Fixed:** RNDN read POKEY's RANDOM directly. It is a 17-bit shift register, so calls a fixed number of cycles apart were strongly correlated (an RNDN(3) after RNDN(8) came out 2 in 5 rounds of 6). RNDN is now a 16-bit xorshift with RANDOM stirred in each call (HIUTIL RNDSTEP).
- **Scripts:**
  - `..\tests\altirra\party2.ps1 [-Priest]`: fighter A, mage B (IQ 11), priest C (PIETY 11).
  - `..\tests\altirra\spell.ps1 [-Priest] [-Enemy N]`: forced encounter, state saved at A's first combat menu as `out\spell.atstate2`, `out\spell3.atstate2` or `out\enemyN.atstate2`. `-Enemy` pokes ENEMYINX ($901C) as CINIT loads. Useful enemies: 10 LVL 1 MAGE (friendly: F at 60), 11 LVL 1 PRIEST, 12 CREEPING COIN (breath).
  - `..\tests\altirra\camp.ps1`: the same 3-character party, saved at the CAMP menu as `out\camp.atstate2`.
  - `..\tests\altirra\sweep.ps1 -Mode combat|camp [-Only X,Y]`: casts every spell from those states with B and C poked up (all spells known, 9 points a level, level 13). It logs PRINTSTR/PRINTNUM/PUTCH output and writes a per-spell transcript to `out\sweep\<mode>.txt` (`spells.py` lists the table, `transcript.py` decodes a log). Each run's Altirra log can occasionally show a character twice: a debugger double hit, not the game.
- **Altirra single instance:** a hidden test instance can receive the user's own Altirra launch (it took a TirNaNog run on 2026-10-25), breaking that test. Don't run tests while the user is using Altirra, or ask them to start theirs with `/nosingleinstance`.
- **Driving combat from a state:** each character's menu at 60, 500, 900 (a key sent earlier is lost), spell names at 40-frame gaps, RETURN, then RETURN about 400 frames later to fight. To keep the party alive, poke TTEMP04 HPLEFT after the load (`e 8be3 63 00; e 8bf0 63 00; e 8bfd 63 00`, $8BDD + 13·slot + 6). Combat works on these copies and caps them to HPMAX each round. Enemies choose their actions in CUTIL, before the party menus, so a state taken at the menu has already decided round 1.
- Parallel runs must each have their own output folder: `altrun.ps1` writes its batch and log next to `-Out`.

Next: breath (enemy 12), the set-up spell effects listed under "Not yet exercised", then the rest of PLAN's step 2 (run, use item, dispel).

**Rebuild routine.** After every rebuild, regenerate any saved state before using it.

**Before trusting a run, check:**
- the build log shows `ZPAGE: $0080..$00D3`;
- `tools/ptrfield.py` is clean.

## Next steps (in order)

1. ~~**REWARDS chest path**~~ done 2026-10-22: `..\tests\altirra\chesttests.ps1` covers it.
   - Chest and gold pictures.
   - Open: untrapped, poison needle, crossbow (damage), alarm, teleporter.
   - Inspect: a failed roll sets the trap off.
   - Disarm: the typed name matches; a failed disarm sets the trap off.
   - Calfo and Leave.
   - Not yet seen: anti-mage and anti-priest on a mage or priest, and a successful disarm (needs a thief).
2. **Combat coverage:**
   - A mage or priest in the party, to exercise CAST.
   - A caster monster, for enemy spells.
   - A party of 2–3.
   - Parry, run, use item, dispel.
   - A party wipe leading to the cemetery.
3. **Town:**
   - Boltac's buy, sell and identify.
   - The Temple.
   - Save a character, reboot, and check it persists.
4. **64K:** smoke test, then decide whether combat's per-round overlay reloads need restructuring.
5. **WIZHI space audit** before more resident code is needed.
6. **CAMP and UTILITIE:** spells and items in camp, and the remaining v3.2 checks.

## Memory map

```
$0800..$0FFF  text page: font, mode 4 screen, display list (res/screen.pas)
$1080..$3FFF  WIZRES, the low resident (-code:1080 = LiteDOS MEMLO): boot,
              overlay loader, AP main loop, COMBAT + MELEE loops, LOUTIL (disk)
$4000..$7FFF  overlay window = XE bank window (overlay primary part)
$8000..$8FFF  overlay tail (overlays up to 20K)
$8800..$8F16  COMBATG: combat state shared by the combat overlays, which are
              built to end below $8800
$9000..$9A3F  GLOBALS block 1 (globals.pas)
$9A40..$9FFF  WIZRES variables
$A010..$BEFF  mode E graphics page + display list
$C000..$C7FF  WIZHI data   \
$C800..$CFFF  GLOBALS 2     > RAM under the OS ROM (the game runs with it off)
$D800..$F7FF  WIZHI code   /  SCREEN, HIUTIL, interrupt handlers
```

Overlays (`ovl/*.pas`, one MP library each at $4000, converted to `.OVL` by
`mkovl.py`):

- SPECIALS, CASTLE, SHOPS, UTILITIE, ROLLER, RUNNER, REWARDS, CAMP.
- The AP COMBAT segment is split into five:
  - CINIT
  - CUTIL (less CACTION)
  - CACT (CACTION)
  - CAST (CASTASPE)
  - SWING (SWINGASW)

  WIZRES runs them from its COMBAT and MELEE procedures.

## Conventions

- **EXIT( proc) unwinding.** Routines return a Byte code: `UNWNONE` (0) or `U_<proc>`, the Apple procedure number within its segment (CONSTS / COMBATG). A caller carries on for 0, stops on its own code, and otherwise passes the code up. Across overlays the code travels in a shared variable, e.g. `CMBEXIT`.
- **Text versus graphics.** GOTOXY + WRITE writes the text page. MVCURSOR (GMOVE) + PRINTCHR/PRINTSTR/PRINTNUM/CLRRECT draws on the graphics page.
- **Picture area.** Apple picture X (0..81) maps to mode E pixel 4 + X·46 div 82, on lines 5..83.
  - Portraits are 50 rows × 10 bytes at bytes 1..10 of lines 23..72.
  - Each portrait block's bytes 500/501 are its COLOR0/COLOR1, set by the caller.
- **PAUSE1/PAUSE2** wait on frames (RTCLOK): TIMEDLAY/32 frames.

## Mad Pascal 1.7.9 rules

Repros for each are in `../mpbugs/`.

- **bug10:** `ARR[I]^` through a pointer array fails as a var parameter. Use a local pointer instead.
- **bug11:** SizeOf of a record with `^record` fields is wrong. Use the `*_SIZE` constants.
- **bug12:** `P^ := TAB[ G^]` is miscompiled. Load the index into a Byte first.
- **bug13:** `absolute` is ignored on enum variables. Shared enums are `Byte` plus constants (TXGOTO).
- **bug14:** `S := PString^` double-dereferences. Use Peek, or pass the pointer on.
- **bug15:** fields reached through a pointer (variable or parameter) can use a static address.
  - Write `P^.F` for enum fields, for `for … to P^.F` bounds, and for every field of a `^record` parameter.
  - `case P^.X of` and passing `P^.X` as an enum argument are rejected. Copy the field to a typed local first.
  - Record or array copies into a field through a pointer must be done per field or per element.
- **bug16:** a `^record` field counts as 0 bytes, so later field offsets are wrong. Declare such fields as untyped `Pointer` (TENEMY2.A/B).
- **GLOBALS pointer fields:** a `^record` field of a GLOBALS record (`SCNTOC.SPELLS`) is read and written as its `.var` symbol, not the field. Use the absolute target directly.
- **bug17:** `V := 10*V + ARR[I]`, with V a var parameter, loses the index. Accumulate in a local.
- **Random:** never use MP's `Random`, and don't read POKEY's RANDOM directly; use HIUTIL `RNDN( R)`. MP's RndSeed is never seeded, so `Random( SmallInt)` always returned 0, and its LCG keeps bit 0 constant anyway. The build fails on `jsr SYSTEM.RANDOM`.
- **No recursion, and no New/GetMem.** Either adds `psptr` and shifts the overlay's zero page away from the residents'. Write tail recursion as a loop. A function that reads its own name is a recursive call: use `Result`.
- **Other gotchas:**
  - Write field widths are ignored. Use SPACES/WRITEINT/PRINTNUM.
  - A function with nested routines must use `Result`.
  - A parameterless function can't be called as a statement.
  - MP's locals are static.

`../tools/ptrfield.py` runs on every compiled `.a65` in the build. It fails on the patterns from bug15 and bug17, and on the zero-page shift. Every build line should show `ZPAGE: $0080..$00D3`.

## Build and test

- **Build:** `.\build.ps1` builds everything into `build/wizardry.atr` and checks segment limits. `-Run` boots it; `-Mem64` boots an 800XL.
- **Test scripts** live outside this repository, in `..\tests\altirra` (moved 2026-10-25).
- **Test runner:** `..\tests\altirra\altrun.ps1` runs the ATR in a private, minimised Altirra (`/nosingleinstance`, its own settings in `..\tests\altirra\out`). It never sends anything to your Altirra, but your own Altirra launches can land in it (see Resume here).
  - It presses keys at fixed frames by poking CH ($2FC).
  - It dumps memory at a frame and renders the screen with `..\tests\altirra\render.py`, which uses the real colour registers.
  - `-Hook auto` ties the key breakpoints to WIZHI's VBI handler (found by `..\tests\altirra\hook.ps1` from `build\wizhi.lst`, since it moves with every WIZHI change). That runs at full speed; plain `@frame>N` breakpoints are checked per instruction and slow everything down.
  - `-Pre` adds debugger lines: `{N}` is the line's own breakpoint number and `{HOOK}` the hook address. Use them for extra memory dumps (`.writemem`) or logging (`r`, `db`).
- **Key and demo scripts:**
  - `..\tests\altirra\keys.ps1`: boot, create fighter A, add him to the party, enter the maze, decline the stairs.
  - `..\tests\altirra\demo.ps1`: adds a walk, a forced encounter (GLOBALS CHSTALRM $9012 := 1), fight rounds, the rewards and a walk.
  - Both take `-Scale` to shorten the gaps between keys.
  - With fixed key frames a run is deterministic. Changing any timing (`-Scale`, or a rebuild that moves code) changes the random numbers, so the encounter and fight differ.
  - At `-Scale 0.75` the game keeps up with every key: the demo is about 15,750 frames instead of 21,000. One of two runs stalled after the maze walk (frame ~12,120: the remaining keys never fired) and the rerun was clean, so the cause is unknown.
  - For tests whose outcome varies (fights), read the state from a dump (`DONEFIGH`, `XGOTO`) between steps rather than relying on fixed round counts.
  - "Invalid breakpoint number: 0" in `run.log` is harmless: the first key's breakpoint fires twice.
- **Saved states:** a `-Pre` line can make one (`.savestate file`), e.g. `..\tests\altirra\chest.ps1`, which saves at the chest menu. `..\tests\altirra\fromstate.ps1 <name> <state> <keys> -Dump N` runs keys from a state in seconds, with output in `..\tests\altirra\out\<name>\`.
  - Altirra's `@frame` restarts near 0 after `.loadstate`, so key frames count from the load.
  - A state captures the code, so regenerate it after every rebuild.
  - Several from-state runs can go in parallel, each with its own name.
  - `..\tests\altirra\chesttests.ps1` runs the chest cases this way, poking TRAPTYPE/TRAP3TYP after the load.
  - `..\tests\altirra\rwvars.py dump.bin [VAR…]` prints REWARDS variables and party slot 0.
- **Random numbers:** with real randomness a run's encounters vary, so a scripted maze walk can meet a random fight. Scripts that need a known fight force the encounter straight after the stairs (`chest.ps1`).
- **Hook addresses:** `..\tests\altirra\hook.ps1 [proc] [binary]` finds any procedure in a listing (e.g. `RUNOVL wizres`). A breakpoint `pc=<RUNOVL> and a=$0A` catches the start of CUTIL; A holds the overlay number.
- **Recording:** `..\tests\altirra\altdemo.ps1` opens the same demo visibly and paused, ready to record with File › Record Video, then F5.
- **Key codes (KBCODE):**

  | Key | Code | Key | Code | Key | Code | Key | Code |
  |---|---|---|---|---|---|---|---|
  | RETURN | 0C | ESC | 1C | + | 06 | A | 3F |
  | D | 3A | E | 2A | F | 38 | G | 3D |
  | L | 00 | M | 25 | N | 23 | R | 28 |
  | S | 3E | T | 2D | Y | 2B | | |

- **Useful addresses:**

  | Item | Address |
  |---|---|
  | GLOBALS PARTYCNT | $9000 |
  | GLOBALS XGOTO | $900C |
  | GLOBALS CHSTALRM | $9012 |
  | GLOBALS ENEMYINX | $901C |
  | Party slot 0 (TCHAR) | $C800 |
  | COMBATG CMBEXIT | $8800 |
  | COMBATG DONEFIGH | $8805 |
  | IOCACHE | $9240 |

  Overlay variables are found from `build\<ovl>.lst` (DATAORIGIN) plus the `.a65` equates.
