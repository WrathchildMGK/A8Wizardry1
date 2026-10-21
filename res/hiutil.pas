unit HIUTIL;

{ Wizardry I — utility routines that need no DOS: TWIZLONG arithmetic,
  keyboard input, drawing and timing (AP WIZ2.TEXT, wiz1d/).  Part of the
  high resident WIZHI, under the OS ROM; overlays reach them through
  imp/util.pas.  Disk-side utilities are in LOUTIL (low resident). }

interface

uses TYPES, CONSTS, GLOBALS, SCREEN;

{ TWIZLONG arithmetic (P010005-P01000B, WIZ2.TEXT) }
procedure ADDLONGS ( var FIRST: TWIZLONG; var SECOND: TWIZLONG);
procedure SUBLONGS ( var FIRST: TWIZLONG; var SECOND: TWIZLONG);
function  TESTLONG( FIRST, SECOND: TWIZLONG): SmallInt;
procedure MULTLONG( var LONGNUM: TWIZLONG; INTNUM: SmallInt);
procedure DIVLONG ( var LONGNUM: TWIZLONG; INTNUM: SmallInt);
procedure LONG2BCD( LONGNUM: TWIZLONG; var BCDNUM: TBCD);
procedure BCD2LONG( var LONGNUM: TWIZLONG; BCDNUM: TBCD);
procedure PRNTLONG( LONGNUM: TWIZLONG);
procedure POOLALLG( CHAR4GLD: SmallInt);     { v3.2 WC040: all party gold to one }

{ Input (P01000D-P01000F) }
procedure GETKEY;
procedure UNITCLEAR( UNITNUM: SmallInt);     { 1 = console: drop type-ahead }
procedure GETLINE;
procedure GETSTR  ( var ASTRING: string; WINXPOS, WINYPOS: SmallInt);
{ PString, not string: an overlay calling an external routine with a string
  among other parameters copies it into the callee's buffer, whose address
  never reaches the MADS header; a PString is just passed. }
function  GETCHARX( DSPNAMES: Boolean; SOLICIT: PString): SmallInt;

{ Display (P010016-P010018, wiz1d/).  PRINTCHR and CLRRECT are in SCREEN. }
procedure MVCURSOR( X, Y: SmallInt);
procedure PRINTSTR( ASTRING: string);
procedure PRINTNUM( ANUM, FIELDSZ: SmallInt);
procedure CENTSTR ( ASTRING: string);
{ AP "WRITE( X: N)": Mad Pascal ignores field widths, so a width is written
  as SPACES( N - Length( S)) + Write( S), or WRITEINT for integers.  The
  width is a minimum (leading spaces), never a truncation. }
procedure SPACES  ( N: SmallInt);
procedure WRITEINT( N, W: SmallInt);
procedure TEXTMODE;
procedure GRAPHICS;
procedure CLEARPIC;
procedure CLRPICT  ( X1, Y1, X2, Y2: SmallInt);
procedure DRAWLINE ( X, Y, DX, DY, LEN: SmallInt);
procedure PICTOSCR ( BUFI: SmallInt);        { AP ENEMYPIC / PIC2SCRN }
procedure PRINTBEL;

{ Timing }
procedure PAUSE1;
procedure PAUSE2;

implementation

{ ── TWIZLONG arithmetic ──────────────────────────────────────────────────── }

procedure ADDLONGS( var FIRST: TWIZLONG; var SECOND: TWIZLONG);
{ v3.2 WC025: SECOND is a value parameter, so ADDLONGS( X, X) doubles X
  instead of feeding the partial sum back in.  Its fields are copied first
  (a record value parameter across the resident boundary is not trusted). }
var
  SLOW, SMID, SHIGH : SmallInt;
begin
  SLOW  := SECOND.XLOW;
  SMID  := SECOND.XMID;
  SHIGH := SECOND.XHIGH;
  FIRST.XLOW := FIRST.XLOW + SLOW;
  if FIRST.XLOW >= 10000 then
    begin
      FIRST.XMID := FIRST.XMID + 1;
      FIRST.XLOW := FIRST.XLOW - 10000
    end;
  FIRST.XMID := FIRST.XMID + SMID;
  if FIRST.XMID >= 10000 then
    begin
      FIRST.XHIGH := FIRST.XHIGH + 1;
      FIRST.XMID  := FIRST.XMID - 10000
    end;
  FIRST.XHIGH := FIRST.XHIGH + SHIGH;
  if FIRST.XHIGH >= 10000 then
    begin
      FIRST.XHIGH := 9999;
      FIRST.XMID  := 9999;
      FIRST.XLOW  := 9999
    end
end;

procedure SUBLONGS( var FIRST: TWIZLONG; var SECOND: TWIZLONG);
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
{ AP: a nested BCD2INT( var LONGPART) doing LONGPART := 10 * LONGPART +
  BCDNUM[ DIGITX].  MP 1.7.9 loads the index into Y and then overwrites
  it for the store through LONGPART (tay; ldy #$00), so it always added
  BCDNUM[ 0] = 0 and every MULTLONG / DIVLONG gave 0 (mpbugs/bug17).
  Four digits at a time into a local instead. }
var
  DIGITX : SmallInt;
  PART   : SmallInt;
  D      : SmallInt;
  K      : Byte;
begin
  DIGITX := 1;
  for K := 0 to 2 do
    begin
      PART := 0;
      for D := 1 to 4 do
        begin
          PART   := 10 * PART + BCDNUM[ DIGITX];
          DIGITX := DIGITX + 1
        end;
      case K of
        0: LONGNUM.XHIGH := PART;
        1: LONGNUM.XMID  := PART;
        2: LONGNUM.XLOW  := PART
      end
    end
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

procedure POOLALLG( CHAR4GLD: SmallInt);
var
  I      : SmallInt;
  TG, TC : PTCHAR;
begin
  TG := CHARACTR[ CHAR4GLD];
  for I := 0 to PARTYCNT - 1 do
    if I <> CHAR4GLD then
      begin
        TC := CHARACTR[ I];
        ADDLONGS( TG.GOLD, TC.GOLD);
        TC.GOLD.XHIGH := 0;
        TC.GOLD.XMID  := 0;
        TC.GOLD.XLOW  := 0
      end
end;

{ ── Input stubs ──────────────────────────────────────────────────────────── }

procedure GETKEY;
begin
  { AP: MVCURSOR(80,0) = spin-wait, ticking the RNG, until a key is available.
    Atari: POKEY RANDOM needs no ticking; ReadKey returns the Apple code. }
  INCHAR := ReadKey
end;

procedure UNITCLEAR( UNITNUM: SmallInt);
begin
  if UNITNUM = 1 then Poke( $02FC, $FF)          { CH: no key }
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
        if IPOS < 22 then IPOS := IPOS + 1;      { v3.2 WC039: overflow crash }
        ASTRING[ IPOS] := INCHAR
      end
  until INCHAR = Chr( CRETURN);
  ASTRING[ 0] := Chr( IPOS)
end;

function GETCHARX( DSPNAMES: Boolean; SOLICIT: PString): SmallInt;
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
    Write( SOLICIT^);
    Write( ' ([RETURN] EXITS) >');
    GETKEY;
    LLBASE04 := Ord( INCHAR) - Ord( '0')
  until ((LLBASE04 > 0) and (LLBASE04 <= PARTYCNT)) or (INCHAR = Chr( 13));
  if INCHAR = Chr( CRETURN) then LLBASE04 := 0;
  GETCHARX := LLBASE04 - 1
end;

{ ── Display (on the SCREEN console) ─────────────────────────────────────── }

procedure TEXTMODE;
begin
  SHOWTEXT
end;

procedure GRAPHICS;
begin
  SHOWGRAPH
end;

procedure MVCURSOR( X, Y: SmallInt);
{ AP special X values: 40=GRAPHICS, 50=TEXTMODE, 60-79=copy-protect (skip),
  80=wait-for-key RNG tick (handled inside GETKEY).  Otherwise it moves the
  graphics cursor (PRINTCHR), not the text cursor (GotoXY). }
begin
  if X = 40 then begin GRAPHICS; exit end;
  if X = 50 then begin TEXTMODE; exit end;
  if X >= 60 then exit;
  GMOVE( X, Y)
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


procedure SPACES( N: SmallInt);
begin
  while N > 0 do
    begin
      Write( ' ');
      Dec( N)
    end
end;


procedure WRITEINT( N, W: SmallInt);
var
  T, D : SmallInt;
begin
  D := 1;
  T := N;
  if T < 0 then
    begin
      Inc( D);
      T := -T
    end;
  while T >= 10 do
    begin
      T := T div 10;
      Inc( D)
    end;
  SPACES( W - D);
  Write( N)
end;


procedure CENTSTR( ASTRING: string);
begin
  GotoXY( 20 - (Length( ASTRING) div 2), 23);
  Write( ASTRING);
  GotoXY( 41, 0);
  PAUSE2
end;


{ ── The picture (maze view / portraits) ──────────────────────────────────
  AP: 82 x 79 hi-res pixels, columns 4..85 and lines 5..83 (CLRPICT.TEXT,
  DRAWLINE.TEXT), filling the frame exactly: its borders are hi-res columns
  0..3 and 86.., which CLRPICT leaves alone.  Here the frame's borders are
  mode E pixels 3 and 50 (lines 4 and 84), so the picture is pixels 4..49
  of lines 5..83: 46 pixels for the Apple's 82 (an Apple text cell is 7
  hi-res pixels, one here 4).  A 70-pixel portrait at hi-res bytes 1..10 is
  40 pixels at mode E bytes 1..10. }

const
  PICLINE0 = 5;                              { first screen line of the picture }
  PICLINES = 79;
  PXTAB : array[ 0..81] of Byte = (          { picture X -> mode E pixel: 4 + X * 46 div 82 }
     4,  4,  5,  5,  6,  6,  7,  7,  8,  9,  9, 10, 10, 11, 11, 12, 12, 13, 14, 14,
    15, 15, 16, 16, 17, 18, 18, 19, 19, 20, 20, 21, 21, 22, 23, 23, 24, 24, 25, 25,
    26, 27, 27, 28, 28, 29, 29, 30, 30, 31, 32, 32, 33, 33, 34, 34, 35, 35, 36, 37,
    37, 38, 38, 39, 39, 40, 41, 41, 42, 42, 43, 43, 44, 44, 45, 46, 46, 47, 47, 48,
    48, 49);
  PXMASK : array[ 0..3] of Byte = ( $C0, $30, $0C, $03 );   { colour 3, leftmost first }

var
  CLIPX1, CLIPY1, CLIPX2, CLIPY2 : SmallInt;  { AP $BFF9..$BFFC: DRAWLINE's rectangle }


procedure CLEARPIC;
{ AP P010013 = CLRPICT( 0, 0, 0, 100): clear the picture only (mode E
  pixels 4..49 of lines 5..83), not the frame round it. }
var
  L : Byte;
  P : PByte;
begin
  P := Pointer( SCRADR + PICLINE0 * SCRWIDTH + 1);
  for L := 1 to PICLINES do
    begin
      FillChar( P^, 11, 0);                      { pixels 4..47 }
      Inc( P, 11);
      P^ := P^ and $0F;                          { pixels 48, 49; keep the border at 50 }
      Inc( P, SCRWIDTH - 11)
    end
end;


procedure CLRPICT( X1, Y1, X2, Y2: SmallInt);
{ AP: Y2 = 100 clears the picture; otherwise (X1,Y1)-(X2,Y2) is the
  rectangle DRAWLINE may draw in, bounds included.  (101 is unused.) }
begin
  if Y2 = 100 then
    CLEARPIC
  else if Y2 <> 101 then
    begin
      CLIPX1 := X1;
      CLIPY1 := Y1;
      CLIPX2 := X2;
      CLIPY2 := Y2
    end
end;


procedure DRAWLINE( X, Y, DX, DY, LEN: SmallInt);
{ AP: LEN pixels from picture point (X,Y), stepping (DX,DY); only those
  inside the CLRPICT rectangle (and the picture) are set, in colour 3. }
var
  I : SmallInt;
  A : Byte;
  P : PByte;
begin
  for I := 1 to LEN do
    begin
      if ( X >= CLIPX1) and ( X <= CLIPX2) and ( Y >= CLIPY1) and ( Y <= CLIPY2) and
         ( X >= 0) and ( X <= 81) and ( Y >= 0) and ( Y < PICLINES) then
        begin
          A  := PXTAB[ X];
          P  := Pointer( SCRADR + Word( Y + PICLINE0) * SCRWIDTH + ( A shr 2));
          A  := PXMASK[ A and 3];
          P^ := P^ or A
        end;
      X := X + DX;
      Y := Y + DY
    end
end;


procedure PICTOSCR( BUFI: SmallInt);
{ AP ENEMYPIC (COMBAT) / PIC2SCRN (REWARDS): clear the picture, then a
  portrait from IOCACHE[ BUFI]: 50 rows of 10 mode E bytes (made by
  tools/gen_atari_portraits.py) at bytes 1..10 of lines 23..72.  Bytes
  500/501 are its two hues, for pixel values 1 and 2: the callers set
  COLOR0/COLOR1 from them (no room here). }
var
  L : Byte;
  P : PByte;
begin
  CLEARPIC;
  P := Pointer( SCRADR + 23 * SCRWIDTH + 1);
  for L := 0 to 49 do
    begin
      Move( IOCACHE[ BUFI], P^, 10);
      Inc( BUFI, 10);
      Inc( P, SCRWIDTH)
    end
end;


procedure PRINTBEL;
begin
  { AP: three bell characters.  Atari: write to POKEY AUDCTL/AUDF if wired;
    for now a no-op to avoid corrupting Mode E screen via Write(). }
end;

{ ── Timing ───────────────────────────────────────────────────────────────── }

{ AP: empty FOR loops timed by the p-code interpreter (TIMEDLAY 2000 ~ 1 s).
  Compiled 6502 code runs them in a frame or two, so wait for frames on
  RTCLOK ($14, kept by WIZHI's VBI): 32 loop units per frame. }
procedure WAITFRMS( N: Word);
var
  T : Byte;
begin
  while N > 0 do
    begin
      T := Peek( $14);
      repeat until Peek( $14) <> T;
      Dec( N)
    end
end;

procedure PAUSE1;
begin
  if TIMEDLAY > 0 then WAITFRMS( Word( TIMEDLAY) shr 5)
end;

procedure PAUSE2;
begin
  WAITFRMS( 3000 shr 5)
end;

end.
