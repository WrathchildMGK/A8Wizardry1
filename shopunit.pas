unit SHOPUNIT;

{ Wizardry I — SHOPS segment.
  Source: apple/wiz1c/SHOPS + SHOPS2.
  Key changes from Apple Pascal:
    - MP proc nesting tested to >=7 levels; original structure preserved.
    - EXIT(CANTSHOP) from DSP2STR/GETPAYER -> shopDone flag in CANTSHOP.
    - EXIT(CANT) from WELCOME (empty input) -> cantDone flag in CANT.
    - EXIT(DOPLAYER), EXIT(SELLIDUN), EXIT(PURCHASE) from own body -> exit.
    - EXIT(SHOPS) from level-2 procs -> exit (SHOPS has no code after case).
    - AASTRAA (inline EXIT(PURCHASE)/EXIT(TRANSACT)) -> CENTSTR + exit.
    - MOVELEFT TCHAR -> LOADTCHAR / SAVETCHAR.
    - MOVELEFT TOBJREC -> LOADOBJREC / SAVEOBJREC (in UTIL).
    - WITH CHARACTR[X] DO -> TC := CHARACTR[X] local pointer.
    - RANDOM MOD N -> Random(N).
    - TWIZLONG fields LOW/MID/HIGH -> XLOW/XMID/XHIGH.
    - LOSTXYL[n].LOCATION -> LOSTXYL[n] (flat array).
    - LOSTXYL.AWARDS[4] -> LOSTXYL[4] or 1 (set award bit 0).
    - SCNTOC.RECPERDK[ZXOBJECT] -> SCNTOC.RECPERDK[ZOBJECT].
    - GOTOXY -> GotoXY (crt).
    - GETLINE result in GTSTRING global.
    - READKEY -> GETKEY.
    - case TSTATUS -> case Byte() with integer literals (bug4 avoidance).
    - EXPBONUS.MID=25 -> XMID=25 (250,000 XP = 25 * 10000).
    - UNITREAD (CHARSET) calls: skipped (TODO Atari charset load). }

interface

uses TYPES, CONSTS, GLOBALS, UTIL, crt;

procedure SHOPS;

implementation

{ ── Var-param helpers for TCHAR fields (MP auto-deref type bugs) ─────────── }

function GETNAME_S( var C: TCHAR): string;
begin GETNAME_S := C.NAME end;

function GETGOLD_S( var C: TCHAR): TWIZLONG;
begin GETGOLD_S := C.GOLD end;

procedure SETGOLD_S( var C: TCHAR; G: TWIZLONG);
begin C.GOLD.XLOW := G.XLOW; C.GOLD.XMID := G.XMID; C.GOLD.XHIGH := G.XHIGH end;

{ ── SHOPS ────────────────────────────────────────────────────────────────── }

procedure SHOPS;


  { ── CANT ── }

  procedure CANT;
  var
    cantDone : Boolean;
    WHOHELP  : SmallInt;
    WHOPAY   : SmallInt;
    WHOHELPX : SmallInt;
    DISABLED : string;
    WHO      : TCHAR;


    procedure CANTSHOP;
    var
      shopDone : Boolean;


      procedure DSP2STR( STR1: string; STR2: string);
      begin
        CENTSTR( Concat( Concat( '** ', STR1), Concat( STR2, ' **')));
        shopDone := true;
        exit
      end;


      procedure WELCOME;
      begin
        GotoXY( 0, 13);
        Write( Chr( 11));
        WriteLn( ' WELCOME TO THE TEMPLE OF RADIANT CANT!');
        WriteLn( '');
        Write( 'WHO ARE YOU HELPING ? >');
        GETLINE;
        DISABLED := GTSTRING;
        if DISABLED = '' then
          begin cantDone := true; shopDone := true; exit end;
        WHOHELPX := 0;
        LOADTCHAR( WHOHELPX, WHO);
        while (WHOHELPX < SCNTOC.RECPERDK[ ZCHAR]) and
              (DISABLED <> WHO.NAME) do
          begin
            WHOHELPX := WHOHELPX + 1;
            LOADTCHAR( WHOHELPX, WHO)
          end;
        if WHOHELPX = SCNTOC.RECPERDK[ ZCHAR] then
          begin DSP2STR( '', 'WHO?'); exit end;
        if shopDone then exit;
        if ((WHO.LOSTXYL[ 1] + WHO.LOSTXYL[ 2] + WHO.LOSTXYL[ 3]) <> 0)
            or WHO.INMAZE then
          begin DSP2STR( WHO.NAME, ' IS NOT HERE'); exit end;
        if shopDone then exit;
        if WHO.STATUS = LOST then
          begin DSP2STR( WHO.NAME, ' IS LOST'); exit end;
        if shopDone then exit;
        if WHO.STATUS = OK then
          begin DSP2STR( WHO.NAME, ' IS OK'); exit end;
        WHOHELP := WHOHELPX
      end;


      procedure PAYCANT;
      var
        PAYAMT : TWIZLONG;


        procedure GETPAYER;
        var
          TC : ^TCHAR;
          G  : TWIZLONG;
        begin
          PAYAMT.XHIGH := 0;
          PAYAMT.XMID  := 0;
          case Byte( WHO.STATUS) of
            3 { PLYZE  }: PAYAMT.XLOW := 100;
            4 { STONED }: PAYAMT.XLOW := 200;
            5 { DEAD   }: PAYAMT.XLOW := 250;
            6 { ASHES  }: PAYAMT.XLOW := 500;
          end;
          MULTLONG( PAYAMT, WHO.CHARLEV);
          GotoXY( 0, 17);
          Write( Chr( 11));
          Write( 'THE DONATION WILL BE ');
          PRNTLONG( PAYAMT);
          WriteLn( '');
          WHOPAY := GETCHARX( false, 'WHO WILL TITHE');
          if WHOPAY = -1 then
            begin shopDone := true; exit end;
          TC := CHARACTR[ WHOPAY];
          if TESTLONG( PAYAMT, GETGOLD_S( TC^)) > 0 then
            begin DSP2STR( '', 'CHEAP APOSTATES! OUT!'); exit end;
          if shopDone then exit;
          G := GETGOLD_S( TC^);
          SUBLONGS( G, PAYAMT);
          SETGOLD_S( TC^, G)
        end;


        procedure DOCANT;


          procedure ASHLOST;
          begin
            if WHO.STATUS = DEAD then
              WHO.STATUS := ASHES
            else
              WHO.STATUS := LOST;
            WHO.INMAZE := false;
            SAVETCHAR( WHOHELP, WHO);
            WriteLn( '');
            if WHO.STATUS = LOST then
              DSP2STR( WHO.NAME, ' WILL BE BURIED')
            else
              DSP2STR( WHO.NAME, ' NEEDS KADORTO NOW')
          end;


        begin { DOCANT }
          GotoXY( 0, 17);
          Write( Chr( 11));
          Write( 'MURMUR - ');
          PAUSE2;
          Write( 'CHANT - ');
          PAUSE2;
          Write( 'PRAY - ');
          PAUSE2;
          Write( 'INVOKE!');
          WriteLn( '');
          if WHO.STATUS = DEAD then
            begin
              if Random( 100) > (50 + 3 * WHO.ATTRIB[ VITALITY]) then
                begin ASHLOST; exit end
              else
                WHO.HPLEFT := 1
            end
          else if WHO.STATUS = ASHES then
            begin
              if Random( 100) > (40 + 3 * WHO.ATTRIB[ VITALITY]) then
                begin ASHLOST; exit end
              else
                WHO.HPLEFT := WHO.HPMAX
            end;
          WHO.AGE := WHO.AGE + Random( 52) + 1;
          WHO.STATUS := OK;
          SAVETCHAR( WHOHELP, WHO);
          WriteLn( '');
          DSP2STR( WHO.NAME, ' IS WELL')
        end;


      begin { PAYCANT }
        GETPAYER;
        if shopDone then exit;
        DOCANT
      end;


    begin { CANTSHOP }
      shopDone := false;
      WELCOME;
      if shopDone then exit;
      PAYCANT
    end;


  begin { CANT }
    XGOTO := XCASTLE;
    cantDone := false;
    repeat
      CANTSHOP;
      if cantDone then exit
    until false
  end;


  { ── BOLTAC ── }

  procedure BOLTAC;
  var
    INVENTX  : SmallInt;
    HALFPRIC : SmallInt;
    XOBJECT  : TOBJREC;
    CHARI    : SmallInt;


    procedure DOPLAYER;
    const
      SELL     = 0;
      UNCURSE  = 1;
      IDENTIFY = 2;
    var
      OBJLIST : array[ 0..6] of SmallInt;
      POSSCNT : SmallInt;


      procedure DOBUY;
      var
        NOTPURCH : Boolean;
        SCROLDIR : SmallInt;
        BUYX     : SmallInt;
        TCC      : ^TCHAR;


        procedure SCROLPOS;
        var
          X  : SmallInt;
          TC : ^TCHAR;
        begin
          INVENTX := OBJLIST[ 6] - 1;
          for X := 1 to 6 do
            begin
              GotoXY( 0, 12 + X);
              Write( Chr( 29));
              repeat
                INVENTX := INVENTX + 1;
                if INVENTX >= SCNTOC.RECPERDK[ ZOBJECT] then
                  INVENTX := 1;
                LOADOBJREC( INVENTX, XOBJECT)
              until (XOBJECT.BOLTACXX <> 0) and (not XOBJECT.CURSED);
              OBJLIST[ X] := INVENTX;
              Write( X: 1);
              Write( ')');
              Write( XOBJECT.NAME: 15);
              Write( ' ');
              PRNTLONG( XOBJECT.PRICE);
              TC := CHARACTR[ CHARI];
              if not XOBJECT.CLASSUSE[ TC.XCLASS] then
                Write( ' UNUSABLE')
            end
        end;


        procedure SCROLNEG;
        var
          X  : SmallInt;
          TC : ^TCHAR;
        begin
          INVENTX := OBJLIST[ 1] + 1;
          for X := 6 downto 1 do
            begin
              GotoXY( 0, 12 + X);
              Write( Chr( 29));
              repeat
                INVENTX := INVENTX - 1;
                if INVENTX < 1 then
                  INVENTX := SCNTOC.RECPERDK[ ZOBJECT] - 1;
                LOADOBJREC( INVENTX, XOBJECT)
              until (XOBJECT.BOLTACXX <> 0) and (not XOBJECT.CURSED);
              OBJLIST[ X] := INVENTX;
              Write( X: 1);
              Write( ')');
              Write( XOBJECT.NAME: 15);
              Write( ' ');
              PRNTLONG( XOBJECT.PRICE);
              TC := CHARACTR[ CHARI];
              if not XOBJECT.CLASSUSE[ TC.XCLASS] then
                Write( ' UNUSABLE')
            end
        end;


        procedure PURCHASE;
        var
          INSERTX : SmallInt;
          TC      : ^TCHAR;
          TP      : ^TPOSSESS;
          G       : TWIZLONG;
        begin
          repeat
            NOTPURCH := false;
            GotoXY( 0, 21);
            WriteLn( Chr( 11));
            Write( 'PURCHASE WHICH ITEM ([RETURN] EXITS) ? >');
            GETKEY;
            BUYX := Ord( INCHAR) - Ord( '0');
            if INCHAR = Chr( CRETURN) then exit;
          until (BUYX > 0) and (BUYX <= 6);
          LOADOBJREC( OBJLIST[ BUYX], XOBJECT);
          TC := CHARACTR[ CHARI];
          if XOBJECT.BOLTACXX = 0 then
            begin CENTSTR( '** YOU BOUGHT THE LAST ONE **'); exit end;
          if TC.POSS.POSSCNT = 8 then
            begin CENTSTR( '** YOU CANT CARRY ANYTHING MORE **'); exit end;
          G := GETGOLD_S( TC^);
          if TESTLONG( G, XOBJECT.PRICE) < 0 then
            begin CENTSTR( '** YOU CANNOT AFFORD IT **'); exit end;
          if not XOBJECT.CLASSUSE[ TC.XCLASS] then
            begin
              GotoXY( 0, 22);
              Write( Chr( 11));
              Write( 'UNUSABLE ITEM - CONFIRM BUY (Y/N) ? >');
              repeat
                GETKEY
              until (INCHAR = 'Y') or (INCHAR = 'N');
              if INCHAR = 'N' then
                begin CENTSTR( '** WE ALL MAKE MISTAKES **'); exit end
            end
          else
            INCHAR := ' ';
          G := GETGOLD_S( TC^);
          SUBLONGS( G, XOBJECT.PRICE);
          SETGOLD_S( TC^, G);
          INSERTX := TC.POSS.POSSCNT + 1;
          TP := TC.POSS.POSSESS[ INSERTX];
          TP.EQUIPED := false;
          TP.IDENTIF := true;
          TP.CURSED  := false;
          TP.EQINDEX := OBJLIST[ BUYX];
          TC.POSS.POSSCNT := INSERTX;
          if XOBJECT.BOLTACXX > 0 then
            XOBJECT.BOLTACXX := XOBJECT.BOLTACXX - 1;
          SAVEOBJREC( OBJLIST[ BUYX], XOBJECT);
          if Ord( INCHAR) = Ord( 'Y') then
            CENTSTR( '** ITS YOUR MONEY **')
          else
            CENTSTR( '** JUST WHAT YOU NEEDED **')
        end;


      begin { DOBUY }
        INVENTX := 1;
        NOTPURCH := true;
        OBJLIST[ 1] := 1;
        OBJLIST[ 6] := 1;
        SCROLDIR := 1;
        GotoXY( 0, 13);
        Write( Chr( 11));
        repeat
          if NOTPURCH then
            if SCROLDIR = 1 then
              SCROLPOS
            else
              SCROLNEG;
          NOTPURCH := true;
          SCROLDIR := 1;
          GotoXY( 0, 20);
          Write( Chr( 11));
          Write( 'YOU HAVE ');
          TCC := CHARACTR[ CHARI];
          PRNTLONG( GETGOLD_S( TCC^));
          WriteLn( ' GOLD');
          WriteLn( 'YOU MAY P)URCHASE, SCROLL');
          Write( ' ': 8);
          WriteLn( 'F)ORWARD OR B)ACK, GO TO THE');
          Write( ' ': 8);
          Write( 'S)TART, OR L)EAVE');
          GotoXY( 41, 0);
          repeat
            GETKEY
          until (INCHAR = 'P') or (INCHAR = 'F') or
                (INCHAR = 'B') or (INCHAR = 'S') or
                (INCHAR = 'L');
          case INCHAR of
            'P': PURCHASE;
            'S': OBJLIST[ 6] := 1;
            'B': SCROLDIR := -1;
          end
        until INCHAR = 'L'
      end;


      procedure SELLIDUN( ACTION: SmallInt);
      var
        TRANOBJX : SmallInt;
        { POSSCNT, OBJLIST accessed from DOPLAYER's var section via nesting }


        procedure LISTPOSS;
        var
          TC : ^TCHAR;
          TP : ^TPOSSESS;
        begin
          GotoXY( 0, 13);
          Write( Chr( 11));
          TC := CHARACTR[ CHARI];
          POSSCNT := TC.POSS.POSSCNT;
          for TRANOBJX := 1 to POSSCNT do
            begin
              TP := TC.POSS.POSSESS[ TRANOBJX];
              OBJLIST[ TRANOBJX] := TP.EQINDEX;
              LOADOBJREC( OBJLIST[ TRANOBJX], XOBJECT);
              Write( TRANOBJX: 1);
              Write( Chr( 41));
              if TP.IDENTIF then
                Write( XOBJECT.NAME: 15)
              else
                Write( XOBJECT.NAMEUNK: 15);
              Write( ' ');
              DIVLONG( XOBJECT.PRICE, HALFPRIC);
              if ACTION = SELL then
                if not TP.IDENTIF then
                  begin
                    XOBJECT.PRICE.XHIGH := 0;
                    XOBJECT.PRICE.XMID  := 0;
                    XOBJECT.PRICE.XLOW  := 1
                  end;
              PRNTLONG( XOBJECT.PRICE);
              WriteLn( '')
            end
        end;


        procedure TRANSACT;
        var
          POSSX : SmallInt;
          TC    : ^TCHAR;
          TP    : ^TPOSSESS;
          TP2   : ^TPOSSESS;
          G     : TWIZLONG;
        begin
          LOADOBJREC( OBJLIST[ TRANOBJX], XOBJECT);
          DIVLONG( XOBJECT.PRICE, HALFPRIC);
          TC := CHARACTR[ CHARI];
          TP := TC.POSS.POSSESS[ TRANOBJX];
          if ACTION = SELL then
            begin
              if not TP.IDENTIF then
                begin
                  XOBJECT.PRICE.XHIGH := 0;
                  XOBJECT.PRICE.XMID  := 0;
                  XOBJECT.PRICE.XLOW  := 1
                end;
              if TP.CURSED then
                begin CENTSTR( '** WE DONT BUY CURSED ITEMS **'); exit end
            end
          else
            begin
              if (not TP.CURSED) and (ACTION = UNCURSE) then
                begin CENTSTR( '** THAT IS NOT A CURSED ITEM **'); exit end;
              if TP.IDENTIF and (ACTION = IDENTIFY) then
                begin CENTSTR( '** THAT HAS BEEN IDENTIFIED **'); exit end;
              G := GETGOLD_S( TC^);
              if TESTLONG( G, XOBJECT.PRICE) < 0 then
                begin CENTSTR( '** YOU CANT AFFORD THE FEE **'); exit end
            end;
          G := GETGOLD_S( TC^);
          if ACTION = SELL then
            ADDLONGS( G, XOBJECT.PRICE)
          else
            SUBLONGS( G, XOBJECT.PRICE);
          SETGOLD_S( TC^, G);
          if ACTION = IDENTIFY then
            TP.IDENTIF := true
          else
            begin
              if TRANOBJX < TC.POSS.POSSCNT then
                for POSSX := (TRANOBJX + 1) to TC.POSS.POSSCNT do
                  begin
                    TP  := TC.POSS.POSSESS[ POSSX - 1];
                    TP2 := TC.POSS.POSSESS[ POSSX];
                    TC.POSS.POSSESS[ POSSX - 1] := TP2
                  end;
              TC.POSS.POSSCNT := TC.POSS.POSSCNT - 1;
              LOADOBJREC( OBJLIST[ TRANOBJX], XOBJECT);
              if ACTION = SELL then
                if XOBJECT.BOLTACXX > -1 then
                  XOBJECT.BOLTACXX := XOBJECT.BOLTACXX + 1;
              SAVEOBJREC( OBJLIST[ TRANOBJX], XOBJECT)
            end;
          CENTSTR( '** ANYTHING ELSE, SIRE? **');
          LISTPOSS
        end;


      begin { SELLIDUN }
        LISTPOSS;
        repeat
          if POSSCNT = 0 then exit;
          GotoXY( 0, 22);
          if ACTION = SELL then
            begin
              Write( Chr( 11));
              Write( 'WHICH DO YOU WISH TO SELL ? >')
            end
          else if ACTION = UNCURSE then
            begin
              Write( Chr( 11));
              Write( 'WHICH DO YOU WISH UNCURSED ? >')
            end
          else
            begin
              Write( Chr( 11));
              Write( 'WHICH DO YOU WISH IDENTIFIED ? >')
            end;
          GETKEY;
          if Ord( INCHAR) = CRETURN then exit;
          TRANOBJX := Ord( INCHAR) - Ord( '0');
          if (TRANOBJX > 0) and (TRANOBJX <= POSSCNT) then
            TRANSACT
        until false
      end;


    var
      TC : ^TCHAR;

    begin { DOPLAYER }
      repeat
        GotoXY( 0, 13);
        Write( Chr( 11));
        Write( '      WELCOME ');
        TC := CHARACTR[ CHARI];
        Write( GETNAME_S( TC^));
        WriteLn( '');
        Write( '     YOU HAVE ');
        PRNTLONG( GETGOLD_S( TC^));
        WriteLn( ' GOLD');
        WriteLn( '');
        WriteLn( 'YOU MAY B)UY  AN ITEM,');
        WriteLn( '        S)ELL AN ITEM, HAVE AN ITEM');
        WriteLn( '        U)NCURSED,  OR HAVE AN ITEM');
        WriteLn( '        I)DENTIFIED, OR L)EAVE');
        GotoXY( 41, 0);
        GETKEY;
        case INCHAR of
          'U': SELLIDUN( UNCURSE);
          'I': SELLIDUN( IDENTIFY);
          'S': SELLIDUN( SELL);
          'B': DOBUY;
          'L': exit;
        end
      until false
    end;


  begin { BOLTAC }
    HALFPRIC := 2;
    XGOTO := XCASTLE;
    repeat
      GotoXY( 0, 13);
      Write( Chr( 11));
      Write( '       WELCOME TO THE TRADING POST');
      WriteLn( '');
      CHARI := GETCHARX( false, 'WHO WILL ENTER');
      if CHARI = -1 then exit;
      if CHARI < PARTYCNT then
        DOPLAYER
    until false
  end;


  { ── CEMETARY ── }

  procedure CEMETARY;
  var
    TWO : SmallInt;


    procedure TOMBSTON( CHARI: SmallInt);
    var
      TOMBY : SmallInt;
      TOMBX : SmallInt;


      procedure DSPTOMBL( TOMBCHRS: string);
      begin
        MVCURSOR( TOMBX, TOMBY);
        PRINTSTR( TOMBCHRS);
        TOMBY := TOMBY + 1
      end;


    begin { TOMBSTON }
      TOMBX := 20 * (CHARI mod 2);
      TOMBY :=  6 * (CHARI div 2);
      UNITREAD_BUF( SCNTOCBL + 2, CHARSET[0]);   { tombstone charset }
      MVCURSOR( TOMBX, TOMBY);
      DSPTOMBL( '+,-.');   { CHR(43) CHR(44) CHR(45) CHR(46) }
      DSPTOMBL( '/012');   { CHR(47) CHR(48) CHR(49) CHR(50) }
      DSPTOMBL( '3456');   { CHR(51) CHR(52) CHR(53) CHR(54) }
      DSPTOMBL( '789:');   { CHR(55) CHR(56) CHR(57) CHR(58) }
      DSPTOMBL( ';<=>');   { CHR(59) CHR(60) CHR(61) CHR(62) }
      DSPTOMBL( '?XYZ');   { CHR(63) CHR(88) CHR(89) CHR(90) — last line jumps XYZ }
      UNITREAD_BUF( SCNTOCBL + 1, CHARSET[0]);   { restore normal charset }
      MVCURSOR( TOMBX + 1, TOMBY - 2);
      PRINTNUM( CHARACTR[ CHARI]^.AGE div 52, 2);
      MVCURSOR( TOMBX + 4, TOMBY - 4);
      PRINTSTR( GETNAME_S( CHARACTR[ CHARI]^))
    end;


    procedure BADSTUFF;


      procedure BREAKPOS;
      var
        X     : SmallInt;
        POSSX : SmallInt;
        TC    : ^TCHAR;
        TP    : ^TPOSSESS;
      begin
        TC := CHARACTR[ LLBASE04];
        for POSSX := 1 to TC.POSS.POSSCNT do
          begin
            TP := TC.POSS.POSSESS[ POSSX];
            if not TP.CURSED then
              if Random( 21) > TC.ATTRIB[ LUCK] then
                TP.EQINDEX := 0
          end;
        X := 0;
        for POSSX := 1 to TC.POSS.POSSCNT do
          begin
            TP := TC.POSS.POSSESS[ POSSX];
            if TP.EQINDEX <> 0 then
              begin
                X := X + 1;
                TC.POSS.POSSESS[ X] := TC.POSS.POSSESS[ POSSX]
              end
          end;
        TC.POSS.POSSCNT := X
      end;


    var
      TC : ^TCHAR;
      G  : TWIZLONG;

    begin { BADSTUFF }
      TWO := 2;
      for LLBASE04 := 0 to PARTYCNT - 1 do
        begin
          TC := CHARACTR[ LLBASE04];
          if TC.STATUS <> LOST then
            begin
              if TC.STATUS < DEAD then
                TC.STATUS := DEAD;
              TC.INMAZE := false;
              G := GETGOLD_S( TC^);
              DIVLONG( G, TWO);
              SETGOLD_S( TC^, G);
              BREAKPOS;
              if Random( 50) < MAZELEV then
                begin
                  TC.LOSTXYL[ 1] := -1;
                  TC.LOSTXYL[ 2] := -1;
                  TC.LOSTXYL[ 3] := -1
                end
              else
                begin
                  TC.LOSTXYL[ 1] := MAZEX;
                  TC.LOSTXYL[ 2] := MAZEY;
                  TC.LOSTXYL[ 3] := MAZELEV
                end;
              SAVETCHAR( CHARDISK[ LLBASE04], TC^)
            end
        end
    end;


  begin { CEMETARY }
    BADSTUFF;
    CLRRECT( 0, 0, 40, 24);
    GRAPHICS;
    for LLBASE04 := 0 to PARTYCNT - 1 do
      TOMBSTON( LLBASE04);
    UNITREAD_BUF( SCNTOCBL + 2, CHARSET[0]);   { tombstone charset for border }
    MVCURSOR( 0, 19);
    PRINTCHR( Chr( 33));          { upper-left corner }
    for LLBASE04 := 1 to 38 do
      PRINTCHR( Chr( 34));        { horizontal line }
    PRINTCHR( Chr( 35));          { upper-right corner }
    MVCURSOR( 0, 20);
    PRINTCHR( Chr( 36));          { vertical bar }
    MVCURSOR( 39, 20);
    PRINTCHR( Chr( 36));
    MVCURSOR( 0, 21);
    PRINTCHR( Chr( 39));
    for LLBASE04 := 1 to 38 do
      PRINTCHR( Chr( 34));
    PRINTCHR( Chr( 40));
    MVCURSOR( 0, 22);
    PRINTCHR( Chr( 36));
    MVCURSOR( 39, 22);
    PRINTCHR( Chr( 36));
    MVCURSOR( 0, 23);
    PRINTCHR( Chr( 37));
    for LLBASE04 := 1 to 38 do
      PRINTCHR( Chr( 34));
    PRINTCHR( Chr( 38));
    UNITREAD_BUF( SCNTOCBL + 1, CHARSET[0]);   { restore normal charset }
    MVCURSOR( 1, 20);
    PRINTSTR( 'YOUR ENTIRE PARTY HAS BEEN SLAUGHTERED');
    MVCURSOR( 1, 22);
    PRINTSTR( '  PRESS RETURN TO LEAVE THE CEMETERY  ');
    PARTYCNT := 0;
    repeat
      GETKEY
    until INCHAR = Chr( CRETURN);
    Write( Chr( 12));
    GotoXY( 41, 0);
    LLBASE04 := -2;
    XGOTO    := XSCNMSG;
    exit
  end;


  { ── EDGETOWN ── }

  procedure EDGETOWN;


    procedure ENTMAZE;
    begin
      GotoXY( 0, 13);
      WriteLn( Chr( 11));
      WriteLn( 'ENTERING': 24);
      WriteLn( SCNTOC.GAMENAME: 20 + Length( SCNTOC.GAMENAME) div 2);
      GotoXY( 41, 0);
      XGOTO    := XNEWMAZE;
      MAZEX    :=  0;
      MAZEY    :=  0;
      MAZELEV  := -1;
      DIRECTIO :=  0;
      exit
    end;


    procedure UPDCHARS;
    var
      X  : SmallInt;
      TC : ^TCHAR;
    begin
      for X := 0 to PARTYCNT - 1 do
        begin
          TC := CHARACTR[ X];
          TC.INMAZE := false;
          SAVETCHAR( CHARDISK[ X], TC^)
        end;
      PARTYCNT := 0;
      exit
    end;


  begin { EDGETOWN }
    GotoXY( 0, 13);
    if PARTYCNT = 0 then
      begin
        Write( Chr( 11));
        WriteLn( 'YOU MAY GO TO THE T)RAINING GROUNDS,');
        WriteLn( 'RETURN TO THE C)ASTLE, OR L)EAVE THE');
        WriteLn( 'GAME.')
      end
    else
      begin
        Write( Chr( 11));
        WriteLn( 'YOU MAY ENTER THE M)AZE, THE T)RAINING');
        WriteLn( 'GROUNDS, C)ASTLE,  OR L)EAVE THE GAME.')
      end;
    repeat
      GotoXY( 41, 0);
      GETKEY
    until (INCHAR = 'T') or (INCHAR = 'C') or (INCHAR = 'L') or
          ((INCHAR = 'M') and (PARTYCNT > 0));
    if INCHAR = 'M' then
      ENTMAZE
    else if INCHAR = 'T' then
      begin
        XGOTO := XTRAININ;
        UPDCHARS
      end
    else if INCHAR = 'L' then
      begin
        XGOTO := XDONE;
        UPDCHARS
      end
    else
      begin
        XGOTO := XCASTLE;
        exit
      end
  end;


  { ── CHK4WIN ── }

  procedure CHK4WIN;
  var
    POSSI   : SmallInt;
    CHARX   : SmallInt;
    WONGAME : Boolean;
    TC      : ^TCHAR;
    TP      : ^TPOSSESS;


    procedure CONGRATS;
    var
      EXPBONUS : TWIZLONG;
    begin
      EXPBONUS.XHIGH := 0;
      EXPBONUS.XLOW  := 0;
      EXPBONUS.XMID  := 25;    { 250,000 XP = 25 * 10,000 }
      for CHARX := 0 to PARTYCNT - 1 do
        begin
          TC := CHARACTR[ CHARX];
          TC.POSS.POSSCNT := 0;
          TC.GOLD.XHIGH := 0;
          TC.GOLD.XMID  := 0;
          TC.GOLD.XLOW  := 0;
          ADDLONGS( TC.EXP, EXPBONUS);
          TC.LOSTXYL[ 4] := TC.LOSTXYL[ 4] or 1   { set Honor Guard award bit }
        end;
      Write( Chr( 12));
      WriteLn( '*** CONGRATULATIONS ***': 32);
      TEXTMODE;
      WriteLn( '');
      WriteLn( 'YOU HAVE COMPLETED YOUR QUEST AND THE');
      WriteLn( 'AMULET IS NOW BACK IN THE HANDS OF');
      WriteLn( 'YOUR BENIFICENT RULER, TREBOR.');
      WriteLn( '');
      WriteLn( 'IN RETURN FOR THIS, HE GRANTS YOU A');
      WriteLn( 'BOON OF 250,000 EXPERIENCE POINTS');
      WriteLn( 'EACH!');
      WriteLn( '');
      WriteLn( 'ADDITIONALLY, YOU WILL BE INITIATED');
      WriteLn( 'INTO THE OVERLORD''S HONOR GUARD AND');
      WriteLn( 'THUS WILL BE ENTITLED TO WEAR THE');
      WriteLn( 'CHEVRON (>) OF THIS RANK EVERMORE.');
      WriteLn( '');
      WriteLn( 'HOWEVER, YOU MUST GIVE UP ALL YOUR');
      WriteLn( 'EQUIPMENT AND MOST OF YOUR MONEY TO');
      WriteLn( 'PAY FOR YOUR INITIATION.');
      WriteLn( '');
      WriteLn( 'PRESS [RETURN], HONORED ONES');
      GotoXY( 41, 0);
      GETKEY;
      Write( Chr( 12))
    end;


  begin { CHK4WIN }
    WONGAME := false;
    for CHARX := 0 to PARTYCNT - 1 do
      begin
        TC := CHARACTR[ CHARX];
        for POSSI := 1 to TC.POSS.POSSCNT do
          begin
            TP := TC.POSS.POSSESS[ POSSI];
            if TP.EQINDEX = 94 then WONGAME := true
          end;
        TC.LOSTXYL[ 1] := 0;
        TC.LOSTXYL[ 2] := 0;
        TC.LOSTXYL[ 3] := 0
      end;
    if WONGAME then CONGRATS;
    for CHARX := 0 to PARTYCNT - 1 do
      begin
        TC := CHARACTR[ CHARX];
        TC.INMAZE := TC.STATUS = OK;
        SAVETCHAR( CHARDISK[ CHARX], TC^)
      end;
    CHARX := 0;
    POSSI := 0;
    while CHARX < PARTYCNT do
      begin
        CHARACTR[ POSSI] := CHARACTR[ CHARX];
        CHARDISK[ POSSI] := CHARDISK[ CHARX];
        if Byte( CHARACTR[ POSSI].STATUS) = 0 then  { OK = 0 }
          POSSI := POSSI + 1;
        CHARX := CHARX + 1
      end;
    PARTYCNT := POSSI;
    XGOTO := XCASTLE;
    exit
  end;


begin { SHOPS }
  case XGOTO of
    XCEMETRY : CEMETARY;
    XCANT    : CANT;
    XBOLTAC  : BOLTAC;
    XCHK4WIN : CHK4WIN;
    XEDGTOWN : EDGETOWN;
  end
end;

end.
