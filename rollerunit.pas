unit ROLLERUNIT;

{ Source: apple/wiz1c/ROLLER

  Translation notes:
    - SEGMENT PROCEDURE ROLLER -> unit procedure ROLLER
    - EXIT(ROLLER)        -> _done := true; break (main loop) or exit
    - EXIT(MAKECHAR)      -> _exitmakechar := true; exit
    - EXIT(CREATE)        -> _exitcreate := true; exit
    - EXIT(TRAINING)      -> exit (from within TRAINING) or _exittraining flag
    - EXIT(DELCHAR/etc.)  -> exit (from within that procedure)
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
    - WRITE(CHR(12)) -> ClrScr
    - GOTOXY(x,y)    -> GotoXY(x+1, y+1)  (CRT is 1-based)
    - GOTOXY(41,0)   -> (no-op: off-screen position used to suppress key echo)
    - CHR(11)        -> cursor-down approximated / no-op
    - CHR(29)        -> no-op
    - GETLINE(VAR S) -> GETLINE; S := GTSTRING
    - RANDOM MOD N   -> Random(N)
    - CHG2LST array[FIGHTER..NINJA] -> indexed by Byte(TCLASS)
    - BASEATTR/SIXATTR2 array[STRENGTH..LUCK] -> indexed by Byte(TATTRIB)
    - SUCC(enum) -> SUCC(enum) — try first; fallback cast if MP fails
}

interface

uses TYPES, CONSTS, GLOBALS, UTIL, crt;

procedure ROLLER;

implementation

{ Unit-level helpers for enum assignment (bug4: nested proc/case re-types
  non-zero enum constants as Byte; typed parameter restores correct type). }
{ Access enum fields of TCHAR via PTCHAR pointer (avoids nested-scope type loss). }
procedure SETALIGN_RL( TC: PTCHAR; V: TALIGN);  begin TC.ALIGN  := TALIGN( Byte(V)) end;
procedure SETSTATUS_RL(TC: PTCHAR; V: TSTATUS); begin TC.STATUS := TSTATUS(Byte(V)) end;
procedure SETRACE_RL(  TC: PTCHAR; V: TRACE);   begin TC.RACE   := TRACE(  Byte(V)) end;
procedure SETCLASS_RL( TC: PTCHAR; V: TCLASS);  begin TC.XCLASS := TCLASS( Byte(V)) end;

{ MP comparison operators return BYTE, not Boolean; this bridges the gap. }
function BSET(B: Byte): Boolean;
begin
  if B <> 0 then BSET := true else BSET := false
end;


{ ══════════════════════════════════════════════════════════════════════════════
  ROLLER
  ══════════════════════════════════════════════════════════════════════════════ }

procedure ROLLER;

var
  CHARREC  : TCHAR;
  TEMPX    : SmallInt;
  CHARACX  : SmallInt;
  PTSLEFT  : SmallInt;
  CHARNAME : string[ 15];
  CHG2LST  : array[ FIGHTER..NINJA]   of Boolean;
  BASEATTR : array[ STRENGTH..LUCK]   of SmallInt;
  SIXATTR2 : array[ STRENGTH..LUCK]   of SmallInt;
  _done    : Boolean;   { EXIT(ROLLER) from nested procs }


  { ── GETPASS ── }
  procedure GETPASS( var PASSWORD: string);
  var
    RANDX  : SmallInt;
    CHRCNT : SmallInt;
  begin
    CHRCNT := 0;
    repeat
      GETKEY;
      if INCHAR <> Chr( CRETURN) then
        if CHRCNT < 15 then
          begin
            for RANDX := 0 to Random( 2) do
              Write( 'X');
            CHRCNT              := CHRCNT + 1;
            PASSWORD[ CHRCNT]   := INCHAR
          end
        else
          Write( Chr( 7))
    until INCHAR = Chr( CRETURN);
    WriteLn;
    PASSWORD[ 0] := Chr( CHRCNT)
  end;


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

    CHG2LST[ NINJA]   := BSET((SIXATTR2[ STRENGTH] >= 17) and
                         (SIXATTR2[ IQ] >= 17) and
                         (SIXATTR2[ PIETY] >= 17) and
                         (SIXATTR2[ VITALITY] >= 17) and
                         (SIXATTR2[ AGILITY] >= 17) and
                         (SIXATTR2[ LUCK] >= 17) and
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
  var
    _exitmakechar : Boolean;


    { ── INITCHAR ── }
    procedure INITCHAR;
    var
      LSI : SmallInt;
      I   : SmallInt;
    begin
      FillChar( CHARREC, SizeOf( CHARREC), 0);
      GetMem( CHARREC.SPELLSKN);                  { allocate SPELLSKN pointer }
      FillChar( CHARREC.SPELLSKN^, SizeOf( TSPELLSKN), 0);
      for I := 0 to 8 do                         { allocate possession slots }
        begin
          GetMem( CHARREC.POSS.POSSESS[ I]);
          FillChar( CHARREC.POSS.POSSESS[ I]^, SizeOf( TPOSSESS), 0)
        end;
      CHARREC.NAME      := CHARNAME;
      CHARREC.AGE       := (18 * 52) + Random( 300);
      CHARREC.GOLD.XLOW := 90 + Random( 100);
      SETSTATUS_RL( @CHARREC, OK);
      for LSI := 0 to 4 do
        CHARREC.LUCKSKIL[ LSI] := 16;
      CHARREC.MAXLEVAC  := 1;
      CHARREC.CHARLEV   := 1;
      CHARREC.ARMORCL   := 10
    end;


    { ── MAKEMENU ── }
    procedure MAKEMENU;
    var
      PASSWD : string[ 15];
    begin
      ClrScr;
      Write(   'NAME':10);
      WriteLn( CHARREC.NAME);
      WriteLn( 'PASSWORD':9);
      WriteLn( 'RACE':9);
      WriteLn( 'POINTS':9);
      WriteLn;
      WriteLn( 'STRENGTH':9);
      WriteLn( 'I.Q.':9);
      WriteLn( 'PIETY':9);
      WriteLn( 'VITALITY':9);
      WriteLn( 'AGILITY':9);
      WriteLn( 'LUCK':9);
      WriteLn;
      WriteLn( 'ALIGNMENT');
      WriteLn( 'CLASS':9);
      WriteLn;
      repeat
        GotoXY( 1, 16);
        WriteLn( 'ENTER A PASSWORD ([RET] FOR NONE)');
        GotoXY( 11, 2);
        GETPASS( CHARNAME);
        if Length( CHARNAME) > 15 then
          CHARNAME := Copy( CHARNAME, 1, 15);
        GotoXY( 1, 16);
        WriteLn( 'ENTER IT AGAIN TO BE SURE');
        GotoXY( 11, 2);
        GETPASS( PASSWD);
      until PASSWD = CHARNAME;
      CHARREC.PASSWORD := CHARNAME
    end;


    { ── CHOSRACE ── }
    procedure CHOSRACE;
    var
      RACEI : TRACE;
    begin
      GotoXY( 1, 16);
      GotoXY( 1, 18);
      for RACEI := HUMAN to HOBBIT do
        begin
          Write( Chr( Ord( '@') + Byte( RACEI)));
          Write( ') ');
          WriteLn( SCNTOC_RACE[ Byte( RACEI)])
        end;
      repeat
        GotoXY( 1, 16);
        Write( 'CHOOSE A RACE >');
        GETKEY
      until (INCHAR >= 'A') and (INCHAR <= 'E');
      GotoXY( 11, 3);
      SETRACE_RL( @CHARREC, HUMAN);
      while INCHAR > 'A' do
        begin
          INCHAR := PRED( INCHAR);
          CHARREC.RACE := SUCC( CHARREC.RACE)
        end;
      Write( SCNTOC_RACE[ Byte( CHARREC.RACE)]);
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
        GotoXY( 1, 16);
        WriteLn( 'ENTER [+,-] TO ALTER A SCORE,');
        WriteLn( '      [RET] TO GO TO NEXT SCORE,');
        WriteLn( '      [ESC] TO GO ON WHEN POINTS USED UP');
        PTSLEFT := 7 + Random( 4);
        while (PTSLEFT < 20) and ((Random( 11)) = 10) do
          PTSLEFT := PTSLEFT + 10;
        SIXATTR2 := BASEATTR;
        for ATTRIBX := STRENGTH to LUCK do
          begin
            GotoXY( 11, 6 + Byte( ATTRIBX));
            Write( SIXATTR2[ ATTRIBX]:2)
          end;
        ATTRIBX := STRENGTH;
        CANCHG  := false
      end;

    begin  { GIVEPTS }
      PTSMENU;
      repeat
        GotoXY( 14, 6 + Byte( ATTRIBX));
        Write( '<--');
        repeat
          GotoXY( 11, 4);
          Write( PTSLEFT:2);
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
              GotoXY( 11, 6 + Byte( ATTRIBX));
              Write( SIXATTR2[ ATTRIBX]:2);
              CANCHG := GTCHGLST;
              for CLASSX := FIGHTER to NINJA do
                begin
                  GotoXY( 21, 6 + Byte( CLASSX));
                  if CHG2LST[ CLASSX] then
                    begin
                      Write( Chr( Ord( 'A') + Byte( CLASSX)));
                      Write( ') ');
                      Write( SCNTOC_CLASS[ Byte( CLASSX)])
                    end
                  else
                    Write( '   ')
                end
            end
        until (INCHAR = Chr( 27)) or (INCHAR = Chr( CRETURN));
        if INCHAR = Chr( CRETURN) then
          begin
            GotoXY( 14, 6 + Byte( ATTRIBX));
            Write( '   ');
            if ATTRIBX < LUCK then
              ATTRIBX := SUCC( ATTRIBX)
            else
              ATTRIBX := STRENGTH
          end
      until (INCHAR = Chr( 27)) and CANCHG and (PTSLEFT = 0);
      repeat
        repeat
          GotoXY( 1, 16);
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
      GotoXY( 11, 14);
      Write( SCNTOC_CLASS[ Byte( CLASSX)]);
      CHARREC.XCLASS := CLASSX;
      for ATTRIBX := STRENGTH to LUCK do
        CHARREC.ATTRIB[ ATTRIBX] := SIXATTR2[ ATTRIBX]
    end;  { GIVEPTS }


    { ── CHOSALIG ── }
    procedure CHOSALIG;
    var
      ALIGNX : TALIGN;
    begin
      GotoXY( 1, 16);
      GotoXY( 1, 18);
      for ALIGNX := GOOD to EVIL do
        begin
          Write( Chr( Ord( '@') + Byte( ALIGNX)));
          Write( ') ');
          WriteLn( SCNTOC_ALIGN[ Byte( ALIGNX)])
        end;
      repeat
        GotoXY( 1, 16);
        Write( 'CHOOSE AN ALIGNMENT >');
        GETKEY
      until (INCHAR >= 'A') and (INCHAR <= 'C');
      if INCHAR = 'A' then
        SETALIGN_RL( @CHARREC, GOOD)
      else if INCHAR = 'B' then
        SETALIGN_RL( @CHARREC, NEUTRAL)
      else
        SETALIGN_RL( @CHARREC, EVIL);
      GotoXY( 11, 13);
      Write( SCNTOC_ALIGN[ Byte( CHARREC.ALIGN)])
    end;


    { ── KEEPCHYN ── }
    procedure KEEPCHYN;
    var
      VITHPMOD : SmallInt;
      CLSHPMOD : SmallInt;
      SKN      : PTSPELLSKN;
    begin
      repeat
        GotoXY( 1, 16);
        Write( 'KEEP THIS CHARACTER (Y/N)? >');
        GETKEY
      until (INCHAR = 'Y') or (INCHAR = 'N');
      if INCHAR = 'N' then begin _exitmakechar := true; exit; end;  { EXIT(MAKECHAR) }

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
        if Random( 2) = 1 then
          CLSHPMOD := (9 * CLSHPMOD) div 10;
      if CLSHPMOD < 2 then CLSHPMOD := 2;
      CHARREC.HPMAX  := CLSHPMOD;
      CHARREC.HPLEFT := CLSHPMOD
    end;


  begin  { MAKECHAR }
    _exitmakechar := false;
    INITCHAR;
    MAKEMENU;
    CHOSRACE;
    CHOSALIG;
    GIVEPTS;
    KEEPCHYN;
    if _exitmakechar then exit;
    SAVETCHAR( CHARACX, CHARREC)
  end;  { MAKECHAR }


  { ── CREATE ── }
  procedure CREATE;
  var
    CHARRECI  : SmallInt;
    _exitcreate : Boolean;

    procedure EXITCREA( EXITSTR: string);
    begin
      WriteLn;
      WriteLn;
      WriteLn( EXITSTR);
      WriteLn;
      WriteLn( 'PRESS ANY KEY TO CONTINUE');
      GETKEY;
      _exitcreate := true; exit   { EXIT(CREATE) }
    end;

  begin  { CREATE }
    _exitcreate := false;
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
      begin
        EXITCREA( 'THERE IS NO ROOM LEFT - TRY DELETING');
        if _exitcreate then exit
      end;
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
            GotoXY( 1, LINECNT + 2);
            Write( CHARREC.NAME);
            Write( ' LEVEL ');
            Write( CHARREC.CHARLEV);
            Write( ' ');
            Write( SCNTOC_RACE[   Byte( CHARREC.RACE)]);
            Write( ' ');
            Write( SCNTOC_CLASS[  Byte( CHARREC.XCLASS)]);
            Write( ' (');
            Write( SCNTOC_STATUS[ Byte( CHARREC.STATUS)]);
            Write( ')');
            if CHARREC.INMAZE or (CHARREC.LOSTXYL[ 1] <> 0) then
              Write( ' OUT')
          end
      end;
    GotoXY( 1, 23);
    WriteLn( '----------------------------------------');
    Write( 'YOU MAY L)EAVE WHEN READY');
    repeat GETKEY until INCHAR = 'L';
    INCHAR := Chr( 0)
  end;


  { ── TRAINING ── }
  procedure TRAINING;
  var
    PASSSTR      : string[ 15];
    _exittraining : Boolean;


    { ── LOSECHAR ── }
    procedure LOSECHAR;
    begin
      SETSTATUS_RL( @CHARREC, LOST);
      CHARREC.INMAZE := false;
      SAVETCHAR( CHARACX, CHARREC);
      GTSCNTOC
    end;


    { ── INSPECT ── }
    procedure INSPECT;
    begin
      PARTYCNT      := 1;
      CHARACTR[ 0]^ := CHARREC;
      CHARDISK[ 0]  := CHARACX;
      XGOTO         := XINSPCT3;
      _done         := true; exit   { EXIT(ROLLER) }
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
    procedure DELCHAR;
    begin
      RUSUREYN( 'DELETE');
      if INCHAR = 'N' then exit;   { EXIT(DELCHAR) }
      LOSECHAR;
      _exittraining := true; exit   { EXIT(TRAINING) }
    end;


    { ── CHGCLASS ── }
    procedure CHGCLASS;
    var
      ATTRIBI : TATTRIB;
      CLASSX  : TCLASS;
      PP      : ^TPOSSESS;
      SKN     : PTSPELLSKN;
    begin
      GotoXY( 1, 3);
      for ATTRIBI := STRENGTH to LUCK do
        SIXATTR2[ ATTRIBI] := CHARREC.ATTRIB[ ATTRIBI];
      if GTCHGLST then;   { side-effect: fills CHG2LST }
      for CLASSX := FIGHTER to NINJA do
        if CHG2LST[ CLASSX] and (CLASSX <> CHARREC.XCLASS) then
          begin
            Write( Chr( Ord('A') + Byte( CLASSX)));
            Write( ') ');
            WriteLn( SCNTOC_CLASS[ Byte( CLASSX)])
          end;
      WriteLn;
      WriteLn( 'PRESS [LETTER] TO CHANGE CLASS');
      WriteLn( '[RET] TO NOT CHANGE CLASS':34);
      repeat
        repeat
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
      CHARREC.AGE       := CHARREC.AGE + 52 * Random( 3) + 252;

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
          PP := CHARREC.POSS.POSSESS[ TEMPX];
          if not PP.CURSED then PP.EQUIPED := false
        end;
      SAVETCHAR( CHARACX, CHARREC);
      GTSCNTOC
    end;


    { ── CHGPASS ── }
    procedure CHGPASS;
    var
      NEWPASS1 : string[ 15];
      NEWPASS2 : string[ 15];
    begin
      ClrScr;
      Write( 'ENTER NEW PASSWORD ([RET] FOR NONE)');
      repeat
        GotoXY( 11, 3);
        GETPASS( NEWPASS1)
      until Length( NEWPASS1) <= 15;
      ClrScr;
      Write( 'ENTER AGAIN TO BE SURE');
      repeat
        GotoXY( 11, 3);
        GETPASS( NEWPASS2)
      until Length( NEWPASS2) <= 15;
      ClrScr;
      if NEWPASS1 = NEWPASS2 then
        begin
          CHARREC.PASSWORD := NEWPASS1;
          SAVETCHAR( CHARACX, CHARREC);
          GTSCNTOC;
          Write( 'PASSWORD CHANGED - ')
        end
      else
        begin
          WriteLn( 'THEY ARE NOT THE SAME - YOUR PASSWORD');
          WriteLn( 'HAS NOT BEEN CHANGED!');
          WriteLn;
        end;
      Write( 'PRESS [RET]');
      ReadLn;
    end;


  begin  { TRAINING }
    _exittraining := false;
    PARTYCNT      := 0;
    if XGOTO <> XBCK2ROL then
      begin
        repeat
          GotoXY( 10, 11);
          Write( 'PASSWORD >');
          GETPASS( PASSSTR)
        until Length( PASSSTR) <= 15;
        if PASSSTR <> CHARREC.PASSWORD then exit   { EXIT(TRAINING) — wrong pass }
      end
    else
      begin
        XGOTO   := XTRAININ;
        CHARREC := CHARACTR[ 0]^;
        CHARACX := CHARDISK[ 0]
      end;

    repeat
      ClrScr;
      Write( CHARREC.NAME);
      Write( ' LEVEL ');
      Write( CHARREC.CHARLEV);
      Write( ' ');
      Write( SCNTOC_RACE[   Byte( CHARREC.RACE)]);
      Write( ' ');
      Write( SCNTOC_CLASS[  Byte( CHARREC.XCLASS)]);
      Write( ' (');
      Write( SCNTOC_STATUS[ Byte( CHARREC.STATUS)]);
      WriteLn( ')');
      WriteLn;
      WriteLn( 'YOU MAY I)NSPECT THIS CHARACTER,');
      WriteLn( 'D)ELETE  THIS CHARACTER,':32);
      WriteLn( 'R)EROLL  THIS CHARACTER,':32);
      WriteLn( 'C)HANGE  CLASS,':23);
      WriteLn( 'S)ET NEW PASSWORD, OR':29);
      WriteLn( '  PRESS [RET] TO LEAVE');
      GETKEY;
      if INCHAR = Chr( CRETURN) then exit;   { EXIT(TRAINING) }
      case INCHAR of
        'I': begin INSPECT;  if _done then exit; end;
        'D': begin DELCHAR;  if _exittraining or _done then exit; end;
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
        'S': CHGPASS;
      end;
      if _done then exit
    until false
  end;  { TRAINING }


begin  { ROLLER }
  _done := false;
  if XGOTO = XBCK2ROL then
    begin TRAINING; if _done then exit; end;
  repeat
    ClrScr;
    Write(   ' ':12);
    WriteLn( 'TRAINING GROUNDS');
    WriteLn;
    WriteLn( 'YOU MAY ENTER A CHARACTER NAME TO ADD,');
    Write(   ' ':8);
    WriteLn( 'INSPECT OR EDIT,');
    WriteLn;
    Write(   ' ':8);
    WriteLn( '"*ROSTER" TO SEE ROSTER,');
    WriteLn;
    WriteLn( 'OR PRESS [RET] FOR CASTLE.':33);
    repeat
      GotoXY( 14, 10);
      Write( 'NAME >');
      GETLINE;
      CHARNAME := GTSTRING;
      if CHARNAME = '' then
        begin
          ClrScr;
          XGOTO := XCASTLE;
          break   { EXIT(ROLLER) — go to castle }
        end
    until Length( CHARNAME) <= 15;
    if _done or (XGOTO = XCASTLE) then break;
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
          begin CREATE;   if _done then break; end
        else
          begin TRAINING; if _done then break; end
      end
  until false
end;  { ROLLER }


end.
