library OVCACT : $4000;

{ Overlay for CUTIL's CACTION (atari/cactunit.pas), one of the five
  combat overlays run by WIZRES's combat loop.  Built to end below $8800
  (mkovl --limit 0x8800): COMBATG's state lives there. }

uses TYPES, CONSTS, GLOBALS, UTIL, SCREEN, COMBATG, CACTUNIT;

begin
  CACTN
end.
