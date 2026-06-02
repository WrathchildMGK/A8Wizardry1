program WIZARDRY;

{ Wizardry I — Proving Grounds of the Mad Overlord
  Atari 8-bit port in Mad Pascal.

  Original Apple Pascal reverse-engineered by Thomas William Ewers (Mar-Jun 2014).
  Atari port based on apple/wiz1a/WIZ.TEXT (authoritative source).
  Reference only (not authoritative): mads/ prior attempt.

  Build:
    mp.exe -target:a8 -ipath:C:\cygwin64\home\mgkea\Mad-Pascal\lib wiz.pas
}

uses TYPES, CONSTS, GLOBALS, UTIL, SPECUNIT, CASTLEUNIT, SHOPUNIT, RUNNERUNIT, UTILUNIT, REWARDSUNIT, ROLLERUNIT, CAMPUNIT, COMBATUNIT;




{ ============================================================
  Main program
  ============================================================ }

begin

  { Wire pointer arrays to their static backing stores. }
  CHARACTR[0] := @CHAR_SLOT0;
  CHARACTR[1] := @CHAR_SLOT1;
  CHARACTR[2] := @CHAR_SLOT2;
  CHARACTR[3] := @CHAR_SLOT3;
  CHARACTR[4] := @CHAR_SLOT4;
  CHARACTR[5] := @CHAR_SLOT5;
  SCNTOC.SPELLS := @SPELBLK_DATA;

  repeat
    LLBASE04 := -1;
    SPECIALS;
    repeat
      case XGOTO of

        XSCNMSG,
        XINSAREA:              SPECIALS;

        XCASTLE,
        XGILGAMS:              CASTLE;

        XBOLTAC,
        XCANT,
        XCHK4WIN,
        XCEMETRY,
        XEDGTOWN:              SHOPS;

        XNEWMAZE,
        XEQUIP6,
        XEQPDSP,
        XREORDER,
        XCMP2EQ6,
        XCAMPSTF:              UTILITIE;

        XTRAININ,
        XBCK2ROL:              ROLLER;

        XRUNNER:               RUNNER;

        XREWARD,
        XREWARD2:              REWARDS;

        XCOMBAT,
        XUNUSED:               COMBAT;

        XINSPECT,
        XINSPCT2,
        XINSPCT3,
        XBCK2CMP,
        XBK2CMP2:              CAMP;

      end;
    until XGOTO = XDONE;

    Write( Chr( 12));
    MVCURSOR( 0, 10);
    Write( '    PRESS [RETURN] FOR MORE WIZARDRY    ');
    ReadLn;
  until False;

end.
