unit CINITUNIT;

{ Wizardry I — COMBAT's CINIT segment (AP P010501), an overlay of its own.
  Source: apple/Wizardry_v3-2/Wiz1B.DSK/COMBAT (v3.2).  Shares COMBAT's
  variables through COMBATG; run by the resident combat loop. }

interface

uses TYPES, CONSTS, GLOBALS, UTIL, SCREEN, COMBATG;

procedure CINIT;

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


procedure CINIT;

  procedure ENEMYPIC( ENEMYID: SmallInt);
  { ENEMYID = GETREC( ZSPCCHRS, PIC, 512), the portrait's IOCACHE offset. }
  begin
    if ENEMYID < 0 then
      begin
        ENEMYID := 0;              { AP: no picture, so use the first one }
        Write( Chr( 7))            {   and ring the bell                  }
      end;
    Poke( $02C4, Ord( IOCACHE[ ENEMYID + 500]));    { COLOR0, COLOR1: the }
    Poke( $02C5, Ord( IOCACHE[ ENEMYID + 501]));    {   portrait's hues   }
    PICTOSCR( ENEMYID)
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
    X := GETREC( ZZERO, 0, TSCNTOC_SIZE);    { flushes a pending cache write }
    Move( IOCACHE[ X], LLBASE04, 2);
    Move( DRAINED[ 0], BATRESLT.DRAINED[ 0], SizeOf( BATRESLT.DRAINED));
    for X := 1 to 4 do
      begin
        BRC := BATTLERC[ X];
        BRA := BRC^.A;
        BATRESLT.ENMYID[  X] := BRA.ENEMYID;
        BATRESLT.ENMYCNT[ X] := BRA.ENMYCNT
      end;
    Move( BATRESLT, IOCACHE[ 0], SizeOf( TBATRSLT))
  end;


  function INITATTK: Byte;                     { UNWNONE or U_COMBAT }
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
      { AP recurses for the next group (a tail call): a loop here, as a
        recursive routine makes MP add psptr to zero page, shifting the
        overlay's ZP layout away from the residents'. }
      var
        BRC  : ^TENEMY2;
        BRA  : ^TENEMY2A;
        BTG  : ^TENEMY;
        MORE : Boolean;
      begin
        repeat
          BRC := BATTLERC[ ENMYGRUP];
          BRA := BRC^.A;
          BTG := BRC^.B;
          repeat
            LOADENEMY( ENMYI, BTG^);
            if BTG.UNIQUE = 0 then
              ENMYI := BTG.ENMYTEAM;
          until BTG.UNIQUE <> 0;
          BRA.ENEMYID := ENMYI;
          MORE := false;
          if ENMYGRUP < 4 then
            if BTG.ENMYTEAM >= 0 then
              if ENMYGRUP <= MAZELEV then
                if Random( 100) < BTG.TEAMPERC then
                  begin
                    ENMYI    := BTG.ENMYTEAM;               { ENGROUPS( ENMYTEAM, }
                    ENMYGRUP := ENMYGRUP + 1;               {   ENMYGRUP + 1)     }
                    MORE     := true
                  end
        until not MORE
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
          BRA := BRC^.A;
          BRA.ENMYCNT  := 0;
          BRA.ALIVECNT := 0;
          BRA.ENEMYID  := -1
        end;
      ENGROUPS( ENEMYINX, 1);
      BRC := BATTLERC[ 1];
      BRA := BRC^.A;
      BTB := BRC^.B;
      ENEMYINX := BRA.ENEMYID;
      ENEMYPIC( GETREC( ZSPCCHRS, BTB.PIC, 512));
      for GROUPI := 1 to 4 do
        begin
          BRC := BATTLERC[ GROUPI];
          BRA := BRC^.A;
          BTB := BRC^.B;
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
      BRA0 := BRC0^.A;
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


    function FRIENDLY: Byte;                   { UNWNONE or U_COMBAT }
    var
      GOODLEAV : Boolean;
      ZERO99   : SmallInt;
      INDEX    : SmallInt;
      BRC1     : ^TENEMY2;
      BRA1     : ^TENEMY2A;
      BTB1     : ^TENEMY;
      TC       : PTCHAR;
    begin
      FRIENDLY := UNWNONE;
      BRC1 := BATTLERC[ 1];
      BTB1 := BRC1^.B;
      if BTB1.WEPVSTY3[ 0] then exit;                   { v3.2 WC005: resists }
      GOODLEAV := false;
      for INDEX := 0 to PARTYCNT - 1 do
        GOODLEAV := GOODLEAV or
                    (Byte( CHARACTR[ INDEX].ALIGN) = Byte( GOOD));
      if not GOODLEAV then exit;
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
      if (ZERO99 > INDEX) or (ZERO99 < 50) then exit;
      for INDEX := 1 to 4 do
        begin
          BRC1 := BATTLERC[ INDEX];
          BRA1 := BRC1^.A;
          BRA1.IDENTIFI := true
        end;
      BRC1 := BATTLERC[ 1];
      BTB1 := BRC1^.B;
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
          XGOTO := XRUNNER;
          exit( U_COMBAT)                               { EXIT( COMBAT) }
        end;
      for INDEX := 0 to PARTYCNT - 1 do
        begin
          TC := CHARACTR[ INDEX];
          if Byte( TC.ALIGN) = Byte( GOOD) then
            if (Random(2000)) = 565 then
              SETALIGN_CB( TC, EVIL)
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
    Result := FRIENDLY
  end;  { INITATTK }


begin  { CINIT }
  CMBEXIT := UNWNONE;
  if CINITFL1 = 0 then
    begin
      WIREBATL;
      CMBEXIT := INITATTK
    end
  else
    SVREWARD
end;  { CINIT }


end.
