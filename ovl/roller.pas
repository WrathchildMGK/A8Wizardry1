library OVROLLER : $4000;

{ Overlay for the AP segment ROLLER (atari/rollerunit.pas).  Built by build.ps1:
  imp/ ahead of atari/ in the unit path, so UTIL and SCREEN are the
  external declarations of the residents. }

uses TYPES, CONSTS, GLOBALS, UTIL, SCREEN, ROLLERUNIT;

begin
  ROLLER
end.
