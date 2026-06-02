unit CASTLEUNIT;

{ Wizardry I — CASTLE segment.
  Source: apple/wiz1c/CASTLE + CASTLE2.
  Key changes from Apple Pascal:
    - MOVELEFT record copies -> LOADTCHAR / SAVETCHAR (pointer-aware loaders)
    - WITH CHARACTR[X] DO -> local TC := CHARACTR[X] pointer
    - RANDOM MOD N -> Random(N)
    - SCNTOC.ALIGN/CLASS/STATUS arrays -> SCNTOC_ALIGN/CLASS/STATUS globals
    - CLASS field renamed XCLASS (reserved word in MP)
    - TWIZLONG fields LOW/MID/HIGH -> XLOW/XMID/XHIGH
    - LOSTXYL variant record -> flat LOSTXYL array
    - GOTOXY -> MVCURSOR; UNITCLEAR -> CLRRECT
    - GETLINE result in GTSTRING (not a parameter)
    - SPELLSKN: ^TSPELLSKN — access as TC.SPELLSKN^[i]
    - CPCALLED copy-protection: skipped in Atari port
    - KEYAVAIL: Peek($02FC) <> $FF
    - TEXP access: EXP[Ord(XCLASS)*13 + CHARLEV]^ (1-D pointer array)
    - MP nesting limit 3: hoisted to unit level —
        SPLPERLV, NWPRIEST, NWMAGE, MINSPCNT, MINMAG, MINPRI, SETSPELS,
        MOREHP, TRY2LRN, TRYMAGE, TRYPRI, TRYLEARN,
        GAINLOST, MADELEV, HEALHP }

interface

uses TYPES, CONSTS, GLOBALS, UTIL, crt;

procedure CASTLE;

implementation

{ ── Unit-level vars shared by hoisted sub-procedures ─────────────────────── }
var
  _partyx   : SmallInt;   { ADVNTINN's active-character index }
  _hpadd    : SmallInt;   { TAKENAP's HPADD param — used by hoisted HEALHP }
  _gold4nap : TWIZLONG;   { TAKENAP's payment counter — used by hoisted HEALHP }
  _iqpiety  : TATTRIB;    { TRYLEARN's active attribute — used by TRY2LRN }
  _learned  : Boolean;    { TRYLEARN's new-spell flag — written by TRY2LRN }
  _attribx  : TATTRIB;    { GAINLOST's attribute iterator — used by inline PRATTRIB }

{ ── var-param helpers (MP auto-deref type-resolution bug — see bug5) ──────── }

function GETNAME_C( var C: TCHAR): string;
begin GETNAME_C := C.NAME end;

function GETGOLD_C( var C: TCHAR): TWIZLONG;
begin GETGOLD_C := C.GOLD end;

procedure SETGOLD_C( var C: TCHAR; G: TWIZLONG);
begin
  C.GOLD.XLOW  := G.XLOW;
  C.GOLD.XMID  := G.XMID;
  C.GOLD.XHIGH := G.XHIGH
end;

{ ── Hoisted level-4+ procedures (ADVNTINN sub-tree) ──────────────────────── }

{ --- SETSPELS helpers --- }

procedure SPLPERLV( var SPELGRPS: TSPELL7G; LEVELMOD, LEVMOD2: SmallInt);
var SPGRPI, SPELLCNT : SmallInt;
begin
  SPELLCNT := CHARACTR[ _partyx].CHARLEV - LEVELMOD;
  if SPELLCNT <= 0 then exit;
  SPGRPI := 1;
  while (SPGRPI >= 1) and (SPGRPI <= 7) and (SPELLCNT > 0) do
    begin
      if SPELLCNT > SPELGRPS[ SPGRPI] then
        SPELGRPS[ SPGRPI] := SPELLCNT;
      SPGRPI   := SPGRPI   + 1;
      SPELLCNT := SPELLCNT - LEVMOD2
    end;
  for SPGRPI := 1 to 7 do
    if SPELGRPS[ SPGRPI] > 9 then
      SPELGRPS[ SPGRPI] := 9
end;

procedure NWPRIEST( MOD1, MOD2: SmallInt);
var TC : ^TCHAR;
begin
  TC := CHARACTR[ _partyx];
  SPLPERLV( TC.PRIESTSP, MOD1, MOD2)
end;

procedure NWMAGE( MOD1, MOD2: SmallInt);
var TC : ^TCHAR;
begin
  TC := CHARACTR[ _partyx];
  SPLPERLV( TC.MAGESP, MOD1, MOD2)
end;

procedure MINSPCNT( var SPLGRPS: TSPELL7G; GROUPI, LOWINDX, HIGHINDX: SmallInt);
var SPELLI, SPELKNOW : SmallInt; TC : ^TCHAR; SKNS : ^TSPELLSKN;
begin
  TC       := CHARACTR[ _partyx];
  SKNS     := TC.SPELLSKN;
  SPELKNOW := 0;
  for SPELLI := LOWINDX to HIGHINDX do
    if SKNS^[ SPELLI] then
      SPELKNOW := SPELKNOW + 1;
  SPLGRPS[ GROUPI] := SPELKNOW
end;

procedure MINMAG;
var TC : ^TCHAR;
begin
  TC := CHARACTR[ _partyx];
  MINSPCNT( TC.MAGESP, 1,  1,  4);
  MINSPCNT( TC.MAGESP, 2,  5,  6);
  MINSPCNT( TC.MAGESP, 3,  7,  8);
  MINSPCNT( TC.MAGESP, 4,  9, 11);
  MINSPCNT( TC.MAGESP, 5, 12, 14);
  MINSPCNT( TC.MAGESP, 6, 15, 18);
  MINSPCNT( TC.MAGESP, 7, 19, 21)
end;

procedure MINPRI;
var TC : ^TCHAR;
begin
  TC := CHARACTR[ _partyx];
  MINSPCNT( TC.PRIESTSP, 1, 22, 26);
  MINSPCNT( TC.PRIESTSP, 2, 27, 30);
  MINSPCNT( TC.PRIESTSP, 3, 31, 34);
  MINSPCNT( TC.PRIESTSP, 4, 35, 38);
  MINSPCNT( TC.PRIESTSP, 5, 39, 44);
  MINSPCNT( TC.PRIESTSP, 6, 45, 48);
  MINSPCNT( TC.PRIESTSP, 7, 49, 50)
end;

procedure SETSPELS;
begin
  MINPRI;
  MINMAG;
  case TCLASS( CHARACTR[ _partyx].XCLASS) of
     PRIEST:  NWPRIEST( 0, 2);
       MAGE:  NWMAGE(   0, 2);
     BISHOP:  begin NWPRIEST( 3, 4); NWMAGE( 0, 4) end;
       LORD:  NWPRIEST( 3, 2);
    SAMURAI:  NWMAGE(   3, 3)
  end
end;

{ --- MOREHP: HP roll for new level --- }

function MOREHP: SmallInt;
var HITPTS : SmallInt; TC : ^TCHAR;
begin
  TC := CHARACTR[ _partyx];
  case TCLASS( TC.XCLASS) of
    FIGHTER, LORD:         HITPTS := Random( 10);
    PRIEST,  SAMURAI:      HITPTS := Random(  8);
    THIEF,   BISHOP, NINJA: HITPTS := Random(  6);
    MAGE:                  HITPTS := Random(  4);
  end;
  HITPTS := HITPTS + 1;
  case TC.ATTRIB[ Byte( VITALITY)] of
    3:         HITPTS := HITPTS - 2;
    4, 5:      HITPTS := HITPTS - 1;
    16:        HITPTS := HITPTS + 1;
    17:        HITPTS := HITPTS + 2;
    18:        HITPTS := HITPTS + 3;
  end;
  if HITPTS < 1 then HITPTS := 1;
  MOREHP := HITPTS
end;

{ --- Spell learning (TRYLEARN sub-tree) --- }

procedure TRY2LRN( LOWINDX, HIGHINDX: SmallInt);
var SPELLI : SmallInt; SPLKNOWN : Boolean; TC : ^TCHAR; SKNS : ^TSPELLSKN;
begin
  TC       := CHARACTR[ _partyx];
  SKNS     := TC.SPELLSKN;
  SPLKNOWN := false;
  for SPELLI := LOWINDX to HIGHINDX do
    SPLKNOWN := SPLKNOWN or SKNS^[ SPELLI];
  for SPELLI := LOWINDX to HIGHINDX do
    if not SKNS^[ SPELLI] then
      if (Random( 30) < TC.ATTRIB[ Byte( _iqpiety)]) or (not SPLKNOWN) then
        begin
          _learned      := true;
          SPLKNOWN      := true;
          SKNS^[ SPELLI] := true
        end
end;

procedure TRYMAGE;
var TC : ^TCHAR;
begin
  _iqpiety := IQ;
  TC := CHARACTR[ _partyx];
  if TC.MAGESP[ 1] > 0 then TRY2LRN(  1,  4);
  if TC.MAGESP[ 2] > 0 then TRY2LRN(  5,  6);
  if TC.MAGESP[ 3] > 0 then TRY2LRN(  7,  8);
  if TC.MAGESP[ 4] > 0 then TRY2LRN(  9, 11);
  if TC.MAGESP[ 5] > 0 then TRY2LRN( 12, 14);
  if TC.MAGESP[ 6] > 0 then TRY2LRN( 15, 18);
  if TC.MAGESP[ 7] > 0 then TRY2LRN( 19, 21)
end;

procedure TRYPRI;
var TC : ^TCHAR;
begin
  _iqpiety := PIETY;
  TC := CHARACTR[ _partyx];
  if TC.PRIESTSP[ 1] > 0 then TRY2LRN( 22, 26);
  if TC.PRIESTSP[ 2] > 0 then TRY2LRN( 27, 30);
  if TC.PRIESTSP[ 3] > 0 then TRY2LRN( 31, 34);
  if TC.PRIESTSP[ 4] > 0 then TRY2LRN( 35, 38);
  if TC.PRIESTSP[ 5] > 0 then TRY2LRN( 39, 44);
  if TC.PRIESTSP[ 6] > 0 then TRY2LRN( 45, 48);
  if TC.PRIESTSP[ 7] > 0 then TRY2LRN( 49, 50)
end;

procedure TRYLEARN;
begin
  _learned := false;
  TRYMAGE;
  TRYPRI;
  if _learned then
    WriteLn( 'YOU LEARNED NEW SPELLS!!!!');
  SETSPELS
end;

{ --- Attribute gain/loss --- }

procedure GAINLOST;
var ATTRVAL : SmallInt; TC : ^TCHAR;
begin
  TC := CHARACTR[ _partyx];
  for _attribx := STRENGTH to LUCK do
    begin
      if Random( 4) <> 0 then
        begin
          ATTRVAL := TC.ATTRIB[ Byte( _attribx)];
          if Random( 130) < (TC.AGE div 52) then
            begin
              if (ATTRVAL = 18) and (Random( 6) <> 4) then
                { nothing }
              else
                begin
                  ATTRVAL := ATTRVAL - 1;
                  Write( 'YOU LOST ');
                  { inline PRATTRIB }
                  case _attribx of
                    STRENGTH: WriteLn( 'STRENGTH');
                          IQ: WriteLn( 'I.Q.');
                       PIETY: WriteLn( 'PIETY');
                    VITALITY: WriteLn( 'VITALITY');
                     AGILITY: WriteLn( 'AGILITY');
                        LUCK: WriteLn( 'LUCK');
                  end;
                  if _attribx = VITALITY then
                    if ATTRVAL = 2 then
                      begin
                        Write( '** YOU HAVE DIED OF OLD AGE **'); WriteLn;
                        TC.STATUS := LOST;
                        TC.HPLEFT := 0;
                        TC.ATTRIB[ Byte( _attribx)] := ATTRVAL;
                        exit   { exits GAINLOST }
                      end
                end
            end
          else
            begin
              if ATTRVAL <> 18 then
                begin
                  ATTRVAL := ATTRVAL + 1;
                  Write( 'YOU GAINED ');
                  case _attribx of
                    STRENGTH: WriteLn( 'STRENGTH');
                          IQ: WriteLn( 'I.Q.');
                       PIETY: WriteLn( 'PIETY');
                    VITALITY: WriteLn( 'VITALITY');
                     AGILITY: WriteLn( 'AGILITY');
                        LUCK: WriteLn( 'LUCK');
                  end
                end
            end;
          TC.ATTRIB[ Byte( _attribx)] := ATTRVAL
        end
    end
end;

{ --- Level advancement --- }

procedure MADELEV;
var CHARLEV, NEWHPMAX : SmallInt; TC : ^TCHAR;
begin
  TC := CHARACTR[ _partyx];
  Write( 'YOU MADE A LEVEL!'); WriteLn;
  TC.CHARLEV := TC.CHARLEV + 1;
  if TC.CHARLEV > TC.MAXLEVAC then
    TC.MAXLEVAC := TC.CHARLEV;
  SETSPELS;
  TRYLEARN;
  GAINLOST;
  NEWHPMAX := 0;
  TC := CHARACTR[ _partyx];   { refresh after GAINLOST may have changed TC.HPMAX }
  for CHARLEV := 1 to TC.CHARLEV do
    NEWHPMAX := NEWHPMAX + MOREHP;
  if Byte( TC.XCLASS) = Byte( SAMURAI) then
    NEWHPMAX := NEWHPMAX + MOREHP;
  if NEWHPMAX <= TC.HPMAX then
    NEWHPMAX := TC.HPMAX + 1;
  TC.HPMAX := NEWHPMAX
end;

{ --- Inn healing loop body --- }

procedure HEALHP;
var PAUSEX : SmallInt; TC : ^TCHAR; G : TWIZLONG;
begin
  MVCURSOR( 0, 13);
  TC := CHARACTR[ _partyx];
  TC.HPLEFT := TC.HPLEFT + _hpadd;
  if TC.HPLEFT > TC.HPMAX then
    TC.HPLEFT := TC.HPMAX;
  G := GETGOLD_C( CHARACTR[ _partyx]^);
  SUBLONGS( G, _gold4nap);
  SETGOLD_C( CHARACTR[ _partyx]^, G);
  Write( TC.NAME);
  WriteLn( ' IS HEALING UP');
  WriteLn;
  WriteLn;
  Write( '         HIT POINTS (');
  Write( TC.HPLEFT: 1);
  Write( '/');
  Write( TC.HPMAX: 1);
  Write( ')');
  WriteLn;
  WriteLn;
  Write( '               GOLD  ');
  G := GETGOLD_C( CHARACTR[ _partyx]^);
  PRNTLONG( G);
  MVCURSOR( 41, 10);
  for PAUSEX := 1 to 500 do
    begin end
end;


{ ── CASTLE segment ────────────────────────────────────────────────────────── }

procedure CASTLE;


  procedure GETPASS( var PASSWORD: string);
  var RANDX, CHRCNT : SmallInt;
  begin
    CHRCNT := 0;
    repeat
      GETKEY;
      if INCHAR <> Chr( CRETURN) then
        if CHRCNT < 15 then
          begin
            for RANDX := 0 to Random( 2) do
              Write( Chr( 88));   { 'X' — password echo mask }
            CHRCNT := CHRCNT + 1;
            PASSWORD[ CHRCNT] := INCHAR
          end
        else
          Write( Chr( 7))
    until INCHAR = Chr( CRETURN);
    WriteLn;
    PASSWORD[ 0] := Chr( CHRCNT)
  end;


  procedure CHARINFO( CHARX: SmallInt);
  var TC : ^TCHAR;
  begin
    TC := CHARACTR[ CHARX];
    MVCURSOR( 0, 5 + CHARX);
    Write( ' ');
    Write( (CHARX + 1): 2);
    Write( ' ');
    Write( TC.NAME);
    MVCURSOR( 19, 5 + CHARX);
    Write( Copy( SCNTOC_ALIGN[ TC.ALIGN], 1, 1));
    Write( '-');
    Write( Copy( SCNTOC_CLASS[ TC.XCLASS], 1, 3));
    Write( ' ');
    if TC.ARMORCL > -10 then
      Write( TC.ARMORCL: 2)
    else
      Write( 'LO');
    Write( TC.HPLEFT: 5);
    Write( ' ');
    if TC.STATUS = OK then
      if TC.LOSTXYL[ 1] <> 0 then
        WriteLn( 'POISON')
      else
        WriteLn( TC.HPMAX: 4)
    else
      WriteLn( SCNTOC_STATUS[ TC.STATUS])
  end;


  procedure DSPTITLE( TITLESTR: string);
  begin
    MVCURSOR( 0, 1);
    Write( '! CASTLE');
    Write( TITLESTR);
    Write( ' !')
  end;


  procedure DSPPARTY( TITLE: string);
  var CHARX : SmallInt;
  begin
    MVCURSOR( 0, 0);
    WriteLn( '+--------------------------------------+');
    DSPTITLE( TITLE);
    WriteLn;
    WriteLn( '+----------- CURRENT PARTY: -----------+');
    WriteLn;
    WriteLn( ' # CHARACTER NAME  CLASS AC HITS STATUS');
    for CHARX := 0 to 5 do
      if CHARX < PARTYCNT then
        CHARINFO( CHARX)
      else
        WriteLn( ' ');
    WriteLn( '+--------------------------------------+');
    Write( Chr( 11))
  end;


  procedure GOBOLTAC;
  begin
    DSPTITLE( 'SHOP');
    XGOTO  := XBOLTAC;
    XGOTO2 := XBOLTAC;
    exit   { EXIT(CASTLE) }
  end;


  procedure GOTEMPLE;
  begin
    DSPTITLE( 'TEMPLE');
    XGOTO  := XCANT;
    XGOTO2 := XBOLTAC;
    exit   { EXIT(CASTLE) }
  end;


  procedure EXTCASTL;
  begin
    DSPTITLE( 'EXIT');
    XGOTO := XEDGTOWN;
    exit   { EXIT(CASTLE) }
  end;


  procedure P010A26;
  begin
    MVCURSOR( 0, 13);
    Write( Chr( 11));
    Write( '             ');
    WriteLn( 'YOU MAY GO TO:');
    WriteLn;
    WriteLn( 'THE A)DVENTURER''S INN, G)ILGAMESH''');
    WriteLn( 'TAVERN, B)OLTAC''S TRADING POST, THE');
    WriteLn( 'TEMPLE OF C)ANT, OR THE E)DGE OF TOWN.')
  end;


  procedure GILGAMSH;
  var PRTYALGN : TALIGN;


    procedure GETALIGN;
    var LLBASE : SmallInt; ALIGNB : Byte;
    begin
      PRTYALGN := NEUTRAL;
      for LLBASE := 0 to PARTYCNT - 1 do
        begin
          ALIGNB := CHARACTR[ LLBASE].ALIGN;   { auto-deref → BYTE }
          if ALIGNB <> Byte( NEUTRAL) then
            PRTYALGN := TALIGN( ALIGNB)
        end
    end;


    procedure GILGMENU;
    begin
      MVCURSOR( 0, 13);
      Write( Chr( 11));
      Write( 'YOU MAY ');
      if PARTYCNT < 6 then
        begin
          Write( 'A)DD A MEMBER');
          if PARTYCNT = 0 then WriteLn( '') else WriteLn( ',');
          Write( '        ')
        end;
      if PARTYCNT > 0 then
        begin
          WriteLn( 'R)EMOVE A MEMBER,');
          Write( '        ');
          WriteLn( '#) SEE A MEMBER,')
        end
      else
        begin
          WriteLn( ' ');
          WriteLn( ' ')
        end;
      WriteLn;
      WriteLn( 'OR PRESS [RETURN] TO LEAVE');
      Write( Chr( 11))
    end;


    procedure ADDPARTY;
    var CHARI : SmallInt; CHARNAME : string; TC_SLOT : ^TCHAR;
    begin
      MVCURSOR( 0, 19);
      Write( 'WHO WILL JOIN ? >');
      GETLINE;
      CHARNAME := GTSTRING;
      if (CHARNAME = '') or (Length( CHARNAME) > 15) then exit;
      CHARI    := 0;
      LOADTCHAR( CHARI, CHARACTR[ PARTYCNT]^);
      TC_SLOT := CHARACTR[ PARTYCNT];
      while (CHARI < SCNTOC.RECPERDK[ ZCHAR]) and
            ((CHARNAME <> TC_SLOT.NAME) or
             (TC_SLOT.STATUS = LOST)) do
        begin
          CHARI := CHARI + 1;
          LOADTCHAR( CHARI, CHARACTR[ PARTYCNT]^)
        end;
      if CHARI = SCNTOC.RECPERDK[ ZCHAR] then
        begin CENTSTR( '** WHO? **'); exit end;
      if TC_SLOT.INMAZE or (TC_SLOT.LOSTXYL[ 3] <> 0) then
        begin CENTSTR( '** OUT **'); exit end;
      if PRTYALGN <> NEUTRAL then
        if TC_SLOT.ALIGN <> NEUTRAL then
          if PRTYALGN <> TC_SLOT.ALIGN then
            begin CENTSTR( '** BAD ALIGNMENT **'); exit end;
      MVCURSOR( 0, 20);
      Write( 'ENTER PASSWORD  >');
      GETPASS( CHARNAME);
      MVCURSOR( 0, 21);
      if CHARNAME <> TC_SLOT.PASSWORD then
        begin CENTSTR( '** THATS NOT IT **'); exit end;
      CHARDISK[ PARTYCNT] := CHARI;
      TC_SLOT.INMAZE := true;
      SAVETCHAR( CHARI, CHARACTR[ PARTYCNT]^);
      PARTYCNT := PARTYCNT + 1;
      GETALIGN;
      LLBASE04 := GETREC( ZZERO, 0, SizeOf( TSCNTOC));
      LOADSCNTOC;
      CHARINFO( PARTYCNT - 1)
    end;


    procedure REMOVE;
    var CHARX, CHARI : SmallInt;
    begin
      CHARI := GETCHARX( false, 'WHO WILL LEAVE');
      if (CHARI < 0) or (CHARI >= PARTYCNT) then exit;
      CHARACTR[ CHARI].INMAZE := false;
      SAVETCHAR( CHARDISK[ CHARI], CHARACTR[ CHARI]^);
      if CHARI <> (PARTYCNT - 1) then
        for CHARX := (CHARI + 1) to (PARTYCNT - 1) do
          begin
            CHARACTR[ CHARX - 1] := CHARACTR[ CHARX];
            CHARDISK[ CHARX - 1] := CHARDISK[ CHARX]
          end;
      PARTYCNT := PARTYCNT - 1;
      GETALIGN;
      DSPPARTY( 'TAVERN')
    end;


    procedure EXITCASL;
    begin
      LLBASE04 := Ord( INCHAR) - Ord( '1');
      if (LLBASE04 < 0) or (LLBASE04 >= PARTYCNT) then exit;
      MAZELEV := -1;
      XGOTO   := XINSPECT;
      exit   { EXIT(CASTLE) — cascades through GILGAMSH }
    end;


  begin  { GILGAMSH }
    GETALIGN;
    DSPTITLE( 'TAVERN');
    repeat
      CLRRECT( 0, 13, 40, 11);
      GILGMENU;
      MVCURSOR( 41, 0);
      GETKEY;
      if INCHAR = Chr( CRETURN) then exit;
      case INCHAR of
        'A': if PARTYCNT < 6 then ADDPARTY;
        'R': if PARTYCNT > 0 then REMOVE;
        '1', '2', '3', '4', '5', '6':
             if PARTYCNT > 0 then EXITCASL
      end
    until false
  end;  { GILGAMSH }


  procedure ADVNTINN;


    procedure GETWHO;
    begin
      DSPTITLE( 'INN');
      MVCURSOR( 0, 13);
      Write( Chr( 11));
      _partyx := GETCHARX( false, 'WHO WILL STAY');
      if _partyx < 0 then exit
    end;


    procedure INNMENU;
    var TC : ^TCHAR;
    begin
      TC := CHARACTR[ _partyx];
      MVCURSOR( 0, 13);
      Write( Chr( 11));
      Write( '   WELCOME ');
      Write( TC.NAME);
      WriteLn( '. WE HAVE:');
      WriteLn;
      WriteLn( '[A] THE STABLES (FREE!)');
      WriteLn( '[B] COTS. 10 GP/WEEK.');
      WriteLn( '[C] ECONOMY ROOMS. 50 GP/WEEK.');
      WriteLn( '[D] MERCHANT SUITES. 200 GP/WEEK.');
      WriteLn( '[E] ROYAL SUITES. 500 GP/WEEK.');
      Write(   '    OR [RETURN] TO LEAVE')
    end;


    procedure CHNEWLEV;
    var EXP2NEXT : TEXP;
         BIGLEV  : SmallInt;
         EXPNXTLV: TWIZLONG;
         CLSIDX  : SmallInt;
         TC      : ^TCHAR;
    var  EXI     : SmallInt;
    begin
      { AP: MOVELEFT from IOCACHE; stub: allocate zeroed entries }
      for EXI := 0 to 103 do GetMem( EXP2NEXT[ EXI]);
      TC := CHARACTR[ _partyx];
      CLSIDX := Ord( TCLASS( TC.XCLASS)) * 13;
      if TC.CHARLEV <= 12 then
        EXPNXTLV := EXP2NEXT[ CLSIDX + TC.CHARLEV]^
      else
        begin
          EXPNXTLV := EXP2NEXT[ CLSIDX + 12]^;
          for BIGLEV := 13 to TC.CHARLEV do
            ADDLONGS( EXPNXTLV, EXP2NEXT[ CLSIDX]^)
        end;
      if TESTLONG( EXPNXTLV, TC.EXP) <= 0 then
        MADELEV
      else
        begin
          Write( 'YOU NEED ');
          SUBLONGS( EXPNXTLV, TC.EXP);
          PRNTLONG( EXPNXTLV);
          WriteLn( ' MORE');
          WriteLn( 'EXPERIENCE POINTS TO MAKE LEVEL')
        end
    end;


    procedure TAKENAP( HPADD, GOLDAMT: SmallInt);
    var TC : ^TCHAR; G : TWIZLONG;
    begin
      _hpadd           := HPADD;
      _gold4nap.XHIGH  := 0;
      _gold4nap.XMID   := 0;
      _gold4nap.XLOW   := GOLDAMT;
      MVCURSOR( 0, 13);
      Write( Chr( 11));
      TC := CHARACTR[ _partyx];
      if GOLDAMT > 0 then
        begin
          G := GETGOLD_C( CHARACTR[ _partyx]^);
          while (TESTLONG( G, _gold4nap) >= 0) and
                (TC.HPLEFT < TC.HPMAX) and
                (Peek( $02FC) = $FF) do    { $FF = no key available }
            begin
              HEALHP;
              G := GETGOLD_C( CHARACTR[ _partyx]^)
            end
        end
      else
        begin
          Write( TC.NAME);
          WriteLn( ' IS NAPPING')
        end;
      if Peek( $02FC) <> $FF then
        begin
          MVCURSOR( 41, 0);
          GETKEY
        end;
      MVCURSOR( 0, 13);
      Write( Chr( 11));
      CHNEWLEV;
      SETSPELS;
      MVCURSOR( 0, 23);
      Write( 'PRESS [RETURN] TO LEAVE');
      MVCURSOR( 41, 0);
      repeat GETKEY until INCHAR = Chr( CRETURN);
      INCHAR := Chr( 0)
    end;


  begin  { ADVNTINN }
    repeat
      GETWHO;
      if Byte( CHARACTR[ _partyx].STATUS) = 0 then   { OK = 0 }
        repeat
          CLRRECT( 0, 13, 40, 11);
          INNMENU;
          MVCURSOR( 41, 0);
          GETKEY;
          case Byte( Ord( INCHAR)) of
            65: TAKENAP(  0,   0);   { 'A' STABLES  }
            66: TAKENAP(  1,  10);   { 'B' COTS     }
            67: TAKENAP(  3,  50);   { 'C' ECONOMY  }
            68: TAKENAP(  7, 200);   { 'D' MERCHANT }
            69: TAKENAP( 10, 500);   { 'E' ROYAL    }
          end;
          CHARINFO( _partyx)
        until (INCHAR = Chr( CRETURN)) or
              (Byte( CHARACTR[ _partyx].STATUS) <> 0)
    until false
  end;  { ADVNTINN }


begin  { CASTLE }
  ACMOD2   := 0;
  LIGHT    := 0;
  CHSTALRM := 0;
  { CPCALLED copy-protection: skipped in Atari port }
  ATTK012 := 0;
  FIZZLES := 0;
  TEXTMODE;
  if XGOTO2 <> XBOLTAC then
    DSPPARTY( '');
  XGOTO2 := XGILGAMS;
  if XGOTO = XGILGAMS then
    GILGAMSH;
  repeat
    DSPTITLE( 'MARKET');
    P010A26;
    repeat
      repeat
        MVCURSOR( 41, 0);
        GETKEY
      until (INCHAR = 'A') or (INCHAR = 'G') or (INCHAR = 'B') or
            (INCHAR = 'C') or (INCHAR = 'E');
    until (PARTYCNT > 0) or (INCHAR = 'E') or (INCHAR = 'G');
    case INCHAR of
      'G': GILGAMSH;
      'A': ADVNTINN;
      'C': GOTEMPLE;
      'B': GOBOLTAC;
      'E': EXTCASTL
    end
  until false
end;  { CASTLE }

end.
