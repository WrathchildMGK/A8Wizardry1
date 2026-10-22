unit ROLLERUNIT;

{ Source: apple/Wizardry_v3-2/Wiz1C.DSK/ROLLER (v3.2: no passwords, WC019)

  Translation notes:
    - SEGMENT PROCEDURE ROLLER -> unit procedure ROLLER
    - EXIT(ROLLER/MAKECHAR/CREATE/TRAINING) past the current routine ->
      unwind codes U_* (CONSTS); EXIT of the current routine -> exit
    - GETCHARC/PUTCHARC   -> LOADTCHAR/SAVETCHAR
    - CHARACTR[0] := CHARREC -> CHARACTR[0]^ := CHARREC (CHARACTR holds ^TCHAR)
    - CHARREC := CHARACTR[0] -> CHARREC := CHARACTR[0]^
    - CHARREC.CLASS       -> CHARREC.XCLASS
    - CHARREC.LOSTXYL.LOCATION[1] -> CHARREC.LOSTXYL[1]
    - CHARREC.EXP.HIGH/MID/LOW    -> XHIGH/XMID/XLOW
    - CHARREC.GOLD.LOW            -> CHARREC.GOLD.XLOW
    - SCNTOC.RACE/CLASS/ALIGN/STATUS -> SCNTOC_RACE/CLASS/ALIGN/STATUS globals
    - CHARREC.SPELLSKN[I]  -> SKN^[I] via local PTSPELLSKN variable
    - CHARREC.POSS.POSSESS[I].FIELD -> PP := CHARREC.POSS.POSSESS[I]; PP.FIELD
    - WRITE(CHR(12)) -> ClrScr; GOTOXY, CHR(11), CHR(29) as AP (SCREEN)
    - GETLINE(VAR S) -> GETLINE; S := GTSTRING
    - RANDOM MOD N   -> RNDN(N)
    - CHG2LST array[FIGHTER..NINJA] -> indexed by Byte(TCLASS)
    - BASEATTR/SIXATTR2 array[STRENGTH..LUCK] -> indexed by Byte(TATTRIB)
    - SUCC(enum) -> SUCC(enum) — try first; fallback cast if MP fails
}

interface

uses TYPES, CONSTS, GLOBALS, UTIL, SCREEN;

procedure ROLLER;

implementation

{ Unit-level helpers for enum assignment (bug4: nested proc/case re-types
  non-zero enum constants as Byte; typed parameter restores correct type). }
{ Access enum fields of TCHAR via PTCHAR pointer (avoids nested-scope type loss). }
procedure SETALIGN_RL( TC: PTCHAR; V: TALIGN);  begin TC^.ALIGN  := TALIGN( Byte(V)) end;
procedure SETSTATUS_RL(TC: PTCHAR; V: TSTATUS); begin TC^.STATUS := TSTATUS(Byte(V)) end;
procedure SETRACE_RL(  TC: PTCHAR; V: TRACE);   begin TC^.RACE   := TRACE(  Byte(V)) end;
procedure SETCLASS_RL( TC: PTCHAR; V: TCLASS);  begin TC^.XCLASS := TCLASS( Byte(V)) end;

{ MP comparison operators return BYTE, not Boolean; this bridges the gap. }
function BSET(B: Byte): Boolean;
begin
  if B <> 0 then BSET := true else BSET := false
end;


{ ══════════════════════════════════════════════════════════════════════════════
  ROLLER
  ══════════════════════════════════════════════════════════════════════════════ }

procedure ROLLER;

const
  U_ROLLER   = $01;       { unwind targets: AP P010B01, P010B09, P010B13, }
  U_MAKECHAR = $09;       {   P010B16                                     }
  U_CREATE   = $13;
  U_TRAINING = $16;

var
  CHARREC  : TCHAR;
  CRSKN    : TSPELLSKN;   { CHARREC's wired spell list and possessions }
  CRPOSS   : TPOSSBLK;
  PCHARREC : ^TCHAR;      { = @CHARREC: MP 1.7.9 needs pointer arrays inside a
                            record reached through a pointer (mpbugs/bug10) }
  PSLOT    : ^TCHAR;      { CHARACTR[ 0], for whole-record copies }
  TEMPX    : SmallInt;
  CHARACX  : SmallInt;
  PTSLEFT  : SmallInt;
  CHARNAME : string[ 15];
  CHG2LST  : array[ FIGHTER..NINJA]   of Boolean;
  BASEATTR : array[ STRENGTH..LUCK]   of SmallInt;
  SIXATTR2 : array[ STRENGTH..LUCK]   of SmallInt;


  { ── GTCHGLST ── }
  function GTCHGLST: Boolean;
  begin
    CHG2LST[ FIGHTER] := BSET(SIXATTR2[ STRENGTH] >= 11);

    CHG2LST[ MAGE]    := BSET(SIXATTR2[ IQ] >= 11);

    CHG2LST[ PRIEST]  := BSET((SIXATTR2[ PIETY] >= 11) and
                         (CHARREC.ALIGN <> NEUTRAL));

    CHG2LST[ THIEF]   := BSET((SIXATTR2[ AGILITY] >= 11) and
                         (CHARREC.ALIGN <> GOOD));

    CHG2LST[ BISHOP]  := BSET((SIXATTR2[ IQ] >= 12) and
                         (SIXATTR2[ PIETY] >= 12) and
                         (CHARREC.ALIGN <> NEUTRAL));

    CHG2LST[ SAMURAI] := BSET((SIXATTR2[ STRENGTH] >= 15) and
                         (SIXATTR2[ IQ] >= 11) and
                         (SIXATTR2[ PIETY] >= 10) and
                         (SIXATTR2[ VITALITY] >= 14) and
                         (SIXATTR2[ AGILITY] >= 10) and
                         (CHARREC.ALIGN <> EVIL));

    CHG2LST[ LORD]    := BSET((SIXATTR2[ STRENGTH] >= 15) and
                         (SIXATTR2[ IQ] >= 12) and
                         (SIXATTR2[ PIETY] >= 12) and
                         (SIXATTR2[ VITALITY] >= 15) and
                         (SIXATTR2[ AGILITY] >= 14) and
                         (SIXATTR2[ LUCK] >= 15) and
                         (CHARREC.ALIGN = GOOD));

    CHG2LST[ NINJA]   := BSET(               { v3.2 WC030: 15, not 17 }
                         (SIXATTR2[ STRENGTH] >= 15) and
                         (SIXATTR2[ IQ] >= 15) and
                         (SIXATTR2[ PIETY] >= 15) and
                         (SIXATTR2[ VITALITY] >= 15) and
                         (SIXATTR2[ AGILITY] >= 15) and
                         (SIXATTR2[ LUCK] >= 15) and
                         (CHARREC.ALIGN = EVIL));

    GTCHGLST := CHG2LST[ FIGHTER] or CHG2LST[ MAGE]    or
                CHG2LST[ PRIEST]  or CHG2LST[ THIEF]   or
                CHG2LST[ BISHOP]  or CHG2LST[ LORD]     or
                CHG2LST[ SAMURAI] or CHG2LST[ NINJA]
  end;


  { ── SETBASE ── }
  procedure SETBASE;

    procedure SETXBASE( BASESTR: string);  {  S  I  P  V  A  L }
    var
      ATTRI : SmallInt;
      ATTR  : TATTRIB;
    begin
      ATTR := STRENGTH;
      for ATTRI := 1 to 6 do
        begin
          BASEATTR[ ATTR] := Ord( BASESTR[ ATTRI]) - Ord( '0');
          ATTR := SUCC( ATTR)
        end
    end;

  begin  { SETBASE }
    case Byte( CHARREC.RACE) of              {  S  I  P  V  A  L  }
      Byte( HUMAN):  SETXBASE( '885889');   {  8  8  5  8  8  9  }
      Byte( ELF):    SETXBASE( '7::696');   {  7 10 10  6  9  6  }
      Byte( DWARF):  SETXBASE( ':7::56');   { 10  7 10 10  5  6  }
      Byte( GNOME):  SETXBASE( '77:8:7');   {  7  7 10  8 10  7  }
      Byte( HOBBIT): SETXBASE( '5776:?');   {  5  7  7  6 10 15  }
    end
  end;


  { ── GTSCNTOC ── }
  procedure GTSCNTOC;
  var DUMMY : SmallInt;
  begin
    DUMMY := GETREC( ZZERO, 0, SizeOf( TSCNTOC));
    LOADSCNTOC
  end;


  { ── MAKECHAR ── }
  procedure MAKECHAR;


    { ── INITCHAR ── }
    procedure INITCHAR;
    var
      LSI : SmallInt;
    begin
      CLEARCHAR( CHARREC);
      CHARREC.NAME      := CHARNAME;
      CHARREC.AGE       := (18 * 52) + RNDN( 300);
      CHARREC.GOLD.XLOW := 90 + RNDN( 100);
      SETSTATUS_RL( @CHARREC, OK);
      for LSI := 0 to 4 do
        CHARREC.LUCKSKIL[ LSI] := 16;
      CHARREC.MAXLEVAC  := 1;
      CHARREC.CHARLEV   := 1;
      CHARREC.ARMORCL   := 10
    end;


    procedure P010B0B;
    begin
      GotoXY( 0, 15);
      Write( Chr( 11))
    end;


    procedure P010B0C;
    begin
      GotoXY( 0, 15);
      Write( Chr( 29))
    end;


    { ── MAKEMENU ── }
    procedure MAKEMENU;
    begin
      ClrScr;
      Write( '     NAME ');
      WriteLn( CHARREC.NAME);
      WriteLn( '         ');
      WriteLn( '     RACE');
      WriteLn( '   POINTS');
      WriteLn;
      WriteLn( ' STRENGTH');
      WriteLn( '     I.Q.');
      WriteLn( '    PIETY');
      WriteLn( ' VITALITY');
      WriteLn( '  AGILITY');
      WriteLn( '     LUCK');
      WriteLn;
      WriteLn( 'ALIGNMENT');
      WriteLn( '    CLASS');
      WriteLn
    end;


    { ── CHOSRACE ── }
    procedure CHOSRACE;
    var
      RACEI : TRACE;
    begin
      P010B0B;
      GotoXY( 0, 17);
      for RACEI := HUMAN to HOBBIT do
        begin
          Write( Chr( Ord( '@') + Byte( RACEI)));
          Write( ') ');
          WriteLn( RACENAME( Byte( RACEI)))
        end;
      repeat
        P010B0C;
        Write( 'CHOOSE A RACE >');
        GETKEY
      until (INCHAR >= 'A') and (INCHAR <= 'E');
      GotoXY( 10, 2);
      SETRACE_RL( @CHARREC, HUMAN);
      while INCHAR > 'A' do
        begin
          INCHAR := PRED( INCHAR);
          CHARREC.RACE := SUCC( CHARREC.RACE)
        end;
      Write( RACENAME( Byte( CHARREC.RACE)));
      SETBASE
    end;


    { ── GIVEPTS ── }
    procedure GIVEPTS;
    var
      CANCHG  : Boolean;
      ATTRIBX : TATTRIB;
      CLASSX  : TCLASS;

      procedure PTSMENU;
      begin
        GotoXY( 0, 15);
        Write( Chr( 11));
        WriteLn( 'ENTER [+,-] TO ALTER A SCORE,');
        WriteLn( '      [RET] TO GO TO NEXT SCORE,');
        WriteLn( '      [ESC] TO GO ON WHEN POINTS USED UP');
        PTSLEFT := 7 + RNDN( 4);
        while (PTSLEFT < 20) and ((RNDN( 11)) = 10) do
          PTSLEFT := PTSLEFT + 10;
        SIXATTR2 := BASEATTR;
        for ATTRIBX := STRENGTH to LUCK do
          begin
            GotoXY( 10, 5 + Byte( ATTRIBX));
            WRITEINT( SIXATTR2[ ATTRIBX], 2)
          end;
        ATTRIBX := STRENGTH;
        CANCHG  := false
      end;

    begin  { GIVEPTS }
      PTSMENU;
      repeat
        GotoXY( 13, 5 + Byte( ATTRIBX));
        Write( '<--');
        repeat
          GotoXY( 10, 3);
          WRITEINT( PTSLEFT, 2);
          GotoXY( 41, 0);
          GETKEY;
          if ((INCHAR = '+') or (INCHAR = ';')) and
             (SIXATTR2[ ATTRIBX] < 18) and
             (PTSLEFT > 0) then
            begin
              SIXATTR2[ ATTRIBX] := SIXATTR2[ ATTRIBX] + 1;
              PTSLEFT             := PTSLEFT - 1
            end
          else
            begin
              if ((INCHAR = '-') or (INCHAR = '=')) and
                 (SIXATTR2[ ATTRIBX] > BASEATTR[ ATTRIBX]) then
                begin
                  SIXATTR2[ ATTRIBX] := SIXATTR2[ ATTRIBX] - 1;
                  PTSLEFT             := PTSLEFT + 1
                end
            end;
          if (INCHAR = '+') or (INCHAR = '-') or
             (INCHAR = ';') or (INCHAR = '=') then
            begin
              GotoXY( 10, 5 + Byte( ATTRIBX));
              WRITEINT( SIXATTR2[ ATTRIBX], 2);
              CANCHG := GTCHGLST;
              for CLASSX := FIGHTER to NINJA do
                begin
                  GotoXY( 20, 5 + Byte( CLASSX));
                  if CHG2LST[ CLASSX] then
                    begin
                      Write( Chr( Ord( 'A') + Byte( CLASSX)));
                      Write( ') ');
                      Write( CLASSNAME( Byte( CLASSX)))
                    end
                  else
                    Write( Chr( 29))
                end
            end
        until (INCHAR = Chr( 27)) or (INCHAR = Chr( CRETURN));
        if INCHAR = Chr( CRETURN) then
          begin
            GotoXY( 13, 5 + Byte( ATTRIBX));
            Write( '   ');
            if ATTRIBX < LUCK then
              ATTRIBX := SUCC( ATTRIBX)
            else
              ATTRIBX := STRENGTH
          end
      until (INCHAR = Chr( 27)) and CANCHG and (PTSLEFT = 0);
      repeat
        repeat
          P010B0B;
          Write( 'CHOOSE A CLASS >');
          GETKEY
        until (INCHAR >= 'A') and (INCHAR <= 'H');
        CLASSX := FIGHTER;
        while INCHAR > 'A' do
          begin
            CLASSX := SUCC( CLASSX);
            INCHAR := PRED( INCHAR)
          end
      until CHG2LST[ CLASSX];
      GotoXY( 10, 13);
      Write( CLASSNAME( Byte( CLASSX)));
      CHARREC.XCLASS := CLASSX;
      for ATTRIBX := STRENGTH to LUCK do
        CHARREC.ATTRIB[ ATTRIBX] := SIXATTR2[ ATTRIBX]
    end;  { GIVEPTS }


    { ── CHOSALIG ── }
    procedure CHOSALIG;
    var
      ALIGNX : TALIGN;
    begin
      P010B0B;
      GotoXY( 0, 17);
      for ALIGNX := GOOD to EVIL do
        begin
          Write( Chr( Ord( '@') + Byte( ALIGNX)));
          Write( ') ');
          WriteLn( ALIGNNAME( Byte( ALIGNX)))
        end;
      repeat
        P010B0C;
        Write( 'CHOOSE AN ALIGNMENT >');
        GETKEY
      until (INCHAR >= 'A') and (INCHAR <= 'C');
      if INCHAR = 'A' then
        SETALIGN_RL( @CHARREC, GOOD)
      else if INCHAR = 'B' then
        SETALIGN_RL( @CHARREC, NEUTRAL)
      else
        SETALIGN_RL( @CHARREC, EVIL);
      GotoXY( 10, 12);
      Write( ALIGNNAME( Byte( CHARREC.ALIGN)))
    end;


    { ── KEEPCHYN ── }
    function KEEPCHYN: Byte;
    var
      VITHPMOD : SmallInt;
      CLSHPMOD : SmallInt;
      SKN      : PTSPELLSKN;
    begin
      KEEPCHYN := UNWNONE;
      repeat
        P010B0B;
        Write( 'KEEP THIS CHARACTER (Y/N)? >');
        GETKEY
      until (INCHAR = 'Y') or (INCHAR = 'N');
      if INCHAR = 'N' then exit( U_MAKECHAR);          { EXIT( MAKECHAR) }

      SKN := CHARREC.SPELLSKN;
      if (CHARREC.XCLASS = MAGE) or (CHARREC.XCLASS = BISHOP) then
        begin
          SKN^[  3] := true;
          SKN^[  1] := true;
          CHARREC.MAGESP[ 1] := 2
        end;
      if CHARREC.XCLASS = PRIEST then
        begin
          SKN^[ 23] := true;
          SKN^[ 24] := true;
          CHARREC.PRIESTSP[ 1] := 2
        end;

      case Byte( CHARREC.XCLASS) of
        Byte( FIGHTER),
        Byte( LORD):    CLSHPMOD := 10;
        Byte( PRIEST):  CLSHPMOD :=  8;
        Byte( THIEF),
        Byte( BISHOP),
        Byte( NINJA):   CLSHPMOD :=  6;
        Byte( MAGE):    CLSHPMOD :=  4;
        Byte( SAMURAI): CLSHPMOD := 16;
      else              CLSHPMOD :=  6;
      end;

      VITHPMOD := 0;
      case Byte( CHARREC.ATTRIB[ VITALITY]) of
         3:      VITHPMOD := -2;
        4, 5:    VITHPMOD := -1;
        16:      VITHPMOD :=  1;
        17:      VITHPMOD :=  2;
        18:      VITHPMOD :=  3;
      end;

      CLSHPMOD := CLSHPMOD + VITHPMOD;
      for LLBASE04 := 1 to 2 do
        if RNDN( 2) = 1 then
          CLSHPMOD := (9 * CLSHPMOD) div 10;
      if CLSHPMOD < 2 then CLSHPMOD := 2;
      CHARREC.HPMAX  := CLSHPMOD;
      CHARREC.HPLEFT := CLSHPMOD
    end;


  begin  { MAKECHAR }
    INITCHAR;
    MAKEMENU;
    CHOSRACE;
    CHOSALIG;
    GIVEPTS;
    if KEEPCHYN = U_MAKECHAR then exit;
    SAVETCHAR( CHARACX, CHARREC)
  end;  { MAKECHAR }


  { ── CREATE ── }
  procedure CREATE;
  var
    CHARRECI  : SmallInt;

    function EXITCREA( EXITSTR: string): Byte;
    begin
      WriteLn;
      WriteLn;
      WriteLn( EXITSTR);
      WriteLn;
      WriteLn( 'PRESS ANY KEY TO CONTINUE');
      GotoXY( 41, 0);
      GETKEY;
      EXITCREA := U_CREATE                              { EXIT( CREATE) }
    end;

  begin  { CREATE }
    CHARACX := -1;
    for CHARRECI := 0 to SCNTOC.RECPERDK[ ZCHAR] - 1 do
      begin
        if CHARACX < 0 then
          begin
            LOADTCHAR( CHARRECI, CHARREC);
            if CHARREC.STATUS = LOST then CHARACX := CHARRECI
          end
      end;
    if CHARACX = -1 then
      if EXITCREA( 'THERE IS NO ROOM LEFT - TRY DELETING') = U_CREATE then exit;
    WriteLn;
    WriteLn;
    WriteLn( 'THAT CHARACTER DOES NOT EXIST. DO YOU');
    Write(   'WANT TO CREATE IT (Y/N) ?> ');
    repeat
      Write( Chr( 8));
      GETKEY
    until (INCHAR = 'Y') or (INCHAR = 'N');
    if INCHAR = 'N' then exit;
    MAKECHAR
  end;


  { ── DSP20NM ── }
  procedure DSP20NM;
  var
    LINECNT : SmallInt;
    CHARI   : SmallInt;
  begin
    ClrScr;
    WriteLn( 'NAMES IN USE:');
    WriteLn( '----------------------------------------');
    LINECNT := 0;
    for CHARI := 0 to SCNTOC.RECPERDK[ ZCHAR] - 1 do
      begin
        LOADTCHAR( CHARI, CHARREC);
        if CHARREC.STATUS <> LOST then
          begin
            LINECNT := LINECNT + 1;
            GotoXY( 0, LINECNT + 1);
            Write( CHARREC.NAME);
            Write( ' LEVEL ');
            Write( CHARREC.CHARLEV);
            Write( ' ');
            Write( RACENAME(   Byte( CHARREC.RACE)));
            Write( ' ');
            Write( CLASSNAME(  Byte( CHARREC.XCLASS)));
            Write( ' (');
            Write( STATNAME( Byte( CHARREC.STATUS)));
            Write( ')');
            if CHARREC.INMAZE or (CHARREC.LOSTXYL[ 3] <> 0) then   { v3.2 WC032 }
              Write( ' OUT')
          end
      end;
    GotoXY( 0, 22);
    WriteLn( '----------------------------------------');
    Write( 'YOU MAY L)EAVE WHEN READY');
    repeat GotoXY( 41, 0); GETKEY until INCHAR = 'L';
    INCHAR := Chr( 0)
  end;


  { ── TRAINING ── }
  function TRAINING: Byte;
  var
    U            : Byte;


    { ── LOSECHAR ── }
    procedure LOSECHAR;
    begin
      SETSTATUS_RL( @CHARREC, LOST);
      CHARREC.INMAZE := false;
      SAVETCHAR( CHARACX, CHARREC);
      GTSCNTOC
    end;


    { ── INSPECT ── }
    function INSPECT: Byte;
    begin
      PARTYCNT      := 1;
      PSLOT  := CHARACTR[ 0];
      COPYCHAR( PSLOT^, CHARREC);
      CHARDISK[ 0]  := CHARACX;
      XGOTO         := XINSPCT3;
      INSPECT       := U_ROLLER                         { EXIT( ROLLER) }
    end;


    { ── RUSUREYN ── }
    procedure RUSUREYN( DELSTR: string);
    begin
      repeat
        ClrScr;
        Write( 'ARE YOU SURE YOU WANT TO ');
        Write( DELSTR);
        Write( ' (Y/N) ?');
        GETKEY
      until (INCHAR = 'Y') or (INCHAR = 'N')
    end;


    { ── DELCHAR ── }
    function DELCHAR: Byte;
    begin
      DELCHAR := UNWNONE;
      RUSUREYN( 'DELETE');
      if INCHAR = 'N' then exit;                        { EXIT( DELCHAR) }
      LOSECHAR;
      DELCHAR := U_TRAINING                             { EXIT( TRAINING) }
    end;


    { ── CHGCLASS ── }
    procedure CHGCLASS;
    var
      ATTRIBI : TATTRIB;
      CLASSX  : TCLASS;
      PP      : ^TPOSSESS;
      SKN     : PTSPELLSKN;
    begin
      GotoXY( 0, 2);
      WriteLn( Chr( 11));
      for ATTRIBI := STRENGTH to LUCK do
        SIXATTR2[ ATTRIBI] := CHARREC.ATTRIB[ ATTRIBI];
      if GTCHGLST then;   { side-effect: fills CHG2LST }
      for CLASSX := FIGHTER to NINJA do
        if CHG2LST[ CLASSX] and (CLASSX <> CHARREC.XCLASS) then
          begin
            Write( Chr( Ord('A') + Byte( CLASSX)));
            Write( ') ');
            WriteLn( CLASSNAME( Byte( CLASSX)))
          end;
      WriteLn;
      WriteLn( 'PRESS [LETTER] TO CHANGE CLASS');
      WriteLn( '         [RET] TO NOT CHANGE CLASS');
      repeat
        repeat
          GotoXY( 41, 0);
          GETKEY
        until (INCHAR = Chr( CRETURN)) or
              ((INCHAR >= 'A') and (INCHAR <= 'H'));
        if INCHAR = Chr( CRETURN) then exit;   { EXIT(CHGCLASS) }
        CLASSX := FIGHTER;
        while INCHAR > 'A' do
          begin
            CLASSX := SUCC( CLASSX);
            INCHAR := PRED( INCHAR)
          end
      until CHG2LST[ CLASSX] and (CLASSX <> CHARREC.XCLASS);

      SETBASE;
      for ATTRIBI := STRENGTH to LUCK do
        CHARREC.ATTRIB[ ATTRIBI] := BASEATTR[ ATTRIBI];
      SETCLASS_RL( @CHARREC, CLASSX);
      CHARREC.CHARLEV   := 1;
      CHARREC.EXP.XHIGH := 0;
      CHARREC.EXP.XMID  := 0;
      CHARREC.EXP.XLOW  := 0;
      CHARREC.AGE       := CHARREC.AGE + 52 * RNDN( 3) + 252;

      SKN := CHARREC.SPELLSKN;
      if CLASSX = MAGE then
        SKN^[ 3] := true
      else if CLASSX = PRIEST then
        SKN^[ 23] := true;

      for TEMPX := 1 to 7 do
        begin
          CHARREC.MAGESP[   TEMPX] := 0;
          CHARREC.PRIESTSP[ TEMPX] := 0
        end;
      for TEMPX := 1 to CHARREC.POSS.POSSCNT do
        begin
          PCHARREC := @CHARREC;
          PP := PCHARREC.POSS.POSSESS[ TEMPX];
          if not PP.CURSED then PP.EQUIPED := false
        end;
      SAVETCHAR( CHARACX, CHARREC);
      GTSCNTOC
    end;


  begin  { TRAINING }
    Result   := UNWNONE;
    PARTYCNT := 0;
    if XGOTO = XBCK2ROL then
      begin
        XGOTO   := XTRAININ;
        PSLOT   := CHARACTR[ 0];
        COPYCHAR( CHARREC, PSLOT^);
        CHARACX := CHARDISK[ 0]
      end;

    repeat
      ClrScr;
      Write( CHARREC.NAME);
      Write( ' LEVEL ');
      Write( CHARREC.CHARLEV);
      Write( ' ');
      Write( RACENAME(   Byte( CHARREC.RACE)));
      Write( ' ');
      Write( CLASSNAME(  Byte( CHARREC.XCLASS)));
      Write( ' (');
      Write( STATNAME( Byte( CHARREC.STATUS)));
      WriteLn( ')');
      WriteLn;
      WriteLn( 'YOU MAY I)NSPECT THIS CHARACTER,');
      WriteLn( '        D)ELETE  THIS CHARACTER,');
      WriteLn( '        R)EROLL  THIS CHARACTER,');
      WriteLn( '        C)HANGE  CLASS, OR');
      WriteLn( '  PRESS [RET] TO LEAVE');
      GotoXY( 41, 0);
      GETKEY;
      if INCHAR = Chr( CRETURN) then exit;              { EXIT( TRAINING) }
      case INCHAR of
        'I': exit( INSPECT);                            { only U_ROLLER }
        'D': if DELCHAR = U_TRAINING then exit;
        'C': CHGCLASS;
        'R': begin
               RUSUREYN( 'REROLL');
               if INCHAR = 'Y' then
                 begin
                   CHARNAME := CHARREC.NAME;
                   LOSECHAR;
                   MAKECHAR
                 end
             end;
      end
    until false
  end;  { TRAINING }


begin  { ROLLER }
  WIRECHAR( CHARREC, CRSKN, CRPOSS);
  if XGOTO = XBCK2ROL then
    if TRAINING = U_ROLLER then exit;
  repeat
    ClrScr;
    Write( '            ');
    WriteLn( 'TRAINING GROUNDS');
    WriteLn;
    WriteLn( 'YOU MAY ENTER A CHARACTER NAME TO ADD,');
    Write( '        ');
    WriteLn( 'INSPECT OR EDIT,');
    WriteLn;
    Write( '        ');
    WriteLn( '"*ROSTER" TO SEE ROSTER,');
    WriteLn;
    WriteLn( '       OR PRESS [RET] FOR CASTLE.');
    repeat
      GotoXY( 13, 9);
      Write( Chr( 11));
      Write( 'NAME >');
      GETLINE;
      CHARNAME := GTSTRING;
      if CHARNAME = '' then
        begin
          ClrScr;
          XGOTO := XCASTLE;
          exit                                          { EXIT( ROLLER) }
        end
    until Length( CHARNAME) <= 15;
    if CHARNAME = '*ROSTER' then
      DSP20NM
    else
      begin
        CHARACX := -1;
        for TEMPX := 0 to SCNTOC.RECPERDK[ ZCHAR] - 1 do
          if CHARACX < 0 then
            begin
              LOADTCHAR( TEMPX, CHARREC);
              if (CHARREC.STATUS <> LOST) and (CHARREC.NAME = CHARNAME) then
                CHARACX := TEMPX
            end;
        if CHARACX < 0 then
          CREATE
        else
          if TRAINING = U_ROLLER then exit
      end
  until false
end;  { ROLLER }


end.
