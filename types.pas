unit TYPES;

{ Wizardry I — Mad Pascal type definitions for Atari 8-bit port.
  Source authority: apple/wiz1a/WIZ.TEXT (Apple Pascal original).
  Sizes verified against disk layout (SCENARIO.DATA block structure).

  Key changes from Apple Pascal:
    - BOOLEAN/enumerations: 2 bytes AP -> 1 byte MP
    - PACKED ARRAY OF BOOLEAN -> ARRAY OF Boolean (1 byte/element)
    - PACKED ARRAY OF 0..n  -> ARRAY OF Byte (subrange preserved where useful)
    - Arrays with lower bound 1..n extended to 0..n so original 1-based
      indexing continues to work; element [0] is unused padding.
    - TSCNTOC: RACE/CLASS/STATUS/ALIGN moved to separate globals in wiz.pas;
               SPELLS moved to ^TSPELBLK — keeps TSCNTOC at ~108 bytes
    - TMAZE: W/S/E/N/FIGHTS/SQREXTRA -> pointers — keeps TMAZE at ~130 bytes
    - TENEMY2: A -> ^TENEMY2A, B -> ^TENEMY — 4 bytes in record
    - TCHAR: POSSESS[1..8] -> Array of ^TPOSSESS; LOSTXYL variant -> flat array
    - TENEMY: RECS[1..7] inline -> Array of ^THPREC (pointers)
    - INTEGER -> SmallInt throughout (same 16-bit signed)
    - CLASS field/type renamed XCLASS (CLASS is a reserved word in MP)
    - TEXP: array of pointers (624 byte AP array -> ~210 bytes)
}

interface

type

  { --- Enumerations --- }

  { TXGOTO is a Byte with named values, not an enum: MP 1.7.9 ignores
    "absolute" on enum-typed variables, and XGOTO / XGOTO2 must sit at
    fixed addresses shared by the residents and the overlays. }
  TXGOTO = Byte;

const
  XDONE    = 0;
  XTRAININ = 1;
  XCASTLE  = 2;
  XGILGAMS = 3;
  XINSPECT = 4;
  XBOLTAC  = 5;
  XCANT    = 6;
  XRUNNER  = 7;
  XCOMBAT  = 8;
  XNEWMAZE = 9;
  XCHK4WIN = 10;
  XREWARD  = 11;
  XINSPCT2 = 12;
  XEQUIP6  = 13;
  XEQPDSP  = 14;
  XREORDER = 15;
  XCEMETRY = 16;
  XINSPCT3 = 17;
  XBCK2CMP = 18;
  XBCK2ROL = 19;
  XCMP2EQ6 = 20;
  XUNUSED  = 21;
  XREWARD2 = 22;
  XSCNMSG  = 23;
  XCAMPSTF = 24;
  XEDGTOWN = 25;
  XINSAREA = 26;
  XBK2CMP2 = 27;

type
  TRACE    = (NORACE, HUMAN, ELF, DWARF, GNOME, HOBBIT);
  TCLASS   = (FIGHTER, MAGE, PRIEST, THIEF, BISHOP, SAMURAI, LORD, NINJA);
  TALIGN   = (UNALIGN, GOOD, NEUTRAL, EVIL);
  TSTATUS  = (OK, AFRAID, ASLEEP, PLYZE, STONED, DEAD, ASHES, LOST);
  TATTRIB  = (STRENGTH, IQ, PIETY, VITALITY, AGILITY, LUCK);
  TOBJTYPE = (WEAPON, ARMOR, SHIELD, HELMET, GAUNTLET, SPECIAL, MISC);
  TWALL    = (OPEN, WALL, DOOR, HIDEDOOR);
  TSQUARE  = (NORMAL, STAIRS, PIT, CHUTE, SPINNER, DARK, TRANSFER,
              OUCHY, BUTTONZ, ROCKWATE, FIZZLE, SCNMSG, ENCOUNTE);
  TZSCN    = (ZZERO, ZMAZE, ZENEMY, ZREWARD, ZOBJECT, ZCHAR, ZSPCCHRS, ZEXP);
  TSPEL012 = (GENERIC, PERSON, GROUP);

  { --- Simple records and array types --- }

  TWIZLONG = record
    XLOW  : SmallInt;
    XMID  : SmallInt;
    XHIGH : SmallInt;
  end;                              { 6 bytes }

  THPREC = record
    LEVEL   : SmallInt;
    HPFAC   : SmallInt;
    HPMINAD : SmallInt;
  end;                              { 6 bytes }

  { AP: ARRAY[1..7] OF INTEGER — extended to 0..7; element [0] is unused padding
    so all original 1-based index references remain valid without adjustment. }
  TSPELL7G = array[ 0..7] of SmallInt;   { 16 bytes (1 extra vs AP 14 bytes) }

  TCHRIMAG  = array[ 0..7] of Byte;       { 8 bytes;  AP: PACKED ARRAY[0..7] OF 0..255 }
  TBCD      = array[ 0..13] of SmallInt; { 28 bytes }
  TSPELLSKN = array[ 0..49] of Boolean;  { 50 bytes; split from TCHAR to keep it ≤255 }

  { --- Spell data block (split from TSCNTOC to keep it under 255 bytes) --- }

  TSPELBLK = record
    SPELLHSH : array[ 0..50] of SmallInt;  { 102 bytes; AP: PACKED ARRAY[0..50] OF INTEGER }
    SPELLGRP : array[ 0..50] of 0..7;      {  51 bytes; AP: PACKED ARRAY[0..50] OF 0..7 }
    SPELL012 : array[ 0..50] of Byte;      {  51 bytes; AP: PACKED ARRAY[0..50] OF TSPEL012 }
  end;                                     { 204 bytes total }

  { --- Table of contents (TSCNTOC) ---
    AP size: 501 bytes.  MP fix: SPELLS -> ^TSPELBLK (2 bytes);
    RACE/CLASS/STATUS/ALIGN lifted to global vars in wiz.pas (260 bytes gone).
    Remaining: ~108 bytes. }

  TSCNTOC = record
    GAMENAME  : string[ 40];                        { 42 bytes }
    RECPER2BL : array[ ZZERO..ZEXP] of SmallInt;   { 16 bytes }
    RECPERDK  : array[ ZZERO..ZEXP] of SmallInt;   { 16 bytes }
    UNUSEDXX  : array[ ZZERO..ZEXP] of SmallInt;   { 16 bytes }
    BLOFF     : array[ ZZERO..ZEXP] of SmallInt;   { 16 bytes }
    SPELLS    : ^TSPELBLK;                          {  2 bytes, unused: MP 1.7.9 reads
                                                       and writes SCNTOC.SPELLS as its .var
                                                       symbol, not the field (2026-10-25).
                                                       Use GLOBALS SPELBLK_DATA. }
  end;                                              { ~108 bytes total }

  { --- Object/item record --- }

  TOBJREC = record
    NAME     : string[ 15];
    NAMEUNK  : string[ 15];
    OBJTYPE  : TOBJTYPE;
    ALIGN    : TALIGN;
    CURSED   : Boolean;
    SPECIAL  : SmallInt;
    CHANGETO : SmallInt;
    CHGCHANC : SmallInt;
    PRICE    : TWIZLONG;
    BOLTACXX : SmallInt;
    SPELLPWR : SmallInt;
    CLASSUSE : array[ FIGHTER..NINJA] of Boolean;  { AP: PACKED ARRAY[TCLASS] OF BOOLEAN }
    HEALPTS  : SmallInt;
    WEPVSTY2 : array[ 0..15] of Boolean;           { AP: PACKED ARRAY[0..15] OF BOOLEAN }
    WEPVSTY3 : array[ 0..15] of Boolean;           { AP: PACKED ARRAY[0..15] OF BOOLEAN }
    ARMORMOD : SmallInt;
    WEPHITMD : SmallInt;
    WEPHPDAM : THPREC;
    XTRASWNG : SmallInt;
    CRITHITM : Boolean;
    WEPVSTYP : array[ 0..13] of Boolean;           { AP: PACKED ARRAY[0..13] OF BOOLEAN }
  end;                                             { ~120 bytes }

  { --- Character possession item --- }

  TPOSSESS = record
    EQUIPED : Boolean;
    CURSED  : Boolean;
    IDENTIF : Boolean;
    EQINDEX : SmallInt;
  end;                   { 5 bytes }

  { AP: POSSESS ARRAY[1..8] — extended to 0..8; element [0] is unused padding. }
  TPOSS = record
    POSSCNT : SmallInt;
    POSSESS : array[ 0..8] of ^TPOSSESS;
  end;                                    { 2 + 18 = 20 bytes }

  { --- Character record ---
    AP size: ~205 bytes.  MP size: ~247 bytes (packed fields expand; POSSESS -> ptrs).
    Still under 255. }

  TCHAR = record
    NAME     : string[ 15];
    PASSWORD : string[ 15];
    INMAZE   : Boolean;
    RACE     : TRACE;
    XCLASS   : TCLASS;              { renamed: CLASS is reserved in MP }
    AGE      : SmallInt;
    STATUS   : TSTATUS;
    ALIGN    : TALIGN;
    ATTRIB   : array[ STRENGTH..LUCK] of 0..18;  { AP: PACKED ARRAY[STRENGTH..LUCK] OF 0..18 }
    LUCKSKIL : array[ 0..4] of 0..31;            { AP: PACKED ARRAY[0..4] OF 0..31 }
    GOLD     : TWIZLONG;
    POSS     : TPOSS;
    EXP      : TWIZLONG;
    MAXLEVAC : SmallInt;
    CHARLEV  : SmallInt;
    HPLEFT   : SmallInt;
    HPMAX    : SmallInt;
    SPELLSKN : ^TSPELLSKN;                        { AP: PACKED ARRAY[0..49] OF BOOLEAN; ptr saves 48 bytes }
    MAGESP   : TSPELL7G;
    PRIESTSP : TSPELL7G;
    HPCALCMD : SmallInt;
    ARMORCL  : SmallInt;
    HEALPTS  : SmallInt;
    CRITHITM : Boolean;
    SWINGCNT : SmallInt;
    HPDAMRC  : THPREC;
    WEPVSTY2 : array[ 0..1, 0..13] of Boolean;  { AP: PACKED ARRAY[0..1,0..13] OF BOOLEAN }
    WEPVSTY3 : array[ 0..1, 0..6] of Boolean;   { AP: PACKED ARRAY[0..1,0..6] OF BOOLEAN  }
    WEPVSTYP : array[ 0..13] of Boolean;         { AP: PACKED ARRAY[0..13] OF BOOLEAN      }
    { AP variant record (LOCATION/POISNAMT/AWARDS — all 3 cases = 4 integers):
      extended to 0..4; element [0] unused so original [1]..[4] indexing holds. }
    LOSTXYL  : array[ 0..4] of SmallInt;
  end;                                           { ~247 bytes }

  PTCHAR     = ^TCHAR;     { MP disallows ^TYPE inline in parameter lists }
  PTSPELLSKN = ^TSPELLSKN;
  PTTEMP04   = ^TTEMP04;

  { --- Enemy definition ---
    AP size: ~156 bytes.  RECS extended to 0..7 (element [0] unused). }

  TENEMY = record
    NAMEUNK  : string[ 15];
    NAMEUNKS : string[ 15];
    NAME     : string[ 15];
    NAMES    : string[ 15];
    PIC      : SmallInt;
    CALC1    : TWIZLONG;
    HPREC    : THPREC;
    XCLASS   : SmallInt;            { renamed: CLASS reserved in MP }
    AC       : SmallInt;
    RECSN    : SmallInt;
    { AP: ARRAY[1..7] OF THPREC inline (42 bytes) -> 0..7 of ^THPREC; [0] unused. }
    RECS     : array[ 0..7] of ^THPREC;
    EXPAMT   : TWIZLONG;
    DRAINAMT : SmallInt;
    HEALPTS  : SmallInt;
    REWARD1  : SmallInt;
    REWARD2  : SmallInt;
    ENMYTEAM : SmallInt;
    TEAMPERC : SmallInt;
    MAGSPELS : SmallInt;
    PRISPELS : SmallInt;
    UNIQUE   : SmallInt;
    BREATHE  : SmallInt;
    UNAFFCT  : SmallInt;
    WEPVSTY3 : array[ 0..15] of Boolean;  { AP: PACKED ARRAY[0..15] OF BOOLEAN }
    SPPC     : array[ 0..15] of Boolean;  { AP: PACKED ARRAY[0..15] OF BOOLEAN }
  end;                                    { ~156 bytes }

  { --- In-combat enemy state ---
    AP TENEMY2 size: ~290 bytes (A:134 + B:156).  Split into two heap records. }

  TTEMP04 = record
    VICTIM   : SmallInt;
    SPELLHSH : SmallInt;
    AGILITY  : SmallInt;
    HPLEFT   : SmallInt;
    ARMORCL  : SmallInt;
    INAUDCNT : SmallInt;
    XSTATUS  : TSTATUS;             { renamed: STATUS conflicts with TCHAR.STATUS }
  end;                              { 13 bytes }

  TENEMY2A = record
    IDENTIFI : Boolean;
    ALIVECNT : SmallInt;
    ENMYCNT  : SmallInt;
    ENEMYID  : SmallInt;
    TEMP04   : array[ 0..8] of ^TTEMP04;
  end;                              { 1+2+2+2+18 = 25 bytes }

  TENEMY2 = record
    A : Pointer;                    { ^TENEMY2A; AP: inline sub-record (134 bytes) }
    B : Pointer;                    { ^TENEMY; AP: inline TENEMY (156 bytes).  Untyped:
                                      MP counts a ^record field as 0 bytes, so
                                      P^.B used offset 0 (mpbugs/bug16) }
  end;                              { 4 bytes }

const
  TENEMY2_SIZE = 4;                 { SizeOf( TENEMY2) wrongly gives 0 (mpbugs/bug11) }
  TSCNTOC_SIZE = 107;               { SizeOf( TSCNTOC) gives 105, same bug }

  { Converted scenario file header (block 0, tools/mkscen.py). }
  SCNHDROFS    = 448;
  SCNVERSION   = 1;

type

  { --- Maze level ---
    AP TMAZE size: ~784 bytes.  Large fields moved to heap via pointers.
    Values stored as Byte per cell (AP used 2-bit packed for walls, etc.) }

  { Flat 1-D: MP cannot subscript pointer-to-2D-array; access via [H*20+V]. }
  TMAZEMAP  = array[ 0..399] of Byte;         { 400 bytes; AP: PACKED 2-bit TWALL }
  TFIGHTMAP = array[ 0..399] of Byte;         { 400 bytes; AP: PACKED 1-bit 0..1  }
  TSQRMAP   = array[ 0..399] of Byte;         { 400 bytes; AP: PACKED 4-bit 0..15 }

  TENMYCALC = record
    MINENEMY : SmallInt;
    MULTWORS : SmallInt;
    WORSE01  : SmallInt;
    RANGE0N  : SmallInt;
    PERCWORS : SmallInt;
  end;                              { 10 bytes }

  { AP: ENMYCALC PACKED ARRAY[1..3] — extended to 0..3; element [0] unused. }
  TMAZE = record
    W        : ^TMAZEMAP;           { AP: inline 100-byte packed array }
    S        : ^TMAZEMAP;
    E        : ^TMAZEMAP;
    N        : ^TMAZEMAP;
    FIGHTS   : ^TFIGHTMAP;          { AP: inline 50-byte packed array  }
    SQREXTRA : ^TSQRMAP;            { AP: inline 200-byte packed array }
    SQRETYPE : array[ 0..15] of Byte;      { AP: PACKED ARRAY[0..15] OF TSQUARE }
    AUX0     : array[ 0..15] of SmallInt;  { AP: PACKED ARRAY[0..15] OF INTEGER }
    AUX1     : array[ 0..15] of SmallInt;
    AUX2     : array[ 0..15] of SmallInt;
    ENMYCALC : array[ 0..3] of ^TENMYCALC; { AP: PACKED ARRAY[1..3]; [0] unused }
  end;                              { 12 + 16 + 96 + 8 = ~132 bytes }

  { --- Experience table ---
    AP: ARRAY[FIGHTER..NINJA] OF ARRAY[0..12] OF TWIZLONG = 624 bytes.
    MP: 1D array of pointers (MP requires ^RECORD elements; no inline records in arrays).
    Access: EXP[Ord(CLASS)*13 + LEVEL]^  (replaces EXP[CLASS, LEVEL]).
    104 elements x 2 bytes = 208 bytes. }

  TEXP = array[ 0..103] of ^TWIZLONG;

  { --- Static backing stores for the pointer fields above ---
    Nothing is heap-allocated: each pointer field is wired (util.pas
    WIRECHAR/WIREMAZE/WIREENEMY/WIREEXP) to a fixed block owned by whoever
    owns the record.  The blocks are byte arrays because MP 1.7.9
    miscompiles arrays of records; elements are contiguous, [0] first. }

  TPOSSBLK = array[ 0..9 * SizeOf( TPOSSESS) - 1]   of Byte;  { TCHAR.POSS.POSSESS[0..8] }
  TECBLK   = array[ 0..4 * SizeOf( TENMYCALC) - 1]  of Byte;  { TMAZE.ENMYCALC[0..3]    }
  TRECSBLK = array[ 0..8 * SizeOf( THPREC) - 1]     of Byte;  { TENEMY.RECS[0..7]        }
  TEXPBLK  = array[ 0..104 * SizeOf( TWIZLONG) - 1] of Byte;  { TEXP[0..103]             }

  { --- Scenario message buffer (used by SPCMISC/DECRYPTM) --- }
  TSTRBUFF = record
    BUFF   : string[ 38];
    ENDMSG : Boolean;
  end;                              { 40 bytes }

  { --- Battle result ---
    ENMYCNT/ENMYID extended to 0..4; elements [0] unused (AP was 1..4). }

  TBATRSLT = record
    ENMYCNT : array[ 0..4] of SmallInt;
    ENMYID  : array[ 0..4] of SmallInt;
    DRAINED : array[ 0..5] of Boolean;
  end;                              { 10+10+6 = 26 bytes }

implementation

end.
