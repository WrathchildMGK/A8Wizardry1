library OVCUTIL : $4000;

{ Overlay for COMBAT's CUTIL segment (atari/cutilunit.pas), one of the five
  combat overlays run by WIZRES's combat loop.  Built to end below $8800
  (mkovl --limit 0x8800): COMBATG's state lives there. }

uses TYPES, CONSTS, GLOBALS, UTIL, SCREEN, COMBATG, CUTILUNIT;

begin
  CUTIL
end.
