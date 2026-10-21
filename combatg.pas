unit COMBATG;

{ Wizardry I — combat state shared by the combat overlays.

  The AP COMBAT segment holds CINIT, CUTIL and MELEE (with CASTASPE and
  SWINGASW) as nested segments sharing COMBAT's variables.  On the Atari
  CINIT, CUTIL, CUTIL's CACTION, CASTASPE and SWINGASW are overlays run by
  the resident COMBAT and MELEE loops (WIZRES), so COMBAT's and MELEE's
  variables live here at fixed addresses, like GLOBALS: in the overlay tail
  area at $8800.., which the combat overlays leave free (they are built to
  end below it, mkovl --limit 0x8800).

  CMBEXIT is how an overlay reports AP EXIT( COMBAT) to the combat loop
  (UNWNONE or U_COMBAT; see CONSTS).

  BATTLERC[0..4] and what it points at are wired to the blocks here once,
  by CINIT (WIREBATL); the pointers stay valid for the whole combat. }

interface

uses TYPES, CONSTS;

const
  U_COMBAT     = $01;                           { unwind target: AP P010401 }

  A_COMBATG    = $8800;                         { .. A_CMBEND = $8F16, below GLOBALS }
  A_CMBEXIT    = A_COMBATG;
  A_CINITFL1   = A_CMBEXIT  + 1;
  A_SURPRISE   = A_CINITFL1 + 2;
  A_DONEFIGH   = A_SURPRISE + 2;
  A_MYSTRENG   = A_DONEFIGH + 1;                { AP: BASE12.MYSTRENG }
  A_PREBATOR   = A_MYSTRENG + 2;
  A_DRAINED    = A_PREBATOR + 6 * 2;
  A_BATG       = A_DRAINED  + 6;                { AP MELEE's variables: the }
  A_BATI       = A_BATG     + 2;                {   combatant CAST / SWING  }
  A_VICTIM     = A_BATI     + 2;                {   acts for                }
  A_ATTACKTY   = A_VICTIM   + 2;
  A_BATTLERC   = A_ATTACKTY + 2;
  A_BR2BLK     = A_BATTLERC + 5 * 2;
  A_BR2ABLK    = A_BR2BLK   + 5 * TENEMY2_SIZE;
  A_BRBBLK     = A_BR2ABLK  + 5 * 25;           { TENEMY2A }
  A_T04BLK     = A_BRBBLK   + 5 * 160;          { TENEMY }
  A_RECSBLK    = A_T04BLK   + 45 * 13;          { TTEMP04 }
  A_CMBEND     = A_RECSBLK  + 40 * 6;           { THPREC }

var
  CMBEXIT  : Byte absolute A_CMBEXIT;
  CINITFL1 : SmallInt absolute A_CINITFL1;
  SURPRISE : SmallInt absolute A_SURPRISE;
  DONEFIGH : Boolean absolute A_DONEFIGH;
  MYSTRENG : SmallInt absolute A_MYSTRENG;
  PREBATOR : array[ 0..5] of SmallInt absolute A_PREBATOR;
  DRAINED  : array[ 0..5] of Boolean absolute A_DRAINED;
  BATG     : SmallInt absolute A_BATG;
  BATI     : SmallInt absolute A_BATI;
  VICTIM   : SmallInt absolute A_VICTIM;
  ATTACKTY : SmallInt absolute A_ATTACKTY;
  BATTLERC : array[ 0..4] of ^TENEMY2 absolute A_BATTLERC;

procedure WIREBATL;

implementation

procedure WIREBATL;
{ Wire BATTLERC[0..4] -> TENEMY2 -> A (TENEMY2A, TEMP04[0..8]) and
  B (TENEMY, RECS[0..7]) to the blocks above, then clear them. }
var
  I, J : SmallInt;
  P    : PByte;
  BRC  : ^TENEMY2;
  BRA  : ^TENEMY2A;
  BRB  : ^TENEMY;
begin
  P := Pointer( A_BR2BLK);
  FillChar( P^, A_CMBEND - A_BR2BLK, 0);
  for I := 0 to 4 do
    begin
      BATTLERC[ I] := Pointer( A_BR2BLK + I * TENEMY2_SIZE);
      BRC   := BATTLERC[ I];
      BRA   := Pointer( A_BR2ABLK + I * 25);
      BRB   := Pointer( A_BRBBLK  + I * 160);
      BRC^.A := BRA;              { not ":= Pointer(...)": rejected for a ^record field }
      BRC^.B := BRB;
      for J := 0 to 8 do
        BRA.TEMP04[ J] := Pointer( A_T04BLK + ( I * 9 + J) * 13);
      for J := 0 to 7 do
        BRB.RECS[ J] := Pointer( A_RECSBLK + ( I * 8 + J) * 6)
    end
end;

end.
