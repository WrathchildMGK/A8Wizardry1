unit COMBATUNIT;

{ Wizardry I — COMBAT segment port.
  Source authority: apple/wiz1b/COMBAT through COMBAT5.
  Segments CINIT/CUTIL/MELEE/CASTASPE/SWINGASW ported as nested procedures.
  AP-specific stubs: ENEMYPIC (HGR render), MOVETEXT (HGR text scroll). }

interface

uses TYPES, CONSTS, GLOBALS, UTIL;

procedure COMBAT;

implementation

procedure COMBAT;

  var
    CINITFL1 : SmallInt;
    SURPRISE : SmallInt;
    DONEFIGH : Boolean;
    MYSTRENG : SmallInt;            { AP: BASE12.MYSTRENG }
    PREBATOR : array[ 0..5] of SmallInt;
    DRAINED  : array[ 0..5] of Boolean;
    BATTLERC : array[ 0..4] of ^TENEMY2;


  function BSET_CB( B: Byte): Boolean;
  begin
    if B <> 0 then BSET_CB := true else BSET_CB := false
  end;

  procedure SETSTATUS_CB( TC: PTCHAR; V: TSTATUS);
  begin
    TC.STATUS := TSTATUS( Byte( V))
  end;

  procedure SETXSTATUS_CB( PT: PTTEMP04; V: TSTATUS);
  begin
    PT.XSTATUS := TSTATUS( Byte( V))
  end;

  procedure SETALIGN_CB( TC: PTCHAR; V: TALIGN);
  begin
    TC.ALIGN := TALIGN( Byte( V))
  end;


  { ── CINIT ────────────────────────────────────────────────────────── }

  procedure CINIT;

    procedure ENEMYPIC( ENEMYID: SmallInt);
    begin
      { Atari stub — Apple II HGR monster picture render not ported. }
      CLRPICT( 0, 0, 0, 100)
    end;


    procedure SVREWARD;
    var
      BATRESLT : TBATRSLT;
      X        : SmallInt;
      BRC      : ^TENEMY2;
      BRA      : ^TENEMY2A;
    begin
      for X := 0 to PARTYCNT - 1 do
        begin
          if (Byte( CHARACTR[ X].STATUS) = 2) or   { ASLEEP=2 }
             (Byte( CHARACTR[ X].STATUS) = 1) then  { AFRAID=1 }
            SETSTATUS_CB( CHARACTR[ X], OK)
        end;
      LLBASE04 := 0;   { AP: read SCNTOCBL from IOCACHE; stub }
      Move( DRAINED[ 0], BATRESLT.DRAINED[ 0], SizeOf( BATRESLT.DRAINED));
      for X := 1 to 4 do
        begin
          BRC := BATTLERC[ X];
          BRA := BRC.A;
          BATRESLT.ENMYID[  X] := BRA.ENEMYID;
          BATRESLT.ENMYCNT[ X] := BRA.ENMYCNT
        end;
      Move( BATRESLT, IOCACHE[ 0], SizeOf( TBATRSLT))
    end;


    procedure INITATTK;
    var
      CHARX  : SmallInt;
      GROUPI : SmallInt;


      procedure INITGRUP;
      var
        BRC  : ^TENEMY2;
        BRA  : ^TENEMY2A;
        BTB  : ^TENEMY;
        PT04 : ^TTEMP04;
        K    : SmallInt;


        procedure ENGROUPS( ENMYI: SmallInt; ENMYGRUP: SmallInt);
        var
          BRC : ^TENEMY2;
          BRA : ^TENEMY2A;
          BTG : ^TENEMY;
        begin
          BRC := BATTLERC[ ENMYGRUP];
          BRA := BRC.A;
          BTG := BRC.B;
          repeat
            LOADENEMY( ENMYI, BTG^);
            if BTG.UNIQUE = 0 then
              ENMYI := BTG.ENMYTEAM;
          until BTG.UNIQUE <> 0;
          BRA.ENEMYID := ENMYI;
          if ENMYGRUP < 4 then
            if BTG.ENMYTEAM >= 0 then
              if ENMYGRUP <= MAZELEV then
                if Random( 100) < BTG.TEAMPERC then
                  ENGROUPS( BTG.ENMYTEAM, ENMYGRUP + 1)
        end;


        function ENEMYCNT( LEVEL, HPFAC, HPMINAD: SmallInt): SmallInt;
        begin
          LLBASE04 := HPMINAD;
          while LEVEL > 0 do
            begin
              LLBASE04 := LLBASE04 + Random( HPFAC) + 1;
              LEVEL := LEVEL - 1
            end;
          ENEMYCNT := LLBASE04
        end;


      begin  { INITGRUP }
        for GROUPI := 1 to 4 do
          begin
            BRC := BATTLERC[ GROUPI];
            BRA := BRC.A;
            BRA.ENMYCNT  := 0;
            BRA.ALIVECNT := 0;
            BRA.ENEMYID  := -1
          end;
        ENGROUPS( ENEMYINX, 1);
        BRC := BATTLERC[ 1];
        BRA := BRC.A;
        BTB := BRC.B;
        ENEMYINX := BRA.ENEMYID;
        ENEMYPIC( GETREC( ZSPCCHRS, BTB.PIC, 512));
        for GROUPI := 1 to 4 do
          begin
            BRC := BATTLERC[ GROUPI];
            BRA := BRC.A;
            BTB := BRC.B;
            if BRA.ENEMYID <> -1 then
              begin
                BRA.ENMYCNT :=
                  ENEMYCNT( BTB.CALC1.XLOW, BTB.CALC1.XMID, BTB.CALC1.XHIGH);
                if BRA.ENMYCNT > (4 + MAZELEV) then
                  BRA.ENMYCNT := 4 + MAZELEV;
                if BRA.ENMYCNT > 9 then
                  BRA.ENMYCNT := 9;
                if BRA.ENMYCNT < 1 then
                  BRA.ENMYCNT := 1;
                BRA.ALIVECNT := BRA.ENMYCNT;
                BRA.IDENTIFI := false;
                for CHARX := 0 to BRA.ENMYCNT - 1 do
                  begin
                    PT04 := BRA.TEMP04[ CHARX];
                    PT04.ARMORCL  := 0;
                    PT04.INAUDCNT := 0;
                    PT04.HPLEFT   :=
                      ENEMYCNT( BTB.HPREC.LEVEL, BTB.HPREC.HPFAC,
                                BTB.HPREC.HPMINAD);
                    SETXSTATUS_CB( PT04, OK)
                  end
              end
          end
      end;  { INITGRUP }


      procedure INTPARTY;
      var
        BRC0 : ^TENEMY2;
        BRA0 : ^TENEMY2A;
        TC   : PTCHAR;
        PT04 : ^TTEMP04;
        K    : SmallInt;
      begin
        BRC0 := BATTLERC[ 0];
        BRA0 := BRC0.A;
        BRA0.ENMYCNT  := PARTYCNT;
        BRA0.ALIVECNT := PARTYCNT;
        for CHARX := 0 to PARTYCNT - 1 do
          begin
            TC   := CHARACTR[ CHARX];
            PT04 := BRA0.TEMP04[ CHARX];
            PT04.ARMORCL  := 0;
            PT04.INAUDCNT := 0;
            PT04.HPLEFT   := TC.HPLEFT;
            SETXSTATUS_CB( PT04, TSTATUS( Byte( TC.STATUS)));
            for K := 0 to 6 do
              TC.WEPVSTY3[ 1, K] := TC.WEPVSTY3[ 0, K];
            for K := 0 to 13 do
              TC.WEPVSTY2[ 1, K] := TC.WEPVSTY2[ 0, K]
          end
      end;


      procedure FRIENDLY;
      var
        GOODLEAV : Boolean;
        ZERO99   : SmallInt;
        INDEX    : SmallInt;
        _done    : Boolean;
        BRC1     : ^TENEMY2;
        BRA1     : ^TENEMY2A;
        BTB1     : ^TENEMY;
        TC       : PTCHAR;
      begin
        _done    := false;
        GOODLEAV := false;
        for INDEX := 0 to PARTYCNT - 1 do
          GOODLEAV := GOODLEAV or
                      (Byte( CHARACTR[ INDEX].ALIGN) = Byte( GOOD));
        if not GOODLEAV then
          _done := true;
        if not _done then
          begin
            BRC1 := BATTLERC[ 1];
            BTB1 := BRC1.B;
            ZERO99 := Random(100);
            INDEX  := 50;
            case Byte( BTB1.XCLASS) of
              0:  INDEX := 60;
              1:  INDEX := 55;
              2:  INDEX := 65;
              3:  INDEX := 53;
              4:  INDEX := 80;
              7:  INDEX := 75;
            end;
            if (ZERO99 > INDEX) or (ZERO99 < 50) then
              _done := true
          end;
        if not _done then
          begin
            for INDEX := 1 to 4 do
              begin
                BRC1 := BATTLERC[ INDEX];
                BRA1 := BRC1.A;
                BRA1.IDENTIFI := true
              end;
            BRC1 := BATTLERC[ 1];
            BTB1 := BRC1.B;
            CLRRECT( 1, 11, 38, 4);
            MVCURSOR( 1, 11);
            PRINTSTR( 'A FRIENDLY GROUP OF ');
            PRINTSTR( BTB1.NAMES);
            PRINTSTR( '.');
            MVCURSOR( 1, 12);
            PRINTSTR( 'THEY HAIL YOU IN WELCOME!');
            MVCURSOR( 1, 14);
            PRINTSTR( 'YOU MAY F)IGHT OR L)EAVE IN PEACE.');
            SURPRISE := 0;
            repeat
              GETKEY
            until (INCHAR = 'F') or (INCHAR = 'L');
            if INCHAR = 'L' then
              begin
                XGOTO    := XRUNNER;
                DONEFIGH := true;     { signal EXIT(COMBAT) }
                exit
              end;
            for INDEX := 0 to PARTYCNT - 1 do
              begin
                TC := CHARACTR[ INDEX];
                if Byte( TC.ALIGN) = Byte( GOOD) then
                  if (Random(2000)) = 565 then
                    SETALIGN_CB( TC, EVIL)
              end
          end
      end;


    begin  { INITATTK }
      CLRRECT( 13, 1, 26, 4);
      CLRRECT( 13, 6, 26, 4);
      CLRRECT( 1, 11, 38, 4);
      INITGRUP;
      INTPARTY;
      FillChar( DRAINED[ 0], 6, 0);
      for LLBASE04 := 0 to PARTYCNT - 1 do
        PREBATOR[ LLBASE04] := CHARDISK[ LLBASE04];
      if (Random(100)) > 80 then
        SURPRISE := 1
      else if (Random(100)) > 80 then
        SURPRISE := 2
      else
        SURPRISE := 0;
      FRIENDLY
    end;  { INITATTK }


  begin  { CINIT }
    if CINITFL1 = 0 then
      INITATTK
    else
      SVREWARD
  end;  { CINIT }


  { ── CUTIL ────────────────────────────────────────────────────────── }

  procedure CUTIL;
  var
    _exitcutil : Boolean;


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
        if (Random(100)) <= HEALCHAN then
          begin
            TBRC := BATTLERC[ T2];
            TBRA := TBRC.A;
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
            HBRA := HBRC.A;
            HBTB := HBRC.B;
            if HBRA.ALIVECNT > 0 then
              begin
                T1       := 0;
                MVUPLIVE := 0;
                while MVUPLIVE < HBRA.ALIVECNT do
                  begin
                    HBRA.TEMP04[ T1] := HBRA.TEMP04[ MVUPLIVE];
                    MVUPLIVE := MVUPLIVE + 1;
                    PT04 := HBRA.TEMP04[ T1];
                    if Ord( PT04.XSTATUS) < Ord( DEAD) then
                      begin
                        case Byte( PT04.XSTATUS) of
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
              TBRA1 := TBRC1.A;
              if TBRA1.ALIVECNT = 0 then
                begin
                  TBRC1 := BATTLERC[ T2];
                  TBRA1 := TBRC1.A;
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
            HBRA := HBRC.A;
            if HBRA.ALIVECNT > 0 then
              T2 := T1
          end;
        DONEFIGH := BSET_CB( T2 = 0)
      end;


      procedure HEALPRTY;
      begin
        HBR0  := BATTLERC[ 0];
        HBRA0 := HBR0.A;
        T2 := 0;
        for T1 := 0 to PARTYCNT - 1 do
          begin
            PT04 := HBRA0.TEMP04[ T1];
            TC   := CHARACTR[ T1];
            if Ord( PT04.XSTATUS) < Ord( DEAD) then
              begin
                if (Random(4)) = 2 then
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
                case Byte( PT04.XSTATUS) of
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
            TC.STATUS  := TSTATUS( Byte( PT04.XSTATUS))
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
          DBRA := DBRC.A;
          for X := 0 to ALIVECNT - 1 do
            begin
              PT04 := DBRA.TEMP04[ ALIVECNT];
              if PT04.INAUDCNT > 0 then
                PT04.INAUDCNT := PT04.INAUDCNT - 1
            end
        end;

      begin  { HEALHEAR }
        DECINAUD( 0, PARTYCNT);
        DBRC := BATTLERC[ 1]; DBRA := DBRC.A; DECINAUD( 1, DBRA.ALIVECNT);
        DBRC := BATTLERC[ 2]; DBRA := DBRC.A; DECINAUD( 2, DBRA.ALIVECNT);
        DBRC := BATTLERC[ 3]; DBRA := DBRC.A; DECINAUD( 3, DBRA.ALIVECNT)
      end;


    begin  { HEAL }
      HEALENMY;
      HEALPRTY;
      HEALHEAR
    end;  { HEAL }


    { ── DSPPARTY ── }

    procedure DSPPARTY;
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
        STATUSOK := STATUSOK or BSET_CB( Ord( TC.STATUS) < Ord( DEAD));
        if Byte( TC.STATUS) = 0 then  { OK=0 }
          if TC.LOSTXYL[ 1] > 0 then
            PRINTSTR( 'POISON')
          else
            PRINTNUM( TC.HPMAX, 4)
        else
          PRINTSTR( SCNTOC_STATUS[ Ord( TC.STATUS)])
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
      DBRC0 := BATTLERC[ 0];
      DBRA0 := DBRC0.A;
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
          if Byte( TC.STATUS) = 0 then  { OK=0 }
            MYSTRENG := MYSTRENG + TC.CHARLEV;
          if Ord( TC.STATUS) < Ord( DEAD) then
            DBRA0.ALIVECNT := DBRA0.ALIVECNT + 1
        end;
      CLRRECT( 1, 17, 38, 6);
      STATUSOK := false;
      for PARTYI := 0 to PARTYCNT - 1 do
        begin
          TC   := CHARACTR[ PARTYI];
          PT04 := DBRA0.TEMP04[ PARTYI];
          if (Random(99)) < (TC.ATTRIB[ Ord( IQ)] +
                                TC.ATTRIB[ Ord( PIETY)] +
                                TC.CHARLEV) then
            begin
              DBRC_R := BATTLERC[ Random( 4) + 1];
              DBRA_R := DBRC_R.A;
              DBRA_R.IDENTIFI := true
            end;
          MVCURSOR( 1, 17 + PARTYI);
          PRINTNUM( PARTYI + 1, 1);
          PRINTSTR( ' ');
          PRINTSTR( TC.NAME);
          MVCURSOR( 19, 17 + PARTYI);
          PRINTSTR( Copy( SCNTOC_ALIGN[ Ord( TC.ALIGN)], 1, 1));
          PRINTCHR( '-');
          PRINTSTR( Copy( SCNTOC_CLASS[ Ord( TC.XCLASS)], 1, 3));
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
        begin
          DONEFIGH     := true;     { signal EXIT(COMBAT) }
          _exitcutil   := true;
          exit
        end
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
          DEBRA := DEBRC.A;
          DEBTB := DEBRC.B;
          if DEBRA.ALIVECNT > 0 then
            begin
              ENMYGROK := 0;
              for ENMYIND := 0 to DEBRA.ALIVECNT - 1 do
                begin
                  PT04 := DEBRA.TEMP04[ ENMYIND];
                  if Byte( PT04.XSTATUS) = 0 then  { OK=0 }
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
                    BSET_CB( (Random(100)) < 50)
      end;


      procedure ENEMYSPL;

        procedure SPELLEZR( var SPELLGR: SmallInt);
        begin
          if Random( EABRA.ALIVECNT + 2) = 0 then
            SPELLGR := SPELLGR - 1
        end;

        procedure GETMAGSP( SPELLLEV: SmallInt);
        var
          SPELLCAS : SmallInt;
          TWOTHIRD : Boolean;
        begin
          while (SPELLLEV > 1) and ((Random(100)) > 70) do
            SPELLLEV := SPELLLEV - 1;
          TWOTHIRD := BSET_CB( (Random(100)) > 33);
          SPELLEZR( EABTB.MAGSPELS);
          case Byte( SPELLLEV) of
            1: if TWOTHIRD then SPELLCAS := KATINO  else SPELLCAS := HALITO;
            2: if TWOTHIRD then SPELLCAS := DILTO   else SPELLCAS := HALITO;
            3: if TWOTHIRD then SPELLCAS := MOLITO  else SPELLCAS := MAHALITO;
            4: if TWOTHIRD then SPELLCAS := DALTO   else SPELLCAS := LAHALITO;
            5: if TWOTHIRD then SPELLCAS := LAHALITO else SPELLCAS := MADALTO;
            6: if TWOTHIRD then SPELLCAS := MADALTO  else SPELLCAS := ZILWAN;
            7: SPELLCAS := TILTOWAI;
          end;
          ATTCKTYP := SPELLCAS
        end;

        procedure GETPRISP( SPELLLEV: SmallInt);
        var
          SPELLCAS : SmallInt;
          TWOTHIRD : Boolean;
        begin
          TWOTHIRD := BSET_CB( (Random(100)) > 33);
          SPELLEZR( EABTB.PRISPELS);
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
          if (Random(100)) < 75 then
            GETMAGSP( EABTB.MAGSPELS);
        if ATTCKTYP = 0 then
          if EABTB.PRISPELS > 0 then
            if (Random(100)) < 75 then
              GETPRISP( EABTB.PRISPELS)
      end;


      procedure YELLHELP_EN;
      begin
        if EABTB.SPPC[ 6] then
          if EABRA.ALIVECNT < 5 then
            if (Random(100)) < 75 then
              ATTCKTYP := -4
      end;


      procedure RUNENMY;
      begin
        if not EABTB.SPPC[ 5] then
          exit;
        if MYSTRENG > ENSTRENG then
          if (Random(100)) < 65 then
            ATTCKTYP := -2
      end;


      procedure BREATHES;
      begin
        if EABTB.BREATHE > 0 then
          if (Random(100)) < 60 then
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
            AVBRA := AVBRC.A;
            AVBTB := AVBRC.B;
            ADVSTREN[ AVGI] := 0;
            for AVEX := 0 to AVBRA.ALIVECNT - 1 do
              begin
                AVP04 := AVBRA.TEMP04[ AVEX];
                if Byte( AVP04.XSTATUS) = 0 then  { OK=0 }
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
            AVBRA := AVBRC.A;
            AVBTB := AVBRC.B;
            if AVBRA.ALIVECNT > 0 then
              begin
                if (Random(100)) <=
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
      EABRA0 := EABRC0.A;
      ADVANCE;
      for GROUPI := 1 to 4 do
        begin
          EABRC := BATTLERC[ GROUPI];
          EABRA := EABRC.A;
          EABTB := EABRC.B;
          if EABRA.ALIVECNT > 0 then
            for ENEMYX := 0 to EABRA.ALIVECNT - 1 do
              begin
                PT04 := EABRA.TEMP04[ ENEMYX];
                if (Byte( PT04.XSTATUS) = 0) and (SURPRISE <> 1) then  { OK=0 }
                  begin
                    PT04.AGILITY := (Random(8)) + 2;
                    if PARTYCNT = 1 then
                      CHARX := 0
                    else
                      begin
                        CHARX := PARTYCNT - 1;
                        PT04 := EABRA0.TEMP04[ CHARX];
                        while Ord( PT04.XSTATUS) >= Ord( DEAD) do
                          begin
                            CHARX := CHARX - 1;
                            PT04 := EABRA0.TEMP04[ CHARX]
                          end;
                        CHARX := Random( CHARX + 1);
                        PT04 := EABRA.TEMP04[ ENEMYX]
                      end;
                    PT04.VICTIM   := CHARX;
                    PT04.SPELLHSH := 0;
                    ATTCKTYP      := 0;
                    if CANATTCK then
                      begin
                        ENEMYSPL;
                        if ATTCKTYP = 0 then BREATHES;
                        if ATTCKTYP = 0 then YELLHELP_EN;
                        if ATTCKTYP = 0 then RUNENMY;
                        if ATTCKTYP > 0 then
                          begin
                            TC := CHARACTR[ CHARX];
                            if TC.WEPVSTY3[ 1, 6] then
                              PT04.AGILITY := -1
                          end;
                        if ATTCKTYP = 0 then
                          if (ENEMYX <= 4 - GROUPI) or
                             ((60 - 10 * GROUPI) <= (Random(100))) then
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


    { ── CACTION ── }

    procedure CACTION;
    var
      SPLGRCNT : array[ 0..5] of SmallInt;
      BDISPELL : Boolean;
      MYCHARX  : SmallInt;
      AGIL1TEN : SmallInt;
      PT04     : ^TTEMP04;
      TC       : PTCHAR;
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
        XBRA := XBRC.A;
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
        XBRA := XBRC.A;
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
        PP       : ^TPOSSESS;
        _exit    : Boolean;

        procedure READOBJT;
        begin
          TC := CHARACTR[ MYCHARX];
          PP := TC.POSS.POSSESS[ POSSX];
          LOADOBJREC( PP.EQINDEX, OBJREC)
        end;

        procedure DSPITEMS;
        var
          ITEMCNT : SmallInt;
        begin
          CLRRECT( 1, 11, 38, 4);
          ITEMCNT := 0;
          TC := CHARACTR[ MYCHARX];
          for POSSX := 1 to TC.POSS.POSSCNT do
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
            _exit := true
          else
            begin
              MVCURSOR( 13, 8);
              PRINTSTR( 'WHICH ITEM (RETURN EXITS)?')
            end
        end;

        procedure CHGITEM;
        begin
          if (Random(100)) >= OBJREC.CHGCHANC then
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
        _exit := false;
        TC := CHARACTR[ MYCHARX];
        if TC.POSS.POSSCNT = 0 then
          exit;
        DSPITEMS;
        if _exit then
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
        SPTR := SCNTOC.SPELLS;
        LLBASE04 := SPTR.SPELLHSH[ OBJREC.SPELLPWR];
        case SPTR.SPELL012[ OBJREC.SPELLPWR] of
          0: UIGENERC( LLBASE04);
          1: UIPERSON( LLBASE04);
          2: UIGROUP(  LLBASE04);
        end
      end;  { USEITEM }


      procedure GETSPELL;
      var
        SPELLNAM : string[ 14];
        SPELLCST : SmallInt;
        SPELNAML : SmallInt;
        SPELCHRA : SmallInt;
        SPELNAMI : SmallInt;
        _exit    : Boolean;
        SPTR     : ^TSPELBLK;

        procedure DOSPELL;
        var
          SPELLX : SmallInt;

          procedure CASTCHK( SPELLI: SmallInt; SPELLGR: SmallInt);
          begin
            TC   := CHARACTR[ MYCHARX];
            SKNS := TC.SPELLSKN;
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
              PRINTSTR( 'YOU DONT KNOW THAT SPELL');
            PAUSE1;
            _exit := true     { EXIT(GETSPELL) }
          end;

          procedure SPGENERC( SPELLI: SmallInt; SPELLGR: SmallInt);
          begin
            CASTCHK( SPELLI, SPELLGR);
            if not _exit then
              begin
                PT04 := BRA0.TEMP04[ MYCHARX];
                PT04.SPELLHSH := SPELLCST;
                PT04.VICTIM   := -1
              end
          end;

          procedure SPPERSON( SPELLI: SmallInt; SPELLGR: SmallInt);
          begin
            CASTCHK( SPELLI, SPELLGR);
            if not _exit then
              begin
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
              end
          end;

          procedure SPGROUP( SPELLI: SmallInt; SPELLGR: SmallInt);
          begin
            CASTCHK( SPELLI, SPELLGR);
            if not _exit then
              WHICHGRP( 'CAST SPELL ON GROUP #?', SPELLCST)
          end;

        begin  { DOSPELL }
          SPTR := SCNTOC.SPELLS;
          for SPELLX := 0 to 50 do
            if SPELLCST = SPTR.SPELLHSH[ SPELLX] then
              case SPTR.SPELL012[ SPELLX] of
                0: SPGENERC( SPELLX, SPTR.SPELLGRP[ SPELLX]);
                1: SPPERSON( SPELLX, SPTR.SPELLGRP[ SPELLX]);
                2: SPGROUP(  SPELLX, SPTR.SPELLGRP[ SPELLX]);
              end
        end;  { DOSPELL }

      begin  { GETSPELL }
        _exit := false;
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
        DOSPELL
      end;  { GETSPELL }


      procedure RUNAWAY;
      var
        TEMP     : SmallInt;
        _exitca  : Boolean;
        XBRC     : ^TENEMY2;
        XBRA     : ^TENEMY2A;

        procedure RUNFAILD;
        var
          TEMPX : SmallInt;
          PT04R : ^TTEMP04;
        begin
          for TEMPX := 0 to PARTYCNT - 1 do
            begin
              PT04R := BRA0.TEMP04[ TEMPX];
              PT04R.AGILITY := -1
            end;
          _exitca := true     { EXIT(CACTION) }
        end;

      begin  { RUNAWAY }
        _exitca := false;
        CLRRECT( 13, 6, 26, 4);
        TEMP := 38 - 3 * MAZELEV;
        if PARTYCNT < 4 then
          TEMP := TEMP + 20 - 5 * PARTYCNT;
        if MYSTRENG > ENSTRENG then
          TEMP := TEMP + 20;
        if MAZELEV = 10 then
          TEMP := -1;
        if (Random(100)) > TEMP then
          RUNFAILD;
        if not _exitca then
          begin
            for TEMP := 1 to 4 do
              begin
                XBRC := BATTLERC[ TEMP];
                XBRA := XBRC.A;
                XBRA.ALIVECNT := 0;
                XBRA.ENMYCNT  := 0
              end;
            XGOTO    := XREWARD2;
            DONEFIGH := true;
            _exitcutil := true
          end
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
            PRINTBEL;
            PAUSE2;
            PAUSE2
          end
      end;


    begin  { CACTION }
      BRC0 := BATTLERC[ 0];
      BRA0 := BRC0.A;
      DOSUPRIS;
      MYCHARX := 0;
      FillChar( SPLGRCNT[ 0], 12, 0);
      while (MYCHARX < PARTYCNT) and (not _exitcutil) do
        begin
          repeat
            PT04 := BRA0.TEMP04[ MYCHARX];
            if (Byte( PT04.XSTATUS) = 0) and (SURPRISE <> 2) then
              begin
                PT04.SPELLHSH := -999;
                repeat
                  AGIL1TEN := Random(10);
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
                  if AGIL1TEN < 1 then
                    AGIL1TEN := 1
                  else if AGIL1TEN > 10 then
                    AGIL1TEN := 10;
                  PT04.AGILITY := AGIL1TEN;
                  MVCURSOR( 13, 6);
                  PRINTSTR( TC.NAME);
                  PRINTSTR( '''S OPTIONS');
                  MVCURSOR( 13, 8);
                  if MYCHARX < 3 then
                    PRINTSTR( 'F)IGHT  ');
                  PRINTSTR( 'S)PELL  P)ARRY');
                  MVCURSOR( 13, 9);
                  PRINTSTR( 'R)UN    U)SE    ');
                  BDISPELL := false;
                  if (Byte( TC.XCLASS) = 2) or
                     ((Byte( TC.XCLASS) = 6) and (TC.CHARLEV > 8)) or
                     ((Byte( TC.XCLASS) = 4) and (TC.CHARLEV > 3)) then
                    begin
                      BDISPELL := true;
                      PRINTSTR( 'D)ISPELL ')
                    end;
                  repeat
                    GETKEY
                  until (INCHAR = 'F') or (INCHAR = 'S') or
                        (INCHAR = 'P') or (INCHAR = 'U') or
                        (INCHAR = 'D') or (INCHAR = 'R') or
                        (INCHAR = 'B');
                  CLRRECT( 13, 8, 26, 2);
                  SPLGRCNT[ MYCHARX] := 0;
                  case INCHAR of
                    'D': if BDISPELL then
                           WHICHGRP( 'DISPELL WHICH GROUP# ?', -5);
                    'R': RUNAWAY;
                    'F': if MYCHARX < 3 then
                           WHICHGRP( 'FIGHT AGAINST GROUP# ?', -1);
                    'P': begin
                           PT04.SPELLHSH := 0;
                           PT04.AGILITY  := -1
                         end;
                    'S': GETSPELL;
                    'U': begin
                           USEITEM;
                           CLRRECT( 1, 11, 38, 4)
                         end;
                    'B': if MYCHARX > 0 then
                           PT04.SPELLHSH := -100;
                  end;
                  CLRRECT( 13, 6, 26, 4);
                until PT04.SPELLHSH <> -999;
                if PT04.SPELLHSH = -100 then
                  MYCHARX := -1
              end
            else
              PT04.AGILITY := -1;
            MYCHARX := MYCHARX + 1
          until (MYCHARX = PARTYCNT) or _exitcutil;
          if _exitcutil then
            exit;
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
      if _exitcutil then
        exit;
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


  begin  { CUTIL }
    _exitcutil := false;
    HEAL;
    DSPPARTY;
    if _exitcutil then exit;
    DSPENEMY;
    if DONEFIGH then
      exit;
    ENATTACK;
    CACTION;
    SURPRISE := 0
  end;  { CUTIL }


  { ── MELEE ────────────────────────────────────────────────────────── }

  procedure MELEE;
  var
    VICTIM   : SmallInt;
    ATTACKTY : SmallInt;
    BATI     : SmallInt;
    BATG     : SmallInt;
    AGILELEV : SmallInt;
    MBRC     : ^TENEMY2;
    MBRA     : ^TENEMY2A;
    PT04     : ^TTEMP04;


    { ── CASTASPE ── }

    procedure CASTASPE;
    var
      SPELL   : SmallInt;
      CASTI   : SmallInt;
      CASTGR  : SmallInt;
      PT04    : ^TTEMP04;
      TC      : PTCHAR;
      BTB     : ^TENEMY;
      _exitca : Boolean;
      CBRC    : ^TENEMY2;
      CBRA    : ^TENEMY2A;


      procedure DSPNAMES( GROUPI: SmallInt; MYCHARI: SmallInt);
      var
        XBRC : ^TENEMY2;
        XBRA : ^TENEMY2A;
        XBTB : ^TENEMY;
        TCN  : PTCHAR;
      begin
        if GROUPI = 0 then
          begin
            TCN := CHARACTR[ MYCHARI];
            PRINTSTR( TCN.NAME)
          end
        else
          begin
            XBRC := BATTLERC[ GROUPI];
            XBRA := XBRC.A;
            XBTB := XBRC.B;
            if XBRA.IDENTIFI then
              PRINTSTR( XBTB.NAME)
            else
              PRINTSTR( XBTB.NAMEUNK)
          end;
        PRINTSTR( ' ')
      end;


      procedure UNAFFECT( GROUPI: SmallInt; CHARX: SmallInt;
                          DAMPTS: SmallInt);
      var
        XBRC : ^TENEMY2;
        XBRA : ^TENEMY2A;
        XBTB : ^TENEMY;
      begin
        CLRRECT( 1, 12, 38, 3);
        XBRC := BATTLERC[ GROUPI];
        XBRA := XBRC.A;
        PT04 := XBRA.TEMP04[ CHARX];
        if Byte( PT04.XSTATUS) >= 5 then
          exit;
        MVCURSOR( 1, 12);
        DSPNAMES( GROUPI, CHARX);
        if GROUPI <> 0 then
          begin
            XBTB := XBRC.B;
            if XBTB.UNAFFCT > (Random(100)) then
              DAMPTS := 0
          end;
        if DAMPTS = 0 then
          PRINTSTR( 'IS UNAFFECTED!')
        else
          begin
            PRINTSTR( 'TAKES ');
            PRINTNUM( DAMPTS, 4);
            PRINTSTR( ' DAMAGE');
            PT04.HPLEFT := PT04.HPLEFT - DAMPTS;
            if PT04.HPLEFT <= 0 then
              begin
                PT04.HPLEFT  := 0;
                SETXSTATUS_CB( PT04, DEAD);
                MVCURSOR( 1, 14);
                DSPNAMES( GROUPI, CHARX);
                PRINTSTR( 'DIES!')
              end
          end;
        PAUSE1
      end;


      procedure ISISNOT( GROUPI: SmallInt; CHARI: SmallInt;
                         ISNOTCHN: SmallInt; SDAMTYPE: string;
                         DAMTYPE: SmallInt);
      var
        XBRC : ^TENEMY2;
        XBRA : ^TENEMY2A;
      begin
        MVCURSOR( 1, 13);
        DSPNAMES( GROUPI, CHARI);
        XBRC := BATTLERC[ GROUPI];
        XBRA := XBRC.A;
        PT04 := XBRA.TEMP04[ CHARI];
        if (Random(100)) < ISNOTCHN then
          PRINTSTR( 'IS NOT ')
        else
          begin
            PRINTSTR( 'IS ');
            case Byte( DAMTYPE) of
              0,
              3: SETXSTATUS_CB( PT04, ASLEEP);
              1: PT04.INAUDCNT := (Random(4)) + 2;
              2: begin
                   SETXSTATUS_CB( PT04, DEAD);
                   PT04.HPLEFT  := 0
                 end;
            end
          end;
        PRINTSTR( SDAMTYPE);
        PAUSE1;
        CLRRECT( 1, 13, 38, 1)
      end;


      function CALCPTS( HITS, HITRANGE, HITMIN: SmallInt): SmallInt;
      var
        POINTS : SmallInt;
      begin
        POINTS := 0;
        while HITS > 0 do
          begin
            POINTS := POINTS + (Random(HITRANGE)) + 1;
            HITS   := HITS - 1
          end;
        CALCPTS := POINTS + HITMIN
      end;


      procedure MODAC( GROUPI: SmallInt; ACMOD: SmallInt;
                       CHARF: SmallInt; CHARL: SmallInt);
      var
        X    : SmallInt;
        XBRC : ^TENEMY2;
        XBRA : ^TENEMY2A;
      begin
        XBRC := BATTLERC[ GROUPI];
        XBRA := XBRC.A;
        for X := CHARF to CHARL do
          begin
            PT04 := XBRA.TEMP04[ X];
            PT04.ARMORCL := PT04.ARMORCL + ACMOD
          end
      end;


      procedure DOHEAL( GROUPI: SmallInt; CHARI: SmallInt;
                        HITCNT: SmallInt; HITRANGE: SmallInt);
      var
        POINTS : SmallInt;
        XBRC   : ^TENEMY2;
        XBRA   : ^TENEMY2A;
      begin
        POINTS := CALCPTS( HITCNT, HITRANGE, 0);
        XBRC := BATTLERC[ GROUPI];
        XBRA := XBRC.A;
        PT04 := XBRA.TEMP04[ CHARI];
        PT04.HPLEFT := PT04.HPLEFT + POINTS;
        TC := CHARACTR[ CHARI];
        if TC.HPMAX < PT04.HPLEFT then
          PT04.HPLEFT := TC.HPMAX;
        DSPNAMES( GROUPI, CHARI);
        if TC.HPMAX = PT04.HPLEFT then
          PRINTSTR( 'IS FULLY HEALED')
        else
          PRINTSTR( 'IS PARTIALLY HEALED')
      end;


      procedure DOHITS( GROUPI: SmallInt; CHARI: SmallInt;
                        HITCNT: SmallInt; HITRANGE: SmallInt);
      var
        POINTS : SmallInt;
        XBRC   : ^TENEMY2;
        XBTB   : ^TENEMY;
      begin
        POINTS := CALCPTS( HITCNT, HITRANGE, 0);
        if GROUPI > 0 then
          begin
            XBRC := BATTLERC[ GROUPI];
            XBTB := XBRC.B;
            if XBTB.UNAFFCT > 0 then
              if (Random(100)) < XBTB.UNAFFCT then
                POINTS := 0
          end;
        UNAFFECT( GROUPI, CHARI, POINTS)
      end;


      procedure DOHOLD;
      var
        CHARX : SmallInt;
        XBRC  : ^TENEMY2;
        XBRA  : ^TENEMY2A;
        XBTB  : ^TENEMY;
      begin
        XBRC := BATTLERC[ CASTGR];
        XBRA := XBRC.A;
        XBTB := XBRC.B;
        for CHARX := 0 to XBRA.ALIVECNT - 1 do
          begin
            PT04 := XBRA.TEMP04[ CHARX];
            if Byte( PT04.XSTATUS) <= 2 then
              if CASTGR = 0 then
                ISISNOT( CASTGR, CHARX,
                         50 + 10 * CHARACTR[ CHARX].CHARLEV,
                         'HELD', 0)
              else
                ISISNOT( CASTGR, CHARX,
                         50 + 10 * XBTB.HPREC.LEVEL,
                         'HELD', 0)
          end
      end;


      procedure DOSILENC;
      var
        CHARX : SmallInt;
        XBRC  : ^TENEMY2;
        XBRA  : ^TENEMY2A;
        XBTB  : ^TENEMY;
      begin
        XBRC := BATTLERC[ CASTGR];
        XBRA := XBRC.A;
        XBTB := XBRC.B;
        for CHARX := 0 to XBRA.ALIVECNT - 1 do
          begin
            TC := CHARACTR[ CHARX];
            if CASTGR = 0 then
              ISISNOT( CASTGR, CHARX,
                       100 - 5 * TC.LUCKSKIL[ 4],
                       'SILENCED', 1)
            else
              ISISNOT( CASTGR, CHARX,
                       10 * XBTB.HPREC.LEVEL,
                       'SILENCED', 1)
          end
      end;


      procedure DODISRUP;
      begin
        MVCURSOR( 1, 13);
        PRINTSTR( 'SPELL DISRUPTED')
      end;


      procedure DOSLAIN( GROUPI: SmallInt; CHARI: SmallInt);
      var
        CHNOTSLN : SmallInt;
        XBRC     : ^TENEMY2;
        XBTB     : ^TENEMY;
      begin
        if GROUPI = 0 then
          CHNOTSLN := CHARACTR[ CHARI].CHARLEV
        else
          begin
            XBRC := BATTLERC[ GROUPI];
            XBTB := XBRC.B;
            CHNOTSLN := XBTB.HPREC.LEVEL
          end;
        ISISNOT( GROUPI, CHARI, 10 * CHNOTSLN, 'SLAIN', 2)
      end;


      procedure DOSLEPT;
      var
        CHARX : SmallInt;
        XBRC  : ^TENEMY2;
        XBRA  : ^TENEMY2A;
        XBTB  : ^TENEMY;
      begin
        XBRC := BATTLERC[ CASTGR];
        XBRA := XBRC.A;
        XBTB := XBRC.B;
        for CHARX := 0 to XBRA.ALIVECNT - 1 do
          begin
            PT04 := XBRA.TEMP04[ CHARX];
            if Byte( PT04.XSTATUS) < 2 then
              if CASTGR > 0 then
                begin
                  if XBTB.SPPC[ 4] then
                    ISISNOT( CASTGR, CHARX,
                             20 * XBTB.HPREC.LEVEL,
                             'SLEPT', 3)
                end
              else
                ISISNOT( CASTGR, CHARX,
                         20 * CHARACTR[ CHARX].CHARLEV,
                         'SLEPT', 3)
          end
      end;


      procedure HAMMAHAM( MAHAMFLG: SmallInt);
      var
        TEMP2    : SmallInt;
        TEMP1    : SmallInt;
        BCHARLEV : SmallInt;
        PT04L    : ^TTEMP04;
        XBRC0    : ^TENEMY2;
        XBRA0    : ^TENEMY2A;
        XBRC     : ^TENEMY2;
        XBRA     : ^TENEMY2A;
        XBTB     : ^TENEMY;

        procedure HAMCURE;
        begin
          PRINTSTR( 'DIALKO''S PARTY 3 TIMES');
          for TEMP1 := 0 to PARTYCNT - 1 do
            begin
              PT04L := XBRA0.TEMP04[ TEMP1];
              if Byte( PT04L.XSTATUS) < 5 then
                begin
                  SETXSTATUS_CB( PT04L, OK);
                  PT04L.INAUDCNT := 0;
                  PT04L.HPLEFT   := PT04L.HPLEFT +
                                    CALCPTS( 9, 8, 0);
                  if PT04L.HPLEFT > CHARACTR[ TEMP1].HPMAX then
                    PT04L.HPLEFT := CHARACTR[ TEMP1].HPMAX
                end
            end
        end;

        procedure HAMSILEN;
        begin
          PRINTSTR( 'SILENCES MONSTERS!');
          for TEMP1 := 1 to 3 do
            begin
              XBRC := BATTLERC[ TEMP1];
              XBRA := XBRC.A;
              for TEMP2 := 0 to XBRA.ALIVECNT - 1 do
                begin
                  PT04L := XBRA.TEMP04[ TEMP2];
                  PT04L.INAUDCNT := 5 + (Random(5))
                end
            end
        end;

        procedure HAMMAGIC;
        begin
          PRINTSTR( 'ZAPS MONSTER MAGIC RESISTANCE!');
          for TEMP1 := 1 to 3 do
            begin
              XBRC := BATTLERC[ TEMP1];
              XBTB := XBRC.B;
              XBTB.UNAFFCT := 0
            end
        end;

        procedure HAMTELEP;
        begin
          PRINTSTR( 'DESTROYS MONSTERS!');
          for TEMP1 := 1 to 4 do
            begin
              XBRC := BATTLERC[ TEMP1];
              XBRA := XBRC.A;
              for TEMP2 := 0 to XBRA.ALIVECNT - 1 do
                begin
                  PT04L := XBRA.TEMP04[ TEMP2];
                  SETXSTATUS_CB( PT04L, DEAD);
                  PT04L.HPLEFT  := 0
                end;
              XBRA.ALIVECNT := 0
            end
        end;

        procedure HAMHEAL;
        begin
          PRINTSTR( 'HEALS PARTY!');
          for TEMP1 := 0 to PARTYCNT - 1 do
            begin
              PT04L := XBRA0.TEMP04[ TEMP1];
              if Byte( PT04L.XSTATUS) < 5 then
                begin
                  SETXSTATUS_CB( PT04L, OK);
                  PT04L.INAUDCNT := 0;
                  PT04L.HPLEFT   := CHARACTR[ TEMP1].HPMAX
                end
            end
        end;

        procedure HAMPROT;
        begin
          PRINTSTR( 'SHIELDS PARTY');
          for TEMP1 := 0 to PARTYCNT - 1 do
            if CHARACTR[ TEMP1].ARMORCL > -10 then
              CHARACTR[ TEMP1].ARMORCL := -10
        end;

        procedure HAMALIVE;
        begin
          PRINTSTR( 'RESSURECTS AND ');
          for TEMP1 := 0 to PARTYCNT - 1 do
            begin
              PT04L := XBRA0.TEMP04[ TEMP1];
              if Byte( PT04L.XSTATUS) <> 7 then
                SETXSTATUS_CB( PT04L, OK)
            end;
          HAMHEAL
        end;

        procedure HAMMANGL;
        var
          SPELLI : SmallInt;
          SKNS   : ^TSPELLSKN;
        begin
          MVCURSOR( 1, 14);
          PRINTSTR( 'BUT HIS SPELL BOOKS ARE MANGLED!');
          SKNS := CHARACTR[ TEMP1].SPELLSKN;
          for SPELLI := 1 to 50 do
            if (Random(100)) > 50 then
              SKNS^[ SPELLI] := false
        end;

      begin  { HAMMAHAM }
        XBRC0 := BATTLERC[ 0];
        XBRA0 := XBRC0.A;
        if MAHAMFLG = 7 then
          PRINTSTR( 'MA');
        PRINTSTR( 'HAMAN IS INTONED AND...');
        PAUSE2;
        MVCURSOR( 1, 13);
        if CHARACTR[ BATI].CHARLEV < 13 then
          begin
            PRINTSTR( 'FAILS!');
            exit
          end;
        CHARACTR[ BATI].CHARLEV := CHARACTR[ BATI].CHARLEV - 1;
        DRAINED[ BATI] := true;
        case Byte( Random(3) * MAHAMFLG) of
            0,  1,  2,  3,  4,  5: HAMCURE;
                7,  8,  9, 10, 11: HAMSILEN;
                   12, 13, 22, 23: HAMMAGIC;
                       14, 20, 21: HAMTELEP;
                        6, 15, 19: HAMHEAL;
                               17: HAMPROT;
                           16, 18: HAMALIVE;
        end;
        BCHARLEV := CHARACTR[ BATI].CHARLEV;
        if Random( BCHARLEV) = 5 then
          HAMMANGL
      end;  { HAMMAHAM }


      procedure HITGROUP( GROUPI: SmallInt; HITSX: SmallInt;
                          HITSR: SmallInt; TEMP99I: SmallInt);
      var
        CHARI : SmallInt;
        TC    : PTCHAR;
        BTB   : ^TENEMY;
        K     : SmallInt;
        XBRC  : ^TENEMY2;
        XBRA  : ^TENEMY2A;
      begin
        XBRC := BATTLERC[ GROUPI];
        XBRA := XBRC.A;
        if XBRA.ALIVECNT > 0 then
          for CHARI := 0 to XBRA.ALIVECNT - 1 do
            begin
              if GROUPI = 0 then
                begin
                  TC := CHARACTR[ CHARI];
                  if TC.WEPVSTY3[ 1, TEMP99I] then
                    DOHITS( GROUPI, CHARI, HITSX div 2 + 1, HITSR)
                  else
                    DOHITS( GROUPI, CHARI, HITSX, HITSR)
                end
              else
                begin
                  BTB := XBRC.B;
                  if BTB.WEPVSTY3[ TEMP99I] then
                    DOHITS( GROUPI, CHARI, HITSX div 2 + 1, HITSR)
                  else
                    DOHITS( GROUPI, CHARI, HITSX, HITSR)
                end
            end
      end;


      procedure SLOKTOFE;
      var
        POSSX  : SmallInt;
        TEMPXX : SmallInt;
        TC     : PTCHAR;
        PP     : ^TPOSSESS;
      begin
        if (Random(100)) > 2 * CHARACTR[ BATI].CHARLEV then
          begin
            MVCURSOR( 1, 13);
            PRINTSTR( 'LOKTOFEIT FAILS!');
            exit
          end;
        for TEMPXX := 0 to PARTYCNT - 1 do
          begin
            TC := CHARACTR[ TEMPXX];
            for POSSX := 1 to TC.POSS.POSSCNT do
              begin
                PP := TC.POSS.POSSESS[ POSSX];
                PP.EQINDEX := 0;
                PP.IDENTIF := false;
                PP.CURSED  := false;
                PP.EQUIPED := false
              end;
            TC.POSS.POSSCNT := 0;
            TC.GOLD.XHIGH   := 0;
            TC.GOLD.XMID    := 0
          end;
        XGOTO    := XCHK4WIN;
        Write( Chr( 12));
        TEXTMODE;
        DONEFIGH := true     { EXIT(COMBAT) }
      end;


      procedure SMAKANIT;
      var
        ENEMYX : SmallInt;
        GROUPI : SmallInt;
        PT04L  : ^TTEMP04;
        XBRC   : ^TENEMY2;
        XBRA   : ^TENEMY2A;
        XBTB   : ^TENEMY;
      begin
        for GROUPI := 1 to 4 do
          begin
            XBRC := BATTLERC[ GROUPI];
            XBRA := XBRC.A;
            XBTB := XBRC.B;
            if XBRA.ALIVECNT > 0 then
              begin
                MVCURSOR( 1, 13);
                if XBRA.IDENTIFI then
                  PRINTSTR( XBTB.NAMES)
                else
                  PRINTSTR( XBTB.NAMEUNKS);
                if XBTB.XCLASS = 10 then
                  PRINTSTR( ' ARE UNAFFECTED!')
                else
                  if XBTB.HPREC.LEVEL > 7 then
                    PRINTSTR( ' SURVIVE!')
                  else
                    begin
                      PRINTSTR( ' PERISH!');
                      for ENEMYX := 0 to XBRA.ALIVECNT do
                        begin
                          PT04L := XBRA.TEMP04[ ENEMYX];
                          PT04L.HPLEFT  := 0;
                          SETXSTATUS_CB( PT04L, DEAD)
                        end
                    end;
                PAUSE1;
                CLRRECT( 1, 13, 38, 1)
              end
          end
      end;


      procedure SMALOR;
      begin
        MAZEX := Random(20);
        MAZEY := Random(20);
        while (Random(100)) < 30 do
          MAZELEV := MAZELEV - 1;
        while (Random(100)) < 10 do
          MAZELEV := MAZELEV - 1;
        if MAZELEV < SCNTOC.RECPERDK[ ZMAZE] then
          MAZELEV := SCNTOC.RECPERDK[ ZMAZE];
        CLRRECT( 13, 1, 26, 4);
        if MAZELEV = 0 then
          begin
            XGOTO := XCHK4WIN;
            Write( Chr( 12));
            TEXTMODE
          end
        else
          XGOTO := XNEWMAZE;
        DONEFIGH := true     { EXIT(COMBAT) }
      end;


      procedure DOPRIEST;
      var
        GROUPI : SmallInt;
        PT04L  : ^TTEMP04;
        XBRC0  : ^TENEMY2;
        XBRA0  : ^TENEMY2A;
        XBRC   : ^TENEMY2;
        XBRA   : ^TENEMY2A;
      begin
        XBRC0 := BATTLERC[ 0];
        XBRA0 := XBRC0.A;
        if SPELL = KALKI   then MODAC( 0, 1, 0, PARTYCNT - 1);
        if SPELL = DIOS    then DOHEAL( 0, CASTGR, 1, 8);
        if SPELL = BADIOS  then DOHITS( CASTGR, CASTI, 1, 8);
        if SPELL = MILWA   then
          LIGHT := LIGHT + 15 + (Random(15));
        if SPELL = PORFIC  then MODAC( 0, 4, BATI, BATI);
        if SPELL = MATU    then MODAC( 0, 2, 0, PARTYCNT - 1);
        if SPELL = MANIFO  then DOHOLD;
        if SPELL = MONTINO then DOSILENC;
        if SPELL = LOMILWA then LIGHT := 32000;
        if SPELL = DIALKO  then
          begin
            DSPNAMES( 0, CASTGR);
            PT04L := XBRA0.TEMP04[ CASTGR];
            if (Byte( PT04L.XSTATUS) = 3) or (Byte( PT04L.XSTATUS) = 2) then
              begin
                SETXSTATUS_CB( PT04L, OK);
                PRINTSTR( 'IS CURED!')
              end
            else
              PRINTSTR( 'IS NOT HELPED!')
          end;
        if SPELL = LATUMAPI then
          begin
            XBRC := BATTLERC[ LLBASE04];
            XBRA := XBRC.A;
            for GROUPI := 1 to 4 do
              XBRA.IDENTIFI := true   { AP bug preserved }
          end;
        if SPELL = BAMATU   then MODAC( 0, 4, 0, PARTYCNT - 1);
        if SPELL = DIAL     then DOHEAL( 0, CASTGR, 2, 8);
        if SPELL = BADIAL   then DOHITS( CASTGR, CASTI, 2, 8);
        if SPELL = LATUMOFI then
          begin
            DSPNAMES( 0, CASTGR);
            PRINTSTR( 'IS UNPOISONED!');
            CHARACTR[ CASTGR].LOSTXYL[ 1] := 0
          end;
        if SPELL = MAPORFIC then ACMOD2 := 2;
        if SPELL = DIALMA   then DOHEAL( 0, CASTGR, 3, 8);
        if SPELL = BADIALMA then DOHITS( CASTGR, CASTI, 3, 8);
        if SPELL = LITOKAN  then HITGROUP( CASTGR, 3, 8, 1);
        if SPELL = KANDI    then DODISRUP;
        if SPELL = DI       then DODISRUP;
        if SPELL = BADI     then DOSLAIN( CASTGR, CASTI);
        if SPELL = LORTO    then HITGROUP( CASTGR, 6, 6, 0);
        if SPELL = MADI     then
          begin
            PT04L := XBRA0.TEMP04[ CASTGR];
            PT04L.HPLEFT := CHARACTR[ CASTGR].HPMAX;
            if Byte( PT04L.XSTATUS) < 5 then
              SETXSTATUS_CB( PT04L, OK);
            CHARACTR[ CASTGR].LOSTXYL[ 1] := 0;
            DOHEAL( 0, CASTGR, 1, 1)
          end;
        if SPELL = MABADI then
          begin
            CLRRECT( 1, 12, 38, 3);
            MVCURSOR( 1, 12);
            DSPNAMES( CASTGR, CASTI);
            PRINTSTR( ' IS HIT BY MABADI!');
            XBRC := BATTLERC[ CASTGR];
            XBRA := XBRC.A;
            PT04L := XBRA.TEMP04[ CASTI];
            PT04L.HPLEFT := 1 + (Random(8))
          end;
        if SPELL = LOKTOFEI then SLOKTOFE;
        if SPELL = MALIKTO  then
          for GROUPI := 1 to 4 do
            HITGROUP( GROUPI, 12, 6, 0);
        if SPELL = KADORTO  then DODISRUP
      end;  { DOPRIEST }


      procedure DOMAGE;
      var
        GROUPI : SmallInt;
        XBRC   : ^TENEMY2;
        XBRA   : ^TENEMY2A;
        XBTB   : ^TENEMY;
        XBRCG  : ^TENEMY2;
        XBRAG  : ^TENEMY2A;
      begin
        XBRC := BATTLERC[ CASTGR];
        XBRA := XBRC.A;
        XBTB := XBRC.B;
        if SPELL = HALITO   then DOHITS( CASTGR, CASTI, 1, 8);
        if SPELL = MOGREF   then MODAC( 0, 2, BATI, BATI);
        if SPELL = KATINO   then DOSLEPT;
        if SPELL = DILTO    then
          MODAC( CASTGR, -2, 0, XBRA.ALIVECNT - 1);
        if SPELL = SOPIC    then MODAC( 0, 4, BATI, BATI);
        if SPELL = MAHALITO then HITGROUP( CASTGR, 4, 6, 1);
        if SPELL = MOLITO   then HITGROUP( CASTGR, 3, 6, 0);
        if SPELL = MORLIS   then
          MODAC( CASTGR, -3, 0, XBRA.ALIVECNT - 1);
        if SPELL = DALTO    then HITGROUP( CASTGR, 6, 6, 2);
        if SPELL = LAHALITO then HITGROUP( CASTGR, 6, 6, 1);
        if SPELL = MAMORLIS then
          for GROUPI := 1 to 4 do
            begin
              XBRCG := BATTLERC[ GROUPI];
              XBRAG := XBRCG.A;
              MODAC( GROUPI, -3, 1, XBRAG.ALIVECNT)
            end;
        if SPELL = MAKANITO then SMAKANIT;
        if SPELL = MADALTO  then HITGROUP( CASTGR, 8, 8, 2);
        if SPELL = LAKANITO then
          for GROUPI := 0 to XBRA.ALIVECNT - 1 do
            begin
              PT04 := XBRA.TEMP04[ GROUPI];
              if Byte( PT04.XSTATUS) < 5 then
                ISISNOT( CASTGR, GROUPI,
                         6 * XBTB.HPREC.LEVEL,
                         'SMOTHERED', 2)
            end;
        if SPELL = ZILWAN then
          if XBTB.XCLASS = 10 then
            DOHITS( CASTGR, CASTI, 10, 200);
        if SPELL = MASOPIC  then MODAC( 0, 4, 0, PARTYCNT - 1);
        if SPELL = HAMAN    then HAMMAHAM( 6);
        if SPELL = MALOR    then SMALOR;
        if SPELL = MAHAMAN  then HAMMAHAM( 7);
        if SPELL = TILTOWAI then
          if BATG = 0 then
            for GROUPI := 1 to 4 do
              HITGROUP( GROUPI, 10, 15, 0)
          else
            HITGROUP( 0, 10, 15, 0)
      end;  { DOMAGE }


      procedure EXITCAST( EXITSTR: string);
      begin
        MVCURSOR( 1, 12);
        PRINTSTR( EXITSTR);
        _exitca := true    { EXIT(CASTASPE) }
      end;


    begin  { CASTASPE }
      _exitca := false;
      CBRC := BATTLERC[ BATG];
      CBRA := CBRC.A;
      PT04 := CBRA.TEMP04[ BATI];
      DSPNAMES( BATG, BATI);
      PRINTSTR( 'CASTS A SPELL');
      if PT04.INAUDCNT > 0 then
        begin
          EXITCAST( 'WHICH FAILS TO BECOME AUDIBLE!');
          exit
        end;
      if FIZZLES > 0 then
        begin
          EXITCAST( 'WHICH FIZZLES OUT');
          exit
        end;
      if BATG = 0 then
        begin
          CASTGR := PT04.VICTIM;
          if (CASTGR > 0) and (CASTGR < 5) then
            begin
              CBRC := BATTLERC[ CASTGR];
              CBRA := CBRC.A;
              if CBRA.ALIVECNT > 0 then
                CASTI := BATI mod CBRA.ALIVECNT
            end;
          SPELL := PT04.SPELLHSH
        end
      else
        begin
          CASTGR := 0;
          CASTI  := PT04.VICTIM;
          SPELL  := PT04.SPELLHSH
        end;
      MVCURSOR( 1, 12);
      DOMAGE;
      if not DONEFIGH then
        DOPRIEST
    end;  { CASTASPE }


    { ── SWINGASW ── }

    procedure SWINGASW;
    var
      PT04   : ^TTEMP04;
      TC     : PTCHAR;
      BTB    : ^TENEMY;
      SBRC   : ^TENEMY2;
      SBRA   : ^TENEMY2A;


      procedure ARMATTK;
      begin
        case (Random(5)) of
          0: PRINTSTR( 'SWINGS');
          1: PRINTSTR( 'THRUSTS');
          2: PRINTSTR( 'STABS');
          3: PRINTSTR( 'SLASHES');
          4: PRINTSTR( 'CHOPS');
        end
      end;


      procedure PRNAME( GROUPI: SmallInt; CHARX: SmallInt);
      var
        XBRC : ^TENEMY2;
        XBRA : ^TENEMY2A;
        XBTB : ^TENEMY;
        TCN  : PTCHAR;
      begin
        if GROUPI = 0 then
          begin
            TCN := CHARACTR[ CHARX];
            PRINTSTR( TCN.NAME)
          end
        else
          begin
            XBRC := BATTLERC[ GROUPI];
            XBRA := XBRC.A;
            XBTB := XBRC.B;
            if XBRA.IDENTIFI then
              PRINTSTR( XBTB.NAME)
            else
              PRINTSTR( XBTB.NAMEUNK)
          end;
        PRINTSTR( ' ')
      end;


      procedure UNAFFECT( GROUPI: SmallInt; CHARI: SmallInt;
                          HITDAM: SmallInt);
      var
        XBRC : ^TENEMY2;
        XBRA : ^TENEMY2A;
        XBTB : ^TENEMY;
      begin
        CLRRECT( 1, 12, 38, 3);
        XBRC := BATTLERC[ GROUPI];
        XBRA := XBRC.A;
        PT04 := XBRA.TEMP04[ CHARI];
        if Byte( PT04.XSTATUS) >= 5 then
          exit;
        MVCURSOR( 1, 12);
        PRNAME( GROUPI, CHARI);
        if GROUPI <> 0 then
          begin
            XBTB := XBRC.B;
            if XBTB.UNAFFCT > (Random(100)) then
              HITDAM := 0
          end;
        if HITDAM = 0 then
          PRINTSTR( 'IS UNAFFECTED!')
        else
          begin
            PRINTSTR( 'TAKES ');
            PRINTNUM( HITDAM, 4);
            PRINTSTR( ' DAMAGE');
            PT04.HPLEFT := PT04.HPLEFT - HITDAM;
            if PT04.HPLEFT <= 0 then
              begin
                PT04.HPLEFT  := 0;
                SETXSTATUS_CB( PT04, DEAD);
                MVCURSOR( 1, 14);
                PRNAME( GROUPI, CHARI);
                PRINTSTR( 'IS SLAIN!')
              end
          end;
        PAUSE1
      end;


      function CALCHP( AHPREC: THPREC): SmallInt;
      var
        HITPTS : SmallInt;
      begin
        HITPTS := 0;
        while AHPREC.LEVEL > 0 do
          begin
            HITPTS       := HITPTS + (Random(AHPREC.HPFAC)) + 1;
            AHPREC.LEVEL := AHPREC.LEVEL - 1
          end;
        CALCHP := HITPTS + AHPREC.HPMINAD
      end;


      procedure DOBREATH;
      var
        HITDAM  : SmallInt;
        CHARX   : SmallInt;
        XBRC0   : ^TENEMY2;
        XBRA0   : ^TENEMY2A;
        PT04CH  : ^TTEMP04;
        XBTBG   : ^TENEMY;
      begin
        PRINTSTR( 'BREATHES!');
        PT04 := SBRA.TEMP04[ BATI];
        XBRC0 := BATTLERC[ 0];
        XBRA0 := XBRC0.A;
        for CHARX := 0 to PARTYCNT - 1 do
          begin
            PT04CH := XBRA0.TEMP04[ CHARX];
            if Byte( PT04CH.XSTATUS) < 5 then
              begin
                CLRRECT( 1, 12, 38, 3);
                MVCURSOR( 1, 12);
                HITDAM := PT04.HPLEFT div 2;
                TC := CHARACTR[ CHARX];
                if (Random(20)) >= TC.LUCKSKIL[ 3] then
                  HITDAM := (HITDAM + 1) div 2;
                if TC.WEPVSTY3[ 1, BTB.BREATHE] then
                  HITDAM := (HITDAM + 1) div 2;
                UNAFFECT( 0, CHARX, HITDAM)
              end
          end
      end;


      procedure DOFIGHT;

        procedure DAM2ME;
        var
          HPCALCPC : SmallInt;
          RECSI    : SmallInt;
          MYVICTIM : SmallInt;
          HPDAMAGE : SmallInt;
          HITSCNT  : SmallInt;
          PREC     : ^THPREC;
          TC2      : PTCHAR;
          XBRC0    : ^TENEMY2;
          XBRA0    : ^TENEMY2A;


          procedure CASEDAMG;

            procedure DRAINLEV;
            var
              PT04X : ^TTEMP04;
            begin
              TC2 := CHARACTR[ MYVICTIM];
              if TC2.WEPVSTY3[ 1, 4] then
                exit;
              TC2.CHARLEV := TC2.CHARLEV - BTB.DRAINAMT;
              MVCURSOR( 1, 14);
              CLRRECT( 1, 14, 38, 1);
              PRINTNUM( BTB.DRAINAMT, 2);
              if BTB.DRAINAMT = 1 then
                PRINTSTR( ' LEVEL')
              else
                PRINTSTR( ' LEVELS');
              PRINTSTR( ' ARE DRAINED!');
              if TC2.CHARLEV < 1 then
                begin
                  TC2.CHARLEV := 0;
                  PT04X := XBRA0.TEMP04[ MYVICTIM];
                  PT04X.HPLEFT  := 0;
                  SETXSTATUS_CB( PT04X, LOST)
                end
              else
                begin
                  TC2.HPMAX := (TC2.HPMAX div TC2.MAXLEVAC) * TC2.CHARLEV;
                  TC2.MAXLEVAC := TC2.CHARLEV;
                  if TC2.HPLEFT > TC2.HPMAX then
                    TC2.HPLEFT := TC2.HPMAX;
                  DRAINED[ MYVICTIM] := true
                end;
              PAUSE1
            end;


            procedure RESULT( ATTK0123: SmallInt; STONFLAG: SmallInt;
                              POISSTON: SmallInt; DAMSTR: string);
            var
              CHANCBAD : SmallInt;
            begin
              TC2 := CHARACTR[ MYVICTIM];
              if (Random(20)) > TC2.LUCKSKIL[ STONFLAG] then
                exit;
              if ATTK0123 = 3 then
                begin
                  CHANCBAD := BTB.HPREC.LEVEL * 2;
                  if CHANCBAD > 50 then
                    CHANCBAD := 50;
                  if (Random(100)) > CHANCBAD then
                    exit
                end;
              if POISSTON > 0 then
                if TC2.WEPVSTY3[ 1, POISSTON] then
                  exit;
              if Byte( TC2.STATUS) >= 5 then
                exit;
              CLRRECT( 1, 14, 38, 1);
              MVCURSOR( 1, 14);
              PRNAME( 0, MYVICTIM);
              PRINTSTR( 'IS ');
              PRINTSTR( DAMSTR);
              PT04 := XBRA0.TEMP04[ MYVICTIM];
              case Byte( ATTK0123) of
                0: if Byte( PT04.XSTATUS) < 4 then
                     SETXSTATUS_CB( PT04, STONED);
                1: TC2.LOSTXYL[ 1] := 1;
                2: if Byte( PT04.XSTATUS) < 3 then
                     SETXSTATUS_CB( PT04, PLYZE);
                3: begin
                     SETXSTATUS_CB( PT04, DEAD);
                     PT04.HPLEFT  := 0
                   end;
              end;
              PAUSE1
            end;


          begin  { CASEDAMG }
            BTB := SBRC.B;
            if BTB.SPPC[ 1] then RESULT( 1, 0, 3, 'POISONED');
            if BTB.SPPC[ 2] then RESULT( 2, 0, 0, 'PARALYZED');
            if BTB.SPPC[ 0] then RESULT( 0, 1, 5, 'STONED');
            if BTB.DRAINAMT > 0 then DRAINLEV;
            if BTB.SPPC[ 3] then RESULT( 3, 0, 0, 'CRITICALLY HIT')
          end;  { CASEDAMG }


          procedure ATTKSTRG;

            procedure RIPBITCL;
            begin
              case (Random(5)) of
                0: PRINTSTR( 'TEARS');
                1: PRINTSTR( 'RIPS');
                2: PRINTSTR( 'GNAWS');
                3: PRINTSTR( 'BITES');
                4: PRINTSTR( 'CLAWS');
              end
            end;

            procedure ARMRIP;
            begin
              if (Random(2)) = 1 then RIPBITCL else ARMATTK
            end;

          begin  { ATTKSTRG }
            case Byte( BTB.XCLASS) of
              0, 1, 2, 3, 4, 5, 10, 11: ARMATTK;
                          6, 8, 12, 13: RIPBITCL;
                                  7, 9: ARMRIP;
            end
          end;


        begin  { DAM2ME }
          XBRC0 := BATTLERC[ 0];
          XBRA0 := XBRC0.A;
          PT04 := XBRA0.TEMP04[ VICTIM];
          if Byte( PT04.XSTATUS) >= 5 then
            exit;
          PRNAME( BATG, BATI);
          ATTKSTRG;
          PRINTSTR( ' AT');
          MVCURSOR( 1, 12);
          TC2 := CHARACTR[ VICTIM];
          PRINTSTR( TC2.NAME);
          MYVICTIM := VICTIM;
          PT04 := XBRA0.TEMP04[ MYVICTIM];
          if Byte( PT04.XSTATUS) < 5 then
            begin
              HPCALCPC :=
                20
                - CHARACTR[ MYVICTIM].ARMORCL
                - BTB.HPREC.LEVEL
                + ACMOD2
                + PT04.ARMORCL
                + 2 * Ord( PT04.SPELLHSH = 0);
              if HPCALCPC < 1 then
                HPCALCPC := 1
              else if HPCALCPC > 19 then
                HPCALCPC := 19;
              HPDAMAGE := 0;
              HITSCNT  := 0;
              MVCURSOR( 1, 13);
              for RECSI := 1 to BTB.RECSN do
                if (Random(20)) >= HPCALCPC then
                  begin
                    PREC := BTB.RECS[ RECSI];
                    HPDAMAGE := HPDAMAGE + CALCHP( PREC^);
                    HITSCNT  := HITSCNT + 1
                  end;
              if Byte( PT04.XSTATUS) = 2 then
                HPDAMAGE := HPDAMAGE * 2;
              if HPDAMAGE = 0 then
                PRINTSTR( 'AND MISSES!')
              else
                begin
                  PRINTSTR( 'AND HITS ');
                  PRINTNUM( HITSCNT, 3);
                  PRINTSTR( ' TIMES FOR ');
                  PRINTNUM( HPDAMAGE, 3);
                  PRINTSTR( ' DAMAGE');
                  CASEDAMG
                end;
              PT04.HPLEFT := PT04.HPLEFT - HPDAMAGE;
              if PT04.HPLEFT <= 0 then
                begin
                  CLRRECT( 1, 14, 38, 1);
                  MVCURSOR( 1, 14);
                  TC2 := CHARACTR[ MYVICTIM];
                  PRINTSTR( TC2.NAME);
                  PRINTSTR( ' IS SLAIN!');
                  PT04.HPLEFT := 0;
                  if Byte( PT04.XSTATUS) < 5 then
                    SETXSTATUS_CB( PT04, DEAD)
                end
            end
        end;  { DAM2ME }


        procedure DAM2ENMY;
        var
          HPCALCPC : SmallInt;
          TEMPX    : SmallInt;
          SINGLEX  : SmallInt;
          HPDAMAGE : SmallInt;
          HITSCNT  : SmallInt;
          PT04V    : ^TTEMP04;
          TC2      : PTCHAR;
          XBRCV    : ^TENEMY2;
          XBRAV    : ^TENEMY2A;
          XBTBV    : ^TENEMY;
        begin
          XBRCV := BATTLERC[ VICTIM];
          XBRAV := XBRCV.A;
          XBTBV := XBRCV.B;
          SINGLEX := BATI mod XBRAV.ALIVECNT;
          PT04V   := XBRAV.TEMP04[ SINGLEX];
          if Byte( PT04V.XSTATUS) < 5 then
            begin
              PRNAME( BATG, BATI);
              ARMATTK;
              PRINTSTR( ' AT A');
              MVCURSOR( 1, 12);
              PRNAME( VICTIM, BATI);
              TC2 := CHARACTR[ BATI];
              HPCALCPC := 21
                          - XBTBV.AC
                          - TC2.HPCALCMD
                          + PT04V.ARMORCL
                          - 3 * VICTIM;
              if HPCALCPC < 1 then
                HPCALCPC := 1
              else if HPCALCPC > 19 then
                HPCALCPC := 19;
              HPDAMAGE := 0;
              MVCURSOR( 1, 13);
              HITSCNT := 0;
              for TEMPX := 1 to TC2.SWINGCNT do
                if (Random(20)) >= HPCALCPC then
                  begin
                    HPDAMAGE := HPDAMAGE + CALCHP( TC2.HPDAMRC);
                    HITSCNT  := HITSCNT + 1
                  end;
              if Byte( PT04V.XSTATUS) = 2 then
                HPDAMAGE := 2 * HPDAMAGE;
              if TC2.WEPVSTYP[ XBTBV.XCLASS] then
                HPDAMAGE := 2 * HPDAMAGE;
              if HPDAMAGE = 0 then
                PRINTSTR( 'AND MISSES')
              else
                begin
                  PRINTSTR( 'AND HITS ');
                  PRINTNUM( HITSCNT, 3);
                  PRINTSTR( ' TIMES FOR ');
                  PRINTNUM( HPDAMAGE, 3);
                  PRINTSTR( ' DAMAGE!')
                end;
              PT04V.HPLEFT := PT04V.HPLEFT - HPDAMAGE;
              if TC2.CRITHITM and (HPDAMAGE > 0) then
                begin
                  TEMPX := TC2.CHARLEV * 2;
                  if TEMPX > 50 then TEMPX := 50;
                  if (Random(100)) < TEMPX then
                    if (Random(35)) >
                       XBTBV.HPREC.LEVEL + 10 then
                      begin
                        MVCURSOR( 1, 14);
                        PRINTSTR( 'A CRITICAL HIT!');
                        PT04V.HPLEFT := 0;
                        PAUSE1;
                        CLRRECT( 1, 14, 38, 1)
                      end
                end;
              if PT04V.HPLEFT <= 0 then
                begin
                  MVCURSOR( 1, 14);
                  PRNAME( 0, BATI);
                  PRINTSTR( 'KILLS ONE!');
                  PT04V.HPLEFT  := 0;
                  SETXSTATUS_CB( PT04V, DEAD)
                end
            end
        end;  { DAM2ENMY }


      begin  { DOFIGHT }
        if BATG = 0 then
          DAM2ENMY
        else
          DAM2ME
      end;  { DOFIGHT }


      procedure YELLHELP;
      var
        YHTEMP2  : SmallInt;
        PT04Y    : ^TTEMP04;
        PT04BI   : ^TTEMP04;
        _exityh  : Boolean;

        procedure NONECOME;
        begin
          PRINTSTR( 'BUT NONE COMES!');
          _exityh := true
        end;

      begin  { YELLHELP }
        _exityh := false;
        PRINTSTR( 'CALLS FOR HELP!');
        MVCURSOR( 1, 12);
        if SBRA.ALIVECNT = 9 then
          NONECOME;
        if not _exityh then
          if (Random(200)) > 10 * BTB.HPREC.LEVEL then
            NONECOME;
        if not _exityh then
          begin
            PRINTSTR( 'AND IS HEARD!');
            YHTEMP2 := SBRA.ALIVECNT;
            SBRA.ALIVECNT := YHTEMP2 + 1;
            SBRA.ENMYCNT  := SBRA.ENMYCNT + 1;
            PT04Y := SBRA.TEMP04[ YHTEMP2];
            PT04Y.AGILITY  := -1;
            PT04Y.SPELLHSH := 0;
            PT04BI := SBRA.TEMP04[ BATI];
            PT04Y.INAUDCNT := PT04BI.INAUDCNT;
            PT04Y.ARMORCL  := 0;
            PT04Y.HPLEFT   := CALCHP( BTB.HPREC);
            SETXSTATUS_CB( PT04Y, OK)
          end
      end;  { YELLHELP }


      procedure DORUN;
      begin
        PRINTSTR( 'FLEES!');
        SBRA.ENMYCNT := SBRA.ENMYCNT - 1;
        PT04 := SBRA.TEMP04[ BATI];
        SETXSTATUS_CB( PT04, DEAD);
        PT04.HPLEFT  := 0
      end;


      procedure DODISPEL;
      var
        DISPLCNT : SmallInt;
        CHARX    : SmallInt;
        DISPCALC : SmallInt;
        PT04D    : ^TTEMP04;
        TC2      : PTCHAR;
        XBRCV    : ^TENEMY2;
        XBRAV    : ^TENEMY2A;
        XBTBV    : ^TENEMY;
      begin
        PRINTSTR( 'DISPELLS!');
        XBRCV := BATTLERC[ VICTIM];
        XBRAV := XBRCV.A;
        XBTBV := XBRCV.B;
        TC2 := CHARACTR[ BATI];
        DISPCALC := 50 + 5 * TC2.CHARLEV -
                    10 * XBTBV.HPREC.LEVEL;
        case Byte( TC2.XCLASS) of
          6: DISPCALC := DISPCALC - 40;  { LORD }
          4: DISPCALC := DISPCALC - 20;  { BISHOP }
        end;
        DISPLCNT := 0;
        for CHARX := 0 to XBRAV.ALIVECNT - 1 do
          begin
            PT04D := XBRAV.TEMP04[ CHARX];
            if Byte( PT04D.XSTATUS) = 0 then
              if (Random(100)) < DISPCALC then
                if XBTBV.XCLASS = 10 then
                  begin
                    DISPLCNT := DISPLCNT + 1;
                    XBRAV.ENMYCNT := XBRAV.ENMYCNT - 1;
                    SETXSTATUS_CB( PT04D, DEAD);
                    PT04D.HPLEFT  := 0
                  end
          end;
        MVCURSOR( 1, 12);
        if DISPLCNT = 0 then
          PRINTSTR( 'TO NO AVAIL!')
        else
          if DISPLCNT = 1 then
            PRINTSTR( '1 DISSOLVES!')
          else
            begin
              PRINTNUM( DISPLCNT, 1);
              PRINTSTR( ' DISSOLVE!')
            end
      end;


    begin  { SWINGASW }
      SBRC := BATTLERC[ BATG];
      SBRA := SBRC.A;
      BTB  := SBRC.B;
      if ATTACKTY < -1 then
        PRNAME( BATG, BATI);
      if ATTACKTY = -5 then DODISPEL
      else if ATTACKTY = -4 then YELLHELP
      else if ATTACKTY = -3 then DOBREATH
      else if ATTACKTY = -2 then DORUN
      else if ATTACKTY = -1 then DOFIGHT
    end;  { SWINGASW }


  begin  { MELEE }
    for AGILELEV := 1 to 10 do
      for BATG := 0 to 4 do
        begin
          MBRC := BATTLERC[ BATG];
          MBRA := MBRC.A;
          for BATI := 0 to MBRA.ALIVECNT - 1 do
            begin
              PT04 := MBRA.TEMP04[ BATI];
              if (Byte( PT04.XSTATUS) = 0) and
                 (PT04.AGILITY = AGILELEV) then
                begin
                  VICTIM   := PT04.VICTIM;
                  ATTACKTY := PT04.SPELLHSH;
                  MVCURSOR( 1, 11);
                  if (ATTACKTY >= -5) and (ATTACKTY < 0) then
                    SWINGASW
                  else if ATTACKTY > 0 then
                    CASTASPE;
                  if ATTACKTY <> 0 then
                    begin
                      PAUSE1;
                      CLRRECT( 1, 11, 38, 4)
                    end
                end
            end
        end
  end;  { MELEE }


  { ── COMBAT main ──────────────────────────────────────────────────── }

  procedure ALLOC_BATTLERC;
  var
    I   : SmallInt;
    J   : SmallInt;
    BRC : ^TENEMY2;
    BRA : ^TENEMY2A;
    BRB : ^TENEMY;
  begin
    for I := 0 to 4 do
      begin
        GetMem( BATTLERC[ I]);
        BRC := BATTLERC[ I];
        FillChar( BRC^, SizeOf( TENEMY2), 0);
        GetMem( BRC.A);
        GetMem( BRC.B);
        BRA := BRC.A;
        BRB := BRC.B;
        FillChar( BRA^, SizeOf( TENEMY2A), 0);
        FillChar( BRB^, SizeOf( TENEMY),   0);
        for J := 0 to 8 do
          begin
            GetMem( BRA.TEMP04[ J]);
            FillChar( BRA.TEMP04[ J]^, SizeOf( TTEMP04), 0)
          end;
        for J := 1 to 7 do
          begin
            GetMem( BRB.RECS[ J]);
            FillChar( BRB.RECS[ J]^, SizeOf( THPREC), 0)
          end
      end
  end;


begin  { COMBAT }
  ALLOC_BATTLERC;
  DONEFIGH := false;
  CINITFL1 := 0;
  CINIT;
  if DONEFIGH then exit;   { FRIENDLY chose to leave }
  XGOTO := XREWARD;
  repeat
    CUTIL;
    if not DONEFIGH then
      MELEE
  until DONEFIGH;
  CINITFL1 := 2;
  CINIT
end;  { COMBAT }


end.
