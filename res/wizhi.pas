library WIZHI : $D800;

{ Wizardry I — the high resident, in the RAM under the OS ROM: code from
  $D800, data from $C000 (built with -data:C000; MADS rejects some
  var-parameter code once data reaches $E000).  Holds everything that needs
  no DOS: the SCREEN console and HIUTIL.  The game runs with the OS ROM
  switched out, so this also supplies the interrupt handlers.

  Loaded by WIZRES at boot (OS in, staged in the overlay window, copied up
  with the OS out); its main block then runs once, interrupts still off:
    $FFFA NMI -> NMIH  (VBI: RTCLOK + the OS shadow-register copy, so the
                        display is the same whether or not the OS is in)
    $FFFE IRQ -> IRQH  (keyboard -> CH, as the OS does)
  and SCRINIT sets up the screen and hooks Write/WriteLn.

  Overlays call it through imp/util.pas / imp/screen.pas, resolved from
  WIZHI.hea (aliased by tools/heaalias.py). }

uses TYPES, CONSTS, GLOBALS, SCREEN, HIUTIL;

procedure NMIH; assembler;
asm
	bit $D40F
	bpl vbi
	rti
vbi	pha
	txa
	pha
	sta $D40F
	inc $14
	bne @+
	inc $13
	bne @+
	inc $12
@	lda $022F
	sta $D400
	lda $0230
	sta $D402
	lda $0231
	sta $D403
	lda $02F3
	sta $D401
	lda $02F4
	sta $D409
	lda $026F
	sta $D01B
	ldx #4
@	lda $02C4,x
	sta $D016,x
	dex
	bpl @-
	pla
	tax
	pla
	rti
end;

procedure IRQH; assembler;
asm
	pha
	lda $D20E
	and #$40
	bne @+
	lda $D209
	sta $02FC
@	lda #$00
	sta $D20E
	lda $10
	sta $D20E
	pla
	rti
end;

{$I ../imp/wizhi_exports.inc}

begin
  DPoke( $FFFA, Word( @NMIH));
  DPoke( $FFFE, Word( @IRQH));
  SCRINIT
end.
