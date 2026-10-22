unit CUTILUNIT;

{ Wizardry I — COMBAT's CUTIL segment (AP P0106xx) without CACTION, an
  overlay of its own (CACTION, the party's choices, is cactunit.pas: CUTIL
  is too big for one overlay).  Source: apple/Wizardry_v3-2/Wiz1B.DSK/COMBAT2
  + COMBAT3 (v3.2).  Shares COMBAT's variables through COMBATG; run by the
  resident combat loop, which runs CACTION after it unless DONEFIGH. }

interface

uses TYPES, CONSTS, GLOBALS, UTIL, SCREEN, COMBATG;

procedure CUTIL;

implementation

function BSET_CB( B: Byte): Boolean;
begin
  if B <> 0 then BSET_CB := true else BSET_CB := false
end;

procedure SETSTATUS_CB( TC: PTCHAR; V: TSTATUS);
begin
  TC^.STATUS := TSTATUS( Byte( V))
end;

procedure SETXSTATUS_CB( PT: PTTEMP04; V: TSTATUS);
begin
  PT^.XSTATUS := TSTATUS( Byte( V))
end;

procedure SETALIGN_CB( TC: PTCHAR; V: TALIGN);
begin
  TC^.ALIGN := TALIGN( Byte( V))
end;


procedure CUTIL;


  { ── HEAL ── }

  procedure HEAL;
  var
    MVUPLIVE : SmallInt;
    T1       : SmallInt;
    T2       : SmallInt;
    PT04     : ^TTEMP04;
    PT04B    : ^TTEMP04;
    TC       : PTCHAR;
    ENEMYRC  : ^TENEMY2;
    HBRC     : ^TENEMY2;
    HBRA     : ^TENEMY2A;
    HBTB     : ^TENEMY;
    HBR0     : ^TENEMY2;
    HBRA0    : ^TENEMY2A;


    procedure TRYHEAL( HEALCHAN: SmallInt);
    var
      TBRC : ^TENEMY2;
      TBRA : ^TENEMY2A;
    begin
      if HEALCHAN > 50 then
        HEALCHAN := 50;
      if (RNDN(100)) <= HEALCHAN then
        begin
          TBRC := BATTLERC[ T2];
          TBRA := TBRC^.A;
          PT04 := TBRA.TEMP04[ T1];
          SETXSTATUS_CB( PT04, OK)
        end
    end;


    procedure HEALENMY;
    var
      TBRC1 : ^TENEMY2;
      TBRA1 : ^TENEMY2A;
    begin
      for T2 := 1 to 4 do
        begin
          HBRC := BATTLERC[ T2];
          HBRA := HBRC^.A;
          HBTB := HBRC^.B;
          if HBRA.ALIVECNT > 0 then
            begin
              T1       := 0;
              MVUPLIVE := 0;
              while MVUPLIVE < HBRA.ALIVECNT do
                begin
                  HBRA.TEMP04[ T1] := HBRA.TEMP04[ MVUPLIVE];
                  MVUPLIVE := MVUPLIVE + 1;
                  PT04 := HBRA.TEMP04[ T1];
                  if Ord( PT04^.XSTATUS) < Ord( DEAD) then
                    begin
                      case Byte( PT04^.XSTATUS) of
                        Byte( AFRAID): TRYHEAL( 10 * HBTB.HPREC.LEVEL);
                        Byte( ASLEEP): TRYHEAL( 20 * HBTB.HPREC.LEVEL);
                        Byte( PLYZE):  TRYHEAL(  7 * HBTB.HPREC.LEVEL);
                      end;
                      PT04 := HBRA.TEMP04[ T1];
                      PT04.HPLEFT := PT04.HPLEFT + HBTB.HEALPTS;
                      T1 := T1 + 1
                    end
                end;
              HBRA.ALIVECNT := T1
            end
        end;
      for T1 := 1 to 3 do
        for T2 := T1 + 1 to 4 do
          begin
            TBRC1 := BATTLERC[ T1];
            TBRA1 := TBRC1^.A;
            if TBRA1.ALIVECNT = 0 then
              begin
                TBRC1 := BATTLERC[ T2];
                TBRA1 := TBRC1^.A;
                if TBRA1.ALIVECNT > 0 then
                  begin
                    ENEMYRC       := BATTLERC[ T1];
                    BATTLERC[ T1] := BATTLERC[ T2];
                    BATTLERC[ T2] := ENEMYRC
                  end
              end
          end;
      T2 := 0;
      for T1 := 1 to 4 do
        begin
          HBRC := BATTLERC[ T1];
          HBRA := HBRC^.A;
          if HBRA.ALIVECNT > 0 then
            T2 := T1
        end;
      DONEFIGH := BSET_CB( T2 = 0)
    end;


    procedure HEALPRTY;
    begin
      HBR0  := BATTLERC[ 0];
      HBRA0 := HBR0^.A;
      T2 := 0;
      for T1 := 0 to PARTYCNT - 1 do
        begin
          PT04 := HBRA0.TEMP04[ T1];
          TC   := CHARACTR[ T1];
          if Ord( PT04^.XSTATUS) < Ord( DEAD) then
            begin
              if (RNDN(4)) = 2 then
                PT04.HPLEFT := PT04.HPLEFT + TC.HEALPTS - TC.LOSTXYL[ 1];
              if PT04.HPLEFT > TC.HPMAX then
                PT04.HPLEFT := TC.HPMAX;
              if PT04.HPLEFT <= 0 then
                begin
                  SETXSTATUS_CB( PT04, DEAD);
                  PT04.HPLEFT  := 0;
                  MVCURSOR( 1, 12);
                  PRINTSTR( TC.NAME);
                  PRINTSTR( ' JUST DIED!');
                  PAUSE2;
                  CLRRECT( 1, 12, 38, 1)
                end;
              case Byte( PT04^.XSTATUS) of
                Byte( ASLEEP): TRYHEAL( 10 * TC.CHARLEV);
                Byte( AFRAID): TRYHEAL(  5 * TC.CHARLEV);
              end
            end
        end;
      for T1 := 0 to PARTYCNT - 1 do
        begin
          PT04 := HBRA0.TEMP04[ T1];
          TC   := CHARACTR[ T1];
          TC.HPLEFT  := PT04.HPLEFT;
          TC.STATUS  := TSTATUS( Byte( PT04^.XSTATUS))
        end
    end;


    procedure HEALHEAR;
    var
      X    : SmallInt;
      DBRC : ^TENEMY2;
      DBRA : ^TENEMY2A;

      procedure DECINAUD( GROUPI: SmallInt; ALIVECNT: SmallInt);
      begin
        DBRC := BATTLERC[ GROUPI];
        DBRA := DBRC^.A;
        for X := 0 to ALIVECNT - 1 do
          begin
            PT04 := DBRA.TEMP04[ X];                    { v3.2 WC009: [ X] }
            if PT04.INAUDCNT > 0 then
              PT04.INAUDCNT := PT04.INAUDCNT - 1
          end
      end;

    begin  { HEALHEAR }
      DECINAUD( 0, PARTYCNT);
      DBRC := BATTLERC[ 1]; DBRA := DBRC^.A; DECINAUD( 1, DBRA.ALIVECNT);
      DBRC := BATTLERC[ 2]; DBRA := DBRC^.A; DECINAUD( 2, DBRA.ALIVECNT);
      DBRC := BATTLERC[ 3]; DBRA := DBRC^.A; DECINAUD( 3, DBRA.ALIVECNT);
      DBRC := BATTLERC[ 4]; DBRA := DBRC^.A; DECINAUD( 4, DBRA.ALIVECNT)  { v3.2 WC009 }
    end;


  begin  { HEAL }
    HEALENMY;
    HEALPRTY;
    HEALHEAR
  end;  { HEAL }


  { ── DSPPARTY ── }

  function DSPPARTY: Byte;                       { UNWNONE or U_COMBAT }
  var
    TEMPXYZ  : SmallInt;
    PARTYI   : SmallInt;
    STATUSOK : Boolean;
    TC       : PTCHAR;
    TC2      : PTCHAR;
    PT04     : ^TTEMP04;
    PT04B    : ^TTEMP04;
    PT04C    : ^TTEMP04;
    TEMPPTR  : PTCHAR;
    TEMPBOOL : Boolean;
    DBRC0    : ^TENEMY2;
    DBRA0    : ^TENEMY2A;
    DBRC_R   : ^TENEMY2;
    DBRA_R   : ^TENEMY2A;


    procedure PRSTATUS;
    begin
      TC := CHARACTR[ PARTYI];
      STATUSOK := STATUSOK or BSET_CB( Ord( TC^.STATUS) < Ord( DEAD));
      if Byte( TC^.STATUS) = 0 then  { OK=0 }
        begin
          PT04C := DBRA0.TEMP04[ PARTYI];
          if PT04C.INAUDCNT > 0 then                    { v3.2 WC044 }
            PRINTSTR( 'SILENC')
          else if TC.LOSTXYL[ 1] > 0 then
            PRINTSTR( 'POISON')
          else
            PRINTNUM( TC.HPMAX, 4)
        end
      else
        PRINTSTR( STATNAME( Ord( TC^.STATUS)))
    end;


    procedure SWAP2CHR( X: SmallInt; Y: SmallInt);
    var
      TEMPSI : SmallInt;
    begin
      { swap PTCHAR pointers }
      TEMPPTR      := CHARACTR[ X];
      CHARACTR[ X] := CHARACTR[ Y];
      CHARACTR[ Y] := TEMPPTR;
      { swap CHARDISK slots }
      TEMPSI       := CHARDISK[ X];
      CHARDISK[ X] := CHARDISK[ Y];
      CHARDISK[ Y] := TEMPSI;
      { swap DRAINED flags }
      TEMPBOOL    := DRAINED[ X];
      DRAINED[ X] := DRAINED[ Y];
      DRAINED[ Y] := TEMPBOOL;
      { swap BATTLERC[0] TEMP04 pointers using slot 6 as temp }
      DBRA0.TEMP04[ 6] := DBRA0.TEMP04[ X];
      DBRA0.TEMP04[ X] := DBRA0.TEMP04[ Y];
      DBRA0.TEMP04[ Y] := DBRA0.TEMP04[ 6]
    end;


  begin  { DSPPARTY }
    Result := UNWNONE;
    DBRC0 := BATTLERC[ 0];
    DBRA0 := DBRC0^.A;
    for PARTYI := 0 to PARTYCNT - 2 do
      for TEMPXYZ := PARTYI + 1 to PARTYCNT - 1 do
        if PREBATOR[ PARTYI] = CHARDISK[ TEMPXYZ] then
          SWAP2CHR( PARTYI, TEMPXYZ);
    for PARTYI := 0 to PARTYCNT - 2 do
      for TEMPXYZ := PARTYI + 1 to PARTYCNT - 1 do
        if Ord( CHARACTR[ PARTYI].STATUS) > Ord( CHARACTR[ TEMPXYZ].STATUS) then
          SWAP2CHR( PARTYI, TEMPXYZ);
    MYSTRENG := 0;
    DBRA0.ALIVECNT := 0;
    for PARTYI := 0 to PARTYCNT - 1 do
      begin
        TC := CHARACTR[ PARTYI];
        if Byte( TC^.STATUS) = 0 then  { OK=0 }
          MYSTRENG := MYSTRENG + TC.CHARLEV;
        if Ord( TC^.STATUS) < Ord( DEAD) then
          DBRA0.ALIVECNT := DBRA0.ALIVECNT + 1
      end;
    CLRRECT( 1, 17, 38, 6);
    STATUSOK := false;
    for PARTYI := 0 to PARTYCNT - 1 do
      begin
        TC   := CHARACTR[ PARTYI];
        PT04 := DBRA0.TEMP04[ PARTYI];
        if (RNDN(99)) < (TC.ATTRIB[ Ord( IQ)] +
                              TC.ATTRIB[ Ord( PIETY)] +
                              TC.CHARLEV) then
          begin
            DBRC_R := BATTLERC[ RNDN( 4) + 1];
            DBRA_R := DBRC_R^.A;
            DBRA_R.IDENTIFI := true
          end;
        MVCURSOR( 1, 17 + PARTYI);
        PRINTNUM( PARTYI + 1, 1);
        PRINTSTR( ' ');
        PRINTSTR( TC.NAME);
        MVCURSOR( 19, 17 + PARTYI);
        PRINTSTR( LEFTSTR( ALIGNNAME( Ord( TC^.ALIGN)), 1));
        PRINTCHR( '-');
        PRINTSTR( LEFTSTR( CLASSNAME( Ord( TC^.XCLASS)), 3));
        LLBASE04 := TC.ARMORCL - ACMOD2 - PT04.ARMORCL;
        if LLBASE04 >= 0 then
          PRINTNUM( LLBASE04, 3)
        else
          if LLBASE04 > -10 then
            begin
              PRINTSTR( ' -');
              PRINTNUM( Abs( LLBASE04), 1)
            end
          else
            PRINTSTR( ' LO');
        PRINTNUM( TC.HPLEFT, 5);
        TEMPXYZ := TC.HEALPTS - TC.LOSTXYL[ 1];
        if TEMPXYZ = 0 then
          PRINTCHR( ' ')
        else if TEMPXYZ < 0 then
          PRINTCHR( '-')
        else
          PRINTCHR( '+');
        PRSTATUS
      end;
    if not STATUSOK then
      Result := U_COMBAT                                { EXIT( COMBAT) }
  end;  { DSPPARTY }


  { ── DSPENEMY ── }

  procedure DSPENEMY;
  var
    ENMYGROK : SmallInt;
    ENMYGRI  : SmallInt;
    ENMYIND  : SmallInt;
    PT04     : ^TTEMP04;
    DEBRC    : ^TENEMY2;
    DEBRA    : ^TENEMY2A;
    DEBTB    : ^TENEMY;
  begin
    ENSTRENG := 0;
    for ENMYGRI := 1 to 4 do
      begin
        CLRRECT( 13, ENMYGRI, 26, 1);
        DEBRC := BATTLERC[ ENMYGRI];
        DEBRA := DEBRC^.A;
        DEBTB := DEBRC^.B;
        if DEBRA.ALIVECNT > 0 then
          begin
            ENMYGROK := 0;
            for ENMYIND := 0 to DEBRA.ALIVECNT - 1 do
              begin
                PT04 := DEBRA.TEMP04[ ENMYIND];
                if Byte( PT04^.XSTATUS) = 0 then  { OK=0 }
                  ENMYGROK := ENMYGROK + 1
              end;
            ENSTRENG := ENSTRENG +
                        ENMYGROK * DEBTB.HPREC.LEVEL;
            MVCURSOR( 13, ENMYGRI);
            PRINTNUM( ENMYGRI, 1);
            PRINTSTR( ') ');
            PRINTNUM( DEBRA.ALIVECNT, 1);
            PRINTSTR( ' ');
            if DEBRA.IDENTIFI then
              if DEBRA.ALIVECNT > 1 then
                PRINTSTR( DEBTB.NAMES)
              else
                PRINTSTR( DEBTB.NAME)
            else
              if DEBRA.ALIVECNT > 1 then
                PRINTSTR( DEBTB.NAMEUNKS)
              else
                PRINTSTR( DEBTB.NAMEUNK);
            PRINTSTR( ' (');
            PRINTNUM( ENMYGROK, 1);
            PRINTCHR( ')')
          end
      end
  end;  { DSPENEMY }


  { ── ENATTACK ── }

  procedure ENATTACK;
  var
    ATTCKTYP : SmallInt;
    CHARX    : SmallInt;
    ENEMYX   : SmallInt;
    GROUPI   : SmallInt;
    PT04     : ^TTEMP04;
    TC       : PTCHAR;
    EABRC    : ^TENEMY2;
    EABRA    : ^TENEMY2A;
    EABTB    : ^TENEMY;
    EABRC0   : ^TENEMY2;
    EABRA0   : ^TENEMY2A;


    function CANATTCK: Boolean;
    begin
      TC := CHARACTR[ CHARX];
      CANATTCK := (not TC.WEPVSTY2[ 1, Byte( EABTB.XCLASS)]) or
                  BSET_CB( (RNDN(100)) < 50)
    end;


    procedure ENEMYSPL;

      procedure SPELLEZR( var SPELLGR: SmallInt);
      begin
        if RNDN( EABRA.ALIVECNT + 2) = 0 then
          SPELLGR := SPELLGR - 1
      end;

      procedure GETMAGSP( SPELLLEV: SmallInt);
      var
        SPELLCAS : SmallInt;
        TWOTHIRD : Boolean;
      begin
        while (SPELLLEV > 1) and ((RNDN(100)) > 70) do
          SPELLLEV := SPELLLEV - 1;
        TWOTHIRD := BSET_CB( (RNDN(100)) > 33);
        SPELLEZR( EABTB^.MAGSPELS);
        case Byte( SPELLLEV) of
          1: if TWOTHIRD then SPELLCAS := KATINO  else SPELLCAS := HALITO;
          2: if TWOTHIRD then SPELLCAS := DILTO   else SPELLCAS := HALITO;
          3: if TWOTHIRD then SPELLCAS := MOLITO  else SPELLCAS := MAHALITO;
          4: if TWOTHIRD then SPELLCAS := DALTO   else SPELLCAS := LAHALITO;
          5: if TWOTHIRD then SPELLCAS := LAHALITO else SPELLCAS := MADALTO;
          6: SPELLCAS := MADALTO;                        { v3.2 WC021: not ZILWAN }
          7: SPELLCAS := TILTOWAI;
        end;
        ATTCKTYP := SPELLCAS
      end;

      procedure GETPRISP( SPELLLEV: SmallInt);
      var
        SPELLCAS : SmallInt;
        TWOTHIRD : Boolean;
      begin
        TWOTHIRD := BSET_CB( (RNDN(100)) > 33);
        SPELLEZR( EABTB^.PRISPELS);
        case Byte( SPELLLEV) of
          1: SPELLCAS := BADIOS;
          2: SPELLCAS := MONTINO;
          3: if TWOTHIRD then SPELLCAS := BADIOS   else SPELLCAS := BADIAL;
          4: SPELLCAS := BADIAL;
          5: if TWOTHIRD then SPELLCAS := BADIALMA else SPELLCAS := BADI;
          6: if TWOTHIRD then SPELLCAS := LORTO    else SPELLCAS := MABADI;
          7: SPELLCAS := MABADI;
        end;
        ATTCKTYP := SPELLCAS
      end;

    begin  { ENEMYSPL }
      if EABTB.MAGSPELS > 0 then
        if (RNDN(100)) < 75 then
          GETMAGSP( EABTB.MAGSPELS);
      if ATTCKTYP = 0 then
        if EABTB.PRISPELS > 0 then
          if (RNDN(100)) < 75 then
            GETPRISP( EABTB.PRISPELS)
    end;


    procedure YELLHELP_EN;
    begin
      if EABTB.SPPC[ 6] then
        if EABRA.ALIVECNT < 5 then
          if (RNDN(100)) < 75 then
            ATTCKTYP := -4
    end;


    procedure RUNENMY;
    begin
      if not EABTB.SPPC[ 5] then
        exit;
      if MYSTRENG > ENSTRENG then
        if (RNDN(100)) < 65 then
          ATTCKTYP := -2
    end;


    procedure BREATHES;
    begin
      if EABTB.BREATHE > 0 then
        if (RNDN(100)) < 60 then
          ATTCKTYP := -3
    end;


    procedure ADVANCE;
    var
      ADVSTREN : array[ 0..4] of SmallInt;
      AVEX     : SmallInt;
      AVGI     : SmallInt;
      TEMPE2   : ^TENEMY2;
      AVBRC    : ^TENEMY2;
      AVBRA    : ^TENEMY2A;
      AVBTB    : ^TENEMY;
      AVP04    : ^TTEMP04;

      procedure MOVETEXT( GROUPI: SmallInt);
      begin
        { Atari stub — Apple II HGR text scroll animation not ported. }
        PRINTBEL
      end;

    begin  { ADVANCE }
      for AVGI := 1 to 4 do
        begin
          AVBRC := BATTLERC[ AVGI];
          AVBRA := AVBRC^.A;
          AVBTB := AVBRC^.B;
          ADVSTREN[ AVGI] := 0;
          for AVEX := 0 to AVBRA.ALIVECNT - 1 do
            begin
              AVP04 := AVBRA.TEMP04[ AVEX];
              if Byte( AVP04^.XSTATUS) = 0 then  { OK=0 }
                ADVSTREN[ AVGI] :=
                  ADVSTREN[ AVGI] + AVP04.HPLEFT
                  - 3 * (AVBTB.MAGSPELS + AVBTB.PRISPELS)
            end;
          if ADVSTREN[ AVGI] > 1000 then
            ADVSTREN[ AVGI] := 1000
          else if ADVSTREN[ AVGI] < 1 then
            ADVSTREN[ AVGI] := 1
        end;
      for AVGI := 4 downto 2 do
        begin
          AVBRC := BATTLERC[ AVGI];
          AVBRA := AVBRC^.A;
          AVBTB := AVBRC^.B;
          if AVBRA.ALIVECNT > 0 then
            begin
              if (RNDN(100)) <=
                 30 + ((20 * ADVSTREN[ AVGI]) div ADVSTREN[ AVGI - 1]) then
                begin
                  MVCURSOR( 1, 15 - AVGI);
                  PRINTSTR( 'THE ');
                  if AVBRA.IDENTIFI then
                    PRINTSTR( AVBTB.NAMES)
                  else
                    PRINTSTR( AVBTB.NAMEUNKS);
                  PRINTSTR( ' ADVANCE!');
                  MOVETEXT( AVGI - 1);
                  PAUSE1;
                  AVEX                      := ADVSTREN[ AVGI];
                  ADVSTREN[ AVGI]           := ADVSTREN[ AVGI - 1];
                  ADVSTREN[ AVGI - 1]       := AVEX;
                  TEMPE2                    := BATTLERC[ AVGI];
                  BATTLERC[ AVGI]           := BATTLERC[ AVGI - 1];
                  BATTLERC[ AVGI - 1]       := TEMPE2
                end
            end
        end;
      CLRRECT( 1, 11, 38, 4)
    end;  { ADVANCE }


  begin  { ENATTACK }
    EABRC0 := BATTLERC[ 0];
    EABRA0 := EABRC0^.A;
    ADVANCE;
    for GROUPI := 1 to 4 do
      begin
        EABRC := BATTLERC[ GROUPI];
        EABRA := EABRC^.A;
        EABTB := EABRC^.B;
        if EABRA.ALIVECNT > 0 then
          for ENEMYX := 0 to EABRA.ALIVECNT - 1 do
            begin
              PT04 := EABRA.TEMP04[ ENEMYX];
              if (Byte( PT04^.XSTATUS) = 0) and (SURPRISE <> 1) then  { OK=0 }
                begin
                  PT04.AGILITY := (RNDN(8)) + 2;
                  if PARTYCNT = 1 then
                    CHARX := 0
                  else
                    begin
                      CHARX := PARTYCNT - 1;
                      PT04 := EABRA0.TEMP04[ CHARX];
                      while Ord( PT04^.XSTATUS) >= Ord( DEAD) do
                        begin
                          CHARX := CHARX - 1;
                          PT04 := EABRA0.TEMP04[ CHARX]
                        end;
                      CHARX := RNDN( CHARX + 1);
                      PT04 := EABRA.TEMP04[ ENEMYX]
                    end;
                  PT04.VICTIM   := CHARX;
                  PT04.SPELLHSH := 0;
                  ATTCKTYP      := 0;
                  if CANATTCK then
                    begin
                      if SURPRISE = 0 then                    { v3.2 WC023, WC046 }
                        begin
                          ENEMYSPL;
                          if ATTCKTYP = 0 then BREATHES;
                          if ATTCKTYP = 0 then YELLHELP_EN
                        end;
                      if ATTCKTYP = 0 then RUNENMY;
                      if ATTCKTYP > 0 then
                        begin
                          TC := CHARACTR[ CHARX];
                          if TC.WEPVSTY3[ 1, 6] then
                            PT04.AGILITY := -1
                        end;
                      if ATTCKTYP = 0 then
                        if (ENEMYX <= 4 - GROUPI) or
                           ((60 - 10 * GROUPI) <= (RNDN(100))) then
                          begin
                            CHARX := CHARX mod 3;
                            if CANATTCK then
                              begin
                                ATTCKTYP    := -1;
                                PT04.VICTIM := CHARX
                              end
                            else
                              PT04.AGILITY := -1
                          end
                    end;
                  PT04.SPELLHSH := ATTCKTYP
                end
              else
                PT04.AGILITY := -1
            end
      end
  end;  { ENATTACK }


begin  { CUTIL }
  CMBEXIT := UNWNONE;
  HEAL;
  CMBEXIT := DSPPARTY;
  if CMBEXIT <> UNWNONE then exit;                      { EXIT( COMBAT) }
  DSPENEMY;
  if DONEFIGH then
    exit;
  ENATTACK
  { AP: CACTION; SURPRISE := 0 -- the CACTION overlay }
end;  { CUTIL }


end.
