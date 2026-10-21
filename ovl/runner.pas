library OVRUNNER : $4000;

{ Overlay for the AP segment RUNNER (atari/runnerunit.pas).  Built by build.ps1:
  imp/ ahead of atari/ in the unit path, so UTIL and SCREEN are the
  external declarations of the residents. }

uses TYPES, CONSTS, GLOBALS, UTIL, SCREEN, RUNNERUNIT;

begin
  RUNNER
end.
