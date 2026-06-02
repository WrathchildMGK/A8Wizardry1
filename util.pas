unit UTIL;

{ Wizardry I — shared utility procedures.
  Source: apple/wiz1a/WIZ2.TEXT + wiz1d/ machine-code routines.
  Disk I/O: reads/writes D1:SCENARIO.DATA and D1:SCENARIO.MESGS via Mad Pascal
  file operations (Assign/Reset/Seek/BlockRead/BlockWrite). }

interface

uses TYPES, CONSTS, GLOBALS, crt;

{ Disk cache }
function  GETREC ( DATATYPE: TZSCN; DATAINDX, DATASIZE: SmallInt): SmallInt;
function  GETRECW( DATATYPE: TZSCN; DATAINDX, DATASIZE: SmallInt): SmallInt;

{ Scenario file location — returns block offset within the named file.
  Both files start at their own byte 0 on the Atari (separate D1: files). }
function  FINDFILE( DRIVE: SmallInt; FILENM: string): SmallInt;

{ Disk I/O — Mad Pascal file operations on D1:SCENARIO.DATA / D1:SCENARIO.MESGS.
  UNITREAD/UNITWRITE load/save IOCACHE and keep the file handle open.
  UNITREAD_MSG reads one block (BLOCKSZ bytes) from SCENARIO.MESGS into BUF. }
procedure UNITREAD    ( BLOCK: SmallInt);
procedure UNITWRITE   ( BLOCK: SmallInt);
procedure UNITREAD_BUF( BLOCK: SmallInt; var BUF);
procedure UNITREAD_MSG( BLOCK: SmallInt; var BUF);

{ Deserialize IOCACHE → SCNTOC + SCNTOC_* globals + SPELBLK_DATA.
  Call immediately after UNITREAD(SCNTOCBL) to populate game data from disk. }
procedure LOADSCNTOC;

{ TWIZLONG arithmetic (P010005-P01000B, WIZ2.TEXT) }
procedure ADDLONGS ( var FIRST: TWIZLONG; SECOND: TWIZLONG);
procedure SUBLONGS ( var FIRST: TWIZLONG; SECOND: TWIZLONG);
function  TESTLONG( FIRST, SECOND: TWIZLONG): SmallInt;
procedure MULTLONG( var LONGNUM: TWIZLONG; INTNUM: SmallInt);
procedure DIVLONG ( var LONGNUM: TWIZLONG; INTNUM: SmallInt);
procedure LONG2BCD( LONGNUM: TWIZLONG; var BCDNUM: TBCD);
procedure BCD2LONG( var LONGNUM: TWIZLONG; BCDNUM: TBCD);
procedure PRNTLONG( LONGNUM: TWIZLONG);

{ Input (P01000D-P01000F) }
procedure GETKEY;
procedure GETLINE;
procedure GETSTR  ( var ASTRING: string; WINXPOS, WINYPOS: SmallInt);
function  GETCHARX( DSPNAMES: Boolean; SOLICIT: string): SmallInt;

{ Display stubs (P010016-P010018, wiz1d/MVCURSOR etc.)
  Full implementation requires Atari GTIA/ANTIC programming. }
procedure MVCURSOR( X, Y: SmallInt);
procedure CLRRECT ( X, Y, W, H: SmallInt);
procedure PRINTCHR( ACHAR: Char);
procedure PRINTSTR( ASTRING: string);
procedure PRINTNUM( ANUM, FIELDSZ: SmallInt);
procedure CENTSTR ( ASTRING: string);
procedure TEXTMODE;
procedure GRAPHICS;
procedure CLEARPIC;
procedure CLRPICT  ( X1, Y1, X2, Y2: SmallInt);
procedure DRAWLINE ( X, Y, DX, DY, LEN: SmallInt);
procedure PRINTBEL;

{ Timing }
procedure PAUSE1;
procedure PAUSE2;

{ Record loaders — allocate MP pointer fields; deserialize AP disk format.
  TODO: wire up actual AP-format unpack once Atari disk I/O is stable. }
procedure LOADTMAZE ( LEVEL: SmallInt; var MAZE: TMAZE);
procedure LOADTCHAR ( INDEX: SmallInt; var CH:   TCHAR);
procedure SAVETCHAR ( INDEX: SmallInt; var CH:   TCHAR);
procedure LOADOBJREC( INDEX: SmallInt; var OBJ:  TOBJREC);
procedure SAVEOBJREC( INDEX: SmallInt; var OBJ:  TOBJREC);
procedure LOADENEMY ( INDEX: SmallInt; var ENM:  TENEMY);

implementation

{ ── Mode E display layer ─────────────────────────────────────────────────── }

const
  SCRWIDTH = 40;   { Mode E bytes per scanline (160px / 4px per byte) }
  CHARH    = 8;    { scanlines per character row }
  CHARCOLS = 40;   { character columns (160px / 4px) }
  CHARROWS = 24;   { character rows (192px / 8px) }

var
  CURX    : SmallInt;
  CURY    : SmallInt;
  SCRNBUF : array[ 0..7679] of Byte;   { ANTIC Mode E screen bitmap }
  DLIST   : array[ 0..215]  of Byte;   { ANTIC display list }
  CHRTAB  : array[ 0..255]  of Byte;   { blit LUT: TCHRIMAG byte → Mode E byte }

{ ── Disk I/O — Mad Pascal file operations ────────────────────────────────── }

var
  SCENFILE : File;
  MESGFILE : File;
  SCENOPEN : Boolean;
  MESGOPEN : Boolean;

procedure OPENSCEN;
{ Open D1:SCENARIO.DATA for random-access byte I/O if not already open. }
begin
  if SCENOPEN then exit;
  Assign( SCENFILE, 'D1:SCENARIO.DATA');
  {$I-} Reset( SCENFILE, 1); {$I+}
  SCENOPEN := IOResult = 0
end;

procedure UNITREAD( BLOCK: SmallInt);
{ Load 1024 bytes (2x512-byte blocks) from SCENARIO.DATA at block BLOCK
  into IOCACHE.  CACHEBL is managed by GETREC; direct callers must set it. }
var N : SmallInt;
begin
  OPENSCEN;
  if not SCENOPEN then exit;
  Seek( SCENFILE, Word( BLOCK) * BLOCKSZ);
  BlockRead( SCENFILE, IOCACHE[0], SizeOf( IOCACHE), N)
end;

procedure UNITWRITE( BLOCK: SmallInt);
{ Write IOCACHE back to SCENARIO.DATA at block BLOCK. }
var N : SmallInt;
begin
  OPENSCEN;
  if not SCENOPEN then exit;
  Seek( SCENFILE, Word( BLOCK) * BLOCKSZ);
  BlockWrite( SCENFILE, IOCACHE[0], SizeOf( IOCACHE), N)
end;

procedure UNITREAD_BUF( BLOCK: SmallInt; var BUF);
{ Read one block (BLOCKSZ bytes) from SCENARIO.DATA at block BLOCK into BUF.
  Bypasses IOCACHE — use for CHARSET swaps and other single-block direct reads.
  Does NOT update CACHEBL. }
var N : SmallInt;
begin
  OPENSCEN;
  if not SCENOPEN then exit;
  Seek( SCENFILE, Word( BLOCK) * BLOCKSZ);
  BlockRead( SCENFILE, BUF, BLOCKSZ, N)
end;

procedure UNITREAD_MSG( BLOCK: SmallInt; var BUF);
{ Read one block (BLOCKSZ bytes) from SCENARIO.MESGS at block BLOCK into BUF. }
var N : SmallInt;
begin
  if not MESGOPEN then
    begin
      Assign( MESGFILE, 'D1:SCENARIO.MESGS');
      {$I-} Reset( MESGFILE, 1); {$I+}
      MESGOPEN := IOResult = 0
    end;
  if not MESGOPEN then exit;
  Seek( MESGFILE, Word( BLOCK) * BLOCKSZ);
  BlockRead( MESGFILE, BUF, BLOCKSZ, N)
end;

{ ── GETREC / GETRECW ─────────────────────────────────────────────────────── }

function GETREC( DATATYPE: TZSCN; DATAINDX, DATASIZE: SmallInt): SmallInt;
var
  BUFFADDR : SmallInt;
  DSKBLOCK : SmallInt;
begin
  DSKBLOCK := SCNTOC.BLOFF[ DATATYPE] +
              2 * (DATAINDX div SCNTOC.RECPER2BL[ DATATYPE]);
  BUFFADDR := DATASIZE * (DATAINDX mod SCNTOC.RECPER2BL[ DATATYPE]);
  if CACHEBL <> DSKBLOCK then
    begin
      if CACHEWRI then
        UNITWRITE( CACHEBL + SCNTOCBL);
      CACHEWRI := false;
      CACHEBL  := DSKBLOCK;
      UNITREAD( CACHEBL + SCNTOCBL);
    end;
  GETREC := BUFFADDR
end;

function GETRECW( DATATYPE: TZSCN; DATAINDX, DATASIZE: SmallInt): SmallInt;
var
  BUFFADDR : SmallInt;
  DSKBLOCK : SmallInt;
begin
  DSKBLOCK := SCNTOC.BLOFF[ DATATYPE] +
              2 * (DATAINDX div SCNTOC.RECPER2BL[ DATATYPE]);
  BUFFADDR := DATASIZE * (DATAINDX mod SCNTOC.RECPER2BL[ DATATYPE]);
  if CACHEBL <> DSKBLOCK then
    begin
      if CACHEWRI then
        UNITWRITE( CACHEBL + SCNTOCBL);
      CACHEBL := DSKBLOCK;
      UNITREAD( CACHEBL + SCNTOCBL);
    end;
  CACHEWRI := true;
  GETRECW  := BUFFADDR
end;

{ ── FINDFILE ─────────────────────────────────────────────────────────────── }

function FINDFILE( DRIVE: SmallInt; FILENM: string): SmallInt;
begin
  if FILENM = 'SCENARIO.DATA' then
    FINDFILE := 0
  else if FILENM = 'SCENARIO.MESGS' then
    FINDFILE := 0          { Atari: separate D1:SCENARIO.MESGS file — offset 0 }
  else
    FINDFILE := -9
end;


procedure LOADSCNTOC;
{ Deserialize IOCACHE → SCNTOC + SCNTOC_* string globals + SPELBLK_DATA.
  Byte map of AP TSCNTOC in SCENARIO.DATA block 0:
    0..41   GAMENAME  STRING[40]  42 bytes (41 data + 1 word-align pad; Move 41, skip 1)
    42..57  RECPER2BL 8 x INTEGER 16 bytes
    58..73  RECPERDK  8 x INTEGER 16 bytes
    74..89  UNUSEDXX  8 x INTEGER 16 bytes
    90..105 BLOFF     8 x INTEGER 16 bytes
    106..165  RACE    6 x STRING[9]   60 bytes (10 each)
    166..245  CLASS   8 x STRING[9]   80 bytes (10 each)
    246..325  STATUS  8 x STRING[8]   80 bytes (10 each: 9 data + 1 word-align pad)
    326..365  ALIGN   4 x STRING[9]   40 bytes (10 each)
    366..467  SPELLHSH 51 x INTEGER  102 bytes (plain LE words)
    468..489  SPELLGRP 51 x 0..7      22 bytes (3-bit packed, 5 per 16-bit LE word)
    490..503  SPELL012 51 x 0..2      14 bytes (2-bit packed, 8 per 16-bit LE word) }
var
  P, I, J, IDX : SmallInt;
  W            : Word;
begin
  Move( IOCACHE[  0], SCNTOC.GAMENAME[0],      41);  { skip 1 word-align pad at disk[41] }
  Move( IOCACHE[ 42], SCNTOC.RECPER2BL[ZZERO], 16);
  Move( IOCACHE[ 58], SCNTOC.RECPERDK[ZZERO],  16);
  Move( IOCACHE[ 74], SCNTOC.UNUSEDXX[ZZERO],  16);
  Move( IOCACHE[ 90], SCNTOC.BLOFF[ZZERO],     16);
  P := 106;
  for I := 0 to 5 do
    begin Move( IOCACHE[P], SCNTOC_RACE[I],   10); P := P + 10 end;
  for I := 0 to 7 do
    begin Move( IOCACHE[P], SCNTOC_CLASS[I],  10); P := P + 10 end;
  for I := 0 to 7 do
    begin Move( IOCACHE[P], SCNTOC_STATUS[I],  9); P := P + 10 end;  { skip 1 pad }
  for I := 0 to 3 do
    begin Move( IOCACHE[P], SCNTOC_ALIGN[I],  10); P := P + 10 end;
  { P = 366 }
  Move( IOCACHE[366], SPELBLK_DATA.SPELLHSH[0], 102);
  { SPELLGRP: 3-bit packed, 5 elements per 16-bit LE word, 11 words at offset 468 }
  for I := 0 to 10 do
    begin
      W := Byte( IOCACHE[468 + I*2]) or (Word( Byte( IOCACHE[469 + I*2])) shl 8);
      for J := 0 to 4 do
        begin
          IDX := I*5 + J;
          if IDX <= 50 then
            SPELBLK_DATA.SPELLGRP[ IDX] := (W shr (J*3)) and 7
        end
    end;
  { SPELL012: 2-bit packed, 8 elements per 16-bit LE word, 7 words at offset 490 }
  for I := 0 to 6 do
    begin
      W := Byte( IOCACHE[490 + I*2]) or (Word( Byte( IOCACHE[491 + I*2])) shl 8);
      for J := 0 to 7 do
        begin
          IDX := I*8 + J;
          if IDX <= 50 then
            SPELBLK_DATA.SPELL012[ IDX] := (W shr (J*2)) and 3
        end
    end;
  SCNTOC.SPELLS := @SPELBLK_DATA
end;

{ ── TWIZLONG arithmetic ──────────────────────────────────────────────────── }

procedure ADDLONGS( var FIRST: TWIZLONG; SECOND: TWIZLONG);
begin
  FIRST.XLOW := FIRST.XLOW + SECOND.XLOW;
  if FIRST.XLOW >= 10000 then
    begin
      FIRST.XMID := FIRST.XMID + 1;
      FIRST.XLOW := FIRST.XLOW - 10000
    end;
  FIRST.XMID := FIRST.XMID + SECOND.XMID;
  if FIRST.XMID >= 10000 then
    begin
      FIRST.XHIGH := FIRST.XHIGH + 1;
      FIRST.XMID  := FIRST.XMID - 10000
    end;
  FIRST.XHIGH := FIRST.XHIGH + SECOND.XHIGH;
  if FIRST.XHIGH >= 10000 then
    begin
      FIRST.XHIGH := 9999;
      FIRST.XMID  := 9999;
      FIRST.XLOW  := 9999
    end
end;

procedure SUBLONGS( var FIRST: TWIZLONG; SECOND: TWIZLONG);
begin
  FIRST.XLOW := FIRST.XLOW - SECOND.XLOW;
  if FIRST.XLOW < 0 then
    begin
      FIRST.XMID := FIRST.XMID - 1;
      FIRST.XLOW := FIRST.XLOW + 10000
    end;
  FIRST.XMID := FIRST.XMID - SECOND.XMID;
  if FIRST.XMID < 0 then
    begin
      FIRST.XHIGH := FIRST.XHIGH - 1;
      FIRST.XMID  := FIRST.XMID + 10000
    end;
  FIRST.XHIGH := FIRST.XHIGH - SECOND.XHIGH;
  if FIRST.XHIGH < 0 then
    begin
      FIRST.XHIGH := 0;
      FIRST.XMID  := 0;
      FIRST.XLOW  := 0
    end
end;

function TESTLONG( FIRST, SECOND: TWIZLONG): SmallInt;
begin
  TESTLONG := 0;
  if FIRST.XHIGH <> SECOND.XHIGH then
    begin
      if FIRST.XHIGH > SECOND.XHIGH then TESTLONG := 1 else TESTLONG := -1;
      exit
    end;
  if FIRST.XMID <> SECOND.XMID then
    begin
      if FIRST.XMID > SECOND.XMID then TESTLONG := 1 else TESTLONG := -1;
      exit
    end;
  if FIRST.XLOW <> SECOND.XLOW then
    begin
      if FIRST.XLOW > SECOND.XLOW then TESTLONG := 1 else TESTLONG := -1;
      exit
    end
end;

procedure LONG2BCD( LONGNUM: TWIZLONG; var BCDNUM: TBCD);
var
  DIGITX : SmallInt;

  procedure INT2BCD( PARTLONG: SmallInt);
  begin
    BCDNUM[ DIGITX] := PARTLONG div 1000; DIGITX := DIGITX + 1; PARTLONG := PARTLONG mod 1000;
    BCDNUM[ DIGITX] := PARTLONG div 100;  DIGITX := DIGITX + 1; PARTLONG := PARTLONG mod 100;
    BCDNUM[ DIGITX] := PARTLONG div 10;   DIGITX := DIGITX + 1; PARTLONG := PARTLONG mod 10;
    BCDNUM[ DIGITX] := PARTLONG;          DIGITX := DIGITX + 1
  end;

begin
  BCDNUM[ 0] := 0;
  DIGITX := 1;
  INT2BCD( LONGNUM.XHIGH);
  INT2BCD( LONGNUM.XMID);
  INT2BCD( LONGNUM.XLOW)
end;

procedure BCD2LONG( var LONGNUM: TWIZLONG; BCDNUM: TBCD);
var
  DIGITX : SmallInt;

  procedure BCD2INT( var LONGPART: SmallInt);
  begin
    LONGPART := (10 * LONGPART) + BCDNUM[ DIGITX]; DIGITX := DIGITX + 1;
    LONGPART := (10 * LONGPART) + BCDNUM[ DIGITX]; DIGITX := DIGITX + 1;
    LONGPART := (10 * LONGPART) + BCDNUM[ DIGITX]; DIGITX := DIGITX + 1;
    LONGPART := (10 * LONGPART) + BCDNUM[ DIGITX]; DIGITX := DIGITX + 1
  end;

begin
  FillChar( LONGNUM, 6, 0);
  DIGITX := 1;
  BCD2INT( LONGNUM.XHIGH);
  BCD2INT( LONGNUM.XMID);
  BCD2INT( LONGNUM.XLOW)
end;

procedure MULTLONG( var LONGNUM: TWIZLONG; INTNUM: SmallInt);
var
  DIGITX : SmallInt;
  BCDNUM : TBCD;
begin
  LONG2BCD( LONGNUM, BCDNUM);
  for DIGITX := 12 downto 1 do
    BCDNUM[ DIGITX] := BCDNUM[ DIGITX] * INTNUM;
  for DIGITX := 12 downto 1 do
    if BCDNUM[ DIGITX] > 9 then
      begin
        BCDNUM[ DIGITX - 1] := BCDNUM[ DIGITX - 1] + BCDNUM[ DIGITX] div 10;
        BCDNUM[ DIGITX]     := BCDNUM[ DIGITX] mod 10
      end;
  BCD2LONG( LONGNUM, BCDNUM)
end;

procedure DIVLONG( var LONGNUM: TWIZLONG; INTNUM: SmallInt);
var
  NXTDIGIT : SmallInt;
  DIGITX   : SmallInt;
  BCDNUM   : TBCD;
begin
  LONG2BCD( LONGNUM, BCDNUM);
  for DIGITX := 1 to 12 do
    begin
      NXTDIGIT := BCDNUM[ DIGITX] div INTNUM;
      BCDNUM[ DIGITX + 1] := BCDNUM[ DIGITX + 1] +
                              10 * (BCDNUM[ DIGITX] - NXTDIGIT * INTNUM);
      BCDNUM[ DIGITX] := NXTDIGIT
    end;
  BCD2LONG( LONGNUM, BCDNUM)
end;

procedure PRNTLONG( LONGNUM: TWIZLONG);
var
  BCDNUM  : TBCD;
  NONSPCX : SmallInt;
  LEADSPC : SmallInt;
begin
  LONG2BCD( LONGNUM, BCDNUM);
  LEADSPC := 1;
  while (LEADSPC < 12) and (BCDNUM[ LEADSPC] = 0) do
    begin
      LEADSPC := LEADSPC + 1;
      Write( ' ')
    end;
  for NONSPCX := LEADSPC to 12 do
    Write( BCDNUM[ NONSPCX]: 1)
end;

{ ── Input stubs ──────────────────────────────────────────────────────────── }

procedure GETKEY;
var K : Byte;
begin
  { AP: MVCURSOR(80,0) = spin-wait, ticking hardware RNG, until key available.
    Atari: $02FC (CH) holds last ATASCII key pressed; $FF means no key.
    TODO: also tick a software RNG while waiting. }
  repeat K := Peek( $02FC) until K <> $FF;
  INCHAR := Chr( K);
  Poke( $02FC, $FF)   { clear key register }
end;

procedure GETLINE;
var IPOS : SmallInt;
begin
  IPOS := 0;
  repeat
    GETKEY;
    if (INCHAR >= Chr( 32)) and (INCHAR <= Chr( 90)) and (IPOS < 40) then
      begin
        IPOS := IPOS + 1;
        GTSTRING[ IPOS] := INCHAR;
        Write( INCHAR)
      end
    else if INCHAR = Chr( 8) then
      begin
        if IPOS > 0 then
          begin
            Write( INCHAR); Write( ' '); Write( INCHAR);
            IPOS := IPOS - 1
          end
      end
  until INCHAR = Chr( CRETURN);
  GTSTRING[ 0] := Chr( IPOS)
end;

procedure GETSTR( var ASTRING: string; WINXPOS, WINYPOS: SmallInt);
var IPOS : SmallInt;
begin
  IPOS := 0;
  repeat
    MVCURSOR( WINXPOS + IPOS, WINYPOS);
    PRINTCHR( Chr( 64));     { cursor character }
    GETKEY;
    if INCHAR = Chr( 27) then
      begin
        CLRRECT( WINXPOS, WINYPOS, IPOS + 1, 1);
        IPOS := 0
      end
    else if (INCHAR = Chr( 8)) and (IPOS > 0) then
      begin
        CLRRECT( WINXPOS + IPOS, WINYPOS, 1, 1);
        IPOS := IPOS - 1
      end
    else if (INCHAR <> Chr( CRETURN)) and (Ord( INCHAR) >= 32) then
      begin
        MVCURSOR( WINXPOS + IPOS, WINYPOS);
        PRINTCHR( INCHAR);
        IPOS := IPOS + 1;
        ASTRING[ IPOS] := INCHAR
      end
  until INCHAR = Chr( CRETURN);
  ASTRING[ 0] := Chr( IPOS)
end;

function GETCHARX( DSPNAMES: Boolean; SOLICIT: string): SmallInt;
var CHARX : SmallInt;
begin
  GotoXY( 0, 18);
  Write( Chr( 11));
  if DSPNAMES then
    begin
      for LLBASE04 := 0 to PARTYCNT - 1 do
        begin
          GotoXY( 20 * (LLBASE04 mod 2), 20 + (LLBASE04 div 2));
          Write( LLBASE04 + 1: 1);
          Write( ') ');
          Write( CHARACTR[ LLBASE04]^.NAME)
        end
    end;
  repeat
    GotoXY( 0, 18);
    Write( Chr( 29));
    Write( SOLICIT);
    Write( ' ([RETURN] EXITS) >');
    GETKEY;
    LLBASE04 := Ord( INCHAR) - Ord( '0')
  until ((LLBASE04 > 0) and (LLBASE04 <= PARTYCNT)) or (INCHAR = Chr( 13));
  if INCHAR = Chr( CRETURN) then LLBASE04 := 0;
  GETCHARX := LLBASE04 - 1
end;

{ ── Mode E display implementation ───────────────────────────────────────── }

procedure GRAPHICS;
{ Initialise ANTIC Mode E (160x192, 4 colours) full-screen display.
  Builds CHRTAB lookup and ANTIC display list at runtime so any linker-chosen
  address for SCRNBUF is handled correctly (LMS inserted at each 4K crossing). }
var
  SCRADDR : Word;
  DLADDR  : Word;
  ROWADDR : Word;
  I, DI   : SmallInt;
begin
  { CHRTAB: TCHRIMAG byte (1bpp, Apple LSB = leftmost pixel) → Mode E byte
    (2bpp, bits[7:6] = leftmost pixel).  Each of the 4 low bits expands to
    a 2-bit pair: 1→11 (colour 3 = COLPF2), 0→00 (colour 0 = COLBAK). }
  for I := 0 to 255 do
    begin
      CHRTAB[ I] := 0;
      if (I and  1) <> 0 then CHRTAB[ I] := CHRTAB[ I] or $C0;
      if (I and  2) <> 0 then CHRTAB[ I] := CHRTAB[ I] or $30;
      if (I and  4) <> 0 then CHRTAB[ I] := CHRTAB[ I] or $0C;
      if (I and  8) <> 0 then CHRTAB[ I] := CHRTAB[ I] or $03
    end;

  { Build ANTIC display list for 192 Mode E rows.
    Insert LMS (load memory scan) before any row whose 40-byte span crosses
    a 4K boundary — ANTIC's internal counter wraps at 4K without one. }
  SCRADDR := Word( @SCRNBUF);
  DLADDR  := Word( @DLIST);
  DI := 0;

  DLIST[ DI] := $70; DI := DI + 1;   { blank 8 lines }
  DLIST[ DI] := $70; DI := DI + 1;
  DLIST[ DI] := $70; DI := DI + 1;

  DLIST[ DI] := $4E; DI := DI + 1;   { Mode E + LMS for row 0 }
  DLIST[ DI] := Lo( SCRADDR); DI := DI + 1;
  DLIST[ DI] := Hi( SCRADDR); DI := DI + 1;

  for I := 1 to 191 do
    begin
      ROWADDR := SCRADDR + Word( I) * SCRWIDTH;
      if (ROWADDR and $F000) <> ((ROWADDR + SCRWIDTH - 1) and $F000) then
        begin
          DLIST[ DI] := $4E; DI := DI + 1;
          DLIST[ DI] := Lo( ROWADDR); DI := DI + 1;
          DLIST[ DI] := Hi( ROWADDR); DI := DI + 1
        end
      else
        begin
          DLIST[ DI] := $0E; DI := DI + 1
        end
    end;

  DLIST[ DI] := $41; DI := DI + 1;   { JVB — jump + wait for VBL }
  DLIST[ DI] := Lo( DLADDR); DI := DI + 1;
  DLIST[ DI] := Hi( DLADDR);

  FillChar( SCRNBUF, SizeOf( SCRNBUF), 0);
  CURX := 0;
  CURY := 0;

  { Install display list — shadow registers (picked up by OS VBI) and
    hardware registers (take effect immediately). }
  Poke( $0230, Lo( DLADDR));   { SDLSTL shadow }
  Poke( $0231, Hi( DLADDR));   { SDLSTH shadow }
  Poke( $D402, Lo( DLADDR));   { DLISTL hardware }
  Poke( $D403, Hi( DLADDR));   { DLISTH hardware }

  { Standard-width (160px) playfield DMA — shadow + hardware. }
  Poke( $022F, $22);           { SDMCTL shadow }
  Poke( $D400, $22)            { DMACTL hardware }
end;


procedure TEXTMODE;
begin
  { All-Mode E: no text/graphics split — no-op. }
end;


procedure MVCURSOR( X, Y: SmallInt);
{ AP special X values: 40=GRAPHICS, 50=TEXTMODE, 60-79=copy-protect (skip),
  80=wait-for-key RNG tick (handled inside GETKEY).
  Normal range 0-39: update character cursor position. }
begin
  if X = 40 then begin GRAPHICS; exit end;
  if X = 50 then begin TEXTMODE; exit end;
  if X >= 60 then exit;
  CURX := X;
  CURY := Y
end;


procedure CLRRECT( X, Y, W, H: SmallInt);
{ Clear WxH character cells starting at (X,Y) in SCRNBUF.
  Each cell is 1 byte wide x CHARH scanlines tall in Mode E. }
var
  ROW, S : SmallInt;
  BASE   : Word;
begin
  for ROW := 0 to H - 1 do
    for S := 0 to CHARH - 1 do
      begin
        BASE := (Word( Y + ROW) * CHARH + Word( S)) * SCRWIDTH + Word( X);
        FillChar( SCRNBUF[ BASE], W, 0)
      end
end;


procedure PRINTCHR( ACHAR: Char);
{ Blit one CHARSET glyph into SCRNBUF at (CURX, CURY) and advance CURX.
  TCHRIMAG bytes are converted via CHRTAB (bit-reverse + 1bpp→2bpp expand). }
var
  IDX  : SmallInt;
  ROW  : SmallInt;
  BASE : Word;
begin
  IDX := Ord( ACHAR) - 32;
  if (IDX < 0) or (IDX > 63) then
    begin
      CURX := CURX + 1;
      exit
    end;
  BASE := Word( CURY) * CHARH * SCRWIDTH + Word( CURX);
  for ROW := 0 to CHARH - 1 do
    SCRNBUF[ BASE + Word( ROW) * SCRWIDTH] := CHRTAB[ CHARSET[ IDX][ ROW]];
  CURX := CURX + 1;
  if CURX >= CHARCOLS then
    begin
      CURX := 0;
      CURY := CURY + 1
    end
end;


procedure PRINTSTR( ASTRING: string);
var IPOS : SmallInt;
begin
  for IPOS := 1 to Length( ASTRING) do
    PRINTCHR( ASTRING[ IPOS])
end;


procedure PRINTNUM( ANUM, FIELDSZ: SmallInt);
{ Right-justified decimal, space-padded to FIELDSZ digits (1-5).
  Matches AP PRINTNUM exactly, rendered via PRINTCHR. }
var
  DIGITS : string[ 5];
  DIGITX : SmallInt;
begin
  if ANUM < 0 then ANUM := 0;
  if FIELDSZ > 5 then FIELDSZ := 5;
  if FIELDSZ < 1 then FIELDSZ := 1;
  for DIGITX := 5 downto 1 do
    begin
      DIGITS[ DIGITX] := Chr( 48 + (ANUM mod 10));
      ANUM := ANUM div 10
    end;
  DIGITX := 1;
  while (DIGITX < 5) and (DIGITS[ DIGITX] = Chr( 48)) do
    begin
      DIGITS[ DIGITX] := Chr( 32);
      DIGITX := DIGITX + 1
    end;
  for DIGITX := 6 - FIELDSZ to 5 do
    PRINTCHR( DIGITS[ DIGITX])
end;


procedure CENTSTR( ASTRING: string);
begin
  MVCURSOR( 20 - (Length( ASTRING) div 2), 23);
  PRINTSTR( ASTRING);
  PAUSE2
end;


procedure CLEARPIC;
begin
  FillChar( SCRNBUF, SizeOf( SCRNBUF), 0)
end;


procedure CLRPICT( X1, Y1, X2, Y2: SmallInt);
{ AP: Y2=100 → clear picture area; otherwise set DRAWLINE clip rectangle.
  Clip rectangle TODO: store X1/Y1/X2/Y2 and apply bounds-check in DRAWLINE. }
begin
  if Y2 = 100 then CLEARPIC
end;


procedure DRAWLINE( X, Y, DX, DY, LEN: SmallInt);
{ Step LEN pixels from (X,Y) by (DX,DY) each step, setting each pixel
  to colour 3 (COLPF2) in SCRNBUF.
  Mode E pixel (PX,PY): byte = PY*SCRWIDTH + PX div 4;
  bit-pair position = (3 - (PX and 3)) * 2. }
var
  I    : SmallInt;
  PX   : SmallInt;
  PY   : SmallInt;
  BOFF : Word;
  SHFT : SmallInt;
  MASK : Byte;
begin
  PX := X;
  PY := Y;
  for I := 1 to LEN do
    begin
      if (PX >= 0) and (PX < 160) and (PY >= 0) and (PY < 192) then
        begin
          BOFF := Word( PY) * SCRWIDTH + Word( PX) div 4;
          SHFT := (3 - (PX and 3)) * 2;
          MASK := Byte( 3 shl SHFT);
          SCRNBUF[ BOFF] := SCRNBUF[ BOFF] or MASK
        end;
      PX := PX + DX;
      PY := PY + DY
    end
end;


procedure PRINTBEL;
begin
  { AP: three bell characters.  Atari: write to POKEY AUDCTL/AUDF if wired;
    for now a no-op to avoid corrupting Mode E screen via Write(). }
end;

{ ── Timing ───────────────────────────────────────────────────────────────── }

procedure PAUSE1;
var I : SmallInt;
begin
  for I := 0 to TIMEDLAY do begin end
end;

procedure PAUSE2;
var I : SmallInt;
begin
  for I := 0 to 3000 do begin end
end;

{ ── Record loaders (stubs) ───────────────────────────────────────────────── }

{ Load a maze floor from SCENARIO.DATA and unpack AP packed format.
  AP disk layout (784 bytes):
    0..399    W/S/E/N wall maps: 2-bit TWALL per cell, 4/byte, 100 bytes each
    400..449  FIGHTS: 1-bit per cell, 8/byte, 50 bytes
    450..649  SQREXTRA: 4-bit per cell, 2/byte, 200 bytes
    650..657  SQRETYPE: 4-bit per entry, 2/byte, 8 bytes (16 entries)
    658..689  AUX0: 16 x LE INTEGER (32 bytes)
    690..721  AUX1: 16 x LE INTEGER (32 bytes)
    722..753  AUX2: 16 x LE INTEGER (32 bytes)
    754..783  ENMYCALC[1..3]: 3 x TENMYCALC (10 bytes each) }
procedure LOADTMAZE( LEVEL: SmallInt; var MAZE: TMAZE);
{ Confirmed offsets from WizardryData/MazeLevel.java (dmolony/WizardryData):
  Walls: 20 columns x 6 bytes (5 data + 1 pad byte); 2-bit per cell, 4 per byte.
    W=$000  S=$078  E=$0F0  N=$168
  FIGHTS:    $1E0  20 cols x 4 bytes (3 data + 1 pad); 1-bit/cell, 24-bit LE per col
  SQREXTRA:  $230  20 cols x 10 bytes; 4-bit per cell, 2 per byte
  SQRETYPE:  $2F8  16 entries, 4-bit each, 2 per byte
  AUX0:      $300  16 x LE INTEGER
  AUX1:      $320  16 x LE INTEGER
  AUX2:      $340  16 x LE INTEGER
  ENMYCALC:  $360  3 x 10-byte TENMYCALC (index 0 unused)
  Total data: 894 bytes; 130 bytes unused in 1024-byte IOCACHE.
  MP does not support ptr^[I] := x on LHS; use ^Byte + Inc(WP). }
var
  I, X, Y : SmallInt;
  WP      : ^Byte;
begin
  I := GETREC( ZMAZE, LEVEL, 784);
  { RECPER2BL[ZMAZE]=1: BUFFADDR always 0; full 1024-byte block loaded into IOCACHE }

  if MAZE.W        = nil then GetMem( MAZE.W);
  if MAZE.S        = nil then GetMem( MAZE.S);
  if MAZE.E        = nil then GetMem( MAZE.E);
  if MAZE.N        = nil then GetMem( MAZE.N);
  if MAZE.FIGHTS   = nil then GetMem( MAZE.FIGHTS);
  if MAZE.SQREXTRA = nil then GetMem( MAZE.SQREXTRA);
  for I := 0 to 3 do
    if MAZE.ENMYCALC[I] = nil then GetMem( MAZE.ENMYCALC[I]);

  { Wall maps: column X (0..19), row Y (0..19).
    Byte = base + X*6 + Y div 4.  Bit-pair = (Y mod 4)*2. }
  WP := Pointer(MAZE.W);
  for X := 0 to 19 do
    for Y := 0 to 19 do
      begin WP^ := (Ord( IOCACHE[       X*6 + Y div 4]) shr ((Y mod 4)*2)) and 3; Inc(WP) end;
  WP := Pointer(MAZE.S);
  for X := 0 to 19 do
    for Y := 0 to 19 do
      begin WP^ := (Ord( IOCACHE[$078 + X*6 + Y div 4]) shr ((Y mod 4)*2)) and 3; Inc(WP) end;
  WP := Pointer(MAZE.E);
  for X := 0 to 19 do
    for Y := 0 to 19 do
      begin WP^ := (Ord( IOCACHE[$0F0 + X*6 + Y div 4]) shr ((Y mod 4)*2)) and 3; Inc(WP) end;
  WP := Pointer(MAZE.N);
  for X := 0 to 19 do
    for Y := 0 to 19 do
      begin WP^ := (Ord( IOCACHE[$168 + X*6 + Y div 4]) shr ((Y mod 4)*2)) and 3; Inc(WP) end;

  { FIGHTS: column X, row Y.  24-bit LE value per column; bit = Y.
    Byte = $1E0 + X*4 + Y div 8.  Bit within byte = Y mod 8. }
  WP := Pointer(MAZE.FIGHTS);
  for X := 0 to 19 do
    for Y := 0 to 19 do
      begin WP^ := (Ord( IOCACHE[$1E0 + X*4 + Y div 8]) shr (Y mod 8)) and 1; Inc(WP) end;

  { SQREXTRA: 4-bit slot index, 2 cells/byte, low nibble = even Y.
    Byte = $230 + X*10 + Y div 2. }
  WP := Pointer(MAZE.SQREXTRA);
  for X := 0 to 19 do
    for Y := 0 to 19 do
      begin WP^ := (Ord( IOCACHE[$230 + X*10 + Y div 2]) shr ((Y mod 2)*4)) and $F; Inc(WP) end;

  { SQRETYPE: 4-bit TSQUARE, 2 per byte, low nibble = even entry }
  for I := 0 to 15 do
    MAZE.SQRETYPE[I] := (Ord( IOCACHE[$2F8 + I div 2]) shr ((I mod 2)*4)) and $F;

  { AUX0/AUX1/AUX2: 16 x LE INTEGER each }
  Move( IOCACHE[$300], MAZE.AUX0[0], 32);
  Move( IOCACHE[$320], MAZE.AUX1[0], 32);
  Move( IOCACHE[$340], MAZE.AUX2[0], 32);

  { ENMYCALC[1..3]: 3 x TENMYCALC (10 bytes each); index 0 is unused }
  for I := 1 to 3 do
    Move( IOCACHE[$360 + (I-1)*10], MAZE.ENMYCALC[I]^, SizeOf(TENMYCALC))
end;

{ Load TCHAR from disk (ZCHAR slot INDEX).
  AP disk layout (206 bytes used; DATASIZE=256, RECPER2BL=4):
    0  2xSTRING[15]                   NAME PASSWORD
   32  6x2-byte AP enum/BOOLEAN       INMAZE RACE CLASS AGE STATUS ALIGN
   44  PACKED 5-bitx6 (4 bytes)       ATTRIB[STRENGTH..LUCK]  (3 per LE word)
   48  PACKED 5-bitx5 (4 bytes)       LUCKSKIL[0..4]
   52  TWIZLONG (HIGH,MID,LOW)        GOLD
   58  INTEGER                        POSSCNT
   60  8x(3xBOOL+INTEGER) (64 bytes)  POSSESS[1..8]
  124  TWIZLONG                       EXP
  130  4xINTEGER                      MAXLEVAC CHARLEV HPLEFT HPMAX
  138  PACKED BOOLx50 (4 words)       SPELLSKN
  146  7xINTEGER (14 bytes)           MAGESP[1..7]
  160  7xINTEGER (14 bytes)           PRIESTSP[1..7]
  174  3xINTEGER                      HPCALCMD ARMORCL HEALPTS
  180  2-byte AP BOOLEAN              CRITHITM
  182  INTEGER                        SWINGCNT
  184  THPREC (6 bytes)               HPDAMRC
  190  PACKED BOOL 2x14 (4 bytes)     WEPVSTY2  (bits packed continuously)
  194  PACKED BOOL 2x7  (2 bytes)     WEPVSTY3
  196  PACKED BOOL 14   (2 bytes)     WEPVSTYP
  198  4xINTEGER (8 bytes)            LOSTXYL[1..4]
  206  (50 bytes padding to 256) }
procedure LOADTCHAR( INDEX: SmallInt; var CH: TCHAR);
var
  I, J, K : SmallInt;
  B       : SmallInt;
  W       : Word;
  PP      : ^TPOSSESS;
  SKN     : PTSPELLSKN;
  TC      : PTCHAR;
begin
  B  := GETREC( ZCHAR, INDEX, 256);
  TC := PTCHAR(@CH);
  FillChar( CH, SizeOf( TCHAR), 0);

  { Strings }
  Move( IOCACHE[B +  0], CH.NAME[0],     16);
  Move( IOCACHE[B + 16], CH.PASSWORD[0], 16);

  { AP 2-byte BOOLEAN / enum fields }
  CH.INMAZE := (Byte( IOCACHE[B + 32]) or Byte( IOCACHE[B + 33])) <> 0;
  CH.RACE   := TRACE(  Byte( IOCACHE[B + 34]));
  CH.XCLASS := TCLASS( Byte( IOCACHE[B + 36]));
  Move( IOCACHE[B + 38], CH.AGE, 2);
  CH.STATUS := TSTATUS( Byte( IOCACHE[B + 40]));
  CH.ALIGN  := TALIGN(  Byte( IOCACHE[B + 42]));

  { ATTRIB: 5-bit packed, 3 per LE word; integer index 0..5 = STRENGTH..LUCK }
  W := Byte( IOCACHE[B + 44]) or (Word( Byte( IOCACHE[B + 45])) shl 8);
  CH.ATTRIB[0] :=  W        and 31;
  CH.ATTRIB[1] := (W shr 5) and 31;
  CH.ATTRIB[2] := (W shr 10) and 31;
  W := Byte( IOCACHE[B + 46]) or (Word( Byte( IOCACHE[B + 47])) shl 8);
  CH.ATTRIB[3] :=  W        and 31;
  CH.ATTRIB[4] := (W shr 5) and 31;
  CH.ATTRIB[5] := (W shr 10) and 31;

  { LUCKSKIL: 5-bit packed, 3 per LE word }
  W := Byte( IOCACHE[B + 48]) or (Word( Byte( IOCACHE[B + 49])) shl 8);
  CH.LUCKSKIL[0] :=  W        and 31;
  CH.LUCKSKIL[1] := (W shr 5) and 31;
  CH.LUCKSKIL[2] := (W shr 10) and 31;
  W := Byte( IOCACHE[B + 50]) or (Word( Byte( IOCACHE[B + 51])) shl 8);
  CH.LUCKSKIL[3] :=  W       and 31;
  CH.LUCKSKIL[4] := (W shr 5) and 31;

  { GOLD: TWIZLONG disk HIGH→XHIGH, MID→XMID, LOW→XLOW }
  Move( IOCACHE[B + 52], CH.GOLD.XHIGH, 2);
  Move( IOCACHE[B + 54], CH.GOLD.XMID,  2);
  Move( IOCACHE[B + 56], CH.GOLD.XLOW,  2);

  { POSS }
  Move( IOCACHE[B + 58], CH.POSS.POSSCNT, 2);
  for I := 1 to 8 do
    begin
      if CH.POSS.POSSESS[I] = nil then GetMem( CH.POSS.POSSESS[I]);
      PP := CH.POSS.POSSESS[I];
      J  := B + 60 + (I - 1) * 8;
      PP.EQUIPED := (Byte( IOCACHE[J    ]) or Byte( IOCACHE[J + 1])) <> 0;
      PP.CURSED  := (Byte( IOCACHE[J + 2]) or Byte( IOCACHE[J + 3])) <> 0;
      PP.IDENTIF := (Byte( IOCACHE[J + 4]) or Byte( IOCACHE[J + 5])) <> 0;
      Move( IOCACHE[J + 6], PP.EQINDEX, 2)
    end;

  { EXP: TWIZLONG }
  Move( IOCACHE[B + 124], CH.EXP.XHIGH, 2);
  Move( IOCACHE[B + 126], CH.EXP.XMID,  2);
  Move( IOCACHE[B + 128], CH.EXP.XLOW,  2);

  { MAXLEVAC CHARLEV HPLEFT HPMAX: 4 x INTEGER = 8 bytes }
  Move( IOCACHE[B + 130], CH.MAXLEVAC, 8);

  { SPELLSKN: 50 bits in 4 LE words at +138; bit I = word I/16 bit I mod 16 }
  if TC.SPELLSKN = nil then GetMem( TC.SPELLSKN);
  SKN := TC.SPELLSKN;
  for I := 0 to 49 do
    begin
      K := B + 138 + (I div 16) * 2;
      W := Byte( IOCACHE[K]) or (Word( Byte( IOCACHE[K + 1])) shl 8);
      SKN^[I] := (W shr (I mod 16)) and 1 <> 0
    end;

  { MAGESP / PRIESTSP: AP ARRAY[1..7] OF INTEGER = 14 bytes each }
  Move( IOCACHE[B + 146], CH.MAGESP[1],   14);
  Move( IOCACHE[B + 160], CH.PRIESTSP[1], 14);

  { HPCALCMD ARMORCL HEALPTS: 3 x INTEGER = 6 bytes }
  Move( IOCACHE[B + 174], CH.HPCALCMD, 6);

  { CRITHITM }
  CH.CRITHITM := (Byte( IOCACHE[B + 180]) or Byte( IOCACHE[B + 181])) <> 0;

  { SWINGCNT }
  Move( IOCACHE[B + 182], CH.SWINGCNT, 2);

  { HPDAMRC: THPREC }
  Move( IOCACHE[B + 184], CH.HPDAMRC, 6);

  { WEPVSTY2: 28 bits packed continuously into 2 words; bit = row*14+col }
  for I := 0 to 1 do
    for J := 0 to 13 do
      begin
        K := I * 14 + J;
        W := Byte( IOCACHE[B + 190 + (K div 16) * 2]) or
             (Word( Byte( IOCACHE[B + 190 + (K div 16) * 2 + 1])) shl 8);
        CH.WEPVSTY2[I, J] := (W shr (K mod 16)) and 1 <> 0
      end;

  { WEPVSTY3: row-aligned, 2 words (4 bytes); each row in its own 16-bit word.
    Row 0 at +194 (bits 0-6 = [0][0..6]); row 1 at +196 (bits 0-6 = [1][0..6]) }
  W := Byte( IOCACHE[B + 194]) or (Word( Byte( IOCACHE[B + 195])) shl 8);
  for J := 0 to 6 do
    CH.WEPVSTY3[0, J] := (W shr J) and 1 <> 0;
  W := Byte( IOCACHE[B + 196]) or (Word( Byte( IOCACHE[B + 197])) shl 8);
  for J := 0 to 6 do
    CH.WEPVSTY3[1, J] := (W shr J) and 1 <> 0;

  { WEPVSTYP: 14 bits in 1 word at +198 }
  W := Byte( IOCACHE[B + 198]) or (Word( Byte( IOCACHE[B + 199])) shl 8);
  for I := 0 to 13 do
    CH.WEPVSTYP[I] := (W shr I) and 1 <> 0;

  { LOSTXYL: AP ARRAY[1..4] OF INTEGER = 8 bytes at +200; MP [0] unused }
  Move( IOCACHE[B + 200], CH.LOSTXYL[1], 8)
end;

{ Save TCHAR to disk (ZCHAR slot INDEX).
  Reverses LOADTCHAR: serializes MP fields to 206-byte AP wire format. }
procedure SAVETCHAR( INDEX: SmallInt; var CH: TCHAR);
var
  I, J, K : SmallInt;
  B       : SmallInt;
  W, W1   : Word;
  PP      : ^TPOSSESS;
  SKN     : PTSPELLSKN;
  TC      : PTCHAR;
begin
  B  := GETRECW( ZCHAR, INDEX, 256);
  TC := PTCHAR(@CH);

  { Zero the full 256-byte slot first }
  for I := 0 to 255 do IOCACHE[B + I] := Chr(0);

  { Strings }
  Move( CH.NAME[0],     IOCACHE[B +  0], 16);
  Move( CH.PASSWORD[0], IOCACHE[B + 16], 16);

  { INMAZE: Boolean → AP 2-byte BOOLEAN }
  if CH.INMAZE then W := $FFFF else W := 0;
  Move( W, IOCACHE[B + 32], 2);

  { Enums: 1-byte MP → 2-byte AP (high byte already 0 from zeroing) }
  IOCACHE[B + 34] := Chr( Ord( CH.RACE));
  IOCACHE[B + 36] := Chr( Ord( CH.XCLASS));
  Move( CH.AGE, IOCACHE[B + 38], 2);
  IOCACHE[B + 40] := Chr( Ord( CH.STATUS));
  IOCACHE[B + 42] := Chr( Ord( CH.ALIGN));

  { ATTRIB: pack 6 x 5-bit values into 2 words }
  W := Word(CH.ATTRIB[0]) or (Word(CH.ATTRIB[1]) shl 5) or (Word(CH.ATTRIB[2]) shl 10);
  Move( W, IOCACHE[B + 44], 2);
  W := Word(CH.ATTRIB[3]) or (Word(CH.ATTRIB[4]) shl 5) or (Word(CH.ATTRIB[5]) shl 10);
  Move( W, IOCACHE[B + 46], 2);

  { LUCKSKIL: pack 5 x 5-bit values into 2 words }
  W := Word(CH.LUCKSKIL[0]) or (Word(CH.LUCKSKIL[1]) shl 5) or (Word(CH.LUCKSKIL[2]) shl 10);
  Move( W, IOCACHE[B + 48], 2);
  W := Word(CH.LUCKSKIL[3]) or (Word(CH.LUCKSKIL[4]) shl 5);
  Move( W, IOCACHE[B + 50], 2);

  { GOLD: TWIZLONG XHIGH→HIGH, XMID→MID, XLOW→LOW }
  Move( CH.GOLD.XHIGH, IOCACHE[B + 52], 2);
  Move( CH.GOLD.XMID,  IOCACHE[B + 54], 2);
  Move( CH.GOLD.XLOW,  IOCACHE[B + 56], 2);

  { POSS }
  Move( CH.POSS.POSSCNT, IOCACHE[B + 58], 2);
  for I := 1 to 8 do
    begin
      J := B + 60 + (I - 1) * 8;
      PP := CH.POSS.POSSESS[I];
      if PP <> nil then
        begin
          if PP.EQUIPED then W := $FFFF else W := 0;
          Move( W, IOCACHE[J], 2);
          if PP.CURSED  then W := $FFFF else W := 0;
          Move( W, IOCACHE[J + 2], 2);
          if PP.IDENTIF then W := $FFFF else W := 0;
          Move( W, IOCACHE[J + 4], 2);
          Move( PP.EQINDEX, IOCACHE[J + 6], 2)
        end
    end;

  { EXP: TWIZLONG }
  Move( CH.EXP.XHIGH, IOCACHE[B + 124], 2);
  Move( CH.EXP.XMID,  IOCACHE[B + 126], 2);
  Move( CH.EXP.XLOW,  IOCACHE[B + 128], 2);

  { MAXLEVAC CHARLEV HPLEFT HPMAX }
  Move( CH.MAXLEVAC, IOCACHE[B + 130], 8);

  { SPELLSKN: 50 booleans → 4 LE words }
  SKN := TC.SPELLSKN;
  for K := 0 to 3 do
    begin
      W := 0;
      for I := 0 to 15 do
        begin
          J := K * 16 + I;
          if (J <= 49) and SKN^[J] then
            W := W or (Word(1) shl I)
        end;
      Move( W, IOCACHE[B + 138 + K * 2], 2)
    end;

  { MAGESP / PRIESTSP }
  Move( CH.MAGESP[1],   IOCACHE[B + 146], 14);
  Move( CH.PRIESTSP[1], IOCACHE[B + 160], 14);

  { HPCALCMD ARMORCL HEALPTS }
  Move( CH.HPCALCMD, IOCACHE[B + 174], 6);

  { CRITHITM }
  if CH.CRITHITM then W := $FFFF else W := 0;
  Move( W, IOCACHE[B + 180], 2);

  { SWINGCNT }
  Move( CH.SWINGCNT, IOCACHE[B + 182], 2);

  { HPDAMRC }
  Move( CH.HPDAMRC, IOCACHE[B + 184], 6);

  { WEPVSTY2: 28 bits into 2 words }
  W := 0; W1 := 0;
  for I := 0 to 1 do
    for J := 0 to 13 do
      if CH.WEPVSTY2[I, J] then
        begin
          K := I * 14 + J;
          if K < 16 then W  := W  or (Word(1) shl K)
          else            W1 := W1 or (Word(1) shl (K - 16))
        end;
  Move( W,  IOCACHE[B + 190], 2);
  Move( W1, IOCACHE[B + 192], 2);

  { WEPVSTY3: row-aligned, 2 words at +194/+196 }
  W := 0;
  for J := 0 to 6 do
    if CH.WEPVSTY3[0, J] then W := W or (Word(1) shl J);
  Move( W, IOCACHE[B + 194], 2);
  W := 0;
  for J := 0 to 6 do
    if CH.WEPVSTY3[1, J] then W := W or (Word(1) shl J);
  Move( W, IOCACHE[B + 196], 2);

  { WEPVSTYP: 14 bits into 1 word at +198 }
  W := 0;
  for I := 0 to 13 do
    if CH.WEPVSTYP[I] then W := W or (Word(1) shl I);
  Move( W, IOCACHE[B + 198], 2);

  { LOSTXYL[1..4] at +200 }
  Move( CH.LOSTXYL[1], IOCACHE[B + 200], 8)
end;

{ Load TOBJREC from disk (ZOBJECT slot INDEX).
  AP disk layout (78 bytes):
    0   2xSTRING[15] = 2x16 bytes   NAME NAMEUNK
   32   2xINTEGER                   OBJTYPE ALIGN  (2-byte AP enum → 1-byte MP enum)
   36   3xINTEGER                   SPECIAL CHANGETO CHGCHANC
   42   TWIZLONG (HIGH,MID,LOW)     PRICE
   48   2xINTEGER                   BOLTACXX SPELLPWR
   52   BOOLEAN (2-byte AP)         CURSED   (-1=true, 0=false)
   54   PACKED BOOL (8-bit)         CLASSUSE (bit 0=FIGHTER..bit 7=NINJA)
   56   INTEGER                     HEALPTS
   58   2xPACKED BOOL (16-bit)      WEPVSTY2 WEPVSTY3
   62   2xINTEGER                   ARMORMOD WEPHITMD
   66   THPREC                      WEPHPDAM
   72   INTEGER                     XTRASWNG
   74   BOOLEAN (2-byte AP)         CRITHITM
   76   PACKED BOOL (14-bit)        WEPVSTYP }
procedure LOADOBJREC( INDEX: SmallInt; var OBJ: TOBJREC);
var
  I : SmallInt;
  B : SmallInt;
  W : Word;
begin
  B := GETREC( ZOBJECT, INDEX, 78);
  FillChar( OBJ, SizeOf( TOBJREC), 0);

  { Strings }
  Move( IOCACHE[B +  0], OBJ.NAME[0],    16);
  Move( IOCACHE[B + 16], OBJ.NAMEUNK[0], 16);

  { 2-byte AP enum → 1-byte MP enum (low byte only; values 0..6 / 0..3) }
  OBJ.OBJTYPE := TOBJTYPE( Byte( IOCACHE[B + 32]));
  OBJ.ALIGN   := TALIGN(   Byte( IOCACHE[B + 34]));

  { AP source field order: CURSED before SPECIAL (confirmed Item.java) }
  OBJ.CURSED := (Byte( IOCACHE[B + 36]) or Byte( IOCACHE[B + 37])) <> 0;
  Move( IOCACHE[B + 38], OBJ.SPECIAL,  2);
  Move( IOCACHE[B + 40], OBJ.CHANGETO, 2);
  Move( IOCACHE[B + 42], OBJ.CHGCHANC, 2);

  { PRICE: TWIZLONG disk HIGH→XHIGH, MID→XMID, LOW→XLOW }
  Move( IOCACHE[B + 44], OBJ.PRICE.XHIGH, 2);
  Move( IOCACHE[B + 46], OBJ.PRICE.XMID,  2);
  Move( IOCACHE[B + 48], OBJ.PRICE.XLOW,  2);

  Move( IOCACHE[B + 50], OBJ.BOLTACXX, 2);
  Move( IOCACHE[B + 52], OBJ.SPELLPWR, 2);

  { CLASSUSE: 8-bit packed → array[FIGHTER..NINJA] of Boolean }
  W := Byte( IOCACHE[B + 54]) or (Word( Byte( IOCACHE[B + 55])) shl 8);
  for I := 0 to 7 do
    OBJ.CLASSUSE[I] := (W shr I) and 1 <> 0;

  Move( IOCACHE[B + 56], OBJ.HEALPTS, 2);

  { WEPVSTY2/WEPVSTY3: 16-bit packed → array[0..15] of Boolean }
  W := Byte( IOCACHE[B + 58]) or (Word( Byte( IOCACHE[B + 59])) shl 8);
  for I := 0 to 15 do
    OBJ.WEPVSTY2[I] := (W shr I) and 1 <> 0;

  W := Byte( IOCACHE[B + 60]) or (Word( Byte( IOCACHE[B + 61])) shl 8);
  for I := 0 to 15 do
    OBJ.WEPVSTY3[I] := (W shr I) and 1 <> 0;

  Move( IOCACHE[B + 62], OBJ.ARMORMOD, 2);
  Move( IOCACHE[B + 64], OBJ.WEPHITMD, 2);

  { WEPHPDAM: THPREC — same field order AP/MP }
  Move( IOCACHE[B + 66], OBJ.WEPHPDAM, 6);

  Move( IOCACHE[B + 72], OBJ.XTRASWNG, 2);

  { CRITHITM: AP 2-byte BOOLEAN → MP Boolean }
  OBJ.CRITHITM := (Byte( IOCACHE[B + 74]) or Byte( IOCACHE[B + 75])) <> 0;

  { WEPVSTYP: 14-bit packed → array[0..13] of Boolean }
  W := Byte( IOCACHE[B + 76]) or (Word( Byte( IOCACHE[B + 77])) shl 8);
  for I := 0 to 13 do
    OBJ.WEPVSTYP[I] := (W shr I) and 1 <> 0
end;

{ Save TOBJREC back to disk (ZOBJECT slot INDEX).
  Reverses LOADOBJREC: serializes MP fields to 78-byte AP wire format in IOCACHE,
  then GETRECW marks the cache dirty for writeback. }
procedure SAVEOBJREC( INDEX: SmallInt; var OBJ: TOBJREC);
var
  I : SmallInt;
  B : SmallInt;
  W : Word;
begin
  B := GETRECW( ZOBJECT, INDEX, 78);

  { Strings }
  Move( OBJ.NAME[0],    IOCACHE[B +  0], 16);
  Move( OBJ.NAMEUNK[0], IOCACHE[B + 16], 16);

  { 1-byte MP enum → 2-byte AP INTEGER (high byte explicit 0) }
  IOCACHE[B + 32] := Chr( Ord( OBJ.OBJTYPE));
  IOCACHE[B + 33] := Chr(0);
  IOCACHE[B + 34] := Chr( Ord( OBJ.ALIGN));
  IOCACHE[B + 35] := Chr(0);

  { AP source field order: CURSED before SPECIAL (confirmed Item.java) }
  if OBJ.CURSED then W := $FFFF else W := 0;
  Move( W, IOCACHE[B + 36], 2);
  Move( OBJ.SPECIAL,  IOCACHE[B + 38], 2);
  Move( OBJ.CHANGETO, IOCACHE[B + 40], 2);
  Move( OBJ.CHGCHANC, IOCACHE[B + 42], 2);

  { PRICE: TWIZLONG XHIGH→HIGH, XMID→MID, XLOW→LOW }
  Move( OBJ.PRICE.XHIGH, IOCACHE[B + 44], 2);
  Move( OBJ.PRICE.XMID,  IOCACHE[B + 46], 2);
  Move( OBJ.PRICE.XLOW,  IOCACHE[B + 48], 2);

  Move( OBJ.BOLTACXX, IOCACHE[B + 50], 2);
  Move( OBJ.SPELLPWR, IOCACHE[B + 52], 2);

  { CLASSUSE: array[FIGHTER..NINJA] of Boolean → 8-bit packed }
  W := 0;
  for I := 0 to 7 do
    if OBJ.CLASSUSE[I] then W := W or (Word(1) shl I);
  Move( W, IOCACHE[B + 54], 2);

  Move( OBJ.HEALPTS, IOCACHE[B + 56], 2);

  { WEPVSTY2/WEPVSTY3: array[0..15] of Boolean → 16-bit packed }
  W := 0;
  for I := 0 to 15 do
    if OBJ.WEPVSTY2[I] then W := W or (Word(1) shl I);
  Move( W, IOCACHE[B + 58], 2);

  W := 0;
  for I := 0 to 15 do
    if OBJ.WEPVSTY3[I] then W := W or (Word(1) shl I);
  Move( W, IOCACHE[B + 60], 2);

  Move( OBJ.ARMORMOD, IOCACHE[B + 62], 2);
  Move( OBJ.WEPHITMD, IOCACHE[B + 64], 2);

  { WEPHPDAM: THPREC }
  Move( OBJ.WEPHPDAM, IOCACHE[B + 66], 6);

  Move( OBJ.XTRASWNG, IOCACHE[B + 72], 2);

  { CRITHITM: MP Boolean → AP 2-byte BOOLEAN }
  if OBJ.CRITHITM then W := $FFFF else W := 0;
  Move( W, IOCACHE[B + 74], 2);

  { WEPVSTYP: array[0..13] of Boolean → 14-bit packed (bits 14-15 stay 0) }
  W := 0;
  for I := 0 to 13 do
    if OBJ.WEPVSTYP[I] then W := W or (Word(1) shl I);
  Move( W, IOCACHE[B + 76], 2)
end;

{ Load TENEMY from disk (ZENEMY slot INDEX).
  AP disk layout (158 bytes):
    0   4xSTRING[15] = 4x16 bytes  NAMEUNK NAMEUNKS NAME NAMES
   64   INTEGER                    PIC
   66   TWIZLONG (HIGH,MID,LOW)    CALC1
   72   THPREC                     HPREC
   78   3xINTEGER                  XCLASS AC RECSN
   84   7xTHPREC = 42 bytes        RECS[1..7]
  126   TWIZLONG (HIGH,MID,LOW)    EXPAMT
  132   11xINTEGER = 22 bytes      DRAINAMT..UNAFFCT
  154   2xPACKED BOOL (16-bit LE)  WEPVSTY3 SPPC
  AP TWIZLONG disk order is HIGH,MID,LOW; MP is XHIGH,XMID,XLOW — not byte-compatible. }
procedure LOADENEMY( INDEX: SmallInt; var ENM: TENEMY);
var
  I : SmallInt;
  B : SmallInt;
  W : Word;
begin
  B := GETREC( ZENEMY, INDEX, 158);
  FillChar( ENM, SizeOf( TENEMY), 0);

  { 4 x STRING[15]: 16 bytes each (1 len + 15 chars, no pad) }
  Move( IOCACHE[B +  0], ENM.NAMEUNK[0],  16);
  Move( IOCACHE[B + 16], ENM.NAMEUNKS[0], 16);
  Move( IOCACHE[B + 32], ENM.NAME[0],     16);
  Move( IOCACHE[B + 48], ENM.NAMES[0],    16);

  { PIC (INTEGER) }
  Move( IOCACHE[B + 64], ENM.PIC, 2);

  { CALC1 (TWIZLONG): disk HIGH→XHIGH, MID→XMID, LOW→XLOW }
  Move( IOCACHE[B + 66], ENM.CALC1.XHIGH, 2);
  Move( IOCACHE[B + 68], ENM.CALC1.XMID,  2);
  Move( IOCACHE[B + 70], ENM.CALC1.XLOW,  2);

  { HPREC (THPREC): same field order AP/MP }
  Move( IOCACHE[B + 72], ENM.HPREC, 6);

  { XCLASS, AC, RECSN (3 x INTEGER = 6 bytes) }
  Move( IOCACHE[B + 78], ENM.XCLASS, 6);

  { RECS[1..7]: 7 x THPREC inline on disk (42 bytes); RECS[0] stays nil }
  for I := 1 to 7 do
    begin
      if ENM.RECS[I] = nil then GetMem( ENM.RECS[I]);
      Move( IOCACHE[B + 84 + (I-1)*6], ENM.RECS[I]^, 6)
    end;

  { EXPAMT (TWIZLONG): disk HIGH→XHIGH, MID→XMID, LOW→XLOW }
  Move( IOCACHE[B + 126], ENM.EXPAMT.XHIGH, 2);
  Move( IOCACHE[B + 128], ENM.EXPAMT.XMID,  2);
  Move( IOCACHE[B + 130], ENM.EXPAMT.XLOW,  2);

  { DRAINAMT..UNAFFCT (11 x INTEGER = 22 bytes); contiguous in AP and MP }
  Move( IOCACHE[B + 132], ENM.DRAINAMT, 22);

  { WEPVSTY3: PACKED ARRAY[0..15] OF BOOLEAN → 16-bit LE word → Boolean array }
  W := Byte( IOCACHE[B + 154]) or (Word( Byte( IOCACHE[B + 155])) shl 8);
  for I := 0 to 15 do
    ENM.WEPVSTY3[I] := (W shr I) and 1 <> 0;

  { SPPC: same }
  W := Byte( IOCACHE[B + 156]) or (Word( Byte( IOCACHE[B + 157])) shl 8);
  for I := 0 to 15 do
    ENM.SPPC[I] := (W shr I) and 1 <> 0
end;

end.
