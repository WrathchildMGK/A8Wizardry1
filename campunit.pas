unit CAMPUNIT;

{ Source: apple/wiz1c/CAMP, apple/wiz1c/CAMP2

  Translation notes:
    - SEGMENT PROCEDURE CAMP -> unit procedure CAMP
    - EXIT(CAMP)         -> _done := true; exit; propagate: if _done then exit
    - EXIT(CASTSPEL)     -> _exitcastspel := true (via EXITCASTSPEL); propagate within CASTSPEL
    - EXIT(CAMPDO)       -> exit (returns to INSPECT repeat loop)
    - EXIT(DROPITEM)     -> exit
    - EXIT(USEITEM)      -> exit
    - EXIT(DOTRADE)      -> _exittrade := true; propagate in DOTRADE
    - EXIT(DISBAND)      -> _exitdisband := true; propagate in DISBAND
    - EXIT(IDENTIFY_PROC) -> exit
    - EXIT(DSPITEMS)     -> exit
    - EXIT(CHKSPCNT)     -> exit (when USEITEM_B is true)
    - WITH CHARACTR[CAMPCHAR] DO -> TC := CHARACTR[CAMPCHAR]; TC.FIELD
    - WRITE(CHR(12))     -> ClrScr
    - GOTOXY(x,y)        -> GotoXY(x+1, y+1)  (CRT is 1-based)
    - GOTOXY(41,0)       -> GotoXY(41, 0)  (off-screen cursor park)
    - CHR(11)            -> WriteLn  (cursor-down / scroll approximation)
    - CHR(29)            -> no-op    (clear to EOL)
    - GETLINE(S)         -> GETLINE; S := GTSTRING
    - GETCHARX(B,'T')    -> GETCHARX(B, 'T')
    - UNITCLEAR(1)       -> CLEARPIC (all-Mode-E full screen clear)
    - TEXTMODE           -> TEXTMODE (from UTIL)
    - BASE12.GOTOX       -> XGOTO2
    - MOVELEFT(IOCACHE[GETREC(ZOBJECT,IDX,SZ)],OBJ,SZ) -> LOADOBJREC(IDX, OBJ)
    - MOVELEFT(IOCACHE[GETREC(ZZERO,0,SZ)],SCNTOC,SZ)  -> GTSCNTOC → GETREC + LOADSCNTOC
    - MOVELEFT(CH, IOCACHE[GETRECW(ZCHAR,IDX,SZ)],SZ)  -> SAVETCHAR(IDX, CH)
    - CHARREC.CLASS      -> CHARREC.XCLASS
    - SCNTOC.RACE/CLASS/ALIGN/STATUS -> SCNTOC_RACE/CLASS/ALIGN/STATUS globals
    - SCNTOC.SPELLHSH[X] -> SPTR.SPELLHSH[X] via SPTR := SCNTOC.SPELLS
    - LOSTXYL.POISNAMT[1] -> LOSTXYL[1]
    - LOSTXYL.LOCATION[1..3] -> LOSTXYL[1..3]
    - LOSTXYL.AWARDS[4]  -> LOSTXYL[4]
    - RANDOM MOD N       -> Random(N)
    - ARRAY[FALSE..TRUE] -> array[0..1]  (index with Byte(BOOL_EXPR))
    - CLASSUSE[CLASS]    -> CLASSUSE[Byte(TC.XCLASS)]
    - USEITEM (local Boolean in CASTSPEL) -> USEITEM_B (renamed to avoid proc name clash)
    - SUCC(STATUS)       -> TSTATUS(Byte(STATUS) + 1)  (safe for DEAD->ASHES->LOST)
    - STATUS < DEAD      -> Byte(STATUS) < Byte(DEAD)
    - BSET_CU()          -> converts BYTE comparison result to Boolean
}

interface

uses TYPES, CONSTS, GLOBALS, UTIL, crt;

procedure CAMP;

implementation

{ ── Unit-level constants ─────────────────────────────────────────────────── }
{ Chevron indicator chars: each char maps to a LOSTXYL[4] bit.
  '$' cannot appear raw in an MP string literal ($-signs start hex literals);
  use #36 char-code syntax instead. }
const
  CHEVTBL: array[0..15] of char = (
    '>','!',#36,'#','&','*','<','?','B','C','P','K','O','D','G','@');

{ ── Unit-level helpers ───────────────────────────────────────────────────── }

procedure SETSTATUS_CU(TC: PTCHAR; V: TSTATUS);
begin
  TC.STATUS := TSTATUS(Byte(V))
end;

function BSET_CU(B: Byte): Boolean;
begin
  if B <> 0 then BSET_CU := true else BSET_CU := false
end;


{ ══════════════════════════════════════════════════════════════════════════════
  CAMP
  ══════════════════════════════════════════════════════════════════════════════ }

procedure CAMP;

var
  OBJIDS   : array[ 0..7] of SmallInt;
  OBJNAMES : array[ 0..7] of array[ 0..1] of string[ 15];  { AP: ARRAY[FALSE..TRUE] OF STRING[15] }
  CURSEDXX : array[ 0..7] of Boolean;
  CANUSE   : array[ 0..7] of Boolean;
  DISPSTAT : Boolean;
  OBJI     : SmallInt;
  _done    : Boolean;


  { ── GTSCNTOC ── }
  procedure GTSCNTOC;
  var DUMMY : SmallInt;
  begin
    DUMMY := GETREC( ZZERO, 0, SizeOf( TSCNTOC));
    LOADSCNTOC
  end;


  { ── AASTRAA ── }
  procedure AASTRAA(ASTRA: string);
  begin
    CENTSTR( Concat( '** ', Concat( ASTRA, ' **')))
  end;


  { ── INSPECT ── }
  procedure INSPECT;

  var
    CAMPCHAR : SmallInt;
    TC       : PTCHAR;
    SKN      : PTSPELLSKN;


    { ── DSPSPELS ── }
    procedure DSPSPELS;
    var INDX : SmallInt;
    begin
      TC := CHARACTR[ CAMPCHAR];
      GotoXY( 1, 10);
      Write( ' ' : 7);
      Write( ' MAGE ');
      for INDX := 1 to 7 do
        begin
          Write( TC.MAGESP[ INDX]);
          if INDX < 7 then Write( '/')
        end;
      WriteLn;
      Write( ' ' : 6);
      Write( 'PRIEST ');
      for INDX := 1 to 7 do
        begin
          Write( TC.PRIESTSP[ INDX]);
          if INDX < 7 then Write( '/')
        end
    end;


    { ── DSPITEMS ── }
    procedure DSPITEMS;
    var
      ITEMX  : SmallInt;
      OBJREC : TOBJREC;
      PP     : ^TPOSSESS;
    begin
      TC := CHARACTR[ CAMPCHAR];
      GotoXY( 1, 13);
      Write( '*=EQUIP, -=CURSED, ?=UNKNOWN, #=UNUSABLE');
      for ITEMX := 14 to 17 do
        begin
          GotoXY( 1, ITEMX + 1);
          Write( ' ')
        end;
      if TC.POSS.POSSCNT = 0 then exit;
      for ITEMX := 1 to TC.POSS.POSSCNT do
        begin
          GotoXY( 21 - 20 * (ITEMX mod 2),
                  15 + ((ITEMX - 1) div 2));
          PP := TC.POSS.POSSESS[ ITEMX];
          if OBJIDS[ ITEMX - 1] <> PP.EQINDEX then
            begin
              LOADOBJREC( PP.EQINDEX, OBJREC);
              OBJIDS[ ITEMX - 1]    := PP.EQINDEX;
              OBJNAMES[ ITEMX-1][1] := OBJREC.NAME;
              OBJNAMES[ ITEMX-1][0] := OBJREC.NAMEUNK;
              CANUSE[   ITEMX - 1]  := OBJREC.CLASSUSE[ Byte( TC.XCLASS)];
              CURSEDXX[ ITEMX - 1]  := OBJREC.CURSED
            end;
          Write( ITEMX : 1);
          Write( ')');
          if PP.EQUIPED then
            if CURSEDXX[ ITEMX - 1] then Write( '-')
            else Write( '*')
          else
            if PP.IDENTIF then
              if CANUSE[ ITEMX - 1] then Write( ' ')
              else Write( '#')
            else Write( '?');
          Write( OBJNAMES[ ITEMX - 1][ Byte( PP.IDENTIF)])
        end
    end;


    { ── CASTSPEL ── }
    procedure CASTSPEL(SPELHASH: SmallInt);

    var
      USEITEM_B     : Boolean;   { AP: USEITEM — renamed to avoid clash with USEITEM proc }
      SPELNAME      : string[ 40];
      HASHCALC      : SmallInt;
      SPELLI        : SmallInt;
      HEALME        : SmallInt;
      TC_HEAL       : PTCHAR;
      SPTR          : ^TSPELBLK;
      _exitcastspel : Boolean;


      procedure EXITCASTSPEL(EXITSTR: string);  { AP: EXITCAST -> EXIT(CASTSPEL) }
      begin
        AASTRAA( EXITSTR);
        DSPSPELS;
        _exitcastspel := true
      end;


      procedure HEALWHO;
      begin
        HEALME := GETCHARX( true, 'CAST ON WHO');
        if HEALME = -1 then
          begin EXITCASTSPEL( 'NOT IN THE PARTY'); exit end
      end;


      procedure CHKSPCNT(PRIESTGR: SmallInt; SPELLIDX: SmallInt);
      begin
        if USEITEM_B then exit;
        TC   := CHARACTR[ CAMPCHAR];
        SKN  := TC.SPELLSKN;
        if (TC.PRIESTSP[ PRIESTGR] <= 0) or (not SKN^[ SPELLIDX]) then
          begin EXITCASTSPEL( 'YOU CANT CAST IT'); exit end
      end;


      procedure DECPRIEST(PRIESTGR: SmallInt);
      begin
        if not USEITEM_B then
          begin
            TC := CHARACTR[ CAMPCHAR];
            TC.PRIESTSP[ PRIESTGR] := TC.PRIESTSP[ PRIESTGR] - 1
          end;
        if FIZZLES > 0 then EXITCASTSPEL( 'SPELL HAS NO EFFECT')
      end;


      procedure DOHEAL(HPTRIES:  SmallInt;
                       MAXHPTRY: SmallInt;
                       PRIESTGR: SmallInt;
                       SPELLIDX: SmallInt);
      var HPHEALED : SmallInt;
      begin
        CHKSPCNT( PRIESTGR, SPELLIDX); if _exitcastspel then exit;
        HEALWHO;                        if _exitcastspel then exit;
        DECPRIEST( PRIESTGR);           if _exitcastspel then exit;
        HPHEALED := 0;
        TC_HEAL  := CHARACTR[ HEALME];
        if HPTRIES = -1 then
          begin
            { MADI }
            HPHEALED := TC_HEAL.HPMAX;
            TC_HEAL.LOSTXYL[ 1] := 0;
            if Byte( TC_HEAL.STATUS) < Byte( DEAD) then
              SETSTATUS_CU( TC_HEAL, OK)
          end
        else
          while HPTRIES > 0 do
            begin
              HPHEALED := HPHEALED + Random( MAXHPTRY) + 1;
              HPTRIES  := HPTRIES - 1
            end;
        TC_HEAL.HPLEFT := TC_HEAL.HPLEFT + HPHEALED;
        if TC_HEAL.HPLEFT > TC_HEAL.HPMAX then
          TC_HEAL.HPLEFT := TC_HEAL.HPMAX;
        GotoXY( 1, 24);
        Write( 'CURED ');
        Write( HPHEALED);
        Write( ' HP - NOW ');
        Write( TC_HEAL.HPLEFT);
        Write( '/');
        Write( TC_HEAL.HPMAX);
        GotoXY( 41, 0);
        PAUSE2;
        DSPSPELS;
        _exitcastspel := true    { AP: EXIT(CASTSPEL) }
      end;


      procedure DOKANDI;
      begin
        CHKSPCNT( 5, 42); if _exitcastspel then exit;
        DECPRIEST( 5);    if _exitcastspel then exit;
        DISPSTAT  := true;
        LLBASE04  := CAMPCHAR;
        XGOTO2    := XCASTLE;
        XGOTO     := XCAMPSTF;
        _done     := true         { AP: EXIT(CAMP) }
      end;


      procedure DODIKADO(DIKADOXX: SmallInt);

        procedure DIKADORT;
        begin
          TC_HEAL := CHARACTR[ HEALME];
          if Random( 100) <= 4 * TC_HEAL.ATTRIB[ VITALITY] then
            begin
              SETSTATUS_CU( TC_HEAL, OK);
              if DIKADOXX = 5 then TC_HEAL.HPLEFT := 1
              else TC_HEAL.HPLEFT := TC_HEAL.HPMAX;
              if TC_HEAL.ATTRIB[ VITALITY] = 3 then
                SETSTATUS_CU( TC_HEAL, LOST)
              else
                TC_HEAL.ATTRIB[ VITALITY] := TC_HEAL.ATTRIB[ VITALITY] - 1
            end;
          if Byte( TC_HEAL.STATUS) = 0 then  { OK = 0 }
            EXITCASTSPEL( 'EXCELSIOR')
          else
            begin
              SETSTATUS_CU( TC_HEAL, TSTATUS( Byte( TC_HEAL.STATUS) + 1));  { AP: SUCC(STATUS) }
              EXITCASTSPEL( 'OOPPS!')
            end
        end;  { DIKADORT }

      begin  { DODIKADO }
        if DIKADOXX = 5 then
          begin CHKSPCNT( DIKADOXX, 43); if _exitcastspel then exit end
        else
          begin CHKSPCNT( DIKADOXX, 50); if _exitcastspel then exit end;
        HEALWHO;    if _exitcastspel then exit;
        DECPRIEST( DIKADOXX); if _exitcastspel then exit;
        TC_HEAL := CHARACTR[ HEALME];
        if DIKADOXX = 5 then
          begin
            if Byte( TC_HEAL.STATUS) = 5 then  { DEAD = 5 }
              begin DIKADORT; if _exitcastspel then exit end
            else if Byte( TC_HEAL.STATUS) = 6 then  { ASHES = 6 }
              begin EXITCASTSPEL( '"KADORTO" NEEDED'); exit end
          end
        else
          if (Byte( TC_HEAL.STATUS) = 5) or (Byte( TC_HEAL.STATUS) = 6) then
            begin DIKADORT; if _exitcastspel then exit end
          else if Byte( TC_HEAL.STATUS) = 7 then  { LOST = 7 }
            begin EXITCASTSPEL( 'LOST'); exit end;
        if _exitcastspel then exit;
        EXITCASTSPEL( 'NOT DEAD')
      end;  { DODIKADO }


      procedure DODUMAPI;
      begin
        if not USEITEM_B then
          begin
            TC  := CHARACTR[ CAMPCHAR];
            SKN := TC.SPELLSKN;
            if (TC.MAGESP[ 1] = 0) or (not SKN^[ 4]) then
              begin EXITCASTSPEL( 'YOU CANT CAST IT'); exit end
          end;
        if _exitcastspel then exit;
        if FIZZLES > 0 then begin EXITCASTSPEL( 'SPELL FAILS'); exit end;
        if not USEITEM_B then
          begin
            TC := CHARACTR[ CAMPCHAR];
            TC.MAGESP[ 1] := TC.MAGESP[ 1] - 1
          end;
        LLBASE04 := CAMPCHAR;
        XGOTO2   := XGILGAMS;
        XGOTO    := XCAMPSTF;
        _done    := true          { AP: EXIT(CAMP) }
      end;


      procedure DOMALOR;
      begin
        if not USEITEM_B then
          begin
            TC  := CHARACTR[ CAMPCHAR];
            SKN := TC.SPELLSKN;
            if (TC.MAGESP[ 7] = 0) or (not SKN^[ 19]) then
              begin EXITCASTSPEL( 'YOU CANT CAST IT'); exit end
          end;
        if _exitcastspel then exit;
        if FIZZLES > 0 then begin EXITCASTSPEL( 'SPELL FAILS'); exit end;
        if not USEITEM_B then
          begin
            TC := CHARACTR[ CAMPCHAR];
            TC.MAGESP[ 7] := TC.MAGESP[ 7] - 1
          end;
        LLBASE04 := CAMPCHAR;
        XGOTO2   := XINSPECT;
        XGOTO    := XCAMPSTF;
        _done    := true          { AP: EXIT(CAMP) }
      end;


    begin  { CASTSPEL }
      _exitcastspel := false;
      DISPSTAT  := false;
      USEITEM_B := BSET_CU( SPELHASH > 0);
      TC  := CHARACTR[ CAMPCHAR];
      SKN := TC.SPELLSKN;
      if SPELHASH = -1 then
        begin
          GotoXY( 1, 19);
          WriteLn;  { AP: WRITE(CHR(11)) }
          Write( 'WHAT SPELL ? >' : 24);
          GETLINE;
          SPELNAME := GTSTRING;
          SPELHASH := Length( SPELNAME);
          for SPELLI := 1 to Length( SPELNAME) do
            begin
              HASHCALC := Ord( SPELNAME[ SPELLI]) - 64;
              SPELHASH := SPELHASH + HASHCALC * HASHCALC * SPELLI
            end
        end;
      GotoXY( 41, 0);
      Write( SPELHASH : 6);
      Write( ' ');
      if SPELHASH = DIOS then
        begin DOHEAL( 1, 8, 1, 23); if _exitcastspel or _done then exit end
      else if SPELHASH = MILWA then
        begin
          CHKSPCNT( 1, 25); if _exitcastspel then exit;
          DECPRIEST( 1);    if _exitcastspel then exit;
          LIGHT := 15 + Random( 15)
        end
      else if SPELHASH = DUMAPI then
        begin DODUMAPI; if _exitcastspel or _done then exit end
      else if SPELHASH = KANDI then
        begin DOKANDI; if _done then exit end
      else if SPELHASH = LOMILWA then
        begin
          CHKSPCNT( 3, 31); if _exitcastspel then exit;
          DECPRIEST( 3);    if _exitcastspel then exit;
          LIGHT := 32000
        end
      else if SPELHASH = LATUMOFI then
        begin
          CHKSPCNT( 4, 37); if _exitcastspel then exit;
          HEALWHO;          if _exitcastspel then exit;
          DECPRIEST( 4);    if _exitcastspel then exit;
          TC_HEAL := CHARACTR[ HEALME];
          TC_HEAL.LOSTXYL[ 1] := 0
        end
      else if SPELHASH = DIALKO then
        begin
          CHKSPCNT( 3, 32); if _exitcastspel then exit;
          HEALWHO;          if _exitcastspel then exit;
          DECPRIEST( 3);    if _exitcastspel then exit;
          TC_HEAL := CHARACTR[ HEALME];
          if (Byte( TC_HEAL.STATUS) = 3) or (Byte( TC_HEAL.STATUS) = 2) then  { PLYZE=3, ASLEEP=2 }
            SETSTATUS_CU( TC_HEAL, OK)
        end
      else if SPELHASH = DIAL then
        begin DOHEAL( 2, 8, 4, 35); if _exitcastspel or _done then exit end
      else if SPELHASH = MAPORFIC then
        begin
          CHKSPCNT( 4, 38); if _exitcastspel then exit;
          DECPRIEST( 4);    if _exitcastspel then exit;
          ACMOD2 := 2
        end
      else if SPELHASH = DIALMA then
        begin DOHEAL( 3, 8, 5, 39); if _exitcastspel or _done then exit end
      else if SPELHASH = DI then
        begin DODIKADO( 5); if _exitcastspel or _done then exit end
      else if SPELHASH = MADI then
        begin DOHEAL( -1, -1, 6, 46); if _exitcastspel or _done then exit end
      else if SPELHASH = KADORTO then
        begin DODIKADO( 7); if _exitcastspel or _done then exit end
      else if SPELHASH = MALOR then
        begin DOMALOR; if _exitcastspel or _done then exit end
      else
        EXITCASTSPEL( 'WHAT?');
      if _exitcastspel then exit;
      EXITCASTSPEL( 'DONE!')
    end;  { CASTSPEL }


    { ── USEITEM ── }
    procedure USEITEM;
    var
      THEITEM : TOBJREC;
      ITEMX   : SmallInt;
      PP      : ^TPOSSESS;
      SPTR    : ^TSPELBLK;
    begin
      DISPSTAT := false;
      repeat
        GotoXY( 1, 19);
        WriteLn;  { AP: WRITE(CHR(11)) }
        Write( 'USE ITEM (0=EXIT) ? >');
        GETKEY;
        WriteLn;
        ITEMX := Ord( INCHAR) - Ord( '0');
        if ITEMX = 0 then exit;
        TC := CHARACTR[ CAMPCHAR]
      until (ITEMX > 0) and (ITEMX <= TC.POSS.POSSCNT);
      TC := CHARACTR[ CAMPCHAR];
      PP := TC.POSS.POSSESS[ ITEMX];
      LOADOBJREC( PP.EQINDEX, THEITEM);
      if THEITEM.SPELLPWR = 0 then
        begin AASTRAA( 'POWERLESS'); exit end;
      if Byte( THEITEM.OBJTYPE) <> Byte( SPECIAL) then
        if not PP.EQUIPED then
          begin AASTRAA( 'NOT EQUIPPED'); exit end;
      if Random( 100) < THEITEM.CHGCHANC then
        PP.EQINDEX := THEITEM.CHANGETO;
      SPTR := SCNTOC.SPELLS;
      CASTSPEL( SPTR.SPELLHSH[ THEITEM.SPELLPWR]);
      if _done then exit
    end;


    { ── DROPITEM ── }
    procedure DROPITEM;
    var
      POSSX : SmallInt;
      POSSI : SmallInt;
      PP    : ^TPOSSESS;
      PP2   : ^TPOSSESS;
    begin
      DISPSTAT := false;
      repeat
        GotoXY( 1, 19);
        WriteLn;  { AP: WRITE(CHR(11)) }
        Write( 'DROP ITEM (0=EXIT) ? >');
        GETKEY;
        POSSI := Ord( INCHAR) - Ord( '0');
        if POSSI = 0 then exit;
        TC := CHARACTR[ CAMPCHAR]
      until (POSSI > 0) and (POSSI <= TC.POSS.POSSCNT);
      TC := CHARACTR[ CAMPCHAR];
      PP := TC.POSS.POSSESS[ POSSI];
      if PP.CURSED  then begin AASTRAA( 'CURSED');   exit end;
      if PP.EQUIPED then begin AASTRAA( 'EQUIPPED'); exit end;
      for POSSX := POSSI + 1 to TC.POSS.POSSCNT do
        begin
          PP  := TC.POSS.POSSESS[ POSSX - 1];
          PP2 := TC.POSS.POSSESS[ POSSX];
          PP^ := PP2^
        end;
      TC.POSS.POSSCNT := TC.POSS.POSSCNT - 1;
      DSPITEMS;
      AASTRAA( 'DROPPED')
    end;


    { ── IDENTIFY_PROC ── }
    procedure IDENTIFY_PROC;
    begin
      DISPSTAT := false;
      TC := CHARACTR[ CAMPCHAR];
      if Byte( TC.XCLASS) <> Byte( BISHOP) then
        begin AASTRAA( 'NOT BISHOP'); exit end;
      LLBASE04 := CAMPCHAR;
      XGOTO2   := XTRAININ;
      XGOTO    := XCAMPSTF;
      _done    := true          { AP: EXIT(CAMP) }
    end;


    { ── DOTRADE ── }
    procedure DOTRADE;
    var
      GOLD2TRA    : TWIZLONG;
      TRADETO     : SmallInt;
      GOLDSTR     : string[ 40];
      GOLDX       : SmallInt;
      TEMP0001    : SmallInt;
      ITEMX       : SmallInt;
      TC_TO       : PTCHAR;
      PP          : ^TPOSSESS;
      PP2         : ^TPOSSESS;
      _exittrade  : Boolean;


      procedure TRADGOLD;
      var
        TEMPGOLD : TWIZLONG;
        MULT10   : SmallInt;
      begin
        GotoXY( 1, 19);
        WriteLn;  { AP: WRITE(CHR(11)) }
        Write( 'AMT OF GOLD ? >');
        GETLINE;
        GOLDSTR := GTSTRING;
        FillChar( TEMPGOLD, SizeOf( TWIZLONG), 0);
        FillChar( GOLD2TRA, SizeOf( TWIZLONG), 0);
        TEMP0001 := 0;
        MULT10   := 10;
        for GOLDX := 1 to Length( GOLDSTR) do
          if (Ord( GOLDSTR[ GOLDX]) < Ord( '0')) or
             (Ord( GOLDSTR[ GOLDX]) > Ord( '9')) or
             (GOLDX > 12) or
             (TEMP0001 = -1) then
            TEMP0001 := -1
          else
            begin
              MULTLONG( GOLD2TRA, MULT10);
              TEMPGOLD.XLOW := Ord( GOLDSTR[ GOLDX]) - Ord( '0');
              ADDLONGS( GOLD2TRA, TEMPGOLD)
            end;
        if TEMP0001 = -1 then
          begin AASTRAA( 'BAD AMT'); _exittrade := true; exit end;
        TC := CHARACTR[ CAMPCHAR];
        if TESTLONG( TC.GOLD, GOLD2TRA) < 0 then
          begin AASTRAA( 'NOT ENOUGH $'); _exittrade := true; exit end;
        TC_TO := CHARACTR[ TRADETO];
        ADDLONGS( TC_TO.GOLD, GOLD2TRA);
        TC := CHARACTR[ CAMPCHAR];
        SUBLONGS( TC.GOLD, GOLD2TRA)
      end;  { TRADGOLD }


      procedure TRADITEM;
      begin
        repeat
          repeat
            GotoXY( 1, 19);
            WriteLn;  { AP: WRITE(CHR(11)) }
            Write( 'WHAT ITEM ([RET] EXITS) ? >');
            GETKEY;
            ITEMX := Ord( INCHAR) - Ord( '0');
            if INCHAR = Chr( CRETURN) then
              begin _exittrade := true; exit end   { AP: EXIT(DOTRADE) }
          until (ITEMX > 0) and (ITEMX <= CHARACTR[ CAMPCHAR].POSS.POSSCNT);
          if _exittrade then exit;
          TC_TO := CHARACTR[ TRADETO];
          TC    := CHARACTR[ CAMPCHAR];
          if TC_TO.POSS.POSSCNT = 8 then
            begin AASTRAA( 'FULL'); _exittrade := true; exit end;
          PP := TC.POSS.POSSESS[ ITEMX];
          if PP.CURSED  then begin AASTRAA( 'CURSED');   _exittrade := true; exit end;
          if PP.EQUIPED then begin AASTRAA( 'EQUIPPED');  _exittrade := true; exit end;
          TEMP0001 := TC_TO.POSS.POSSCNT + 1;
          PP2  := TC_TO.POSS.POSSESS[ TEMP0001];
          PP2^ := PP^;
          TC_TO.POSS.POSSCNT := TEMP0001;
          for TEMP0001 := ITEMX + 1 to TC.POSS.POSSCNT do
            begin
              PP  := TC.POSS.POSSESS[ TEMP0001 - 1];
              PP2 := TC.POSS.POSSESS[ TEMP0001];
              PP^ := PP2^
            end;
          TC.POSS.POSSCNT := TC.POSS.POSSCNT - 1;
          DSPITEMS
        until false
      end;  { TRADITEM }


    begin  { DOTRADE }
      _exittrade := false;
      DISPSTAT   := false;
      repeat
        TRADETO := GETCHARX( true, 'TRADE WITH');
        if TRADETO = -1 then exit
      until TRADETO <> CAMPCHAR;
      TRADGOLD;
      if _exittrade then exit;
      TRADITEM
    end;  { DOTRADE }


    { ── CAMPDO ── }
    procedure CAMPDO;

    var
      MENUTYPE : SmallInt;
      TC2      : PTCHAR;


      procedure CAMPMENU;

        procedure DSPSTATS;

          procedure CHEVRONS;
          var
            INDX : SmallInt;
            BITS : SmallInt;
          begin
            TC   := CHARACTR[ CAMPCHAR];
            BITS := TC.LOSTXYL[ 4];
            Write( '"');
            for INDX := 0 to 15 do
              if BSET_CU( BITS and (1 shl INDX)) then
                Write( CHEVTBL[ INDX]);
            Write( '" ')
          end;  { CHEVRONS }

        begin  { DSPSTATS }
          TC := CHARACTR[ CAMPCHAR];
          ClrScr;
          Write( TC.NAME);
          Write( ' ');
          if TC.LOSTXYL[ 4] > 0 then CHEVRONS;
          Write( SCNTOC_RACE[ Byte( TC.RACE)]);
          Write( ' ');
          Write( Copy( SCNTOC_ALIGN[ Byte( TC.ALIGN)], 1, 1));
          Write( '-');
          Write( SCNTOC_CLASS[ Byte( TC.XCLASS)]);
          WriteLn;
          WriteLn;
          Write( 'STRENGTH' : 12);
          Write( TC.ATTRIB[ STRENGTH] : 3);
          Write( 'GOLD ' : 9);
          PRNTLONG( TC.GOLD);
          WriteLn;
          Write( 'I.Q.' : 12);
          Write( TC.ATTRIB[ IQ] : 3);
          Write( 'EXP ' : 9);
          PRNTLONG( TC.EXP);
          WriteLn;
          Write( 'PIETY' : 12);
          Write( TC.ATTRIB[ PIETY] : 3);
          WriteLn;
          Write( 'VITALITY' : 12);
          Write( TC.ATTRIB[ VITALITY] : 3);
          Write( 'LEVEL ' : 9);
          Write( TC.CHARLEV : 3);
          Write( 'AGE ' : 9);
          Write( (TC.AGE div 52) : 3);
          WriteLn;
          Write( 'AGILITY' : 12);
          Write( TC.ATTRIB[ AGILITY] : 3);
          Write( 'HITS ' : 9);
          Write( TC.HPLEFT : 3);
          Write( '/');
          Write( TC.HPMAX : 3);
          Write( 'AC' : 4);
          Write( (TC.ARMORCL - ACMOD2) : 4);
          WriteLn;
          Write( 'LUCK' : 12);
          Write( TC.ATTRIB[ LUCK] : 3);
          Write( 'STATUS ' : 9);
          Write( SCNTOC_STATUS[ Byte( TC.STATUS)]);
          if TC.LOSTXYL[ 1] > 0 then Write( ' & POISONED');
          WriteLn;
          DSPSPELS;
          DSPITEMS
        end;  { DSPSTATS }


      begin  { CAMPMENU }
        TC2 := CHARACTR[ CAMPCHAR];
        if DISPSTAT then DSPSTATS;
        GotoXY( 1, 19);
        if XGOTO = XINSPCT3 then
          MENUTYPE := 0
        else if XGOTO = XINSPECT then
          MENUTYPE := 1
        else if Byte( TC2.STATUS) = 0 then  { OK = 0 }
          MENUTYPE := 2
        else
          MENUTYPE := 1;
        if MENUTYPE = 2 then
          begin
            WriteLn;
            WriteLn( 'YOU MAY E)QUIP, D)ROP AN ITEM, T)RADE,');
            Write( ' ' : 8);
            WriteLn( 'R)EAD SPELL BOOKS, CAST S)PELLS,');
            Write( ' ' : 8);
            WriteLn( 'U)SE AN ITEM, I)DENTIFY AN ITEM,');
            Write( ' ' : 8);
            WriteLn( 'OR L)EAVE.')
          end
        else if MENUTYPE = 1 then
          begin
            WriteLn;
            WriteLn( 'YOU MAY E)QUIP, D)ROP AN ITEM, T)RADE,');
            Write( ' ' : 8);
            WriteLn( 'R)EAD SPELL BOOKS, OR L)EAVE.')
          end
        else
          begin
            WriteLn;
            WriteLn( 'YOU MAY R)EAD SPELL BOOKS OR L)EAVE.')
          end
      end;  { CAMPMENU }


    begin  { CAMPDO }
      CAMPMENU;
      DISPSTAT := true;
      repeat
        GotoXY( 41, 0);
        GETKEY
      until (INCHAR = 'R') or (INCHAR = 'L') or
            ((MENUTYPE > 0) and
             ((INCHAR = 'T') or (INCHAR = 'D') or (INCHAR = 'E'))) or
            ((MENUTYPE > 1) and
             ((INCHAR = 'I') or (INCHAR = 'S') or (INCHAR = 'U')));
      case INCHAR of
        'L':  exit;   { AP: EXIT(CAMPDO) — returns to INSPECT's repeat loop }
        'E':  if MENUTYPE > 0 then
                begin
                  XGOTO    := XEQPDSP;
                  LLBASE04 := CAMPCHAR;
                  _done    := true;
                  exit
                end;
        'R':  begin
                XGOTO    := XCAMPSTF;
                XGOTO2   := XDONE;
                LLBASE04 := CAMPCHAR;
                _done    := true;
                exit
              end;
        'D':  if MENUTYPE > 0 then begin DROPITEM;      if _done then exit end;
        'I':  if MENUTYPE = 2 then begin IDENTIFY_PROC; if _done then exit end;
        'S':  if MENUTYPE = 2 then begin CASTSPEL( -1); if _done then exit end;
        'U':  if MENUTYPE = 2 then begin USEITEM;       if _done then exit end;
        'T':  DOTRADE
      end
    end;  { CAMPDO }


  begin  { INSPECT }
    CAMPCHAR := LLBASE04;
    XGOTO2   := XGOTO;
    ClrScr;
    repeat
      CAMPDO;
      if _done then exit
    until INCHAR = 'L';
    ClrScr
  end;  { INSPECT }


  { ── CAMPMEN2 ── }
  procedure CAMPMEN2;
  var
    CHARX : SmallInt;
    TC2   : PTCHAR;

    procedure DSP1LINE(CHARX: SmallInt);
    begin
      GotoXY( 1, 4 + CHARX);
      Write( ' ');   { AP: WRITE(CHR(29)) — clear to EOL; approximate }
      Write( (CHARX + 1) : 2);
      Write( ' ');
      TC2 := CHARACTR[ CHARX];
      Write( TC2.NAME);
      GotoXY( 20, 4 + CHARX);
      Write( Copy( SCNTOC_ALIGN[ Byte( TC2.ALIGN)], 1, 1));
      Write( '-');
      Write( Copy( SCNTOC_CLASS[ Byte( TC2.XCLASS)], 1, 3));
      Write( ' ');
      if TC2.ARMORCL - ACMOD2 > -10 then
        Write( (TC2.ARMORCL - ACMOD2) : 2)
      else
        Write( 'LO');
      Write( TC2.HPLEFT : 5);
      LLBASE04 := TC2.HEALPTS - TC2.LOSTXYL[ 1];
      if LLBASE04 > 0 then Write( '+')
      else if LLBASE04 < 0 then Write( '-')
      else Write( ' ');
      if Byte( TC2.STATUS) = 0 then  { OK = 0 }
        if TC2.LOSTXYL[ 1] <> 0 then
          WriteLn( 'POISON')
        else
          WriteLn( TC2.HPMAX : 4)
      else
        WriteLn( SCNTOC_STATUS[ Byte( TC2.STATUS)])
    end;  { DSP1LINE }

  begin  { CAMPMEN2 }
    ClrScr;
    WriteLn( 'CAMP' : 22);
    WriteLn;
    WriteLn( ' # CHARACTER NAME  CLASS AC HITS STATUS');
    for CHARX := 0 to PARTYCNT - 1 do
      DSP1LINE( CHARX);
    GotoXY( 1, 13);
    WriteLn( 'YOU MAY R)EORDER, E)QUIP, D)ISBAND,');
    Write( ' ' : 8);
    WriteLn( '#) TO INSPECT, OR');
    Write( ' ' : 8);
    WriteLn( 'L)EAVE THE CAMP.')
  end;  { CAMPMEN2 }


  { ── DISBAND ── }
  procedure DISBAND;
  var
    _exitdisband : Boolean;
    TC2          : PTCHAR;

    procedure CONFIRM(NULLRE: string);
    begin
      ClrScr;
      Write( NULLRE);
      Write( 'CONFIRM (Y/N) ?');
      repeat
        GotoXY( 41, 0);
        GETKEY
      until (INCHAR = 'Y') or (INCHAR = 'N');
      if INCHAR = 'N' then _exitdisband := true
    end;

  begin  { DISBAND }
    _exitdisband := false;
    CONFIRM( '');   if _exitdisband then exit;
    CONFIRM( 'RE-'); if _exitdisband then exit;
    for LLBASE04 := 0 to PARTYCNT - 1 do
      begin
        TC2 := CHARACTR[ LLBASE04];
        TC2.INMAZE     := false;
        TC2.LOSTXYL[1] := MAZEX;
        TC2.LOSTXYL[2] := MAZEY;
        TC2.LOSTXYL[3] := MAZELEV;
        TC2.AGE        := TC2.AGE + 25;
        SAVETCHAR( CHARDISK[ LLBASE04], TC2^)
      end;
    GTSCNTOC;
    LLBASE04 := -2;
    XGOTO    := XSCNMSG;
    _done    := true          { AP: EXIT(CAMP) }
  end;  { DISBAND }


begin  { CAMP }
  _done    := false;
  DISPSTAT := true;
  for OBJI := 1 to 8 do
    OBJIDS[ OBJI - 1] := -1;
  TEXTMODE;
  if (XGOTO = XBCK2CMP) or (XGOTO = XBK2CMP2) then
    begin
      XGOTO := XGOTO2;
      if XGOTO = XINSPCT2 then begin INSPECT; if _done then exit end
    end;
  if XGOTO = XINSPECT then
    begin
      INSPECT;
      if _done then exit;
      XGOTO := XGILGAMS;
      exit
    end;
  if XGOTO = XINSPCT3 then
    begin
      LLBASE04 := 0;
      INSPECT;
      if _done then exit;
      XGOTO := XBCK2ROL;
      exit
    end;
  repeat
    CLEARPIC;
    CAMPMEN2;
    GotoXY( 41, 0);
    GETKEY;
    if (INCHAR > '0') and (INCHAR <= Chr( Ord( '0') + PARTYCNT)) then
      begin
        LLBASE04 := Ord( INCHAR) - Ord( '1');
        for OBJI := 1 to 8 do
          OBJIDS[ OBJI - 1] := -1;
        INSPECT;
        if _done then exit
      end
    else
      begin
        case INCHAR of
          'R':  begin
                  XGOTO := XREORDER;
                  exit
                end;
          'L':  begin
                  XGOTO := XCMP2EQ6;
                  exit
                end;
          'E':  begin
                  XGOTO    := XEQPDSP;
                  LLBASE04 := -1;
                  exit
                end;
          'D':  begin DISBAND; if _done then exit end
        end
      end
  until false
end;  { CAMP }


end.
