unit UTILUNIT;

{ Source: apple/wiz1c/UTILITIE + apple/wiz1b/UTILITIE2 + apple/wiz1b/UTILITIE3

  Translation notes:
    - SEGMENT PROCEDURE UTILITIE -> unit procedure UTILITIE
    - EXIT(UTILITIE) -> _done := true; exit (propagated up call chain)
    - EXIT(PROC) for current procedure -> plain exit
    - EXIT(FIGHTS) from FINDSPOT -> _ffail flag in FIGHTS
    - WITH CHARACTR[X] DO -> TC := CHARACTR[X]; TC.FIELD
    - POSS.POSSESS[I].FIELD -> PP := TC.POSS.POSSESS[I]; PP.FIELD
    - CLASS -> XCLASS (reserved word in MP)
    - LOSTXYL.LOCATION[1..3] / POISNAMT[1] -> LOSTXYL[1..3]
    - MOVELEFT TMAZE   -> LOADTMAZE
    - MOVELEFT TCHAR   -> LOADTCHAR
    - MOVELEFT TOBJREC -> LOADOBJREC
    - MOVELEFT TSCNTOC -> (SCNTOC is already a global; reload stubbed)
    - RANDOM MOD N -> Random(N)
    - GOTOXY(X,Y)  -> MVCURSOR(X,Y)
    - BASE12.GOTOX -> XGOTO2 (CAMP sets XGOTO2 before jumping to XCAMPSTF)
    - UNITREAD/UNITWRITE -> stubbed (disk I/O not yet wired up)
    - FOR OBJI := WEAPON TO GAUNTLET -> integer loop with TOBJTYPE cast
    - SUCC(ATTRX) on enum -> TATTRIB(Byte(ATTRX)+1) if MP fails; try SUCC first
}

interface

uses TYPES, CONSTS, GLOBALS, UTIL, crt;

procedure UTILITIE;

implementation

var
  _done   : Boolean;
  CHARI   : SmallInt;   { shared across EQUIPCHR/EQUIP6/EQUIP1 }
  CHARX   : SmallInt;   { shared across RDSPELLS/IDITEM/KANDIFND/DUMAPIC/MALOR }
  EQUIPALL : Boolean;

{ Unit-level helper: assign TSTATUS through ^TCHAR pointer.
  Required because enum constants inside deeply nested procedures (or inside
  case Byte(X) of arms) are re-typed as Byte in MP, causing E6 on direct
  assignment to ENUM-typed fields. Passing as a typed parameter restores the
  correct enum type. }
procedure SETSTAT( TC: PTCHAR; ST: TSTATUS);
begin TC.STATUS := ST end;

procedure SETXCLS( TC: PTCHAR; CL: TCLASS);
begin TC.XCLASS := CL end;


procedure UTILITIE;


  { ── RDSPELLS ─────────────────────────────────────────────────────────────── }

  procedure RDSPELLS;
  const
    SCNMAGE = 4;
    SCNPRST = 5;
  var
    SPELLGRP  : SmallInt;
    SPLISTX   : SmallInt;
    DSKSPLNM  : SmallInt;
    SPELLX    : SmallInt;
    TC        : ^TCHAR;
    SKNS      : ^TSPELLSKN;


    procedure LISTSPLS;
    var
      SPELLNM : string[ 15];
      CHPTR   : SmallInt;


      procedure PRSPELL( SPELLNM: string);
      begin
        if SPELLNM[ 1] = '*' then
          begin
            SPELLNM := Copy( SPELLNM, 2, Length( SPELLNM) - 1);
            SPLISTX := SPLISTX + 1
          end;
        MVCURSOR( 10 * (SPLISTX div 20), 2 + SPLISTX mod 20);
        TC := CHARACTR[ CHARX];
        SKNS := TC.SPELLSKN;
        if SKNS^[ SPELLX] then
          begin
            PRINTSTR( SPELLNM);
            SPLISTX := SPLISTX + 1
          end;
        SPELLX := SPELLX + 1
      end;  { PRSPELL }


      procedure SPRETURN;
      begin
        MVCURSOR( 0, 23);
        PRINTSTR( 'L)EAVE WHEN READY');
        repeat
          MVCURSOR( 41, 0);
          GETKEY
        until INCHAR = 'L';
        INCHAR := Chr( 0)
      end;  { SPRETURN }


    begin  { LISTSPLS }
      UNITREAD( SCNTOCBL + DSKSPLNM);   { load spell name block into IOCACHE }
      CHPTR := 0;
      SPLISTX := 0;
      while IOCACHE[ CHPTR] <> Chr( CRETURN) do
        begin
          LLBASE04 := 0;
          while IOCACHE[ CHPTR] <> Chr( CRETURN) do
            begin
              LLBASE04 := LLBASE04 + 1;
              SPELLNM[ LLBASE04] := IOCACHE[ CHPTR];
              CHPTR := CHPTR + 1
            end;
          SPELLNM[ 0] := Chr( LLBASE04);
          PRSPELL( SPELLNM);
          CHPTR := CHPTR + 1
        end;
      SPRETURN
    end;  { LISTSPLS }


    procedure PRPRIEST;
    begin
      Write( Chr( 12));
      Write( 'KNOWN PRIEST SPELLS');
      DSKSPLNM := SCNPRST;
      SPELLX   := 22;
      LISTSPLS
    end;


    procedure PRMAGE;
    begin
      DSKSPLNM := SCNMAGE;
      SPELLX   := 1;
      Write( Chr( 12));
      Write( 'KNOWN MAGE SPELLS');
      LISTSPLS
    end;


  begin  { RDSPELLS }
    CHARX := LLBASE04;
    TC := CHARACTR[ CHARX];
    repeat
      Write( Chr( 12));
      Write( 'MAGE   SPELLS LEFT = ');
      Write( TC.MAGESP[ 1]);
      SPELLGRP := 2;
      while SPELLGRP <= 7 do
        begin
          Write( '/');
          Write( TC.MAGESP[ SPELLGRP]);
          SPELLGRP := SPELLGRP + 1
        end;
      WriteLn;
      Write( 'PRIEST SPELLS LEFT = ');
      Write( TC.PRIESTSP[ 1]);
      SPELLGRP := 2;
      while SPELLGRP <= 7 do
        begin
          Write( '/');
          Write( TC.PRIESTSP[ SPELLGRP]);
          SPELLGRP := SPELLGRP + 1
        end;
      WriteLn;
      WriteLn;
      WriteLn( 'YOU MAY SEE M)AGE OR P)RIEST SPELL BOOKS');
      WriteLn( 'OR L)EAVE.');
      MVCURSOR( 41, 15);
      GETKEY;
      case INCHAR of
        'M': PRMAGE;
        'P': PRPRIEST;
      end
    until INCHAR = 'L';
    INCHAR := Chr( 0);
    XGOTO := XBK2CMP2;
    LLBASE04 := CHARX;
    _done := true; exit
  end;  { RDSPELLS }


  { ── IDITEM ───────────────────────────────────────────────────────────────── }

  procedure IDITEM;
  var
    ITEMX  : SmallInt;
    OBJ    : TOBJREC;
    TC     : ^TCHAR;
    PP     : ^TPOSSESS;


    procedure EXITIDIT;
    begin
      LLBASE04 := CHARX;
      _done := true; exit
    end;


  begin  { IDITEM }
    CHARX := LLBASE04;
    TC := CHARACTR[ CHARX];
    XGOTO := XBK2CMP2;
    repeat
      MVCURSOR( 0, 18);
      Write( Chr( 11));
      Write( 'IDENTIFY WHAT ITEM (0=EXIT) ? >');
      GETKEY;
      ITEMX := Byte( INCHAR) - Byte( '0');
      if ITEMX = 0 then begin EXITIDIT; if _done then exit end
    until (ITEMX > 0) or (ITEMX <= TC.POSS.POSSCNT);
    PP := TC.POSS.POSSESS[ ITEMX];
    if PP.IDENTIF then begin EXITIDIT; if _done then exit end;
    PP.IDENTIF :=
      (Random( 100)) < (10 + 5 * TC.CHARLEV);
    if PP.IDENTIF then
      CENTSTR( 'SUCCESS!')
    else
      CENTSTR( 'FAILURE');
    if (Random( 100)) < (35 - (3 * TC.CHARLEV)) then
      begin
        LOADOBJREC( PP.EQINDEX, OBJ);
        PP.CURSED := OBJ.CURSED;
        XGOTO := XEQPDSP
      end;
    EXITIDIT
  end;  { IDITEM }


  { ── KANDIFND ─────────────────────────────────────────────────────────────── }

  procedure KANDIFND;
  var
    CHARXDSK  : SmallInt;
    LOCSTRING : string[ 40];
    LOSTCHAR  : TCHAR;


    procedure EXITKAND;
    begin
      WriteLn;
      WriteLn( 'L)EAVE WHEN READY');
      MVCURSOR( 41, 0);
      repeat
        GETKEY
      until INCHAR = 'L';
      INCHAR := 'A';
      LLBASE04 := CHARX;
      XGOTO := XBK2CMP2;
      _done := true; exit
    end;


    procedure KANDILOC;
    begin
      if Byte( LOSTCHAR.STATUS) = Byte( LOST) then exit;
      if Byte( LOSTCHAR.STATUS) < Byte( DEAD) then
        WriteLn( 'STILL WITH US!')
      else
        begin
          if (LOSTCHAR.LOSTXYL[ 1] = 0) and
             (LOSTCHAR.LOSTXYL[ 2] = 0) and
             (LOSTCHAR.LOSTXYL[ 3] = 0) then
            WriteLn( 'IN THE MOURGE')
          else
            if LOSTCHAR.LOSTXYL[ 3] <= 0 then
              WriteLn( 'UNREACHABLE!')
            else
              begin
                Write( 'IN THE ');
                if LOSTCHAR.LOSTXYL[ 2] > 9 then
                  Write( 'NORTH ')
                else
                  Write( 'SOUTH ');
                if LOSTCHAR.LOSTXYL[ 1] > 9 then
                  Write( 'EAST')
                else
                  Write( 'WEST');
                Write( ' OF LEVEL ');
                WriteLn( LOSTCHAR.LOSTXYL[ 3])
              end
        end;
      EXITKAND; if _done then exit
    end;  { KANDILOC }


  begin  { KANDIFND }
    CHARX := LLBASE04;
    Write( Chr( 12));
    WriteLn( 'LOCATE BODIES');
    WriteLn;
    Write( 'FIND WHO ? >');
    GETLINE;
    LOCSTRING := GTSTRING;
    Write( Chr( 12));
    Write( 'THE SOUL OF ');
    Write( LOCSTRING);
    WriteLn( ' IS..');
    WriteLn;
    for CHARXDSK := 0 to SCNTOC.RECPERDK[ ZCHAR] - 1 do
      begin
        LOADTCHAR( CHARXDSK, LOSTCHAR);
        if LOSTCHAR.NAME = LOCSTRING then
          begin KANDILOC; if _done then exit end
      end;
    WriteLn( 'LOST FOREVER!');
    EXITKAND
  end;  { KANDIFND }


  { ── DUMAPIC ──────────────────────────────────────────────────────────────── }

  procedure DUMAPIC;
  begin
    XGOTO := XBK2CMP2;
    if MAZELEV = 10 then
      begin
        Write( Chr( 12));
        WriteLn( 'ENCHANTMENTS PREVENT SPELL FROM WORKING');
        _done := true; exit
      end;
    CHARX := LLBASE04;
    Write( Chr( 12));
    WriteLn( 'PARTY LOCATION:');
    WriteLn;
    Write( 'THE PARTY IS FACING ');
    case Byte( DIRECTIO) of
      0: WriteLn( 'NORTH.');
      1: WriteLn( 'EAST.');
      2: WriteLn( 'SOUTH.');
      3: WriteLn( 'WEST.');
    end;
    WriteLn;
    Write( 'YOU ARE ');
    Write( MAZEX);
    WriteLn( ' SQUARES EAST AND');
    Write( MAZEY);
    WriteLn( ' SQUARES NORTH OF THE STAIRS');
    Write( 'TO THE CASTLE, AND ');
    Write( MAZELEV);
    WriteLn( ' LEVELS');
    WriteLn( 'BELOW IT.');
    WriteLn;
    WriteLn( 'L)EAVE WHEN READY');
    repeat
      MVCURSOR( 41, 0);
      GETKEY
    until INCHAR = 'L';
    INCHAR := 'A';
    LLBASE04 := CHARX;
    _done := true; exit
  end;  { DUMAPIC }


  { ── MALOR_PROC ───────────────────────────────────────────────────────────── }

  procedure MALOR_PROC;
  var
    DELTAUD : SmallInt;
    DELTANS : SmallInt;
    DELTAEW : SmallInt;


    procedure TELEPORT;


      procedure ROCK;
      var X : SmallInt; XTC : ^TCHAR;
      begin
        WriteLn( 'YOU LANDED IN SOLID ROCK OUTSIDE THE');
        WriteLn( 'DUNGEON - YOU ARE LOST FOREVER!');
        for X := 0 to PARTYCNT - 1 do
          begin
            XTC := CHARACTR[ X];
            XTC.INMAZE := false;
            SETSTAT( XTC, LOST)
          end;
        XGOTO := XCEMETRY;
        _done := true; exit
      end;


      procedure VOLCANO;
      var X : SmallInt; XTC : ^TCHAR;
      begin
        WriteLn( 'YOU MATERIALIZED IN MID-AIR AND FELL');
        WriteLn( 'TO A PAINFUL DEATH!');
        for X := 0 to PARTYCNT - 1 do
          begin
            XTC := CHARACTR[ X];
            if Byte( XTC.STATUS) < Byte( DEAD) then
              SETSTAT( XTC, DEAD)
          end;
        MAZELEV := 0;
        XGOTO := XCHK4WIN;
        _done := true; exit
      end;


      procedure MOAT;
      var X : SmallInt; XTC : ^TCHAR;
      begin
        WriteLn( 'YOU APPEARED IN THE CASTLE MOAT AND');
        WriteLn( 'PROBABLY DROWNED!');
        for X := 0 to PARTYCNT - 1 do
          begin
            XTC := CHARACTR[ X];
            if Byte( XTC.STATUS) < Byte( DEAD) then
              if (Random( 25)) > XTC.ATTRIB[ AGILITY] then
                SETSTAT( XTC, DEAD)
          end;
        MAZELEV := 0;
        XGOTO := XCHK4WIN;
        _done := true; exit
      end;


      procedure TOSHOPS;
      begin
        XGOTO := XCHK4WIN;
        _done := true; exit
      end;


      procedure BOUNCE;
      begin
        WriteLn( 'YOU BOUNCED BACK TO WHERE YOU WERE!');
        _done := true; exit
      end;


    begin  { TELEPORT }
      Write( Chr( 12));
      XGOTO := XNEWMAZE;
      if MAZELEV + DELTAUD = SCNTOC.RECPERDK[ ZMAZE] then
        begin BOUNCE; if _done then exit end;
      MAZEX   := MAZEX + DELTAEW;
      MAZEY   := MAZEY + DELTANS;
      MAZELEV := MAZELEV + DELTAUD;
      if ((MAZEX < 0) or (MAZEX > 19) or
          (MAZEY < 0) or (MAZEY > 19) or
          (MAZELEV > SCNTOC.RECPERDK[ ZMAZE])) and (MAZELEV > 0) then
        begin ROCK; if _done then exit end
      else
        begin
          if MAZELEV < 0 then
            begin VOLCANO; if _done then exit end
          else if MAZELEV = 0 then
            if (MAZEX = 0) and (MAZEY = 0) then
              begin TOSHOPS; if _done then exit end
            else
              begin MOAT; if _done then exit end
        end;
      _done := true; exit
    end;  { TELEPORT }


  begin  { MALOR_PROC }
    CHARX := LLBASE04;
    Write( Chr( 12));
    WriteLn( 'PARTY TELEPORT:');
    WriteLn;
    WriteLn( 'ENTER NSEWU OR D TO  SET DISPLACEMENT,');
    WriteLn( 'THEN [RETURN] TO TELEPORT, OR [ESC] TO');
    WriteLn( 'CHICKEN OUT!');
    WriteLn;
    WriteLn( '# SQUARES EAST  =');
    WriteLn( '# SQUARES NORTH =');
    WriteLn( '# SQUARES DOWN  =');
    DELTAEW := 0;
    DELTANS := 0;
    DELTAUD := 0;
    repeat
      MVCURSOR( 18, 6); PRINTNUM( DELTAEW, 4);
      MVCURSOR( 18, 7); PRINTNUM( DELTANS, 4);
      MVCURSOR( 18, 8); PRINTNUM( DELTAUD, 4);
      MVCURSOR( 41, 0);
      GETKEY;
      if INCHAR = Chr( CRETURN) then
        begin TELEPORT; if _done then exit end
      else
        case INCHAR of
          'N': DELTANS := DELTANS + 1;
          'S': DELTANS := DELTANS - 1;
          'E': DELTAEW := DELTAEW + 1;
          'W': DELTAEW := DELTAEW - 1;
          'D': DELTAUD := DELTAUD + 1;
          'U': DELTAUD := DELTAUD - 1;
        end
    until INCHAR = Chr( 27);
    XGOTO := XBK2CMP2;
    LLBASE04 := CHARX;
    _done := true; exit
  end;  { MALOR_PROC }


  { ── NEWMAZE ──────────────────────────────────────────────────────────────── }

  procedure NEWMAZE;
  var
    MAZEMAP : TMAZE;
    UNUSED  : array[ 0..2] of SmallInt;


    { Helpers to access MAZEMAP pointer fields via Move() }
    function MZFGT( X, Y: SmallInt): Byte;
    var B: Byte;
    begin B := 0; Move( MAZEMAP.FIGHTS^[ X*20+Y], B, 1); MZFGT := B end;

    function MZNN( X, Y: SmallInt): Byte;
    var B: Byte;
    begin B := 0; Move( MAZEMAP.N^[ X*20+Y], B, 1); MZNN := B end;

    function MZEE( X, Y: SmallInt): Byte;
    var B: Byte;
    begin B := 0; Move( MAZEMAP.E^[ X*20+Y], B, 1); MZEE := B end;

    function MZSS( X, Y: SmallInt): Byte;
    var B: Byte;
    begin B := 0; Move( MAZEMAP.S^[ X*20+Y], B, 1); MZSS := B end;

    function MZWW( X, Y: SmallInt): Byte;
    var B: Byte;
    begin B := 0; Move( MAZEMAP.W^[ X*20+Y], B, 1); MZWW := B end;

    function MZSQR( X, Y: SmallInt): Byte;
    var B: Byte;
    begin B := 0; Move( MAZEMAP.SQREXTRA^[ X*20+Y], B, 1); MZSQR := B end;


    procedure FIGHTS;
    var
      FIGHTY  : SmallInt;
      FIGHTX  : SmallInt;
      Y       : SmallInt;
      X       : SmallInt;
      _ffail  : Boolean;


      procedure FINDSPOT;
      var X1, Y1 : SmallInt;
      begin
        X1 := Random( 20);
        Y1 := Random( 20);
        FIGHTX := X1;
        FIGHTY := Y1;
        repeat
          if MZFGT( FIGHTX, FIGHTY) = 1 then
            if not FIGHTMAP[ FIGHTX][ FIGHTY] then
              exit;  { EXIT(FINDSPOT) — found a spot }
          FIGHTX := FIGHTX + 1;
          if FIGHTX > 19 then
            begin
              FIGHTX := 0;
              FIGHTY := FIGHTY + 1;
              if FIGHTY > 19 then
                FIGHTY := 0
            end
        until (FIGHTX = X1) and (FIGHTY = Y1);
        _ffail := true; exit  { EXIT(FIGHTS) — no spot available }
      end;  { FINDSPOT }


      procedure FILLROOM( X, Y: SmallInt);
      begin
        X := (X + 20) mod 20;
        Y := (Y + 20) mod 20;
        if (MZFGT( X, Y) = 0) or FIGHTMAP[ X][ Y] then exit;
        FIGHTMAP[ X][ Y] := true;
        if MZNN( X, Y) = Byte( OPEN) then FILLROOM( X, Y + 1);
        if MZEE( X, Y) = Byte( OPEN) then FILLROOM( X + 1, Y);
        if MZSS( X, Y) = Byte( OPEN) then FILLROOM( X, Y - 1);
        if MZWW( X, Y) = Byte( OPEN) then FILLROOM( X - 1, Y)
      end;  { FILLROOM }


    begin  { FIGHTS }
      _ffail := false;
      FillChar( FIGHTMAP, SizeOf( FIGHTMAP), 0);
      for X := 1 to 9 do
        begin
          FINDSPOT;
          if _ffail then exit;
          FILLROOM( FIGHTX, FIGHTY)
        end;
      for X := 0 to 19 do
        for Y := 0 to 19 do
          if MAZEMAP.SQRETYPE[ MZSQR( X, Y)] = Byte( ENCOUNTE) then
            FILLROOM( X, Y)
    end;  { FIGHTS }


  begin  { NEWMAZE }
    if MAZELEV = 0 then
      begin
        Write( Chr( 12));
        XGOTO := XCHK4WIN;
        _done := true; exit
      end;
    if MAZELEV < 0 then
      begin
        MAZELEV := 1;
        XGOTO := XEQUIP6
      end
    else
      XGOTO := XRUNNER;
    LOADTMAZE( MAZELEV - 1, MAZEMAP);
    FIGHTS;
    CLRRECT( 1, 11, 38, 4);
    _done := true; exit
  end;  { NEWMAZE }


  { ── EQUIPCHR (from UTILITIE2) ────────────────────────────────────────────── }

  procedure EQUIPCHR( LCHARI: SmallInt);
  var
    UNARMED  : Boolean;
    CANUSE   : array[ 0..6] of Boolean;   { indexed by Byte(TOBJTYPE) }
    UNUSED   : Boolean;
    TEMPX    : SmallInt;
    POSSI    : SmallInt;
    POSSCNT  : SmallInt;
    LUCKI    : SmallInt;
    OBJI     : TOBJTYPE;
    OBJI_I   : SmallInt;                   { integer runner for enum loop }
    OBJ      : TOBJREC;
    OBJLIST  : array[ 0..8] of SmallInt;   { [0] unused; AP: ARRAY[1..8] }
    TC       : ^TCHAR;
    PP       : ^TPOSSESS;


    procedure CHSPCPOW;


      procedure SPCPOWER;
      var
        SPCTEMP : SmallInt;
        GOLD50K : TWIZLONG;
        SPCX    : SmallInt;


        procedure SPC1TO12( ATTR2MOD: SmallInt; MODAMT: SmallInt);
        var ATTRX : TATTRIB;
        begin
          ATTRX := STRENGTH;
          while ATTR2MOD > 1 do
            begin
              ATTRX := TATTRIB( Byte( ATTRX) + 1);
              ATTR2MOD := ATTR2MOD - 1
            end;
          SPCTEMP := TC.ATTRIB[ ATTRX] + MODAMT;
          if (SPCTEMP > 2) and (SPCTEMP < 19) then
            TC.ATTRIB[ ATTRX] := SPCTEMP
        end;


      begin  { SPCPOWER }
        FillChar( GOLD50K, SizeOf( GOLD50K), 0);
        GOLD50K.XMID := 5;
        Write( Chr( 12));
        WriteLn( 'WILL YOU INVOKE THE SPECIAL POWER OF');
        Write( 'YOUR ');
        PP := TC.POSS.POSSESS[ POSSI];
        if PP.IDENTIF then
          Write( OBJ.NAME)
        else
          Write( OBJ.NAMEUNK);
        Write( ' (Y/N) ? >');
        repeat
          GETKEY
        until (INCHAR = 'Y') or (INCHAR = 'N');
        if INCHAR = 'N' then exit;
        if (Random( 100)) < OBJ.CHGCHANC then
          begin
            PP := TC.POSS.POSSESS[ POSSI];
            PP.EQINDEX := OBJ.CHANGETO
          end;
        if OBJ.SPECIAL < 7 then
          SPC1TO12( OBJ.SPECIAL, 1)
        else
          begin
            if OBJ.SPECIAL < 13 then
              SPC1TO12( OBJ.SPECIAL - 6, -1)
            else
              begin
                SPCX := OBJ.SPECIAL;
                case Byte( SPCX) of
                  13: if TC.AGE > 1040 then TC.AGE := TC.AGE - 52;
                  14: TC.AGE := TC.AGE + 52;
                  15: SETXCLS( TC, SAMURAI);
                  16: SETXCLS( TC, LORD);
                  17: SETXCLS( TC, NINJA);
                  18: ADDLONGS( TC.GOLD, GOLD50K);
                  19: ADDLONGS( TC.EXP, GOLD50K);
                  20: SETSTAT( TC, LOST);
                  21: begin
                        SETSTAT( TC, OK);
                        TC.HPLEFT := TC.HPMAX;
                        TC.LOSTXYL[ 1] := 0
                      end;
                  22: TC.HPMAX := TC.HPMAX + 1;
                  23: begin
                        for SPCTEMP := 0 to PARTYCNT - 1 do
                          begin
                            TC := CHARACTR[ SPCTEMP];
                            TC.HPLEFT := TC.HPMAX
                          end;
                        TC := CHARACTR[ LCHARI]   { restore }
                      end;
                end
              end
          end
      end;  { SPCPOWER }


    begin  { CHSPCPOW }
      TC := CHARACTR[ LCHARI];
      for POSSI := 1 to TC.POSS.POSSCNT do
        begin
          PP := TC.POSS.POSSESS[ POSSI];
          if PP.EQINDEX > 0 then
            begin
              LOADOBJREC( PP.EQINDEX, OBJ);
              if OBJ.SPECIAL > 0 then
                SPCPOWER
            end
        end
    end;  { CHSPCPOW }


    procedure NORMPOW;
    var
      TEMPX : SmallInt;
      TEMPY : SmallInt;
      POSSX : SmallInt;
    begin
      TC := CHARACTR[ LCHARI];
      FillChar( CANUSE, SizeOf( CANUSE), 0);
      for POSSX := 1 to TC.POSS.POSSCNT do
        begin
          PP := TC.POSS.POSSESS[ POSSX];
          LOADOBJREC( PP.EQINDEX, OBJ);
          if OBJ.CLASSUSE[ TC.XCLASS] then
            CANUSE[ Byte( OBJ.OBJTYPE)] := true;
          if TC.HEALPTS < OBJ.HEALPTS then
            TC.HEALPTS := OBJ.HEALPTS;
          for TEMPX := 0 to 13 do
            TC.WEPVSTY2[ 0][ TEMPX] :=
              TC.WEPVSTY2[ 0][ TEMPX] or OBJ.WEPVSTY2[ TEMPX];
          for TEMPY := 0 to 6 do
            TC.WEPVSTY3[ 0][ TEMPY] :=
              TC.WEPVSTY3[ 0][ TEMPY] or OBJ.WEPVSTY3[ TEMPY]
        end
    end;  { NORMPOW }


    procedure ARMORPOW( ACHARX: SmallInt; APOSSX: SmallInt; OBJID: SmallInt);
    var
      ATC : ^TCHAR;
      APP : ^TPOSSESS;
    begin
      UNARMED := false;
      LOADOBJREC( OBJID, OBJ);
      ATC := CHARACTR[ ACHARX];
      APP := ATC.POSS.POSSESS[ APOSSX];
      APP.CURSED := OBJ.CURSED;
      if (OBJ.ALIGN = UNALIGN) or
         (Byte( OBJ.ALIGN) = Byte( ATC.ALIGN)) then
        begin
          if OBJ.XTRASWNG > ATC.SWINGCNT then
            ATC.SWINGCNT := OBJ.XTRASWNG;
          ATC.ARMORCL  := ATC.ARMORCL - OBJ.ARMORMOD;
          ATC.HPCALCMD := ATC.HPCALCMD + OBJ.WEPHITMD;
          if OBJ.OBJTYPE = WEAPON then
            begin
              LLBASE04 := ATC.HPDAMRC.HPMINAD;
              ATC.HPDAMRC := OBJ.WEPHPDAM;
              ATC.HPDAMRC.HPMINAD := ATC.HPDAMRC.HPMINAD + LLBASE04;
              ATC.CRITHITM := ATC.CRITHITM or OBJ.CRITHITM;
              ATC.WEPVSTYP := OBJ.WEPVSTYP
            end
        end
      else
        begin
          ATC.HPCALCMD := ATC.HPCALCMD - 1;
          ATC.ARMORCL  := ATC.ARMORCL + 1;
          ATC.CRITHITM := false;
          APP.CURSED   := true
        end
    end;  { ARMORPOW }


    procedure ARM4CHAR;
    var POSSX : SmallInt;
    begin
      TC := CHARACTR[ LCHARI];
      for POSSX := 1 to TC.POSS.POSSCNT do
        begin
          PP := TC.POSS.POSSESS[ POSSX];
          if PP.EQUIPED then
            ARMORPOW( LCHARI, POSSX, PP.EQINDEX)
        end
    end;  { ARM4CHAR }


    procedure DOEQUIP;


      procedure EQUIPONE;
      begin
        repeat
          MVCURSOR( 0, 15);
          Write( Chr( 11));
          Write( 'WHICH ONE ([RET] FOR NONE) ? >');
          GETKEY;
          if INCHAR = Chr( CRETURN) then exit;
          POSSI := Byte( INCHAR) - Byte( '0')
        until (POSSI > 0) and (POSSI <= POSSCNT);
        TC := CHARACTR[ LCHARI];
        PP := TC.POSS.POSSESS[ OBJLIST[ POSSI]];
        PP.EQUIPED := true;
        ARMORPOW( LCHARI, OBJLIST[ POSSI], PP.EQINDEX)
      end;  { EQUIPONE }


      procedure CURSBELL( CURSSTR: string);
      var X : SmallInt;
      begin
        for X := 1 to Length( CURSSTR) do
          begin
            Write( CURSSTR[ X]);
            Write( Chr( 7));
            Write( Chr( 7))
          end
      end;


    begin  { DOEQUIP }
      if not CANUSE[ Byte( OBJI)] then exit;
      Write( Chr( 12));
      Write( 'SELECT ');
      case Byte( OBJI) of
        0 { WEAPON   }: Write( 'WEAPON');
        1 { ARMOR    }: Write( 'ARMOR');
        2 { SHIELD   }: Write( 'SHIELD');
        3 { HELMET   }: Write( 'HELMET');
        4 { GAUNTLET }: Write( 'GAUNTLETS');
        6 { MISC     }: Write( 'MISC. ITEM');
      end;
      Write( ' FOR ');
      TC := CHARACTR[ LCHARI];
      WriteLn( TC.NAME);
      WriteLn;
      WriteLn;
      POSSCNT := 0;
      for POSSI := 1 to TC.POSS.POSSCNT do
        begin
          PP := TC.POSS.POSSESS[ POSSI];
          if PP.EQINDEX > 0 then
            begin
              LOADOBJREC( PP.EQINDEX, OBJ);
              if (OBJ.OBJTYPE = OBJI) and
                 OBJ.CLASSUSE[ TC.XCLASS] then
                begin
                  POSSCNT := POSSCNT + 1;
                  OBJLIST[ POSSCNT] := POSSI;
                  Write( '          ');
                  PRINTNUM( POSSCNT, 1);
                  Write( ')');
                  if PP.CURSED then
                    Write( '-')
                  else if PP.IDENTIF then
                    Write( ' ')
                  else
                    Write( '?');
                  if PP.IDENTIF then
                    WriteLn( OBJ.NAME)
                  else
                    WriteLn( OBJ.NAMEUNK)
                end
            end
        end;
      TEMPX := 0;
      for POSSI := 1 to POSSCNT do
        begin
          PP := TC.POSS.POSSESS[ OBJLIST[ POSSI]];
          if PP.CURSED then TEMPX := POSSI
        end;
      if TEMPX = 0 then EQUIPONE;
      TEMPX := 0;
      for POSSI := 1 to POSSCNT do
        begin
          PP := TC.POSS.POSSESS[ OBJLIST[ POSSI]];
          if PP.CURSED then TEMPX := POSSI
        end;
      if TEMPX > 0 then
        begin
          MVCURSOR( 7, 23);
          CURSBELL( '** CURSED **');
          PP := TC.POSS.POSSESS[ OBJLIST[ TEMPX]];
          PP.EQUIPED := true;
          ARMORPOW( LCHARI, OBJLIST[ TEMPX], PP.EQINDEX)
        end
    end;  { DOEQUIP }


    procedure UPLCKSKL( LSSUB: SmallInt; LSMODAMT: SmallInt);
    begin
      TC := CHARACTR[ LCHARI];
      LSMODAMT := TC.LUCKSKIL[ LSSUB] - LSMODAMT;
      if LSMODAMT < 1 then LSMODAMT := 1;
      TC.LUCKSKIL[ LSSUB] := LSMODAMT
    end;


    procedure INITSTUF;
    var X, Y : SmallInt;
    begin
      TC := CHARACTR[ LCHARI];
      for X := 0 to 13 do
        begin
          TC.WEPVSTY2[ 0][ X] := false;
          TC.WEPVSTY2[ 1][ X] := false;
          TC.WEPVSTYP[ X]     := false
        end;
      for Y := 0 to 6 do
        begin
          TC.WEPVSTY3[ 0][ Y] := false;
          TC.WEPVSTY3[ 1][ Y] := false
        end
    end;


  begin  { EQUIPCHR }
    TC := CHARACTR[ LCHARI];
    TEMPX := (20 - TC.CHARLEV div 5) - (TC.ATTRIB[ LUCK] div 6);
    if TEMPX < 1 then TEMPX := 1;
    for LUCKI := 0 to 4 do
      TC.LUCKSKIL[ LUCKI] := TEMPX;
    case TC.XCLASS of
      FIGHTER: UPLCKSKL( 0, 3);
      MAGE:    UPLCKSKL( 4, 3);
      PRIEST:  UPLCKSKL( 1, 3);
      THIEF:   UPLCKSKL( 3, 3);
      BISHOP:  begin UPLCKSKL( 2, 2); UPLCKSKL( 4, 2); UPLCKSKL( 1, 2) end;
      SAMURAI: begin UPLCKSKL( 0, 2); UPLCKSKL( 4, 2) end;
      LORD:    begin UPLCKSKL( 0, 2); UPLCKSKL( 1, 2) end;
      NINJA:   begin
                 UPLCKSKL( 0, 3); UPLCKSKL( 1, 2);
                 UPLCKSKL( 2, 4); UPLCKSKL( 3, 3); UPLCKSKL( 4, 2)
               end;
    end;
    case TC.RACE of
      HUMAN:  UPLCKSKL( 0, 1);
      ELF:    UPLCKSKL( 2, 2);
      DWARF:  UPLCKSKL( 3, 4);
      GNOME:  UPLCKSKL( 1, 2);
      HOBBIT: UPLCKSKL( 4, 3);
    end;
    if not EQUIPALL then
      for TEMPX := 1 to 8 do
        begin
          PP := TC.POSS.POSSESS[ TEMPX];
          PP.EQUIPED := false
        end;
    if (TC.XCLASS = PRIEST) or
       (TC.XCLASS = FIGHTER) or
       (Byte( TC.XCLASS) >= Byte( SAMURAI)) then
      TC.HPCALCMD := 2 + TC.CHARLEV div 3
    else
      TC.HPCALCMD := TC.CHARLEV div 5;
    TC.HPDAMRC.LEVEL   := 2;
    TC.HPDAMRC.HPFAC   := 2;
    TC.HPDAMRC.HPMINAD := 0;
    if TC.ATTRIB[ STRENGTH] > 15 then
      begin
        TC.HPCALCMD        := TC.HPCALCMD + TC.ATTRIB[ STRENGTH] - 15;
        TC.HPDAMRC.HPMINAD := TC.ATTRIB[ STRENGTH] - 15
      end
    else
      if TC.ATTRIB[ STRENGTH] < 6 then
        TC.HPCALCMD := TC.HPCALCMD + TC.ATTRIB[ STRENGTH] - 6;
    TC.HEALPTS  := 0;
    TC.CRITHITM := TC.XCLASS = NINJA;
    TC.SWINGCNT := 1;
    if TC.XCLASS = NINJA then
      TC.HPDAMRC.HPFAC := 4;
    TC.ARMORCL := 10;
    if (TC.XCLASS = FIGHTER) or (Byte( TC.XCLASS) >= Byte( SAMURAI)) then
      TC.SWINGCNT := TC.SWINGCNT + (TC.CHARLEV div 5) +
                     SmallInt( TC.XCLASS = NINJA);
    if TC.SWINGCNT > 10 then TC.SWINGCNT := 10;
    INITSTUF;
    NORMPOW;
    UNARMED := true;
    if not EQUIPALL then
      begin
        for OBJI_I := Byte( WEAPON) to Byte( GAUNTLET) do
          begin OBJI := TOBJTYPE( OBJI_I); DOEQUIP end;
        OBJI := MISC;
        DOEQUIP;
        CHSPCPOW
      end
    else
      ARM4CHAR;
    TC := CHARACTR[ LCHARI];
    if TC.XCLASS = NINJA then
      if UNARMED then
        TC.ARMORCL := (TC.ARMORCL - (TC.CHARLEV div 3)) - 2
  end;  { EQUIPCHR }


  { ── EQUIP6 ───────────────────────────────────────────────────────────────── }

  procedure EQUIP6;
  var PARTYX : SmallInt;
  begin
    EQUIPALL := true;
    for PARTYX := 0 to PARTYCNT - 1 do
      EQUIPCHR( PARTYX);
    if XGOTO = XEQUIP6 then
      XGOTO := XINSPCT2
    else
      begin
        XGOTO := XRUNNER;
        GRAPHICS
      end
  end;  { EQUIP6 }


  { ── EQUIP1 ───────────────────────────────────────────────────────────────── }

  procedure EQUIP1( ACHARX: SmallInt);
  begin
    EQUIPALL := false;
    EQUIPCHR( ACHARX);
    XGOTO    := XBCK2CMP;
    LLBASE04 := ACHARX
  end;  { EQUIP1 }


  { ── REORDER ──────────────────────────────────────────────────────────────── }

  procedure REORDER;
  var
    SWITCH   : SmallInt;
    PARTYNUM : SmallInt;
    PARTYX   : SmallInt;
    CHARREC  : ^TCHAR;
    DONE     : Boolean;
    LIST     : array[ 0..5] of SmallInt;
    TC       : ^TCHAR;
  begin
    XGOTO := XINSPCT2;
    if PARTYCNT < 2 then exit;
    MVCURSOR( 0, 11);
    Write( Chr( 11));
    Write( '               REORDERING');
    for PARTYX := 0 to PARTYCNT - 1 do
      begin
        LIST[ PARTYX] := 99;
        MVCURSOR( 0, 13 + PARTYX);
        PRINTNUM( PARTYX + 1, 1);
        Write( ')')
      end;
    for PARTYX := 0 to PARTYCNT - 2 do
      begin
        repeat
          DONE := false;
          MVCURSOR( 1, 13 + PARTYX);
          Write( '   ');
          MVCURSOR( 1, 13 + PARTYX);
          Write( '>>');
          GETKEY;
          PARTYNUM := Byte( INCHAR) - Byte( '1');
          if (PARTYNUM >= 0) and (PARTYNUM < PARTYCNT) then
            if LIST[ PARTYNUM] = 99 then
              begin
                LIST[ PARTYNUM] := PARTYX;
                DONE := true
              end
        until DONE;
        MVCURSOR( 1, 13 + PARTYX);
        Write( ') ');
        TC := CHARACTR[ PARTYNUM];
        Write( TC.NAME)
      end;
    for PARTYX := 0 to PARTYCNT - 2 do
      for PARTYNUM := PARTYX + 1 to PARTYCNT - 1 do
        if LIST[ PARTYNUM] < LIST[ PARTYX] then
          begin
            CHARREC             := CHARACTR[ PARTYX];
            CHARACTR[ PARTYX]   := CHARACTR[ PARTYNUM];
            CHARACTR[ PARTYNUM] := CHARREC;
            SWITCH               := CHARDISK[ PARTYX];
            CHARDISK[ PARTYX]   := CHARDISK[ PARTYNUM];
            CHARDISK[ PARTYNUM] := SWITCH;
            SWITCH               := LIST[ PARTYX];
            LIST[ PARTYX]        := LIST[ PARTYNUM];
            LIST[ PARTYNUM]      := SWITCH
          end;
    MVCURSOR( 1, 13 + PARTYCNT - 1);
    Write( ') ');
    TC := CHARACTR[ PARTYCNT - 1];
    Write( TC.NAME)
  end;  { REORDER }


  { ── UTILITIE main body ───────────────────────────────────────────────────── }

begin
  _done := false;
  if XGOTO <> XNEWMAZE then TEXTMODE;
  case XGOTO of
    XCAMPSTF:
      { CAMP sets XGOTO2 to indicate which sub-function to perform.
        AP: CASE BASE12.GOTOX OF ... (BASE12.GOTOX mapped to XGOTO2) }
      case XGOTO2 of
        XDONE:    RDSPELLS;
        XTRAININ: IDITEM;
        XCASTLE:  KANDIFND;
        XGILGAMS: DUMAPIC;
        XINSPECT: MALOR_PROC;
      end;
    XNEWMAZE:   NEWMAZE;
    XEQUIP6,
    XCMP2EQ6:   EQUIP6;
    XREORDER:   REORDER;
    XEQPDSP:
      if LLBASE04 >= 0 then
        EQUIP1( LLBASE04)
      else
        begin
          for CHARI := 0 to PARTYCNT - 1 do
            EQUIP1( CHARI);
          XGOTO := XINSPCT2
        end;
  end
end;  { UTILITIE }


end.
