unit GLOBALS;

{ All game-state globals shared across segment units.
  Moved out of wiz.pas so every unit can access them via: uses GLOBALS; }

interface

uses TYPES, CONSTS;

var
  PARTYCNT : SmallInt;
  CACHEBL  : SmallInt;
  SCNTOCBL : SmallInt;
  LLBASE04 : SmallInt;
  TIMEDLAY : SmallInt;
  CACHEWRI : Boolean;
  INCHAR   : Char;
  XGOTO    : TXGOTO;
  XGOTO2   : TXGOTO;
  ATTK012  : SmallInt;
  FIZZLES  : SmallInt;
  CHSTALRM : SmallInt;
  LIGHT    : SmallInt;
  ACMOD2   : SmallInt;
  ENSTRENG : SmallInt;
  BASE12   : SmallInt;
  ENEMYINX : SmallInt;
  SAVELEV  : SmallInt;
  SAVEY    : SmallInt;
  SAVEX    : SmallInt;
  DIRECTIO : SmallInt;
  MAZELEV  : SmallInt;
  MAZEY    : SmallInt;
  MAZEX    : SmallInt;
  ENCB4RUN : Boolean;
  FIGHTMAP : array[ 0..19, 0..19] of Boolean;
  CHARDISK : array[ 0..5] of SmallInt;
  CHARACTR : array[ 0..5] of ^TCHAR;
  SCNTOC   : TSCNTOC;
  IOCACHE  : array[ 0..1023] of Char;
  CHARSET  : array[ 0..63] of TCHRIMAG;
  BASE06B6 : SmallInt;

  SCNTOC_RACE   : array[ 0..5] of string[ 9];   { indexed by Byte(TRACE)   NORACE..HOBBIT }
  SCNTOC_CLASS  : array[ 0..7] of string[ 9];   { indexed by Byte(TCLASS)  FIGHTER..NINJA }
  SCNTOC_STATUS : array[ 0..7] of string[ 8];   { indexed by Byte(TSTATUS) OK..LOST }
  SCNTOC_ALIGN  : array[ 0..3] of string[ 9];   { indexed by Byte(TALIGN)  UNALIGN..EVIL }

  GTSTRING  : string[ 40];           { output buffer for GETLINE }

  { Static backing stores for pointer arrays; wired up at program start in wiz.pas. }
  CHAR_SLOT0, CHAR_SLOT1, CHAR_SLOT2,
  CHAR_SLOT3, CHAR_SLOT4, CHAR_SLOT5 : TCHAR;
  CHAR_SKN0,  CHAR_SKN1,  CHAR_SKN2,
  CHAR_SKN3,  CHAR_SKN4,  CHAR_SKN5  : TSPELLSKN;   { slot spell lists }
  CHAR_POSS0, CHAR_POSS1, CHAR_POSS2,
  CHAR_POSS3, CHAR_POSS4, CHAR_POSS5 : TPOSSBLK;    { slot possessions }
  SPELBLK_DATA                        : TSPELBLK;

implementation

end.
