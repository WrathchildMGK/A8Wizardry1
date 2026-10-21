unit SCREEN;

{ Console for the game: replaces Mad Pascal's crt, which needs the OS ROM
  (the game runs with it switched out).  Lives in the high resident
  (WIZHI, under the OS); overlays reach it through imp/screen.pas.

  Two pages, as on the Apple:
    text page      ANTIC mode 4, 40x24 characters of 4x8 four-colour
                   pixels (the Apple text screen).  Write/WriteLn arrive
                   here through PUTCH, hooked into the IOCB 0 put-byte
                   vector; GotoXY moves its cursor.
    graphics page  ANTIC mode E, 160x192 (the Apple hi-res screen).
                   PRINTCHR draws a glyph of the current CHARSET at the
                   graphics cursor (GMOVE = AP MVCURSOR); CLRRECT clears.
  SHOWTEXT / SHOWGRAPH pick the one displayed (AP TEXTMODE / GRAPHICS).
  Both have the same pixel shape, so a glyph looks the same on either.

  Apple Pascal console codes are honoured on the text page:
    12 clear screen + home    11 clear to end of screen
    29 clear to end of line   13 / $9B new line    8 backspace    7 bell
  ReadKey returns Apple codes: RETURN 13, ESC 27, backspace 8, letters
  upper case.

  Everything ANTIC reads sits in main RAM, because ANTIC sees ROM, not the
  RAM under it, while the OS is switched in for disk access: the text page
  at $0800..$0FFF (LiteDOS's memory, unused once WIZHI is loaded), the
  graphics page at $A010.. with its display list at $BE10.  Row 102 of the
  graphics page starts exactly at $B000, where ANTIC needs a fresh LMS. }

interface

uses TYPES, CONSTS, GLOBALS;

const
  SCRWIDTH = 40;                  { mode E bytes per scanline }
  CHARCOLS = 40;
  CHARROWS = 24;
  SCRADR   = $A010;               { graphics page }
  DLADR    = $BE10;
  TXTFONT  = $0800;               { text page: 1K font (64 glyphs used), }
  TXTADR   = $0C00;               {   960-byte screen,                   }
  TXTDL    = $0FC0;               {   display list                       }

var
  SCRNBUF : array[ 0..7679] of Byte absolute SCRADR;

procedure SCRINIT;                { both pages, colours, PUTCH hook; shows text }
procedure TEXTFONT;               { text-page font from CHARSET (call with block 1) }
procedure SHOWTEXT;
procedure SHOWGRAPH;
procedure GotoXY( X, Y: Byte);    { text cursor }
function  WhereX: Byte;
function  WhereY: Byte;
procedure ClrScr;
procedure GMOVE( X, Y: Byte);     { graphics cursor }
procedure PRINTCHR( ACHAR: Char); { one glyph at the graphics cursor, advancing it }
procedure CLRRECT( X, Y, W, H: SmallInt);   { clear W x H cells of the graphics page }
function  KeyPressed: Boolean;
function  ReadKey: Char;
procedure Delay( MS: Word);

implementation

const
  CH     = $02FC;                 { OS last-key register (our IRQ fills it) }
  RTCLOK = $14;
  TXTSIZE = CHARCOLS * CHARROWS;

  { Keyboard code -> Apple code; 0 = ignored.  Index bits 0-5 = key,
    bit 6 = SHIFT (CTRL keys are not used by the game). }
  KEYTAB : array[ 0..127] of Byte = (
    { $00 } 76, 74, 59,  0,  0, 75, 43, 42, 79,  0, 80, 85, 13, 73, 45, 61,
    { $10 } 86,  0, 67,  0,  0, 66, 88, 90, 52,  0, 51, 54, 27, 53, 50, 49,
    { $20 } 44, 32, 46, 78,  0, 77, 47,  0, 82,  0, 69, 89,  0, 84, 87, 81,
    { $30 } 57,  0, 48, 55,  8, 56, 60, 62, 70, 72, 68,  0,  0, 71, 83, 65,
    { $40 } 76, 74, 58,  0,  0, 75, 92, 94, 79,  0, 80, 85, 13, 73, 95,124,
    { $50 } 86,  0, 67,  0,  0, 66, 88, 90, 36,  0, 35, 38, 27, 37, 34, 33,
    { $60 } 91, 32, 93, 78,  0, 77, 63,  0, 82,  0, 69, 89,  0, 84, 87, 81,
    { $70 } 40,  0, 41, 39,  8, 64,  0,  0, 70, 72, 68,  0,  0, 71, 83, 65);

var
  TX, TY       : Byte;                     { text cursor }
  TOFF         : Boolean;                  { parked off the page (GotoXY X >= 40) }
  GX, GY       : Byte;                     { graphics cursor (may be off-page) }
  ROWLO, ROWHI : array[ 0..CHARROWS - 1] of Byte;
  CHRTAB       : array[ 0..255] of Byte;   { glyph byte (1bpp) -> 4-pixel byte }
  PUTC         : Byte;                     { char handed over by PUTCH }
  SAVEZP       : array[ 0..$53] of Byte;   { MP zero page $80..$D3 }
  DLP          : Word;


{ ── Text page ────────────────────────────────────────────────────────────── }

function TCELL( X, Y: Byte): Word;
begin
  TCELL := TXTADR + Word( Y) * CHARCOLS + X
end;

procedure TCLRROWS( Y: Byte);
{ Clear text rows Y..23. }
var
  P : PByte;
begin
  if Y < CHARROWS then
    begin
      P := Pointer( TCELL( 0, Y));
      FillChar( P^, Word( CHARROWS - Y) * CHARCOLS, 0)
    end
end;

procedure TCLREOL;
{ Clear from the cursor to the end of its row (TX may be past the end). }
var
  P : PByte;
begin
  if TX < CHARCOLS then
    begin
      P := Pointer( TCELL( TX, TY));
      FillChar( P^, CHARCOLS - TX, 0)
    end
end;

procedure TNEWLINE;
var
  SRC, DST : PByte;
begin
  TX := 0;
  TOFF := false;
  if TY < CHARROWS - 1 then
    Inc( TY)
  else
    begin
      SRC := Pointer( TXTADR + CHARCOLS);           { scroll up one row }
      DST := Pointer( TXTADR);
      Move( SRC^, DST^, TXTSIZE - CHARCOLS);
      TCLRROWS( CHARROWS - 1)
    end
end;

procedure TPUT( C: Byte);
{ Apple character C (32..95) at the text cursor.  The wrap after column
  39 is deferred to the next character (as on the Apple), so a full
  40-character line followed by WriteLn gives one new line, not two. }
begin
  if TOFF then exit;
  if TX >= CHARCOLS then TNEWLINE;
  Poke( TCELL( TX, TY), C - 32);
  Inc( TX)
end;

procedure PUTCHP; keep;
{ The console proper, for the character in PUTC ("keep": only PUTCH calls it). }
var
  C : Byte;
begin
  C := PUTC;
  case C of
    12:       begin TCLRROWS( 0); TX := 0; TY := 0; TOFF := false end;
    11:       begin TCLREOL; TCLRROWS( TY + 1) end;
    29:       TCLREOL;
    13, $9B:  TNEWLINE;
    8:        if TX > 0 then Dec( TX);
  else
    begin
      C := C and $7F;
      if C >= 96 then Dec( C, 32);         { lower case -> upper }
      if C >= 32 then TPUT( C)
    end
  end
end;

procedure PUTCH; assembler;
{ IOCB 0 put-byte replacement: A = character, returns Y = 1.  MP's print
  routines keep pointers in zero page across each call, so the whole MP
  zero page is saved around the Pascal console code. }
asm
	sta PUTC
	ldx #$53
sv	lda $80,x
	sta adr.SAVEZP,x
	dex
	bpl sv
	ldx #$FF
	jsr PUTCHP
	ldx #$53
rs	lda adr.SAVEZP,x
	sta $80,x
	dex
	bpl rs
	ldy #1
end;

procedure GotoXY( X, Y: Byte);
{ AP GOTOXY( 41, 0) parks the cursor in the unseen right half of Apple
  Pascal's 80-column screen: characters written there are not shown. }
begin
  TOFF := X >= CHARCOLS;
  if not TOFF then TX := X;
  if Y < CHARROWS then TY := Y
end;

function WhereX: Byte;
begin
  WhereX := TX
end;

function WhereY: Byte;
begin
  WhereY := TY
end;

procedure ClrScr;
begin
  TCLRROWS( 0);
  TX := 0;
  TY := 0;
  TOFF := false
end;

procedure TEXTFONT;
{ The 64 glyphs of CHARSET (ASCII 32..95), each row through CHRTAB. }
var
  G, P : PByte;
  I    : Word;
  B    : Byte;
begin
  G := @CHARSET;
  P := Pointer( TXTFONT);
  for I := 0 to 64 * 8 - 1 do
    begin
      B := G^;                    { "P^ := CHRTAB[ G^]" is miscompiled by MP 1.7.9 }
      P^ := CHRTAB[ B];
      Inc( G);
      Inc( P)
    end
end;


{ ── Graphics page ────────────────────────────────────────────────────────── }

function CELL( X, Y: Byte): Word;
begin
  CELL := ( ROWLO[ Y] or ( Word( ROWHI[ Y]) shl 8)) + X
end;

procedure CLRCELLS( X, Y, N: Byte);
{ Clear N cells from (X,Y) on one text row. }
var
  P : PByte;
  R : Byte;
begin
  P := Pointer( CELL( X, Y));
  for R := 0 to 7 do
    begin
      FillChar( P^, N, 0);
      Inc( P, SCRWIDTH)
    end
end;

procedure GMOVE( X, Y: Byte);
begin
  GX := X;
  GY := Y
end;

procedure PRINTCHR( ACHAR: Char);
{ AP PRGRCHR: glyph ACHAR of CHARSET at the graphics cursor, which then
  moves right; no console codes, no wrap (off the page: not drawn). }
var
  G, P : PByte;
  R, B : Byte;
begin
  B := Ord( ACHAR) and $7F;
  if B >= 96 then Dec( B, 32);
  if ( B >= 32) and ( GX < CHARCOLS) and ( GY < CHARROWS) then
    begin
      G := Pointer( Word( @CHARSET) + Word( B - 32) * 8);
      P := Pointer( CELL( GX, GY));
      for R := 0 to 7 do
        begin
          B := G^;                { "P^ := CHRTAB[ G^]" is miscompiled by MP 1.7.9 }
          P^ := CHRTAB[ B];
          Inc( G);
          Inc( P, SCRWIDTH)
        end
    end;
  Inc( GX)
end;

procedure CLRRECT( X, Y, W, H: SmallInt);
var
  R, LAST : SmallInt;
begin
  if X + W > CHARCOLS then W := CHARCOLS - X;
  LAST := Y + H - 1;            { not "to Y + H - 1": MP 1.7.9 emits a bad label }
  if ( W > 0) and ( X >= 0) then
    for R := Y to LAST do
      if ( R >= 0) and ( R < CHARROWS) then CLRCELLS( X, R, W)
end;


{ ── Setup ────────────────────────────────────────────────────────────────── }

procedure SHOWTEXT;
begin
  Poke( $0230, Lo( TXTDL));
  Poke( $0231, Hi( TXTDL))
end;

procedure SHOWGRAPH;
begin
  Poke( $0230, Lo( DLADR));
  Poke( $0231, Hi( DLADR))
end;

procedure DLB( B: Byte);
begin
  Poke( DLP, B);
  Inc( DLP)
end;

procedure SCRINIT;
var
  I : Byte;
  A : Word;
  J : Word;
  P : PByte;
begin
  for J := 0 to 255 do
    begin
      I := 0;                               { Apple LSB = leftmost pixel; }
      if J and 1 <> 0 then I := I or $C0;   { 4 low bits -> 4 pixels of   }
      if J and 2 <> 0 then I := I or $30;   { colour 3 (mode E and 4)     }
      if J and 4 <> 0 then I := I or $0C;
      if J and 8 <> 0 then I := I or $03;
      CHRTAB[ J] := I
    end;
  for I := 0 to CHARROWS - 1 do
    begin
      A := SCRADR + Word( I) * 8 * SCRWIDTH;
      ROWLO[ I] := Lo( A);
      ROWHI[ I] := Hi( A)
    end;

  DLP := DLADR;                                 { graphics: mode E }
  DLB( $70); DLB( $70); DLB( $70);
  DLB( $4E); DLB( Lo( SCRADR)); DLB( Hi( SCRADR));
  for I := 1 to 101 do DLB( $0E);
  DLB( $4E); DLB( $00); DLB( $B0);              { row 102 = $B000 }
  for I := 103 to 191 do DLB( $0E);
  DLB( $41); DLB( Lo( DLADR)); DLB( Hi( DLADR));

  DLP := TXTDL;                                 { text: mode 4 }
  DLB( $70); DLB( $70); DLB( $70);
  DLB( $44); DLB( Lo( TXTADR)); DLB( Hi( TXTADR));
  for I := 1 to CHARROWS - 1 do DLB( $04);
  DLB( $41); DLB( Lo( TXTDL)); DLB( Hi( TXTDL));

  P := Pointer( TXTFONT);
  FillChar( P^, 1024, 0);
  FillChar( SCRNBUF, SizeOf( SCRNBUF), 0);
  GX := 0;
  GY := 0;
  ClrScr;

  Poke( $02C4, $00);              { COLOR0 }
  Poke( $02C5, $28);              { COLOR1 }
  Poke( $02C6, $0E);              { COLOR2: glyph colour 3 = COLPF2 }
  Poke( $02C8, $00);              { COLOR4 background }
  Poke( $02F4, Hi( TXTFONT));     { CHBAS }
  Poke( $022F, $22);
  SHOWTEXT;
  DPoke( $0346, Word( @PUTCH) - 1)
end;


{ ── Keyboard and timing ──────────────────────────────────────────────────── }

function KeyPressed: Boolean;
begin
  KeyPressed := Peek( CH) <> $FF
end;

function ReadKey: Char;
var
  K, C : Byte;
begin
  repeat
    repeat until Peek( CH) <> $FF;
    K := Peek( CH);
    Poke( CH, $FF);
    C := 0;
    if K and $80 = 0 then C := KEYTAB[ K and $7F]
  until C <> 0;
  ReadKey := Chr( C)
end;

procedure Delay( MS: Word);
{ In 1/60 s steps (NTSC frame), at least one. }
var
  T : Byte;
  N : Word;
begin
  N := MS div 17;
  if N = 0 then N := 1;
  while N > 0 do
    begin
      T := Peek( RTCLOK);
      repeat until Peek( RTCLOK) <> T;
      Dec( N)
    end
end;

end.
