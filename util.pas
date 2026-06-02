(* ---------- BEGIN FORWARD DECLARATIONS ---------- *)

PROCEDURE PRINTBEL; FORWARD;                   (* P010002 *)

FUNCTION GETREC( DATATYPE: TZSCN;              (* P010003 *)
                 DATAINDX: INTEGER;
                 DATASIZE: INTEGER) : INTEGER; FORWARD;
                 
FUNCTION GETRECW( DATATYPE: TZSCN;             (* P010004 *)
                  DATAINDX: INTEGER;
                  DATASIZE: INTEGER) : INTEGER; FORWARD;
                  
PROCEDURE ADDLONGS( VAR FIRST:  TWIZLONG;      (* P010005 *)
                    VAR SECOND: TWIZLONG); FORWARD;
                    
PROCEDURE SUBLONGS( VAR FIRST:  TWIZLONG;      (* P010006 *)
                    VAR SECOND: TWIZLONG); FORWARD;
                    
PROCEDURE BCD2LONG( VAR LONGNUM: TWIZLONG;     (* P010007 *)
                    VAR BCDNUM:  TBCD); FORWARD;
                    
PROCEDURE LONG2BCD( VAR LONGNUM: TWIZLONG;     (* P010008 *)
                    VAR BCDNUM:  TBCD); FORWARD;
                   
PROCEDURE MULTLONG( VAR LONGNUM: TWIZLONG;     (* P010009 *)
                    VAR INTNUM:  INTEGER); FORWARD;

PROCEDURE DIVLONG( VAR LONGNUM: TWIZLONG;      (* P01000A *)
                   VAR INTNUM:  INTEGER); FORWARD;

FUNCTION TESTLONG( FIRST:  TWIZLONG;           (* P01000B *)
                   SECOND: TWIZLONG) : INTEGER; FORWARD;

PROCEDURE PRNTLONG( LONGNUM: TWIZLONG); FORWARD;  (* P01000C *)
                         
PROCEDURE GETKEY; FORWARD;                     (* P01000D *)

PROCEDURE GETLINE( VAR GTSTRING: STRING); FORWARD; (* P01000E *)

FUNCTION GETCHARX( DSPNAMES: BOOLEAN;          (* P01000F *)
                   SOLICIT: STRING) : INTEGER; FORWARD;

PROCEDURE CENTSTR( ASTRING: STRING); FORWARD;  (* P010010 *)

PROCEDURE PAUSE1; FORWARD;                     (* P010011 *)

PROCEDURE PAUSE2; FORWARD;                     (* P010012 *)

PROCEDURE CLEARPIC; FORWARD;                   (* P010013 *)

PROCEDURE GRAPHICS; FORWARD;                   (* P010014 *)

PROCEDURE TEXTMODE; FORWARD;                   (* P010015 *)

PROCEDURE PRINTCHR( ACHAR: CHAR); FORWARD;     (* P010016 *)

PROCEDURE PRINTSTR( ASTRING: STRING); FORWARD; (* P010017 *)

PROCEDURE PRINTNUM( ANUM: INTEGER;             (* P010018 *)
                    FIELDSZ: INTEGER); FORWARD;

PROCEDURE GETSTR( VAR ASTRING: STRING;         (* P010019 *)
                      WINXPOS: INTEGER;
                      WINYPOS: INTEGER); FORWARD;


(* ---------- END FORWARD DECLARATIONS ---------- *)

(* ---------- BEGIN EXTERNALS ------------------- *)


PROCEDURE CLRPICT( A1:  INTEGER;               (* P01001A *)
                   A2:  INTEGER;
                   A3:  INTEGER;
                   A4:  INTEGER); EXTERNAL;

  (* WHEN A4 === 100, THEN CLEAR PICTURE
     WHEN A4 <> 100 AND A4 <> 101 THEN:
     
     DRAWING MAZE USES THIS FOR DRAWING PICTURE (82 X 79 PIXELS).
     
       $0679 = A1   X LOWER BOUNDS (FIRST TIME IT IS 0)
       $06F9 = A2   Y LOWER BOUNDS (0 ALWAYS)
       $0779 = A3   X UPPER BOUNDS (FIRST TIME IT IS 81)
       $07F9 = A4   Y UPPER BOUNDS (79 ALWAYS)
          ...AND NO PICTURE CLEARING           *)
       
PROCEDURE DRAWLINE( X:       INTEGER;          (* P01001B *)
                    Y:       INTEGER;
                    DELTAH:  INTEGER;
                    DELTAV:  INTEGER;
                    LINELEN: INTEGER); EXTERNAL;
 
FUNCTION RANDOM : INTEGER;  EXTERNAL;          (* P01001C *)

  (* RETURNS A VALUE FROM 0 TO 32,767 *)
  

FUNCTION KEYAVAIL : BOOLEAN; EXTERNAL;         (* P01001D *)

PROCEDURE CLRRECT( X:      INTEGER;            (* P01001E *)
                   Y:      INTEGER;
                   WIDTH:  INTEGER;
                   HEIGHT: INTEGER); EXTERNAL;

PROCEDURE MVCURSOR( X: INTEGER;                (* P01001F *)
                    Y: INTEGER); EXTERNAL;
                   
    (* STORE X AT $4F9.  (SLOT #1 RAM SPACE)
       STORE Y AT $579.  (SLOT #1 RAM SPACE)
       
       MVCURSOR( 40, Y)  TURN ON GRAPHICS MODE
       MVCURSOR( 50, Y)  TURN ON TEXT MODE
       MVCURSOR( 60, Y)  JUMP TO $2002  (COPY PROTECTION)
       MVCURSOR( 70, Y)  CRASH AND BURN (COPY PROTECTION)
       MVCURSOR( 80, Y)  ADJUST RANDOM # (UNTIL KEY IS AVAILABLE)
                                      $47A, $47B, $47C, $47D  (???)
                           RNG USES:  $47A, $4FA, $57A, $5FB  (!!!)  *)
       
                    
PROCEDURE PRGRCHR( VAR A1: TCHRIMAG); EXTERNAL; (* P010020 *)

  (* PRINT A CHARACTER TO HI RES SCREEN *)

(* ---------- END EXTERNALS --------------------- *)

  PROCEDURE PRINTBEL;  (* P010002 *)
  
    BEGIN
      WRITE( CHR( 7));
      WRITE( CHR( 7));
      WRITE( CHR( 7))
    END;


  FUNCTION GETREC;  (* P010003 *)
  
    VAR
         BUFFADDR : INTEGER;
         DSKBLOCK : INTEGER;
                        
    BEGIN
      DSKBLOCK := SCNTOC.BLOFF[ DATATYPE] +
                  2 *  (DATAINDX DIV SCNTOC.RECPER2BL[ DATATYPE]);
      BUFFADDR := DATASIZE * (DATAINDX MOD SCNTOC.RECPER2BL[ DATATYPE]);
      IF CACHEBL <> DSKBLOCK THEN
        BEGIN
          IF CACHEWRI THEN
            REPEAT
              UNITWRITE( DRIVE1, IOCACHE, SIZEOF( IOCACHE),
                         (CACHEBL + SCNTOCBL), 0)
            UNTIL IORESULT = 0;
          CACHEWRI := FALSE;
          CACHEBL := DSKBLOCK;
          REPEAT
            UNITREAD( DRIVE1, IOCACHE, SIZEOF( IOCACHE),
                      (CACHEBL + SCNTOCBL), 0)
          UNTIL IORESULT = 0
        END;
      GETREC := BUFFADDR
    END;
         

  FUNCTION GETRECW;  (* P010004 *)
    
    VAR
         BUFFADDR : INTEGER;
         DSKBLOCK : INTEGER;
                        
    BEGIN
    
      DSKBLOCK := SCNTOC.BLOFF[ DATATYPE] +
                  2 *  (DATAINDX DIV SCNTOC.RECPER2BL[ DATATYPE]);
      BUFFADDR := DATASIZE * (DATAINDX MOD SCNTOC.RECPER2BL[ DATATYPE]);
      IF CACHEBL <> DSKBLOCK THEN
        BEGIN
          IF CACHEWRI THEN
            REPEAT
              UNITWRITE( DRIVE1, IOCACHE, SIZEOF( IOCACHE),
                         (CACHEBL + SCNTOCBL), 0)
            UNTIL IORESULT = 0;
          CACHEBL := DSKBLOCK;
          REPEAT
            UNITREAD( DRIVE1, IOCACHE, SIZEOF( IOCACHE),
                      (CACHEBL + SCNTOCBL), 0)
          UNTIL IORESULT = 0;
        END;
      CACHEWRI := TRUE;
      GETRECW := BUFFADDR
    END;
    
    
  PROCEDURE ADDLONGS;  (* P010005 *)
  
    BEGIN
      FIRST.LOW := FIRST.LOW + SECOND.LOW;
      IF FIRST.LOW >= 10000 THEN
        BEGIN
          FIRST.MID := FIRST.MID + 1;
          FIRST.LOW := FIRST.LOW - 10000
        END;
        
      FIRST.MID := FIRST.MID + SECOND.MID;
      IF FIRST.MID >= 10000 THEN
        BEGIN
          FIRST.HIGH := FIRST.HIGH + 1;
          FIRST.MID := FIRST.MID - 10000
        END;
        
      FIRST.HIGH := FIRST.HIGH + SECOND.HIGH;
      IF FIRST.HIGH >= 10000 THEN
        BEGIN
          FIRST.HIGH := 9999;
          FIRST.MID  := 9999;
          FIRST.LOW  := 9999
        END
    END;
    
    
  PROCEDURE SUBLONGS;  (* P010006 *)
  
    BEGIN
      FIRST.LOW := FIRST.LOW - SECOND.LOW;
      IF FIRST.LOW < 0 THEN
        BEGIN
          FIRST.MID := FIRST.MID - 1;
          FIRST.LOW := FIRST.LOW + 10000
        END;
      
      FIRST.MID := FIRST.MID - SECOND.MID;
      IF FIRST.MID < 0 THEN
        BEGIN
          FIRST.HIGH := FIRST.HIGH - 1;
          FIRST.MID := FIRST.MID + 10000
        END;
        
      FIRST.HIGH := FIRST.HIGH - SECOND.HIGH;
      IF FIRST.HIGH < 0 THEN
        BEGIN
          FIRST.HIGH := 0;
          FIRST.MID  := 0;
          FIRST.LOW  := 0
        END
    END;


  PROCEDURE LONG2BCD;  (* P010008 *)
  
    VAR
         DIGITX : INTEGER;
  
  
    PROCEDURE INT2BCD( PARTLONG: INTEGER);  (* P010021 *)
    
      PROCEDURE PUTDIGIT( POWOF10: INTEGER);  (* P010022 *)
      
        BEGIN
          BCDNUM[ DIGITX] := PARTLONG DIV POWOF10;
          DIGITX := DIGITX + 1;
          PARTLONG := PARTLONG MOD POWOF10
        END;
    
    
      BEGIN  (* INT2BCD *)
        PUTDIGIT( 1000);
        PUTDIGIT(  100);
        PUTDIGIT(   10);
        PUTDIGIT(    1)
      END;   (* INT2BCD *)
      
      
    BEGIN  (* LONG2BCD *)
      BCDNUM[ 0] := 0;
      DIGITX := 1;
      INT2BCD( LONGNUM.HIGH);
      INT2BCD( LONGNUM.MID);
      INT2BCD( LONGNUM.LOW)
    END;  (* LONG2BCD *)


  PROCEDURE BCD2LONG;  (* P010007 *)
  
    VAR
         DIGITX : INTEGER;
  
  
    PROCEDURE BCD2INT( VAR LONGPART: INTEGER);  (* P010023 *)
  
  
      PROCEDURE GETDIGIT;  (* P010024 *)
      
        BEGIN
          LONGPART := (10 * LONGPART) + BCDNUM[ DIGITX];
          DIGITX := DIGITX + 1
        END;
        
        
      BEGIN  (* BCD2INT *)
        LONGPART := 0;
        GETDIGIT;
        GETDIGIT;
        GETDIGIT;
        GETDIGIT
      END;
      
      
    BEGIN  (* BCD2LONG *)
      FILLCHAR( LONGNUM, 6, 0);
      DIGITX := 1;
      BCD2INT( LONGNUM.HIGH);
      BCD2INT( LONGNUM.MID);
      BCD2INT( LONGNUM.LOW)
    END;  (* BCD2LONG *)


  PROCEDURE MULTLONG;  (* P010009 *)
  
    VAR
         UNUSEDXX : INTEGER;
         UNUSEDYY : INTEGER;
         DIGITX   : INTEGER;
         BCDNUM   : TBCD;
         
    BEGIN
      LONG2BCD( LONGNUM, BCDNUM);
      FOR DIGITX := 12 DOWNTO 1 DO
        BCDNUM[ DIGITX] := BCDNUM[ DIGITX] * INTNUM;
      FOR DIGITX := 12 DOWNTO 1 DO
        IF BCDNUM[ DIGITX] > 9 THEN
          BEGIN
            BCDNUM[ DIGITX - 1] := BCDNUM[ DIGITX - 1] +
                                   BCDNUM[ DIGITX] DIV 10;
            BCDNUM[ DIGITX] := BCDNUM[ DIGITX] MOD 10
          END;
      BCD2LONG( LONGNUM, BCDNUM)
    END;  (* MULTLONG *)


  PROCEDURE DIVLONG;  (* P01000A *)

    VAR
         NXTDIGIT : INTEGER;
         DIGITX   : INTEGER;
         BCDNUM   : TBCD;

    BEGIN
      LONG2BCD( LONGNUM, BCDNUM);
      FOR DIGITX := 1 TO 12 DO
        BEGIN
          NXTDIGIT := BCDNUM[ DIGITX] DIV INTNUM;
          BCDNUM[ DIGITX + 1] := BCDNUM[ DIGITX + 1] + 
                                 (10 * (BCDNUM[ DIGITX] - NXTDIGIT * INTNUM));
          BCDNUM[ DIGITX] := NXTDIGIT
        END;
      BCD2LONG( LONGNUM, BCDNUM)
    END;  (* DIVLONG *)


  FUNCTION TESTLONG;  (* P01000B *)
                    
    PROCEDURE LTEQGT( FIRSTX:  INTEGER;  (* P01002E *)
                      SECONDX: INTEGER);
    
      BEGIN
        IF FIRSTX = SECONDX THEN
          EXIT( LTEQGT)
        ELSE
          BEGIN
            IF FIRSTX > SECONDX THEN
              TESTLONG := 1
            ELSE
              TESTLONG := -1
          END;
        EXIT( TESTLONG)
      END; (* LTEQGT *)
      
  
    BEGIN  (* TESTLONG *)
      LTEQGT( FIRST.HIGH, SECOND.HIGH);
      LTEQGT( FIRST.MID,  SECOND.MID);
      LTEQGT( FIRST.LOW,  SECOND.LOW);
      TESTLONG := 0
    END;


  PROCEDURE PRNTLONG;  (* P01000C *)
                     
    VAR
         BCDNUM   : TBCD;
         NONSPCX  : INTEGER;
         LEADSPCX : INTEGER;
  
    BEGIN
      LONG2BCD( LONGNUM, BCDNUM);
      LEADSPCX := 1;
      WHILE (LEADSPCX < 12) AND (BCDNUM[ LEADSPCX] = 0) DO
        BEGIN
          LEADSPCX := LEADSPCX + 1;
          WRITE( ' ')
        END;
      FOR NONSPCX := LEADSPCX TO 12 DO
        WRITE(  BCDNUM[ NONSPCX] : 1)
    END;  (* PRNTLONG *)


  PROCEDURE GETKEY;  (* P01000D *)
  
    CONST
         SYSTERM = 2;
         
    VAR
         INBUF : PACKED ARRAY[ 0..1] OF CHAR;
  
  
    BEGIN
      MVCURSOR( 80, 0);  (* ADJUST RANDOM #, AND RETURN WHEN A CHAR IS AVAIL *)
      UNITREAD( SYSTERM, INBUF, 1, 0, 0);
      INCHAR := INBUF[ 0];
      IF EOLN THEN
        INCHAR := CHR( CRETURN)
    END;  (* GETKEY *)


  PROCEDURE GETLINE;  (* P01000E *)
  
    VAR
         IPOS : INTEGER;
         
    BEGIN
      IPOS := 0;
      REPEAT
        GETKEY;
        IF (INCHAR >= CHR( 32)) AND
           (INCHAR <= CHR( 90)) AND
           (IPOS < 40) THEN
          BEGIN
             IPOS:= IPOS + 1;
            GTSTRING[ IPOS] := INCHAR;
            WRITE( INCHAR)
          END
        ELSE
          BEGIN
            IF INCHAR = CHR( 8) THEN
              BEGIN
                IF IPOS > 0 THEN
                  BEGIN
                    WRITE( INCHAR);
                    WRITE( ' ');
                    WRITE( INCHAR);
                    IPOS := IPOS -1
                  END;
              END;
          END;
      UNTIL INCHAR = CHR( CRETURN);
      GTSTRING[ 0] := CHR( IPOS)
    END;
    
    
   FUNCTION GETCHARX;  (* P01000F *)
  
    BEGIN
      GOTOXY( 0, 18);
      WRITE( CHR( 11));
      IF DSPNAMES THEN
        BEGIN
          FOR LLBASE04 := 0 TO PARTYCNT - 1 DO
            BEGIN
              GOTOXY( 20 * (LLBASE04 MOD 2), 20 + (LLBASE04 DIV 2));
              WRITE( LLBASE04 + 1 :1);
              WRITE( ') ' );
              WRITE( CHARACTR[ LLBASE04].NAME);
            END;
        END;
      REPEAT
        GOTOXY( 0, 18);
        WRITE( CHR( 29));
        WRITE( SOLICIT);
        WRITE( ' ([RETURN] EXITS) >');
        GETKEY;
        LLBASE04 := ORD( INCHAR) - ORD( '0');
      UNTIL ((LLBASE04 > 0) AND (LLBASE04 <= PARTYCNT)) OR
            (INCHAR = CHR( 13));
      IF INCHAR = CHR( CRETURN) THEN
        LLBASE04 := 0;
      GETCHARX := LLBASE04 - 1
    END;
  
  
  PROCEDURE PAUSE1;   (* P010011 *)
  
    BEGIN
      FOR LLBASE04 := 0 TO TIMEDLAY DO
        BEGIN
        END;
    END;
    
    
  PROCEDURE PAUSE2;   (* P010012 *)
  
    BEGIN
      FOR LLBASE04 := 0 TO 3000 DO
        BEGIN
        END
    END;
    
    
  PROCEDURE CENTSTR;  (* P010010 *)
  
    BEGIN
      GOTOXY( 20 - (LENGTH( ASTRING) DIV 2), 23);
      WRITE( ASTRING);
      GOTOXY( 41, 0);
      PAUSE2
    END;
    
    
  PROCEDURE CLEARPIC;  (* P010013 *)
  
    BEGIN
      CLRPICT( 0, 0, 0, 100)    (* 100 === CLEAR PICTURE *)
    END;
    
    
  PROCEDURE GRAPHICS;  (* P010014 *)
  
    BEGIN
      MVCURSOR( 40, 0)    (* GRAPHICS MODE *)
    END;
    
    
  PROCEDURE TEXTMODE;  (* P010015 *)
  
    BEGIN
      MVCURSOR( 50, 0)    (* TEXT MODE *)
    END;
    
    
  PROCEDURE PRINTCHR;  (* P010016 *)
  
    BEGIN
      PRGRCHR( CHARSET[ ORD( ACHAR) - 32])
    END;
    
    
  PROCEDURE PRINTSTR;  (* P010017 *)
  
    VAR
         IPOS : INTEGER;
  
    BEGIN
      FOR IPOS := 1 TO LENGTH( ASTRING) DO
        BEGIN
          PRGRCHR( CHARSET[ ORD( ASTRING[ IPOS]) - 32])
        END;
    END;
    
    
  PROCEDURE PRINTNUM;  (* P010018 *)
  
    VAR
         DIGITS : STRING[ 5];
         DIGITX : INTEGER;
         
    BEGIN
      IF ANUM < 0 THEN
        ANUM := 0;
      IF FIELDSZ > 5 THEN
        FIELDSZ := 5;
      IF FIELDSZ < 1 THEN
        FIELDSZ := 1;
      FOR DIGITX := 5 DOWNTO 1 DO
        BEGIN
           DIGITS[  DIGITX]  :=  CHR( 48 +  (ANUM MOD 10));
           ANUM := ANUM DIV 10
        END;
      DIGITX := 1;
      WHILE  (DIGITX < 5) AND (DIGITS[ DIGITX] = CHR( 48)) DO
        BEGIN
          DIGITS[ DIGITX] := CHR( 32);
           DIGITX:= DIGITX + 1
        END;
      FOR DIGITX := (6 - FIELDSZ) TO 5 DO
        BEGIN
          PRINTCHR( DIGITS[ DIGITX])
        END;
    END;
    
    
  PROCEDURE GETSTR;
  
    VAR
         UNUSEDXX : INTEGER;
         UNUSEDYY : INTEGER;
         IPOS     : INTEGER;
         
    BEGIN
      IPOS := 0;
      REPEAT
        MVCURSOR( WINXPOS + IPOS, WINYPOS);
        PRINTCHR( CHR( 64));
        GETKEY;
        IF INCHAR = CHR( 27) THEN
          BEGIN
            CLRRECT( WINXPOS, WINYPOS, IPOS + 1, 1);
            IPOS := 0
          END
        ELSE
          BEGIN
            IF (INCHAR = CHR( 8)) AND (IPOS > 0) THEN
              BEGIN
                CLRRECT( WINXPOS + IPOS, WINYPOS, 1, 1);
                IPOS := IPOS - 1
              END
            ELSE
              BEGIN
                IF (INCHAR <> CHR( CRETURN)) AND (ORD( INCHAR) >= 32) THEN
                  BEGIN
                    MVCURSOR( WINXPOS + IPOS, WINYPOS);
                    PRINTCHR( INCHAR);
                    IPOS := IPOS + 1;
                    ASTRING[ IPOS] := INCHAR
                  END
              END
          END
      UNTIL INCHAR = CHR( CRETURN);
      ASTRING[ 0] := CHR( IPOS)
    END;
