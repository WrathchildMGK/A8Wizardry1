unit CAMPUNIT;

{ Source: apple/Wizardry_v3-2/Wiz1C.DSK/CAMP + CAMP2 (v3.2: WC017 WC026
  WC029 WC038 WC040).

  Translation notes:
    - SEGMENT PROCEDURE CAMP -> unit procedure CAMP
    - EXIT(CAMP / CASTSPEL / DOTRADE / DISBAND) past the current routine ->
      unwind codes U_* (CONSTS); EXIT of the current routine -> exit
    - WITH CHARACTR[CAMPCHAR] DO -> TC := CHARACTR[CAMPCHAR]; TC.FIELD
    - WRITE(CHR(12)) -> ClrScr; GOTOXY, CHR(11), CHR(29) as AP (SCREEN)
    - WRITE( X :N)   -> WRITEINT / padded literals (MP ignores field widths)
    - GETLINE(S)     -> GETLINE; S := GTSTRING;  READ( INCHAR) -> GETKEY
    - BASE12.GOTOX   -> XGOTO2
    - MOVELEFT TOBJREC / TCHAR / TSCNTOC -> LOADOBJREC / SAVETCHAR / GTSCNTOC
    - SCNTOC.RACE/CLASS/ALIGN/STATUS[X] -> RACENAME/CLASSNAME/ALIGNNAME/STATNAME
    - SCNTOC.SPELLHSH[X] -> SPTR.SPELLHSH[X] via SPTR := SCNTOC.SPELLS
    - LOSTXYL.POISNAMT[1] / LOCATION[1..3] / AWARDS[4] -> LOSTXYL[1] / [1..3] / [4]
    - ARRAY[FALSE..TRUE] -> array[0..1], indexed with Byte(BOOL_EXPR)
    - USEITEM (Boolean in CASTSPEL) -> USEITEM_B (clashes with procedure USEITEM)
    - SUCC(STATUS) -> TSTATUS(Byte(STATUS) + 1)
    - record copies (TWIZLONG, TPOSSESS) -> field copies / pointer copies
}

interface

uses TYPES, CONSTS, GLOBALS, UTIL, SCREEN;

procedure CAMP;

implementation

const
  U_CAMP     = $01;       { unwind targets: AP P010C01, P010C06, P010C17, }
  U_CASTSPEL = $06;       {   P010C21                                     }
  U_DOTRADE  = $17;
  U_DISBAND  = $21;

  { Chevron characters, one per LOSTXYL[4] bit ('$' as #36: MP reads $ as hex). }
  CHEVTBL: array[0..15] of char = (
    '>','!',#36,'#','&','*','<','?','B','C','P','K','O','D','G','@');


procedure SETSTATUS_CU(TC: PTCHAR; V: TSTATUS);
begin
  TC^.STATUS := TSTATUS(Byte(V))
end;

function BSET_CU(B: Byte): Boolean;
begin
  if B <> 0 then BSET_CU := true else BSET_CU := false
end;


procedure CAMP;

var
  OBJIDS   : array[ 0..7] of SmallInt;
  OBJNAMES : array[ 0..7] of array[ 0..1] of string[ 15];  { AP: ARRAY[FALSE..TRUE] OF STRING[15] }
  CURSEDXX : array[ 0..7] of Boolean;
  CANUSE   : array[ 0..7] of Boolean;
  DISPSTAT : Boolean;
  OBJI     : SmallInt;


  procedure GTSCNTOC;
  var DUMMY : SmallInt;
  begin
    DUMMY := GETREC( ZZERO, 0, SizeOf( TSCNTOC));
    LOADSCNTOC
  end;


  procedure AASTRAA(ASTRA: string);
  begin
    CENTSTR( Concat( '** ', Concat( ASTRA, ' **')))
  end;


  { ── INSPECT ── }
  function INSPECT: Byte;
  var
    CAMPCHAR : SmallInt;
    TC       : PTCHAR;
    SKN      : PTSPELLSKN;


    procedure DSPSPELS;
    var INDX : SmallInt;
    begin
      TC := CHARACTR[ CAMPCHAR];
      GotoXY( 24, 2);                                   { v3.2 WC038 }
      PRNTLONG( TC.GOLD);
      GotoXY( 24, 6);
      WRITEINT( TC.HPLEFT, 3);
      GotoXY( 24, 7);
      Write( STATNAME( Byte( TC^.STATUS)));
      if TC.LOSTXYL[ 1] > 0 then
        Write( ' & POISONED')
      else
        Write( '           ');
      GotoXY( 0, 9);
      Write( '       ');
      Write( ' MAGE ');
      for INDX := 1 to 7 do
        begin
          Write( TC.MAGESP[ INDX]);
          if INDX < 7 then Write( '/')
        end;
      WriteLn;
      Write( '      ');
      Write( 'PRIEST ');
      for INDX := 1 to 7 do
        begin
          Write( TC.PRIESTSP[ INDX]);
          if INDX < 7 then Write( '/')
        end
    end;


    procedure DSPITEMS;
    var
      ITEMX  : SmallInt;
      OBJREC : TOBJREC;
      PP     : ^TPOSSESS;
    begin
      TC := CHARACTR[ CAMPCHAR];
      GotoXY( 0, 12);
      Write( '*=EQUIP, -=CURSED, ?=UNKNOWN, #=UNUSABLE');
      for ITEMX := 14 to 17 do
        begin
          GotoXY( 0, ITEMX);
          Write( Chr( 29))
        end;
      if TC.POSS.POSSCNT = 0 then exit;
      for ITEMX := 1 to TC^.POSS.POSSCNT do
        begin
          GotoXY( 20 - 20 * (ITEMX mod 2),
                  14 + ((ITEMX - 1) div 2));
          PP := TC.POSS.POSSESS[ ITEMX];
          if OBJIDS[ ITEMX - 1] <> PP.EQINDEX then
            begin
              LOADOBJREC( PP.EQINDEX, OBJREC);
              OBJIDS[ ITEMX - 1]    := PP.EQINDEX;
              OBJNAMES[ ITEMX-1][1] := OBJREC.NAME;
              OBJNAMES[ ITEMX-1][0] := OBJREC.NAMEUNK;
              CANUSE[   ITEMX - 1]  := OBJREC.CLASSUSE[ Byte( TC^.XCLASS)];
              CURSEDXX[ ITEMX - 1]  := OBJREC.CURSED
            end;
          Write( ITEMX);
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


    { ── CASTSPEL: UNWNONE, or U_CAMP (KANDI, DUMAPIC, MALOR) ── }
    function CASTSPEL(SPELHASH: SmallInt): Byte;
    var
      USEITEM_B : Boolean;
      SPELNAME  : string[ 40];
      HASHCALC  : SmallInt;
      SPELLI    : SmallInt;
      HEALME    : SmallInt;
      TC_HEAL   : PTCHAR;
      U         : Byte;


      function EXITCAST(EXITSTR: string): Byte;
      begin
        AASTRAA( EXITSTR);
        DSPSPELS;
        EXITCAST := U_CASTSPEL                          { EXIT( CASTSPEL) }
      end;


      function HEALWHO: Byte;
      begin
        HEALWHO := UNWNONE;
        HEALME := GETCHARX( true, 'CAST ON WHO');
        if HEALME = -1 then
          HEALWHO := EXITCAST( 'NOT IN THE PARTY')
      end;


      function CHKSPCNT(PRIESTGR: SmallInt; SPELLIDX: SmallInt): Byte;
      begin
        CHKSPCNT := UNWNONE;
        if USEITEM_B then exit;
        TC  := CHARACTR[ CAMPCHAR];
        SKN := TC^.SPELLSKN;
        if (TC.PRIESTSP[ PRIESTGR] <= 0) or (not SKN^[ SPELLIDX]) then
          CHKSPCNT := EXITCAST( 'YOU CANNOT CAST IT')   { v3.2 WC029 }
      end;


      function DECPRIEST(PRIESTGR: SmallInt): Byte;
      begin
        DECPRIEST := UNWNONE;
        if not USEITEM_B then
          begin
            TC := CHARACTR[ CAMPCHAR];
            TC.PRIESTSP[ PRIESTGR] := TC.PRIESTSP[ PRIESTGR] - 1
          end;
        if FIZZLES > 0 then
          DECPRIEST := EXITCAST( 'SPELL HAS NO EFFECT')
      end;


      function DOHEAL(HPTRIES:  SmallInt;
                      MAXHPTRY: SmallInt;
                      PRIESTGR: SmallInt;
                      SPELLIDX: SmallInt): Byte;
      var HPHEALED : SmallInt;
      begin
        Result := CHKSPCNT( PRIESTGR, SPELLIDX);  if Result <> UNWNONE then exit;
        Result := HEALWHO;                        if Result <> UNWNONE then exit;
        Result := DECPRIEST( PRIESTGR);           if Result <> UNWNONE then exit;
        HPHEALED := 0;
        TC_HEAL  := CHARACTR[ HEALME];
        if HPTRIES = -1 then
          begin
            { MADI }
            HPHEALED := TC_HEAL.HPMAX;
            TC_HEAL.LOSTXYL[ 1] := 0;
            if Byte( TC_HEAL^.STATUS) < Byte( DEAD) then
              SETSTATUS_CU( TC_HEAL, OK)
          end
        else
          while HPTRIES > 0 do
            begin
              HPHEALED := HPHEALED + RNDN( MAXHPTRY) + 1;
              HPTRIES  := HPTRIES - 1
            end;
        TC_HEAL.HPLEFT := TC_HEAL.HPLEFT + HPHEALED;
        if TC_HEAL.HPLEFT > TC_HEAL.HPMAX then
          TC_HEAL.HPLEFT := TC_HEAL.HPMAX;
        GotoXY( 0, 23);
        Write( 'CURED ');
        Write( HPHEALED);
        Write( ' HP - NOW ');
        Write( TC_HEAL.HPLEFT);
        Write( '/');
        Write( TC_HEAL.HPMAX);
        GotoXY( 41, 0);
        PAUSE2;
        DSPSPELS;
        Result := U_CASTSPEL                            { EXIT( CASTSPEL) }
      end;


      function DOKANDI: Byte;
      begin
        Result := CHKSPCNT( 5, 42);  if Result <> UNWNONE then exit;
        Result := DECPRIEST( 5);     if Result <> UNWNONE then exit;
        DISPSTAT := true;
        LLBASE04 := CAMPCHAR;
        XGOTO2   := XCASTLE;
        XGOTO    := XCAMPSTF;
        Result   := U_CAMP                              { EXIT( CAMP) }
      end;


      function DODIKADO(DIKADOXX: SmallInt): Byte;

        function DIKADORT: Byte;
        begin
          TC_HEAL := CHARACTR[ HEALME];
          if RNDN( 100) <= 4 * TC_HEAL.ATTRIB[ VITALITY] then
            begin
              SETSTATUS_CU( TC_HEAL, OK);
              if DIKADOXX = 5 then TC_HEAL.HPLEFT := 1
              else TC_HEAL.HPLEFT := TC_HEAL.HPMAX;
              if TC_HEAL.ATTRIB[ VITALITY] = 3 then
                SETSTATUS_CU( TC_HEAL, LOST)
              else
                TC_HEAL.ATTRIB[ VITALITY] := TC_HEAL.ATTRIB[ VITALITY] - 1
            end;
          if Byte( TC_HEAL^.STATUS) = 0 then             { OK = 0 }
            DIKADORT := EXITCAST( 'EXCELSIOR')
          else
            begin
              SETSTATUS_CU( TC_HEAL, TSTATUS( Byte( TC_HEAL^.STATUS) + 1));
              DIKADORT := EXITCAST( 'OOPPS!')
            end
        end;

      begin  { DODIKADO }
        if DIKADOXX = 5 then
          Result := CHKSPCNT( DIKADOXX, 43)
        else
          Result := CHKSPCNT( DIKADOXX, 50);
        if Result <> UNWNONE then exit;
        Result := HEALWHO;              if Result <> UNWNONE then exit;
        Result := DECPRIEST( DIKADOXX); if Result <> UNWNONE then exit;
        TC_HEAL := CHARACTR[ HEALME];
        if DIKADOXX = 5 then
          begin
            if Byte( TC_HEAL^.STATUS) = 5 then           { DEAD }
              exit( DIKADORT)
            else if Byte( TC_HEAL^.STATUS) = 6 then      { ASHES }
              exit( EXITCAST( '"KADORTO" NEEDED'))
          end
        else
          if (Byte( TC_HEAL^.STATUS) = 5) or (Byte( TC_HEAL^.STATUS) = 6) then
            exit( DIKADORT)
          else if Byte( TC_HEAL^.STATUS) = 7 then        { LOST }
            exit( EXITCAST( 'LOST'));
        Result := EXITCAST( 'NOT DEAD')
      end;


      function DODUMAPI: Byte;
      begin
        if not USEITEM_B then
          begin
            TC  := CHARACTR[ CAMPCHAR];
            SKN := TC^.SPELLSKN;
            if (TC.MAGESP[ 1] = 0) or (not SKN^[ 4]) then
              exit( EXITCAST( 'YOU CANNOT CAST IT'))   { v3.2 WC029 }
          end;
        if FIZZLES > 0 then exit( EXITCAST( 'SPELL FAILS'));
        if not USEITEM_B then
          begin
            TC := CHARACTR[ CAMPCHAR];
            TC.MAGESP[ 1] := TC.MAGESP[ 1] - 1
          end;
        LLBASE04 := CAMPCHAR;
        XGOTO2   := XGILGAMS;
        XGOTO    := XCAMPSTF;
        DODUMAPI := U_CAMP                              { EXIT( CAMP) }
      end;


      function DOMALOR: Byte;
      begin
        if not USEITEM_B then
          begin
            TC  := CHARACTR[ CAMPCHAR];
            SKN := TC^.SPELLSKN;
            if (TC.MAGESP[ 7] = 0) or (not SKN^[ 19]) then
              exit( EXITCAST( 'YOU CANNOT CAST IT'))   { v3.2 WC029 }
          end;
        if FIZZLES > 0 then exit( EXITCAST( 'SPELL FAILS'));
        if not USEITEM_B then
          begin
            TC := CHARACTR[ CAMPCHAR];
            TC.MAGESP[ 7] := TC.MAGESP[ 7] - 1
          end;
        LLBASE04 := CAMPCHAR;
        XGOTO2   := XINSPECT;
        XGOTO    := XCAMPSTF;
        DOMALOR  := U_CAMP                              { EXIT( CAMP) }
      end;


    begin  { CASTSPEL }
      DISPSTAT  := false;
      USEITEM_B := BSET_CU( SPELHASH > 0);
      if SPELHASH = -1 then
        begin
          GotoXY( 0, 18);
          Write( Chr( 11));
          Write( '          WHAT SPELL ? >');
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
      WRITEINT( SPELHASH, 6);
      Write( ' ');
      U := UNWNONE;
      if SPELHASH = DIOS then
        U := DOHEAL( 1, 8, 1, 23)
      else if SPELHASH = MILWA then
        begin
          U := CHKSPCNT( 1, 25);
          if U = UNWNONE then U := DECPRIEST( 1);
          if U = UNWNONE then LIGHT := 15 + RNDN( 15)
        end
      else if SPELHASH = DUMAPI then
        U := DODUMAPI
      else if SPELHASH = KANDI then
        U := DOKANDI
      else if SPELHASH = LOMILWA then
        begin
          U := CHKSPCNT( 3, 31);
          if U = UNWNONE then U := DECPRIEST( 3);
          if U = UNWNONE then LIGHT := 32000
        end
      else if SPELHASH = LATUMOFI then
        begin
          U := CHKSPCNT( 4, 37);
          if U = UNWNONE then U := HEALWHO;
          if U = UNWNONE then U := DECPRIEST( 4);
          if U = UNWNONE then
            begin
              TC_HEAL := CHARACTR[ HEALME];
              TC_HEAL.LOSTXYL[ 1] := 0
            end
        end
      else if SPELHASH = DIALKO then
        begin
          U := CHKSPCNT( 3, 32);
          if U = UNWNONE then U := HEALWHO;
          if U = UNWNONE then U := DECPRIEST( 3);
          if U = UNWNONE then
            begin
              TC_HEAL := CHARACTR[ HEALME];
              if (Byte( TC_HEAL^.STATUS) = 3) or (Byte( TC_HEAL^.STATUS) = 2) then  { PLYZE, ASLEEP }
                SETSTATUS_CU( TC_HEAL, OK)
            end
        end
      else if SPELHASH = DIAL then
        U := DOHEAL( 2, 8, 4, 35)
      else if SPELHASH = MAPORFIC then
        begin
          U := CHKSPCNT( 4, 38);
          if U = UNWNONE then U := DECPRIEST( 4);
          if U = UNWNONE then ACMOD2 := 2
        end
      else if SPELHASH = DIALMA then
        U := DOHEAL( 3, 8, 5, 39)
      else if SPELHASH = DI then
        U := DODIKADO( 5)
      else if SPELHASH = MADI then
        U := DOHEAL( -1, -1, 6, 46)
      else if SPELHASH = KADORTO then
        U := DODIKADO( 7)
      else if SPELHASH = MALOR then
        U := DOMALOR
      else
        U := EXITCAST( 'WHAT?');
      if U = UNWNONE then U := EXITCAST( 'DONE!');
      if U = U_CASTSPEL then U := UNWNONE;              { stops here }
      Result := U
    end;  { CASTSPEL }


    function USEITEM: Byte;
    var
      THEITEM : TOBJREC;
      ITEMX   : SmallInt;
      PP      : ^TPOSSESS;
      SPTR    : ^TSPELBLK;
    begin
      Result   := UNWNONE;
      DISPSTAT := false;
      repeat
        GotoXY( 0, 18);
        Write( Chr( 11));
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
        begin AASTRAA( 'POWERLESS'); exit end;          { EXITUSE }
      if Byte( THEITEM.OBJTYPE) <> Byte( SPECIAL) then
        if not PP.EQUIPED then
          begin AASTRAA( 'NOT EQUIPPED'); exit end;
      if RNDN( 100) < THEITEM.CHGCHANC then
        PP.EQINDEX := THEITEM.CHANGETO;
      SPTR := SCNTOC.SPELLS;
      Result := CASTSPEL( SPTR.SPELLHSH[ THEITEM.SPELLPWR]);
      if Result <> UNWNONE then exit;
      DSPITEMS                                          { v3.2 WC017 }
    end;


    procedure DROPITEM;
    var
      POSSX : SmallInt;
      POSSI : SmallInt;
      PP    : ^TPOSSESS;
      PP2   : ^TPOSSESS;
    begin
      DISPSTAT := false;
      repeat
        GotoXY( 0, 18);
        Write( Chr( 11));
        Write( 'DROP ITEM (0=EXIT) ? >');
        GETKEY;
        POSSI := Ord( INCHAR) - Ord( '0');
        if POSSI = 0 then exit;
        TC := CHARACTR[ CAMPCHAR]
      until (POSSI > 0) and (POSSI <= TC.POSS.POSSCNT);
      TC := CHARACTR[ CAMPCHAR];
      PP := TC.POSS.POSSESS[ POSSI];
      if PP.CURSED  then begin AASTRAA( 'CURSED');   exit end;     { EXITDROP }
      if PP.EQUIPED then begin AASTRAA( 'EQUIPPED'); exit end;
      for POSSX := POSSI + 1 to TC^.POSS.POSSCNT do
        begin
          PP  := TC.POSS.POSSESS[ POSSX - 1];
          PP2 := TC.POSS.POSSESS[ POSSX];
          PP^ := PP2^
        end;
      TC.POSS.POSSCNT := TC.POSS.POSSCNT - 1;
      DSPITEMS;
      AASTRAA( 'DROPPED')
    end;


    function IDENTIFY: Byte;
    begin
      IDENTIFY := UNWNONE;
      DISPSTAT := false;
      TC := CHARACTR[ CAMPCHAR];
      if Byte( TC^.XCLASS) <> Byte( BISHOP) then
        begin AASTRAA( 'NOT BISHOP'); exit end;         { EXITIDNT }
      LLBASE04 := CAMPCHAR;
      XGOTO2   := XTRAININ;
      XGOTO    := XCAMPSTF;
      IDENTIFY := U_CAMP                                { EXIT( CAMP) }
    end;


    procedure DOTRADE;
    var
      GOLD2TRA : TWIZLONG;
      TRADETO  : SmallInt;
      GOLDSTR  : string[ 40];
      GOLDX    : SmallInt;
      TEMP0001 : SmallInt;
      ITEMX    : SmallInt;
      TC_TO    : PTCHAR;
      PP       : ^TPOSSESS;
      PP2      : ^TPOSSESS;


      function EXITTRAD(EXITSTR: string): Byte;
      begin
        AASTRAA( EXITSTR);
        EXITTRAD := U_DOTRADE                           { EXIT( DOTRADE) }
      end;


      function TRADGOLD: Byte;
      var
        TEMPGOLD : TWIZLONG;
        MULT10   : SmallInt;
      begin
        TRADGOLD := UNWNONE;
        GotoXY( 0, 18);
        Write( Chr( 11));
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
          exit( EXITTRAD( 'BAD AMOUNT'));               { v3.2 WC026 }
        TC := CHARACTR[ CAMPCHAR];
        if TESTLONG( TC.GOLD, GOLD2TRA) < 0 then
          exit( EXITTRAD( 'NOT ENOUGH $'));
        TC_TO := CHARACTR[ TRADETO];
        ADDLONGS( TC_TO.GOLD, GOLD2TRA);
        TC := CHARACTR[ CAMPCHAR];
        SUBLONGS( TC.GOLD, GOLD2TRA)
      end;  { TRADGOLD }


      procedure TRADITEM;
      { Every way out of it is AP EXIT( DOTRADE), its caller's last call. }
      begin
        repeat
          repeat
            GotoXY( 0, 18);
            Write( Chr( 11));
            Write( 'WHAT ITEM ([RET] EXITS) ? >');
            GETKEY;
            ITEMX := Ord( INCHAR) - Ord( '0');
            if INCHAR = Chr( CRETURN) then exit         { EXIT( DOTRADE) }
          until (ITEMX > 0) and (ITEMX <= CHARACTR[ CAMPCHAR].POSS.POSSCNT);
          TC_TO := CHARACTR[ TRADETO];
          TC    := CHARACTR[ CAMPCHAR];
          if TC_TO.POSS.POSSCNT = 8 then
            begin AASTRAA( 'FULL'); exit end;
          PP := TC.POSS.POSSESS[ ITEMX];
          if PP.CURSED  then begin AASTRAA( 'CURSED');   exit end;
          if PP.EQUIPED then begin AASTRAA( 'EQUIPPED'); exit end;
          TEMP0001 := TC_TO.POSS.POSSCNT + 1;
          PP2  := TC_TO.POSS.POSSESS[ TEMP0001];
          PP2^ := PP^;
          TC_TO.POSS.POSSCNT := TEMP0001;
          for TEMP0001 := ITEMX + 1 to TC^.POSS.POSSCNT do
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
      DISPSTAT := false;
      repeat
        TRADETO := GETCHARX( true, 'TRADE WITH');
        if TRADETO = -1 then exit
      until TRADETO <> CAMPCHAR;
      if TRADGOLD = U_DOTRADE then exit;
      DSPSPELS;                                         { v3.2 WC038: gold }
      TRADITEM
    end;  { DOTRADE }


    procedure DIVALLG( CHAR4GLD: SmallInt);
    { v3.2 WC040: pool the party's gold, then share it out evenly. }
    var
      ALOOP4   : SmallInt;
      GOLD2DIV : TWIZLONG;
      GOLDLESS : TWIZLONG;
      TG, TC2  : PTCHAR;
    begin
      POOLALLG( CHAR4GLD);
      TG := CHARACTR[ CHAR4GLD];
      GOLD2DIV.XLOW  := TG.GOLD.XLOW;                   { record copies by field }
      GOLD2DIV.XMID  := TG.GOLD.XMID;
      GOLD2DIV.XHIGH := TG.GOLD.XHIGH;
      DIVLONG( GOLD2DIV, PARTYCNT);
      GOLDLESS.XLOW  := GOLD2DIV.XLOW;
      GOLDLESS.XMID  := GOLD2DIV.XMID;
      GOLDLESS.XHIGH := GOLD2DIV.XHIGH;
      MULTLONG( GOLDLESS, PARTYCNT);
      SUBLONGS( TG.GOLD, GOLDLESS);
      for ALOOP4 := 0 to PARTYCNT - 1 do
        begin
          TC2 := CHARACTR[ ALOOP4];
          ADDLONGS( TC2.GOLD, GOLD2DIV)
        end
    end;


    { ── CAMPDO: UNWNONE or U_CAMP ── }
    function CAMPDO: Byte;
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
          Write( RACENAME( Byte( TC^.RACE)));
          Write( ' ');
          Write( LEFTSTR( ALIGNNAME( Byte( TC^.ALIGN)), 1));
          Write( '-');
          Write( CLASSNAME( Byte( TC^.XCLASS)));
          WriteLn;
          WriteLn;
          Write( '    STRENGTH');
          WRITEINT( TC.ATTRIB[ STRENGTH], 3);
          Write( '    GOLD ');
          PRNTLONG( TC.GOLD);
          WriteLn;
          Write( '        I.Q.');
          WRITEINT( TC.ATTRIB[ IQ], 3);
          Write( '     EXP ');
          PRNTLONG( TC.EXP);
          WriteLn;
          Write( '       PIETY');
          WRITEINT( TC.ATTRIB[ PIETY], 3);
          WriteLn;
          Write( '    VITALITY');
          WRITEINT( TC.ATTRIB[ VITALITY], 3);
          Write( '   LEVEL ');
          WRITEINT( TC.CHARLEV, 3);
          Write( '     AGE ');
          WRITEINT( (TC.AGE div 52), 3);
          WriteLn;
          Write( '     AGILITY');
          WRITEINT( TC.ATTRIB[ AGILITY], 3);
          Write( '    HITS ');
          WRITEINT( TC.HPLEFT, 3);
          Write( '/');
          WRITEINT( TC.HPMAX, 3);
          Write( '  AC');
          WRITEINT( (TC.ARMORCL - ACMOD2), 4);
          WriteLn;
          Write( '        LUCK');
          WRITEINT( TC.ATTRIB[ LUCK], 3);
          Write( '  STATUS ');
          Write( STATNAME( Byte( TC^.STATUS)));
          if TC.LOSTXYL[ 1] > 0 then Write( ' & POISONED');
          WriteLn;
          DSPSPELS;
          DSPITEMS
        end;  { DSPSTATS }


        procedure MENULST4;                             { v3.2 WC040 }
        begin
          Write( Chr( 11));
          WriteLn( 'YOU MAY E)QUIP, D)ROP AN ITEM, T)RADE,');
          Write( '        ');
          WriteLn( 'POOL G)OLD, DIV)IDE GOLD,');
          Write( '        ')
        end;


        procedure MENULST5;                             { v3.2 WC040 }
        begin
          WriteLn( 'R)EAD SPELL BOOKS, OR L)EAVE.')
        end;


      begin  { CAMPMENU }
        TC2 := CHARACTR[ CAMPCHAR];
        if DISPSTAT then DSPSTATS;
        GotoXY( 0, 18);
        if XGOTO = XINSPCT3 then
          MENUTYPE := 0
        else if XGOTO = XINSPECT then
          MENUTYPE := 1
        else if Byte( TC2^.STATUS) = 0 then              { OK = 0 }
          MENUTYPE := 2
        else
          MENUTYPE := 1;
        if MENUTYPE = 2 then
          begin
            MENULST4;
            WriteLn( 'U)SE AN ITEM, I)DENTIFY AN ITEM,');
            Write( '        ');
            WriteLn( 'CAST S)PELLS,');
            Write( '        ');
            MENULST5
          end
        else if MENUTYPE = 1 then
          begin
            MENULST4;
            MENULST5
          end
        else
          begin
            Write( Chr( 11));
            Write( 'YOU MAY ');
            MENULST5
          end
      end;  { CAMPMENU }


    begin  { CAMPDO }
      Result := UNWNONE;
      CAMPMENU;
      DISPSTAT := true;
      repeat
        GotoXY( 41, 0);
        GETKEY
      until (INCHAR = 'R') or (INCHAR = 'L') or
            ((MENUTYPE > 0) and
             ((INCHAR = 'T') or (INCHAR = 'D') or (INCHAR = 'E') or
              (INCHAR = 'G') or (INCHAR = 'V'))) or
            ((MENUTYPE > 1) and
             ((INCHAR = 'I') or (INCHAR = 'S') or (INCHAR = 'U')));
      case INCHAR of
        'L':  exit;                                     { EXIT( CAMPDO) }
        'E':  if MENUTYPE > 0 then
                begin
                  XGOTO    := XEQPDSP;
                  LLBASE04 := CAMPCHAR;
                  exit( U_CAMP)                         { EXIT( CAMP) }
                end;
        'R':  begin
                XGOTO    := XCAMPSTF;
                XGOTO2   := XDONE;
                LLBASE04 := CAMPCHAR;
                exit( U_CAMP)                           { EXIT( CAMP) }
              end;
        'D':  if MENUTYPE > 0 then DROPITEM;
        'G':  if MENUTYPE > 0 then POOLALLG( CAMPCHAR); { v3.2 WC040 }
        'V':  if MENUTYPE > 0 then DIVALLG( CAMPCHAR);  { v3.2 WC040 }
        'I':  if MENUTYPE = 2 then Result := IDENTIFY;
        'S':  if MENUTYPE = 2 then Result := CASTSPEL( -1);
        'U':  if MENUTYPE = 2 then Result := USEITEM;
        'T':  DOTRADE
      end
    end;  { CAMPDO }


  begin  { INSPECT }
    Result   := UNWNONE;
    CAMPCHAR := LLBASE04;
    XGOTO2   := XGOTO;
    ClrScr;
    repeat
      if CAMPDO = U_CAMP then exit( U_CAMP)
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
      GotoXY( 0, 3 + CHARX);
      Write( Chr( 29));
      WRITEINT( (CHARX + 1), 2);
      Write( ' ');
      TC2 := CHARACTR[ CHARX];
      Write( TC2.NAME);
      GotoXY( 19, 3 + CHARX);
      Write( LEFTSTR( ALIGNNAME( Byte( TC2^.ALIGN)), 1));
      Write( '-');
      Write( LEFTSTR( CLASSNAME( Byte( TC2^.XCLASS)), 3));
      Write( ' ');
      if TC2.ARMORCL - ACMOD2 > -10 then
        WRITEINT( (TC2.ARMORCL - ACMOD2), 2)
      else
        Write( 'LO');
      WRITEINT( TC2.HPLEFT, 5);
      LLBASE04 := TC2.HEALPTS - TC2.LOSTXYL[ 1];
      if LLBASE04 > 0 then Write( '+')
      else if LLBASE04 < 0 then Write( '-')
      else Write( ' ');
      if Byte( TC2^.STATUS) = 0 then                     { OK = 0 }
        if TC2.LOSTXYL[ 1] <> 0 then
          WriteLn( 'POISON')
        else
          begin WRITEINT( TC2.HPMAX, 4); WriteLn end
      else
        WriteLn( STATNAME( Byte( TC2^.STATUS)))
    end;  { DSP1LINE }

  begin  { CAMPMEN2 }
    ClrScr;
    WriteLn( '                  CAMP');
    WriteLn;
    WriteLn( ' # CHARACTER NAME  CLASS AC HITS STATUS');
    for CHARX := 0 to PARTYCNT - 1 do
      DSP1LINE( CHARX);
    GotoXY( 0, 12);
    WriteLn( 'YOU MAY R)EORDER, E)QUIP, D)ISBAND,');
    Write( '        ');
    WriteLn( '#) TO INSPECT, OR');
    Write( '        ');
    WriteLn( 'L)EAVE THE CAMP.')
  end;  { CAMPMEN2 }


  { ── DISBAND: UNWNONE (not confirmed) or U_CAMP ── }
  function DISBAND: Byte;
  var
    TC2 : PTCHAR;

    function CONFIRM(NULLRE: string): Byte;
    begin
      CONFIRM := UNWNONE;
      ClrScr;
      Write( NULLRE);
      Write( 'CONFIRM (Y/N) ?');
      repeat
        GotoXY( 41, 0);
        GETKEY                                          { AP: READ( INCHAR) }
      until (INCHAR = 'Y') or (INCHAR = 'N');
      if INCHAR = 'N' then
        CONFIRM := U_DISBAND                            { EXIT( DISBAND) }
    end;

  begin  { DISBAND }
    Result := UNWNONE;
    if CONFIRM( '')    = U_DISBAND then exit;
    if CONFIRM( 'RE-') = U_DISBAND then exit;
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
    Result   := U_CAMP                                  { EXIT( CAMP) }
  end;  { DISBAND }


begin  { CAMP }
  DISPSTAT := true;
  for OBJI := 1 to 8 do
    OBJIDS[ OBJI - 1] := -1;
  TEXTMODE;
  if (XGOTO = XBCK2CMP) or (XGOTO = XBK2CMP2) then
    begin
      XGOTO := XGOTO2;
      if XGOTO = XINSPCT2 then
        if INSPECT = U_CAMP then exit
    end;
  if XGOTO = XINSPECT then
    begin
      if INSPECT = U_CAMP then exit;
      XGOTO := XGILGAMS;
      exit
    end;
  if XGOTO = XINSPCT3 then
    begin
      LLBASE04 := 0;
      if INSPECT = U_CAMP then exit;
      XGOTO := XBCK2ROL;
      exit
    end;
  repeat
    UNITCLEAR( 1);
    CAMPMEN2;
    GotoXY( 41, 0);
    GETKEY;
    if (INCHAR > '0') and (INCHAR <= Chr( Ord( '0') + PARTYCNT)) then
      begin
        LLBASE04 := Ord( INCHAR) - Ord( '1');
        for OBJI := 1 to 8 do
          OBJIDS[ OBJI - 1] := -1;
        if INSPECT = U_CAMP then exit
      end
    else
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
        'D':  if DISBAND = U_CAMP then exit
      end
  until false
end;  { CAMP }


end.
