unit CASTUNIT;

{ Wizardry I — COMBAT's CASTASPE (AP P010801): one combatant casts.  An
  overlay of its own, run by the resident MELEE loop (WIZRES) for each
  caster with BATG, BATI, VICTIM, ATTACKTY set in COMBATG.
  Source: apple/Wizardry_v3-2/Wiz1B.DSK/COMBAT4 (v3.2). }

interface

uses TYPES, CONSTS, GLOBALS, UTIL, SCREEN, COMBATG;

procedure CAST;

implementation


const
  U_CASTASPE = $08;       { unwind target: AP P010801 (U_COMBAT: COMBATG) }

  { v3.2 WC020 SHOWMP (AP WIZ2): the spell name for a hash, in combat only. }
  SHOWH : array[ 0..49] of SmallInt = (
    4178, 2409, 3983, 3245, 3340, 1953, 6181, 4731, 4744, 3180,
    6156, 7525, 6612, 4925, 6587, 4573, 3990, 1562, 3128, 2597,
    11157, 1449, 2301, 3675, 2889, 2287, 3139, 1717, 2619, 5970,
    5333, 2718, 6491, 5169,  761, 1253, 9463, 4322, 1614, 2446,
    4396, 1885,  180,  382, 4296,  547,  759, 8330, 5514, 6673);
  SHOWN : array[ 0..49] of string[ 9] = (
    'HALITO', 'MOGREF', 'KATINO', 'DUMAPIC', 'DILTO', 'SOPIC', 'MAHALITO',
    'MOLITO', 'MORLIS', 'DALTO', 'LAHALITO', 'MAMORLIS', 'MAKANITO',
    'MADALTO', 'LAKANITO', 'ZILWAN', 'MASOPIC', 'HAMAN', 'MALOR', 'MAHAMAN',
    'TILTOWAIT', 'KALKI', 'DIOS', 'BADIOS', 'MILWA', 'PORFIC', 'MATU',
    'CALFO', 'MANIFO', 'MONTINO', 'LOMILWA', 'DIALKO', 'LATUMAPIC', 'BAMATU',
    'DIAL', 'BADIAL', 'LATUMOFIS', 'MAPORFIC', 'DIALMA', 'BADIALMA',
    'LITOKAN', 'KANDI', 'DI', 'BADI', 'LORTO', 'MADI', 'MABADI', 'LOKTOFEIT',
    'MALIKTO', 'KADORTO');
procedure SHOWMP( SPELLINT: SmallInt);
var
  I : Byte;
begin
  for I := 0 to 49 do
    if SHOWH[ I] = SPELLINT then PRINTSTR( SHOWN[ I])
end;

procedure SETXSTATUS_CB( PT: PTTEMP04; V: TSTATUS);
begin
  PT^.XSTATUS := TSTATUS( Byte( V))
end;


function CASTASPE: Byte;                         { UNWNONE or U_COMBAT }
var
  SPELL   : SmallInt;
  CASTI   : SmallInt;
  CASTGR  : SmallInt;
  PT04    : ^TTEMP04;
  TC      : PTCHAR;
  BTB     : ^TENEMY;
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
        XBRA := XBRC^.A;
        XBTB := XBRC^.B;
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
    XBRA := XBRC^.A;
    PT04 := XBRA.TEMP04[ CHARX];
    if Byte( PT04^.XSTATUS) >= 5 then
      exit;
    MVCURSOR( 1, 12);
    DSPNAMES( GROUPI, CHARX);
    if GROUPI <> 0 then
      begin
        XBTB := XBRC^.B;
        if XBTB.UNAFFCT > (RNDN(100)) then
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
    XBRA := XBRC^.A;
    PT04 := XBRA.TEMP04[ CHARI];
    if (RNDN(100)) < ISNOTCHN then
      PRINTSTR( 'IS NOT ')
    else
      begin
        PRINTSTR( 'IS ');
        case Byte( DAMTYPE) of
          0: SETXSTATUS_CB( PT04, PLYZE);             { v3.2 WC014 }
          1: PT04.INAUDCNT := (RNDN(4)) + 2;
          2: begin
               SETXSTATUS_CB( PT04, DEAD);
               PT04.HPLEFT  := 0
             end;
          3: SETXSTATUS_CB( PT04, ASLEEP);
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
        POINTS := POINTS + (RNDN(HITRANGE)) + 1;
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
    XBRA := XBRC^.A;
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
    XBRA := XBRC^.A;
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
        XBTB := XBRC^.B;
        if XBTB.UNAFFCT > 0 then
          if (RNDN(100)) < XBTB.UNAFFCT then
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
    XBRA := XBRC^.A;
    XBTB := XBRC^.B;
    for CHARX := 0 to XBRA.ALIVECNT - 1 do
      begin
        PT04 := XBRA.TEMP04[ CHARX];
        if Byte( PT04^.XSTATUS) <= 2 then
          if CASTGR = 0 then
            ISISNOT( CASTGR, CHARX,
                     50 + 10 * CHARACTR[ CHARX].CHARLEV,
                     'HELD', 0)
          else
            ISISNOT( CASTGR, CHARX,
                     50 + 5 * XBTB.HPREC.LEVEL,       { v3.2 WC014 }
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
    XBRA := XBRC^.A;
    XBTB := XBRC^.B;
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
        XBTB := XBRC^.B;
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
    XBRA := XBRC^.A;
    XBTB := XBRC^.B;
    for CHARX := 0 to XBRA.ALIVECNT - 1 do
      begin
        PT04 := XBRA.TEMP04[ CHARX];
        if Byte( PT04^.XSTATUS) < 2 then
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
          if Byte( PT04L^.XSTATUS) < 5 then
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
          XBRA := XBRC^.A;
          for TEMP2 := 0 to XBRA.ALIVECNT - 1 do
            begin
              PT04L := XBRA.TEMP04[ TEMP2];
              PT04L.INAUDCNT := 5 + (RNDN(5))
            end
        end
    end;

    procedure HAMMAGIC;
    begin
      PRINTSTR( 'ZAPS MONSTER MAGIC RESISTANCE!');
      for TEMP1 := 1 to 3 do
        begin
          XBRC := BATTLERC[ TEMP1];
          XBTB := XBRC^.B;
          XBTB.UNAFFCT := 0
        end
    end;

    procedure HAMTELEP;
    begin
      PRINTSTR( 'DESTROYS MONSTERS!');
      for TEMP1 := 1 to 4 do
        begin
          XBRC := BATTLERC[ TEMP1];
          XBRA := XBRC^.A;
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
          if Byte( PT04L^.XSTATUS) < 5 then
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
      PRINTSTR( 'RESURRECTS AND ');                 { v3.2 WC035 }
      for TEMP1 := 0 to PARTYCNT - 1 do
        begin
          PT04L := XBRA0.TEMP04[ TEMP1];
          if Byte( PT04L^.XSTATUS) <> 7 then
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
        if (RNDN(100)) > 50 then
          SKNS^[ SPELLI] := false
    end;

  begin  { HAMMAHAM }
    XBRC0 := BATTLERC[ 0];
    XBRA0 := XBRC0^.A;
    if MAHAMFLG = 8 then                            { v3.2 WC006 }
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
    case Byte( RNDN( 3 * MAHAMFLG)) of             { v3.2 WC006 }
        0,  1,  2,  3,  4,  5: HAMCURE;
            7,  8,  9, 10, 11: HAMSILEN;
               12, 13, 22, 23: HAMMAGIC;
                   14, 20, 21: HAMTELEP;
                    6, 15, 19: HAMHEAL;
                           17: HAMPROT;
                       16, 18: HAMALIVE;
    end;
    BCHARLEV := CHARACTR[ BATI].CHARLEV;
    if RNDN( BCHARLEV) = 5 then
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
    XBRA := XBRC^.A;
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
              BTB := XBRC^.B;
              if BTB.WEPVSTY3[ TEMP99I] then
                DOHITS( GROUPI, CHARI, HITSX div 2 + 1, HITSR)
              else
                DOHITS( GROUPI, CHARI, HITSX, HITSR)
            end
        end
  end;


  function SLOKTOFE: Byte;
  var
    POSSX  : SmallInt;
    TEMPXX : SmallInt;
    TC     : PTCHAR;
    PP     : ^TPOSSESS;
  begin
    SLOKTOFE := UNWNONE;
    if (RNDN(100)) > 2 * CHARACTR[ BATI].CHARLEV then
      begin
        MVCURSOR( 1, 13);
        PRINTSTR( 'LOKTOFEIT FAILS!');
        exit
      end;
    for TEMPXX := 0 to PARTYCNT - 1 do
      begin
        TC := CHARACTR[ TEMPXX];
        for POSSX := 1 to TC^.POSS.POSSCNT do
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
    SLOKTOFE := U_COMBAT                              { EXIT( COMBAT) }
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
        XBRA := XBRC^.A;
        XBTB := XBRC^.B;
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
                  for ENEMYX := 0 to XBRA^.ALIVECNT do
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


  function SMALOR: Byte;
  begin
    MAZEX := RNDN(20);
    MAZEY := RNDN(20);
    while (RNDN(100)) < 30 do
      MAZELEV := MAZELEV - 1;
    while (RNDN(100)) < 10 do
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
    SMALOR := U_COMBAT                                { EXIT( COMBAT) }
  end;


  function DOPRIEST: Byte;                       { UNWNONE or U_COMBAT }
  var
    GROUPI : SmallInt;
    PT04L  : ^TTEMP04;
    XBRC0  : ^TENEMY2;
    XBRA0  : ^TENEMY2A;
    XBRC   : ^TENEMY2;
    XBRA   : ^TENEMY2A;
  begin
    Result := UNWNONE;
    XBRC0 := BATTLERC[ 0];
    XBRA0 := XBRC0^.A;
    if SPELL = KALKI   then MODAC( 0, 1, 0, PARTYCNT - 1);
    if SPELL = DIOS    then DOHEAL( 0, CASTGR, 1, 8);
    if SPELL = BADIOS  then DOHITS( CASTGR, CASTI, 1, 8);
    if SPELL = MILWA   then
      LIGHT := LIGHT + 15 + (RNDN(15));
    if SPELL = PORFIC  then MODAC( 0, 4, BATI, BATI);
    if SPELL = MATU    then MODAC( 0, 2, 0, PARTYCNT - 1);
    if SPELL = MANIFO  then DOHOLD;
    if SPELL = MONTINO then DOSILENC;
    if SPELL = LOMILWA then LIGHT := 32000;
    if SPELL = DIALKO  then
      begin
        DSPNAMES( 0, CASTGR);
        PT04L := XBRA0.TEMP04[ CASTGR];
        if (Byte( PT04L^.XSTATUS) = 3) or (Byte( PT04L^.XSTATUS) = 2) then
          begin
            SETXSTATUS_CB( PT04L, OK);
            PRINTSTR( 'IS CURED!')
          end
        else
          PRINTSTR( 'IS NOT HELPED!')
      end;
    if SPELL = LATUMAPI then
      for GROUPI := 1 to 4 do
        begin
          XBRC := BATTLERC[ GROUPI];                  { v3.2 WC003 }
          XBRA := XBRC^.A;
          XBRA.IDENTIFI := true
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
        if Byte( PT04L^.XSTATUS) < 5 then
          SETXSTATUS_CB( PT04L, OK);
        CHARACTR[ CASTGR].LOSTXYL[ 1] := 0;
        DOHEAL( 0, CASTGR, 1, 1)
      end;
    if SPELL = MABADI then
      begin
        XBRC := BATTLERC[ CASTGR];
        XBRA := XBRC^.A;
        PT04L := XBRA.TEMP04[ CASTI];
        if Byte( PT04L^.XSTATUS) < 5 then              { v3.2 WC013 }
          begin
            CLRRECT( 1, 12, 38, 3);
            MVCURSOR( 1, 12);
            DSPNAMES( CASTGR, CASTI);
            PRINTSTR( 'IS HIT BY MABADI!');
            PT04L.HPLEFT := 1 + (RNDN(8))
          end
      end;
    if SPELL = LOKTOFEI then
      if SLOKTOFE = U_COMBAT then exit( U_COMBAT);
    if SPELL = MALIKTO  then
      for GROUPI := 1 to 4 do
        HITGROUP( GROUPI, 12, 6, 0);
    if SPELL = KADORTO  then DODISRUP
  end;  { DOPRIEST }


  function DOMAGE: Byte;                         { UNWNONE or U_COMBAT }
  var
    GROUPI : SmallInt;
    XBRC   : ^TENEMY2;
    XBRA   : ^TENEMY2A;
    XBTB   : ^TENEMY;
    XBRCG  : ^TENEMY2;
    XBRAG  : ^TENEMY2A;
  begin
    Result := UNWNONE;
    XBRC := BATTLERC[ CASTGR];
    XBRA := XBRC^.A;
    XBTB := XBRC^.B;
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
          XBRAG := XBRCG^.A;
          MODAC( GROUPI, -3, 0, XBRAG.ALIVECNT - 1)  { v3.2 WC012 }
        end;
    if SPELL = MAKANITO then SMAKANIT;
    if SPELL = MADALTO  then HITGROUP( CASTGR, 8, 8, 2);
    if SPELL = LAKANITO then
      for GROUPI := 0 to XBRA.ALIVECNT - 1 do
        begin
          PT04 := XBRA.TEMP04[ GROUPI];
          if Byte( PT04^.XSTATUS) < 5 then
            ISISNOT( CASTGR, GROUPI,
                     6 * XBTB.HPREC.LEVEL,
                     'SMOTHERED', 2)
        end;
    if SPELL = ZILWAN then
      if XBTB.XCLASS = 10 then
        DOHITS( CASTGR, CASTI, 10, 200);
    if SPELL = MASOPIC  then MODAC( 0, 4, 0, PARTYCNT - 1);
    if SPELL = HAMAN    then HAMMAHAM( 6);
    if SPELL = MALOR    then exit( SMALOR);          { always U_COMBAT }
    if SPELL = MAHAMAN  then HAMMAHAM( 8);           { v3.2 WC006 }
    if SPELL = TILTOWAI then
      if BATG = 0 then
        for GROUPI := 1 to 4 do
          HITGROUP( GROUPI, 10, 15, 0)
      else
        HITGROUP( 0, 10, 15, 0)
  end;  { DOMAGE }


  procedure EXITCAST( EXITSTR: string);           { AP: then EXIT( CASTASPE) }
  begin
    MVCURSOR( 1, 12);
    PRINTSTR( EXITSTR)
  end;


begin  { CASTASPE }
  Result := UNWNONE;
  CBRC := BATTLERC[ BATG];
  CBRA := CBRC^.A;
  PT04 := CBRA.TEMP04[ BATI];
  DSPNAMES( BATG, BATI);
  PRINTSTR( 'CASTS ');                                { v3.2 WC020 }
  if BATG = 0 then
    begin
      CASTGR := PT04.VICTIM;
      if (CASTGR > 0) and (CASTGR < 5) then
        begin
          CBRC := BATTLERC[ CASTGR];
          CBRA := CBRC^.A;
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
  SHOWMP( SPELL);                                     { v3.2 WC020 }
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
  MVCURSOR( 1, 12);
  if DOMAGE = U_COMBAT then exit( U_COMBAT);
  Result := DOPRIEST
end;  { CASTASPE }


procedure CAST;                                   { AP MELEE, for a caster }
begin
  CMBEXIT := UNWNONE;
  MVCURSOR( 1, 11);
  if CASTASPE = U_COMBAT then
    begin
      CMBEXIT := U_COMBAT;                              { EXIT( COMBAT) }
      exit
    end;
  PAUSE1;
  CLRRECT( 1, 11, 38, 4)
end;


end.
