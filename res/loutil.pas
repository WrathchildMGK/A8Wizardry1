unit LOUTIL;

{ Wizardry I — disk-side utilities: direct sector access to SCENARIO.DAT /
  SCENARIO.MSG, the GETREC cache, the record loaders and the static wiring
  of record pointer fields (AP WIZ2.TEXT GETREC etc.).  Part of the low
  resident WIZRES, in main RAM, because the OS ROM is switched in for each
  SIO transfer (OSIN / OSOUT); overlays reach it through imp/util.pas. }

interface

uses TYPES, CONSTS, GLOBALS;

{ OS ROM in / back to the previous state, around anything needing the OS
  (SIO, CIO).  Nothing may print while the OS is in: the console is under it. }
procedure OSIN; assembler;
procedure OSOUT; assembler;

{ Disk cache }
function  GETREC ( DATATYPE: TZSCN; DATAINDX, DATASIZE: SmallInt): SmallInt;
function  GETRECW( DATATYPE: TZSCN; DATAINDX, DATASIZE: SmallInt): SmallInt;

{ Scenario file location — returns block offset within the named file
  (0: each is its own file on the Atari), -9 if not on the disk. }
function  FINDFILE( DRIVE: SmallInt; FILENM: PString): SmallInt;

{ Disk I/O — direct sector access to SCENARIO.DAT / SCENARIO.MSG.
  UNITREAD/UNITWRITE load/save IOCACHE (1024 bytes at a 512-byte block).
  UNITREAD_MSG reads one block (BLOCKSZ bytes) of SCENARIO.MSG into BUF. }
procedure UNITREAD    ( BLOCK: SmallInt);
procedure UNITWRITE   ( BLOCK: SmallInt);

{ Byte ranges of a data file, any offset/length (spanning sector ends). }
const
  FSCEN = 0;                   { SCENARIO.DAT }
  FMESG = 1;                   { SCENARIO.MSG }
procedure READRANGE ( F: Byte; OFS: Cardinal; LEN: Word; DEST: Pointer);
procedure WRITERANGE( F: Byte; OFS: Cardinal; LEN: Word; SRC: Pointer);
procedure UNITREAD_BUF( BLOCK: SmallInt; var BUF);
procedure UNITREAD_MSG( BLOCK: SmallInt; var BUF);

{ Sequential read of any file by following its sector links (it need not be
  contiguous): WIZHI.XEX and the overlays, so DOS is not needed after boot.
  NM is the 8+3 directory name, space padded ('CASTLE  OVL').  SEQREAD
  returns the number of bytes read, less than LEN at the end of the file. }
function  SEQOPEN( NM: PString): Boolean;
function  SEQREAD( DEST: Pointer; LEN: Word): Word;

{ IOCACHE (blocks 0-1) → SCNTOC + SCNNAMES strings; reads SPELBLK_DATA.
  Checks the file was built for these record sizes.  Call after UNITREAD(SCNTOCBL). }
procedure LOADSCNTOC;

{ Static wiring of record pointer fields (no heap: see types.pas TPOSSBLK).
  A record must be wired once before it is loaded or used; the loaders and
  CLEARCHAR/COPYCHAR keep the wiring.  Pointed-to blocks are contiguous. }
procedure WIRECHAR ( var C: TCHAR; var SKN: TSPELLSKN; var POSS: TPOSSBLK);
procedure CLEARCHAR( var C: TCHAR);
procedure COPYCHAR ( var DST: TCHAR; var SRC: TCHAR);
procedure WIREMAZE ( var M: TMAZE; var W, S, E, N: TMAZEMAP; var FIGHTS: TFIGHTMAP;
                     var SQREXTRA: TSQRMAP; var EC: TECBLK);
procedure WIREENEMY( var ENM: TENEMY; var RECS: TRECSBLK);
procedure WIREEXP  ( var EXP: TEXP; var BLK: TEXPBLK);

{ Record loaders — native records (SCENARIO.DAT, tools/mkscen.py). }
procedure LOADTMAZE ( LEVEL: SmallInt; var MAZE: TMAZE);
procedure SAVETMAZE ( LEVEL: SmallInt; var MAZE: TMAZE);
procedure LOADTCHAR ( INDEX: SmallInt; var CH:   TCHAR);
procedure SAVETCHAR ( INDEX: SmallInt; var CH:   TCHAR);
procedure LOADOBJREC( INDEX: SmallInt; var OBJ:  TOBJREC);
procedure SAVEOBJREC( INDEX: SmallInt; var OBJ:  TOBJREC);
procedure LOADENEMY ( INDEX: SmallInt; var ENM:  TENEMY);
procedure LOADTEXP  ( var EXP: TEXP);

implementation

{ ── OS ROM switching ─────────────────────────────────────────────────────── }

var
  OSSAVE : Byte;               { PORTB bit 0 before OSIN }

procedure OSIN; assembler;
asm
	sei
	lda #$00
	sta $D40E
	lda $D301
	and #$01
	sta OSSAVE
	lda $D301
	ora #$01
	sta $D301
	lda #$40
	sta $D40E
	cli
end;

procedure OSOUT; assembler;
asm
	lda OSSAVE
	bne done
	sei
	lda #$00
	sta $D40E
	lda $D301
	and #$FE
	sta $D301
	lda #$40
	sta $D40E
	cli
done
end;


{ ── Disk I/O — direct sector access ──────────────────────────────────────── }

{ LiteDOS-SE can neither seek (no POINT) nor write double density, so the
  data files are read and written sector by sector through SIO.  A file
  must be contiguous on disk (the build checks this; READ/WRITE re-check
  each link).  LiteDOS DD sector: 253 data bytes, link-hi, link-lo, count.
  Byte offset N of a file = sector FSTART + N div 253, position N mod 253.
  A range may start and end anywhere inside a sector: each touched sector
  is read and only its covered bytes used or replaced, so read-modify-write
  keeps the 3 trailer bytes intact.  SIOSEC switches the OS ROM in for each
  transfer, so errors are always reported with the OS out. }

const
  SIOV     = $E459;
  SECDATA  = 253;              { data bytes per DD sector }
  DIRFIRST = 361;              { LiteDOS directory: sectors 361.. }
  DIRLAST  = 368;

var
  SECBUF   : array[ 0..255] of Byte;
  SECNUM   : Word;             { sector held in SECBUF, 0 = none }
  FSTART   : array[ FSCEN..FMESG] of Word;
  FSECTS   : array[ FSCEN..FMESG] of Word;
  FOPEN    : array[ FSCEN..FMESG] of Boolean;

const
  FNAME    : array[ FSCEN..FMESG] of string[ 11] =   { 8+3 directory names }
             ( 'SCENARIODAT', 'SCENARIOMSG');

procedure SIOCALL( CMD, DIR: Byte; SECT: Word); assembler;
{ Drive 1, one 256-byte sector to/from SECBUF.  CMD 'R' / 'P', DIR $40 / $80.
  Needs the OS ROM: called only by SIOSEC. }
asm
	lda #$31
	sta $0300
	lda #$01
	sta $0301
	lda CMD
	sta $0302
	lda DIR
	sta $0303
	lda <adr.SECBUF
	sta $0304
	lda >adr.SECBUF
	sta $0305
	lda #$07
	sta $0306
	lda #$00
	sta $0308
	lda #$01
	sta $0309
	lda SECT
	sta $030A
	lda SECT+1
	sta $030B
	txa
	pha
	jsr SIOV
	pla
	tax
end;

procedure SIOSEC( CMD, DIR: Byte; SECT: Word);
{ One sector transfer, with the OS ROM switched in for it only. }
begin
  OSIN;
  SIOCALL( CMD, DIR, SECT);
  OSOUT
end;

procedure DISKFAIL( MSG: string[ 20]; SECT: Word);
begin
  Write( 'DISK ERROR: ');
  Write( MSG);
  Write( ' SECTOR ');
  WriteLn( SECT);
  repeat until False
end;

procedure SECREAD( SECT: Word);
var
  TRY : Byte;
begin
  if SECT = SECNUM then exit;
  for TRY := 1 to 3 do
    begin
      SIOSEC( $52, $40, SECT);
      if Peek( $0303) < 128 then
        begin
          SECNUM := SECT;
          exit
        end
    end;
  SECNUM := 0;
  DISKFAIL( 'READ', SECT)
end;

procedure SECWRITE;
var
  TRY : Byte;
begin
  for TRY := 1 to 3 do
    begin
      SIOSEC( $50, $80, SECNUM);
      if Peek( $0303) < 128 then exit
    end;
  DISKFAIL( 'WRITE', SECNUM)
end;

function DIRFIND( NM: PString; var START, SIZE: Word): Boolean;
{ Look NM up in the LiteDOS directory (16-byte entries: flags bit 6 in
  use / bit 7 deleted, size, start sector, 8+3 name).  NM's characters are
  read with Peek: "S := NM^" is miscompiled by MP 1.7.9 (mpbugs/bug14). }
var
  S    : Word;
  E, K : Byte;
  HIT  : Boolean;
begin
  for S := DIRFIRST to DIRLAST do
    begin
      SECREAD( S);
      for E := 0 to 15 do
        if SECBUF[ E * 16] and $C0 = $40 then
          begin
            HIT := True;
            for K := 0 to 10 do
              if SECBUF[ E * 16 + 5 + K] <> Peek( Word( NM) + K + 1) then HIT := False;
            if HIT then
              begin
                SIZE  := SECBUF[ E * 16 + 1] + Word( SECBUF[ E * 16 + 2]) shl 8;
                START := SECBUF[ E * 16 + 3] + Word( SECBUF[ E * 16 + 4]) shl 8;
                exit( True)
              end
          end
    end;
  Result := False
end;

function FILEFIND( F: Byte): Boolean;
{ Locate data file F; it must be contiguous (READRANGE computes sectors). }
var
  L, ST, SZ : Word;
  NM        : string[ 11];
begin
  Result := FOPEN[ F];
  if Result then exit;
  NM := FNAME[ F];                { MP can't index FNAME[ F][ K] directly }
  if not DIRFIND( @NM, ST, SZ) then exit;
  FSTART[ F] := ST;
  FSECTS[ F] := SZ;
  { Contiguous only if the sector SIZE-1 after the start is the file's
    last (zero link): any gap, e.g. around the directory at 360-368, moves
    the real end further on. }
  L := FSTART[ F] + FSECTS[ F] - 1;
  SECREAD( L);
  if ( SECBUF[ 253] <> 0) or ( SECBUF[ 254] <> 0) then
    DISKFAIL( 'FILE NOT CONTIGUOUS', L);
  FOPEN[ F] := True;
  Result := True
end;

procedure FILEPOS( F: Byte; OFS: Cardinal; var REL: Word; var POS: Byte);
{ Byte OFS of file F = data byte POS of its REL'th sector (one division). }
begin
  if not FILEFIND( F) then DISKFAIL( FNAME[ F], 0);
  REL := Word( OFS div SECDATA);
  POS := Byte( OFS mod SECDATA)
end;

procedure FILESEC( F: Byte; REL: Word);
{ The REL'th sector of file F into SECBUF.  Its link must point at the
  next sector unless it is the file's last. }
var
  S : Word;
begin
  if REL >= FSECTS[ F] then DISKFAIL( 'PAST END', REL);
  S := FSTART[ F] + REL;
  SECREAD( S);
  if REL + 1 < FSECTS[ F] then
    if SECBUF[ 253] * 256 + SECBUF[ 254] <> S + 1 then
      DISKFAIL( 'FILE NOT CONTIGUOUS', S)
end;

procedure READRANGE( F: Byte; OFS: Cardinal; LEN: Word; DEST: Pointer);
{ First and last sectors may be partial; the rest are whole (POS 0). }
var
  REL : Word;
  POS : Byte;
  N   : Word;
  D   : PByte;
begin
  D := DEST;
  FILEPOS( F, OFS, REL, POS);
  while LEN > 0 do
    begin
      FILESEC( F, REL);
      N := SECDATA - POS;
      if N > LEN then N := LEN;
      Move( SECBUF[ POS], D^, N);
      Inc( D, N);
      Dec( LEN, N);
      Inc( REL);
      POS := 0
    end
end;

var
  SEQSEC : Word;               { sector being read, 0 = end of file }
  SEQPOS : Byte;               { next byte in it }

function SEQOPEN( NM: PString): Boolean;
var
  SIZE : Word;
begin
  SEQPOS := 0;
  SEQSEC := 0;
  Result := DIRFIND( NM, SEQSEC, SIZE)
end;

function SEQREAD( DEST: Pointer; LEN: Word): Word;
{ Sector trailer: link-hi, link-lo, bytes used. }
var
  D    : PByte;
  N    : Word;
  CNT  : Byte;
begin
  Result := 0;
  D := DEST;
  while ( LEN > 0) and ( SEQSEC <> 0) do
    begin
      SECREAD( SEQSEC);
      CNT := SECBUF[ 255];
      if SEQPOS >= CNT then
        begin
          SEQSEC := Word( SECBUF[ 253]) shl 8 + SECBUF[ 254];
          SEQPOS := 0
        end
      else
        begin
          N := CNT - SEQPOS;
          if N > LEN then N := LEN;
          Move( SECBUF[ SEQPOS], D^, N);
          Inc( D, N);
          Inc( SEQPOS, N);
          Dec( LEN, N);
          Inc( Result, N)
        end
    end
end;

procedure WRITERANGE( F: Byte; OFS: Cardinal; LEN: Word; SRC: Pointer);
{ Read-modify-write of every touched sector: trailer bytes stay as read. }
var
  REL : Word;
  POS : Byte;
  N   : Word;
  S   : PByte;
begin
  S := SRC;
  FILEPOS( F, OFS, REL, POS);
  while LEN > 0 do
    begin
      FILESEC( F, REL);
      N := SECDATA - POS;
      if N > LEN then N := LEN;
      Move( S^, SECBUF[ POS], N);
      SECWRITE;
      Inc( S, N);
      Dec( LEN, N);
      Inc( REL);
      POS := 0
    end
end;

procedure UNITREAD( BLOCK: SmallInt);
{ 1024 bytes (2 x 512-byte blocks) at block BLOCK of the scenario into IOCACHE. }
begin
  READRANGE( FSCEN, Cardinal( BLOCK) * BLOCKSZ, SizeOf( IOCACHE), @IOCACHE)
end;

procedure UNITWRITE( BLOCK: SmallInt);
begin
  WRITERANGE( FSCEN, Cardinal( BLOCK) * BLOCKSZ, SizeOf( IOCACHE), @IOCACHE)
end;

procedure UNITREAD_BUF( BLOCK: SmallInt; var BUF);
{ One 512-byte block of the scenario into BUF, bypassing IOCACHE (charsets). }
begin
  READRANGE( FSCEN, Cardinal( BLOCK) * BLOCKSZ, BLOCKSZ, @BUF)
end;

procedure UNITREAD_MSG( BLOCK: SmallInt; var BUF);
{ One 512-byte block of the message file into BUF. }
begin
  READRANGE( FMESG, Cardinal( BLOCK) * BLOCKSZ, BLOCKSZ, @BUF)
end;

{ ── GETREC / GETRECW ─────────────────────────────────────────────────────── }

{ AP: BUFFADDR := DATASIZE * ... with the caller's AP record size.  The
  converted file (tools/mkscen.py) stores each section's own record stride
  in SCNTOC.UNUSEDXX, so DATASIZE is ignored. }

function GETREC( DATATYPE: TZSCN; DATAINDX, DATASIZE: SmallInt): SmallInt;
var
  BUFFADDR : SmallInt;
  DSKBLOCK : SmallInt;
begin
  DSKBLOCK := SCNTOC.BLOFF[ DATATYPE] +
              2 * (DATAINDX div SCNTOC.RECPER2BL[ DATATYPE]);
  BUFFADDR := SCNTOC.UNUSEDXX[ DATATYPE] * (DATAINDX mod SCNTOC.RECPER2BL[ DATATYPE]);
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
  BUFFADDR := SCNTOC.UNUSEDXX[ DATATYPE] * (DATAINDX mod SCNTOC.RECPER2BL[ DATATYPE]);
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

function FINDFILE( DRIVE: SmallInt; FILENM: PString): SmallInt;
{ AP: block offset of FILENM on the scenario disk.  Atari: each is its own
  file starting at block 0; -9 if it is not on the disk in drive 1. }
var
  F : Byte;
begin
  FINDFILE := -9;
  if FILENM^ = 'SCENARIO.DATA' then F := FSCEN
  else if FILENM^ = 'SCENARIO.MESGS' then F := FMESG
  else exit;
  FOPEN[ F] := false;            { re-read the directory: disk may have changed }
  SECNUM := 0;
  if FILEFIND( F) then FINDFILE := 0
end;


procedure LOADSCNTOC;
{ IOCACHE holds blocks 0-1 of the converted scenario (tools/mkscen.py):
    0..106   TSCNTOC image       (TSCNTOC_SIZE: SizeOf misreports, bug11)
    112..363 RACE / CLASS / STATUS / ALIGN strings (MP string[n] images)
    448..    'WZA8', version, record sizes the file was built for
  The spell block is block 3. }
const
  SZOFS = SCNHDROFS + 5;
var
  P    : SmallInt;
  OK   : Boolean;

  function SZ( N: Byte): Word;
  begin
    SZ := Byte( IOCACHE[ SZOFS + N * 2]) + Word( Byte( IOCACHE[ SZOFS + N * 2 + 1])) shl 8
  end;

begin
  OK := ( IOCACHE[ SCNHDROFS] = 'W') and ( IOCACHE[ SCNHDROFS + 1] = 'Z') and
        ( IOCACHE[ SCNHDROFS + 2] = 'A') and ( IOCACHE[ SCNHDROFS + 3] = '8') and
        ( Byte( IOCACHE[ SCNHDROFS + 4]) = SCNVERSION) and
        ( SZ( 0) = SizeOf( TCHAR))     and ( SZ( 1) = SizeOf( TOBJREC)) and
        ( SZ( 2) = SizeOf( TENEMY))    and ( SZ( 3) = SizeOf( TMAZE))   and
        ( SZ( 4) = SizeOf( TSPELBLK))  and ( SZ( 5) = TSCNTOC_SIZE)     and
        ( SZ( 6) = SizeOf( TPOSSESS))  and ( SZ( 7) = SizeOf( THPREC))  and
        ( SZ( 8) = SizeOf( TENMYCALC)) and ( SZ( 9) = SizeOf( TWIZLONG));
  if not OK then
    begin
      WriteLn( 'SCENARIO.DAT DOES NOT MATCH THIS BUILD');
      WriteLn( '(RERUN TOOLS/MKSCEN.PY)');
      repeat until False
    end;

  { Variable indexes: MP can't take the address of an absolute array
    element at a constant index. }
  P := 0;
  Move( IOCACHE[ P], SCNTOC, TSCNTOC_SIZE);
  SCNTOC.SPELLS := @SPELBLK_DATA;
  { The file stores the name strings exactly as GLOBALS.SCNNAMES holds them. }
  P := 112;
  Move( IOCACHE[ P], SCNNAMES, SCNNAMESZ);
  READRANGE( FSCEN, Cardinal( SCNTOCBL + 3) * BLOCKSZ, SizeOf( TSPELBLK), @SPELBLK_DATA)
end;

{ ── Static wiring of record pointer fields ───────────────────────────────── }

procedure SETPOSS( PC: PTCHAR; A: Word);
{ Point POSS.POSSESS[0..8] at consecutive TPOSSESS starting at A. }
var
  I : Byte;
begin
  for I := 0 to 8 do
    begin
      PC.POSS.POSSESS[ I] := Pointer( A);
      Inc( A, SizeOf( TPOSSESS))
    end
end;

procedure WIRECHAR( var C: TCHAR; var SKN: TSPELLSKN; var POSS: TPOSSBLK);
var
  PC : PTCHAR;
begin
  PC := @C;
  PC^.SPELLSKN := @SKN;
  SETPOSS( PC, Word( @POSS))
end;

procedure CLEARCHAR( var C: TCHAR);
var
  PC  : PTCHAR;
  SKN : PTSPELLSKN;
  P0  : PByte;
begin
  PC  := @C;
  SKN := PC^.SPELLSKN;
  P0  := PByte( PC.POSS.POSSESS[ 0]);
  FillChar( C, SizeOf( TCHAR), 0);
  PC^.SPELLSKN := SKN;
  SETPOSS( PC, Word( P0));
  FillChar( SKN^, SizeOf( TSPELLSKN), 0);
  FillChar( P0^, SizeOf( TPOSSBLK), 0)
end;

procedure COPYCHAR( var DST: TCHAR; var SRC: TCHAR);
{ AP copies TCHAR by value; here the pointed-to spell and possession data
  is copied too, so DST never shares SRC's storage. }
var
  PD, PS     : PTCHAR;
  DSKN, SSKN : PTSPELLSKN;
  D0, S0     : PByte;
begin
  PD   := @DST;
  PS   := @SRC;
  DSKN := PD^.SPELLSKN;
  D0   := PByte( PD.POSS.POSSESS[ 0]);
  SSKN := PS^.SPELLSKN;
  S0   := PByte( PS.POSS.POSSESS[ 0]);
  Move( SRC, DST, SizeOf( TCHAR));
  PD^.SPELLSKN := DSKN;
  SETPOSS( PD, Word( D0));
  Move( SSKN^, DSKN^, SizeOf( TSPELLSKN));   { not PS.SPELLSKN^: mpbugs/bug10 }
  Move( S0^, D0^, SizeOf( TPOSSBLK))
end;

procedure WIREMAZE( var M: TMAZE; var W, S, E, N: TMAZEMAP; var FIGHTS: TFIGHTMAP;
                    var SQREXTRA: TSQRMAP; var EC: TECBLK);
var
  PM : ^TMAZE;
  I  : Byte;
  A  : Word;
begin
  PM := @M;
  PM.W        := @W;
  PM^.S        := @S;
  PM^.E        := @E;
  PM^.N        := @N;
  PM.FIGHTS   := @FIGHTS;
  PM.SQREXTRA := @SQREXTRA;
  A := Word( @EC);
  for I := 0 to 3 do
    begin
      PM.ENMYCALC[ I] := Pointer( A);
      Inc( A, SizeOf( TENMYCALC))
    end
end;

procedure SETRECS( PE: Pointer; A: Word);
{ Point TENEMY.RECS[0..7] at consecutive THPREC starting at A. }
var
  P : ^TENEMY;
  I : Byte;
begin
  P := PE;
  for I := 0 to 7 do
    begin
      P.RECS[ I] := Pointer( A);
      Inc( A, SizeOf( THPREC))
    end
end;

procedure WIREENEMY( var ENM: TENEMY; var RECS: TRECSBLK);
begin
  SETRECS( @ENM, Word( @RECS))
end;

procedure WIREEXP( var EXP: TEXP; var BLK: TEXPBLK);
var
  I : Byte;
  A : Word;
begin
  A := Word( @BLK);
  for I := 0 to 103 do
    begin
      EXP[ I] := Pointer( A);
      Inc( A, SizeOf( TWIZLONG))
    end
end;


{ ── Record loaders ───────────────────────────────────────────────────────── }

{ The converted scenario (tools/mkscen.py) holds each record as its Mad
  Pascal memory image followed by the blocks its pointer fields are wired
  to, so loading is a few Moves.  Pointer slots read from disk are
  meaningless: each loader saves the record's wiring first and restores it.
  Native record layout (offsets from the record start):
    TCHAR   0 fixed (SizeOf TCHAR) | SPELLSKN 50 | POSSESS[0..8] block
    TENEMY  0 fixed (SizeOf TENEMY) | RECS[0..7] block
    TOBJREC 0 fixed
    maze    W, S, E, N, FIGHTS, SQREXTRA (400 each) | TMAZE | ENMYCALC block }

const
  MZ_FIXED = 6 * 400;                        { TMAZE after the six maps }
  MZ_EC    = MZ_FIXED + SizeOf( TMAZE);      { then ENMYCALC[0..3] }

function MAZEOFS( LEVEL: SmallInt): Cardinal;
begin
  MAZEOFS := Cardinal( SCNTOCBL + SCNTOC.BLOFF[ ZMAZE]) * BLOCKSZ +
             Cardinal( LEVEL) * Word( SCNTOC.UNUSEDXX[ ZMAZE])
end;

procedure LOADTMAZE( LEVEL: SmallInt; var MAZE: TMAZE);
{ Maze levels (2572 bytes) are larger than IOCACHE, so they are read
  straight from the file into the wired maps. }
var
  PM             : ^TMAZE;
  PW, PS, PE, PN : ^TMAZEMAP;
  PF             : ^TFIGHTMAP;
  PX             : ^TSQRMAP;
  EC0            : PByte;
  EC             : ^TENMYCALC;
  BASE           : Cardinal;
  I              : Byte;
begin
  PM := @MAZE;                    { MAZE must already be wired (WIREMAZE) }
  PW := PM.W; PS := PM^.S; PE := PM^.E; PN := PM^.N;
  PF := PM.FIGHTS; PX := PM.SQREXTRA;
  EC0 := PByte( PM.ENMYCALC[ 0]);
  BASE := MAZEOFS( LEVEL);
  READRANGE( FSCEN, BASE,        400, PW);
  READRANGE( FSCEN, BASE +  400, 400, PS);
  READRANGE( FSCEN, BASE +  800, 400, PE);
  READRANGE( FSCEN, BASE + 1200, 400, PN);
  READRANGE( FSCEN, BASE + 1600, 400, PF);
  READRANGE( FSCEN, BASE + 2000, 400, PX);
  READRANGE( FSCEN, BASE + MZ_FIXED, SizeOf( TMAZE), PM);
  READRANGE( FSCEN, BASE + MZ_EC, SizeOf( TECBLK), EC0);
  PM.W := PW; PM^.S := PS; PM^.E := PE; PM^.N := PN;      { restore the wiring }
  PM.FIGHTS := PF; PM.SQREXTRA := PX;
  for I := 0 to 3 do
    begin
      EC := Pointer( Word( EC0) + I * SizeOf( TENMYCALC));
      PM.ENMYCALC[ I] := EC
    end
end;

procedure SAVETMAZE( LEVEL: SmallInt; var MAZE: TMAZE);
{ AP wrote back only SQRETYPE / AUX0-2 (the fields changed at runtime);
  they all live in the TMAZE part, written straight to the file. }
begin
  WRITERANGE( FSCEN, MAZEOFS( LEVEL) + MZ_FIXED, SizeOf( TMAZE), @MAZE)
end;

procedure LOADTCHAR( INDEX: SmallInt; var CH: TCHAR);
var
  B   : SmallInt;
  TC  : PTCHAR;
  SKN : PTSPELLSKN;
  P0  : PByte;
begin
  B   := GETREC( ZCHAR, INDEX, 0);
  TC  := @CH;                     { CH must already be wired (WIRECHAR) }
  SKN := TC^.SPELLSKN;
  P0  := PByte( TC.POSS.POSSESS[ 0]);
  Move( IOCACHE[ B], CH, SizeOf( TCHAR));
  TC^.SPELLSKN := SKN;
  SETPOSS( TC, Word( P0));
  Move( IOCACHE[ B + SizeOf( TCHAR)], SKN^, SizeOf( TSPELLSKN));
  Move( IOCACHE[ B + SizeOf( TCHAR) + SizeOf( TSPELLSKN)], P0^, SizeOf( TPOSSBLK))
end;

procedure SAVETCHAR( INDEX: SmallInt; var CH: TCHAR);
var
  B   : SmallInt;
  TC  : PTCHAR;
  SKN : PTSPELLSKN;
  P0  : PByte;
begin
  B   := GETRECW( ZCHAR, INDEX, 0);
  TC  := @CH;
  SKN := TC^.SPELLSKN;
  P0  := PByte( TC.POSS.POSSESS[ 0]);
  Move( CH, IOCACHE[ B], SizeOf( TCHAR));
  Move( SKN^, IOCACHE[ B + SizeOf( TCHAR)], SizeOf( TSPELLSKN));
  Move( P0^, IOCACHE[ B + SizeOf( TCHAR) + SizeOf( TSPELLSKN)], SizeOf( TPOSSBLK))
end;

procedure LOADOBJREC( INDEX: SmallInt; var OBJ: TOBJREC);
begin
  Move( IOCACHE[ GETREC( ZOBJECT, INDEX, 0)], OBJ, SizeOf( TOBJREC))
end;

procedure SAVEOBJREC( INDEX: SmallInt; var OBJ: TOBJREC);
begin
  Move( OBJ, IOCACHE[ GETRECW( ZOBJECT, INDEX, 0)], SizeOf( TOBJREC))
end;

procedure LOADENEMY( INDEX: SmallInt; var ENM: TENEMY);
var
  B  : SmallInt;
  R0 : PByte;
begin
  B  := GETREC( ZENEMY, INDEX, 0);
  R0 := PByte( ENM.RECS[ 0]);     { ENM must already be wired (WIREENEMY) }
  Move( IOCACHE[ B], ENM, SizeOf( TENEMY));
  SETRECS( @ENM, Word( R0));
  Move( IOCACHE[ B + SizeOf( TENEMY)], R0^, SizeOf( TRECSBLK))
end;

procedure LOADTEXP( var EXP: TEXP);
{ 104 x TWIZLONG, Ord(CLASS)*13 + LEVEL; AP order LOW,MID,HIGH = XLOW..XHIGH. }
var
  PE : PByte;
begin
  PE := PByte( EXP[ 0]);          { EXP must already be wired (WIREEXP) }
  Move( IOCACHE[ GETREC( ZEXP, 0, 0)], PE^, SizeOf( TEXPBLK))
end;

end.
