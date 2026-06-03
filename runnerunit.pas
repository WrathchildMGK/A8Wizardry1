unit RUNNERUNIT;

{ Wizardry I — RUNNER segment (maze movement and 3-D rendering).
  Source: apple/wiz1c/RUNNER + apple/wiz1c/RUNNER2.
  Key changes from Apple Pascal:
    - EXIT(RUNNER) from nested procs → _done := true; exit chain
    - EXIT(PROCNAME) within PROCNAME → plain exit
    - MAZE.N[X][Y] → MAZE.N^[X*20+Y]  (flat 1-D TMAZEMAP pointer)
    - MAZE.SQREXTRA[X][Y] → MAZE.SQREXTRA^[X*20+Y]
    - WITH MAZE.ENMYCALC[n] DO → with MAZE.ENMYCALC[n]^ do
    - WITH CHARACTR[n] DO → with CHARACTR[n]^ do
    - RANDOM MOD n → Random(n)
    - SCNTOC.CLASS/ALIGN/STATUS → SCNTOC_CLASS/SCNTOC_ALIGN/SCNTOC_STATUS
    - CLASS field → XCLASS  (CLASS is reserved in MP)
    - LOSTXYL.POISNAMT[1] → LOSTXYL[1]  (flat variant array)
    - CHARREC sort swaps ^TCHAR pointers, not full record copies
    - DRAWLINE/CLRPICT: stubs (Apple II hi-res; Atari impl TODO)
    - CHENCOUN maze write-back: stub (TODO: SAVETMAZE when I/O is wired) }

interface

uses TYPES, CONSTS, GLOBALS, UTIL, crt;

procedure RUNNER;

implementation

const
  NORTH = 0;
  EAST  = 1;
  SOUTH = 2;
  WEST  = 3;

var
  _done    : Boolean;   { set true to simulate EXIT(RUNNER) from a nested proc }
  QUICKPLT : Boolean;
  INITTURN : Boolean;
  NEEDDRMZ : Boolean;
  MAZE     : TMAZE;


{ Unit-level helpers: record.ptr^[i] is untyped in MP so we use Move() to copy
  one byte to a typed local before returning. }

function MZ_N( X, Y: SmallInt): Byte;
var B: Byte; begin B := 0; Move( MAZE.N^[ X*20+Y], B, 1); MZ_N := B end;

function MZ_S( X, Y: SmallInt): Byte;
var B: Byte; begin B := 0; Move( MAZE.S^[ X*20+Y], B, 1); MZ_S := B end;

function MZ_E( X, Y: SmallInt): Byte;
var B: Byte; begin B := 0; Move( MAZE.E^[ X*20+Y], B, 1); MZ_E := B end;

function MZ_W( X, Y: SmallInt): Byte;
var B: Byte; begin B := 0; Move( MAZE.W^[ X*20+Y], B, 1); MZ_W := B end;

function MZ_SQR( X, Y: SmallInt): Byte;
var B: Byte; begin B := 0; Move( MAZE.SQREXTRA^[ X*20+Y], B, 1); MZ_SQR := B end;

function MZ_FGT( X, Y: SmallInt): Byte;
var B: Byte; begin B := 0; Move( MAZE.FIGHTS^[ X*20+Y], B, 1); MZ_FGT := B end;


procedure RUNNER;


  { ── DRAWMAZE ─────────────────────────────────────────────────────────────── }

  procedure DRAWMAZE;
  var
    GOTLIGHT : Boolean;
    WALHEIGH : SmallInt;
    DOORFRAM : SmallInt;
    DOORWIDT : SmallInt;
    WALWIDTH : SmallInt;
    LR       : SmallInt;
    UL       : SmallInt;
    SQREDESC : SmallInt;
    XUPPER   : SmallInt;
    XLOWER   : SmallInt;
    Y4DRAW   : SmallInt;
    X4DRAW   : SmallInt;
    LIGHTDIS : SmallInt;
    WALLTYPE : Byte;       { stores TWALL ordinal: 0=OPEN 1=WALL 2=DOOR 3=HIDEDOOR }


    procedure SHFTPOS( var X: SmallInt; var Y: SmallInt;
                       RIGHSHFT, FRWDSHFT: SmallInt);
    begin
      case Byte( DIRECTIO) of
        NORTH: begin X := X + RIGHSHFT; Y := Y + FRWDSHFT end;
        EAST:  begin X := X + FRWDSHFT; Y := Y - RIGHSHFT end;
        SOUTH: begin X := X - RIGHSHFT; Y := Y - FRWDSHFT end;
        WEST:  begin X := X - FRWDSHFT; Y := Y + RIGHSHFT end;
      end;
      X := (X + 20) mod 20;
      Y := (Y + 20) mod 20
    end;


    function FRWDVIEW( DELTAR: SmallInt): Byte;
    var X, Y: SmallInt;
    begin
      X := X4DRAW; Y := Y4DRAW;
      SHFTPOS( X, Y, DELTAR, 0);
      case Byte( DIRECTIO) of
        NORTH: FRWDVIEW := MZ_N( X, Y);
        EAST:  FRWDVIEW := MZ_E( X, Y);
        SOUTH: FRWDVIEW := MZ_S( X, Y);
        WEST:  FRWDVIEW := MZ_W( X, Y);
      end
    end;


    function LEFTVIEW( DELTAR: SmallInt): Byte;
    var X, Y: SmallInt;
    begin
      X := X4DRAW; Y := Y4DRAW;
      SHFTPOS( X, Y, DELTAR, 0);
      case Byte( DIRECTIO) of
        NORTH: LEFTVIEW := MZ_W( X, Y);
        EAST:  LEFTVIEW := MZ_N( X, Y);
        SOUTH: LEFTVIEW := MZ_E( X, Y);
        WEST:  LEFTVIEW := MZ_S( X, Y);
      end
    end;


    function RIGHVIEW( DELTAR: SmallInt): Byte;
    var X, Y: SmallInt;
    begin
      X := X4DRAW; Y := Y4DRAW;
      SHFTPOS( X, Y, DELTAR, 0);
      case Byte( DIRECTIO) of
        NORTH: RIGHVIEW := MZ_E( X, Y);
        EAST:  RIGHVIEW := MZ_S( X, Y);
        SOUTH: RIGHVIEW := MZ_W( X, Y);
        WEST:  RIGHVIEW := MZ_N( X, Y);
      end
    end;


    procedure DRAWLEFT;
    begin
      XLOWER := UL;
      DRAWLINE( UL,            UL, -1, -1, WALWIDTH);
      DRAWLINE( UL,            UL,  0,  1, WALHEIGH);
      DRAWLINE( UL,            LR, -1,  1, WALWIDTH);
      DRAWLINE( UL - WALWIDTH, UL - WALWIDTH, 0, 1, WALHEIGH + WALHEIGH);
      if (WALLTYPE = Byte( OPEN)) or (WALLTYPE = Byte( WALL)) or
         ((WALLTYPE = Byte( HIDEDOOR)) and
          (not GOTLIGHT and (Random( 6) <> 3))) then
        exit;
      DRAWLINE( UL - DOORFRAM, UL, -1, -1, DOORWIDT);
      DRAWLINE( UL - DOORFRAM, UL,  0,  1, WALHEIGH + DOORFRAM);
      DRAWLINE( UL - DOORFRAM - DOORWIDT, UL - DOORWIDT, 0, 1,
                WALHEIGH + WALWIDTH + DOORFRAM)
    end;


    procedure DRAWRIGH;
    begin
      XUPPER := LR;
      DRAWLINE( LR, UL,  1, -1, WALWIDTH);
      DRAWLINE( LR, UL,  0,  1, WALHEIGH);
      DRAWLINE( LR, LR,  1,  1, WALWIDTH);
      DRAWLINE( LR + WALWIDTH, UL - WALWIDTH, 0, 1, WALHEIGH + WALHEIGH);
      if (WALLTYPE = Byte( OPEN)) or (WALLTYPE = Byte( WALL)) or
         ((WALLTYPE = Byte( HIDEDOOR)) and
          (not GOTLIGHT and (Random( 6) <> 3))) then
        exit;
      DRAWLINE( LR + DOORFRAM, UL,  1, -1, DOORWIDT);
      DRAWLINE( LR + DOORFRAM, UL,  0,  1, WALHEIGH + DOORFRAM);
      DRAWLINE( LR + DOORFRAM + DOORWIDT, UL - DOORWIDT, 0, 1,
                WALHEIGH + WALWIDTH + DOORFRAM)
    end;


    procedure DRAWFRNT( FRNTWALL: Byte; LRCENT: SmallInt);
    begin
      DRAWLINE( UL + LRCENT,            UL,           1, 0, WALHEIGH);
      DRAWLINE( UL + LRCENT,            UL,           0, 1, WALHEIGH);
      DRAWLINE( UL + LRCENT + WALHEIGH, UL,           0, 1, WALHEIGH + 1);
      DRAWLINE( UL + LRCENT,            UL + WALHEIGH, 1, 0, WALHEIGH);
      if (FRNTWALL = Byte( OPEN)) or (FRNTWALL = Byte( WALL)) or
         ((FRNTWALL = Byte( HIDEDOOR)) and
          (not GOTLIGHT and (Random( 6) <> 3))) then
        exit;
      DRAWLINE( UL + LRCENT + DOORFRAM, LR, 0, -1,
                WALWIDTH + DOORWIDT + DOORFRAM);
      DRAWLINE( UL + LRCENT + WALWIDTH + DOORWIDT + DOORFRAM, LR, 0, -1,
                WALWIDTH + DOORWIDT + DOORFRAM);
      DRAWLINE( UL + LRCENT + DOORFRAM,
                LR - WALWIDTH - DOORWIDT - DOORFRAM,
                1, 0, WALWIDTH + DOORWIDT + 1)
    end;


  begin  { DRAWMAZE }
    GOTLIGHT := LIGHT > 0;
    if GOTLIGHT then
      begin
        if QUICKPLT then
          LIGHTDIS := 3
        else
          LIGHTDIS := 5;
        LIGHT := LIGHT - 1
      end
    else
      LIGHTDIS := 2;
    UL       :=  8;
    LR       := 72;
    WALWIDTH := 32;
    DOORWIDT := 16;
    DOORFRAM :=  8;
    WALHEIGH := 64;
    X4DRAW := MAZEX;
    Y4DRAW := MAZEY;
    CLEARPIC;
    XLOWER := 0;
    XUPPER := 81;
    while LIGHTDIS > 0 do
      begin
        SQREDESC := MZ_SQR( X4DRAW, Y4DRAW);
        if MAZE.SQRETYPE[ SQREDESC] = Byte( DARK) then
          exit
        else
          if MAZE.SQRETYPE[ SQREDESC] = Byte( TRANSFER) then
            if MAZE.AUX0[ SQREDESC] = MAZELEV then
              begin
                X4DRAW := MAZE.AUX2[ SQREDESC];
                Y4DRAW := MAZE.AUX1[ SQREDESC]
              end;
        CLRPICT( XLOWER, 0, XUPPER, 79);
        WALLTYPE := LEFTVIEW( 0);
        if WALLTYPE <> Byte( OPEN) then
          DRAWLEFT
        else
          begin
            WALLTYPE := FRWDVIEW( -1);
            if WALLTYPE <> Byte( OPEN) then
              begin
                DRAWFRNT( WALLTYPE, -(2 * WALWIDTH));
                XLOWER := UL
              end
          end;
        WALLTYPE := RIGHVIEW( 0);
        if WALLTYPE <> Byte( OPEN) then
          DRAWRIGH
        else
          begin
            WALLTYPE := FRWDVIEW( 1);
            if WALLTYPE <> Byte( OPEN) then
              begin
                DRAWFRNT( WALLTYPE, 2 * WALWIDTH);
                XUPPER := LR
              end
          end;
        WALLTYPE := FRWDVIEW( 0);
        if WALLTYPE <> Byte( OPEN) then
          begin
            DRAWFRNT( WALLTYPE, 0);
            exit
          end;
        WALWIDTH := WALWIDTH div 2;
        DOORWIDT := WALWIDTH div 2;
        WALHEIGH := WALWIDTH * 2;
        DOORFRAM := WALWIDTH div 4;
        UL := UL + WALWIDTH;
        LR := LR - WALWIDTH;
        SHFTPOS( X4DRAW, Y4DRAW, 0, 1);
        LIGHTDIS := LIGHTDIS - 1
      end
  end;  { DRAWMAZE }


  { ── READMAZE ─────────────────────────────────────────────────────────────── }

  procedure READMAZE;
  begin
    LOADTMAZE( MAZELEV - 1, MAZE)
  end;


  { ── PRSTATS ──────────────────────────────────────────────────────────────── }

  procedure PRSTATS;
  var
    SAVE1    : SmallInt;
    TEMPX    : SmallInt;
    CHARX    : SmallInt;
    CHARREC  : ^TCHAR;   { used for pointer-swap sort }
    ANYALIVE : Boolean;


    procedure PRSTATUS;
    begin
      if Byte( CHARREC.STATUS) = Byte( OK) then
        begin
          ANYALIVE := true;
          if CHARREC.LOSTXYL[ 1] = 0 then
            PRINTNUM( CHARREC.HPMAX, 4)
          else
            PRINTSTR( 'POISON')
        end
      else
        PRINTSTR( SCNTOC_STATUS[ Byte( CHARREC.STATUS)])
    end;


  begin  { PRSTATS }
    for CHARX := 0 to PARTYCNT - 2 do
      for TEMPX := CHARX + 1 to PARTYCNT - 1 do
        if Byte( CHARACTR[ CHARX].STATUS) >
           Byte( CHARACTR[ TEMPX].STATUS) then
          begin
            CHARREC         := CHARACTR[ CHARX];
            CHARACTR[ CHARX]:= CHARACTR[ TEMPX];
            CHARACTR[ TEMPX]:= CHARREC;
            SAVE1            := CHARDISK[ CHARX];
            CHARDISK[ CHARX] := CHARDISK[ TEMPX];
            CHARDISK[ TEMPX] := SAVE1
          end;
    CLRRECT( 1, 17, 38, 6);
    ANYALIVE := false;
    for CHARX := 0 to PARTYCNT - 1 do
      begin
        CHARREC := CHARACTR[ CHARX];
        MVCURSOR( 1, 17 + CHARX);
        PRINTNUM( CHARX + 1, 1);
        PRINTSTR( ' ');
        PRINTSTR( CHARREC.NAME);
        MVCURSOR( 19, 17 + CHARX);
        PRINTSTR( Copy( SCNTOC_ALIGN[ Byte( CHARREC.ALIGN)], 1, 1));
        PRINTCHR( '-');
        PRINTSTR( Copy( SCNTOC_CLASS[ Byte( CHARREC.XCLASS)], 1, 3));
        LLBASE04 := CHARREC.ARMORCL - ACMOD2;
        if LLBASE04 >= 0 then
          PRINTNUM( LLBASE04, 3)
        else
          if LLBASE04 > -10 then
            begin
              PRINTSTR( ' -');
              PRINTNUM( Abs( LLBASE04), 1)
            end
          else
            PRINTSTR( ' LO');
        if Byte( CHARREC.STATUS) >= Byte( DEAD) then
          CHARREC.HPLEFT := 0;
        PRINTNUM( CHARREC.HPLEFT, 5);
        TEMPX := CHARREC.HEALPTS - CHARREC.LOSTXYL[ 1];
        if TEMPX = 0 then
          PRINTCHR( ' ')
        else if TEMPX < 0 then
          PRINTCHR( '-')
        else
          PRINTCHR( '+');
        PRSTATUS
      end;
    if not ANYALIVE then
      begin
        XGOTO  := XCEMETRY;
        _done  := true; exit
      end
  end;  { PRSTATS }


  { ── ENCOUNTR ─────────────────────────────────────────────────────────────── }

  procedure ENCOUNTR;
  var
    ENCTYPE  : SmallInt;
    ENEMYI   : SmallInt;
    ENCCALC  : SmallInt;
    ENCREC   : ^TENMYCALC;
  begin
    ENCB4RUN := true;
    CLRRECT( 1, 11, 38, 4);
    MVCURSOR( 14, 12);
    PRINTSTR( 'AN ENCOUNTER');
    ENCTYPE := 1;
    while (Random( 4) = 2) and (ENCTYPE < 3) do
      ENCTYPE := ENCTYPE + 1;
    ENCREC := MAZE.ENMYCALC[ ENCTYPE];
    ENCCALC := 0;
    while (Random( 100) < ENCREC.PERCWORS) and (ENCCALC < ENCREC.WORSE01) do
      ENCCALC := ENCCALC + 1;
    ENEMYI := ENCREC.MINENEMY + Random( ENCREC.RANGE0N) + (ENCREC.MULTWORS * ENCCALC);
    if CHSTALRM = 1 then
      ATTK012 := 2
    else
      if MZ_FGT( MAZEX, MAZEY) = 1 then
        if FIGHTMAP[ MAZEX][ MAZEY] then
          ATTK012 := 2
        else
          ATTK012 := 1
      else
        ATTK012 := 0;
    ENEMYINX := ENEMYI;
    XGOTO    := XCOMBAT;
    _done    := true; exit
  end;  { ENCOUNTR }


  { ── RUNMAIN ──────────────────────────────────────────────────────────────── }

  procedure RUNMAIN;


    procedure EXITRUN( MAZELVL: SmallInt);
    begin
      MAZELEV := MAZELVL;
      CLEARPIC;
      XGOTO  := XNEWMAZE;
      _done  := true; exit
    end;


    procedure SPECSQAR;
    var
      SQTYPE : SmallInt;


      procedure SPINDIR;
      begin
        DIRECTIO := Random( 4);
        DRAWMAZE
      end;


      procedure QUIETXFR;
      begin
        MAZEX := MAZE.AUX2[ SQTYPE];
        MAZEY := MAZE.AUX1[ SQTYPE];
        if MAZELEV <> MAZE.AUX0[ SQTYPE] then
          begin EXITRUN( MAZE.AUX0[ SQTYPE]); if _done then exit end
      end;


      procedure ACHUTE;
      begin
        PRINTSTR( 'A CHUTE!');
        QUIETXFR
      end;


      procedure STAIRSYN;
      begin
        PRINTSTR( 'STAIRS GOING ');
        if MAZELEV > MAZE.AUX0[ SQTYPE] then
          PRINTSTR( 'UP.')
        else
          PRINTSTR( 'DOWN.');
        MVCURSOR( 1, 12);
        PRINTSTR( 'TAKE THEM (Y/N) ?');
        repeat GETKEY until (INCHAR = 'Y') or (INCHAR = 'N');
        if INCHAR = 'Y' then
          begin QUIETXFR; if _done then exit end
      end;


      procedure VERYDARK;
      begin
        MVCURSOR( 2, 5); PRINTSTR( 'IT''S VERY');
        MVCURSOR( 2, 6); PRINTSTR( 'DARK HERE');
        LIGHT := 0
      end;


      procedure ROCKWATR;
      var
        HPDAM   : SmallInt;
        HPTIMES : SmallInt;
        PARTYI  : SmallInt;
        PREC    : ^TCHAR;
      begin
        Write( Chr( 7));
        PAUSE2;
        for PARTYI := 0 to PARTYCNT - 1 do
          begin
            PREC := CHARACTR[ PARTYI];
            if Byte( PREC.STATUS) < Byte( DEAD) then
              if (Random( 25) + MAZELEV) > PREC.ATTRIB[ AGILITY] then
                begin
                  HPDAM := MAZE.AUX0[ SQTYPE];
                  for HPTIMES := 1 to MAZE.AUX2[ SQTYPE] do
                    HPDAM := HPDAM + Random( MAZE.AUX1[ SQTYPE]) + 1;
                  PREC.HPLEFT := PREC.HPLEFT - HPDAM;
                  if PREC.HPLEFT < 0 then
                    begin
                      PREC.HPLEFT := 0;
                      PREC.STATUS := DEAD;
                      CLRRECT( 1, 11, 38, 1);
                      MVCURSOR( 1, 11);
                      PRINTSTR( PREC.NAME);
                      PRINTSTR( ' DIED');
                      PAUSE2
                    end
                end
          end;
        PRSTATS; if _done then exit
      end;


      procedure APIT;
      begin
        PRINTSTR( 'A PIT!');
        ROCKWATR; if _done then exit
      end;


      procedure OUCH;
      begin
        PRINTSTR( 'OUCH!');
        ROCKWATR; if _done then exit
      end;


      procedure DOSCNMSG;
      begin
        LLBASE04 := SQTYPE;
        XGOTO    := XSCNMSG;
        XGOTO2   := XRUNNER;
        _done    := true; exit
      end;


      procedure CHENCOUN;
      var
        UNUSEDXX : SmallInt;
        UNUSEDYY : SmallInt;
      begin
        if MAZE.AUX0[ SQTYPE] = 0 then exit;
        if not FIGHTMAP[ MAZEX][ MAZEY] then exit;
        MVCURSOR( 14, 12);
        PRINTSTR( 'AN ENCOUNTER');
        ENCB4RUN := false;
        ATTK012  := 2;
        XGOTO    := XCOMBAT;
        ENEMYINX := MAZE.AUX2[ SQTYPE];
        if MAZE.AUX1[ SQTYPE] > 1 then
          ENEMYINX := ENEMYINX + Random( MAZE.AUX1[ SQTYPE]);
        if MAZE.AUX0[ SQTYPE] > 0 then
          begin
            MAZE.AUX0[ SQTYPE] := MAZE.AUX0[ SQTYPE] - 1;
            if MAZE.AUX0[ SQTYPE] = 0 then
              MAZE.SQRETYPE[ SQTYPE] := Byte( NORMAL);
            SAVETMAZE( MAZELEV - 1, MAZE);
          end;
        _done := true; exit
      end;


      procedure BUTTONS;
      var
        MAXBUT   : SmallInt;
        MINBUT   : SmallInt;
        UNUSEDXX : SmallInt;
        UNUSEDYY : SmallInt;
      begin
        MINBUT := MAZE.AUX2[ SQTYPE];
        MAXBUT := MAZE.AUX1[ SQTYPE];
        PRINTSTR( 'THERE ARE BUTTONS ON THE WALL');
        MVCURSOR( 1, 12);
        PRINTSTR( 'MARKED A THROUGH ');
        PRINTCHR( Chr( Ord( 'A') + MAXBUT - MINBUT));
        PRINTCHR( '.');
        MVCURSOR( 1, 14);
        PRINTSTR( 'PRESS ONE (OR RETURN TO LEAVE THEM)');
        repeat
          GETKEY
        until (INCHAR = Chr( CRETURN)) or
              ((INCHAR >= 'A') and
               (INCHAR <= Chr( Ord( 'A') + MAXBUT - MINBUT)));
        CLRRECT( 1, 11, 38, 4);
        if INCHAR = Chr( CRETURN) then exit;
        if MAZE.AUX0[ SQTYPE] > 0 then
          begin
            MAZEX := Random( 20);
            MAZEY := Random( 20)
          end;
        EXITRUN( MINBUT + Ord( INCHAR) - Ord( 'A'))
      end;


    begin  { SPECSQAR }
      CLRRECT( 1, 11, 38, 4);
      MVCURSOR( 1, 11);
      SQTYPE   := MZ_SQR( MAZEX, MAZEY);
      FIZZLES  := 0;
      NEEDDRMZ := true;
      case MAZE.SQRETYPE[ SQTYPE] of
        Byte( FIZZLE):   FIZZLES := 1;
        Byte( ROCKWATE): begin
                           MAZELEV := -99;
                           XGOTO   := XNEWMAZE;
                           _done   := true; exit
                         end;
        Byte( BUTTONZ):  BUTTONS;
        Byte( STAIRS):   if INITTURN then STAIRSYN;
        Byte( PIT):      if INITTURN then APIT;
        Byte( OUCHY):    OUCH;
        Byte( CHUTE):    ACHUTE;
        Byte( SPINNER):  if INITTURN then SPINDIR;
        Byte( TRANSFER): QUIETXFR;
        Byte( DARK):     VERYDARK;
        Byte( SCNMSG):   DOSCNMSG;
        Byte( ENCOUNTE): CHENCOUN;
      end;
      if _done then exit
    end;  { SPECSQAR }


    procedure UPDATEHP;
    var
      CHARX   : SmallInt;
      CHREC   : ^TCHAR;
    begin
      for CHARX := 0 to PARTYCNT - 1 do
        begin
          CHREC := CHARACTR[ CHARX];
          if Random( 4) = 2 then
            CHREC.HPLEFT := CHREC.HPLEFT - CHREC.LOSTXYL[ 1] + CHREC.HEALPTS;
          if CHREC.HPLEFT <= 0 then
            begin
              CHREC.LOSTXYL[ 1] := 0;
              if Byte( CHREC.STATUS) < Byte( DEAD) then
                begin
                  MVCURSOR( 1, 11);
                  PRINTSTR( CHREC.NAME);
                  PRINTSTR( ' DIED');
                  PAUSE2;
                  CLRRECT( 1, 11, 38, 1);
                  CHREC.HPLEFT := 0;
                  CHREC.STATUS := DEAD;
                  PRSTATS; if _done then exit
                end
            end
          else
            if CHREC.HPLEFT > CHREC.HPMAX then
              CHREC.HPLEFT := CHREC.HPMAX
        end  { for }
    end;  { UPDATEHP }


    procedure MOVEFRWD;
    begin
      NEEDDRMZ := true;
      INITTURN := true;
      SAVEX    := MAZEX;
      SAVEY    := MAZEY;
      SAVELEV  := MAZELEV;
      case Byte( DIRECTIO) of
        NORTH: MAZEY := MAZEY + 1;
        EAST:  MAZEX := MAZEX + 1;
        SOUTH: MAZEY := MAZEY - 1;
        WEST:  MAZEX := MAZEX - 1;
      end;
      MAZEY := (MAZEY + 20) mod 20;
      MAZEX := (MAZEX + 20) mod 20
    end;


    procedure BUMPWALL;
    begin
      CLRRECT( 4, 3, 5, 1);
      MVCURSOR( 4, 3);
      PRINTSTR( 'OUCH!');
      Write( Chr( 7))
    end;


    procedure FORWRD;
    begin
      case Byte( DIRECTIO) of
        NORTH: if MZ_N( MAZEX, MAZEY) = Byte( OPEN) then MOVEFRWD;
        EAST:  if MZ_E( MAZEX, MAZEY) = Byte( OPEN) then MOVEFRWD;
        SOUTH: if MZ_S( MAZEX, MAZEY) = Byte( OPEN) then MOVEFRWD;
        WEST:  if MZ_W( MAZEX, MAZEY) = Byte( OPEN) then MOVEFRWD;
      end;
      if not INITTURN then BUMPWALL
    end;


    procedure KICK;
    begin
      case Byte( DIRECTIO) of
        NORTH: if MZ_N( MAZEX, MAZEY) <> Byte( WALL) then MOVEFRWD;
        EAST:  if MZ_E( MAZEX, MAZEY) <> Byte( WALL) then MOVEFRWD;
        SOUTH: if MZ_S( MAZEX, MAZEY) <> Byte( WALL) then MOVEFRWD;
        WEST:  if MZ_W( MAZEX, MAZEY) <> Byte( WALL) then MOVEFRWD;
      end;
      if not INITTURN then BUMPWALL
    end;


    procedure DOTURN( LEFTRIGH: SmallInt);
    begin
      NEEDDRMZ := true;
      DIRECTIO := (DIRECTIO + LEFTRIGH) mod 4
    end;


    procedure SETTIME;
    var
      TIMEVAL : SmallInt;
      TIMESTR : string;

      procedure EXITTIME;
      begin
        CLRRECT( 1, 13, 38, 1)
      end;

    begin  { SETTIME }
      MVCURSOR( 1, 13);
      PRINTSTR( 'NEW DELAY (1-5000) >');
      GETSTR( TIMESTR, 21, 13);
      TIMEVAL := 0;
      if Length( TIMESTR) > 4 then
        begin EXITTIME; exit end;
      for LLBASE04 := 1 to Length( TIMESTR) do
        if (TIMESTR[ LLBASE04] >= '0') and
           (TIMESTR[ LLBASE04] <= '9') then
          TIMEVAL := 10 * TIMEVAL +
                     Ord( TIMESTR[ LLBASE04]) - Ord( '0')
        else
          begin EXITTIME; exit end;
      if (TIMEVAL > 0) and (TIMEVAL <= 5000) then
        TIMEDLAY := TIMEVAL;
      EXITTIME
    end;  { SETTIME }


    procedure QUIKPLOT;
    begin
      MVCURSOR( 1, 13);
      PRINTSTR( 'QUICK PLOT ');
      QUICKPLT := not QUICKPLT;
      if QUICKPLT then
        PRINTSTR( 'ON')
      else
        PRINTSTR( 'OFF');
      DRAWMAZE;
      CLRRECT( 1, 13, 38, 1)
    end;


    procedure RUNINIT;
    begin
      CLRRECT( 13, 1, 26, 4);
      CLRRECT( 13, 6, 26, 4);
      MVCURSOR( 13, 1); PRINTSTR( 'F)ORWARD  C)AMP    S)TATUS');
      MVCURSOR( 13, 2); PRINTSTR( 'L)EFT     Q)UICK   A<-W->D');
      MVCURSOR( 13, 3); PRINTSTR( 'R)IGHT    T)IME    CLUSTER');
      MVCURSOR( 13, 4); PRINTSTR( 'K)ICK     I)NSPECT');
      MVCURSOR( 13, 7); PRINTSTR( 'SPELLS :');
      GRAPHICS;
      PRSTATS; if _done then exit;
      NEEDDRMZ := true;
      INITTURN := true
    end;


  begin  { RUNMAIN }
    RUNINIT;
    if _done then exit;
    repeat
      MVCURSOR( 22, 7);
      if LIGHT > 0 then
        PRINTSTR( 'LIGHT')
      else
        PRINTSTR( '     ');
      MVCURSOR( 22, 8);
      if ACMOD2 > 0 then
        PRINTSTR( 'PROTECT')
      else
        PRINTSTR( '       ');
      if NEEDDRMZ then DRAWMAZE;
      if MAZE.SQRETYPE[ MZ_SQR( MAZEX, MAZEY)] <> Byte( NORMAL) then
        if XGOTO2 <> XSCNMSG then
          if INITTURN then
            begin SPECSQAR; if _done then exit end;
      if XGOTO2 <> XSCNMSG then
        if INITTURN then
          CLRRECT( 1, 11, 38, 4);
      XGOTO2   := XRUNNER;
      NEEDDRMZ := false;
      if ((Random( 99) = 35) or (CHSTALRM = 1) or FIGHTMAP[ MAZEX][ MAZEY]) or
         (INITTURN and (INCHAR = Chr( 75)) and
          (MZ_FGT( MAZEX, MAZEY) = 1) and (Random( 8) = 3))
      then
        begin ENCOUNTR; if _done then exit end;
      if INITTURN then
        begin UPDATEHP; if _done then exit end;
      INITTURN := false;
      GETKEY;
      case INCHAR of
        'F', 'W': FORWRD;
        'A', 'L': DOTURN( 3);
        'D', 'R': DOTURN( 1);
        'K':      KICK;
        'S':      begin PRSTATS; if _done then exit end;
        'T':      SETTIME;
        'Q':      QUIKPLOT;
        'C':      begin
                    XGOTO := XINSPCT2;
                    Write( Chr( 12));
                    _done := true; exit
                  end;
        'I':      begin
                    XGOTO := XINSAREA;
                    Write( Chr( 12));
                    _done := true; exit
                  end;
      end
    until false
  end;  { RUNMAIN }


  { ── CLROOMFG ─────────────────────────────────────────────────────────────── }

  procedure CLROOMFG( XLOOP, YLOOP: SmallInt);
  begin
    XLOOP := (XLOOP + 20) mod 20;
    YLOOP := (YLOOP + 20) mod 20;
    if not FIGHTMAP[ XLOOP][ YLOOP] then exit;
    FIGHTMAP[ XLOOP][ YLOOP] := false;
    if MZ_N( XLOOP, YLOOP) = Byte( OPEN) then CLROOMFG( XLOOP,   YLOOP + 1);
    if MZ_E( XLOOP, YLOOP) = Byte( OPEN) then CLROOMFG( XLOOP+1, YLOOP);
    if MZ_S( XLOOP, YLOOP) = Byte( OPEN) then CLROOMFG( XLOOP,   YLOOP - 1);
    if MZ_W( XLOOP, YLOOP) = Byte( OPEN) then CLROOMFG( XLOOP-1, YLOOP)
  end;


  { ── RUNNER main body ─────────────────────────────────────────────────────── }

begin  { RUNNER }
  QUICKPLT := false;
  READMAZE;
  CLROOMFG( MAZEX, MAZEY);
  _done := false;
  repeat
    RUNMAIN;
    if _done then exit
  until false
end;  { RUNNER }


end.
