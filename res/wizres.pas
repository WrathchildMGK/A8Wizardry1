program WIZRES;

{ Wizardry I — the low resident: boot, overlay loader and the AP main loop
  (WIZ.TEXT P010001), with LOUTIL (disk) linked in.  Autoruns as
  WIZARDRY.AU0 under LiteDOS.  DOS is only used to load this program:
  WIZHI.XEX and the overlays are read by following their sector links
  (LOUTIL SEQOPEN/SEQREAD), so its memory is reused for the text page.

  Memory map
    $0800..$0FFF  text page: font, screen, display list  (screen.pas)
    $1080..       this program (-code:1080: LiteDOS MEMLO)
    $4000..$7FFF  overlay window = XE bank window (overlay primary part)
    $8000..$8FFF  overlay tail (overlays up to 20K), main RAM
    $9000..$9A3F  GLOBALS block 1                        (globals.pas)
    $9A40..$9FFF  this program's variables (-data:9A40)
    $A010..$BEFF  mode E screen + display list           (screen.pas)
    $C000..$C7FF  WIZHI data          \
    $C800..$CFFF  GLOBALS block 2      > RAM under the OS ROM
    $D800..$F7FF  WIZHI code          /

  The game runs with the OS ROM switched out (WIZHI provides the interrupt
  handlers and the console); OSIN/OSOUT switch it in only for each SIO
  sector transfer in LOUTIL.  Nothing may print while it is in: the
  console is under it.

  Overlays are Mad Pascal libraries at $4000, converted to .OVL by
  tools/mkovl.py: a primary part (<= 16K at $4000) and an optional tail
  (<= 4K at $8000).  With extended RAM each part is kept in a bank (slot
  table of overlay*2+part, LRU replacement; the tail is copied to $8000
  before a call and back after it); without, every call reloads from disk
  into main RAM. }

uses TYPES, CONSTS, GLOBALS, LOUTIL, COMBATG;

const
  OVLBASE  = $4000;
  OVLMAX   = $5000;                         { primary 16K + tail 4K }
  TAILBASE = $8000;
  HISTAGE  = $4000;                         { WIZHI staged here at boot }
  PORTB    = $D301;
  NMIEN    = $D40E;
  MAXBANK  = 16;
  NOBANK   = $FF;

  { Overlays: one per AP segment, except COMBAT: its CINIT, CUTIL (less
    CACTION), CACTION, CASTASPE and SWINGASW are five, run by COMBAT and
    MELEE below. }
  OSPEC = 1; OCAST = 2; OSHOP = 3; OUTIL = 4; OROLL = 5;
  ORUNN = 6; OREWD = 7; OCINI = 8; OCAMP = 9; OCUTL = 10; OCACT = 11;
  OSPEL = 12; OSWNG = 13;
  NOVL  = 13;
  OVLFILE : array[ 0..NOVL] of string[ 11] = ( '',     { MP: lower bound 0 }
    'SPECIALSOVL', 'CASTLE  OVL', 'SHOPS   OVL', 'UTILITIEOVL', 'ROLLER  OVL',
    'RUNNER  OVL', 'REWARDS OVL', 'CINIT   OVL', 'CAMP    OVL', 'CUTIL   OVL',
    'CACT    OVL', 'CAST    OVL', 'SWING   OVL');        { 8+3 directory names }

var
  PBNORM   : Byte;                          { PORTB with main RAM selected }
  NBANKS   : Byte;
  BANKCODE : array[ 0..MAXBANK-1] of Byte;
  BANKOVL  : array[ 0..MAXBANK-1] of Byte;  { overlay*2 + part, 0 = empty }
  BANKUSE  : array[ 0..MAXBANK-1] of Word;  { last-use tick for LRU }
  OVLENTRY : array[ 0..NOVL] of Word;
  OVLTAIL  : array[ 0..NOVL] of Word;       { tail length, 0 = none }
  OVLHDR   : array[ 0..3] of Word;          { 'WO', LOAD, LEN, ENTRY }
  TICK     : Word;
  FNAME    : string[ 11];
  SEGDST   : array[ 0..3] of Word;          { WIZHI segments: dest, len, }
  SEGLEN   : array[ 0..3] of Word;          {   staged at SEGSRC         }
  SEGSRC   : array[ 0..3] of Word;
  NSEG     : Byte;
  HIENTRY  : Word;
  APITAB   : array[ 0..31] of Pointer;      { keeps the LOUTIL API linked in }
  WINDOW   : PByte;                         { = OVLBASE }
  TAIL     : PByte;                         { = TAILBASE }

procedure GotoXY( X, Y: Byte); external 'WIZHI';
procedure TEXTFONT; external 'WIZHI';
procedure GETKEY; external 'WIZHI';
procedure PAUSE2; external 'WIZHI';

procedure COLDBOOT; assembler;
{ OS ROM in, then the reset vector: COLDST is set, so a cold start. }
asm
	sei
	lda #$00
	sta $D40E
	lda $D301
	ora #$01
	sta $D301
	jmp ($FFFC)
end;

{ ── Extended RAM ─────────────────────────────────────────────────────── }

function BANKBITS( I: Byte): Byte;
{ Candidate PORTB code I.  Bits 2,3 = 130XE bank, bit 6 = 256K+ expansions,
  bit 5 (ANTIC) kept at main for the first 8 so 130XE banks are found
  with ANTIC still seeing main RAM; bit 4 = 0 selects extended RAM. }
begin
  Result := ( PBNORM and $83) or (( I and 3) shl 2);
  if I and 4 <> 0 then Result := Result or $40;
  if I and 8 =  0 then Result := Result or $20
end;

procedure DETECTBANKS;
var
  J, SAVED : Byte;
begin
  PBNORM := Peek( PORTB) or $30;
  SAVED  := Peek( OVLBASE);
  for J := MAXBANK - 1 downto 0 do
    begin
      Poke( PORTB, BANKBITS( J));
      Poke( OVLBASE, J)
    end;
  Poke( PORTB, PBNORM);
  Poke( OVLBASE, $FF);
  NBANKS := 0;
  for J := 0 to MAXBANK - 1 do
    begin
      Poke( PORTB, BANKBITS( J));
      if Peek( OVLBASE) = J then
        begin
          BANKCODE[ NBANKS] := BANKBITS( J);
          BANKOVL[  NBANKS] := 0;
          BANKUSE[  NBANKS] := 0;
          Inc( NBANKS)
        end
    end;
  Poke( PORTB, PBNORM);
  Poke( OVLBASE, SAVED)
end;

procedure SELECT( B: Byte);
{ Map bank B (NOBANK = main RAM) into the window, keeping the OS bit. }
var
  V : Byte;
begin
  if B = NOBANK then V := PBNORM else V := BANKCODE[ B];
  Poke( PORTB, ( V and $FE) or ( Peek( PORTB) and 1))
end;

function FINDSLOT( TAG: Byte): Byte;
var
  J : Byte;
begin
  Result := NOBANK;
  J := 0;
  while J < NBANKS do
    begin
      if BANKOVL[ J] = TAG then Result := J;
      Inc( J)
    end
end;

function PICKBANK( EXCL: Byte): Byte;
{ Empty bank if any, else the least recently used; never EXCL. }
var
  J : Byte;
begin
  Result := NOBANK;
  J := 0;
  while J < NBANKS do
    begin
      if J <> EXCL then
        begin
          if BANKOVL[ J] = 0 then exit( J);
          if ( Result = NOBANK) or ( BANKUSE[ J] < BANKUSE[ Result]) then Result := J
        end;
      Inc( J)
    end
end;


{ ── Loader ───────────────────────────────────────────────────────────── }

procedure CALLOVL( ADR: Word); assembler;
asm
	jsr go
	jmp done
go	jmp (ADR)
done
end;

procedure FAIL( MSG: string[ 20]);
begin
  SELECT( NOBANK);
  Write( MSG);
  Write( ' ');
  WriteLn( FNAME);
  repeat until False
end;

function LOADOVL( N: Byte): Boolean;
{ Read overlay N into the window as currently mapped, tail into $8000. }
var
  PLEN : Word;
begin
  Result := False;
  FNAME := OVLFILE[ N];
  if not SEQOPEN( @FNAME) then exit;
  if SEQREAD( @OVLHDR, 8) <> 8 then exit;
  if ( OVLHDR[ 0] <> $4F57) or ( OVLHDR[ 1] <> OVLBASE) or ( OVLHDR[ 2] > OVLMAX) then exit;
  PLEN := OVLHDR[ 2];
  if PLEN > $4000 then PLEN := $4000;
  if SEQREAD( Pointer( OVLBASE), PLEN) <> PLEN then exit;
  OVLTAIL[ N] := OVLHDR[ 2] - PLEN;
  if OVLTAIL[ N] > 0 then
    if SEQREAD( Pointer( TAILBASE), OVLTAIL[ N]) <> OVLTAIL[ N] then exit;
  OVLENTRY[ N] := OVLHDR[ 3];
  Result := True
end;

procedure RUNOVL( N: Byte);
var
  PB, TB : Byte;
  OK     : Boolean;
begin
  Inc( TICK);
  PB := FINDSLOT( N * 2);
  TB := FINDSLOT( N * 2 + 1);

  if ( PB <> NOBANK) and (( OVLTAIL[ N] = 0) or ( TB <> NOBANK)) then
    begin
      if OVLTAIL[ N] > 0 then
        begin
          SELECT( TB);
          Move( WINDOW^, TAIL^, OVLTAIL[ N]);
          BANKUSE[ TB] := TICK
        end
    end
  else
    begin
      if PB <> NOBANK then BANKOVL[ PB] := 0;      { drop a partial copy }
      if TB <> NOBANK then BANKOVL[ TB] := 0;
      PB := NOBANK;
      if NBANKS > 0 then
        begin
          PB := PICKBANK( NOBANK);
          BANKOVL[ PB] := 0
        end;
      SELECT( PB);
      OK := LOADOVL( N);
      if not OK then FAIL( 'CANNOT LOAD');

      if PB <> NOBANK then
        begin
          BANKOVL[ PB] := N * 2;
          if OVLTAIL[ N] > 0 then
            begin
              TB := PICKBANK( PB);
              if TB = NOBANK then
                BANKOVL[ PB] := 0                  { tail can't be cached }
              else
                begin
                  BANKOVL[ TB] := 0;
                  SELECT( TB);
                  Move( TAIL^, WINDOW^, OVLTAIL[ N]);
                  BANKOVL[ TB] := N * 2 + 1;
                  BANKUSE[ TB] := TICK
                end
            end
        end
    end;

  SELECT( PB);
  if PB <> NOBANK then BANKUSE[ PB] := TICK;
  CALLOVL( OVLENTRY[ N]);

  { The tail ran from its copy at $8000: write it back so the overlay's
    state there survives in the cache. }
  TB := FINDSLOT( N * 2 + 1);
  if TB <> NOBANK then
    begin
      SELECT( TB);
      Move( TAIL^, WINDOW^, OVLTAIL[ N])
    end;
  SELECT( NOBANK)
end;


{ AP MELEE (P010701): everyone acts, fastest first.  CASTASPE and SWINGASW
  are overlays (CAST, SWING), which also do MELEE's per-action cursor and
  pause. }
procedure MELEE;
var
  AGILELEV : SmallInt;
  MBRC     : ^TENEMY2;
  MBRA     : ^TENEMY2A;
  PT04     : ^TTEMP04;
  NBAT     : SmallInt;
begin
  CMBEXIT := UNWNONE;
  for AGILELEV := 1 to 10 do
    for BATG := 0 to 4 do
      begin
        MBRC := BATTLERC[ BATG];
        MBRA := MBRC^.A;
        NBAT := MBRA.ALIVECNT;                 { AP: a for loop's bound }
        BATI := 0;
        while BATI < NBAT do
          begin
            PT04 := MBRA.TEMP04[ BATI];
            if ( Byte( PT04^.XSTATUS) = 0) and ( PT04.AGILITY = AGILELEV) then
              begin
                VICTIM   := PT04.VICTIM;
                ATTACKTY := PT04.SPELLHSH;
                if ( ATTACKTY >= -5) and ( ATTACKTY < 0) then
                  RUNOVL( OSWNG)
                else if ATTACKTY > 0 then
                  begin
                    RUNOVL( OSPEL);
                    if CMBEXIT = U_COMBAT then exit       { EXIT( COMBAT) }
                  end
              end;
            Inc( BATI)
          end
      end
end;


{ AP COMBAT (P010401) body.  An overlay's EXIT( COMBAT) comes back as
  CMBEXIT = U_COMBAT, with XGOTO already set. }
procedure COMBAT;
begin
  DONEFIGH := false;
  CINITFL1 := 0;
  RUNOVL( OCINI);
  if CMBEXIT = U_COMBAT then exit;
  XGOTO := XREWARD;
  repeat
    RUNOVL( OCUTL);
    if CMBEXIT = U_COMBAT then exit;
    if not DONEFIGH then
      RUNOVL( OCACT);                           { AP: CUTIL's CACTION }
    if not DONEFIGH then
      begin
        MELEE;
        if CMBEXIT = U_COMBAT then exit
      end
  until DONEFIGH;
  CINITFL1 := 2;
  RUNOVL( OCINI)
end;


{ ── Boot ─────────────────────────────────────────────────────────────── }

procedure OSOUTMASKED; assembler;
{ OS out with IRQ and NMI left disabled (before WIZHI's vectors exist). }
asm
	sei
	lda #$00
	sta $D40E
	lda $D301
	and #$FE
	sta $D301
end;

procedure INTSON; assembler;
asm
	lda #$40
	sta $D40E
	cli
end;

procedure STARTHI;
{ Load WIZHI.XEX (OS in): its segments are staged in the window, then the
  OS is switched out, the segments copied under the ROM and WIZHI's main
  block run (it installs the NMI/IRQ vectors and the console). }
var
  W     : array[ 0..1] of Word;
  STG   : Word;
  L     : Word;
  I     : Byte;
  D, S  : PByte;
begin
  FNAME := 'WIZHI   XEX';
  if not SEQOPEN( @FNAME) then FAIL( 'NO FILE');
  STG := HISTAGE;
  NSEG := 0;
  HIENTRY := 0;
  while SEQREAD( @W, 2) = 2 do
    begin
      if W[ 0] = $FFFF then SEQREAD( @W, 2);
      SEQREAD( @W[ 1], 2);
      L := W[ 1] - W[ 0] + 1;
      if W[ 0] = $02E0 then
        SEQREAD( @HIENTRY, 2)
      else if W[ 0] = $02E2 then
        SEQREAD( @L, 2)                      { INITAD: not used }
      else
        begin
          if NSEG > 3 then FAIL( 'TOO MANY SEGMENTS');
          if SEQREAD( Pointer( STG), L) <> L then FAIL( 'SHORT');
          SEGDST[ NSEG] := W[ 0];
          SEGSRC[ NSEG] := STG;
          SEGLEN[ NSEG] := L;
          Inc( NSEG);
          Inc( STG, L)
        end
    end;
  if ( HIENTRY = 0) or ( NSEG = 0) then FAIL( 'BAD FILE');

  OSOUTMASKED;                               { no interrupts until NMIH/IRQH are in }
  for I := 0 to NSEG - 1 do
    begin
      S := Pointer( SEGSRC[ I]);
      D := Pointer( SEGDST[ I]);
      Move( S^, D^, SEGLEN[ I])
    end;
  CALLOVL( HIENTRY);
  INTSON
end;

procedure WIREPARTY;
{ CHARACTR is always a permutation of the six slots; party order is
  changed by swapping pointers, never by copying records. }
begin
  CHARACTR[ 0] := @CHAR_SLOT0;
  CHARACTR[ 1] := @CHAR_SLOT1;
  CHARACTR[ 2] := @CHAR_SLOT2;
  CHARACTR[ 3] := @CHAR_SLOT3;
  CHARACTR[ 4] := @CHAR_SLOT4;
  CHARACTR[ 5] := @CHAR_SLOT5;
  WIRECHAR( CHAR_SLOT0, CHAR_SKN0, CHAR_POSS0);
  WIRECHAR( CHAR_SLOT1, CHAR_SKN1, CHAR_POSS1);
  WIRECHAR( CHAR_SLOT2, CHAR_SKN2, CHAR_POSS2);
  WIRECHAR( CHAR_SLOT3, CHAR_SKN3, CHAR_POSS3);
  WIRECHAR( CHAR_SLOT4, CHAR_SKN4, CHAR_POSS4);
  WIRECHAR( CHAR_SLOT5, CHAR_SKN5, CHAR_POSS5)
end;


begin
{$I ../imp/wizres_keep.inc}

  WINDOW := Pointer( OVLBASE);
  TAIL   := Pointer( TAILBASE);
  WriteLn( 'WIZARDRY - LOADING');
  Poke( $0244, 1);                          { COLDST: RESET reboots (DOS is overwritten) }
  DETECTBANKS;
  STARTHI;                                   { from here on the OS ROM is out }
  WIREPARTY;
  CACHEBL := -1;
  { The text page's font is the scenario's text charset (block 1, the 4x8
    font): built once, before SPECIALS prints its first prompt.  (AP: the
    text screen used the ROM font; CHARSET is reloaded later for graphics.) }
  SCNTOCBL := 0;
  UNITREAD_BUF( 1, CHARSET);
  TEXTFONT;

  { AP mainline (P010001): SPECIALS first with LLBASE04 = -1 (game start),
    then dispatch on XGOTO until XDONE. }
  repeat
    LLBASE04 := -1;
    RUNOVL( OSPEC);
    repeat
      case XGOTO of
        XSCNMSG,  XINSAREA:                     RUNOVL( OSPEC);
        XCASTLE,  XGILGAMS:                     RUNOVL( OCAST);
        XBOLTAC,  XCANT,    XCHK4WIN,
        XCEMETRY, XEDGTOWN:                     RUNOVL( OSHOP);
        XNEWMAZE, XEQUIP6,  XEQPDSP,  XREORDER,
        XCMP2EQ6, XCAMPSTF:                     RUNOVL( OUTIL);
        XTRAININ, XBCK2ROL:                     RUNOVL( OROLL);
        XRUNNER:                                RUNOVL( ORUNN);
        XREWARD,  XREWARD2:                     RUNOVL( OREWD);
        XCOMBAT,  XUNUSED:                      COMBAT;
        XINSPECT, XINSPCT2, XINSPCT3,
        XBCK2CMP, XBK2CMP2:                     RUNOVL( OCAMP);
      end
    until XGOTO = XDONE;

    Write( Chr( 12));                          { v3.2 WC036 }
    GotoXY( 4, 10);
    Write( 'PRESS [RETURN] FOR MORE WIZARDRY    ');
    GotoXY( 12, 13);
    Write( 'OR Q)UIT THE GAME           ');
    repeat
      GETKEY
    until ( INCHAR = 'Q') or ( INCHAR = Chr( CRETURN));
    if INCHAR = 'Q' then
      begin
        GotoXY( 4, 16);
        Write( 'THANK YOU FOR PLAYING WIZARDRY!     ');
        PAUSE2;
        COLDBOOT                               { AP: EXIT( WIZARDRY) }
      end
  until False
end.
