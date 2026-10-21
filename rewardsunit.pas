unit REWARDSUNIT;

{ Source: apple/Wizardry_v3-2/Wiz1C.DSK/REWARDS + REWARDS2 (v3.2)

  Translation notes:
    - EXIT(REWARDS / ACHEST / DISARMTR / GIVEEXP) past the current routine ->
      unwind codes U_* (CONSTS); EXIT of the current routine -> exit.
      CHSTGOLD is REWARDS' last call, so its own exit ends the segment.
    - MOVELEFT(IOCACHE[GETREC(...)], DEST, SZ) -> Move(IOCACHE[GETREC(...)], DEST, SZ)
    - MOVELEFT(SRC, IOCACHE[GETRECW(...)], SZ) -> Move(SRC, IOCACHE[GETRECW(...)], SZ)
    - MOVELEFT(IOCACHE, BATRESLT, SZ)          -> Move(IOCACHE[0], BATRESLT, SZ)
    - CHARACTR[X].FIELD -> TC := CHARACTR[X]; TC.FIELD (for all fields)
    - WITH CHARACTR[X].POSS DO -> TC := CHARACTR[X]; TC.POSS.FIELD / PP := TC.POSS.POSSESS[I]
    - POSSESS[I].FIELD -> PP := POSS.POSSESS[I]; PP.FIELD (^TPOSSESS pointer)
    - TCHAR.SPELLSKN[I] -> TC^.SPELLSKN^[I]  (^TSPELLSKN needs explicit ^)
    - CLASS -> XCLASS
    - LOSTXYL.POISNAMT[1] -> LOSTXYL[1]
    - EXPTABLE[CLASS][LVL] -> EXPTABLE[Ord(XCLASS)*13 + LVL]^
    - PIC2SCRN -> HIUTIL PICTOSCR (the Atari portrait layout)
    - TREWARDX.REWDCALC variant record -> flat REWDCALC: array[0..6] of SmallInt
        GOLD: TRIES=0 AVEAMT=1 MINADD=2 MULTX=3 TRIES2=4 AVEAMT2=5 MINADD2=6
        ITEM: MININDX=0 MFACTOR=1 MAXTIMES=2 RANGE=3 PERCBIGR=4
    - TREWARD.REWARDXX[1..9] -> [0..9]; [0] unused
    - FILLCHAR sizes -> SizeOf() (AP Boolean=2 bytes; MP Boolean=1 byte)
    - Enum assignments in deeply nested procs: SETSTAT_R(TC, ENUM) helper
}

interface

uses TYPES, CONSTS, GLOBALS, UTIL, SCREEN;

procedure REWARDS;

implementation

{ ── Local types (AP defined these inside CHSTGOLD; must be at unit level in MP) ── }

type
  { Flat union of AP variant record TREWARDX.REWDCALC (GOLD or ITEM variant).
    BITEM=0 -> GOLD variant; BITEM<>0 -> ITEM variant. Both are 7 integers. }
  TREWARDX = record
    REWDPERC : SmallInt;
    BITEM    : SmallInt;
    REWDCALC : array[ 0..6] of SmallInt;
  end;

  { REWARDXX[0..9]; [0] unused (AP: ARRAY[1..9]).
    Pointer array avoids nested record-in-record; RDREWARD allocates [1..9]. }
  TREWARD = record
    BCHEST   : Boolean;
    BTRAPTYP : array[ 0..7] of Boolean;
    REWRDCNT : SmallInt;
    REWARDXX : array[ 0..9] of ^TREWARDX;
  end;

{ ── Unit-level state ── }

const
  U_REWARDS  = $01;       { unwind targets: AP P010D01, P010D08, P010D17, }
  U_ACHEST   = $08;       {   P010D1F                                     }
  U_DISARMTR = $17;
  U_GIVEEXP  = $1F;

var
  EXPPERCH : TWIZLONG;
  ALIVECNT : SmallInt;
  ONEORTWO : SmallInt;
  REWARDI  : SmallInt;
  TRAP3TYP : SmallInt;

{ Enum assignment helper — required because MP re-types enum constants as Byte
  inside deeply nested procedures (bug4). }
procedure SETSTAT_R( TC: PTCHAR; ST: TSTATUS);
begin TC^.STATUS := TSTATUS( Byte( ST)) end;   { TC^: mpbugs/bug15 }


{ ══════════════════════════════════════════════════════════════════════════════
  REWARDS
  ══════════════════════════════════════════════════════════════════════════════ }

procedure REWARDS;


  { ── PIC2SCRN ── }
  { BUFFERI = GETREC( ZSPCCHRS, INDEX, 512), the picture's IOCACHE offset
    (18: treasure chest, 19: gold). }
  procedure PIC2SCRN( BUFFERI: SmallInt);
  begin
    Poke( $02C4, Ord( IOCACHE[ BUFFERI + 500]));    { COLOR0, COLOR1: the }
    Poke( $02C5, Ord( IOCACHE[ BUFFERI + 501]));    {   picture's hues    }
    PICTOSCR( BUFFERI)
  end;


  { ── PRLONG2 ── }
  procedure PRLONG2( var MP01: TWIZLONG);
  var
    BCDNUM   : TBCD;
    NONZEROI : SmallInt;
    SUPPRESI : SmallInt;
  begin
    LONG2BCD( MP01, BCDNUM);
    SUPPRESI := 1;
    while (SUPPRESI < 12) and (BCDNUM[ SUPPRESI] = 0) do
      SUPPRESI := SUPPRESI + 1;
    for NONZEROI := SUPPRESI to 12 do
      PRINTCHR( Chr( BCDNUM[ NONZEROI] + Ord( '0')))
  end;


  { ── ENMYREWD ── }
  procedure ENMYREWD;
  var
    ENEMY : TENEMY;
  begin
    Move( IOCACHE[ GETREC( ZENEMY, ENEMYINX, SizeOf( TENEMY))],
          ENEMY,
          SizeOf( TENEMY));
    if ENEMY.UNIQUE > 0 then
      begin
        ENEMY.UNIQUE := ENEMY.UNIQUE - 1;
        Move( ENEMY,
              IOCACHE[ GETRECW( ZENEMY, ENEMYINX, SizeOf( TENEMY))],
              SizeOf( TENEMY))
      end;
    ONEORTWO := 1;
    if ATTK012 = 0 then
      REWARDI := ENEMY.REWARD1
    else if ATTK012 = 1 then
      begin
        REWARDI := ENEMY.REWARD1;
        ONEORTWO := 2
      end
    else
      REWARDI := ENEMY.REWARD2
  end;


  { ── FOUNDITM ── }
  procedure FOUNDITM( FNDCHARX: SmallInt; POSSX: SmallInt; ITEMINDX: SmallInt);
  var
    OBJECTRC : TOBJREC;
    TC       : PTCHAR;
    PP       : ^TPOSSESS;
  begin
    LOADOBJREC( ITEMINDX, OBJECTRC);
    CLRRECT( 1, 11, 38, 4);
    MVCURSOR( 1, 12);
    TC := CHARACTR[ FNDCHARX];
    PRINTSTR( TC.NAME);
    PRINTSTR( ' FOUND - ');
    PRINTSTR( OBJECTRC.NAMEUNK);
    POSSX          := TC.POSS.POSSCNT + 1;
    PP             := TC.POSS.POSSESS[ POSSX];
    PP.EQUIPED     := false;
    PP.IDENTIF     := false;
    PP.CURSED      := false;
    PP.EQINDEX     := ITEMINDX;
    TC.POSS.POSSCNT := POSSX
  end;


  { ── CHSTGOLD ── }
  procedure CHSTGOLD;
  var
    CHRXCHST : SmallInt;
    INDX     : SmallInt;
    GOLD2ONE : TWIZLONG;
    REWARDZ  : TREWARD;
    RWBLK    : array[ 0..10 * SizeOf( TREWARDX) - 1] of Byte;  { REWARDXX[0..9] backing }
    PRWZ     : ^TREWARD;    { REWARDZ.REWARDXX[] only via a pointer (mpbugs/bug10) }
    RXZ      : ^TREWARDX;


    { ── RDREWARD ── }
    { AP disk layout (168 bytes, RECPER2BL=6):
        +0  2  BCHEST   (AP 2-byte BOOLEAN)
        +2  2  BTRAPTYP (8-bit packed, bits 0-7)
        +4  2  REWRDCNT (INTEGER)
        +6  9x18  REWARDXX[1..9]: each TREWARDX = REWDPERC(2)+BITEM(2)+REWDCALC(7x2=14) }
    procedure RDREWARD;
    var
      B, I, J : SmallInt;
      W       : Word;
      RX      : ^TREWARDX;
      PRW     : ^TREWARD;   { REWARDZ.REWARDXX[] only via a pointer (mpbugs/bug10) }
    begin
      B := GETREC( ZREWARD, REWARDI, 168);
      PRW := @REWARDZ;

      FillChar( REWARDZ, SizeOf( TREWARD), 0);

      REWARDZ.BCHEST := (Byte( IOCACHE[B]) or Byte( IOCACHE[B + 1])) <> 0;

      W := Byte( IOCACHE[B + 2]) or (Word( Byte( IOCACHE[B + 3])) shl 8);
      for I := 0 to 7 do
        REWARDZ.BTRAPTYP[I] := (W shr I) and 1 <> 0;

      Move( IOCACHE[B + 4], REWARDZ.REWRDCNT, 2);

      for I := 1 to 9 do
        begin
          PRW.REWARDXX[I] := Pointer( Word( @RWBLK) + I * SizeOf( TREWARDX));
          RX := PRW.REWARDXX[I];
          J  := B + 6 + (I - 1) * 18;
          Move( IOCACHE[J],     RX^.REWDPERC,    2);
          Move( IOCACHE[J + 2], RX^.BITEM,        2);
          Move( IOCACHE[J + 4], RX.REWDCALC[0], 14)
        end
    end;


    { ── ACHEST ── }
    function ACHEST: Byte;                     { UNWNONE or U_REWARDS }
    var
      WHOTRIED    : array[ 0..5] of Boolean;
      TRAPTYPE    : SmallInt;
      U           : Byte;


      { ── GTTRAPTY ── }
      procedure GTTRAPTY;
      var
        BTRAPPED : Boolean;
        ZERO99   : SmallInt;
      begin
        BTRAPPED := false;
        for TRAPTYPE := 0 to 7 do
          if REWARDZ.BTRAPTYP[ TRAPTYPE] then BTRAPPED := true;
        TRAP3TYP := Random( 5);
        if not BTRAPPED then
          TRAPTYPE := 0
        else
          if Random( 15) > (4 + MAZELEV) then
            TRAPTYPE := 0
          else
            begin
              ZERO99   := Random( 100);
              TRAPTYPE := 0;
              while ZERO99 > 0 do
                repeat
                  if TRAPTYPE < 7 then
                    begin
                      if TRAPTYPE = 3 then ZERO99 := ZERO99 - 5
                      else                 ZERO99 := ZERO99 - 1;
                      TRAPTYPE := TRAPTYPE + 1
                    end
                  else
                    TRAPTYPE := 1
                until REWARDZ.BTRAPTYP[ TRAPTYPE]
            end
      end;


      { ── EXITRWDS ── }
      function EXITRWDS: Byte;
      begin
        EXITRWDS := U_REWARDS                           { EXIT( REWARDS) }
      end;


      { ── PRTRAPTY ── }
      procedure PRTRAPTY( TRAPTYPE_P: SmallInt; TRAP3TY: SmallInt);
      begin
        case Byte( TRAPTYPE_P) of
          0: PRINTSTR( 'TRAPLESS CHEST');
          1: PRINTSTR( 'POISON NEEDLE');
          2: PRINTSTR( 'GAS BOMB');
          3: case Byte( TRAP3TY) of
               0: PRINTSTR( 'CROSSBOW BOLT');
               1: PRINTSTR( 'EXPLODING BOX');
               2: PRINTSTR( 'SPLINTERS');
               3: PRINTSTR( 'BLADES');
               4: PRINTSTR( 'STUNNER');
             end;
          4: PRINTSTR( 'TELEPORTER');
          5: PRINTSTR( 'ANTI-MAGE');
          6: PRINTSTR( 'ANTI-PRIEST');
          7: PRINTSTR( 'ALARM');
        end;
        PAUSE2
      end;


      { ── DOTRAPDM: always unwinds ── }
      function DOTRAPDM: Byte;                 { U_ACHEST or U_REWARDS }
      var
        CHARX : SmallInt;
        TC_D  : PTCHAR;


        { ── HPDAMAGE ── }
        function HPDAMAGE( CHARXHIT: SmallInt; HITCNT: SmallInt; HITDAM: SmallInt): Byte;
        var
          TOTDAM : SmallInt;
          TC_H   : PTCHAR;
        begin
          HPDAMAGE := UNWNONE;
          TOTDAM := 0;
          while HITCNT > 0 do
            begin
              TOTDAM := TOTDAM + Random( HITDAM) + 1;
              HITCNT := HITCNT - 1
            end;
          TC_H        := CHARACTR[ CHARXHIT];
          TC_H.HPLEFT := TC_H.HPLEFT - TOTDAM;
          if TC_H.HPLEFT < 1 then
            begin
              TC_H.HPLEFT := 0;
              SETSTAT_R( TC_H, DEAD);
              CLRRECT( 1, 11, 38, 4);
              MVCURSOR( 1, 12);
              PRINTSTR( TC_H.NAME);
              PRINTSTR( ' DIES!');
              ALIVECNT := ALIVECNT - 1;
              if ALIVECNT = 0 then
                begin
                  XGOTO    := XCEMETRY;
                  HPDAMAGE := U_REWARDS                 { EXIT( REWARDS) }
                end
            end
        end;


        { ── ANTIPM ── }
        procedure ANTIPM( BMAGEDAM: Boolean);
        var
          PLYZSTON : Boolean;
          CHARPM   : SmallInt;
          TC_PM    : PTCHAR;

          procedure ISSTONED;
          begin
            if Byte( TC_PM^.STATUS) < Byte( STONED) then SETSTAT_R( TC_PM, STONED)
          end;

          procedure ISPLYZE;
          begin
            if Byte( TC_PM^.STATUS) < Byte( PLYZE) then SETSTAT_R( TC_PM, PLYZE)
          end;

        begin
          for CHARPM := 0 to PARTYCNT - 1 do
            begin
              TC_PM    := CHARACTR[ CHARPM];
              PLYZSTON := Random( 20) < TC_PM.LUCKSKIL[ 4];
              case Byte( TC_PM^.XCLASS) of
                Byte( MAGE):
                  if BMAGEDAM then
                    if PLYZSTON then ISPLYZE else ISSTONED;
                Byte( SAMURAI):
                  if BMAGEDAM then
                    if not PLYZSTON then ISPLYZE;
                Byte( PRIEST):
                  if not BMAGEDAM then
                    if PLYZSTON then ISPLYZE else ISSTONED;
                Byte( BISHOP):
                  if not BMAGEDAM then
                    if not PLYZSTON then ISPLYZE;
              end
            end
        end;


        { ── TYPE3DAM ── }
        function TYPE3DAM: Byte;

          function HPDAMALL( CHANCHIT: SmallInt; HITCNT: SmallInt; HITDAM: SmallInt): Byte;
          var
            CHARXHIT : SmallInt;
          begin
            HPDAMALL := UNWNONE;
            for CHARXHIT := 0 to PARTYCNT - 1 do
              if Random( 100) < CHANCHIT then
                begin
                  if HPDAMAGE( CHARXHIT, HITCNT, HITDAM) <> UNWNONE then exit( U_REWARDS)
                end
              else
                if Random( 100) < CHANCHIT then
                  if HPDAMAGE( CHARXHIT, HITCNT, (HITDAM div 2) + 1) <> UNWNONE then
                    exit( U_REWARDS)
          end;

        begin  { TYPE3DAM }
          Result := UNWNONE;
          case Byte( TRAP3TYP) of
            0: Result := HPDAMAGE( CHRXCHST, MAZELEV, 8);   { CROSSBOW BOLT }
            1: Result := HPDAMALL( 50, MAZELEV, 8);           { EXPLODING BOX }
            2: Result := HPDAMALL( 70, MAZELEV, 6);           { SPLINTERS     }
            3: Result := HPDAMALL( 30, MAZELEV, 12);          { BLADES        }
            4: begin TC_D := CHARACTR[ CHRXCHST]; SETSTAT_R( TC_D, PLYZE); end; { STUNNER }
          end
        end;


      begin  { DOTRAPDM }
        Result := U_ACHEST;
        CLRRECT( 13, 8, 26, 2);
        MVCURSOR( 13, 8);
        if TRAPTYPE <> 0 then
          begin
            PRINTSTR( 'OOPPS! A ');
            PRTRAPTY( TRAPTYPE, TRAP3TYP)
          end
        else
          PRINTSTR( 'THE CHEST WAS NOT TRAPPED');
        PAUSE2;

        case Byte( TRAPTYPE) of

          1:  begin   { POISON NEEDLE }
                TC_D := CHARACTR[ CHRXCHST];
                TC_D.LOSTXYL[ 1] := TC_D.LOSTXYL[ 1] + 1
              end;

          2:  for CHARX := 0 to PARTYCNT - 1 do   { GAS BOMB }
                begin
                  TC_D := CHARACTR[ CHARX];
                  if Random( 20) < TC_D.LUCKSKIL[ 2] then   { v3.2 WC016 }
                    begin
                      TC_D := CHARACTR[ CHARX];
                      TC_D.LOSTXYL[ 1] := 1
                    end
                end;

          3:  if TYPE3DAM = U_REWARDS then exit( U_REWARDS);   { crossbow/box/etc. }

          4:  begin   { TELEPORTER }
                MAZEX    := Random( 20);
                MAZEY    := Random( 20);
                DIRECTIO := Random( 4)
              end;

          5:  ANTIPM( true);                            { ANTI-MAGE   }
          6:  ANTIPM( false);                           { ANTI-PRIEST }

          7:  begin   { ALARM }
                CHSTALRM := 1;
                exit( U_REWARDS)                        { EXIT( REWARDS) }
              end;
        end;

        Result := U_ACHEST                              { EXIT( ACHEST) }
      end;


      { ── PRTRAP ── }
      procedure PRTRAP;
      begin
        CLRRECT( 13, 8, 26, 2);
        MVCURSOR( 13, 8);
        PRTRAPTY( TRAPTYPE, TRAP3TYP);
        PAUSE2
      end;


      { ── PRRNDTRP ── }
      procedure PRRNDTRP;
      var
        RNDX : SmallInt;
        LOOP : SmallInt;
        TRAP : SmallInt;
      begin
        TRAP := 0;
        RNDX := Random( 50);
        for LOOP := 1 to RNDX do
          if TRAP = 7 then TRAP := 0
          else          TRAP := TRAP + 1;
        CLRRECT( 13, 8, 26, 2);
        MVCURSOR( 13, 8);
        PRTRAPTY( TRAP, Random( 5));
        PAUSE2
      end;


      { ── INSPCHST ── }
      function INSPCHST: Byte;
      var
        CHNCGOOD : SmallInt;
        CHARINSP : SmallInt;
        TC_I     : PTCHAR;
      begin
        INSPCHST := UNWNONE;
        CLRRECT( 13, 8, 26, 2);
        MVCURSOR( 15, 8);
        PRINTSTR( 'WHO (#) WILL INSPECT?');
        GETKEY;
        CHARINSP := Ord( INCHAR) - Ord( '0') - 1;
        if (CHARINSP < 0) or (CHARINSP >= PARTYCNT) then exit;
        TC_I := CHARACTR[ CHARINSP];
        if TC_I^.STATUS <> OK then exit;
        if WHOTRIED[ CHARINSP] then
          begin
            CLRRECT( 13, 8, 26, 1);
            MVCURSOR( 16, 8);
            PRINTSTR( 'YOU ALREADY LOOKED!');
            PAUSE2;
            exit
          end;
        WHOTRIED[ CHARINSP] := true;
        CHNCGOOD             := TC_I.ATTRIB[ AGILITY];
        if TC_I^.XCLASS = THIEF then
          CHNCGOOD := CHNCGOOD * 6
        else if TC_I^.XCLASS = NINJA then
          CHNCGOOD := CHNCGOOD * 4;
        if CHNCGOOD > 95 then CHNCGOOD := 95;
        CHRXCHST := CHARINSP;
        if Random( 100) < CHNCGOOD then
          PRTRAP
        else
          if Random( 20) > TC_I.ATTRIB[ AGILITY] then
            INSPCHST := DOTRAPDM
          else
            PRRNDTRP
      end;


      { ── CALFOCH ── }
      procedure CALFOCH;
      var
        TC_C : PTCHAR;
        SKN  : PTSPELLSKN;
      begin
        CLRRECT( 13, 8, 26, 2);
        MVCURSOR( 14, 8);
        PRINTSTR( 'WHO (#) WILL CAST CALFO?');
        GETKEY;
        CHRXCHST := Ord( INCHAR) - Ord( '0') - 1;
        if (CHRXCHST < 0) or (CHRXCHST >= PARTYCNT) then exit;
        TC_C := CHARACTR[ CHRXCHST];
        SKN  := TC_C^.SPELLSKN;
        if not SKN^[ 28] then exit;
        if TC_C.PRIESTSP[ 2] = 0 then exit;
        if TC_C^.STATUS <> OK then exit;
        TC_C.PRIESTSP[ 2] := TC_C.PRIESTSP[ 2] - 1;
        if Random( 100) < 95 then PRTRAP
        else                      PRRNDTRP
      end;


      { ── DISARMTR ── }
      function DISARMTR: Byte;                 { UNWNONE, U_ACHEST or U_REWARDS }
      var
        TRAPSTR       : string[ 24];
        TC_DA         : PTCHAR;
        U             : Byte;

        function DISARM: Byte;
        begin
          CLRRECT( 13, 8, 26, 2);
          MVCURSOR( 18, 8);
          TC_DA := CHARACTR[ CHRXCHST];
          if Random( 70) <
             (  TC_DA.CHARLEV
              - MAZELEV
              + (50 * Ord(   (TC_DA^.XCLASS = THIEF)
                          or (TC_DA^.XCLASS = NINJA)))
             ) then
            begin
              PRINTSTR( 'YOU DISARMED IT!');
              PAUSE2;
              DISARM := U_ACHEST                        { EXIT( ACHEST) }
            end
          else
            if Random( 20) < TC_DA.ATTRIB[ AGILITY] then
              begin
                PRINTSTR( 'DISARM FAILED!!');
                PAUSE2;
                DISARM := U_DISARMTR                    { EXIT( DISARMTR) }
              end
            else
              begin
                PRINTSTR( 'YOU SET IT OFF!');
                PAUSE2;
                DISARM := DOTRAPDM
              end
        end;

      begin  { DISARMTR }
        Result := UNWNONE;
        CLRRECT( 13, 8, 26, 2);
        MVCURSOR( 16, 8);
        PRINTSTR( 'WHO (#) WILL DISARM?');
        GETKEY;
        CHRXCHST := Ord( INCHAR) - Ord( '0') - 1;
        if (CHRXCHST < 0) or (CHRXCHST >= PARTYCNT) then exit;
        TC_DA := CHARACTR[ CHRXCHST];
        if TC_DA^.STATUS <> OK then exit;
        CLRRECT( 13, 8, 26, 2);
        MVCURSOR( 13, 8);
        PRINTSTR( 'WHAT TRAP >');
        GETSTR( TRAPSTR, 24, 8);
        U := UNWNONE;
        if      (TRAPSTR = 'POISON NEEDLE') and (TRAPTYPE = 1) then U := DISARM
        else if (TRAPSTR = 'GAS BOMB')      and (TRAPTYPE = 2) then U := DISARM
        else if TRAPTYPE = 3 then
          begin
            case Byte( TRAP3TYP) of
              0: if TRAPSTR = 'CROSSBOW BOLT' then U := DISARM;
              1: if TRAPSTR = 'EXPLODING BOX' then U := DISARM;
              2: if TRAPSTR = 'SPLINTERS'     then U := DISARM;
              3: if TRAPSTR = 'BLADES'        then U := DISARM;
              4: if TRAPSTR = 'STUNNER'       then U := DISARM;
            end;
            if U = UNWNONE then U := DOTRAPDM          { v3.2 WC037 }
          end
        else if (TRAPSTR = 'TELEPORTER')  and (TRAPTYPE = 4) then U := DISARM
        else if (TRAPSTR = 'ANTI-MAGE')   and (TRAPTYPE = 5) then U := DISARM
        else if (TRAPSTR = 'ANTI-PRIEST') and (TRAPTYPE = 6) then U := DISARM
        else if (TRAPSTR = 'ALARM')       and (TRAPTYPE = 7) then U := DISARM
        else U := DOTRAPDM;
        if U <> U_DISARMTR then Result := U               { U_DISARMTR ends here }
      end;


      { ── OPENCHST ── }
      function OPENCHST: Byte;
      var
        TC_O : PTCHAR;
      begin
        OPENCHST := UNWNONE;
        CLRRECT( 13, 8, 26, 2);
        MVCURSOR( 17, 8);
        PRINTSTR( 'WHO (#) WILL OPEN?');
        GETKEY;
        CHRXCHST := Ord( INCHAR) - Ord( '0') - 1;
        if (CHRXCHST < 0) or (CHRXCHST >= PARTYCNT) then exit;
        TC_O := CHARACTR[ CHRXCHST];
        if TC_O^.STATUS <> OK then exit;
        if TRAPTYPE = 0 then exit( U_ACHEST);           { EXIT( ACHEST) }
        if Random( 1000) < TC_O.CHARLEV then exit( U_ACHEST);
        OPENCHST := DOTRAPDM
      end;


    begin  { ACHEST }
      Result := UNWNONE;
      PIC2SCRN( GETREC( ZSPCCHRS, 18, 512));
      FillChar( WHOTRIED, SizeOf( WHOTRIED), 0);
      GTTRAPTY;
      CLRRECT( 13, 6, 26, 4);
      MVCURSOR( 13, 6);
      PRINTSTR( 'A CHEST! YOU MAY:');
      repeat
        CLRRECT( 13, 8, 26, 2);
        MVCURSOR( 13, 8);
        PRINTSTR( 'O)PEN     C)ALFO   L)EAVE');
        MVCURSOR( 13, 9);
        PRINTSTR( 'I)NSPECT  D)ISARM');
        GETKEY;
        U := UNWNONE;
        if      INCHAR = 'O' then U := OPENCHST
        else if INCHAR = 'L' then U := EXITRWDS
        else if INCHAR = 'I' then U := INSPCHST
        else if INCHAR = 'C' then CALFOCH
        else if INCHAR = 'D' then U := DISARMTR;
        if U = U_REWARDS then exit( U_REWARDS);
        if U = U_ACHEST then exit                       { U_ACHEST ends here }
      until false
    end;


    { ── GETREWRD ── }
    procedure GETREWRD( REWARDM: TREWARDX);
    var
      ITEMINDX : SmallInt;
      CHARIIII : SmallInt;
      CHARXXXX : SmallInt;

      function CALCULAT( TRIES: SmallInt; AVEAMT: SmallInt; MINADD: SmallInt): SmallInt;
      var
        TOTAL : SmallInt;
      begin
        TOTAL := MINADD;
        while TRIES > 0 do
          begin
            TOTAL := TOTAL + Random( AVEAMT) + 1;
            TRIES := TRIES - 1
          end;
        CALCULAT := TOTAL
      end;

      procedure GOLDREWD;
      var
        GOLDAMT : TWIZLONG;
      begin
        FillChar( GOLDAMT, SizeOf( GOLDAMT), 0);
        { REWDCALC[0..6] = TRIES, AVEAMT, MINADD, MULTX, TRIES2, AVEAMT2, MINADD2 }
        GOLDAMT.XLOW := CALCULAT( REWARDM.REWDCALC[ 0],
                                  REWARDM.REWDCALC[ 1],
                                  REWARDM.REWDCALC[ 2]);
        MULTLONG( GOLDAMT, REWARDM.REWDCALC[ 3]);
        CHARXXXX := CALCULAT( REWARDM.REWDCALC[ 4],
                               REWARDM.REWDCALC[ 5],
                               REWARDM.REWDCALC[ 6]);
        MULTLONG( GOLDAMT, CHARXXXX);
        MULTLONG( GOLDAMT, ONEORTWO);
        ADDLONGS( GOLD2ONE, GOLDAMT)
      end;

      procedure ITEMREWD;
      var
        TC_IR    : PTCHAR;
        HASROOM  : SmallInt;
        CHARYYYY : SmallInt;
      begin
        HASROOM := 0;                                   { v3.2 WC033 }
        for CHARYYYY := 0 to PARTYCNT - 1 do
          begin
            TC_IR := CHARACTR[ CHARYYYY];
            if TC_IR.POSS.POSSCNT < 8 then
              begin
                HASROOM  := 1;
                CHARXXXX := CHARYYYY
              end
          end;
        if HASROOM = 0 then
          begin
            MVCURSOR( 1, 12);
            PRINTSTR( 'PARTY INVENTORY FULL !');
            MVCURSOR( 1, 13);
            PRINTSTR( 'TREASURE LOST !');
            PAUSE2;
            exit
          end;
        CHARIIII := 0;
        { REWDCALC[4]=PERCBIGR, [2]=MAXTIMES, [0]=MININDX, [3]=RANGE, [1]=MFACTOR }
        while (CALCULAT( 1, 100, 1) < REWARDM.REWDCALC[ 4]) and
              (CHARIIII < REWARDM.REWDCALC[ 2]) do
          CHARIIII := CHARIIII + 1;
        ITEMINDX := REWARDM.REWDCALC[ 0]
                  + Random( REWARDM.REWDCALC[ 3] + 1)   { v3.2 WC022 }
                  + (REWARDM.REWDCALC[ 1] * CHARIIII);
        FOUNDITM( CHARXXXX, CHARIIII, ITEMINDX);
        PAUSE2
      end;

    begin  { GETREWRD }
      if REWARDM.REWDPERC < Random( 100) then exit;
      if REWARDM.BITEM = 0 then GOLDREWD
      else                       ITEMREWD
    end;


    { ── GIVEGOLD ── }
    procedure GIVEGOLD;
    var
      TC_G : PTCHAR;
    begin
      DIVLONG( GOLD2ONE, ALIVECNT);
      CLRRECT( 1, 11, 38, 4);
      MVCURSOR( 1, 12);
      PRINTSTR( 'EACH SHARE IS WORTH ');
      PRLONG2( GOLD2ONE);
      PRINTSTR( ' GP!');
      for INDX := 0 to PARTYCNT - 1 do
        begin
          TC_G := CHARACTR[ INDX];
          if TC_G^.STATUS = OK then ADDLONGS( TC_G.GOLD, GOLD2ONE)
        end;
      PAUSE2
    end;


  begin  { CHSTGOLD }
    FillChar( GOLD2ONE, SizeOf( GOLD2ONE), 0);
    ENMYREWD;
    RDREWARD;
    UNITCLEAR( 1);
    if REWARDZ.BCHEST and (CHSTALRM <> 1) then
      begin
        if ACHEST = U_REWARDS then exit;                { CHSTGOLD is REWARDS' last call }
        CLRRECT( 3, 5, 9, 5)
      end
    else
      CHSTALRM := 0;
    CLRRECT( 1, 11, 38, 4);
    PIC2SCRN( GETREC( ZSPCCHRS, 19, 512));
    for INDX := 1 to REWARDZ.REWRDCNT do
      begin
        PRWZ := @REWARDZ;
        RXZ  := PRWZ.REWARDXX[ INDX];
        GETREWRD( RXZ^)
      end;
    GIVEGOLD
  end;


  { ── GIVEEXP ── }
  function GIVEEXP: Byte;                      { UNWNONE or U_REWARDS }
  var
    WEPSTY3I     : SmallInt;
    SPPCI        : SmallInt;
    BATRESLT     : TBATRSLT;
    CHARXXX      : SmallInt;
    KILLEXP      : TWIZLONG;
    U            : Byte;
    TC_GE        : PTCHAR;    { local pointer for GIVEEXP's own loops }


    { ── CNTALIVE ── }
    function CNTALIVE: Byte;
    var
      TC_CN : PTCHAR;
    begin
      CNTALIVE := UNWNONE;
      ALIVECNT := 0;
      for LLBASE04 := 0 to PARTYCNT - 1 do
        begin
          TC_CN := CHARACTR[ LLBASE04];
          if TC_CN^.STATUS = OK then ALIVECNT := ALIVECNT + 1
        end;
      if ALIVECNT = 0 then
        begin
          XGOTO    := XCEMETRY;
          CNTALIVE := U_REWARDS                         { EXIT( REWARDS) }
        end
    end;


    { ── CALC1EXP ── }
    procedure CALC1EXP;
    var
      MULT2040 : SmallInt;

      { ── TOTALEXP ── }
      procedure TOTALEXP;
      var
        ENEMYREC : TENEMY;

        { ── CALCKILL ── }
        procedure CALCKILL;
        var
          KILLEXPX : TWIZLONG;

          procedure SETKILLX( AMOUNT: SmallInt);
          begin
            KILLEXPX.XHIGH := 0;
            KILLEXPX.XMID  := 0;
            KILLEXPX.XLOW  := AMOUNT
          end;

          procedure MLTADDKX( MULTIPLY: SmallInt; AMOUNT: SmallInt);
          begin
            if MULTIPLY = 0 then exit;
            SETKILLX( AMOUNT);
            while MULTIPLY > 1 do
              begin
                MULTIPLY := MULTIPLY - 1;
                ADDLONGS( KILLEXPX, KILLEXPX)
              end;
            ADDLONGS( KILLEXP, KILLEXPX)
          end;

        begin  { CALCKILL }
          FillChar( KILLEXP,  SizeOf( KILLEXP),  0);
          FillChar( KILLEXPX, SizeOf( KILLEXPX), 0);
          SETKILLX( ENEMYREC.HPREC.LEVEL * ENEMYREC.HPREC.HPFAC);
          if ENEMYREC.BREATHE = 0 then MULT2040 := 20
          else                         MULT2040 := 40;
          MULTLONG( KILLEXPX, MULT2040);
          ADDLONGS( KILLEXP,  KILLEXPX);
          MLTADDKX( ENEMYREC.MAGSPELS, 35);
          MLTADDKX( ENEMYREC.PRISPELS, 35);
          MLTADDKX( ENEMYREC.DRAINAMT, 200);
          MLTADDKX( ENEMYREC.HEALPTS,  90);

          SETKILLX( 40 * (11 - ENEMYREC.AC));
          ADDLONGS( KILLEXP, KILLEXPX);
          if ENEMYREC.RECSN > 1 then MLTADDKX( ENEMYREC.RECSN, 30);
          if ENEMYREC.UNAFFCT > 0 then
            MLTADDKX( (ENEMYREC.UNAFFCT div 10) + 1, 40);

          LLBASE04 := 0;
          for WEPSTY3I := 1 to 6 do
            if ENEMYREC.WEPVSTY3[ WEPSTY3I] then LLBASE04 := LLBASE04 + 1;
          MLTADDKX( LLBASE04, 35);

          LLBASE04 := 0;
          for SPPCI := 0 to 6 do
            if ENEMYREC.SPPC[ SPPCI] then LLBASE04 := LLBASE04 + 1;
          MLTADDKX( LLBASE04, 40)
        end;

      begin  { TOTALEXP }
        Move( IOCACHE[ GETREC( ZENEMY, BATRESLT.ENMYID[ CHARXXX], SizeOf( TENEMY))],
              ENEMYREC,
              SizeOf( TENEMY));
        CALCKILL;
        MULTLONG( KILLEXP, BATRESLT.ENMYCNT[ CHARXXX]);
        ADDLONGS( EXPPERCH, KILLEXP)
      end;

    begin  { CALC1EXP }
      FillChar( EXPPERCH, SizeOf( EXPPERCH), 0);
      for CHARXXX := 1 to 4 do
        if BATRESLT.ENMYID[ CHARXXX] >= 0 then TOTALEXP;
      DIVLONG( EXPPERCH, ALIVECNT)
    end;


    { ── CHKDRAIN ── }
    function CHKDRAIN: Byte;                 { UNWNONE, U_GIVEEXP or U_REWARDS }
    var
      EXPTABLE : TEXP;
      EXPBLK   : TEXPBLK;     { EXPTABLE's wired entries }
      PEXP     : ^TWIZLONG;   { EXPTABLE[]^ only via a pointer (mpbugs/bug10) }
      TC_CK    : PTCHAR;
      CKCLASS  : TCLASS;      { TC_CK^.XCLASS as an argument is rejected }

      { ── DROPLEVL ── }
      procedure DROPLEVL( var CHAREXP: TWIZLONG;
                              CURRLEVL: SmallInt;
                              XCLASS_P: TCLASS);
      begin
        MVCURSOR( 1, 13);
        PRINTSTR( 'HE HAD ');
        PRLONG2( CHAREXP);
        PRINTSTR( ' EP');
        CURRLEVL := CURRLEVL - 1;
        if CURRLEVL = 0 then
          FillChar( CHAREXP, SizeOf( CHAREXP), 0)
        else if CURRLEVL < 13 then
          begin
            PEXP    := EXPTABLE[ Ord( XCLASS_P) * 13 + CURRLEVL];
            CHAREXP := PEXP^
          end
        else
          begin
            PEXP    := EXPTABLE[ Ord( XCLASS_P) * 13 + 12];
            CHAREXP := PEXP^;
            PEXP    := EXPTABLE[ Ord( XCLASS_P) * 13 + 0];
            for CHARXXX := 13 to CURRLEVL do
              ADDLONGS( CHAREXP, PEXP^)
          end;
        ADDLONGS( CHAREXP, KILLEXP);
        MVCURSOR( 1, 14);
        PRINTSTR( 'HE HAS ');
        PRLONG2( CHAREXP);
        PRINTSTR( ' EP NOW');
        PAUSE2
      end;

    begin  { CHKDRAIN }
      Result := UNWNONE;
      WIREEXP( EXPTABLE, EXPBLK);
      LOADTEXP( EXPTABLE);
      KILLEXP.XHIGH := 0;
      KILLEXP.XMID  := 0;
      KILLEXP.XLOW  := 1;
      for CHARXXX := 0 to PARTYCNT - 1 do
        begin
          if BATRESLT.DRAINED[ CHARXXX] then
            begin
              CLRRECT( 1, 11, 38, 4);
              MVCURSOR( 1, 11);
              TC_CK := CHARACTR[ CHARXXX];
              PRINTSTR( TC_CK.NAME);
              PRINTSTR( ' WAS DRAINED!');
              CKCLASS := TC_CK^.XCLASS;
              DROPLEVL( TC_CK.EXP, TC_CK.CHARLEV, CKCLASS)
            end
        end;
      CLRRECT( 1, 11, 38, 4);
      if XGOTO = XREWARD2 then exit( U_GIVEEXP);        { EXIT( GIVEEXP) }
      for CHARXXX := 0 to PARTYCNT - 1 do
        begin
          TC_CK := CHARACTR[ CHARXXX];
          if TC_CK^.STATUS = OK then exit  { EXIT(CHKDRAIN) — at least one alive }
        end;
      XGOTO  := XCEMETRY;
      Result := U_REWARDS                               { EXIT( REWARDS) }
    end;


  begin  { GIVEEXP }
    Result := UNWNONE;
    Move( IOCACHE[ 0], BATRESLT, SizeOf( TBATRSLT));
    CACHEWRI := false;
    if CNTALIVE = U_REWARDS then exit( U_REWARDS);
    U := CHKDRAIN;
    if U = U_REWARDS then exit( U_REWARDS);
    if U = U_GIVEEXP then exit;                         { U_GIVEEXP ends here }
    CALC1EXP;
    CLRRECT( 13, 1, 26, 4);
    MVCURSOR( 13, 1);
    PRINTSTR( 'FOR KILLING THE MONSTERS');
    MVCURSOR( 13, 2);
    PRINTSTR( 'EACH SURVIVOR GETS ');
    PRLONG2( EXPPERCH);
    MVCURSOR( 13, 3);
    PRINTSTR( 'EXPERIENCE POINTS');
    PAUSE2;
    for LLBASE04 := 0 to PARTYCNT - 1 do
      begin
        TC_GE := CHARACTR[ LLBASE04];
        if TC_GE^.STATUS = OK then ADDLONGS( TC_GE.EXP, EXPPERCH)
      end
  end;


begin  { REWARDS }
  case XGOTO of
    XREWARD:
      begin
        XGOTO := XRUNNER;
        if GIVEEXP = U_REWARDS then exit;
        CHSTGOLD
      end;
    XREWARD2:
      begin
        if GIVEEXP = U_REWARDS then exit;
        LLBASE04 := 0;
        XGOTO    := XSCNMSG
      end
  end
end;


end.
