unit REWARDSUNIT;

{ Source: apple/wiz1c/REWARDS + apple/wiz1c/REWARDS2

  Translation notes:
    - EXIT(REWARDS)   -> _done := true; exit (propagated up through callers)
    - EXIT(ACHEST)    -> _exitachest := true; exit (flag visible in ACHEST scope)
    - EXIT(GIVEEXP)   -> _exitgiveexp := true; exit (flag visible in GIVEEXP scope)
    - EXIT(PROC)      -> exit (current procedure)
    - MOVELEFT(IOCACHE[GETREC(...)], DEST, SZ) -> Move(IOCACHE[GETREC(...)], DEST, SZ)
    - MOVELEFT(SRC, IOCACHE[GETRECW(...)], SZ) -> Move(SRC, IOCACHE[GETRECW(...)], SZ)
    - MOVELEFT(IOCACHE, BATRESLT, SZ)          -> Move(IOCACHE[0], BATRESLT, SZ)
    - CHARACTR[X].FIELD -> TC := CHARACTR[X]; TC.FIELD (for all fields)
    - WITH CHARACTR[X].POSS DO -> TC := CHARACTR[X]; TC.POSS.FIELD / PP := TC.POSS.POSSESS[I]
    - POSSESS[I].FIELD -> PP := POSS.POSSESS[I]; PP.FIELD (^TPOSSESS pointer)
    - TCHAR.SPELLSKN[I] -> TC.SPELLSKN^[I]  (^TSPELLSKN needs explicit ^)
    - CLASS -> XCLASS
    - LOSTXYL.POISNAMT[1] -> LOSTXYL[1]
    - EXPTABLE[CLASS][LVL] -> EXPTABLE[Ord(XCLASS)*13 + LVL]^
    - UNITCLEAR(1) -> CLEARPIC
    - PIC2SCRN stubbed  (Apple-specific video RAM addressing, not applicable to Atari)
    - TREWARDX.REWDCALC variant record -> flat REWDCALC: array[0..6] of SmallInt
        GOLD: TRIES=0 AVEAMT=1 MINADD=2 MULTX=3 TRIES2=4 AVEAMT2=5 MINADD2=6
        ITEM: MININDX=0 MFACTOR=1 MAXTIMES=2 RANGE=3 PERCBIGR=4
    - TREWARD.REWARDXX[1..9] -> [0..9]; [0] unused
    - FILLCHAR sizes -> SizeOf() (AP Boolean=2 bytes; MP Boolean=1 byte)
    - Enum assignments in deeply nested procs: SETSTAT_R(TC, ENUM) helper
}

interface

uses TYPES, CONSTS, GLOBALS, UTIL, crt;

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

  { REWARDXX extended to 0..9; [0] unused (AP: ARRAY[1..9]).
    MP requires array-of-^RECORD inside records; pointer elements used here.
    TODO: proper deserialization when Atari disk I/O is wired up. }
  TREWARD = record
    BCHEST   : Boolean;
    BTRAPTYP : array[ 0..7] of Boolean;
    REWRDCNT : SmallInt;
    REWARDXX : array[ 0..9] of ^TREWARDX;
  end;

{ ── Unit-level state ── }

var
  _done    : Boolean;
  EXPPERCH : TWIZLONG;
  ALIVECNT : SmallInt;
  ONEORTWO : SmallInt;
  REWARDI  : SmallInt;
  TRAP3TYP : SmallInt;

{ Enum assignment helper — required because MP re-types enum constants as Byte
  inside deeply nested procedures (bug4). }
procedure SETSTAT_R( TC: PTCHAR; ST: TSTATUS);
begin TC.STATUS := ST end;


{ ══════════════════════════════════════════════════════════════════════════════
  REWARDS
  ══════════════════════════════════════════════════════════════════════════════ }

procedure REWARDS;


  { ── PIC2SCRN ── }
  { AP: copies 10 bytes/scanline from IOCACHE to Apple lo-res video RAM.
    Atari screen addressing is completely different; stub until Atari GFX done. }
  procedure PIC2SCRN( BUFFERI: SmallInt);
  begin
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


    { ── RDREWARD ── }
    procedure RDREWARD;
    begin
      Move( IOCACHE[ GETREC( ZREWARD, REWARDI, SizeOf( TREWARD))],
            REWARDZ,
            SizeOf( TREWARD))
    end;


    { ── ACHEST ── }
    procedure ACHEST;
    var
      WHOTRIED    : array[ 0..5] of Boolean;
      TRAPTYPE    : SmallInt;
      _exitachest : Boolean;   { set by nested procs for EXIT(ACHEST) }


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
      procedure EXITRWDS;
      begin
        _done := true; exit   { EXIT(REWARDS) }
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


      { ── DOTRAPDM ── }
      procedure DOTRAPDM;
      var
        CHARX : SmallInt;
        TC_D  : PTCHAR;


        { ── HPDAMAGE ── }
        procedure HPDAMAGE( CHARXHIT: SmallInt; HITCNT: SmallInt; HITDAM: SmallInt);
        var
          TOTDAM : SmallInt;
          TC_H   : PTCHAR;
        begin
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
                  XGOTO := XCEMETRY;
                  _done := true; exit   { EXIT(REWARDS) }
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
            if Byte( TC_PM.STATUS) < Byte( STONED) then SETSTAT_R( TC_PM, STONED)
          end;

          procedure ISPLYZE;
          begin
            if Byte( TC_PM.STATUS) < Byte( PLYZE) then SETSTAT_R( TC_PM, PLYZE)
          end;

        begin
          for CHARPM := 0 to PARTYCNT - 1 do
            begin
              TC_PM    := CHARACTR[ CHARPM];
              PLYZSTON := Random( 20) < TC_PM.LUCKSKIL[ 4];
              case Byte( TC_PM.XCLASS) of
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
        procedure TYPE3DAM;

          procedure HPDAMALL( CHANCHIT: SmallInt; HITCNT: SmallInt; HITDAM: SmallInt);
          var
            CHARXHIT : SmallInt;
          begin
            for CHARXHIT := 0 to PARTYCNT - 1 do
              begin
                if _done then break;
                if Random( 100) < CHANCHIT then
                  begin
                    HPDAMAGE( CHARXHIT, HITCNT, HITDAM);
                    if _done then break
                  end
                else
                  if Random( 100) < CHANCHIT then
                    begin
                      HPDAMAGE( CHARXHIT, HITCNT, (HITDAM div 2) + 1);
                      if _done then break
                    end
              end
          end;

        begin  { TYPE3DAM }
          case Byte( TRAP3TYP) of
            0: HPDAMAGE( CHRXCHST, MAZELEV, 8);   { CROSSBOW BOLT }
            1: HPDAMALL( 50, MAZELEV, 8);           { EXPLODING BOX }
            2: HPDAMALL( 70, MAZELEV, 6);           { SPLINTERS     }
            3: HPDAMALL( 30, MAZELEV, 12);          { BLADES        }
            4: begin TC_D := CHARACTR[ CHRXCHST]; SETSTAT_R( TC_D, PLYZE); end; { STUNNER }
          end
        end;


      begin  { DOTRAPDM }
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
                  if Random( 20) < TC_D.LUCKSKIL[ 3] then
                    begin
                      TC_D := CHARACTR[ CHARX];
                      TC_D.LOSTXYL[ 1] := 1
                    end
                end;

          3:  begin TYPE3DAM; if _done then exit; end;  { TYPE3 (crossbow/box/etc.) }

          4:  begin   { TELEPORTER }
                MAZEX    := Random( 20);
                MAZEY    := Random( 20);
                DIRECTIO := Random( 4)
              end;

          5:  begin ANTIPM( true);  if _done then exit; end;  { ANTI-MAGE   }
          6:  begin ANTIPM( false); if _done then exit; end;  { ANTI-PRIEST }

          7:  begin   { ALARM }
                CHSTALRM := 1;
                _done := true; exit   { EXIT(REWARDS) }
              end;
        end;

        _exitachest := true   { EXIT(ACHEST) — unconditional after trap processing }
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
      procedure INSPCHST;
      var
        CHNCGOOD : SmallInt;
        CHARINSP : SmallInt;
        TC_I     : PTCHAR;
      begin
        CLRRECT( 13, 8, 26, 2);
        MVCURSOR( 15, 8);
        PRINTSTR( 'WHO (#) WILL INSPECT?');
        GETKEY;
        CHARINSP := Ord( INCHAR) - Ord( '0') - 1;
        if (CHARINSP < 0) or (CHARINSP >= PARTYCNT) then exit;
        TC_I := CHARACTR[ CHARINSP];
        if TC_I.STATUS <> OK then exit;
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
        if TC_I.XCLASS = THIEF then
          CHNCGOOD := CHNCGOOD * 6
        else if TC_I.XCLASS = NINJA then
          CHNCGOOD := CHNCGOOD * 4;
        if CHNCGOOD > 95 then CHNCGOOD := 95;
        CHRXCHST := CHARINSP;
        if Random( 100) < CHNCGOOD then
          PRTRAP
        else
          if Random( 20) > TC_I.ATTRIB[ AGILITY] then
            begin DOTRAPDM; if _done then exit; end
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
        SKN  := TC_C.SPELLSKN;
        if not SKN^[ 28] then exit;
        if TC_C.PRIESTSP[ 2] = 0 then exit;
        if TC_C.STATUS <> OK then exit;
        TC_C.PRIESTSP[ 2] := TC_C.PRIESTSP[ 2] - 1;
        if Random( 100) < 95 then PRTRAP
        else                      PRRNDTRP
      end;


      { ── DISARMTR ── }
      procedure DISARMTR;
      var
        TRAPSTR       : string[ 24];
        _exitachest_d : Boolean;   { propagates EXIT(ACHEST) from DISARM }
        TC_DA         : PTCHAR;

        procedure DISARM;
        begin
          CLRRECT( 13, 8, 26, 2);
          MVCURSOR( 18, 8);
          TC_DA := CHARACTR[ CHRXCHST];
          if Random( 70) <
             (  TC_DA.CHARLEV
              - MAZELEV
              + (50 * Ord(   (TC_DA.XCLASS = THIEF)
                          or (TC_DA.XCLASS = NINJA)))
             ) then
            begin
              PRINTSTR( 'YOU DISARMED IT!');
              PAUSE2;
              _exitachest_d := true; exit   { EXIT(ACHEST) }
            end
          else
            if Random( 20) < TC_DA.ATTRIB[ AGILITY] then
              begin
                PRINTSTR( 'DISARM FAILED!!');
                PAUSE2;
                exit   { EXIT(DISARMTR) }
              end
            else
              begin
                PRINTSTR( 'YOU SET IT OFF!');
                PAUSE2;
                DOTRAPDM;
                if _done then exit
              end
        end;

      begin  { DISARMTR }
        _exitachest_d := false;
        CLRRECT( 13, 8, 26, 2);
        MVCURSOR( 16, 8);
        PRINTSTR( 'WHO (#) WILL DISARM?');
        GETKEY;
        CHRXCHST := Ord( INCHAR) - Ord( '0') - 1;
        if (CHRXCHST < 0) or (CHRXCHST >= PARTYCNT) then exit;
        TC_DA := CHARACTR[ CHRXCHST];
        if TC_DA.STATUS <> OK then exit;
        CLRRECT( 13, 8, 26, 2);
        MVCURSOR( 13, 8);
        PRINTSTR( 'WHAT TRAP >');
        GETSTR( TRAPSTR, 24, 8);
        if      (TRAPSTR = 'POISON NEEDLE') and (TRAPTYPE = 1) then DISARM
        else if (TRAPSTR = 'GAS BOMB')      and (TRAPTYPE = 2) then DISARM
        else if TRAPTYPE = 3 then
          begin
            case Byte( TRAP3TYP) of
              0: if TRAPSTR = 'CROSSBOW BOLT' then DISARM;
              1: if TRAPSTR = 'EXPLODING BOX' then DISARM;
              2: if TRAPSTR = 'SPLINTERS'     then DISARM;
              3: if TRAPSTR = 'BLADES'        then DISARM;
              4: if TRAPSTR = 'STUNNER'       then DISARM;
            end;
            if not _exitachest_d and not _done then DOTRAPDM  { AP comment: (* DOTRAPDM *) }
          end
        else if (TRAPSTR = 'TELEPORTER')  and (TRAPTYPE = 4) then DISARM
        else if (TRAPSTR = 'ANTI-MAGE')   and (TRAPTYPE = 5) then DISARM
        else if (TRAPSTR = 'ANTI-PRIEST') and (TRAPTYPE = 6) then DISARM
        else if (TRAPSTR = 'ALARM')       and (TRAPTYPE = 7) then DISARM
        else DOTRAPDM;
        if _exitachest_d then _exitachest := true
      end;


      { ── OPENCHST ── }
      procedure OPENCHST;
      var
        TC_O : PTCHAR;
      begin
        CLRRECT( 13, 8, 26, 2);
        MVCURSOR( 17, 8);
        PRINTSTR( 'WHO (#) WILL OPEN?');
        GETKEY;
        CHRXCHST := Ord( INCHAR) - Ord( '0') - 1;
        if (CHRXCHST < 0) or (CHRXCHST >= PARTYCNT) then exit;
        TC_O := CHARACTR[ CHRXCHST];
        if TC_O.STATUS <> OK then exit;
        if TRAPTYPE = 0 then begin _exitachest := true; exit; end;
        if Random( 1000) < TC_O.CHARLEV then begin _exitachest := true; exit; end;
        DOTRAPDM;
        if _done then exit
      end;


    begin  { ACHEST }
      _exitachest := false;
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
        if      INCHAR = 'O' then begin OPENCHST; if _done then break; end
        else if INCHAR = 'L' then EXITRWDS
        else if INCHAR = 'I' then begin INSPCHST; if _done then break; end
        else if INCHAR = 'C' then CALFOCH
        else if INCHAR = 'D' then begin DISARMTR; if _done then break; end
      until _done or _exitachest
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
        TC_IR : PTCHAR;
      begin
        CHARXXXX := Random( PARTYCNT);
        TC_IR    := CHARACTR[ CHARXXXX];
        while TC_IR.STATUS <> OK do
          begin
            CHARXXXX := (CHARXXXX + 1) mod PARTYCNT;
            TC_IR    := CHARACTR[ CHARXXXX]
          end;
        if TC_IR.POSS.POSSCNT = 8 then exit;
        CHARIIII := 0;
        { REWDCALC[4]=PERCBIGR, [2]=MAXTIMES, [0]=MININDX, [3]=RANGE, [1]=MFACTOR }
        while (CALCULAT( 1, 100, 1) < REWARDM.REWDCALC[ 4]) and
              (CHARIIII < REWARDM.REWDCALC[ 2]) do
          CHARIIII := CHARIIII + 1;
        ITEMINDX := REWARDM.REWDCALC[ 0]
                  + CALCULAT( 1, REWARDM.REWDCALC[ 3], 1)
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
          if TC_G.STATUS = OK then ADDLONGS( TC_G.GOLD, GOLD2ONE)
        end;
      PAUSE2
    end;


  begin  { CHSTGOLD }
    FillChar( GOLD2ONE, SizeOf( GOLD2ONE), 0);
    ENMYREWD;
    RDREWARD;
    CLEARPIC;
    if REWARDZ.BCHEST and (CHSTALRM <> 1) then
      begin
        ACHEST;
        if _done then exit;
        CLRRECT( 3, 5, 9, 5)
      end
    else
      CHSTALRM := 0;
    CLRRECT( 1, 11, 38, 4);
    PIC2SCRN( GETREC( ZSPCCHRS, 19, 512));
    for INDX := 1 to REWARDZ.REWRDCNT do
      begin
        GETREWRD( REWARDZ.REWARDXX[ INDX]^);
        if _done then exit
      end;
    GIVEGOLD
  end;


  { ── GIVEEXP ── }
  procedure GIVEEXP;
  var
    WEPSTY3I     : SmallInt;
    SPPCI        : SmallInt;
    BATRESLT     : TBATRSLT;
    CHARXXX      : SmallInt;
    KILLEXP      : TWIZLONG;
    _exitgiveexp : Boolean;   { set by CHKDRAIN for EXIT(GIVEEXP) }
    TC_GE        : PTCHAR;    { local pointer for GIVEEXP's own loops }


    { ── CNTALIVE ── }
    procedure CNTALIVE;
    var
      TC_CN : PTCHAR;
    begin
      ALIVECNT := 0;
      for LLBASE04 := 0 to PARTYCNT - 1 do
        begin
          TC_CN := CHARACTR[ LLBASE04];
          if TC_CN.STATUS = OK then ALIVECNT := ALIVECNT + 1
        end;
      if ALIVECNT = 0 then
        begin
          XGOTO := XCEMETRY;
          _done := true; exit   { EXIT(REWARDS) }
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
    procedure CHKDRAIN;
    var
      EXPTABLE : TEXP;
      TC_CK    : PTCHAR;

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
          CHAREXP := EXPTABLE[ Ord( XCLASS_P) * 13 + CURRLEVL]^
        else
          begin
            CHAREXP := EXPTABLE[ Ord( XCLASS_P) * 13 + 12]^;
            for CHARXXX := 13 to CURRLEVL do
              ADDLONGS( CHAREXP, EXPTABLE[ Ord( XCLASS_P) * 13 + 0]^)
          end;
        ADDLONGS( CHAREXP, KILLEXP);
        MVCURSOR( 1, 14);
        PRINTSTR( 'HE HAS ');
        PRLONG2( CHAREXP);
        PRINTSTR( ' EP NOW');
        PAUSE2
      end;

    begin  { CHKDRAIN }
      Move( IOCACHE[ GETREC( ZEXP, 0, SizeOf( TEXP))],
            EXPTABLE,
            SizeOf( TEXP));
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
              DROPLEVL( TC_CK.EXP, TC_CK.CHARLEV, TC_CK.XCLASS)
            end
        end;
      CLRRECT( 1, 11, 38, 4);
      if XGOTO = XREWARD2 then begin _exitgiveexp := true; exit; end;  { EXIT(GIVEEXP) }
      for CHARXXX := 0 to PARTYCNT - 1 do
        begin
          TC_CK := CHARACTR[ CHARXXX];
          if TC_CK.STATUS = OK then exit  { EXIT(CHKDRAIN) — at least one alive }
        end;
      XGOTO := XCEMETRY;
      _done := true; exit   { EXIT(REWARDS) — nobody survived }
    end;


  begin  { GIVEEXP }
    _exitgiveexp := false;
    Move( IOCACHE[ 0], BATRESLT, SizeOf( TBATRSLT));
    CACHEWRI := false;
    CNTALIVE;
    if _done then exit;
    CHKDRAIN;
    if _done or _exitgiveexp then exit;
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
        if TC_GE.STATUS = OK then ADDLONGS( TC_GE.EXP, EXPPERCH)
      end
  end;


begin  { REWARDS }
  _done := false;
  case XGOTO of
    XREWARD:
      begin
        XGOTO := XRUNNER;
        GIVEEXP;
        if _done then exit;
        CHSTGOLD
      end;
    XREWARD2:
      begin
        GIVEEXP;
        if _done then exit;
        LLBASE04 := 0;
        XGOTO    := XSCNMSG
      end
  end
end;


end.
