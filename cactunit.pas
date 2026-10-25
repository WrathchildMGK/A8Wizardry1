unit CACTUNIT;

{ Wizardry I — CUTIL's CACTION (AP P010602): the party's choices for the
  round.  An overlay of its own, split from CUTIL (cutilunit.pas) for size;
  the resident combat loop runs it after CUTIL unless DONEFIGH.
  Source: apple/Wizardry_v3-2/Wiz1B.DSK/COMBAT3 (v3.2). }

interface

uses TYPES, CONSTS, GLOBALS, UTIL, SCREEN, COMBATG;

procedure CACTN;

implementation

const
  U_CUTIL    = $10;       { unwind targets: CUTIL (AP has no number: $10), }
  U_CACTION  = $02;       {   P010602, P01060B, P010604                    }
  U_GETSPELL = $0B;
  U_USEITEM  = $04;


function CACTION: Byte;
var
  SPLGRCNT : array[ 0..5] of SmallInt;
  BDISPELL : Boolean;
  MYCHARX  : SmallInt;
  AGIL1TEN : SmallInt;
  POSSY    : SmallInt;                            { v3.2 WC030 }
  UNARMED2 : Boolean;
  U        : Byte;
  PT04     : ^TTEMP04;
  TC       : PTCHAR;
  PP       : ^TPOSSESS;
  SKNS     : ^TSPELLSKN;
  SPTR     : ^TSPELBLK;
  BRC0     : ^TENEMY2;
  BRA0     : ^TENEMY2A;


  procedure WHICHGRP( SOLICIT: string; SPELLHSH: SmallInt);
  var
    XBRC : ^TENEMY2;
    XBRA : ^TENEMY2A;
  begin
    PT04 := BRA0.TEMP04[ MYCHARX];
    XBRC := BATTLERC[ 2];
    XBRA := XBRC^.A;
    if XBRA.ALIVECNT = 0 then
      begin
        PT04.VICTIM   := 1;
        PT04.SPELLHSH := SPELLHSH;
        exit
      end;
    MVCURSOR( 26 - (Length( SOLICIT) div 2), 8);
    PRINTSTR( SOLICIT);
    repeat
      GETKEY
    until ((INCHAR >= '1') and (INCHAR < '5')) or
           (INCHAR = Chr( CRETURN));
    if INCHAR = Chr( CRETURN) then
      begin
        PT04.SPELLHSH := -999;
        exit
      end;
    XBRC := BATTLERC[ Ord( INCHAR) - Ord( '0')];
    XBRA := XBRC^.A;
    if XBRA.ALIVECNT = 0 then
      begin
        PT04.SPELLHSH := -999;
        exit
      end;
    PT04.VICTIM   := Ord( INCHAR) - Ord( '0');
    PT04.SPELLHSH := SPELLHSH;
    CLRRECT( 13, 8, 26, 2)
  end;


  procedure USEITEM;
  var
    BUSEABLE : array[ 0..8] of Boolean;
    POSSX    : SmallInt;
    OBJREC   : TOBJREC;

    procedure READOBJT;
    begin
      TC := CHARACTR[ MYCHARX];
      PP := TC.POSS.POSSESS[ POSSX];
      LOADOBJREC( PP.EQINDEX, OBJREC)
    end;

    function DSPITEMS: Byte;
    var
      ITEMCNT : SmallInt;
    begin
      DSPITEMS := UNWNONE;
      CLRRECT( 1, 11, 38, 4);
      ITEMCNT := 0;
      TC := CHARACTR[ MYCHARX];
      for POSSX := 1 to TC^.POSS.POSSCNT do
        begin
          BUSEABLE[ POSSX] := false;
          MVCURSOR( 1 + 19 * ((POSSX - 1) mod 2),
                    11 + (POSSX - 1) div 2);
          READOBJT;
          if OBJREC.SPELLPWR > 0 then
            begin
              PP := TC.POSS.POSSESS[ POSSX];
              if (OBJREC.OBJTYPE = SPECIAL) or PP.EQUIPED then
                begin
                  ITEMCNT := ITEMCNT + 1;
                  BUSEABLE[ POSSX] := true;
                  PRINTNUM( POSSX, 1);
                  PRINTSTR( ') ');
                  if PP.IDENTIF then
                    PRINTSTR( OBJREC.NAME)
                  else
                    PRINTSTR( OBJREC.NAMEUNK)
                end
            end
        end;
      if ITEMCNT = 0 then
        exit( U_USEITEM);                             { EXIT( USEITEM) }
      MVCURSOR( 13, 8);
      PRINTSTR( 'WHICH ITEM (RETURN EXITS)?')
    end;

    procedure CHGITEM;
    begin
      if (RNDN(100)) >= OBJREC.CHGCHANC then
        exit;
      PP := TC.POSS.POSSESS[ POSSX];
      PP.EQINDEX := OBJREC.CHANGETO;
      PP.IDENTIF := false
    end;

    procedure UIGENERC( SPELLHSH: SmallInt);
    begin
      PT04 := BRA0.TEMP04[ MYCHARX];
      PT04.SPELLHSH := SPELLHSH;
      PT04.VICTIM   := -1;
      CHGITEM
    end;

    procedure UIPERSON( SPELLHSH: SmallInt);
    begin
      MVCURSOR( 15, 8);
      PRINTSTR( 'USE ITEM ON PERSON # ?');
      repeat
        GETKEY
      until (INCHAR >= '1') and
            (Ord( INCHAR) <= (Ord( '0') + PARTYCNT));
      PT04 := BRA0.TEMP04[ MYCHARX];
      PT04.VICTIM   := Ord( INCHAR) - Ord( '0') - 1;
      PT04.SPELLHSH := SPELLHSH;
      CHGITEM
    end;

    procedure UIGROUP( SPELLHSH: SmallInt);
    begin
      WHICHGRP( 'USE ITEM ON WHAT GROUP # ?', SPELLHSH);
      CHGITEM
    end;

  begin  { USEITEM }
    TC := CHARACTR[ MYCHARX];
    if TC.POSS.POSSCNT = 0 then
      exit;
    if DSPITEMS = U_USEITEM then
      exit;
    repeat
      GETKEY;
      POSSX := Ord( INCHAR) - Ord( '0');
      if INCHAR = Chr( CRETURN) then
        exit
    until (POSSX > 0) and
          (POSSX <= CHARACTR[ MYCHARX].POSS.POSSCNT) and
          BUSEABLE[ POSSX];
    READOBJT;
    CLRRECT( 13, 6, 26, 4);
    SPTR := @SPELBLK_DATA;
    LLBASE04 := SPTR.SPELLHSH[ OBJREC.SPELLPWR];
    case SPTR.SPELL012[ OBJREC.SPELLPWR] of
      0: UIGENERC( LLBASE04);
      1: UIPERSON( LLBASE04);
      2: UIGROUP(  LLBASE04);
    end
  end;  { USEITEM }


  procedure GETSPELL;
  var
    SPELLNAM : string[ 22];
    SPELLCST : SmallInt;
    SPELNAML : SmallInt;
    SPELCHRA : SmallInt;
    SPELNAMI : SmallInt;

    function DOSPELL: Byte;                       { UNWNONE or U_GETSPELL }
    var
      SPELLX : SmallInt;

      function CASTCHK( SPELLI: SmallInt; SPELLGR: SmallInt): Byte;
      begin
        CASTCHK := UNWNONE;
        TC   := CHARACTR[ MYCHARX];
        SKNS := TC^.SPELLSKN;
        if SKNS^[ SPELLI] then
          if (SPELLI < 22) and
             (TC.MAGESP[ SPELLGR] > 0) then
            SPLGRCNT[ MYCHARX] := SPELLGR
          else
            if TC.PRIESTSP[ SPELLGR] > 0 then
              SPLGRCNT[ MYCHARX] := SPELLGR + 10;
        MVCURSOR( 13, 9);
        if SPLGRCNT[ MYCHARX] > 0 then
          exit;
        if SKNS^[ SPELLI] then
          PRINTSTR( 'SPELL POINTS EXHAUSTED')
        else
          PRINTSTR( 'YOU DO NOT KNOW THAT SPELL');      { v3.2 WC029 }
        PAUSE1;
        CASTCHK := U_GETSPELL                           { EXIT( GETSPELL) }
      end;

      function SPGENERC( SPELLI: SmallInt; SPELLGR: SmallInt): Byte;
      begin
        Result := CASTCHK( SPELLI, SPELLGR);
        if Result <> UNWNONE then exit;
        PT04 := BRA0.TEMP04[ MYCHARX];
        PT04.SPELLHSH := SPELLCST;
        PT04.VICTIM   := -1
      end;

      function SPPERSON( SPELLI: SmallInt; SPELLGR: SmallInt): Byte;
      begin
        Result := CASTCHK( SPELLI, SPELLGR);
        if Result <> UNWNONE then exit;
        MVCURSOR( 13, 8);
        PRINTSTR( ' CAST SPELL ON PERSON # ?');
        repeat
          GETKEY
        until (INCHAR >= '1') and
              (Ord( INCHAR) <= (Ord( '0') + PARTYCNT));
        PT04 := BRA0.TEMP04[ MYCHARX];
        PT04.VICTIM   := Ord( INCHAR) - Ord( '0') - 1;
        PT04.SPELLHSH := SPELLCST;
        CLRRECT( 13, 8, 26, 1)
      end;

      function SPGROUP( SPELLI: SmallInt; SPELLGR: SmallInt): Byte;
      begin
        Result := CASTCHK( SPELLI, SPELLGR);
        if Result <> UNWNONE then exit;
        WHICHGRP( 'CAST SPELL ON GROUP # ?', SPELLCST)  { v3.2 WC002 }
      end;

    begin  { DOSPELL }
      Result := UNWNONE;
      SPTR := @SPELBLK_DATA;
      for SPELLX := 0 to 50 do
        if SPELLCST = SPTR.SPELLHSH[ SPELLX] then
          begin
            case SPTR.SPELL012[ SPELLX] of
              0: Result := SPGENERC( SPELLX, SPTR.SPELLGRP[ SPELLX]);
              1: Result := SPPERSON( SPELLX, SPTR.SPELLGRP[ SPELLX]);
              2: Result := SPGROUP(  SPELLX, SPTR.SPELLGRP[ SPELLX]);
            end;
            if Result <> UNWNONE then exit
          end
    end;  { DOSPELL }

  begin  { GETSPELL }
    MVCURSOR( 13, 8);
    PRINTSTR( 'SPELL NAME ? >');
    GETSTR( SPELLNAM, 27, 8);
    SPELNAML := Length( SPELLNAM);
    if SPELNAML = 0 then
      exit;
    SPELLCST := SPELNAML;
    for SPELNAMI := 1 to SPELNAML do
      begin
        SPELCHRA := Ord( SPELLNAM[ SPELNAMI]) - 64;
        SPELLCST := SPELLCST + (SPELCHRA * SPELCHRA * SPELNAMI)
      end;
    CLRRECT( 13, 8, 26, 1);
    if DOSPELL = U_GETSPELL then exit                 { ends GETSPELL }
  end;  { GETSPELL }


  function RUNAWAY: Byte;                         { U_CACTION or U_CUTIL }
  var
    TEMP : SmallInt;
    XBRC : ^TENEMY2;
    XBRA : ^TENEMY2A;

    function RUNFAILD: Byte;
    var
      PT04R : ^TTEMP04;
    begin
      for TEMP := 0 to PARTYCNT - 1 do
        begin
          PT04R := BRA0.TEMP04[ TEMP];
          PT04R.AGILITY := -1
        end;
      RUNFAILD := U_CACTION                       { EXIT( CACTION) }
    end;

  begin  { RUNAWAY }
    CLRRECT( 13, 6, 26, 4);
    TEMP := 38 - 3 * MAZELEV;
    if PARTYCNT < 4 then
      TEMP := TEMP + 20 - 5 * PARTYCNT;
    if MYSTRENG > ENSTRENG then
      TEMP := TEMP + 20;
    if MAZELEV = 10 then
      TEMP := -1;
    if (RNDN(100)) > TEMP then
      exit( RUNFAILD);
    for TEMP := 1 to 4 do
      begin
        XBRC := BATTLERC[ TEMP];
        XBRA := XBRC^.A;
        XBRA.ALIVECNT := 0;
        XBRA.ENMYCNT  := 0
      end;
    XGOTO    := XREWARD2;
    DONEFIGH := true;
    Result   := U_CUTIL                           { EXIT( CUTIL) }
  end;  { RUNAWAY }


  procedure DOSUPRIS;
  begin
    CLRRECT( 13, 6, 26, 4);
    CLRRECT( 1, 11, 38, 4);
    MVCURSOR( 1, 12);
    if SURPRISE = 1 then
      PRINTSTR( 'YOU SURPRISED THE MONSTERS!')
    else
      if SURPRISE = 2 then
        PRINTSTR( 'THE MONSTERS SURPRISED YOU!');
    if SURPRISE <> 0 then
      begin
        Write( Chr( 7));
        Write( Chr( 7));
        Write( Chr( 7));
        PAUSE2;
        PAUSE2
      end
  end;


begin  { CACTION }
  Result := UNWNONE;
  BRC0 := BATTLERC[ 0];
  BRA0 := BRC0^.A;
  DOSUPRIS;
  MYCHARX := 0;
  FillChar( SPLGRCNT[ 0], 12, 0);
  while MYCHARX < PARTYCNT do
    begin
      repeat
        PT04 := BRA0.TEMP04[ MYCHARX];
        if (Byte( PT04^.XSTATUS) = 0) and (SURPRISE <> 2) then
          begin
            PT04.SPELLHSH := -999;
            repeat
              AGIL1TEN := RNDN(10);
              TC := CHARACTR[ MYCHARX];
              case TC.ATTRIB[ Ord( AGILITY)] of
                 3: AGIL1TEN := AGIL1TEN + 3;
                4,
                5: AGIL1TEN := AGIL1TEN + 2;
                6,
                7: AGIL1TEN := AGIL1TEN + 1;
                15: AGIL1TEN := AGIL1TEN - 1;
                16: AGIL1TEN := AGIL1TEN - 2;
                17: AGIL1TEN := AGIL1TEN - 3;
                18: AGIL1TEN := AGIL1TEN - 4;
              end;
              if TC^.XCLASS = NINJA then                 { v3.2 WC030 }
                begin
                  UNARMED2 := true;
                  for POSSY := 1 to TC^.POSS.POSSCNT do
                    begin
                      PP := TC.POSS.POSSESS[ POSSY];
                      if PP.EQUIPED then UNARMED2 := false
                    end;
                  if UNARMED2 then
                    AGIL1TEN := AGIL1TEN - (TC.CHARLEV div 3)
                end;
              if AGIL1TEN < 1 then
                AGIL1TEN := 1
              else if AGIL1TEN > 10 then
                AGIL1TEN := 10;
              PT04.AGILITY := AGIL1TEN;
              UNITCLEAR( 1);
              MVCURSOR( 13, 6);
              PRINTSTR( TC.NAME);
              PRINTSTR( '''S OPTIONS');
              MVCURSOR( 13, 8);
              if MYCHARX < 3 then
                PRINTSTR( 'F)IGHT  ');
              if SURPRISE = 0 then                      { v3.2 WC023 }
                PRINTSTR( 'S)PELL  P)ARRY')
              else
                PRINTSTR( 'P)ARRY');
              MVCURSOR( 13, 9);
              PRINTSTR( 'R)UN    U)SE    ');
              BDISPELL := false;
              if (Byte( TC^.XCLASS) = 2) or
                 ((Byte( TC^.XCLASS) = 6) and (TC.CHARLEV > 8)) or
                 ((Byte( TC^.XCLASS) = 4) and (TC.CHARLEV > 3)) then
                begin
                  BDISPELL := true;
                  PRINTSTR( 'D)ISPEL  ')                { v3.2 WC002 }
                end;
              repeat
                GETKEY
              until (INCHAR = 'F') or (INCHAR = 'S') or
                    (INCHAR = 'P') or (INCHAR = 'U') or
                    (INCHAR = 'D') or (INCHAR = 'R') or
                    (INCHAR = 'B');
              CLRRECT( 13, 8, 26, 2);
              SPLGRCNT[ MYCHARX] := 0;
              U := UNWNONE;
              case INCHAR of
                'D': if BDISPELL then
                       WHICHGRP( 'DISPEL WHICH GROUP # ?', -5);     { v3.2 WC002 }
                'R': U := RUNAWAY;
                'F': if MYCHARX < 3 then
                       WHICHGRP( 'FIGHT AGAINST GROUP # ?', -1);    { v3.2 WC002 }
                'P': begin
                       PT04.SPELLHSH := 0;
                       PT04.AGILITY  := -1
                     end;
                'S': if SURPRISE = 0 then GETSPELL;               { v3.2 WC023 }
                'U': begin
                       USEITEM;
                       CLRRECT( 1, 11, 38, 4)
                     end;
                'B': if MYCHARX > 0 then
                       PT04.SPELLHSH := -100;
              end;
              if U = U_CUTIL then exit( U_CUTIL);
              if U = U_CACTION then exit;                         { ends CACTION }
              CLRRECT( 13, 6, 26, 4);
            until PT04.SPELLHSH <> -999;
            if PT04.SPELLHSH = -100 then
              MYCHARX := -1
          end
        else
          PT04.AGILITY := -1;
        MYCHARX := MYCHARX + 1
      until MYCHARX = PARTYCNT;
      if SURPRISE <> 2 then
        begin
          MVCURSOR( 14, 6);
          PRINTSTR( 'PRESS [RETURN] TO FIGHT,');
          MVCURSOR( 25, 7);
          PRINTSTR( 'OR');
          MVCURSOR( 14, 8);
          PRINTSTR( 'GO B)ACK TO REDO OPTIONS');
          repeat
            GETKEY
          until (INCHAR = Chr( CRETURN)) or (INCHAR = 'B');
          if INCHAR = 'B' then
            MYCHARX := 0
        end;
      CLRRECT( 13, 6, 26, 4);
      CLRRECT( 1, 11, 38, 4)
    end;
  for MYCHARX := 0 to PARTYCNT - 1 do
    begin
      TC := CHARACTR[ MYCHARX];
      if SPLGRCNT[ MYCHARX] > 0 then
        if SPLGRCNT[ MYCHARX] > 10 then
          TC.PRIESTSP[ SPLGRCNT[ MYCHARX] - 10] :=
            TC.PRIESTSP[ SPLGRCNT[ MYCHARX] - 10] - 1
        else
          TC.MAGESP[ SPLGRCNT[ MYCHARX]] :=
            TC.MAGESP[ SPLGRCNT[ MYCHARX]] - 1
    end
end;  { CACTION }


procedure CACTN;
begin
  CMBEXIT := UNWNONE;
  if CACTION = U_CUTIL then exit;                       { EXIT( CUTIL) }
  SURPRISE := 0
end;


end.
