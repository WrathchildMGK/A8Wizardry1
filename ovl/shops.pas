library OVSHOPS : $4000;

{ Overlay for the AP segment SHOPS (atari/shopunit.pas).  Built by build.ps1:
  imp/ ahead of atari/ in the unit path, so UTIL and SCREEN are the
  external declarations of the residents. }

uses TYPES, CONSTS, GLOBALS, UTIL, SCREEN, SHOPUNIT;

begin
  SHOPS
end.
