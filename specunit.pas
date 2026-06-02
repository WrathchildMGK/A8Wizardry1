unit SPECUNIT;

{ Wizardry I — SPECIALS segment.
  Source: apple/wiz1b/SPECIALS + apple/wiz1b/SPECIALS2.
  Key changes from Apple Pascal:
    - EXIT(SPECIALS) from nested procs -> _done := true; exit (flag checked on return)
    - MOVELEFT/SIZEOF record copy -> LOADTCHAR / LOADTMAZE (pointer-aware loaders)
    - Variant record access LOSTXYL.LOCATION[n] -> LOSTXYL[n] (flat array)
    - MAZE.E[x][y] -> MAZE.E^[x][y]
    - GTSERIAL / COPYPROT / FINDFILE dir-scan -> skipped (Atari port)
    - SWITCHLOC flood-fill -> simplified placeholder (TODO: implement fully)
    - MP nesting tested >=7 levels; all procs at original nesting depth. }

interface

uses TYPES, CONSTS, GLOBALS, UTIL, crt;

procedure SPECIALS;

implementation

var
  _done : Boolean;   { set true to simulate EXIT(SPECIALS) from a nested proc }


{ MP cannot type-check ARRAY_OF_PTR[i].FIELD correctly for non-trivial types;
  passing TCHAR by var reference is the one chain that resolves these fields. }
function GETPOSS( var C: TCHAR; IDX: SmallInt): ^TPOSSESS;
begin
  GETPOSS := C.POSS.POSSESS[ IDX]
end;

function GETNAME( var C: TCHAR): string;
begin
  GETNAME := C.NAME
end;

procedure SETSTAT( var C: TCHAR; S: TSTATUS);
begin
  C.STATUS := TSTATUS( Byte( S))
end;

function GETGOLD( var C: TCHAR): TWIZLONG;
begin
  GETGOLD := C.GOLD
end;

procedure SETGOLD( var C: TCHAR; G: TWIZLONG);
begin
  C.GOLD.XLOW  := G.XLOW;
  C.GOLD.XMID  := G.XMID;
  C.GOLD.XHIGH := G.XHIGH
end;


procedure SPECIALS;
var
  SPCINDEX : SmallInt;


  { ────────────────────────────────────────────────────────────────────────── }
  { INSPECT — find and recover lost characters from the current maze room.    }
  { ────────────────────────────────────────────────────────────────────────── }
  procedure INSPECT;
  var
    PICKCNT  : SmallInt;
    PICKLIST : array[ 0..6] of SmallInt;   { AP: 1..6, extended to 0..6 }
    PICKCHAR : SmallInt;
    PICKREC  : TCHAR;
    MAZE     : TMAZE;
    INMYROOM : array[ 0..19, 0..19] of Boolean;
    CHECKED  : array[ 0..19, 0..19] of Boolean;
    DONELOOK : Boolean;


    procedure LOOKLOST;

      procedure FOUNDLOS;
      begin
        if PICKCNT >= 5 then exit;
        PICKCNT := PICKCNT + 1;
        PICKLIST[ PICKCNT] := PICKCHAR;
        Write( PICKCNT); Write( ') ');
        WriteLn( PICKREC.NAME)
      end;

    begin { LOOKLOST }
      PICKCNT := 0;
      Write( Chr( 12)); WriteLn( 'FOUND:'); WriteLn( ''); WriteLn( ''); WriteLn( '');
      for PICKCHAR := 0 to SCNTOC.RECPERDK[ ZCHAR] - 1 do
        begin
          FillChar( PICKREC, SizeOf( TCHAR), 0);
          LOADTCHAR( PICKCHAR, PICKREC);
          if not PICKREC.INMAZE then
            if PICKREC.LOSTXYL[ 3] = MAZELEV then      { AP: LOSTXYL.LOCATION[3] }
              if INMYROOM[ PICKREC.LOSTXYL[ 1], PICKREC.LOSTXYL[ 2]] then
                FOUNDLOS
        end;
      if PICKCNT = 0 then WriteLn( '** NO ONE **')
    end;


    procedure PICKUP;
    begin
      if PARTYCNT = 6 then
        begin
          MVCURSOR( 0, 20); Write( Chr( 11));
          WriteLn( 'YOU HAVE 6 - PRESS [RET]');
          MVCURSOR( 41, 0);
          repeat GETKEY until INCHAR = Chr( CRETURN);
          exit
        end;
      repeat
        MVCURSOR( 0, 20); Write( Chr( 11));
        Write( 'GET WHO (0=EXIT) >');
        GETKEY;
        PICKCHAR := Ord( INCHAR) - Ord( '0');
        if PICKCHAR = 0 then exit
      until (PICKCHAR > 0) and (PICKCHAR <= PICKCNT);
      if PICKLIST[ PICKCHAR] = -1 then exit;
      FillChar( CHARACTR[ PARTYCNT]^, SizeOf( TCHAR), 0);
      LOADTCHAR( PICKLIST[ PICKCHAR], CHARACTR[ PARTYCNT]^);
      CHARDISK[ PARTYCNT]             := PICKLIST[ PICKCHAR];
      CHARACTR[ PARTYCNT].LOSTXYL[1] := 0;
      CHARACTR[ PARTYCNT].LOSTXYL[2] := 0;
      CHARACTR[ PARTYCNT].LOSTXYL[3] := 0;
      CHARACTR[ PARTYCNT].INMAZE     := true;
      SAVETCHAR( PICKLIST[ PICKCHAR], CHARACTR[ PARTYCNT]^);
      PICKLIST[ PICKCHAR] := -1;
      PARTYCNT := PARTYCNT + 1;
      MVCURSOR( 0, 3 + PICKCHAR); Write( Chr( 29))
    end;


    procedure EXPLROOM;
    var
      VERT, HORZ : SmallInt;

      procedure CHECKLOC( X, Y, WALL: SmallInt);
      begin
        if WALL <> Ord( OPEN) then exit;
        X := (X + 20) mod 20;
        Y := (Y + 20) mod 20;
        if INMYROOM[ X][ Y] then exit;
        DONELOOK := false;
        INMYROOM[ X][ Y] := true
      end;

    begin { EXPLROOM }
      LOADTMAZE( MAZELEV - 1, MAZE);
      FillChar( INMYROOM, SizeOf( INMYROOM), 0);
      INMYROOM[ MAZEX][ MAZEY] := true;
      FillChar( CHECKED, SizeOf( CHECKED), 0);
      repeat
        Write( '.');
        DONELOOK := true;
        for HORZ := 0 to 19 do
          for VERT := 0 to 19 do
            if INMYROOM[ HORZ][ VERT] and not CHECKED[ HORZ][ VERT] then
              begin
                CHECKLOC( HORZ+1, VERT,   MAZE.E^[ HORZ*20+VERT]);
                CHECKLOC( HORZ-1, VERT,   MAZE.W^[ HORZ*20+VERT]);
                CHECKLOC( HORZ,   VERT-1, MAZE.S^[ HORZ*20+VERT]);
                CHECKLOC( HORZ,   VERT+1, MAZE.N^[ HORZ*20+VERT]);
                CHECKED[ HORZ][ VERT] := true
              end
      until DONELOOK
    end;


  begin  { INSPECT }
    Write( Chr( 12)); Write( 'LOOKING');
    TEXTMODE; EXPLROOM; LOOKLOST;
    repeat
      MVCURSOR( 0, 20); Write( 'OPTIONS: ');
      if PICKCNT > 0 then Write( 'P)ICK UP, ');
      Write( 'L)EAVE');
      repeat MVCURSOR( 41, 0); GETKEY until (INCHAR = 'P') or (INCHAR = 'L');
      if INCHAR = 'P' then if PICKCNT > 0 then PICKUP
    until INCHAR = 'L';
    XGOTO  := XRUNNER;
    GRAPHICS;
    _done  := true
  end;  { INSPECT }


  { ────────────────────────────────────────────────────────────────────────── }
  { INITGAME — first-time initialisation: find scenario, load SCNTOC, draw   }
  { the main maze screen.  Copy-protection removed for Atari port.            }
  { ────────────────────────────────────────────────────────────────────────── }
  procedure INITGAME;

    procedure MAZESCRN;

      procedure HORZHYPH;
      var I : SmallInt;
      begin
        for I := 1 to 38 do PRINTCHR( Chr( 34))   { hyphen graphic }
      end;

      procedure SCRNOUTL;
      var I : SmallInt;
      begin
        MVCURSOR( 0, 0); PRINTCHR( Chr( 33));
        for I := 1 to 38 do PRINTCHR( Chr( 34));
        PRINTCHR( Chr( 35));
        for I := 1 to 22 do
          begin
            MVCURSOR( 0,  I); PRINTCHR( Chr( 36));
            MVCURSOR( 39, I); PRINTCHR( Chr( 36))
          end;
        MVCURSOR( 0, 23); PRINTCHR( Chr( 37));
        for I := 1 to 38 do PRINTCHR( Chr( 34));
        PRINTCHR( Chr( 38))
      end;

      procedure HORZLINE( LINE: SmallInt);
      begin
        MVCURSOR( 0, LINE); PRINTCHR( Chr( 39)); HORZHYPH; PRINTCHR( Chr( 40))
      end;

      procedure INITSCRN;
      var I : SmallInt;
      begin
        CLRRECT( 0, 0, 40, 24);
        { TODO: load border charset from block SCNTOCBL+2 into CHARSET }
        SCRNOUTL; HORZLINE( 10); HORZLINE( 15);
        MVCURSOR( 12, 0); PRINTCHR( Chr( 91));
        for I := 1 to 9 do begin MVCURSOR( 12, I); PRINTCHR( Chr( 92)) end;
        MVCURSOR( 12, 5); PRINTCHR( Chr( 93));
        for I := 13 to 38 do PRINTCHR( Chr( 34));
        PRINTCHR( Chr( 40));
        MVCURSOR( 12, 10); PRINTCHR( Chr( 94));
        { TODO: load combat charset from block SCNTOCBL+1 into CHARSET }
        MVCURSOR( 1, 16);
        PRINTSTR( '# CHARACTER NAME  CLASS AC HITS STATUS')
      end;

    begin { MAZESCRN }
      CLRRECT( 0, 0, 40, 24);
      INITSCRN
    end;


  begin  { INITGAME }
    if LLBASE04 = -1 then
      begin
        repeat
          Write( Chr( 12)); GotoXY( 0, 11);
          Write( ' SCENARIO DISK IN DRIVE, PRESS [RETURN]');
          repeat MVCURSOR( 41, 0); GETKEY until INCHAR = Chr( CRETURN);
          SCNTOCBL := FINDFILE( DRIVE1, 'SCENARIO.DATA')
        until SCNTOCBL >= 0;
        TIMEDLAY := 2000;
        CACHEWRI := false;
        CACHEBL  := -1;
        UNITREAD( SCNTOCBL);
        LOADSCNTOC;
      end;
    XGOTO    := XCASTLE;
    Write( Chr( 12)); TEXTMODE; MAZESCRN;
    MAZEX    := 0; MAZEY    := 0; MAZELEV  := 0;
    PARTYCNT := 0; DIRECTIO := 0; ACMOD2   := 0;
    _done    := true
  end;  { INITGAME }


  { ────────────────────────────────────────────────────────────────────────── }
  { SPCMISC — special-square event handler (messages, traps, fees, etc.)     }
  { ────────────────────────────────────────────────────────────────────────── }
  procedure SPCMISC;
  var
    MESSAGE  : array[ 0..511] of Char;
    STRBUFF  : TSTRBUFF;
    MSGX     : SmallInt;
    MSGBLK   : SmallInt;
    CURMSGBL : SmallInt;
    MSGBLK0  : SmallInt;
    BOUNCEFL : SmallInt;
    AUX0     : SmallInt;
    AUX1     : SmallInt;
    AUX2     : SmallInt;
    MAZEFLOR : TMAZE;


    procedure DECRYPTM( MSGINDEX: SmallInt);
    begin
      MSGBLK := MSGINDEX div 12;
      MSGX   := 42 * (MSGINDEX mod 12);
      if MSGBLK <> CURMSGBL then
        begin
          UNITREAD_MSG( MSGBLK0 + MSGBLK, MESSAGE[0]);
          CURMSGBL := MSGBLK
        end;
      Move( MESSAGE[ MSGX], STRBUFF.BUFF, 42)
    end;


    procedure DOMSG( MSGLINEX: SmallInt; PRESSRET: Boolean);
    var
      LINECNT : SmallInt;

      procedure DO1LINE;
      begin
        if LINECNT = 15 then
          begin
            CLRRECT( 13, 6, 26, 4); MVCURSOR( 19, 7); PRINTSTR( '[RET] FOR MORE');
            repeat GETKEY until INCHAR = Chr( CRETURN);
            CLRRECT( 13, 6, 26, 4); CLRRECT( 1, 11, 38, 4);
            LINECNT := 11
          end;
        DECRYPTM( MSGLINEX);
        MVCURSOR( 1, LINECNT); PRINTSTR( STRBUFF.BUFF);
        MSGLINEX := MSGLINEX + 1;
        LINECNT  := LINECNT  + 1
      end;

    begin { DOMSG }
      LINECNT := 11;
      repeat DO1LINE until STRBUFF.ENDMSG;
      if PRESSRET then
        begin
          CLRRECT( 13, 6, 26, 4); MVCURSOR( 21, 7); PRINTSTR( 'PRESS [RET]');
          repeat GETKEY until INCHAR = Chr( CRETURN);
          CLRRECT( 13, 6, 26, 4)
        end
    end;


    function GOTITEM( CHARX, ITEMX: SmallInt): Boolean;
    var POSSX : SmallInt; PP : ^TPOSSESS;
    begin
      GOTITEM := false;
      if CHARACTR[ CHARX].POSS.POSSCNT = 8 then exit;
      for POSSX := 1 to CHARACTR[ CHARX].POSS.POSSCNT do
        begin
          PP := GETPOSS( CHARACTR[ CHARX]^, POSSX);
          if PP.EQINDEX = ITEMX then exit
        end;
      CLRRECT( 1, 11, 38, 4); MVCURSOR( 1, 11);
      PRINTSTR( GETNAME( CHARACTR[ CHARX]^)); PRINTSTR( ' GOT ITEM');
      POSSX := CHARACTR[ CHARX].POSS.POSSCNT + 1;
      CHARACTR[ CHARX].POSS.POSSCNT := POSSX;
      PP := GETPOSS( CHARACTR[ CHARX]^, POSSX);
      PP.EQINDEX := ITEMX;
      PP.EQUIPED := false;
      PP.CURSED  := false;
      GOTITEM := true
    end;


    procedure TRYGET;
    var GOTONE : Boolean; CHARX : SmallInt;
    begin
      GOTONE := false;
      for CHARX := 0 to PARTYCNT - 1 do
        if not GOTONE then GOTONE := GOTITEM( CHARX, AUX0)
    end;


    procedure BOUNCEBK;
    begin
      case Byte( DIRECTIO) of
        0: MAZEY := MAZEY - 1;
        1: MAZEX := MAZEX - 1;
        2: MAZEY := MAZEY + 1;
        3: MAZEX := MAZEX + 1
      end;
      MAZEY := (MAZEY + 20) mod 20;
      MAZEX := (MAZEX + 20) mod 20;
      if AUX1 >= 0 then DOMSG( AUX1, false)
    end;


    procedure WHOWADE;
    var
      WADEX : SmallInt;
      TC    : ^TCHAR;

      procedure MAKWORSE( THISSTAT: TSTATUS);
      var CURSTAT : Byte;
      begin
        CURSTAT := CHARACTR[ WADEX].STATUS;      { read: auto-deref is BYTE }
        if Byte( THISSTAT) > CURSTAT then
          CHARACTR[ WADEX].STATUS := TSTATUS( Byte( THISSTAT))
      end;

    begin { WHOWADE }
      CLRRECT( 1, 11, 38, 4); MVCURSOR( 2, 12);
      PRINTSTR( '#) TO WADE, [RET] EXITS');
      WADEX := GETCHARX( false, '');
      if WADEX < 0 then exit;
      TC := CHARACTR[ WADEX];
      if AUX0 = -1 then AUX0 := Random( 7);
      case Byte( AUX0) of
        0: if TC.STATUS < DEAD then
             begin
               TC.STATUS := OK;
               TC.HPMAX  := TC.HPMAX - 8;
               TC.HPLEFT := TC.HPMAX;
               if TC.HPMAX <= 0 then MAKWORSE( DEAD)
             end;
        1: if (TC.ATTRIB[ IQ] = 3) or
              (TC.ATTRIB[ PIETY] = 3) then
             MAKWORSE( DEAD)
           else
             begin
               TC.AGE := TC.AGE - 52;
               TC.ATTRIB[ IQ]    := TC.ATTRIB[ IQ]    - 1;
               TC.ATTRIB[ PIETY] := TC.ATTRIB[ PIETY] - 1
             end;
        2: TC.LOSTXYL[ 1] := 1;  { POISNAMT[1] := 1 }
        3: MAKWORSE( ASLEEP);
        4: MAKWORSE( PLYZE);
        5: MAKWORSE( STONED);
        6: if TC.STATUS = DEAD then
             begin
               if Random( 10) < 3 then
                 begin
                   TC.STATUS := OK;
                   TC.HPLEFT := TC.HPMAX
                 end
               else
                 SETSTAT( CHARACTR[ WADEX]^, ASHES)
             end
      end
    end;


    procedure GETYN;
    begin
      CLRRECT( 1, 11, 38, 4); MVCURSOR( 1, 11); PRINTSTR( 'SEARCH (Y/N) ?');
      repeat GETKEY until (INCHAR = 'Y') or (INCHAR = 'N');
      if INCHAR = 'N' then begin _done := true; exit end;
      if AUX0 > 0 then
        begin ATTK012 := 0; ENEMYINX := AUX0; XGOTO := XCOMBAT end
      else
        begin AUX0 := Abs( AUX0); TRYGET end
    end;


    procedure ITM2PASS;
    var POSX, CHARX : SmallInt; PP : ^TPOSSESS;
    begin
      for CHARX := 0 to PARTYCNT - 1 do
        for POSX := 1 to CHARACTR[ CHARX].POSS.POSSCNT do
          begin
            PP := GETPOSS( CHARACTR[ CHARX]^, POSX);
            if PP.EQINDEX = AUX0 then exit
          end;
      BOUNCEBK  { no party member carries AUX0 item — block passage }
    end;


    procedure CHKALIGN;
    var CHARX : SmallInt;
    begin
      for CHARX := 0 to PARTYCNT - 1 do
        case TALIGN( CHARACTR[ CHARX].ALIGN) of
          GOOD:    if (AUX0 = 0) or (AUX0 = 2) or
                      (AUX0 = 4) or (AUX0 = 6) then BOUNCEBK;
          NEUTRAL: if (AUX0 = 0) or (AUX0 = 1) or
                      (AUX0 = 4) or (AUX0 = 5) then BOUNCEBK;
          EVIL:    if AUX0 < 4 then BOUNCEBK
        end
    end;


    procedure CHKAUX0;
    begin
      if      AUX0 =  99 then LIGHT := LIGHT + 50
      else if AUX0 = -99 then LIGHT := 0
      else                     ACMOD2 := AUX0
    end;


    procedure BCK2SHOP;
    begin
      MAZELEV := 0; Write( Chr( 12)); XGOTO := XNEWMAZE
    end;


    procedure RIDDLES;
    var ANSWER : string[ 40];
    begin
      CLRRECT( 1, 11, 38, 4); MVCURSOR( 1, 11); PRINTSTR( 'ANSWER ?');
      GETSTR( ANSWER, 1, 13);
      DECRYPTM( AUX0);
      CLRRECT( 1, 11, 38, 4); MVCURSOR( 1, 11);
      if STRBUFF.BUFF <> ANSWER then
        begin AUX1 := -1; PRINTSTR( 'WRONG!'); BOUNCEBK end
      else
        PRINTSTR( 'RIGHT!')
    end;


    procedure FEEIS;
    var
      FEE     : TWIZLONG;
      GOLDTOT : TWIZLONG;

      procedure FEE2LONG;
      var MULT10, STRX : SmallInt;
      begin
        if STRBUFF.BUFF[ 1] >= '@' then
          begin
            BOUNCEFL := Ord( STRBUFF.BUFF[ 1]) - Ord( 'A') + 1;
            STRBUFF.BUFF := Copy( STRBUFF.BUFF, 2, Length( STRBUFF.BUFF) - 1)
          end
        else
          BOUNCEFL := 0;
        FillChar( FEE, 6, 0);
        MULT10 := 10;
        for STRX := 1 to Length( STRBUFF.BUFF) do
          begin
            MULTLONG( FEE, MULT10);
            FEE.XLOW := FEE.XLOW + Ord( STRBUFF.BUFF[ STRX]) - Ord( '0')
          end
      end;

      procedure CHKGOLD;
      var CHARX : SmallInt;
      begin
        FillChar( GOLDTOT, 6, 0);
        for CHARX := 0 to PARTYCNT - 1 do
          ADDLONGS( GOLDTOT, GETGOLD( CHARACTR[ CHARX]^));
        if TESTLONG( GOLDTOT, FEE) <> -1 then exit;
        PRINTSTR( 'NOT ENOUGH $');
        if BOUNCEFL = 0 then BOUNCEBK;
        _done := true
      end;

      procedure PAYGOLD;
      var CHARX : SmallInt; LOCALG : TWIZLONG;
      begin
        FillChar( GOLDTOT, 6, 0);
        for CHARX := 0 to PARTYCNT - 1 do
          if TESTLONG( FEE, GOLDTOT) <> 0 then
            begin
              LOCALG := GETGOLD( CHARACTR[ CHARX]^);
              if TESTLONG( FEE, LOCALG) = 1 then
                begin
                  SUBLONGS( FEE, LOCALG);
                  FillChar( LOCALG, 6, 0);
                  SETGOLD( CHARACTR[ CHARX]^, LOCALG)
                end
              else
                begin
                  SUBLONGS( LOCALG, FEE);
                  SETGOLD( CHARACTR[ CHARX]^, LOCALG);
                  FillChar( FEE, 6, 0)
                end
            end;
        PRINTSTR( 'THANKS!')
      end;

    begin { FEEIS }
      DECRYPTM( AUX0); FEE2LONG;
      CLRRECT( 1, 11, 38, 4); MVCURSOR( 1, 11);
      PRINTSTR( 'FEE IS '); PRINTSTR( STRBUFF.BUFF);
      MVCURSOR( 1, 13); PRINTSTR( 'PAY (Y/N) ?');
      repeat GETKEY until (INCHAR = 'Y') or (INCHAR = 'N');
      AUX1 := -1;
      if INCHAR = 'N' then
        begin
          if BOUNCEFL = 0 then BOUNCEBK;
          _done := true; exit
        end
      else
        begin
          CLRRECT( 1, 11, 38, 4); MVCURSOR( 1, 11);
          CHKGOLD;
          if _done then exit;
          PAYGOLD;
          if BOUNCEFL > 0 then
            begin
              MAZEX   := MAZEFLOR.AUX2[ BOUNCEFL];
              MAZEY   := MAZEFLOR.AUX1[ BOUNCEFL];
              MAZELEV := MAZEFLOR.AUX0[ BOUNCEFL];
              XGOTO   := XNEWMAZE
            end
        end
    end;


    procedure LOOKOUT;
    var X, Y, X2, Y2 : SmallInt;
    begin
      for X2 := -AUX0 to AUX0 do
        for Y2 := -AUX0 to AUX0 do
          begin
            X := (MAZEX + X2 + 20) mod 20;
            Y := (MAZEY + Y2 + 20) mod 20;
            FIGHTMAP[ X][ Y] := true
          end;
      FIGHTMAP[ MAZEX][ MAZEY] := false
    end;


    { SWITCHLOC — spinner square.
      AP: flood-fill through doors from current position to find a random
          adjacent room to teleport into, then set direction randomly.
      TODO: implement full door-following algorithm from apple/wiz1b/SPECIALS2
            (P010325-P01032A).  Simplified version used for now. }
    procedure SWITCHLOC;
    begin
      XGOTO2 := XCOMBAT;
      XGOTO  := XRUNNER;
      MAZEX    := Random( 20);
      MAZEY    := Random( 20);
      DIRECTIO := Random( 4);
      _done    := true
    end;


  begin  { SPCMISC }
    LOADTMAZE( MAZELEV - 1, MAZEFLOR);
    BOUNCEFL := SPCINDEX;
    if BOUNCEFL = 0 then
      begin SWITCHLOC; if _done then exit end;
    XGOTO2  := XSCNMSG;
    CLRRECT( 1, 11, 38, 4);
    MSGBLK0 := FINDFILE( DRIVE1, 'SCENARIO.MESGS');
    if MSGBLK0 < 0 then
      begin
        MVCURSOR( 1, 11); PRINTSTR( 'MESGS LOST');
        _done := true; exit
      end;
    CURMSGBL := 0;
    UNITREAD_MSG( MSGBLK0, MESSAGE[0]);
    AUX2  := MAZEFLOR.AUX2[ BOUNCEFL];
    AUX1  := MAZEFLOR.AUX1[ BOUNCEFL];
    AUX0  := MAZEFLOR.AUX0[ BOUNCEFL];
    XGOTO := XRUNNER;
    if AUX2 = 0 then exit;
    if (AUX2 = 1) or (AUX2 = 4) or (AUX2 = 8) then
      begin
        if AUX0 = 0 then exit
        else
          begin
            if AUX2 <> 4 then
              begin
                if AUX0 > 0 then MAZEFLOR.AUX0[ BOUNCEFL] := AUX0 - 1;
                if AUX0 = 1 then MAZEFLOR.SQRETYPE[ BOUNCEFL] := Byte( NORMAL)
              end
            else
              if AUX0 < 0 then
                if AUX0 > -1000 then MAZEFLOR.AUX0[ BOUNCEFL] := 0
                else                  AUX0 := AUX0 + 1000;
            { TODO: SAVETMAZE( MAZELEV-1, MAZEFLOR) }
          end
      end;
    CLRRECT( 1, 11, 38, 4);
    if not ((AUX2 = 5) or (AUX2 = 6)) then
      DOMSG( AUX1, (AUX2 = 2)  or (AUX2 = 3) or (AUX2 = 4) or
                   (AUX2 = 10) or (AUX2 = 11) or (AUX2 = 12));
    case Byte( AUX2) of
       2: TRYGET;
       3: WHOWADE;
       4: GETYN;
       5: ITM2PASS;
       6: CHKALIGN;
       7: CHKAUX0;
       8: BCK2SHOP;
       9: LOOKOUT;
      10: RIDDLES;
      11: FEEIS
    end;
    { _done may have been set by GETYN or FEEIS inside the case }
  end;  { SPCMISC }


  { ────────────────────────────────────────────────────────────────────────── }
  { SPECIALS main body                                                         }
  { ────────────────────────────────────────────────────────────────────────── }
begin
  _done := false;
  if XGOTO = XINSAREA then
    begin INSPECT; if _done then exit end;
  XGOTO    := XGOTO2;
  SPCINDEX := LLBASE04;
  if SPCINDEX < 0 then
    INITGAME
  else
    SPCMISC
end;

end.
