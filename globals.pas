unit GLOBALS;

{ All game-state globals shared by the resident and every overlay.

  Every variable has a fixed absolute address, so the separately compiled
  binaries (WIZRES, WIZHI, overlays) agree on where each one lives without
  any linking: each compiles this same unit.  Addresses are chained with
  SizeOf of the previous variable (TSCNTOC_SIZE where SizeOf is wrong,
  bug11; literal sizes for ordinal types, as MP parses SizeOf( Char) as a
  cast).

  Two blocks (the build checks both stay clear of their neighbours):
    GBASE  ($9000) .. G_END1 <= $A000   main RAM, above the overlay
                                        tail, below the screen
    GBASE2 ($C800) .. G_END2 <= $D000   RAM under the OS ROM, above
                                        WIZHI's data ($C000..)
  The second is only usable with the OS ROM switched out, which is how the
  game always runs: the ROM is switched in only inside LOUTIL.SIOSEC
  (transfers go through a main-RAM sector buffer) and around CIO overlay
  loads, and no game data is touched then.  ANTIC never reads either.

  The scenario name tables (race, class, status, alignment) are not
  string arrays: MP keeps an array of strings as an array of pointers to
  storage it places itself, and rejects absolute for it.  Their text lives
  in the SCNNAMES block (LOADSCNTOC fills it) and RACENAME etc. return one. }

interface

uses TYPES, CONSTS;

const
  GBASE     = $9000;
  GBASE2    = $C800;
  SCNNAMESZ = 6 * 10 + 8 * 10 + 8 * 9 + 4 * 10;   { string[9] x 6, [9] x 8, [8] x 8, [9] x 4 }
  NAME_RACE   = 0;                                { offsets in SCNNAMES }
  NAME_CLASS  = NAME_RACE + 6 * 10;
  NAME_STATUS = NAME_CLASS + 8 * 10;
  NAME_ALIGN  = NAME_STATUS + 8 * 9;

  A_PARTYCNT     = GBASE;
  A_CACHEBL      = A_PARTYCNT + 2;
  A_SCNTOCBL     = A_CACHEBL + 2;
  A_LLBASE04     = A_SCNTOCBL + 2;
  A_TIMEDLAY     = A_LLBASE04 + 2;
  A_CACHEWRI     = A_TIMEDLAY + 2;
  A_INCHAR       = A_CACHEWRI + 1;
  A_XGOTO        = A_INCHAR + 1;
  A_XGOTO2       = A_XGOTO + 1;
  A_ATTK012      = A_XGOTO2 + 1;                    { TXGOTO = Byte }
  A_FIZZLES      = A_ATTK012 + 2;
  A_CHSTALRM     = A_FIZZLES + 2;
  A_LIGHT        = A_CHSTALRM + 2;
  A_ACMOD2       = A_LIGHT + 2;
  A_ENSTRENG     = A_ACMOD2 + 2;
  A_BASE12       = A_ENSTRENG + 2;
  A_ENEMYINX     = A_BASE12 + 2;
  A_SAVELEV      = A_ENEMYINX + 2;
  A_SAVEY        = A_SAVELEV + 2;
  A_SAVEX        = A_SAVEY + 2;
  A_DIRECTIO     = A_SAVEX + 2;
  A_MAZELEV      = A_DIRECTIO + 2;
  A_MAZEY        = A_MAZELEV + 2;
  A_MAZEX        = A_MAZEY + 2;
  A_ENCB4RUN     = A_MAZEX + 2;
  A_FIGHTMAP     = A_ENCB4RUN + 1;
  A_CHARDISK     = A_FIGHTMAP + 20 * 20;
  A_CHARACTR     = A_CHARDISK + 6 * 2;
  A_SCNTOC       = A_CHARACTR + 6 * 2;
  A_IOCACHE      = A_SCNTOC + TSCNTOC_SIZE;
  A_CHARSET      = A_IOCACHE + 1024;
  A_BASE06B6     = A_CHARSET + 64 * SizeOf( TCHRIMAG);
  A_GTSTRING     = A_BASE06B6 + 2;
  A_SPELBLK_DATA = A_GTSTRING + 41;
  A_SCNNAMES     = A_SPELBLK_DATA + SizeOf( TSPELBLK);
  G_END1         = A_SCNNAMES + SCNNAMESZ;
  A_CHAR_SLOT0   = GBASE2;
  A_CHAR_SLOT1   = A_CHAR_SLOT0 + SizeOf( TCHAR);
  A_CHAR_SLOT2   = A_CHAR_SLOT1 + SizeOf( TCHAR);
  A_CHAR_SLOT3   = A_CHAR_SLOT2 + SizeOf( TCHAR);
  A_CHAR_SLOT4   = A_CHAR_SLOT3 + SizeOf( TCHAR);
  A_CHAR_SLOT5   = A_CHAR_SLOT4 + SizeOf( TCHAR);
  A_CHAR_SKN0    = A_CHAR_SLOT5 + SizeOf( TCHAR);
  A_CHAR_SKN1    = A_CHAR_SKN0 + SizeOf( TSPELLSKN);
  A_CHAR_SKN2    = A_CHAR_SKN1 + SizeOf( TSPELLSKN);
  A_CHAR_SKN3    = A_CHAR_SKN2 + SizeOf( TSPELLSKN);
  A_CHAR_SKN4    = A_CHAR_SKN3 + SizeOf( TSPELLSKN);
  A_CHAR_SKN5    = A_CHAR_SKN4 + SizeOf( TSPELLSKN);
  A_CHAR_POSS0   = A_CHAR_SKN5 + SizeOf( TSPELLSKN);
  A_CHAR_POSS1   = A_CHAR_POSS0 + SizeOf( TPOSSBLK);
  A_CHAR_POSS2   = A_CHAR_POSS1 + SizeOf( TPOSSBLK);
  A_CHAR_POSS3   = A_CHAR_POSS2 + SizeOf( TPOSSBLK);
  A_CHAR_POSS4   = A_CHAR_POSS3 + SizeOf( TPOSSBLK);
  A_CHAR_POSS5   = A_CHAR_POSS4 + SizeOf( TPOSSBLK);
  G_END2         = A_CHAR_POSS5 + SizeOf( TPOSSBLK);

var
  PARTYCNT     : SmallInt absolute A_PARTYCNT;
  CACHEBL      : SmallInt absolute A_CACHEBL;
  SCNTOCBL     : SmallInt absolute A_SCNTOCBL;
  LLBASE04     : SmallInt absolute A_LLBASE04;
  TIMEDLAY     : SmallInt absolute A_TIMEDLAY;
  CACHEWRI     : Boolean absolute A_CACHEWRI;
  INCHAR       : Char absolute A_INCHAR;
  XGOTO        : TXGOTO absolute A_XGOTO;
  XGOTO2       : TXGOTO absolute A_XGOTO2;
  ATTK012      : SmallInt absolute A_ATTK012;
  FIZZLES      : SmallInt absolute A_FIZZLES;
  CHSTALRM     : SmallInt absolute A_CHSTALRM;
  LIGHT        : SmallInt absolute A_LIGHT;
  ACMOD2       : SmallInt absolute A_ACMOD2;
  ENSTRENG     : SmallInt absolute A_ENSTRENG;
  BASE12       : SmallInt absolute A_BASE12;
  ENEMYINX     : SmallInt absolute A_ENEMYINX;
  SAVELEV      : SmallInt absolute A_SAVELEV;
  SAVEY        : SmallInt absolute A_SAVEY;
  SAVEX        : SmallInt absolute A_SAVEX;
  DIRECTIO     : SmallInt absolute A_DIRECTIO;
  MAZELEV      : SmallInt absolute A_MAZELEV;
  MAZEY        : SmallInt absolute A_MAZEY;
  MAZEX        : SmallInt absolute A_MAZEX;
  ENCB4RUN     : Boolean absolute A_ENCB4RUN;
  FIGHTMAP     : array[ 0..19, 0..19] of Boolean absolute A_FIGHTMAP;
  CHARDISK     : array[ 0..5] of SmallInt absolute A_CHARDISK;
  CHARACTR     : array[ 0..5] of ^TCHAR absolute A_CHARACTR;
  SCNTOC       : TSCNTOC absolute A_SCNTOC;
  IOCACHE      : array[ 0..1023] of Char absolute A_IOCACHE;
  CHARSET      : array[ 0..63] of TCHRIMAG absolute A_CHARSET;
  BASE06B6     : SmallInt absolute A_BASE06B6;
  GTSTRING     : string[ 40] absolute A_GTSTRING;
  CHAR_SLOT0   : TCHAR absolute A_CHAR_SLOT0;
  CHAR_SLOT1   : TCHAR absolute A_CHAR_SLOT1;
  CHAR_SLOT2   : TCHAR absolute A_CHAR_SLOT2;
  CHAR_SLOT3   : TCHAR absolute A_CHAR_SLOT3;
  CHAR_SLOT4   : TCHAR absolute A_CHAR_SLOT4;
  CHAR_SLOT5   : TCHAR absolute A_CHAR_SLOT5;
  CHAR_SKN0    : TSPELLSKN absolute A_CHAR_SKN0;
  CHAR_SKN1    : TSPELLSKN absolute A_CHAR_SKN1;
  CHAR_SKN2    : TSPELLSKN absolute A_CHAR_SKN2;
  CHAR_SKN3    : TSPELLSKN absolute A_CHAR_SKN3;
  CHAR_SKN4    : TSPELLSKN absolute A_CHAR_SKN4;
  CHAR_SKN5    : TSPELLSKN absolute A_CHAR_SKN5;
  CHAR_POSS0   : TPOSSBLK absolute A_CHAR_POSS0;
  CHAR_POSS1   : TPOSSBLK absolute A_CHAR_POSS1;
  CHAR_POSS2   : TPOSSBLK absolute A_CHAR_POSS2;
  CHAR_POSS3   : TPOSSBLK absolute A_CHAR_POSS3;
  CHAR_POSS4   : TPOSSBLK absolute A_CHAR_POSS4;
  CHAR_POSS5   : TPOSSBLK absolute A_CHAR_POSS5;
  SPELBLK_DATA : TSPELBLK absolute A_SPELBLK_DATA;

  SCNNAMES : array[ 0..SCNNAMESZ - 1] of Byte absolute A_SCNNAMES;

{ AP SCNTOC.RACE/CLASS/STATUS/ALIGN[ I] }
function RACENAME ( I: Byte): string;
function CLASSNAME( I: Byte): string;
function STATNAME ( I: Byte): string;
function ALIGNNAME( I: Byte): string;

{ Copy( S, 1, N) for a function result (MP's Copy needs a variable). }
function LEFTSTR( S: string; N: Byte): string;

implementation

function RACENAME( I: Byte): string;
begin
  Move( SCNNAMES[ NAME_RACE + I * 10], Result, 10)
end;

function CLASSNAME( I: Byte): string;
begin
  Move( SCNNAMES[ NAME_CLASS + I * 10], Result, 10)
end;

function STATNAME( I: Byte): string;
begin
  Move( SCNNAMES[ NAME_STATUS + I * 9], Result, 9)
end;

function ALIGNNAME( I: Byte): string;
begin
  Move( SCNNAMES[ NAME_ALIGN + I * 10], Result, 10)
end;

function LEFTSTR( S: string; N: Byte): string;
begin
  Result := Copy( S, 1, N)
end;

end.
