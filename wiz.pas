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
  { CHARACTR is always a permutation of these six slots; party order is
    changed by swapping pointers, never by copying records. }
  WIRECHAR( CHAR_SLOT0, CHAR_SKN0, CHAR_POSS0);
  WIRECHAR( CHAR_SLOT1, CHAR_SKN1, CHAR_POSS1);
  WIRECHAR( CHAR_SLOT2, CHAR_SKN2, CHAR_POSS2);
  WIRECHAR( CHAR_SLOT3, CHAR_SKN3, CHAR_POSS3);
  WIRECHAR( CHAR_SLOT4, CHAR_SKN4, CHAR_POSS4);
  WIRECHAR( CHAR_SLOT5, CHAR_SKN5, CHAR_POSS5);
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
