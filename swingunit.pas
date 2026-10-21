unit SWINGUNIT;

{ Wizardry I — COMBAT's SWINGASW (AP P010901): one combatant fights,
  breathes, runs, calls for help or dispels.  An overlay of its own, run by
  the resident MELEE loop (WIZRES) for each such combatant with BATG, BATI,
  VICTIM, ATTACKTY set in COMBATG.
  Source: apple/Wizardry_v3-2/Wiz1B.DSK/COMBAT5 (v3.2). }

interface

uses TYPES, CONSTS, GLOBALS, UTIL, SCREEN, COMBATG;

procedure SWING;

implementation


procedure SETXSTATUS_CB( PT: PTTEMP04; V: TSTATUS);
begin
  PT^.XSTATUS := TSTATUS( Byte( V))
end;


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
        XBRA := XBRC^.A;
        XBTB := XBRC^.B;
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
    XBRA := XBRC^.A;
    PT04 := XBRA.TEMP04[ CHARI];
    if Byte( PT04^.XSTATUS) >= 5 then
      exit;
    MVCURSOR( 1, 12);
    PRNAME( GROUPI, CHARI);
    if GROUPI <> 0 then
      begin
        XBTB := XBRC^.B;
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
    XBRA0 := XBRC0^.A;
    for CHARX := 0 to PARTYCNT - 1 do
      begin
        PT04CH := XBRA0.TEMP04[ CHARX];
        if Byte( PT04CH^.XSTATUS) < 5 then
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

    procedure HITPROB( HITP: SmallInt);               { v3.2 WC018 }
    begin
      PRINTSTR( 'WITH A HIT PROB OF ');
      PRINTNUM( (20 - HITP) * 5, 2);
      PRINTSTR( '%')
    end;

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
          if DRAINED[ MYVICTIM] or TC2.WEPVSTY3[ 1, 4] then   { v3.2 WC027 }
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
          if Byte( TC2^.STATUS) >= 5 then
            exit;
          CLRRECT( 1, 14, 38, 1);
          MVCURSOR( 1, 14);
          PRNAME( 0, MYVICTIM);
          PRINTSTR( 'IS ');
          PRINTSTR( DAMSTR);
          PT04 := XBRA0.TEMP04[ MYVICTIM];
          case Byte( ATTK0123) of
            0: if Byte( PT04^.XSTATUS) < 4 then
                 SETXSTATUS_CB( PT04, STONED);
            1: TC2.LOSTXYL[ 1] := 1;
            2: if Byte( PT04^.XSTATUS) < 3 then
                 SETXSTATUS_CB( PT04, PLYZE);
            3: begin
                 SETXSTATUS_CB( PT04, DEAD);
                 PT04.HPLEFT  := 0
               end;
          end;
          PAUSE1
        end;


      begin  { CASEDAMG }
        BTB := SBRC^.B;
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
      XBRA0 := XBRC0^.A;
      PT04 := XBRA0.TEMP04[ VICTIM];
      if Byte( PT04^.XSTATUS) >= 5 then
        exit;
      PRNAME( BATG, BATI);
      ATTKSTRG;
      PRINTSTR( ' AT');
      MVCURSOR( 1, 12);
      TC2 := CHARACTR[ VICTIM];
      PRINTSTR( TC2.NAME);
      MYVICTIM := VICTIM;
      PT04 := XBRA0.TEMP04[ MYVICTIM];
      if Byte( PT04^.XSTATUS) < 5 then
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
          PRINTSTR( ' ');                             { v3.2 WC018 }
          HITPROB( HPCALCPC);
          MVCURSOR( 1, 13);
          for RECSI := 1 to BTB.RECSN do
            if (Random(20)) >= HPCALCPC then
              begin
                PREC := BTB.RECS[ RECSI];
                HPDAMAGE := HPDAMAGE + CALCHP( PREC^);
                HITSCNT  := HITSCNT + 1
              end;
          if Byte( PT04^.XSTATUS) = 2 then
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
              if Byte( PT04^.XSTATUS) < 5 then
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
      XBRAV := XBRCV^.A;
      XBTBV := XBRCV^.B;
      SINGLEX := BATI mod XBRAV.ALIVECNT;
      PT04V   := XBRAV.TEMP04[ SINGLEX];
      if Byte( PT04V^.XSTATUS) < 5 then
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
                      + ((3 * VICTIM) - 6);           { v3.2 WC015 }
          if HPCALCPC < 1 then
            HPCALCPC := 1
          else if HPCALCPC > 19 then
            HPCALCPC := 19;
          HPDAMAGE := 0;
          HITSCNT  := 0;
          HITPROB( HPCALCPC);                         { v3.2 WC018 }
          MVCURSOR( 1, 13);
          for TEMPX := 1 to TC2^.SWINGCNT do
            if (Random(20)) >= HPCALCPC then
              begin
                HPDAMAGE := HPDAMAGE + CALCHP( TC2.HPDAMRC);
                HITSCNT  := HITSCNT + 1
              end;
          if Byte( PT04V^.XSTATUS) = 2 then
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
                    Write( Chr( 7)); Write( Chr( 7)); Write( Chr( 7));   { v3.2 WC008 }
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
    PRINTSTR( 'DISPELS!');                            { v3.2 WC002 }
    XBRCV := BATTLERC[ VICTIM];
    XBRAV := XBRCV^.A;
    XBTBV := XBRCV^.B;
    TC2 := CHARACTR[ BATI];
    DISPCALC := 50 + 5 * TC2.CHARLEV -
                10 * XBTBV.HPREC.LEVEL;
    case Byte( TC2^.XCLASS) of
      6: DISPCALC := DISPCALC - 40;  { LORD }
      4: DISPCALC := DISPCALC - 20;  { BISHOP }
    end;
    DISPLCNT := 0;
    for CHARX := 0 to XBRAV.ALIVECNT - 1 do
      begin
        PT04D := XBRAV.TEMP04[ CHARX];
        if Byte( PT04D^.XSTATUS) < 5 then              { v3.2 WC011: < DEAD }
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
  SBRA := SBRC^.A;
  BTB  := SBRC^.B;
  if ATTACKTY < -1 then
    PRNAME( BATG, BATI);
  if ATTACKTY = -5 then DODISPEL
  else if ATTACKTY = -4 then YELLHELP
  else if ATTACKTY = -3 then DOBREATH
  else if ATTACKTY = -2 then DORUN
  else if ATTACKTY = -1 then DOFIGHT
end;  { SWINGASW }


procedure SWING;                                  { AP MELEE, for a swinger }
begin
  CMBEXIT := UNWNONE;
  MVCURSOR( 1, 11);
  SWINGASW;
  PAUSE1;
  CLRRECT( 1, 11, 38, 4)
end;


end.
