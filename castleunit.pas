unit CASTLEUNIT;

{ Wizardry I — CASTLE segment.
  Source: apple/Wizardry_v3-2/Wiz1C.DSK/CASTLE + CASTLE2 (v3.2).
  Key changes from Apple Pascal:
    - MOVELEFT record copies -> LOADTCHAR / SAVETCHAR (pointer-aware loaders)
    - WITH CHARACTR[X] DO -> local TC := CHARACTR[X] pointer
    - RANDOM MOD N -> Random(N)
    - SCNTOC.ALIGN/CLASS/STATUS arrays -> SCNTOC_ALIGN/CLASS/STATUS globals
    - CLASS field renamed XCLASS (reserved word in MP)
    - TWIZLONG fields LOW/MID/HIGH -> XLOW/XMID/XHIGH
    - LOSTXYL variant record -> flat LOSTXYL array
    - GETLINE result in GTSTRING (not a parameter)
    - SPELLSKN: ^TSPELLSKN — access as TC^.SPELLSKN^[i]
    - CPCALLED copy-protection: skipped in Atari port
    - KEYAVAIL: Peek($02FC) <> $FF
    - TEXP access: EXP[Ord(XCLASS)*13 + CHARLEV]^ (1-D pointer array)
    - MP nesting limit 3: hoisted to unit level —
        SPLPERLV, NWPRIEST, NWMAGE, MINSPCNT, MINMAG, MINPRI, SETSPELS,
        MOREHP, TRY2LRN, TRYMAGE, TRYPRI, TRYLEARN,
        GAINLOST, MADELEV, HEALHP
    - EXIT( CASTLE / ADVNTINN) from nested routines: unwind codes (CONSTS);
      EXIT( ADDPARTY) in EXITADDP and EXIT( GAINLOST) in OLDAGE are inlined
      into their targets, so a plain exit does it. }

interface

uses TYPES, CONSTS, GLOBALS, UTIL, SCREEN;

procedure CASTLE;

implementation

const
  U_CASTLE   = $01;       { unwind targets: AP P010A01, P010A0F }
  U_ADVNTINN = $0F;

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
  SKNS     := TC^.SPELLSKN;
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
  case TCLASS( TC^.XCLASS) of
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
  SKNS     := TC^.SPELLSKN;
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
  for CHARLEV := 1 to TC^.CHARLEV do
    NEWHPMAX := NEWHPMAX + MOREHP;
  if Byte( TC^.XCLASS) = Byte( SAMURAI) then
    NEWHPMAX := NEWHPMAX + MOREHP;
  if NEWHPMAX <= TC.HPMAX then
    NEWHPMAX := TC.HPMAX + 1;
  TC.HPMAX := NEWHPMAX
end;

{ --- Inn healing loop body --- }

procedure HEALHP;
var PAUSEX : SmallInt; TC : ^TCHAR;
begin
  GotoXY( 0, 13);
  TC := CHARACTR[ _partyx];
  TC.HPLEFT := TC.HPLEFT + _hpadd;
  if TC.HPLEFT > TC.HPMAX then
    TC.HPLEFT := TC.HPMAX;
  SUBLONGS( TC.GOLD, _gold4nap);
  Write( TC.NAME);
  WriteLn( ' IS HEALING UP');
  WriteLn;
  WriteLn;
  Write( '         HIT POINTS (');
  Write( TC.HPLEFT);
  Write( '/');
  Write( TC.HPMAX);
  Write( ')');
  WriteLn;
  WriteLn;
  Write( '               GOLD  ');
  PRNTLONG( TC.GOLD);
  GotoXY( 41, 10);
  for PAUSEX := 1 to 500 do
    begin end
end;


{ ── CASTLE segment ────────────────────────────────────────────────────────── }

procedure CASTLE;


  procedure CHARINFO( CHARX: SmallInt);
  var TC : ^TCHAR;
  begin
    TC := CHARACTR[ CHARX];
    GotoXY( 0, 5 + CHARX);
    Write( ' ');
    WRITEINT( (CHARX + 1), 2);
    Write( ' ');
    Write( TC.NAME);
    GotoXY( 19, 5 + CHARX);
    Write( LEFTSTR( ALIGNNAME( Byte( TC^.ALIGN)), 1));
    Write( '-');
    Write( LEFTSTR( CLASSNAME( Byte( TC^.XCLASS)), 3));
    Write( ' ');
    if TC.ARMORCL > -10 then
      WRITEINT( TC.ARMORCL, 2)
    else
      Write( 'LO');
    WRITEINT( TC.HPLEFT, 5);
    Write( ' ');
    if TC^.STATUS = OK then
      if TC.LOSTXYL[ 1] <> 0 then
        WriteLn( 'POISON')
      else
        begin WRITEINT( TC.HPMAX, 4); WriteLn end
    else
      WriteLn( STATNAME( Byte( TC^.STATUS)))
  end;


  procedure DSPTITLE( TITLESTR: string);
  begin
    GotoXY( 0, 1);
    Write( '! CASTLE');
    SPACES( 30 - Length( TITLESTR));
    Write( TITLESTR);
    Write( ' !')
  end;


  procedure DSPPARTY( TITLE: string);
  var CHARX : SmallInt;
  begin
    GotoXY( 0, 0);
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
        WriteLn( Chr( 29));
    WriteLn( '+--------------------------------------+');
    Write( Chr( 11))
  end;


  function GOBOLTAC: Byte;
  begin
    DSPTITLE( 'SHOP');
    XGOTO  := XBOLTAC;
    XGOTO2 := XBOLTAC;
    GOBOLTAC := U_CASTLE                 { EXIT( CASTLE) }
  end;


  function GOTEMPLE: Byte;
  begin
    DSPTITLE( 'TEMPLE');
    XGOTO  := XCANT;
    XGOTO2 := XBOLTAC;
    GOTEMPLE := U_CASTLE                 { EXIT( CASTLE) }
  end;


  function EXTCASTL: Byte;
  begin
    DSPTITLE( 'EXIT');
    XGOTO := XEDGTOWN;
    EXTCASTL := U_CASTLE                 { EXIT( CASTLE) }
  end;


  procedure P010A26;
  begin
    GotoXY( 0, 13);
    Write( Chr( 11));
    Write( '             ');
    WriteLn( 'YOU MAY GO TO:');
    WriteLn;
    WriteLn( 'THE A)DVENTURER''S INN, G)ILGAMESH''S');   { v3.2 WC004 }
    WriteLn( 'TAVERN, B)OLTAC''S TRADING POST, THE');
    WriteLn( 'TEMPLE OF C)ANT, OR THE E)DGE OF TOWN.')
  end;


  function GILGAMSH: Byte;
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
      GotoXY( 0, 13);
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
          WriteLn( Chr( 29));
          WriteLn( Chr( 29))
        end;
      WriteLn;
      WriteLn( 'OR PRESS [RETURN] TO LEAVE');
      Write( Chr( 11))
    end;


    procedure ADDPARTY;
    var CHARI : SmallInt; CHARNAME : string; TC_SLOT : ^TCHAR;
    begin
      GotoXY( 0, 19);
      Write( 'WHO WILL JOIN ? >');
      GETLINE;
      CHARNAME := GTSTRING;
      if (CHARNAME = '') or (Length( CHARNAME) > 15) then exit;
      CHARI    := 0;
      TC_SLOT := CHARACTR[ PARTYCNT];
      LOADTCHAR( CHARI, TC_SLOT^);
      while (CHARI < SCNTOC.RECPERDK[ ZCHAR]) and
            ((CHARNAME <> TC_SLOT.NAME) or
             (TC_SLOT^.STATUS = LOST)) do
        begin
          CHARI := CHARI + 1;
          LOADTCHAR( CHARI, TC_SLOT^)
        end;
      if CHARI = SCNTOC.RECPERDK[ ZCHAR] then
        begin CENTSTR( '** WHO? **'); exit end;
      if TC_SLOT.INMAZE or (TC_SLOT.LOSTXYL[ 3] <> 0) then
        begin CENTSTR( '** OUT **'); exit end;
      if PRTYALGN <> NEUTRAL then
        if TC_SLOT^.ALIGN <> NEUTRAL then
          if PRTYALGN <> TC_SLOT^.ALIGN then
            begin CENTSTR( '** BAD ALIGNMENT **'); exit end;
      CHARDISK[ PARTYCNT] := CHARI;
      TC_SLOT.INMAZE := true;
      SAVETCHAR( CHARI, TC_SLOT^);
      PARTYCNT := PARTYCNT + 1;
      GETALIGN;
      LLBASE04 := GETREC( ZZERO, 0, SizeOf( TSCNTOC));
      LOADSCNTOC;
      CHARINFO( PARTYCNT - 1)
    end;


    procedure REMOVE;
    var CHARX, CHARI, DISKX : SmallInt; TC : ^TCHAR;
    begin
      CHARI := GETCHARX( false, 'WHO WILL LEAVE');
      if (CHARI < 0) or (CHARI >= PARTYCNT) then exit;
      TC := CHARACTR[ CHARI];
      TC.INMAZE := false;
      SAVETCHAR( CHARDISK[ CHARI], TC^);
      { AP copies TCHAR records down.  CHARACTR holds pointers to the six
        fixed slots, so swap instead: the leaver's slot rotates to the end
        and CHARACTR stays a permutation of the slots (no two entries may
        share a slot, or the next ADDPARTY would overwrite a member). }
      if CHARI <> (PARTYCNT - 1) then
        for CHARX := (CHARI + 1) to (PARTYCNT - 1) do
          begin
            TC := CHARACTR[ CHARX - 1];
            CHARACTR[ CHARX - 1] := CHARACTR[ CHARX];
            CHARACTR[ CHARX]     := TC;
            DISKX := CHARDISK[ CHARX - 1];
            CHARDISK[ CHARX - 1] := CHARDISK[ CHARX];
            CHARDISK[ CHARX]     := DISKX
          end;
      PARTYCNT := PARTYCNT - 1;
      GETALIGN;
      DSPPARTY( 'TAVERN')
    end;


    function EXITCASL: Byte;
    begin
      EXITCASL := UNWNONE;
      LLBASE04 := Ord( INCHAR) - Ord( '1');
      if (LLBASE04 < 0) or (LLBASE04 >= PARTYCNT) then exit;
      MAZELEV  := -1;
      XGOTO    := XINSPECT;
      EXITCASL := U_CASTLE                 { EXIT( CASTLE) }
    end;


  begin  { GILGAMSH }
    Result := UNWNONE;
    GETALIGN;
    DSPTITLE( 'TAVERN');
    repeat
      UNITCLEAR( 1);
      GILGMENU;
      GotoXY( 41, 0);
      GETKEY;
      if INCHAR = Chr( CRETURN) then exit;
      case INCHAR of
        'A': if PARTYCNT < 6 then ADDPARTY;
        'R': if PARTYCNT > 0 then REMOVE;
        '1', '2', '3', '4', '5', '6':
             if PARTYCNT > 0 then
               if EXITCASL <> UNWNONE then exit( U_CASTLE)
      end
    until false
  end;  { GILGAMSH }


  procedure ADVNTINN;


    function GETWHO: Byte;
    begin
      GETWHO := UNWNONE;
      DSPTITLE( 'INN');
      GotoXY( 0, 13);
      Write( Chr( 11));
      _partyx := GETCHARX( false, 'WHO WILL STAY');
      if _partyx < 0 then GETWHO := U_ADVNTINN          { EXIT( ADVNTINN) }
    end;


    procedure INNMENU;
    var TC : ^TCHAR;
    begin
      TC := CHARACTR[ _partyx];
      GotoXY( 0, 13);
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
      WriteLn;
      WriteLn( '[G] POOL PARTY GOLD.');           { v3.2 WC040 }
      WriteLn;
      Write(   '    OR [RETURN] TO LEAVE')
    end;


    procedure CHNEWLEV;
    var EXP2NEXT : TEXP;
         EXP2BLK : TEXPBLK;     { EXP2NEXT's wired entries }
         PEXP    : ^TWIZLONG;   { EXP2NEXT[]^ only via a pointer (mpbugs/bug10) }
         BIGLEV  : SmallInt;
         EXPNXTLV: TWIZLONG;
         CLSIDX  : SmallInt;
         TC      : ^TCHAR;
    begin
      WIREEXP( EXP2NEXT, EXP2BLK);
      LOADTEXP( EXP2NEXT);
      TC := CHARACTR[ _partyx];
      CLSIDX := Ord( TCLASS( TC^.XCLASS)) * 13;
      if TC.CHARLEV <= 12 then
        begin
          PEXP     := EXP2NEXT[ CLSIDX + TC.CHARLEV];
          EXPNXTLV := PEXP^
        end
      else
        begin
          PEXP     := EXP2NEXT[ CLSIDX + 12];
          EXPNXTLV := PEXP^;
          PEXP     := EXP2NEXT[ CLSIDX];
          for BIGLEV := 13 to TC^.CHARLEV do
            ADDLONGS( EXPNXTLV, PEXP^)
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
    var TC : ^TCHAR;
    begin
      _hpadd           := HPADD;
      _gold4nap.XHIGH  := 0;
      _gold4nap.XMID   := 0;
      _gold4nap.XLOW   := GOLDAMT;
      GotoXY( 0, 13);
      Write( Chr( 11));
      TC := CHARACTR[ _partyx];
      if GOLDAMT > 0 then
        while (TESTLONG( TC.GOLD, _gold4nap) >= 0) and
              (TC.HPLEFT < TC.HPMAX) and
              (Peek( $02FC) = $FF) do    { $FF = no key available }
          HEALHP
      else
        begin
          Write( TC.NAME);
          WriteLn( ' IS NAPPING')
        end;
      if Peek( $02FC) <> $FF then
        begin
          GotoXY( 41, 0);
          GETKEY
        end;
      GotoXY( 0, 13);
      Write( Chr( 11));
      CHNEWLEV;
      SETSPELS;
      GotoXY( 0, 23);
      Write( 'PRESS [RETURN] TO LEAVE');
      GotoXY( 41, 0);
      repeat GETKEY until INCHAR = Chr( CRETURN);
      INCHAR := Chr( 0)
    end;


  begin  { ADVNTINN }
    repeat
      if GETWHO = U_ADVNTINN then exit;
      if Byte( CHARACTR[ _partyx].STATUS) = 0 then   { OK = 0 }
        repeat
          UNITCLEAR( 1);
          INNMENU;
          GotoXY( 41, 0);
          GETKEY;
          case Byte( Ord( INCHAR)) of
            65: TAKENAP(  0,   0);   { 'A' STABLES  }
            66: TAKENAP(  1,  10);   { 'B' COTS     }
            67: TAKENAP(  3,  50);   { 'C' ECONOMY  }
            68: TAKENAP(  7, 200);   { 'D' MERCHANT }
            69: TAKENAP( 10, 500);   { 'E' ROYAL    }
            71: POOLALLG( _partyx);  { 'G' pool gold, v3.2 WC040 }
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
    if GILGAMSH = U_CASTLE then exit;
  repeat
    DSPTITLE( 'MARKET');
    P010A26;
    repeat
      repeat
        GotoXY( 41, 0);
        GETKEY
      until (INCHAR = 'A') or (INCHAR = 'G') or (INCHAR = 'B') or
            (INCHAR = 'C') or (INCHAR = 'E');
    until (PARTYCNT > 0) or (INCHAR = 'E') or (INCHAR = 'G');
    case INCHAR of                     { only U_CASTLE can reach here }
      'G': if GILGAMSH = U_CASTLE then exit;
      'A': ADVNTINN;
      'C': if GOTEMPLE = U_CASTLE then exit;
      'B': if GOBOLTAC = U_CASTLE then exit;
      'E': if EXTCASTL = U_CASTLE then exit
    end
  until false
end;  { CASTLE }

end.
