SEGMENT PROCEDURE SPECIALS;   (* P010301 *)
    
    CONST
          SERIALBL = 5;
  
    VAR
         SPCINDEX : INTEGER;
         UNUSED   : INTEGER;
         NUM2000  : RECORD CASE INTEGER OF
                      1: (I: INTEGER);
                      2: (P: ^INTEGER);
                    END;
  
  
    PROCEDURE INSPECT;  (* P010302 *)
    
      VAR
           PICKCNT  : INTEGER;
           PICKLIST : ARRAY[ 1..6] OF INTEGER;
           UNUSEDXX : INTEGER;
           PICKCHAR : INTEGER;
           PICKREC  : TCHAR;
           MAZE     : TMAZE;
           INMYROOM : PACKED ARRAY[ 0..19] OF PACKED ARRAY[ 0..19] OF BOOLEAN;
           CHECKED  : PACKED ARRAY[ 0..19] OF PACKED ARRAY[ 0..19] OF BOOLEAN;
           
        
        
      PROCEDURE LOOKLOST;  (* P010303 *)
      
      
        PROCEDURE FOUNDLOS;  (* P010304 *)
        
          BEGIN
            IF PICKCNT = 5 THEN
              EXIT( LOOKLOST);
            PICKCNT := PICKCNT + 1;
            PICKLIST[ PICKCNT] := PICKCHAR;
            WRITE( PICKCNT : 1);
            WRITE( ') ');
            WRITE( PICKREC.NAME);
            WRITELN
          END;  (* FOUNDLOS *)
          
          
        BEGIN  (* LOOKLOST *)
          PICKCNT := 0;
          WRITE( CHR( 12));
          WRITELN( 'FOUND:');
          WRITELN;
          WRITELN;
          WRITELN;
          FOR PICKCHAR := 0 TO SCNTOC.RECPERDK[ ZCHAR] - 1 DO
            BEGIN
              MOVELEFT( IOCACHE[ GETREC( ZCHAR, PICKCHAR, SIZEOF( TCHAR))],
                        PICKREC,
                        SIZEOF( TCHAR));
              IF NOT PICKREC.INMAZE THEN
                IF PICKREC.LOSTXYL.LOCATION[ 3] = MAZELEV THEN
                  IF INMYROOM[ PICKREC.LOSTXYL.LOCATION[ 1],
                               PICKREC.LOSTXYL.LOCATION[ 2] ] THEN
                    FOUNDLOS
            END;
          IF PICKCNT = 0 THEN
            WRITELN( '** NO ONE **')
        END;  (* LOOKLOST *)
        
        
      PROCEDURE PICKUP;  (* P010305 *)
      
        BEGIN
          IF PARTYCNT = 6 THEN
            BEGIN
              GOTOXY( 0, 20);
              WRITE( CHR( 11));
              WRITELN( 'YOU HAVE 6 - PRESS [RET]');
              GOTOXY( 41, 0);
              REPEAT
                GETKEY
              UNTIL INCHAR = CHR( CRETURN);
              EXIT( PICKUP)
            END;
              
          REPEAT
            GOTOXY( 0, 20);
            WRITE( CHR( 11));
            WRITE( 'GET WHO (0=EXIT) >');
            GETKEY;
            PICKCHAR := ORD( INCHAR) - ORD( '0');
            IF PICKCHAR = 0 THEN
              EXIT( PICKUP)
          UNTIL (PICKCHAR > 0) AND (PICKCHAR <= PICKCNT);
          
          IF PICKLIST[ PICKCHAR] = -1 THEN
            EXIT( PICKUP);
          MOVELEFT( IOCACHE[ GETREC( ZCHAR,
                                     PICKLIST[ PICKCHAR],
                                     SIZEOF( TCHAR))],
                    CHARACTR[ PARTYCNT],
                    SIZEOF( TCHAR));
          CHARDISK[ PARTYCNT] := PICKLIST[ PICKCHAR];
          CHARACTR[ PARTYCNT].LOSTXYL.LOCATION[ 1] := 0;
          CHARACTR[ PARTYCNT].LOSTXYL.LOCATION[ 2] := 0;
          CHARACTR[ PARTYCNT].LOSTXYL.LOCATION[ 3] := 0;
          CHARACTR[ PARTYCNT].INMAZE := TRUE;
          MOVELEFT( CHARACTR[ PARTYCNT],
                    IOCACHE[ GETRECW( ZCHAR,
                                      PICKLIST[ PICKCHAR],
                                      SIZEOF( TCHAR))],
                    SIZEOF( TCHAR));
          PICKLIST[ PICKCHAR] := - 1;
          PARTYCNT := PARTYCNT + 1;
          GOTOXY( 0, 3 + PICKCHAR);
          WRITE( CHR( 29))
        END;  (* PICKUP *)
        
        
      PROCEDURE EXPLROOM;  (* P010306 *)
      
        VAR
             VERT     : INTEGER;
             HORZ     : INTEGER;
             DONELOOK : BOOLEAN;
      
      
        PROCEDURE CHECKLOC( X:    INTEGER;    (* P010307 *)
                            Y:    INTEGER;
                            WALL: TWALL);
        
          BEGIN
            IF WALL <> OPEN THEN
              EXIT( CHECKLOC);
            X := (X + 20) MOD 20;
            Y := (Y + 20) MOD 20;
            IF INMYROOM[ X][ Y] THEN
              EXIT( CHECKLOC);
            DONELOOK := FALSE;
            INMYROOM[ X][ Y] := TRUE
          END;  (* CHECKLOC *)
          
          
        BEGIN (* EXPLROOM *)
          MOVELEFT( IOCACHE[ GETREC( ZMAZE, MAZELEV - 1, SIZEOF( TMAZE))],
                    MAZE,
                    SIZEOF( TMAZE));
          FILLCHAR( INMYROOM, 80, 0);
          INMYROOM[ MAZEX][ MAZEY] := TRUE;
          FILLCHAR( CHECKED, 80, 0);
          REPEAT
            WRITE( '.');
            DONELOOK := TRUE;
            FOR HORZ := 0 TO 19 DO
              FOR VERT := 0 TO 19 DO
                IF INMYROOM[ HORZ][ VERT] THEN
                  IF NOT CHECKED[ HORZ][ VERT] THEN
                    BEGIN
                      CHECKLOC( HORZ + 1, VERT, MAZE.E[ HORZ][ VERT]);
                      CHECKLOC( HORZ - 1, VERT, MAZE.W[ HORZ][ VERT]);
                      CHECKLOC( HORZ, VERT - 1, MAZE.S[ HORZ][ VERT]);
                      CHECKLOC( HORZ, VERT + 1, MAZE.N[ HORZ][ VERT]);
                      CHECKED[ HORZ][ VERT] := TRUE
                    END
          UNTIL DONELOOK
        END;  (* EXPLROOM *)
        
        
      BEGIN (* INSPECT *)
        WRITE( CHR( 12));
        WRITE( 'LOOKING');
        TEXTMODE;
        EXPLROOM;
        LOOKLOST;
        REPEAT
          GOTOXY( 0, 20);
          WRITE( 'OPTIONS: ');
          IF PICKCNT > 0 THEN
            WRITE( 'P)ICK UP, ');
          WRITE( 'L)EAVE');
          REPEAT
            GOTOXY( 41, 0);
            GETKEY
          UNTIL (INCHAR = 'P') OR (INCHAR = 'L');
          IF INCHAR = 'P' THEN
            IF PICKCNT > 0 THEN
              PICKUP;
        UNTIL INCHAR = 'L';
        XGOTO := XRUNNER;
        GRAPHICS;
        EXIT( SPECIALS)
      END;  (* INSPECT *)
      
      
    FUNCTION FINDFILE( DRIVE:  INTEGER;  (* P010308 *)
                       FILENM: STRING) : INTEGER;
                       
      TYPE
           DIRENTRY = RECORD
             FIRSTBLK : INTEGER;
             LASTBLK  : INTEGER;
             FILEKIND : PACKED RECORD
                 FT : (VOLHEAD, BADBLK, MACH6502, TEXT, DEBUG,
                       DATA, GRAFFILE, FOTOFILE, SUBDIR);
               END;
             FILENAME : STRING[ 7];
             VOLLB    : INTEGER;
             FILECNT  : INTEGER;
             LOADTIM  : INTEGER;
             BOOTDATE : INTEGER;
             RES1     : INTEGER;
             RES2     : INTEGER;
         END;
               
      VAR
           DIR   : ARRAY[ 0..3] OF DIRENTRY;
           FILEI : INTEGER;
           FILEX : INTEGER;
                       
      BEGIN
        NUM2000.I := 8192;
        UNITREAD( DRIVE, DIR, 104, 2, 0);
        IF IORESULT <> 0 THEN
          FINDFILE := - ABS( IORESULT)
        ELSE
          BEGIN
            FILEI := 0;
            FOR FILEX := 1 TO DIR[ 0].FILECNT DO
              IF (DIR[ FILEX].FILEKIND.FT >= BADBLK) AND
                 (DIR[ FILEX].FILEKIND.FT <= FOTOFILE) THEN
                IF DIR[ FILEX].FILENAME = FILENM THEN
                  FILEI := FILEX;
            IF FILEI = 0 THEN
              FINDFILE := - 9
            ELSE
              FINDFILE := DIR[ FILEI].FIRSTBLK
          END
      END;  (* FINDFILE *)
      
      
      
    PROCEDURE INITGAME;  (* P010309 *)
    
      VAR
           CPTEMP   : INTEGER;                 (* COPY PROTECTION CODE USES *)
           UNUSED   : INTEGER;                 (* CP CODE *)
           SAVEI    : INTEGER;                 (* CP CODE *)
           SYNCH    : ARRAY[ 0..3] OF INTEGER; (* CP CODE *)
           
           DUPLSER : STRING[ 7];
           MASTSER : STRING[ 7];
    
    
    PROCEDURE MAZESCRN;  (* P01030A *)
      
      
        PROCEDURE HORZHYPH;  (* P01030B *)
        
          BEGIN
            FOR LLBASE04 := 1 TO 38 DO
              PRINTCHR( CHR( 34))        (* HYPHEN GRAPHIC *)
          END;
          
          
        PROCEDURE HORZLINE( LINE : INTEGER);  (* P01030C *)
        
          BEGIN
            MVCURSOR( 0, LINE);
            PRINTCHR( CHR( 39));         (* TILTED "T" ON LEFT OF LINE  *)
            HORZHYPH;
            PRINTCHR( CHR( 40))          (* TILTED "T" ON RIGHT OF LINE *)
          END;
          
          
        PROCEDURE SCRNOUTL;  (* P01030D *)
        
          BEGIN
            MVCURSOR( 0, 0);
            PRINTCHR( CHR( 33));         (* UPPER LEFT CORNER *)
            FOR LLBASE04 := 1 TO 38 DO
              PRINTCHR( CHR( 34));       (* HYPHEN *)
            PRINTCHR( CHR( 35));         (* UPPER RIGHT CORNER *)
            FOR LLBASE04 := 1 TO 22 DO
              BEGIN
                MVCURSOR( 0, LLBASE04);
                PRINTCHR( CHR( 36));     (* VERTICAL BAR ON LEFT  *)
                MVCURSOR( 39, LLBASE04);
                PRINTCHR( CHR( 36))      (* VERTICAL BAR ON RIGHT *)
              END;
            MVCURSOR( 0, 23);
            PRINTCHR( CHR( 37));         (* BOTTOM LEFT CORNER *)
            FOR LLBASE04 := 1 TO 38 DO
              PRINTCHR( CHR( 34));       (* HYPHEN *)
            PRINTCHR( CHR( 38))          (* BOTTOM RIGHT CORNER *)
          END;
          
          
        PROCEDURE INITSCRN;  (* P01030E *)
        
          VAR
               UNUSED : ARRAY[ 0..1] OF INTEGER;
              
          BEGIN
            CLRRECT( 0, 0, 40, 24);
            UNITREAD( DRIVE1, CHARSET, BLOCKSZ, SCNTOCBL + 2, 0);
            SCRNOUTL;
            HORZLINE( 10);
            HORZLINE( 15);
            MVCURSOR( 12, 0);           
            PRINTCHR( CHR( 91));         (* TILTED "T" TOP OF LINE *)
            FOR LLBASE04 := 1 TO 9 DO
              BEGIN
                MVCURSOR( 12, LLBASE04);
                PRINTCHR( CHR( 92))      (* VERTICAL BAR *)
              END;
            MVCURSOR( 12, 5);
            PRINTCHR( CHR( 93));         (* TILTED "T" LEFT OF LINE *)
            FOR LLBASE04 := 13 TO 38 DO
              PRINTCHR( CHR( 34));       (* HYPHEN *)
            PRINTCHR( CHR( 40));         (* TILTED "T" RIGHT OF LINE *)
            MVCURSOR( 12, 10);
            PRINTCHR( CHR( 94));         (* TILTED "T" BOTTOM OF LINE *)
            UNITREAD( DRIVE1, CHARSET, BLOCKSZ, SCNTOCBL + 1, 0);
            MVCURSOR( 1, 16);
            PRINTSTR( '# CHARACTER NAME  CLASS AC HITS STATUS')
          END;
          
        BEGIN (* MAZESCRN *)
          CLRRECT( 0, 0, 40, 24);  (* REPEATED IN INITSCRN!? *)
          INITSCRN
        END;
        
        
      PROCEDURE GTSERIAL;  (* P01030F *)
      
        (* GOOFY TRACK SYNCH COPYPROTECTION CODE *)
      
        BEGIN
          UNITREAD( DRIVE1, IOCACHE, BLOCKSZ, SERIALBL, 0);
          CPTEMP := 31;  (* OFFSET TO MANGLED SYNCH COUNTS *)
          FOR SAVEI := 10 TO 13 DO
            BEGIN
              MOVELEFT( IOCACHE[ CPTEMP], SYNCH[ (SAVEI - 10)], 2);
              CPTEMP := CPTEMP + 2 * (SYNCH[ SAVEI - 10] MOD 13) + 5
            END;
          MOVELEFT( IOCACHE, MASTSER, 8)
        END;
        
        
      PROCEDURE COPYPROT;  (* P010310 *)
      
        VAR
             CPCALC   : INTEGER;
             TRIES    : INTEGER;
             GOODCOPY : BOOLEAN;
      
        BEGIN
          FOR TRIES := 1 TO 5 DO
            BEGIN
               GOODCOPY := TRUE;
              FOR SAVEI := 10 TO 13 DO
                BEGIN
                  UNITREAD( DRIVE1, IOCACHE, BLOCKSZ, 8 * SAVEI, 0);
                  MVCURSOR( 60, 0);  (* JUMP TO $2002 AND EXECUTE *)
                  CPTEMP := NUM2000.P^;  (* SYNCH COUNT FROM $2002
                                              READING DISK TRACKS *)
                  IF SAVEI = 10 THEN
                    CPCALC := CPTEMP - SYNCH[ 10 - 10];
                  CPTEMP := CPTEMP - CPCALC;
                  IF ABS( CPTEMP -  SYNCH[ SAVEI - 10]) > 29 THEN
                     GOODCOPY := FALSE;
                END;
              IF GOODCOPY THEN
                EXIT( COPYPROT);
            END;
            
          MVCURSOR( 70, 0);  (* CRASH AND BURN *)
          HALT
        END;
        
        
        
      BEGIN (* INITGAME *)
      
        IF LLBASE04 = -1 THEN
          BEGIN
            REPEAT
              WRITE( CHR( 12));
              GOTOXY( 0, 11);
              WRITE( ' SCENARIO MASTER IN DRV 1, PRESS [RET]');
              REPEAT
                GOTOXY( 41, 0);
                GETKEY
              UNTIL INCHAR = CHR( CRETURN);
              SCNTOCBL := FINDFILE( DRIVE1, 'SCENARIO.DATA')
            UNTIL SCNTOCBL >= 0;
            
            UNITREAD( DRIVE1, NUM2000.P^, BLOCKSZ, SCNTOCBL + 3, 0);
                (* SCNTOCBL + 3 FOLLOWS MAGE AND PRIEST SPELL NAMES *)
                (* COPY PROTECTION CODE GETS LOADED TO $2000        *)
            GTSERIAL; (* AND SOME COPY PROTECTION *)
            COPYPROT; (* MORE COPY PROTECTION     *)
            
            REPEAT
              WRITE( CHR( 12));
              GOTOXY( 0, 11);
              WRITE( ' MASTER/DUPLICATE IN DRV 1, PRESS [RET]');
              REPEAT
                GOTOXY( 41, 0);
                GETKEY
              UNTIL INCHAR = CHR( CRETURN);
              SCNTOCBL := FINDFILE( DRIVE1, 'SCENARIO.DATA');
              UNITREAD( DRIVE1, IOCACHE, BLOCKSZ, SERIALBL, 0);
              MOVELEFT( IOCACHE, DUPLSER, 8)
            UNTIL (SCNTOCBL >= 0) AND (MASTSER = DUPLSER);
            
            TIMEDLAY := 2000;
            CACHEWRI := FALSE;
            CACHEBL := 0;
            UNITREAD( DRIVE1, IOCACHE, SIZEOF( IOCACHE), SCNTOCBL, 0);
            MOVELEFT( IOCACHE, SCNTOC, SIZEOF( TSCNTOC))
          END;
          
        XGOTO := XCASTLE;
        WRITE( CHR( 12));
        TEXTMODE;
        MAZESCRN;
        MAZEX    := 0;
        MAZEY    := 0;
        MAZELEV  := 0;
        PARTYCNT := 0;
        DIRECTIO := 0;
        ACMOD2   := 0;
        EXIT( SPECIALS)
      END;
    
PROCEDURE SPCMISC;  (* P010311 *)
  
    VAR
         MESSAGE  : PACKED ARRAY[ 0..511] OF CHAR;
         
         STRBUFF  : RECORD
                      BUFF: STRING[ 38];
                      ENDMSG : BOOLEAN;
                    END;
                    
         LINECNT  : INTEGER;
         MSGX     : INTEGER;
         MSGBLK   : INTEGER;
         CURMSGBL : INTEGER;
         MSGBLK0  : INTEGER;
         BOUNCEFL : INTEGER; (* MULTIPLE USES;  FIRST CHAR "FEE" 2CG *)
         AUX0     : INTEGER; (* MULTIPLE USES:  EQINDEX, RANDOM 0-6, MSG INDEX
                                                AUX0 *)
         AUX1     : INTEGER; (* MULTIPLE USES:  AUX1, MSG INDEX, ....*)
         AUX2     : INTEGER;
         MAZEFLOR : TMAZE;
  
      
    PROCEDURE DECRYPTM( MSGINDEX: INTEGER);  (* P010312 *)
    
      BEGIN
        MSGBLK := MSGINDEX DIV 12;
        MSGX := 42 * (MSGINDEX MOD 12);
        IF MSGBLK <> CURMSGBL THEN
          BEGIN
            UNITREAD( DRIVE1, MESSAGE, BLOCKSZ, MSGBLK0 + MSGBLK, 0);
            CURMSGBL := MSGBLK
          END;
        MOVELEFT( MESSAGE[ MSGX], STRBUFF.BUFF, 42)
      END;
    
    
    PROCEDURE DOMSG( MSGLINEX: INTEGER;   (* P010313 *)
                     PRESSRET: BOOLEAN);
    
    
      PROCEDURE DO1LINE;  (* P010314 *)
      
        BEGIN
          IF LINECNT = 15 THEN
            BEGIN
              CLRRECT( 13, 6, 26, 4);
              MVCURSOR( 19, 7);
              PRINTSTR( '[RET] FOR MORE');
              UNITCLEAR( 1);
              REPEAT
                GETKEY
              UNTIL INCHAR = CHR( CRETURN);
              CLRRECT( 13, 6, 26, 4);
              CLRRECT( 1, 11, 38, 4);
              LINECNT := 11;
            END;
          DECRYPTM( MSGLINEX);
          MVCURSOR( 1, LINECNT);
          PRINTSTR( STRBUFF.BUFF);
          MSGLINEX := MSGLINEX + 1;
          LINECNT := LINECNT + 1
        END;  (* DO1LINE *)
        
        
      BEGIN (* DOMSG *)
        LINECNT := 11;
        REPEAT
          DO1LINE
        UNTIL STRBUFF.ENDMSG;
        IF PRESSRET THEN
          BEGIN
            CLRRECT( 13, 6, 26, 4);
            MVCURSOR( 21, 7);
            PRINTSTR( 'PRESS [RET]');
            UNITCLEAR( 1);
            REPEAT
              GETKEY;
            UNTIL INCHAR = CHR( CRETURN);
            CLRRECT( 13, 6, 26, 4)
          END;
      END;  (* DOMSG *)
      
      
    FUNCTION GOTITEM( CHARX: INTEGER;  (* P010315 *)
                      ITEMX: INTEGER) : BOOLEAN;
    
      VAR
           POSSX : INTEGER;
           
      BEGIN
        GOTITEM := FALSE;
        WITH CHARACTR[ CHARX] DO
          BEGIN
            IF POSS.POSSCNT = 8 THEN
              EXIT( GOTITEM);
            FOR POSSX := 1 TO POSS.POSSCNT DO
              IF POSS.POSSESS[ POSSX].EQINDEX = ITEMX THEN
                EXIT( GOTITEM);
            CLRRECT( 1, 11, 38, 4);
            MVCURSOR( 1, 11);
            PRINTSTR( CHARACTR[ CHARX].NAME);
            PRINTSTR( ' GOT ITEM');
            POSSX := POSS.POSSCNT + 1;
            POSS.POSSCNT := POSSX;
            POSS.POSSESS[ POSSX].EQINDEX := ITEMX;
            POSS.POSSESS[ POSSX].EQUIPED := FALSE;
            POSS.POSSESS[ POSSX].CURSED  := FALSE
          END;
        GOTITEM := TRUE
      END;
      
      
    PROCEDURE TRYGET;  (* P010316 *)
    
      VAR
           GOTONE : BOOLEAN;
           CHARX  : INTEGER;
           
      BEGIN
        GOTONE := FALSE;
        FOR CHARX := 0 TO PARTYCNT - 1 DO
          IF NOT GOTONE THEN
            GOTONE := GOTITEM( CHARX, AUX0)
      END;
      
      
    PROCEDURE WHOWADE;  (* P010317 *)
    
      VAR
           WADEX : INTEGER;
           
           
      PROCEDURE MAKWORSE( THISSTAT: TSTATUS);  (* P010318 *)
      
        BEGIN
          IF THISSTAT > CHARACTR[ WADEX].STATUS THEN
            CHARACTR[ WADEX].STATUS := THISSTAT
        END;
        
        
      BEGIN (* WHOWADE *)
        CLRRECT( 1, 11, 38, 4);
        MVCURSOR( 2, 12);
        PRINTSTR( '#) TO WADE, [RET] EXITS');
        WADEX := GETCHARX( FALSE, '');
        IF WADEX < 0 THEN
          EXIT( WHOWADE);
          
        IF AUX0 = -1 THEN
          AUX0 := RANDOM MOD 7;
          
        CASE AUX0 OF
          0:  BEGIN
                IF CHARACTR[ WADEX].STATUS < DEAD THEN
                  BEGIN
                    CHARACTR[ WADEX].STATUS := OK;
                    CHARACTR[ WADEX].HPMAX  := CHARACTR[ WADEX].HPMAX - 8;
                    CHARACTR[ WADEX].HPLEFT := CHARACTR[ WADEX].HPMAX;
                    IF CHARACTR[ WADEX].HPMAX <= 0 THEN
                      MAKWORSE( DEAD);
                  END;
              END;
              
          1:  BEGIN
                IF (CHARACTR[ WADEX].ATTRIB[ IQ] = 3) OR
                   (CHARACTR[ WADEX].ATTRIB[ PIETY] = 3) THEN
                  MAKWORSE( DEAD)
                ELSE
                  BEGIN
                    CHARACTR[ WADEX].AGE := CHARACTR[ WADEX].AGE - 52;
                    CHARACTR[ WADEX].ATTRIB[ IQ] :=
                      CHARACTR[ WADEX].ATTRIB[ IQ] - 1;
                    CHARACTR[ WADEX].ATTRIB[ PIETY] :=
                      CHARACTR[ WADEX].ATTRIB[ PIETY] - 1
                  END
              END;
            
          2:  CHARACTR[ WADEX].LOSTXYL.POISNAMT[ 1] := 1;
          3:  MAKWORSE( ASLEEP);
          4:  MAKWORSE( PLYZE);
          5:  MAKWORSE( STONED);
          6:  IF CHARACTR[ WADEX].STATUS = DEAD THEN
                IF (RANDOM MOD 10 < 3) THEN
                  BEGIN
                    CHARACTR[ WADEX].STATUS := OK;
                    CHARACTR[ WADEX].HPLEFT := CHARACTR[ WADEX].HPMAX
                  END
                ELSE
                  CHARACTR[ WADEX].STATUS := ASHES;
        END
      END;  (* WHOWADE *)
      
      
      
    PROCEDURE GETYN;  (* P010319 *)
    
      BEGIN
        CLRRECT( 1, 11, 38, 4);
        MVCURSOR( 1, 11);
        PRINTSTR( 'SEARCH (Y/N) ?');
        REPEAT
          GETKEY
        UNTIL (INCHAR = 'Y') OR (INCHAR = 'N');
        IF INCHAR = 'N' THEN
          EXIT( SPECIALS);
        IF AUX0 > 0 THEN
          BEGIN
            ATTK012 := 0;
            ENEMYINX := AUX0;
            XGOTO := XCOMBAT
          END
        ELSE
          BEGIN
            AUX0 := ABS( AUX0);
            TRYGET
          END;
      END;
    
      
    PROCEDURE BOUNCEBK;  (* P01031A *)
    
      BEGIN
        CASE DIRECTIO OF
          0:  MAZEY := MAZEY - 1;
          1:  MAZEX := MAZEX - 1;
          2:  MAZEY := MAZEY + 1;
          3:  MAZEX := MAZEX + 1;
        END;
        MAZEY := (MAZEY + 20) MOD 20;
        MAZEX := (MAZEX + 20) MOD 20;
        IF AUX1 >= 0 THEN
            DOMSG( AUX1, FALSE)
      END;
  
  
    PROCEDURE ITM2PASS;  (* P01031B *)
    
    VAR
         POSX  : INTEGER;
         CHARX : INTEGER;
         
      BEGIN
        FOR CHARX := 0 TO PARTYCNT - 1 DO
          WITH CHARACTR[ CHARX] DO
            BEGIN
              FOR POSX := 1 TO POSS.POSSCNT DO
                IF POSS.POSSESS[ POSX].EQINDEX = AUX0 THEN
                  EXIT( SPECIALS)
            END;
        BOUNCEBK
      END;
      
      
    PROCEDURE CHKALIGN;  (* P01031C *)
    
      VAR
           CHARX : INTEGER;
           
      BEGIN
        FOR CHARX := 0 TO PARTYCNT - 1 DO
          WITH CHARACTR[ CHARX] DO
            BEGIN
              CASE ALIGN OF
              
                   GOOD:  IF (AUX0 = 0) OR (AUX0 = 2) OR
                             (AUX0 = 4) OR (AUX0 = 6) THEN
                            BOUNCEBK;
                        
                NEUTRAL:  IF (AUX0 = 0) OR (AUX0 = 1) OR
                             (AUX0 = 4) OR (AUX0 = 5) THEN
                            BOUNCEBK;
                        
                   EVIL:  IF (AUX0 < 4) THEN
                            BOUNCEBK
              END
            END
      END;  (* CHKALIGN *)
      
      
    PROCEDURE CHKAUX0;  (* P01031D *)
    
      BEGIN
        IF AUX0 = 99 THEN
          LIGHT := LIGHT + 50
        ELSE IF AUX0 = -99 THEN
          LIGHT := 0
        ELSE
          ACMOD2 := AUX0
      END;  (* CHKAUX0 *)
      
      
    PROCEDURE BCK2SHOP;  (* P01031E *)
    
      BEGIN
        MAZELEV := 0;
        WRITE( CHR(12));
        XGOTO := XNEWMAZE
      END;
        
        
    PROCEDURE RIDDLES;  (* P01031F *)
    
      VAR
           ANSWER : STRING[ 40];
    
      BEGIN
        CLRRECT( 1, 11, 38, 4);
        MVCURSOR( 1, 11);
        PRINTSTR( 'ANSWER ?');
        GETSTR( ANSWER, 1, 13);
        DECRYPTM( AUX0);
        CLRRECT( 1, 11, 38, 4);
        MVCURSOR( 1, 11);
        IF STRBUFF.BUFF <> ANSWER THEN
          BEGIN
            AUX1 := - 1;
            PRINTSTR( 'WRONG!');
            BOUNCEBK
          END
        ELSE
          PRINTSTR( 'RIGHT!')
      END;


    PROCEDURE FEEIS;  (* P010320 *)
    
      VAR
           GOLDTOT : TWIZLONG;
           FEE     : TWIZLONG;
    
    
      PROCEDURE FEE2LONG;  (* P010321 *)
      
        VAR
             MULT10 : INTEGER;
             STRX   : INTEGER;
      
        BEGIN
          IF STRBUFF.BUFF[ 1] >= '@' THEN
            BEGIN
              BOUNCEFL := ORD( STRBUFF.BUFF[ 1]) - ORD( 'A') + 1;
              STRBUFF.BUFF := COPY( STRBUFF.BUFF, 2,
                                    ORD( STRBUFF.BUFF[ 0]) - 1)
            END
          ELSE
            BOUNCEFL := 0;
          FILLCHAR( FEE, 6, 0);
          MULT10 := 10;
          FOR STRX := 1 TO LENGTH( STRBUFF.BUFF) DO
            BEGIN
              MULTLONG( FEE, MULT10);
              FEE.LOW := FEE.LOW + ORD( STRBUFF.BUFF[ STRX]) - ORD( '0')
            END
        END;
        
        
      PROCEDURE CHKGOLD;  (* P010322 *)
      
        VAR
             CHARX : INTEGER;
      
        BEGIN
          FILLCHAR( GOLDTOT, 6, 0);
          FOR CHARX := 0 TO PARTYCNT - 1 DO
            ADDLONGS( GOLDTOT, CHARACTR[ CHARX].GOLD);
          IF TESTLONG( GOLDTOT, FEE) <> -1 THEN
            EXIT( CHKGOLD);
          PRINTSTR( 'NOT ENOUGH $');
          IF BOUNCEFL = 0 THEN
            BOUNCEBK;
          EXIT( SPECIALS)
        END;
        
        
      PROCEDURE PAYGOLD;  (* P010323 *)
      
        VAR
             CHARX : INTEGER;
      
        BEGIN
          FILLCHAR( GOLDTOT, 6, 0);
          FOR CHARX := 0 TO PARTYCNT - 1 DO
            BEGIN
              IF FEE <> GOLDTOT THEN
                IF TESTLONG( FEE, CHARACTR[ CHARX].GOLD) = 1 THEN
                  BEGIN
                    SUBLONGS( FEE, CHARACTR[ CHARX].GOLD);
                    FILLCHAR( CHARACTR[ CHARX].GOLD, 6, 0)
                  END
                ELSE
                  BEGIN
                    SUBLONGS( CHARACTR[ CHARX].GOLD, FEE);
                    FILLCHAR( FEE, 6, 0)
                  END
            END;
          PRINTSTR( 'THANKS!')
        END;
        
        
      BEGIN (* FEEIS *)
        DECRYPTM( AUX0);
        FEE2LONG;
        CLRRECT( 1, 11, 38, 4);
        MVCURSOR( 1, 11);
        PRINTSTR( 'FEE IS ');
        PRINTSTR( STRBUFF.BUFF);
        MVCURSOR( 1, 13);
        PRINTSTR( 'PAY (Y/N) ?');
        REPEAT
          GETKEY
        UNTIL (INCHAR = 'Y') OR (INCHAR = 'N');
        AUX1 := -1;
        IF INCHAR = 'N' THEN
          BEGIN
            IF BOUNCEFL = 0 THEN
               BOUNCEBK;
            EXIT( SPECIALS)
          END
        ELSE
          BEGIN
            CLRRECT( 1, 11, 38, 4);
            MVCURSOR( 1, 11);
            CHKGOLD;
            PAYGOLD;
            IF BOUNCEFL > 0 THEN
              BEGIN
                MAZEX   := MAZEFLOR.AUX2[ BOUNCEFL];
                MAZEY   := MAZEFLOR.AUX1[ BOUNCEFL];
                MAZELEV := MAZEFLOR.AUX0[ BOUNCEFL];
                XGOTO := XNEWMAZE
              END
          END
      END;
      
      
    PROCEDURE LOOKOUT;  (* P010324 *)
    
      VAR
           Y  : INTEGER;
           X  : INTEGER;
           Y2 : INTEGER;
           X2 : INTEGER;
           
      BEGIN
        FOR X2 := - AUX0 TO AUX0 DO
          FOR Y2 := - AUX0 TO AUX0 DO
            BEGIN
              X := (MAZEX + X2 + 20) MOD 20;
              Y := (MAZEY + Y2 + 20) MOD 20;
              FIGHTMAP[ X, Y] := TRUE
            END;
        FIGHTMAP[ MAZEX, MAZEY] := FALSE
      END;
      
      
    PROCEDURE SWITCHLOC;  (* P010325 *)
    
      VAR
           BEENHERE : PACKED ARRAY[ 0..19] OF PACKED ARRAY[ 0..19] OF BOOLEAN;
           UNUSED1  : INTEGER;
           UNUSED2  : INTEGER;
           UNUSED3  : INTEGER;
           DOORCNT  : INTEGER;  (* DOORS GONE THROUGH *)
    
    
      PROCEDURE SWITCH( VAR FIRST:  INTEGER;  (* P010326 *)
                        VAR SECOND: INTEGER);
      
        VAR
             SAVE : INTEGER;
      
        BEGIN
          SAVE   := FIRST;
          FIRST  := SECOND;
          SECOND := SAVE
        END;
        
        
      PROCEDURE FINDDOOR;  (* P010327 *)
    
        VAR
             LIMITMOV : INTEGER;  (* LIMIT DOORS (ROOMS) MOVED THROUGH *)
    
    
        FUNCTION P010328( X : INTEGER; Y : INTEGER) : BOOLEAN;  (* P010328 *)
        
        
          PROCEDURE TRYADJ( X : INTEGER; Y : INTEGER);  (* P010329 *)
            
            
            PROCEDURE CHK4DOOR( WALLTYPE : TWALL;  (* P01032A *)
                                MOVETOX  : INTEGER;
                                MOVETOY  : INTEGER);
            
              BEGIN (* CHK4DOOR *)
                IF (WALLTYPE = OPEN) OR (WALLTYPE = WALL) THEN
                  EXIT( CHK4DOOR);
                IF WALLTYPE = HIDEDOOR THEN
                  IF (RANDOM MOD 100) < 65 THEN
                    EXIT( CHK4DOOR);
                    
                (* EITHER A DOOR OR SOMETIMES A HIDDEN DOOR *)
                    
                MOVETOX := (MOVETOX + 20) MOD 20;
                MOVETOY := (MOVETOY + 20) MOD 20;
                IF (DOORCNT = 0) OR
                  (NOT (BEENHERE[ MOVETOX][ MOVETOY])
                   AND ((RANDOM MOD 100) > (65 - LIMITMOV))) THEN
                   BEGIN
                     SAVEX := X;
                     SAVEY := Y;
                     MAZEX := MOVETOX;
                     MAZEY := MOVETOY;
                     DOORCNT := DOORCNT + 1;
                     P010328 := TRUE;
                     EXIT( P010328)
                   END;
              END;  (* CHK4DOOR *)
              
              
            BEGIN (* TRYADJ *)
              X := (X + 20) MOD 20;
              Y := (Y + 20) MOD 20;
              IF BEENHERE[ X][ Y] THEN
                EXIT( TRYADJ);
              IF MAZEFLOR.SQRETYPE[ MAZEFLOR.SQREXTRA[ X][ Y]] <> NORMAL THEN
                BEGIN
                  MAZEX := X;
                  MAZEY := Y;
                  EXIT( FINDDOOR)
                END;
                
              BEENHERE[ X][ Y] := TRUE;
              
              CHK4DOOR( MAZEFLOR.N[ X][ Y], X, Y + 1);
              CHK4DOOR( MAZEFLOR.S[ X][ Y], X, Y - 1);
              CHK4DOOR( MAZEFLOR.E[ X][ Y], X + 1, Y);
              CHK4DOOR( MAZEFLOR.W[ X][ Y], X - 1, Y);
              
              IF MAZEFLOR.N[ X][ Y] = OPEN THEN
                TRYADJ( X, Y + 1);
              IF MAZEFLOR.W[ X][ Y] = OPEN THEN
                TRYADJ( X - 1, Y);
              IF MAZEFLOR.E[ X][ Y] = OPEN THEN
                TRYADJ( X + 1, Y);
              IF MAZEFLOR.S[ X][ Y] = OPEN THEN
                TRYADJ( X, Y - 1)
            END;  (* TRYADJ *)
        
        
          BEGIN (* P010328 *)
            P010328 := FALSE;
            TRYADJ( X, Y)
          END;  (* P010328 *)
          
          
          
        BEGIN  (* FINDDOOR *)
          LIMITMOV := 0;
          WHILE  (DOORCNT = 0) OR
                 ((RANDOM MOD 65) >  LIMITMOV) DO
            BEGIN
              IF NOT P010328( MAZEX, MAZEY) THEN
                EXIT( FINDDOOR);
              LIMITMOV := LIMITMOV + 10;
            END;
        END;
      
      
      BEGIN  (* SWITCHLOC *)
        XGOTO2 := XCOMBAT;
        XGOTO := XRUNNER;
        FILLCHAR( BEENHERE, 80, 0);
        DOORCNT := 0;
        MAZEFLOR.SQREXTRA[ MAZEX][ MAZEY] := 0;
        FINDDOOR;
        DIRECTIO := RANDOM MOD 4;
        EXIT( SPECIALS);
      END;  (* SWITCHLOC *)
      
      
    BEGIN  (* SPCMISC *)
      MOVELEFT( IOCACHE[ GETREC( ZMAZE, MAZELEV - 1, SIZEOF( TMAZE))],
                MAZEFLOR,
                SIZEOF( TMAZE));
      BOUNCEFL := SPCINDEX;
      IF BOUNCEFL = 0 THEN
        SWITCHLOC;
      XGOTO2 := XSCNMSG;
      CLRRECT( 1, 11, 38, 4);
      MSGBLK0 := FINDFILE( DRIVE1, 'SCENARIO.MESGS');
      IF MSGBLK0 < 0 THEN
        BEGIN
          MVCURSOR( 1, 11);
          PRINTSTR( 'MESGS LOST');
          EXIT( SPECIALS);
        END;
      CURMSGBL := 0;
      UNITREAD( DRIVE1, MESSAGE, BLOCKSZ, MSGBLK0, 0);
      AUX2 := MAZEFLOR.AUX2[ BOUNCEFL];
      AUX1 := MAZEFLOR.AUX1[ BOUNCEFL];
      AUX0 := MAZEFLOR.AUX0[ BOUNCEFL];
      XGOTO := XRUNNER;
      IF AUX2 = 0 THEN
        EXIT( SPECIALS);
      IF (AUX2 = 1) OR (AUX2 = 4) OR (AUX2 = 8) THEN
        BEGIN
          IF AUX0 = 0 THEN
            EXIT( SPECIALS)
          ELSE
            BEGIN
              IF AUX2 <> 4 THEN
                BEGIN
                  IF AUX0 > 0 THEN
                    MAZEFLOR.AUX0[ BOUNCEFL] := AUX0 - 1;
                  IF AUX0 = 1 THEN
                    MAZEFLOR.SQRETYPE[ BOUNCEFL] := NORMAL;
                END
              ELSE
                IF AUX0 < 0 THEN
                  IF AUX0 > -1000 THEN
                    MAZEFLOR.AUX0[ BOUNCEFL] := 0
                  ELSE
                    AUX0 := AUX0 + 1000;
              MOVELEFT( MAZEFLOR,
                        IOCACHE[ GETRECW( ZMAZE, MAZELEV - 1, SIZEOF( TMAZE))],
                        SIZEOF( TMAZE))
            END
        END;
        
      CLRRECT( 1, 11, 38, 4);
      IF NOT ( (AUX2 = 5) OR (AUX2 = 6) ) THEN
        DOMSG( AUX1,
                 (AUX2 = 2)  OR (AUX2 = 3) OR (AUX2 = 4) OR
                 (AUX2 = 10) OR (AUX2 = 11) OR (AUX2 = 12));
      CASE AUX2 OF
         2: TRYGET;
         3: WHOWADE;
         4: GETYN;
         5: ITM2PASS;
         6: CHKALIGN;
         7: CHKAUX0;
         8: BCK2SHOP;
         9: LOOKOUT;
        10: RIDDLES;
        11: FEEIS;
      END;
    END;  (* SPCMISC *)
    
  BEGIN  (* SPECIALS *)
  
    IF XGOTO = XINSAREA THEN
      INSPECT;
    XGOTO := XGOTO2;
    SPCINDEX := LLBASE04;
    IF SPCINDEX < 0 THEN
      INITGAME
    ELSE
      SPCMISC

  END;  (* SPECIALS *)