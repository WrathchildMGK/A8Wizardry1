PROGRAM WIZARDRY;

(*$S++*)
(*$L PRINTER: *)
(* "$S++" OPTION BEFORE "$L" *)
(*$R-*)
(*$I-*)
(*$V-*)

(*
  WIZARDRY I (PROVING GROUNDS), WIZARDRY.CODE
  REVERSE ENGINEERED BY:
    
    THOMAS WILLIAM EWERS
      (MAR - JUN 2014)
*)

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

(* ---------- BEGIN SEGMENTS -------------------- *)

(*$I WIZ1C:UTILITIE  *)
(*$I WIZ1B:UTILITIE2 *)
(*$I WIZ1B:UTILITIE3 *)

(*$I WIZ1B:SHOPS     *)
(*$I WIZ1A:SHOPS2    *)

(*$I WIZ1B:SPECIALS  *)
(*$I WIZ1B:SPECIALS2 *)

(*$I WIZ1B:COMBAT    *)
(*$I WIZ1B:COMBAT2   *)
(*$I WIZ1B:COMBAT3   *)
(*$I WIZ1B:COMBAT4   *)
(*$I WIZ1B:COMBAT5   *)

(*$I WIZ1C:CASTLE    *)
(*$I WIZ1C:CASTLE2   *)
                      
(*$I WIZ1C:ROLLER    *)

(*$I WIZ1C:CAMP      *)
(*$I WIZ1C:CAMP2     *)
                        
(*$I WIZ1C:REWARDS   *)
(*$I WIZ1C:REWARDS2  *)
                      
(*$I WIZ1C:RUNNER    *)
(*$I WIZ1C:RUNNER2   *)

(* ---------- END SEGMENTS ---------------------- *)

(*$I WIZ1A:WIZ2.TEXT *)

(* ----- BEGIN WIZARDRY MAINLINE ----- *)

BEGIN  (* P010001 *)
  
  MEMPTR.I := 16384;  (* $4000 *)
  RELEASE( MEMPTR.P);
  
  REPEAT
    LLBASE04 := -1;
    SPECIALS;
    REPEAT
      CASE XGOTO OF
      
       XSCNMSG,
       XINSAREA:  SPECIALS;
       
       XCASTLE,
       XGILGAMS:  CASTLE;
       
       XBOLTAC,
       XCANT,
       XCHK4WIN,
       XCEMETRY,
       XEDGTOWN:  SHOPS;
       
       XNEWMAZE,
       XEQUIP6,
       XEQPDSP,
       XREORDER,
       XCMP2EQ6,
       XCAMPSTF:  UTILITIE;
       
       XTRAININ,
       XBCK2ROL:  ROLLER;
       
       XRUNNER:   RUNNER;
       
       XREWARD,
       XREWARD2:  REWARDS;
       
       XCOMBAT,
       XUNUSED:   COMBAT;
       
       XINSPECT,
       XINSPCT2,
       XINSPCT3,
       XBCK2CMP,
       XBK2CMP2:  CAMP;
       
      END;
    UNTIL XGOTO = XDONE;
    
    WRITE( CHR( 12));
    GOTOXY( 0, 10);
    WRITE( '    PRESS [RETURN] FOR MORE WIZARDRY    ');
    READLN
  UNTIL FALSE
END.