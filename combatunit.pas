  SEGMENT PROCEDURE COMBAT;  (* P010401 *)

    VAR
         CINITFL1 : INTEGER;
         SURPRISE : INTEGER;
         DONEFIGH : BOOLEAN;
         PREBATOR : ARRAY[ 0..5] OF INTEGER;
         DRAINED  : ARRAY[ 0..5] OF BOOLEAN;
         BATTLERC : ARRAY[ 0..4] OF TENEMY2;

    
(* CINIT *)
    
    SEGMENT PROCEDURE CINIT;  (* P010501 *)
      
      
      PROCEDURE ENEMYPIC( ENEMYID : INTEGER);  (* P010502 *)
      
        VAR
             PICLINE  : INTEGER;
             UNUSED   : INTEGER;
             SCRNADDR : RECORD CASE INTEGER OF
                 1: (I: INTEGER);
                 2: (P: ^INTEGER);
               END;
                     
        BEGIN
          CLRPICT( 0, 0, 0, 100);  (* CLEAR PICTURE *)
          IF ENEMYID < 0 THEN
            BEGIN
              ENEMYID := 0;  (* NO MONSTER PICTURE (?) SO USE FIRST ONE *)
              WRITE( CHR(7)) (*   AND RING THE BELL                     *)
            END;
          FOR PICLINE := 23 TO 72 DO
            BEGIN
              SCRNADDR.I := (8193 +  (1024 *  (PICLINE MOD 8))) +
                            (128 * ((PICLINE MOD 64) DIV 8)) +
                            40 * (PICLINE DIV 64);
              MOVELEFT( IOCACHE[ ENEMYID], SCRNADDR.P^, 10);
              ENEMYID := ENEMYID + 10    (* 10 BYTES === 70 PIXELS PER LINE *)
            END;
        END;
        
        
      PROCEDURE SVREWARD;  (* P010503 *)
      
        VAR
             BATRESLT : TBATRSLT;
             UNUSEDX  : INTEGER;
             X        : INTEGER;
             
             
        BEGIN
          FOR X := 0 TO PARTYCNT - 1 DO
            IF (CHARACTR[ X].STATUS = ASLEEP) OR
               (CHARACTR[ X].STATUS = AFRAID) THEN
              CHARACTR[ X].STATUS := OK;
              
          MOVELEFT( IOCACHE[ GETREC( ZZERO, 0, SIZEOF( SCNTOC))],
                    LLBASE04,
                    2);
          MOVELEFT( DRAINED, BATRESLT.DRAINED, 12);
          FOR X := 1 TO 4 DO
            BEGIN
              BATRESLT.ENMYID[ X] := BATTLERC[ X].A.ENEMYID;
              BATRESLT.ENMYCNT[ X] := BATTLERC[ X].A.ENMYCNT
            END;
            
          MOVELEFT( BATRESLT, IOCACHE, SIZEOF( TBATRSLT))
        END;
        
        
        
      PROCEDURE INITATTK;  (* P010504 *)
      
        VAR
             UNUSEDWW : INTEGER;
             UNUSEDXX : INTEGER;
             UNUSEDYY : INTEGER;
             UNUSEDZZ : INTEGER;
             CHARX    : INTEGER;
             GROUPI   : INTEGER;
      
      
        PROCEDURE INITGRUP;  (* P010505 *)
        
          PROCEDURE ENGROUPS( ENMYI:    INTEGER;     (* P010506 *)
                              ENMYGRUP: INTEGER);
          
            BEGIN
              REPEAT
                MOVELEFT( IOCACHE[ GETREC( ZENEMY, ENMYI, SIZEOF( TENEMY))],
                          BATTLERC[ ENMYGRUP].B,
                          SIZEOF( TENEMY));
                          
                IF BATTLERC[ ENMYGRUP].B.UNIQUE = 0 THEN
                  ENMYI := BATTLERC[ ENMYGRUP].B.ENMYTEAM;
                
              UNTIL BATTLERC[ ENMYGRUP].B.UNIQUE <> 0;
              
              BATTLERC[ ENMYGRUP].A.ENEMYID := ENMYI;
              IF ENMYGRUP < 4 THEN
                IF BATTLERC[ ENMYGRUP].B.ENMYTEAM >= 0 THEN
                  IF ENMYGRUP <= MAZELEV THEN
                    IF RANDOM MOD 100 < BATTLERC[ ENMYGRUP].B.TEAMPERC THEN
                      ENGROUPS( BATTLERC[ ENMYGRUP].B.ENMYTEAM, ENMYGRUP + 1)
            END;
            
            
            
          FUNCTION ENEMYCNT( HPREC: THPREC) : INTEGER;  (* P010507 *)
          
            BEGIN
              LLBASE04 := HPREC.HPMINAD;
              WHILE HPREC.LEVEL > 0 DO
                BEGIN
                  LLBASE04 := LLBASE04 + (RANDOM MOD HPREC.HPFAC) + 1;
                  HPREC.LEVEL := HPREC.LEVEL - 1
                END;
              ENEMYCNT := LLBASE04
            END;
            
        
          BEGIN (* INITGRUP *)
            FOR GROUPI := 1 TO 4 DO
              BEGIN
                BATTLERC[ GROUPI].A.ENMYCNT  := 0;
                BATTLERC[ GROUPI].A.ALIVECNT := 0;
                BATTLERC[ GROUPI].A.ENEMYID  := -1
              END;
            ENGROUPS( ENEMYINX, 1);
            
            ENEMYINX := BATTLERC[ 1].A.ENEMYID;
            ENEMYPIC( GETREC( ZSPCCHRS, BATTLERC[ 1].B.PIC, 512));
            
            FOR GROUPI := 1 TO 4 DO
              BEGIN
                IF BATTLERC[ GROUPI].A.ENEMYID <> -1 THEN
                  BEGIN
                    BATTLERC[ GROUPI].A.ENMYCNT := 
                      ENEMYCNT( BATTLERC[ GROUPI].B.CALC1);
                    IF BATTLERC[ GROUPI].A.ENMYCNT > (4 + MAZELEV) THEN
                      BATTLERC[ GROUPI].A.ENMYCNT := 4 + MAZELEV;
                    IF BATTLERC[ GROUPI].A.ENMYCNT > 9 THEN
                      BATTLERC[ GROUPI].A.ENMYCNT := 9;
                    IF BATTLERC[ GROUPI].A.ENMYCNT < 1 THEN
                      BATTLERC[ GROUPI].A.ENMYCNT := 1;
                    BATTLERC[ GROUPI].A.ALIVECNT :=
                      BATTLERC[ GROUPI].A.ENMYCNT;
                    BATTLERC[ GROUPI].A.IDENTIFI := FALSE;
                    
                    FOR CHARX := 0 TO (BATTLERC[ GROUPI].A.ENMYCNT - 1) DO
                      WITH BATTLERC[ GROUPI].A.TEMP04[ CHARX] DO
                        BEGIN
                          ARMORCL  := 0;
                          INAUDCNT := 0;
                          HPLEFT   :=
                                    ENEMYCNT( BATTLERC[ GROUPI].B.HPREC);
                          STATUS   := OK
                        END
                  END
                END;
                
          END;  (* INITGRUP *)
        
        
        PROCEDURE INTPARTY;  (* P010508 *)
        
          BEGIN
            BATTLERC[ 0].A.ENMYCNT := PARTYCNT;
            BATTLERC[ 0].A.ALIVECNT := PARTYCNT;
            FOR CHARX := 0 TO (PARTYCNT - 1) DO
              BEGIN
                WITH BATTLERC[ 0].A.TEMP04[ CHARX] DO
                  BEGIN
                    ARMORCL  := 0;
                    INAUDCNT := 0;
                    HPLEFT   := CHARACTR[ CHARX].HPLEFT;
                    STATUS   := CHARACTR[ CHARX].STATUS;
                    CHARACTR[ CHARX].WEPVSTY3[ 1] :=
                      CHARACTR[ CHARX].WEPVSTY3[ 0];
                    CHARACTR[ CHARX].WEPVSTY2[ 1] :=
                      CHARACTR[ CHARX].WEPVSTY2[ 0]
                  END
              END
          END;
          
          
        PROCEDURE FRIENDLY;  (* P010509 *)
        
          VAR
              GOODLEAV : BOOLEAN; (* MULTIPLE USES *)
              UNUSEDYY : BOOLEAN;
              ZERO99   : INTEGER;
              INDEX    : INTEGER;
        
          BEGIN (* FRIENDLY *)
            GOODLEAV := FALSE;
            FOR INDEX := 0 TO PARTYCNT - 1 DO
              BEGIN
                GOODLEAV := GOODLEAV OR (CHARACTR[ INDEX].ALIGN = GOOD)
              END;
            IF NOT GOODLEAV THEN
              EXIT( FRIENDLY);
            
            ZERO99  := RANDOM MOD 100;
            INDEX := 50;
            CASE BATTLERC[ 1].B.CLASS OF
              0:  INDEX := 60;
              1:  INDEX := 55;
              2:  INDEX := 65;
              3:  INDEX := 53;
              4:  INDEX := 80;
              
              7:  INDEX := 75;
            END;
            IF (ZERO99 > INDEX) OR (ZERO99 < 50) THEN
              EXIT( FRIENDLY);
              
            FOR INDEX := 1 TO 4 DO
              BATTLERC[ INDEX].A.IDENTIFI := TRUE;
            CLRRECT( 1, 11, 38, 4);
            MVCURSOR( 1, 11);
            PRINTSTR( 'A FRIENDLY GROUP OF ');
            PRINTSTR( BATTLERC[ 1].B.NAMES);
            PRINTSTR( '.');
            MVCURSOR( 1, 12);
            PRINTSTR( 'THEY HAIL YOU IN WELCOME!');
            MVCURSOR( 1, 14);
            PRINTSTR( 'YOU MAY F)IGHT OR L)EAVE IN PEACE.');
            SURPRISE := 0;
            REPEAT
              GETKEY
            UNTIL (INCHAR = 'F') OR (INCHAR = 'L');
            IF INCHAR = 'L' THEN
              BEGIN
                XGOTO := XRUNNER;
                EXIT( COMBAT)
              END;
            FOR INDEX := 0 TO PARTYCNT - 1 DO
              IF CHARACTR[ INDEX].ALIGN = GOOD THEN
                IF (RANDOM MOD 2000) = 565 THEN
                  CHARACTR[ INDEX].ALIGN := EVIL
          END;  (* FRIENDLY *)
        
        
        BEGIN  (* INITATTK *)
          CLRRECT( 13, 1, 26, 4);
          CLRRECT( 13, 6, 26, 4);
          CLRRECT( 1, 11, 38, 4);
          INITGRUP;
          INTPARTY;
          FILLCHAR( DRAINED, 12, 0);
          FOR LLBASE04 := 0 TO PARTYCNT - 1 DO
            PREBATOR[ LLBASE04] := CHARDISK[ LLBASE04];
          IF (RANDOM MOD 100) > 80 THEN
            SURPRISE := 1
          ELSE IF (RANDOM MOD 100) > 80 THEN
            SURPRISE := 2
          ELSE
            SURPRISE := 0;
          FRIENDLY
        END;  (* INITATTK *)
        
      
      BEGIN (* CINIT *)
        IF CINITFL1 = 0 THEN
          INITATTK
        ELSE
          SVREWARD
      END;  (* CINIT *)
  
    SEGMENT PROCEDURE CUTIL;


      PROCEDURE CACTION;  (* P010602 *)
      
        VAR
             SPLGRCNT : ARRAY[ 0..5] OF INTEGER;
             BDISPELL : BOOLEAN;
             MYCHARX  : INTEGER;
             AGIL1TEN : INTEGER;
             
          
        PROCEDURE WHICHGRP( SOLICIT:   STRING;   (* P010603 *)
                            SPELLHSH:  INTEGER);
                            
        
          BEGIN
            IF BATTLERC[ 2].A.ALIVECNT = 0 THEN
              BEGIN
                BATTLERC[ 0].A.TEMP04[ MYCHARX].VICTIM := 1;
                BATTLERC[ 0].A.TEMP04[ MYCHARX].SPELLHSH := SPELLHSH;
                EXIT( WHICHGRP)
              END;
            MVCURSOR( 26 - ( LENGTH( SOLICIT) DIV 2), 8);
            PRINTSTR( SOLICIT);
            REPEAT
              GETKEY
            UNTIL ((INCHAR >= '1') AND (INCHAR < '5')) OR
                   (INCHAR = CHR( CRETURN));
            IF INCHAR = CHR( CRETURN) THEN
              BEGIN
                BATTLERC[ 0].A.TEMP04[ MYCHARX].SPELLHSH := -999;
                EXIT( WHICHGRP)
              END;
            IF BATTLERC[ ORD( INCHAR) - ORD( '0')].A.ALIVECNT = 0 THEN
              BEGIN
                BATTLERC[ 0].A.TEMP04[ MYCHARX].SPELLHSH := -999;
                EXIT( WHICHGRP)
              END;
            BATTLERC[ 0].A.TEMP04[ MYCHARX].VICTIM := ORD( INCHAR) - ORD( '0');
            BATTLERC[ 0].A.TEMP04[ MYCHARX].SPELLHSH := SPELLHSH;
            CLRRECT( 13, 8, 26, 2)
          END;
          
          
        PROCEDURE USEITEM;  (* P010604 *)
        
          VAR
               BUSEABLE : ARRAY[ 1..8] OF BOOLEAN;
               POSSX    : INTEGER;
               OBJECT   : TOBJREC;
        
        
          PROCEDURE READOBJT;  (* P010605 *)
          
            BEGIN
              MOVELEFT( 
                IOCACHE[ GETREC(
                        ZOBJECT,
                        CHARACTR[ MYCHARX].POSS.POSSESS[ POSSX].EQINDEX,
                        SIZEOF( TOBJREC))],
                OBJECT,
                SIZEOF( TOBJREC))
            END;
            
            
          PROCEDURE DSPITEMS;  (* P010606 *)
          
            VAR
                 ITEMCNT : INTEGER;
          
            BEGIN
              CLRRECT( 1, 11, 38, 4);
              ITEMCNT := 0;
              FOR POSSX := 1 TO CHARACTR[ MYCHARX].POSS.POSSCNT DO
                BEGIN
                  BUSEABLE[ POSSX] := FALSE;
                  MVCURSOR( 1 + 19 * ((POSSX - 1) MOD 2),
                           11 + (POSSX - 1) DIV 2);
                  READOBJT;
                  IF OBJECT.SPELLPWR > 0 THEN
                    IF (OBJECT.OBJTYPE = SPECIAL) OR
                       (CHARACTR[ MYCHARX].POSS.POSSESS[ POSSX].EQUIPED) THEN
                      BEGIN
                        ITEMCNT := ITEMCNT + 1;
                        BUSEABLE[ POSSX] := TRUE;
                        PRINTNUM( POSSX, 1);
                        PRINTSTR( ') ');
                        IF CHARACTR[ MYCHARX].POSS.POSSESS[ POSSX].IDENTIF THEN
                          PRINTSTR( OBJECT.NAME)
                        ELSE
                          PRINTSTR( OBJECT.NAMEUNK)
                      END
                END;
              IF ITEMCNT = 0 THEN
                EXIT( USEITEM);
              MVCURSOR( 13, 8);
              PRINTSTR( 'WHICH ITEM (RETURN EXITS)?')
            END;
            
            
          PROCEDURE CHGITEM;  (* P010607 *)
          
            BEGIN
              IF (RANDOM MOD 100) >= OBJECT.CHGCHANC THEN
                EXIT( CHGITEM);
              WITH CHARACTR[ MYCHARX].POSS.POSSESS[ POSSX] DO
                BEGIN
                  EQINDEX := OBJECT.CHANGETO;
                  IDENTIF := FALSE
                END;
            END;
            
            
          PROCEDURE UIGENERC( SPELLHSH: INTEGER);  (* P010608 *)
          
            BEGIN
              BATTLERC[ 0].A.TEMP04[ MYCHARX].SPELLHSH := SPELLHSH;
              BATTLERC[ 0].A.TEMP04[ MYCHARX].VICTIM := -1;
              CHGITEM
            END;
            
            
          PROCEDURE UIPERSON( SPELLHSH: INTEGER);  (* P010609 *)
          
            BEGIN
              MVCURSOR( 15, 8);
              PRINTSTR( 'USE ITEM ON PERSON # ?');
              REPEAT
                GETKEY
              UNTIL (INCHAR >= '1') AND (INCHAR <= CHR( ORD('0') + PARTYCNT));
              BATTLERC[ 0].A.TEMP04[ MYCHARX].VICTIM :=
                 ORD( INCHAR) - ORD('0') - 1;
              BATTLERC[ 0].A.TEMP04[ MYCHARX].SPELLHSH := SPELLHSH;
              CHGITEM
            END;
            
            
          PROCEDURE UIGROUP( SPELLHSH : INTEGER);  (* P01060A *)
          
            BEGIN
              WHICHGRP( 'USE ITEM ON WHAT GROUP # ?', SPELLHSH);
              CHGITEM
            END;
            
            
          BEGIN (* USEITEM *)
            IF CHARACTR[ MYCHARX].POSS.POSSCNT = 0 THEN
              EXIT( USEITEM);
            DSPITEMS;
            
            REPEAT
              GETKEY;
              POSSX := ORD( INCHAR) - ORD( '0');
              IF INCHAR = CHR( CRETURN) THEN
                EXIT( USEITEM)
            UNTIL (POSSX > 0) AND
                  (POSSX <= CHARACTR[ MYCHARX].POSS.POSSCNT) AND
                  (BUSEABLE[ POSSX]);
            READOBJT;
            CLRRECT( 13, 6, 26, 4);
            LLBASE04 := SCNTOC.SPELLHSH[ OBJECT.SPELLPWR];
            CASE SCNTOC.SPELL012[ OBJECT.SPELLPWR] OF
              GENERIC:  UIGENERC( LLBASE04);
               PERSON:  UIPERSON( LLBASE04);
                GROUP:  UIGROUP(  LLBASE04);
            END
          END; (* USEITEM *)
          
          
        PROCEDURE GETSPELL;  (* P01060B *)
        
          VAR
              SPELLNAM : STRING[ 14];
              SPELLCST : INTEGER;
              SPELNAML : INTEGER;
              SPELCHRA : INTEGER;
              SPELNAMI : INTEGER;
        
        
          PROCEDURE DOSPELL;  (* P01060C *)
          
            VAR
                 SPELLX : INTEGER;
                 
                 
            PROCEDURE CASTCHK( SPELLI:  INTEGER;  (* P01060D *)
                               SPELLGR: INTEGER);
            
              BEGIN
                IF CHARACTR[ MYCHARX].SPELLSKN[ SPELLI] THEN
                  IF (SPELLI < 22) AND 
                     (CHARACTR[ MYCHARX].MAGESP[ SPELLGR] > 0) THEN
                       SPLGRCNT[ MYCHARX] := SPELLGR
                  ELSE
                      IF CHARACTR[ MYCHARX].PRIESTSP[ SPELLGR] > 0 THEN
                          SPLGRCNT[ MYCHARX] := SPELLGR + 10;
              
                MVCURSOR( 13, 9);
                IF SPLGRCNT[ MYCHARX] > 0 THEN
                  EXIT( CASTCHK)
                ELSE
                  IF CHARACTR[ MYCHARX].SPELLSKN[ SPELLI] THEN
                    PRINTSTR( 'SPELL POINTS EXHAUSTED')
                  ELSE
                    PRINTSTR( 'YOU DONT KNOW THAT SPELL');
                PAUSE1;
                EXIT( GETSPELL)
              END;
              
              
            PROCEDURE SPGENERC( SPELLI:  INTEGER;  (* P01060E *)
                                SPELLGR: INTEGER);
            
              BEGIN
                CASTCHK( SPELLI, SPELLGR);
                BATTLERC[ 0].A.TEMP04[ MYCHARX].SPELLHSH := SPELLCST;
                BATTLERC[ 0].A.TEMP04[ MYCHARX].VICTIM := -1
              END;
              
              
            PROCEDURE SPPERSON( SPELLI:  INTEGER;  (* P01060F *)
                                SPELLGR: INTEGER);
            
              BEGIN
                CASTCHK( SPELLI, SPELLGR);
                MVCURSOR( 13, 8);
                PRINTSTR( ' CAST SPELL ON PERSON # ?');
                REPEAT
                  GETKEY
                UNTIL (INCHAR >=  '1') AND
                      (ORD (INCHAR) <= ( (ORD('0') + PARTYCNT) ));
                BATTLERC[ 0].A.TEMP04[ MYCHARX].VICTIM := 
                  ORD( INCHAR) - ORD( '0') - 1;
                BATTLERC[ 0].A.TEMP04[ MYCHARX].SPELLHSH := SPELLCST;
                CLRRECT( 13, 8, 26, 1)
              END;
              
              
            PROCEDURE SPGROUP( SPELLI:  INTEGER;  (* P010610 *)
                               SPELLGR: INTEGER);
            
              BEGIN
                CASTCHK( SPELLI, SPELLGR);
                WHICHGRP( 'CAST SPELL ON GROUP #?', SPELLCST)
              END;
              
              
            BEGIN (* DOSPELL *)
              FOR SPELLX := 0 TO 50 DO
                IF SPELLCST = SCNTOC.SPELLHSH[ SPELLX] THEN
                  CASE SCNTOC.SPELL012[ SPELLX] OF
                    GENERIC:  SPGENERC( SPELLX, SCNTOC.SPELLGRP[ SPELLX]);
                     PERSON:  SPPERSON( SPELLX, SCNTOC.SPELLGRP[ SPELLX]);
                      GROUP:  SPGROUP(  SPELLX, SCNTOC.SPELLGRP[ SPELLX]);
                  END
            END;  (* DOSPELL *)
            
            
          BEGIN  (* GETSPELL *)
            MVCURSOR( 13, 8);
            PRINTSTR( 'SPELL NAME ? >');
            GETSTR( SPELLNAM, 27, 8);
            SPELNAML := LENGTH( SPELLNAM);
            IF SPELNAML = 0 THEN
              EXIT( GETSPELL);
            SPELLCST := SPELNAML;
            FOR SPELNAMI := 1 TO SPELNAML DO
              BEGIN
                SPELCHRA := ORD( SPELLNAM[ SPELNAMI]) - 64;
                SPELLCST := SPELLCST + (SPELCHRA * SPELCHRA * SPELNAMI)
              END;
            CLRRECT( 13, 8, 26, 1);
            DOSPELL
          END; (* GETSPELL *)
          
          
        PROCEDURE RUNAWAY;  (* P010611 *)
        
          VAR
               TEMP : INTEGER;  (* MULTIPLE USES *)
        
        
          PROCEDURE RUNFAILD;  (* P010612 *)
          
            BEGIN
              FOR TEMP := 0 TO PARTYCNT - 1 DO
                BATTLERC[ 0].A.TEMP04[ TEMP].AGILITY := -1;
              EXIT( CACTION)
            END;
            
            
          BEGIN (* RUNAWAY *)
            CLRRECT( 13, 6, 26, 4);
            TEMP := 38 - 3 * MAZELEV;
            IF PARTYCNT < 4 THEN
              TEMP := TEMP + 20 - 5 * PARTYCNT;
            IF BASE12.MYSTRENG > ENSTRENG THEN
              TEMP := TEMP + 20;
            IF MAZELEV = 10 THEN
              TEMP := -1;
            IF (RANDOM MOD 100) > TEMP THEN
              RUNFAILD;
            FOR TEMP := 1 TO 4 DO
              BEGIN
                BATTLERC[ TEMP].A.ALIVECNT := 0;
                BATTLERC[ TEMP].A.ENMYCNT := 0
              END;
            XGOTO := XREWARD2;
            DONEFIGH := TRUE;
            EXIT( CUTIL)
          END; (* RUNAWAY *)
        
        
        PROCEDURE DOSUPRIS;  (* P010613 *)
        
          BEGIN
            CLRRECT( 13, 6, 26, 4);
            CLRRECT( 1, 11, 38, 4);
            MVCURSOR( 1, 12);
          
            IF SURPRISE = 1 THEN
              PRINTSTR( 'YOU SURPRISED THE MONSTERS!')
            ELSE
              IF SURPRISE = 2 THEN
                PRINTSTR( 'THE MONSTERS SURPRISED YOU!');
            IF SURPRISE <> 0 THEN
              BEGIN
                WRITE( CHR( 7));
                WRITE( CHR( 7));
                WRITE( CHR( 7));
                PAUSE2;
                PAUSE2
              END
          END;
          
          
        BEGIN (* CACTION *)
          DOSUPRIS;
          MYCHARX := 0;
          FILLCHAR( SPLGRCNT, 12, 0);
          WHILE MYCHARX < PARTYCNT DO
            BEGIN
              REPEAT
            
                IF (BATTLERC[ 0].A.TEMP04[ MYCHARX].STATUS = OK) AND
                   (SURPRISE <> 2) THEN
                  BEGIN
                    BATTLERC[ 0].A.TEMP04[ MYCHARX].SPELLHSH := -999;
                    REPEAT
                      AGIL1TEN := RANDOM MOD 10;
                      CASE CHARACTR[ MYCHARX].ATTRIB[ AGILITY] OF
                          3:  AGIL1TEN := AGIL1TEN + 3;
                        4,5:  AGIL1TEN := AGIL1TEN + 2;
                        6,7:  AGIL1TEN := AGIL1TEN + 1;
                         15:  AGIL1TEN := AGIL1TEN - 1;
                         16:  AGIL1TEN := AGIL1TEN - 2;
                         17:  AGIL1TEN := AGIL1TEN - 3;
                         18:  AGIL1TEN := AGIL1TEN - 4;
                      END;
                      IF AGIL1TEN < 1 THEN
                        AGIL1TEN := 1
                      ELSE
                        IF AGIL1TEN > 10 THEN
                          AGIL1TEN := 10;
                      BATTLERC[ 0].A.TEMP04[ MYCHARX].AGILITY := AGIL1TEN;
                      UNITCLEAR( 1);
                      MVCURSOR( 13, 6);
                      PRINTSTR( CHARACTR[ MYCHARX].NAME);
                      PRINTSTR( '''S OPTIONS');
                      MVCURSOR( 13, 8);
                      IF MYCHARX < 3 THEN
                        BEGIN
                          PRINTSTR( 'F)IGHT  ')
                        END;
                      PRINTSTR( 'S)PELL  P)ARRY');
                      MVCURSOR( 13, 9);
                      PRINTSTR( 'R)UN    U)SE    ');
                      BDISPELL := FALSE;
                      IF (CHARACTR[ MYCHARX].CLASS = PRIEST)
                         OR
                         ((CHARACTR[ MYCHARX].CLASS = LORD) AND 
                          (CHARACTR[ MYCHARX].CHARLEV > 8)) 
                         OR
                         ((CHARACTR[ MYCHARX].CLASS = BISHOP) AND
                          (CHARACTR[ MYCHARX].CHARLEV > 3)) THEN
                          
                          BEGIN
                            BDISPELL := TRUE;
                            PRINTSTR( 'D)ISPELL ')
                          END;
                          
                      REPEAT
                        GETKEY
                      UNTIL (INCHAR = 'F') OR (INCHAR = 'S') OR
                            (INCHAR = 'P') OR (INCHAR = 'U') OR
                            (INCHAR = 'D') OR (INCHAR = 'R') OR
                            (INCHAR = 'B');
                            
                      CLRRECT( 13, 8, 26, 2);
                      SPLGRCNT[ MYCHARX] := 0;
                          
                      CASE INCHAR OF
                      
                        'D':  IF BDISPELL THEN
                                WHICHGRP( 'DISPELL WHICH GROUP# ?', -5);
                              
                        'R':  RUNAWAY;
                        
                        'F':  IF MYCHARX < 3 THEN
                                WHICHGRP( 'FIGHT AGAINST GROUP# ?', -1);
                              
                        'P':  BEGIN
                                 BATTLERC[ 0].A.TEMP04[ MYCHARX].SPELLHSH := 0;
                                 BATTLERC[ 0].A.TEMP04[ MYCHARX].AGILITY := -1;
                              END;
                              
                        'S':  GETSPELL;
                              
                        'U':  BEGIN
                                USEITEM;
                                CLRRECT( 1, 11, 38, 4)
                              END;
                        
                        'B':  IF MYCHARX > 0 THEN
                                BATTLERC[ 0].A.TEMP04[ MYCHARX].SPELLHSH :=
                                  -100;
                      END;
                      
                    CLRRECT( 13, 6, 26, 4);
                    UNTIL BATTLERC[ 0].A.TEMP04[ MYCHARX].SPELLHSH <> -999;
                    IF BATTLERC[ 0].A.TEMP04[ MYCHARX].SPELLHSH = -100 THEN
                      MYCHARX := -1;
                  END
                ELSE
                  BATTLERC[ 0].A.TEMP04[ MYCHARX].AGILITY := -1;
                  
                MYCHARX := MYCHARX + 1
                  
              UNTIL MYCHARX = PARTYCNT;
              
              IF SURPRISE <> 2 THEN
                BEGIN
                  MVCURSOR( 14, 6);
                  PRINTSTR( 'PRESS [RETURN] TO FIGHT,');
                  MVCURSOR( 25, 7);
                  PRINTSTR( 'OR');
                  MVCURSOR( 14, 8);
                  PRINTSTR( 'GO B)ACK TO REDO OPTIONS');
                  
                  REPEAT
                    GETKEY
                  UNTIL (INCHAR = CHR( CRETURN)) OR (INCHAR = 'B');
                  
                  IF INCHAR = 'B' THEN
                    MYCHARX := 0
                END;
                CLRRECT( 13, 6, 26, 4);
                CLRRECT( 1, 11, 38, 4)
            END; (* WHILE LOOP *)
          
          FOR MYCHARX := 0 TO PARTYCNT - 1 DO
            BEGIN
              IF SPLGRCNT[ MYCHARX] > 0 THEN
                BEGIN
                  IF SPLGRCNT[ MYCHARX] > 10 THEN
                   CHARACTR[ MYCHARX].PRIESTSP[ SPLGRCNT[ MYCHARX] - 10]
                   := CHARACTR[ MYCHARX].PRIESTSP[ SPLGRCNT[ MYCHARX] - 10] - 1
                  ELSE
                   CHARACTR[ MYCHARX].MAGESP[ SPLGRCNT[ MYCHARX]]
                   := CHARACTR[ MYCHARX].MAGESP[ SPLGRCNT[ MYCHARX]] - 1
                END
            END;
        END;  (* CACTION *)
        

      PROCEDURE ENATTACK;  (* P010614 *)
      
        VAR
            UNUSEDXX : INTEGER;
            ATTCKTYP : INTEGER;
            CHARX    : INTEGER;
            ENEMYX   : INTEGER;
            GROUPI   : INTEGER;
      
      
        FUNCTION CANATTCK : BOOLEAN;  (* P010615 *)
        
          BEGIN
            CANATTCK :=
             (NOT CHARACTR[ CHARX].WEPVSTY2[ 1][ BATTLERC[ GROUPI].B.CLASS])
               OR
             ((RANDOM MOD 100) < 50)
          END;
          
          
        PROCEDURE ENEMYSPL;  (* P010616 *)
        
        
          PROCEDURE SPELLEZR( VAR SPELLGR: INTEGER);  (* P010617 *)
          
            BEGIN
              IF RANDOM MOD (BATTLERC[ GROUPI].A.ALIVECNT + 2) = 0 THEN
                SPELLGR := SPELLGR - 1
            END;
            
            
          PROCEDURE GETMAGSP( SPELLLEV: INTEGER);  (* P010618 *)
          
            VAR
                 SPELLCAS : INTEGER;
                 TWOTHIRD : BOOLEAN;
          
            BEGIN
              WHILE (SPELLLEV > 1) AND ( (RANDOM MOD 100) > 70) DO
                SPELLLEV := SPELLLEV - 1;
              TWOTHIRD := (RANDOM MOD 100) > 33;
              SPELLEZR( BATTLERC[ GROUPI].B.MAGSPELS);
              
              CASE SPELLLEV OF
              
                1:  IF TWOTHIRD THEN
                      SPELLCAS := KATINO
                    ELSE
                      SPELLCAS := HALITO;
                      
                2:  IF TWOTHIRD THEN
                      SPELLCAS := DILTO
                    ELSE
                      SPELLCAS := HALITO;  (* BUG *)
                      
                3:  IF TWOTHIRD THEN
                      SPELLCAS := MOLITO
                    ELSE
                      SPELLCAS := MAHALITO;
                      
                4:  IF TWOTHIRD THEN
                      SPELLCAS := DALTO
                    ELSE
                      SPELLCAS := LAHALITO;  (* ...HMMM *)
                      
                5:  IF TWOTHIRD THEN
                      SPELLCAS := LAHALITO   (* ...HMMM *)
                    ELSE
                      SPELLCAS := MADALTO;
                      
                6:  IF TWOTHIRD THEN
                      SPELLCAS := MADALTO    (* ...HMMM *)
                    ELSE
                      SPELLCAS := ZILWAN;
                      
                7:  SPELLCAS := TILTOWAI;
              END;
              
              ATTCKTYP := SPELLCAS
            END;  (* GETMAGSP *)
            
            
          PROCEDURE GETPRISP( SPELLLEV : INTEGER);  (* P010619 *)
          
            VAR
                 SPELLCAS : INTEGER;
                 TWOTHIRD : BOOLEAN;
                 
            BEGIN
              TWOTHIRD := (RANDOM MOD 100) > 33;
              SPELLEZR( BATTLERC[ GROUPI].B.PRISPELS);
              
              CASE SPELLLEV OF
              
                1:  SPELLCAS := BADIOS;
                
                2:  SPELLCAS := MONTINO;
                
                3:  IF TWOTHIRD THEN
                      SPELLCAS := BADIOS
                    ELSE
                      SPELLCAS := BADIAL;
                      
                4:  SPELLCAS := BADIAL;
                
                5:  IF TWOTHIRD THEN
                      SPELLCAS := BADIALMA
                    ELSE
                      SPELLCAS := BADI;
                      
                6:  IF TWOTHIRD THEN
                      SPELLCAS := LORTO
                    ELSE
                      SPELLCAS := MABADI;
                      
                7:  SPELLCAS := MABADI;
              END;
              
              ATTCKTYP := SPELLCAS
            END;  (* GETPRISP *)
            
            
          BEGIN (* ENEMYSPL *)
            IF BATTLERC[ GROUPI].B.MAGSPELS > 0 THEN
              IF (RANDOM MOD 100) < 75 THEN
                GETMAGSP( BATTLERC[ GROUPI].B.MAGSPELS);
                
            IF ATTCKTYP = 0 THEN
              IF BATTLERC[ GROUPI].B.PRISPELS > 0 THEN
                IF (RANDOM MOD 100) < 75 THEN
                  GETPRISP( BATTLERC[ GROUPI].B.PRISPELS);
          END;  (* ENEMYSPL *)
          
          
        PROCEDURE YELLHELP;  (* P01061A *)
        
          BEGIN
            IF BATTLERC[ GROUPI].B.SPPC[ 6] THEN
              IF BATTLERC[ GROUPI].A.ALIVECNT < 5 THEN
                IF (RANDOM MOD 100) < 75 THEN
                  ATTCKTYP := -4
          END;
          
          
        PROCEDURE RUNENMY;  (* P01061B *)
        
          BEGIN
            IF NOT (BATTLERC[ GROUPI].B.SPPC[ 5]) THEN
              EXIT( RUNENMY);
            IF BASE12.MYSTRENG > ENSTRENG THEN
              IF (RANDOM MOD 100) < 65 THEN
                ATTCKTYP := -2
          END;
          
          
        PROCEDURE BREATHES;  (* P01061C *)
        
          BEGIN
            IF BATTLERC[ GROUPI].B.BREATHE > 0 THEN
              IF (RANDOM MOD 100) < 60 THEN
                ATTCKTYP := -3
          END;
          
        PROCEDURE ADVANCE;  (* P01061D *)
        
          VAR
               ADVSTREN : ARRAY[ 1..4] OF INTEGER;
               ENEMYX   : INTEGER;
               GROUPI   : INTEGER;
               TEMPE2   : TENEMY2;
          
          
          PROCEDURE MOVETEXT( GROUPI : INTEGER);  (* P01061E *)
          
            (* MOVE STRINGS OF TEXT AROUND ON THE SCREEN 
               FOR THE VARIOUS MONSTER GROUP NAMES       *)
          
            TYPE
                 MEMVAR = RECORD CASE INTEGER OF
                    1:  (I: INTEGER);
                    2:  (A: ARRAY[ 0..10] OF INTEGER);
                   END;
                   
                 MEMVAR2 = RECORD CASE INTEGER OF
                    1:  (I: INTEGER);
                    2:  (P: ^INTEGER);
                   END;
                   
            VAR
                 LINEX    : INTEGER;
                 PIX      : INTEGER;
                 SAVEROW  : ARRAY[ 0..7] OF MEMVAR;
                 LINEPTRS : ARRAY[ 0..15] OF MEMVAR2;
            
            BEGIN
            
              (* SET UP POINTERS TO 2 TEXT ROWS.  EACH ROW IS 8 PIXELS. *)
            
              LINEPTRS[ 0].I :=  8192 + 128 *  GROUPI      + 16;
              LINEPTRS[ 8].I :=  8192 + 128 * (GROUPI + 1) + 16;
              FOR PIX := 1 TO 7 DO
                BEGIN
                  LINEPTRS[ PIX].I :=     LINEPTRS[ PIX - 1].I + 1024;
                  LINEPTRS[ PIX + 8].I := LINEPTRS[ PIX + 7].I + 1024
                END;
              WRITE( CHR( 7));
              
              (* SAVE UPPER ROW OF TEXT *)
              
              FOR PIX := 0 TO 7 DO
                MOVELEFT( LINEPTRS[ PIX].P^, SAVEROW[ PIX].I, 22);
                 
                (* IS 22 LARGE ENOUGH *)
                
              (* CLEAR UPPER OF THE TWO ROWS *)
                
              FOR PIX := 0 TO 7 DO
                FILLCHAR( LINEPTRS[ PIX].P^, 22, 0);
              WRITE( CHR( 7));
              
              (* MOVE LOWER ROW OF TEXT UPWARD A PIXEL AT A TIME *)
              
              FOR PIX := 7 DOWNTO 0 DO
                BEGIN
                  FOR LINEX := PIX TO PIX + 7 DO
                    MOVELEFT( LINEPTRS[ LINEX + 1].P^, LINEPTRS[ LINEX].P^, 22);
                  FILLCHAR( LINEPTRS[ PIX + 8].P^, 22, 0)
                END;
              WRITE( CHR( 7));
              
              (* MOVE SAVED ROW OF TEXT TO LOWER ROW *)
              
              FOR PIX := 0 TO 7 DO
                MOVELEFT( SAVEROW[ PIX].I, LINEPTRS[ PIX + 8].P^, 22);
            END;
            
            
          BEGIN (* ADVANCE *)
            FOR GROUPI := 1 TO 4 DO
              BEGIN
                ADVSTREN[ GROUPI] := 0;
                FOR ENEMYX := 0 TO BATTLERC[ GROUPI].A.ALIVECNT - 1 DO
                  IF BATTLERC[ GROUPI].A.TEMP04[ ENEMYX].STATUS = OK THEN
                    ADVSTREN[ GROUPI] := ADVSTREN[ GROUPI]
                                + BATTLERC[ GROUPI].A.TEMP04[ ENEMYX].HPLEFT
                                - 3 * (BATTLERC[ GROUPI].B.MAGSPELS + 
                                       BATTLERC[ GROUPI].B.PRISPELS);
                                         
                IF ADVSTREN[ GROUPI] > 1000 THEN
                  ADVSTREN[ GROUPI] := 1000
                ELSE IF ADVSTREN[ GROUPI] < 1 THEN
                  ADVSTREN[ GROUPI] := 1;
              END;
            
            FOR GROUPI := 4 DOWNTO 2 DO
              BEGIN
                IF BATTLERC[ GROUPI].A.ALIVECNT > 0 THEN
                  BEGIN
                    IF (RANDOM MOD 100) <= 
                       30 + ((20 * ADVSTREN[ GROUPI]) DIV ADVSTREN[ GROUPI - 1]) THEN
                       
                      BEGIN
                        MVCURSOR( 1, 15 - GROUPI);
                        PRINTSTR( 'THE ');
                        IF BATTLERC[ GROUPI].A.IDENTIFI THEN
                          PRINTSTR( BATTLERC[ GROUPI].B.NAMES)
                        ELSE
                          PRINTSTR( BATTLERC[ GROUPI].B.NAMEUNKS);
                        PRINTSTR( ' ADVANCE!');
                        MOVETEXT( GROUPI - 1);
                        PAUSE1;
                        
                        ENEMYX                := ADVSTREN[ GROUPI];
                        ADVSTREN[ GROUPI]     := ADVSTREN[ GROUPI - 1];
                        ADVSTREN[ GROUPI - 1] := ENEMYX;
                        
                        TEMPE2                := BATTLERC[ GROUPI];
                        BATTLERC[ GROUPI]     := BATTLERC[ GROUPI - 1];
                        BATTLERC[ GROUPI - 1] := TEMPE2
                      END;
                  END;
              END;
            CLRRECT( 1, 11, 38, 4)
          END;  (* ADVANCE *)
          
          
        BEGIN (* ENATTACK *)
          ADVANCE;
          FOR GROUPI := 1 TO 4 DO
            BEGIN
              IF BATTLERC[ GROUPI].A.ALIVECNT > 0 THEN
                FOR ENEMYX := 0 TO (BATTLERC[ GROUPI].A.ALIVECNT - 1) DO
                  WITH BATTLERC[ GROUPI] DO
                    BEGIN
                    IF (A.TEMP04[ ENEMYX].STATUS = OK) AND
                       (SURPRISE <> 1) THEN
                      BEGIN
                        A.TEMP04[ ENEMYX].AGILITY := (RANDOM MOD 8) + 2;
                        IF PARTYCNT = 1 THEN
                          CHARX := 0
                        ELSE
                          BEGIN
                            CHARX := PARTYCNT - 1;
                            WHILE BATTLERC[ 0].A.TEMP04[ CHARX].STATUS >=
                                    DEAD DO 
                              CHARX := CHARX - 1;
                            CHARX := RANDOM MOD (CHARX + 1)
                          END;
                        A.TEMP04[ ENEMYX].VICTIM := CHARX;
                        A.TEMP04[ ENEMYX].SPELLHSH := 0;
                        ATTCKTYP := 0;
                        IF CANATTCK THEN
                          BEGIN
                            ENEMYSPL;
                            IF ATTCKTYP = 0 THEN
                              BREATHES;
                            IF ATTCKTYP = 0 THEN
                              YELLHELP;
                            IF ATTCKTYP = 0 THEN
                              RUNENMY;
                            IF ATTCKTYP > 0 THEN
                              IF CHARACTR[ CHARX].WEPVSTY3[ 1][ 6] THEN
                                A.TEMP04[ ENEMYX].AGILITY := -1;
                            IF ATTCKTYP = 0 THEN
                              IF (ENEMYX <= 4 - GROUPI) OR
                                 ((60 - 10 * GROUPI) <= (RANDOM MOD 100)) THEN
                                BEGIN
                                  CHARX := CHARX MOD 3;
                                  IF CANATTCK THEN
                                    BEGIN
                                      ATTCKTYP := -1;
                                      A.TEMP04[ ENEMYX].VICTIM := CHARX
                                    END
                                  ELSE
                                    A.TEMP04[ ENEMYX].AGILITY := -1;
                                END
                          END;
                        A.TEMP04[ ENEMYX].SPELLHSH := ATTCKTYP
                      END
                    ELSE
                      A.TEMP04[ ENEMYX].AGILITY := -1
                END
            END
          END;  (* ENATTACK *)
        
        
    PROCEDURE HEAL;  (* P01061F *)
      
        VAR
             MVUPLIVE : INTEGER;
             T1       : INTEGER; (* MULTIPLE USES *)
             T2       : INTEGER; (* MULTIPLE USES *)
             
      
        PROCEDURE TRYHEAL( HEALCHAN: INTEGER);  (* P010620 *)
        
          BEGIN
            IF HEALCHAN > 50 THEN
              HEALCHAN := 50;
            IF (RANDOM MOD 100) <= HEALCHAN THEN
              BATTLERC[ T2].A.TEMP04[ T1].STATUS := OK
          END;
          
          
        PROCEDURE HEALENMY;  (* P010621 *)
        
          VAR
               ENEMYRC : TENEMY2;
        
          BEGIN
            FOR T2 := 1 TO 4 DO
              BEGIN
                IF BATTLERC[ T2].A.ALIVECNT > 0 THEN
                  BEGIN
                    T1 := 0;
                    MVUPLIVE := 0;
                    WHILE MVUPLIVE < BATTLERC[ T2].A.ALIVECNT DO
                      BEGIN
                        BATTLERC[ T2].A.TEMP04[ T1] :=
                          BATTLERC[ T2].A.TEMP04[ MVUPLIVE];
                        MVUPLIVE := MVUPLIVE + 1;
                        IF BATTLERC[ T2].A.TEMP04[ T1].STATUS < DEAD THEN
                          BEGIN
                            CASE BATTLERC[ T2].A.TEMP04[ T1].STATUS OF
                            
                              AFRAID:
                               TRYHEAL( 10 * BATTLERC[ T2].B.HPREC.LEVEL);
                               
                              ASLEEP:
                               TRYHEAL( 20 * BATTLERC[ T2].B.HPREC.LEVEL);
                               
                              PLYZE:
                               TRYHEAL(  7 * BATTLERC[ T2].B.HPREC.LEVEL);
                            END;
                            
                            BATTLERC[ T2].A.TEMP04[ T1].HPLEFT :=
                              BATTLERC[ T2].A.TEMP04[ T1].HPLEFT +
                              BATTLERC[ T2].B.HEALPTS;
                            T1 := T1 + 1
                          END
                      END;
                    BATTLERC[ T2].A.ALIVECNT := T1
                  END
              END;
              
            FOR T1 := 1 TO 3 DO
              BEGIN
                FOR T2 := T1 + 1 TO 4 DO
                  IF (BATTLERC[ T1].A.ALIVECNT = 0) AND
                     (BATTLERC[ T2].A.ALIVECNT > 0)    THEN
                    BEGIN
                      ENEMYRC := BATTLERC[ T1];
                      BATTLERC[ T1] := BATTLERC[ T2];
                      BATTLERC[ T2] := ENEMYRC
                    END
              END;
            
            T2 := 0;
            FOR T1 := 1 TO 4 DO
              IF BATTLERC[ T1].A.ALIVECNT > 0 THEN
                T2 := T1;
            DONEFIGH := (T2 = 0)
          END;  (* HEALENMY *)
          
          
        PROCEDURE HEALPRTY;  (* P010622 *)
        
          BEGIN
            T2 := 0;
            FOR T1 := 0 TO PARTYCNT - 1 DO
              BEGIN
                IF BATTLERC[ 0].A.TEMP04[ T1].STATUS < DEAD THEN
                  BEGIN
                    IF (RANDOM MOD 4) = 2 THEN
                      BATTLERC[ 0].A.TEMP04[ T1].HPLEFT :=
                        BATTLERC[ 0].A.TEMP04[ T1].HPLEFT +
                        CHARACTR[ T1].HEALPTS -
                        CHARACTR[ T1].LOSTXYL.POISNAMT[ 1];
                      
                    IF BATTLERC[ 0].A.TEMP04[ T1].HPLEFT > 
                      CHARACTR[ T1].HPMAX THEN
                       BATTLERC[ 0].A.TEMP04[ T1].HPLEFT :=
                         CHARACTR[ T1].HPMAX;
                         
                    IF BATTLERC[ 0].A.TEMP04[ T1].HPLEFT <= 0 THEN
                      BEGIN
                        BATTLERC[ 0].A.TEMP04[ T1].STATUS := DEAD;
                        BATTLERC[ 0].A.TEMP04[ T1].HPLEFT := 0;
                        MVCURSOR( 1, 12);
                        PRINTSTR( CHARACTR[ T1].NAME);
                        PRINTSTR( ' JUST DIED!');
                        PAUSE2;
                        CLRRECT( 1, 12, 38, 1);
                      END;
           
                    CASE BATTLERC[ 0].A.TEMP04[ T1].STATUS OF
                      ASLEEP:  TRYHEAL( 10 * CHARACTR[ T1].CHARLEV);
                      AFRAID:  TRYHEAL(  5 * CHARACTR[ T1].CHARLEV);
                    END;
                  END
                END;
                
              FOR T1 := 0 TO PARTYCNT - 1 DO
                BEGIN
                  CHARACTR[ T1].HPLEFT := BATTLERC[ 0].A.TEMP04[ T1].HPLEFT;
                  CHARACTR[ T1].STATUS := BATTLERC[ 0].A.TEMP04[ T1].STATUS
                END
          END;  (* HEALPRTY *)
          
          
        PROCEDURE HEALHEAR;  (* P010623 *)
        
        
          PROCEDURE DECINAUD( GROUPI:   INTEGER;  (* P01061B *)
                              ALIVECNT: INTEGER);
          
            VAR
                 X : INTEGER;
          
            BEGIN
              FOR X := 0 TO ALIVECNT - 1 DO
                IF BATTLERC[ GROUPI].A.TEMP04[ ALIVECNT].INAUDCNT > 0 THEN
                   BATTLERC[ GROUPI].A.TEMP04[ ALIVECNT].INAUDCNT :=
                   BATTLERC[ GROUPI].A.TEMP04[ ALIVECNT].INAUDCNT - 1
            END;  (* DECINAUD *)
            
            
          BEGIN (* HEALHEAR *)
            DECINAUD( 0, PARTYCNT);
            DECINAUD( 1, BATTLERC[ 1].A.ALIVECNT);
            DECINAUD( 2, BATTLERC[ 2].A.ALIVECNT);
            DECINAUD( 3, BATTLERC[ 3].A.ALIVECNT)
          END; (* HEALHEAR *)
          
          
        BEGIN (* HEAL *)
          HEALENMY;
          HEALPRTY;
          HEALHEAR
        END;
      
      
      PROCEDURE DSPENEMY;  (* P010625 *)
      
        VAR
             ENMYGROK : INTEGER;
             ENMYGRI  : INTEGER;
             ENMYIND  : INTEGER;
      
        BEGIN
          ENSTRENG := 0;
          FOR ENMYGRI := 1 TO 4 DO
            BEGIN
              CLRRECT( 13, ENMYGRI, 26, 1);
              IF BATTLERC[ ENMYGRI].A.ALIVECNT > 0 THEN
                BEGIN
                  ENMYGROK := 0;
                  FOR ENMYIND := 0 TO BATTLERC[ ENMYGRI].A.ALIVECNT - 1 DO
                    IF BATTLERC[ ENMYGRI].A.TEMP04[ ENMYIND].STATUS = OK THEN
                      ENMYGROK := ENMYGROK + 1;
                  ENSTRENG := ENSTRENG + ENMYGROK *
                                         (BATTLERC[ ENMYGRI].B.HPREC.LEVEL);
                  MVCURSOR( 13, ENMYGRI);
                  PRINTNUM( ENMYGRI, 1);
                  PRINTSTR( ') ');
                  PRINTNUM( BATTLERC[ ENMYGRI].A.ALIVECNT, 1);
                  PRINTSTR( ' ');
                  IF BATTLERC[ ENMYGRI].A.IDENTIFI THEN
                    IF BATTLERC[ ENMYGRI].A.ALIVECNT > 1 THEN
                      PRINTSTR( BATTLERC[ ENMYGRI].B.NAMES)
                    ELSE
                      PRINTSTR( BATTLERC[ ENMYGRI].B.NAME)
                  ELSE
                    IF BATTLERC[ ENMYGRI].A.ALIVECNT > 1 THEN
                      PRINTSTR( BATTLERC[ ENMYGRI].B.NAMEUNKS)
                    ELSE
                      PRINTSTR( BATTLERC[ ENMYGRI].B.NAMEUNK);
                  PRINTSTR( ' (');
                  PRINTNUM( ENMYGROK, 1);
                  PRINTCHR( ')')
                END
            END
        END;
        
        
      PROCEDURE DSPPARTY;  (* P010626 *)
      
        VAR
             UNUSEDXX : INTEGER;
             TEMPXYZ  : INTEGER;  (* MULTIPLE USES *)
             PARTYI   : INTEGER;
             STATUSOK : BOOLEAN;
      
      
        PROCEDURE PRSTATUS;  (* P010627 *)
        
          BEGIN
            STATUSOK :=  STATUSOK OR (CHARACTR[ PARTYI].STATUS < DEAD);
            IF CHARACTR[ PARTYI].STATUS = OK THEN
              IF CHARACTR[ PARTYI].LOSTXYL.POISNAMT[ 1] > 0 THEN
                PRINTSTR( 'POISON')
              ELSE
                PRINTNUM( CHARACTR[ PARTYI].HPMAX, 4)
            ELSE
              PRINTSTR( SCNTOC.STATUS[ CHARACTR[ PARTYI].STATUS])
          END; (* PRSTATUS *)
          
          
        PROCEDURE SWAP2CHR( X: INTEGER;  (* P010628 *)
                            Y: INTEGER);
        
          VAR
               TEMPCHAR : TCHAR;
               TEMPX    : BOOLEAN;
        
          BEGIN
            TEMPCHAR := CHARACTR[ X];
            CHARACTR[ X] := CHARACTR[ Y];
            CHARACTR[ Y] := TEMPCHAR;
            
            LLBASE04 := CHARDISK[ X];
            CHARDISK[ X] := CHARDISK[ Y];
            CHARDISK[ Y] := LLBASE04;
            
            TEMPX := DRAINED[ X];
            DRAINED[ X] := DRAINED[ Y];
            DRAINED[ Y] := TEMPX;
            
            BATTLERC[ 0].A.TEMP04[ 6] := BATTLERC[ 0].A.TEMP04[ X];
            BATTLERC[ 0].A.TEMP04[ X] := BATTLERC[ 0].A.TEMP04[ Y];
            BATTLERC[ 0].A.TEMP04[ Y] := BATTLERC[ 0].A.TEMP04[ 6]
          
          END; (* SWAP2CHR *)
        
        
        BEGIN (* DSPPARTY *)
          FOR PARTYI := 0 TO PARTYCNT - 2 DO
            FOR TEMPXYZ := PARTYI + 1 TO PARTYCNT - 1 DO
              IF PREBATOR[ PARTYI] = CHARDISK[ TEMPXYZ] THEN
                SWAP2CHR( PARTYI, TEMPXYZ);
          
          FOR PARTYI := 0 TO PARTYCNT - 2 DO
            FOR TEMPXYZ := PARTYI + 1 TO PARTYCNT - 1 DO
              IF CHARACTR[ PARTYI].STATUS > CHARACTR[ TEMPXYZ].STATUS THEN
                SWAP2CHR( PARTYI, TEMPXYZ);
                
          BASE12.MYSTRENG := 0;
          BATTLERC[ 0].A.ALIVECNT := 0;
          FOR PARTYI := 0 TO PARTYCNT - 1 DO
            BEGIN
              IF CHARACTR[ PARTYI].STATUS = OK THEN
                BASE12.MYSTRENG := BASE12.MYSTRENG +
                                    CHARACTR[ PARTYI].CHARLEV;
              IF CHARACTR[ PARTYI].STATUS < DEAD THEN
                BATTLERC[ 0].A.ALIVECNT := BATTLERC[ 0].A.ALIVECNT + 1
            END;
            
          CLRRECT( 1, 17, 38, 6);
          
          STATUSOK := FALSE;
          FOR PARTYI := 0 TO PARTYCNT - 1 DO
            BEGIN
              IF (RANDOM MOD 99) < (CHARACTR[ PARTYI].ATTRIB[ IQ] +
                                    CHARACTR[ PARTYI].ATTRIB[ PIETY] +
                                    CHARACTR[ PARTYI].CHARLEV)  THEN
                BATTLERC[ (RANDOM MOD 4) + 1].A.IDENTIFI := TRUE;
              MVCURSOR( 1, 17 + PARTYI);
              PRINTNUM( PARTYI + 1, 1);
              PRINTSTR( ' ');
              PRINTSTR( CHARACTR[ PARTYI].NAME);
              MVCURSOR( 19, 17 + PARTYI);
              PRINTSTR( COPY( SCNTOC.ALIGN[ CHARACTR[ PARTYI].ALIGN], 1, 1));
              PRINTCHR( '-');
              PRINTSTR( COPY( SCNTOC.CLASS[ CHARACTR[ PARTYI].CLASS], 1, 3));
              LLBASE04 := CHARACTR[ PARTYI].ARMORCL -
                        ACMOD2 -
                        BATTLERC[ 0].A.TEMP04[ PARTYI].ARMORCL;
              IF LLBASE04 >= 0 THEN
                PRINTNUM( LLBASE04, 3)
              ELSE
                IF LLBASE04 > - 10 THEN
                  BEGIN
                    PRINTSTR( ' -');
                    PRINTNUM( ABS( LLBASE04), 1)
                  END
                ELSE
                  PRINTSTR( ' LO');
              PRINTNUM( CHARACTR[ PARTYI].HPLEFT, 5);
              TEMPXYZ := CHARACTR[ PARTYI].HEALPTS -
                         CHARACTR[ PARTYI].LOSTXYL.POISNAMT[ 1];
              IF TEMPXYZ = 0 THEN
                PRINTCHR( ' ')
              ELSE IF TEMPXYZ < 0 THEN
                PRINTCHR( '-')
              ELSE
                PRINTCHR( '+');
              PRSTATUS;
            END;
          IF NOT STATUSOK THEN
            EXIT( COMBAT);
        END; (* DSPPARTY *)
        
        
      BEGIN (* CUTIL *)
        HEAL;
        DSPPARTY;
        DSPENEMY;
        IF DONEFIGH THEN
          EXIT( CUTIL);
        ENATTACK;
        CACTION;
        SURPRISE := 0
      END;  (* CUTIL *)
  
(* MELEE *)

SEGMENT PROCEDURE MELEE;  (* P010701 *)

  VAR
         VICTIM   : INTEGER;
         ATTACKTY : INTEGER;
         BATI     : INTEGER;
         BATG     : INTEGER;
         AGILELEV : INTEGER;
  
(* CASTASPE *)

    SEGMENT PROCEDURE CASTASPE;  (* P010801 *)
    
      TYPE
           THITHEAL = RECORD
               HITS     : INTEGER;
               HITRANGE : INTEGER;
               HITMIN   : INTEGER;
             END;
                    
      VAR
           SPELL    : INTEGER;
           CASTI    : INTEGER;
           CASTGR   : INTEGER;
           
           
      PROCEDURE DSPNAMES( GROUPI:  INTEGER;  (* P010802 *)
                          MYCHARI: INTEGER);
      
        BEGIN
          IF GROUPI = 0 THEN
            PRINTSTR( CHARACTR[ MYCHARI].NAME)
          ELSE
            IF BATTLERC[ GROUPI].A.IDENTIFI THEN
              PRINTSTR( BATTLERC[ GROUPI].B.NAME)
            ELSE
              PRINTSTR( BATTLERC[ GROUPI].B.NAMEUNK);
          PRINTSTR( ' ');
        END;
        
        
      PROCEDURE UNAFFECT( GROUPI: INTEGER;
                          CHARX:  INTEGER;
                          DAMPTS: INTEGER);  (* P010803 *)
      
        BEGIN
          CLRRECT( 1, 12, 38, 3);
          IF BATTLERC[ GROUPI].A.TEMP04[ CHARX].STATUS >= DEAD THEN
            EXIT( UNAFFECT);
          MVCURSOR( 1, 12);
          DSPNAMES( GROUPI, CHARX);
          IF GROUPI <> 0 THEN
            BEGIN
              IF BATTLERC[ GROUPI].B.UNAFFCT > (RANDOM MOD 100) THEN
                 DAMPTS := 0;
            END;
          IF DAMPTS = 0 THEN
            PRINTSTR( 'IS UNAFFECTED!')
          ELSE
            BEGIN
              PRINTSTR( 'TAKES ');
              PRINTNUM( DAMPTS, 4);
              PRINTSTR( ' DAMAGE');
              WITH BATTLERC[ GROUPI].A.TEMP04[ CHARX] DO
                BEGIN
                  HPLEFT := HPLEFT - DAMPTS;
                  IF HPLEFT <= 0 THEN
                    BEGIN
                      HPLEFT := 0;
                      STATUS := DEAD;
                      MVCURSOR( 1, 14);
                      DSPNAMES( GROUPI, CHARX);
                      PRINTSTR( 'DIES!')
                    END
                END
            END;
          PAUSE1
        END;
        
        
      PROCEDURE ISISNOT( GROUPI:    INTEGER;  (* P010804 *)
                         CHARI:     INTEGER;
                         ISNOTCHN:  INTEGER;
                         SDAMTYPE:  STRING;
                         DAMTYPE:   INTEGER);
      
        BEGIN
          MVCURSOR( 1, 13);
          DSPNAMES( GROUPI, CHARI);
          
          IF (RANDOM MOD 100) < ISNOTCHN THEN
            PRINTSTR( 'IS NOT ')
          ELSE
            BEGIN
              PRINTSTR( 'IS ');
              CASE DAMTYPE OF
              
                0, 3:  BATTLERC[ GROUPI].A.TEMP04[ CHARI].STATUS := ASLEEP;
                
                   1:  BATTLERC[ GROUPI].A.TEMP04[ CHARI].INAUDCNT :=
                         (RANDOM MOD 4) + 2;
                         
                   2:  BEGIN
                         BATTLERC[ GROUPI].A.TEMP04[ CHARI].STATUS := DEAD;
                         BATTLERC[ GROUPI].A.TEMP04[ CHARI].HPLEFT := 0
                       END
              END
            END;
          PRINTSTR( SDAMTYPE);
          PAUSE1;
          CLRRECT( 1, 13, 38, 1)
        END;
        
        
      FUNCTION CALCPTS( HITHEAL: THITHEAL) : INTEGER;  (* P010805 *)
      
        VAR
             POINTS : INTEGER;
             
        BEGIN
          POINTS := 0;
          WHILE HITHEAL.HITS > 0 DO
            BEGIN
              POINTS := POINTS + (RANDOM MOD HITHEAL.HITRANGE) + 1;
              HITHEAL.HITS := HITHEAL.HITS - 1
            END;
          CALCPTS := POINTS + HITHEAL.HITMIN
        END;
        
        
      PROCEDURE MODAC( GROUPI: INTEGER;  (* P010806 *)
                       ACMOD:  INTEGER;
                       CHARF:  INTEGER;
                       CHARL:  INTEGER);
                         
        VAR
             X : INTEGER;
      
        BEGIN
          FOR X := CHARF TO CHARL DO
            BATTLERC[ GROUPI].A.TEMP04[ X].ARMORCL :=
              BATTLERC[ GROUPI].A.TEMP04[ X].ARMORCL + ACMOD;
        END;
        
        
      PROCEDURE DOHEAL( GROUPI:   INTEGER;   (* P010807 *)
                        CHARI:    INTEGER;
                        HITCNT:   INTEGER;
                        HITRANGE: INTEGER);
      
        VAR
             HITHEAL : THITHEAL;
             POINTS  : INTEGER;
      
        BEGIN
          HITHEAL.HITS     := HITCNT;
          HITHEAL.HITRANGE := HITRANGE;
          HITHEAL.HITMIN   := 0;
          POINTS := CALCPTS( HITHEAL);
          BATTLERC[ GROUPI].A.TEMP04[ CHARI].HPLEFT :=
            BATTLERC[ GROUPI].A.TEMP04[ CHARI].HPLEFT + POINTS;
          IF CHARACTR[ CHARI].HPMAX < 
               BATTLERC[ GROUPI].A.TEMP04[ CHARI].HPLEFT THEN
            BATTLERC[ GROUPI].A.TEMP04[ CHARI].HPLEFT :=
              CHARACTR[ CHARI].HPMAX;
          DSPNAMES( GROUPI, CHARI);
          IF CHARACTR[ CHARI].HPMAX =
               BATTLERC[ GROUPI].A.TEMP04[ CHARI].HPLEFT THEN
            PRINTSTR( 'IS FULLY HEALED')
          ELSE
            PRINTSTR( 'IS PARTIALLY HEALED')
        END;
        
        
      PROCEDURE DOHITS( GROUPI:   INTEGER;  (* P010808 *)
                        CHARI:    INTEGER;
                        HITCNT:   INTEGER;
                        HITRANGE: INTEGER);
      
        VAR
            HITHEAL : THITHEAL;
            POINTS  : INTEGER;
      
        BEGIN
          HITHEAL.HITS     := HITCNT;
          HITHEAL.HITRANGE := HITRANGE;
          HITHEAL.HITMIN   := 0;
          POINTS := CALCPTS( HITHEAL);
          IF GROUPI > 0 THEN
            IF BATTLERC[ GROUPI].B.UNAFFCT > 0 THEN
              IF (RANDOM MOD 100) < BATTLERC[ GROUPI].B.UNAFFCT THEN
                POINTS := 0;
          UNAFFECT( GROUPI, CHARI, POINTS)
        END;
        
        
      PROCEDURE DOHOLD;  (* P010809 *)
      
        VAR
            CHARX : INTEGER;
            
        BEGIN
          FOR CHARX := 0 TO BATTLERC[ CASTGR].A.ALIVECNT - 1 DO
            IF BATTLERC[ CASTGR].A.TEMP04[ CHARX].STATUS <= ASLEEP THEN
              IF CASTGR = 0 THEN
                ISISNOT( CASTGR,
                         CHARX,
                         50 + 10 * CHARACTR[ CHARX].CHARLEV,
                         'HELD',
                         0)
              ELSE
                ISISNOT( CASTGR,
                         CHARX,
                         50 + 10 * BATTLERC[ CASTGR].B.HPREC.LEVEL,
                         'HELD',
                         0)
                 
        END;
        
        
      PROCEDURE DOSILENC;  (* P01080A *)
      
        VAR
             CHARX : INTEGER;
      
        BEGIN
          FOR CHARX := 0 TO BATTLERC[ CASTGR].A.ALIVECNT - 1 DO
            IF CASTGR = 0 THEN
              ISISNOT( CASTGR,
                       CHARX,
                        100 - 5 * CHARACTR[ CHARX].LUCKSKIL[ 4],
                       'SILENCED',
                       1)
            ELSE
              ISISNOT( CASTGR,
                       CHARX,
                       10 * BATTLERC[ CASTGR].B.HPREC.LEVEL, 
                       'SILENCED',
                       1)
        END;
        
        
      PROCEDURE DODISRUP;  (* P01080B *)
      
        BEGIN
          MVCURSOR( 1, 13);
          PRINTSTR( 'SPELL DISRUPTED')
        END;
        
        
      PROCEDURE DOSLAIN( GROUPI: INTEGER;  (* P01080C *)
                         CHARI:  INTEGER);
      
        VAR
             CHNOTSLN : INTEGER;
      
        BEGIN
          IF GROUPI = 0 THEN
            CHNOTSLN := CHARACTR[ CHARI].CHARLEV
          ELSE
            CHNOTSLN := BATTLERC[ GROUPI].B.HPREC.LEVEL;
          ISISNOT( GROUPI, CHARI, 10 * CHNOTSLN, 'SLAIN', 2)
        END;
        
        
      PROCEDURE DOSLEPT;  (* P01080D *)
      
        VAR
             CHARX : INTEGER;
      
        BEGIN
          FOR CHARX := 0 TO BATTLERC[ CASTGR].A.ALIVECNT - 1 DO
            IF BATTLERC[ CASTGR].A.TEMP04[ CHARX].STATUS < ASLEEP THEN
              IF CASTGR > 0 THEN
                BEGIN
                IF BATTLERC[ CASTGR].B.SPPC[ 4] THEN
                  ISISNOT( CASTGR,
                           CHARX,
                           20 * BATTLERC[ CASTGR].B.HPREC.LEVEL,
                           'SLEPT',
                           3)
                END
              ELSE
                ISISNOT( CASTGR,
                         CHARX,
                         20 * CHARACTR[ CHARX].CHARLEV,
                         'SLEPT',
                         3)
        END;
        
        
      PROCEDURE HAMMAHAM( MAHAMFLG: INTEGER);  (* P01080E *)
      
        VAR
             TEMP2    : INTEGER;  (* MULTIPLE USES *)
             TEMP1    : INTEGER;  (* MULTIPLE USES *)
      
      
        PROCEDURE HAMCURE;  (* P01080F *)
        
          VAR
               HITHEAL : THITHEAL;
        
          BEGIN
            PRINTSTR( 'DIALKO''S PARTY 3 TIMES');
            HITHEAL.HITS := 9;
            HITHEAL.HITRANGE := 8;
            HITHEAL.HITMIN := 0;
            FOR TEMP1 := 0 TO PARTYCNT - 1 DO
              IF BATTLERC[ 0].A.TEMP04[ TEMP1].STATUS < DEAD THEN
                BEGIN
                  WITH  BATTLERC[ 0].A.TEMP04[ TEMP1] DO
                    BEGIN
                      STATUS := OK;
                      INAUDCNT := 0;
                      HPLEFT := HPLEFT + CALCPTS( HITHEAL);
                      IF HPLEFT > CHARACTR[ TEMP1].HPMAX THEN
                        HPLEFT := CHARACTR[ TEMP1].HPMAX;
                    END
                END
          END;
          
          
        PROCEDURE HAMSILEN;  (* P010810 *)
        
          BEGIN
            PRINTSTR( 'SILENCES MONSTERS!');
            FOR TEMP1 := 1 TO 3 DO
              FOR TEMP2 := 0 TO BATTLERC[ TEMP1].A.ALIVECNT - 1 DO
                BATTLERC[ TEMP1].A.TEMP04[ TEMP2].INAUDCNT :=
                  5 + (RANDOM MOD 5)
          END;
          
          
        PROCEDURE HAMMAGIC;  (* P010811 *)
        
          BEGIN
            PRINTSTR( 'ZAPS MONSTER MAGIC RESISTANCE!');
            FOR TEMP1 := 1 TO 3 DO
              BEGIN
                BATTLERC[ TEMP1].B.UNAFFCT := 0
              END
          END;
          
          
        PROCEDURE HAMTELEP;  (* P010812 *)    (* NAME IS FROM MESSAGE *)
        
          BEGIN
            PRINTSTR( 'DESTROYS MONSTERS!');
            FOR TEMP1 := 1 TO 4 DO
              BEGIN
                FOR TEMP2 := 0 TO BATTLERC[ TEMP1].A.ALIVECNT - 1 DO
                  BEGIN
                    BATTLERC[ TEMP1].A.TEMP04[ TEMP2].STATUS := DEAD;
                    BATTLERC[ TEMP1].A.TEMP04[ TEMP2].HPLEFT := 0
                  END;
                BATTLERC[ TEMP1].A.ALIVECNT := 0
              END
          END;
          
          
        PROCEDURE HAMHEAL;  (* P010813 *)
        
          BEGIN
            PRINTSTR( 'HEALS PARTY!');
            FOR TEMP1 := 0 TO PARTYCNT - 1 DO
              IF BATTLERC[ 0].A.TEMP04[ TEMP1].STATUS < DEAD THEN
                BEGIN
                  WITH BATTLERC[ 0].A.TEMP04[ TEMP1] DO
                    BEGIN
                      STATUS := OK;
                      INAUDCNT := 0;
                      HPLEFT := CHARACTR[ TEMP1].HPMAX
                    END;
                END
          END;
          
          
        PROCEDURE HAMPROT; (* P010814 *)
        
          BEGIN
            PRINTSTR( 'SHIELDS PARTY');
            FOR TEMP1 := 0 TO PARTYCNT - 1 DO
              IF CHARACTR[ TEMP1].ARMORCL > -10 THEN
                CHARACTR[ TEMP1].ARMORCL := -10
          END;
          
          
        PROCEDURE HAMALIVE;  (* P010815 *)
        
          BEGIN
            PRINTSTR( 'RESSURECTS AND ');
            FOR TEMP1 := 0 TO PARTYCNT - 1 DO
              IF BATTLERC[ 0].A.TEMP04[ TEMP1].STATUS <> LOST THEN
                BATTLERC[ 0].A.TEMP04[ TEMP1].STATUS := OK;
            HAMHEAL
          END;
      
      
        PROCEDURE HAMMANGL;  (* P010816 *)
        
          VAR
               SPELLI : INTEGER;
              
          BEGIN (* HAMMANGL *)
            MVCURSOR( 1, 14);
            PRINTSTR( 'BUT HIS SPELL BOOKS ARE MANGLED!');
            FOR SPELLI := 1 TO 50 DO
              BEGIN
                IF (RANDOM MOD 100) > 50 THEN
                  CHARACTR[ TEMP1].SPELLSKN[ SPELLI] := FALSE
              END
          END; (* HAMMANGL *)
      
      
        BEGIN  (* HAMMAHAM *)
          IF MAHAMFLG = 7 THEN
            PRINTSTR( 'MA');
          PRINTSTR( 'HAMAN IS INTONED AND...');
          PAUSE2;
          MVCURSOR( 1, 13);
          IF CHARACTR[ BATI].CHARLEV < 13 THEN
            BEGIN
              PRINTSTR( 'FAILS!');
              EXIT( HAMMAHAM)
            END;
          CHARACTR[ BATI].CHARLEV := CHARACTR[ BATI].CHARLEV - 1;
          DRAINED[ BATI] := TRUE;
          
          CASE RANDOM MOD 3 * MAHAMFLG OF     (* MAHAMFLG IS 6 OR 7 *)
             0,  1,  2,  3,  4,  5:  HAMCURE;   (*     1? 2? 3? 4? 5? *)
                 7,  8,  9, 10, 11:  HAMSILEN;  (*     8? 9? 10? 11?  *)
                    12, 13, 22, 23:  HAMMAGIC;  (*    13?, 22?, 23?   *)
                        14, 20, 21:  HAMTELEP;  (*    14?, 20?        *)
                         6, 15, 19:  HAMHEAL;   (*    15?, 19?        *)
                                17:  HAMPROT;   (*    17?      DEAD CODE    *)
                            16, 18:  HAMALIVE;  (*    16?, 18? DEAD CODE    *)
                            
          (* MAYBE THEY WANTED "RANDOM MOD (3 * MAHAMFLG)",
             AND MAHAMFLG = 6 OR 8 DEPENDING ON SPELL *)
                            
                            
          END;
          IF (RANDOM MOD CHARACTR[ BATI].CHARLEV) = 5 THEN
            HAMMANGL
        END;   (* HAMMAHAM *)
        
        
      PROCEDURE HITGROUP( GROUPI:  INTEGER;  (* P010817 *)
                          HITSX:   INTEGER;
                          HITSR:   INTEGER;
                          TEMP99I: INTEGER);
      
        VAR
             CHARI : INTEGER;
      
        BEGIN
          IF BATTLERC[ GROUPI].A.ALIVECNT > 0 THEN
            FOR CHARI := 0 TO BATTLERC[ GROUPI].A.ALIVECNT - 1 DO
              BEGIN
                IF GROUPI = 0 THEN
                  BATTLERC[ 0].B.WEPVSTY3 := CHARACTR[ CHARI].WEPVSTY3[ 1];
                IF BATTLERC[ GROUPI].B.WEPVSTY3[ TEMP99I] THEN
                  DOHITS( GROUPI, CHARI, HITSX DIV 2 + 1, HITSR)
                ELSE
                  DOHITS( GROUPI, CHARI, HITSX, HITSR)
              END
        END;
        
        
      PROCEDURE SLOKTOFE;  (* P010818 *)
      
        VAR
             POSSX :  INTEGER;
             TEMPXX : INTEGER; (* MULTIPLE USES *)
      
        BEGIN
          IF (RANDOM MOD 100) >  2 * CHARACTR[ BATI].CHARLEV THEN
            BEGIN
              MVCURSOR( 1, 13);
              PRINTSTR( 'LOKTOFEIT FAILS!');
              EXIT( SLOKTOFE)
            END;
          FOR TEMPXX := 0 TO PARTYCNT - 1 DO
            BEGIN
              FOR POSSX := 1 TO CHARACTR[ TEMPXX].POSS.POSSCNT DO
                WITH CHARACTR[ TEMPXX].POSS.POSSESS[ POSSX] DO
                  BEGIN
                    EQINDEX := 0;
                    IDENTIF := FALSE;
                    CURSED  := FALSE;
                    EQUIPED := FALSE
                  END;
              CHARACTR[ TEMPXX].POSS.POSSCNT := 0;
              CHARACTR[ TEMPXX].GOLD.HIGH := 0;
              CHARACTR[ TEMPXX].GOLD.MID  := 0
            END;
          XGOTO := XCHK4WIN;
          WRITE( CHR( 12));
          TEXTMODE;
          EXIT( COMBAT)(* EXITCOMB *)
        END;
        
        
      PROCEDURE SMAKANIT;  (* P010819 *)
        
        VAR
             ENEMYX  : INTEGER;
             GROUPI  : INTEGER;
             
          
        BEGIN (* SMAKANIT *)
          FOR GROUPI := 1 TO 4 DO
            BEGIN
              IF BATTLERC[ GROUPI].A.ALIVECNT > 0 THEN
                BEGIN
                  MVCURSOR( 1, 13);
                  IF BATTLERC[ GROUPI].A.IDENTIFI THEN
                    PRINTSTR( BATTLERC[ GROUPI].B.NAMES)
                  ELSE
                    PRINTSTR(BATTLERC[ GROUPI].B.NAMEUNKS);
                              
                  IF BATTLERC[ GROUPI].B.CLASS = 10 THEN
                    PRINTSTR( ' ARE UNAFFECTED!')
                  ELSE
                    IF BATTLERC[ GROUPI].B.HPREC.LEVEL > 7 THEN
                      PRINTSTR( ' SURVIVE!')
                    ELSE
                      BEGIN
                        PRINTSTR( ' PERISH!');
                        FOR ENEMYX := 0 TO BATTLERC[ GROUPI].A.ALIVECNT DO
                          BEGIN
                            WITH BATTLERC[ GROUPI].A.TEMP04[ ENEMYX] DO
                              BEGIN
                                HPLEFT := 0;
                                STATUS := DEAD
                              END
                          END
                      END;
                  PAUSE1;
                  CLRRECT( 1, 13, 38, 1)
                END
            END
        END;  (* SMAKANIT *)
        
        
      PROCEDURE SMALOR;  (* P01081A *)
      
        VAR
             UNUSEDXX : INTEGER;
             UNUSEDYY : INTEGER;
             
        BEGIN
          MAZEX := RANDOM MOD 20;
          MAZEY := RANDOM MOD 20;
          WHILE (RANDOM MOD 100) < 30 DO
            MAZELEV := MAZELEV - 1;
          WHILE (RANDOM MOD 100) < 10 DO
            MAZELEV := MAZELEV - 1;
          IF MAZELEV < SCNTOC.RECPERDK[ ZMAZE] THEN
            MAZELEV := SCNTOC.RECPERDK[ ZMAZE];
          CLRRECT( 13, 1, 26, 4);
          IF MAZELEV = 0 THEN
            BEGIN
              XGOTO := XCHK4WIN;
              WRITE( CHR(12));
              TEXTMODE
            END
          ELSE
            XGOTO := XNEWMAZE;
          EXIT( COMBAT)
        END;
        
        
      PROCEDURE DOPRIEST;  (* P01081B *)
      
        VAR
             GROUPI : INTEGER;
      
        BEGIN
          IF SPELL = KALKI THEN
            MODAC( 0, 1, 0, PARTYCNT - 1);
          IF SPELL = DIOS THEN
            DOHEAL( 0, CASTGR, 1, 8);
          IF SPELL = BADIOS THEN
            DOHITS( CASTGR, CASTI, 1, 8);
          IF SPELL = MILWA THEN
            LIGHT := LIGHT + 15 + (RANDOM MOD 15);
          IF SPELL = PORFIC THEN
            MODAC( 0, 4, BATI, BATI);
          IF SPELL = MATU THEN
            MODAC( 0, 2, 0, PARTYCNT - 1);
          IF SPELL = MANIFO THEN
            DOHOLD;
          IF SPELL = MONTINO THEN
            DOSILENC;
          IF SPELL = LOMILWA THEN
            LIGHT := 32000;
          IF SPELL = DIALKO THEN
            BEGIN
              DSPNAMES( 0, CASTGR);
              IF (BATTLERC[ 0].A.TEMP04[ CASTGR].STATUS = PLYZE) OR
                 (BATTLERC[ 0].A.TEMP04[ CASTGR].STATUS = ASLEEP) THEN
                BEGIN
                  BATTLERC[ 0].A.TEMP04[ CASTGR].STATUS := OK;
                  PRINTSTR( 'IS CURED!')
                END
              ELSE
                PRINTSTR( 'IS NOT HELPED!');
            END;
          IF SPELL = LATUMAPI THEN
            BEGIN
              FOR GROUPI := 1 TO 4 DO
                BATTLERC[ LLBASE04].A.IDENTIFI := TRUE;  (* BUG? WITH BASE04*)
            END;
          IF SPELL = BAMATU THEN
            MODAC( 0, 4, 0, PARTYCNT - 1);
          IF SPELL = DIAL THEN
            DOHEAL( 0, CASTGR, 2, 8);
          IF SPELL = BADIAL THEN
            DOHITS( CASTGR, CASTI, 2, 8);
          IF SPELL = LATUMOFI THEN
            BEGIN
              DSPNAMES( 0, CASTGR);
              PRINTSTR( 'IS UNPOISONED!');
              CHARACTR[ CASTGR].LOSTXYL.POISNAMT[ 1] := 0
            END;
          IF SPELL = MAPORFIC THEN
            ACMOD2 := 2;
          IF SPELL = DIALMA THEN
            DOHEAL( 0, CASTGR, 3, 8);
          IF SPELL = BADIALMA THEN
            DOHITS( CASTGR, CASTI, 3, 8);
          IF SPELL = LITOKAN THEN
            HITGROUP( CASTGR, 3, 8, 1);
          IF SPELL = KANDI THEN
            DODISRUP;
          IF SPELL = DI THEN
            DODISRUP;
          IF SPELL = BADI THEN
            DOSLAIN( CASTGR, CASTI);
          IF SPELL = LORTO THEN
            HITGROUP( CASTGR, 6, 6, 0);
          IF SPELL = MADI THEN
            BEGIN
              BATTLERC[ 0].A.TEMP04[ CASTGR].HPLEFT :=
                CHARACTR[ CASTGR].HPMAX;
              IF BATTLERC[ 0].A.TEMP04[ CASTGR].STATUS < DEAD THEN
                BATTLERC[ 0].A.TEMP04[ CASTGR].STATUS := OK;
              CHARACTR[ CASTGR].LOSTXYL.POISNAMT[ 1] := 0;
              DOHEAL( 0, CASTGR, 1, 1)
            END;
          IF SPELL = MABADI THEN
            BEGIN
              CLRRECT( 1, 12, 38, 3);
              MVCURSOR( 1, 12);
              DSPNAMES( CASTGR, CASTI);
              PRINTSTR( ' IS HIT BY MABADI!');
               BATTLERC[ CASTGR].A.TEMP04[ CASTI].HPLEFT := 
                 1 + (RANDOM MOD 8);
            END;
          IF SPELL = LOKTOFEI THEN
            SLOKTOFE;
          IF SPELL = MALIKTO THEN
            FOR GROUPI := 1 TO 4 DO
              HITGROUP( GROUPI, 12, 6, 0);
          IF SPELL = KADORTO THEN
            DODISRUP
        END;
        
        
      PROCEDURE DOMAGE;  (* P01081C *)
      
        VAR
             GROUPI : INTEGER;  (* MULTIPLE USES *)
      
        BEGIN
          IF SPELL = HALITO THEN
            DOHITS( CASTGR, CASTI, 1, 8);
          IF SPELL = MOGREF THEN
            MODAC( 0, 2, BATI, BATI);
          IF SPELL = KATINO THEN
            DOSLEPT;
          IF SPELL = DILTO THEN
            MODAC( CASTGR, -2, 0, BATTLERC[ CASTGR].A.ALIVECNT - 1);
          IF SPELL = SOPIC THEN
            MODAC( 0, 4, BATI, BATI);
          IF SPELL = MAHALITO THEN
            HITGROUP( CASTGR, 4, 6, 1);
          IF SPELL = MOLITO THEN
            HITGROUP( CASTGR, 3, 6, 0);
          IF SPELL = MORLIS THEN
            MODAC( CASTGR, -3, 0, BATTLERC[ CASTGR].A.ALIVECNT - 1);
          IF SPELL = DALTO THEN
            HITGROUP( CASTGR, 6, 6, 2);
          IF SPELL = LAHALITO THEN
            HITGROUP( CASTGR, 6, 6, 1);
          IF SPELL = MAMORLIS THEN
            FOR GROUPI := 1 TO 4 DO
              MODAC( GROUPI, -3, 1, BATTLERC[ GROUPI].A.ALIVECNT);
          IF SPELL = MAKANITO THEN
            SMAKANIT;
          IF SPELL = MADALTO THEN
            HITGROUP( CASTGR, 8, 8, 2);
          IF SPELL = LAKANITO THEN
            FOR GROUPI := 0 TO BATTLERC[ CASTGR].A.ALIVECNT - 1 DO
              IF BATTLERC[ CASTGR].A.TEMP04[ GROUPI].STATUS < DEAD THEN
                ISISNOT( CASTGR, GROUPI, 6 * BATTLERC[ CASTGR].B.HPREC.LEVEL,
                         'SMOTHERED', 2);
          IF SPELL = ZILWAN THEN
            IF BATTLERC[ CASTGR].B.CLASS = 10 THEN
              DOHITS( CASTGR, CASTI, 10, 200);
          IF SPELL = MASOPIC THEN
            MODAC( 0, 4, 0, PARTYCNT - 1);
          IF SPELL = HAMAN THEN
            HAMMAHAM( 6);
          IF SPELL = MALOR THEN
            SMALOR;
          IF SPELL = MAHAMAN THEN
            HAMMAHAM( 7);
          IF SPELL = TILTOWAIT THEN
            IF BATG = 0 THEN
              FOR GROUPI := 1 TO 4 DO
                HITGROUP( GROUPI, 10, 15, 0)
            ELSE
              HITGROUP( 0, 10, 15, 0)
        END;
        
        
      PROCEDURE EXITCAST( EXITSTR: STRING);  (* P01081D *)
      
        BEGIN
          MVCURSOR( 1, 12);
          PRINTSTR( EXITSTR);
          EXIT( CASTASPE)
        END;
        
        
      BEGIN  (* CASTASPE P010801 *)
        DSPNAMES( BATG, BATI);
        PRINTSTR( 'CASTS A SPELL');
        IF BATTLERC[ BATG].A.TEMP04[ BATI].INAUDCNT > 0 THEN
          EXITCAST( 'WHICH FAILS TO BECOME AUDIBLE!');
        IF FIZZLES > 0 THEN
          EXITCAST( 'WHICH FIZZLES OUT');
        IF BATG = 0 THEN
          BEGIN
            CASTGR := BATTLERC[ 0].A.TEMP04[ BATI].VICTIM;
            IF (CASTGR > 0) AND (CASTGR < 5) THEN
              IF BATTLERC[ CASTGR].A.ALIVECNT > 0 THEN
                CASTI := BATI MOD BATTLERC[ CASTGR].A.ALIVECNT;
            SPELL := BATTLERC[ 0].A.TEMP04[ BATI].SPELLHSH;
          END
        ELSE
          BEGIN
            CASTGR := 0;
            CASTI  := BATTLERC[ BATG].A.TEMP04[ BATI].VICTIM;
            SPELL  := BATTLERC[ BATG].A.TEMP04[ BATI].SPELLHSH
          END;
        MVCURSOR( 1, 12);
        DOMAGE;
        DOPRIEST
      END;   (* CASTASPE P010801 *)
    
SEGMENT PROCEDURE SWINGASW;  (* P010901 *)
    
    
    PROCEDURE ARMATTK;  (* P010902 *)
      
        BEGIN
          CASE (RANDOM MOD 5) OF
            0:  PRINTSTR( 'SWINGS');
            1:  PRINTSTR( 'THRUSTS');
            2:  PRINTSTR( 'STABS');
            3:  PRINTSTR( 'SLASHES');
            4:  PRINTSTR( 'CHOPS')
          END
        END;
      
      
    PROCEDURE PRNAME( GROUPI: INTEGER;  (* P010903 *)
                      CHARX:  INTEGER);
                     
      BEGIN
        IF GROUPI = 0 THEN
          PRINTSTR(  CHARACTR[ CHARX].NAME)
        ELSE IF BATTLERC[ GROUPI].A.IDENTIFI THEN
          PRINTSTR(  BATTLERC[ GROUPI].B.NAME)
        ELSE
          PRINTSTR( BATTLERC[ GROUPI].B.NAMEUNK);
        PRINTSTR( ' ')
      END;
        

      PROCEDURE UNAFFECT( GROUPI: INTEGER;
                          CHARI:  INTEGER;
                          HITDAM: INTEGER);  (* P010904 *)
      
        (* COMBINATION OF UNAFFECT AND BREATHDM IN LOL *)
      
        BEGIN
          CLRRECT( 1, 12, 38, 3);
          IF BATTLERC[ GROUPI].A.TEMP04[ CHARI].STATUS >= DEAD THEN
            EXIT( UNAFFECT);
          MVCURSOR( 1, 12);
          PRNAME( GROUPI, CHARI);
          IF GROUPI <> 0 THEN
            BEGIN
              IF BATTLERC[ GROUPI].B.UNAFFCT > (RANDOM MOD 100) THEN
                 HITDAM := 0;
            END;
          IF HITDAM = 0 THEN
            PRINTSTR( 'IS UNAFFECTED!')
          ELSE
            BEGIN
              PRINTSTR( 'TAKES ');
              PRINTNUM( HITDAM, 4);
              PRINTSTR( ' DAMAGE');
              WITH BATTLERC[ GROUPI].A.TEMP04[ CHARI] DO
                BEGIN
                  HPLEFT := HPLEFT - HITDAM;
                  IF HPLEFT <= 0 THEN
                    BEGIN
                      HPLEFT := 0;
                      STATUS := DEAD;
                      MVCURSOR( 1, 14);
                      PRNAME( GROUPI, CHARI);
                      PRINTSTR( 'IS SLAIN!');
                    END
                END
            END;
          PAUSE1
        END;
        
        
      FUNCTION CALCHP( AHPREC: THPREC) : INTEGER;  (* P010905 *)
                           
        VAR
             HITPTS : INTEGER;
             
        BEGIN
          HITPTS := 0;
          WHILE AHPREC.LEVEL > 0 DO
            BEGIN
              HITPTS := HITPTS + (RANDOM MOD AHPREC.HPFAC) + 1;
              AHPREC.LEVEL := AHPREC.LEVEL - 1
            END;
          CALCHP := HITPTS + AHPREC.HPMINAD
        END;
        
        
      PROCEDURE DOBREATH;  (* P010906 *)
      
        VAR
             UNUSED : INTEGER;
             HITDAM : INTEGER;
             CHARX  : INTEGER;
      
        BEGIN
          PRINTSTR(  'BREATHES!');
          FOR CHARX := 0 TO PARTYCNT - 1 DO
            BEGIN
              IF BATTLERC[ 0].A.TEMP04[ CHARX].STATUS < DEAD THEN
                BEGIN
                  CLRRECT( 1, 12, 38, 3);
                  MVCURSOR( 1, 12);
                  HITDAM := BATTLERC[ BATG].A.TEMP04[ BATI].HPLEFT DIV 2;
                  IF (RANDOM MOD 20) >= CHARACTR[ CHARX].LUCKSKIL[ 3] THEN
                    HITDAM := (HITDAM + 1) DIV 2;
                  IF CHARACTR[ CHARX].WEPVSTY3[ 1][ BATTLERC[ BATG].B.BREATHE] 
                      THEN
                    HITDAM := (HITDAM + 1) DIV 2;
                  UNAFFECT( 0, CHARX, HITDAM)
                END
            END
        END;
    
        
      
      PROCEDURE DOFIGHT;  (* P010907 *)
      
        PROCEDURE DAM2ME;  (* P010908 *)
        
          VAR
               HPCALCPC : INTEGER;
               RECSI    : INTEGER;
               MYVICTIM : INTEGER;
               HPDAMAGE : INTEGER;
               HITSCNT  : INTEGER;
        
        
          PROCEDURE CASEDAMG;  (* P010909 *)
          
            PROCEDURE DRAINLEV;  (* P01090A *)
            
              BEGIN 
                IF CHARACTR[ MYVICTIM].WEPVSTY3[ 1][ 4] THEN
                  EXIT( DRAINLEV);
                CHARACTR[ MYVICTIM].CHARLEV := CHARACTR[ MYVICTIM].CHARLEV -
                  BATTLERC[ BATG].B.DRAINAMT;
                MVCURSOR( 1, 14);
                CLRRECT( 1, 14, 38, 1);
                PRINTNUM( BATTLERC[ BATG].B.DRAINAMT, 2);
                IF BATTLERC[ BATG].B.DRAINAMT = 1 THEN
                  PRINTSTR( ' LEVEL')
                ELSE
                  PRINTSTR( ' LEVELS');
                PRINTSTR( ' ARE DRAINED!');
                IF CHARACTR[ MYVICTIM].CHARLEV < 1 THEN
                  BEGIN
                    CHARACTR[ MYVICTIM].CHARLEV := 0;
                    BATTLERC[ 0].A.TEMP04[ MYVICTIM].HPLEFT := 0;
                    BATTLERC[ 0].A.TEMP04[ MYVICTIM].STATUS := LOST
                  END
                ELSE
                  BEGIN
                    CHARACTR[ MYVICTIM].HPMAX := 
                      (CHARACTR[ MYVICTIM].HPMAX DIV
                       CHARACTR[ MYVICTIM].MAXLEVAC) *
                                                   CHARACTR[ MYVICTIM].CHARLEV;
                    CHARACTR[ MYVICTIM].MAXLEVAC :=
                                                   CHARACTR[ MYVICTIM].CHARLEV;
                    IF CHARACTR[ MYVICTIM].HPLEFT >
                                                 CHARACTR[ MYVICTIM].HPMAX THEN
                      CHARACTR[ MYVICTIM].HPLEFT := CHARACTR[ MYVICTIM].HPMAX;
                    DRAINED[ MYVICTIM] := TRUE
                  END;
                PAUSE1
              END;   (* DRAINLEV *)
              
              
            PROCEDURE RESULT( ATTK0123: INTEGER;  (* P01090B *)
                              STONFLAG: INTEGER;
                              POISSTON: INTEGER;
                              DAMSTR:   STRING);
            
              VAR
                   CHANCBAD : INTEGER;
            
              BEGIN
                IF (RANDOM MOD 20) >
                                  CHARACTR[ MYVICTIM].LUCKSKIL[ STONFLAG] THEN
                  EXIT( RESULT);
                IF ATTK0123 = 3 THEN
                  BEGIN
                    CHANCBAD := BATTLERC[ BATG].B.HPREC.LEVEL * 2;
                    IF CHANCBAD > 50 THEN
                      CHANCBAD := 50;
                    IF (RANDOM MOD 100) > CHANCBAD THEN
                      EXIT( RESULT)
                  END;
                IF POISSTON > 0 THEN
                  IF CHARACTR[ MYVICTIM].WEPVSTY3[ 1][ POISSTON] THEN
                    EXIT( RESULT);
                IF CHARACTR[ MYVICTIM].STATUS >= DEAD THEN
                  EXIT( RESULT);
                CLRRECT( 1, 14, 38, 1);
                MVCURSOR( 1, 14);
                PRNAME( 0, MYVICTIM);
                PRINTSTR( 'IS ');
                PRINTSTR( DAMSTR );
                CASE ATTK0123 OF
                
                  0:  IF BATTLERC[ 0].A.TEMP04[ MYVICTIM].STATUS < STONED THEN
                        BATTLERC[ 0].A.TEMP04[ MYVICTIM].STATUS := STONED;
                
                  1:  CHARACTR[ MYVICTIM].LOSTXYL.POISNAMT[ 1] := 1;
                     
                  2:  IF BATTLERC[ 0].A.TEMP04[ MYVICTIM].STATUS < PLYZE THEN
                        BATTLERC[ 0].A.TEMP04[ MYVICTIM].STATUS := PLYZE;
                       
                  3:  BEGIN
                        BATTLERC[ 0].A.TEMP04[ MYVICTIM].STATUS := DEAD;
                        BATTLERC[ 0].A.TEMP04[ MYVICTIM].HPLEFT := 0
                      END
                END;
                PAUSE1
              END;  (* RESULT *)
            
            
            BEGIN  (* CASEDAMG *)
              WITH BATTLERC[ BATG].B DO
                BEGIN
                  IF SPPC[ 1] THEN
                    RESULT( 1, 0, 3, 'POISONED');
                  IF SPPC[ 2] THEN
                    RESULT( 2, 0, 0, 'PARALYZED');
                  IF SPPC[ 0] THEN
                    RESULT( 0, 1, 5, 'STONED');
                    
                  IF DRAINAMT > 0 THEN
                    DRAINLEV;
                    
                  IF SPPC[ 3] THEN
                    RESULT( 3, 0, 0, 'CRITICALLY HIT')
                END
            END;  (* CASEDAMG *)
            
            
          PROCEDURE ATTKSTRG;  (* P01090C *)
          
            PROCEDURE RIPBITCL;  (* P01090D *)
            
              BEGIN
                CASE (RANDOM MOD 5) OF
                  0:  PRINTSTR( 'TEARS');
                  1:  PRINTSTR( 'RIPS');
                  2:  PRINTSTR( 'GNAWS');
                  3:  PRINTSTR( 'BITES');
                  4:  PRINTSTR( 'CLAWS')
                END
              END;
              
              
            PROCEDURE ARMRIP;  (* P01090E *)
            
              BEGIN
                IF (RANDOM MOD 2) = 1 THEN
                  RIPBITCL
                ELSE
                  ARMATTK
              END;
            
            
            BEGIN (* ATTKSTRG *)
              CASE BATTLERC[ BATG].B.CLASS OF
                0, 1, 2, 3, 4, 5, 10, 11: ARMATTK;
                            6, 8, 12, 13: RIPBITCL;
                                    7, 9: ARMRIP;
              END
            END;
          
          
          BEGIN (* DAM2ME *)
            IF BATTLERC[ 0].A.TEMP04[ VICTIM].STATUS >= DEAD THEN
              EXIT( DAM2ME);
            PRNAME( BATG, BATI);
            ATTKSTRG;
            PRINTSTR( ' AT');
            MVCURSOR( 1, 12);
            PRINTSTR( CHARACTR[ VICTIM].NAME);
            MYVICTIM := VICTIM;
            IF BATTLERC[ 0].A.TEMP04[ MYVICTIM].STATUS < DEAD THEN
              BEGIN
                HPCALCPC :=
                  20
                  - CHARACTR[ MYVICTIM].ARMORCL 
                  - BATTLERC[ BATG].B.HPREC.LEVEL
                  + ACMOD2
                  + BATTLERC[ 0].A.TEMP04[ MYVICTIM].ARMORCL
                  + 2 * (ORD( BATTLERC[ BATG].A.TEMP04[ MYVICTIM].SPELLHSH = 0));
              
                IF HPCALCPC < 1 THEN
                  HPCALCPC := 1
                ELSE
                  IF HPCALCPC > 19 THEN
                    HPCALCPC := 19;
                HPDAMAGE := 0;
                HITSCNT := 0;
                MVCURSOR( 1, 13);
                FOR RECSI := 1 TO BATTLERC[ BATG].B.RECSN DO
                  IF (RANDOM MOD 20) >= HPCALCPC THEN
                    BEGIN
                      HPDAMAGE := HPDAMAGE +
                       CALCHP( BATTLERC[ BATG].B.RECS[ RECSI]);
                      HITSCNT := HITSCNT + 1
                    END;
                IF BATTLERC[ 0].A.TEMP04[ MYVICTIM].STATUS = ASLEEP THEN
                  HPDAMAGE := HPDAMAGE * 2;
                IF HPDAMAGE = 0 THEN
                    PRINTSTR( 'AND MISSES!')
                ELSE
                  BEGIN
                    PRINTSTR( 'AND HITS ');
                    PRINTNUM( HITSCNT, 3);
                    PRINTSTR( ' TIMES FOR ');
                    PRINTNUM( HPDAMAGE, 3);
                    PRINTSTR( ' DAMAGE');
                    CASEDAMG
                  END;
                
                BATTLERC[ 0].A.TEMP04[ MYVICTIM].HPLEFT :=
                  BATTLERC[ 0].A.TEMP04[ MYVICTIM].HPLEFT - HPDAMAGE;
                IF BATTLERC[ 0].A.TEMP04[ MYVICTIM].HPLEFT <= 0 THEN
                  BEGIN
                    CLRRECT( 1, 14, 38, 1);
                    MVCURSOR( 1, 14);
                    PRINTSTR( CHARACTR[ MYVICTIM].NAME);
                    PRINTSTR( ' IS SLAIN!');
                    BATTLERC[ 0].A.TEMP04[ MYVICTIM].HPLEFT := 0;
                    IF BATTLERC[ 0].A.TEMP04[ MYVICTIM].STATUS < DEAD THEN
                      BATTLERC[ 0].A.TEMP04[ MYVICTIM].STATUS := DEAD
                  END
              END
          END;  (* DAM2ME *)
          
          
        PROCEDURE DAM2ENMY;  (* P01090F *)
        
          VAR
               HPCALCPC : INTEGER;
               TEMPX    : INTEGER;  (* MULTIPLE USES *)
               SINGLEX  : INTEGER;
               HPDAMAGE : INTEGER;
               HITSCNT  : INTEGER;
        
          BEGIN
            SINGLEX := BATI MOD BATTLERC[ VICTIM].A.ALIVECNT;
            IF BATTLERC[ VICTIM].A.TEMP04[ SINGLEX].STATUS < DEAD THEN
              BEGIN
                PRNAME( BATG, BATI);
                ARMATTK;
                PRINTSTR( ' AT A');
                MVCURSOR( 1, 12);
                PRNAME( VICTIM, BATI);
                HPCALCPC := 21
                              - BATTLERC[ VICTIM].B.AC
                              - CHARACTR[ BATI].HPCALCMD
                              + BATTLERC[ VICTIM].A.TEMP04[ SINGLEX].ARMORCL
                              - 3 * VICTIM;
                IF HPCALCPC < 1 THEN
                  HPCALCPC := 1
                ELSE
                  IF HPCALCPC > 19 THEN
                    HPCALCPC := 19;
                HPDAMAGE := 0;
                MVCURSOR( 1, 13);
                HITSCNT := 0;
                FOR TEMPX := 1 TO CHARACTR[ BATI].SWINGCNT DO
                  IF (RANDOM MOD 20) >= HPCALCPC THEN
                    BEGIN
                      HPDAMAGE := HPDAMAGE + CALCHP( CHARACTR[ BATI].HPDAMRC);
                      HITSCNT := HITSCNT + 1
                    END;
                IF BATTLERC[ VICTIM].A.TEMP04[ SINGLEX].STATUS = ASLEEP THEN
                  HPDAMAGE := 2 * HPDAMAGE;
                IF CHARACTR[ BATI].WEPVSTYP[ BATTLERC[ VICTIM].B.CLASS] THEN
                  HPDAMAGE := 2 * HPDAMAGE;
                IF HPDAMAGE = 0 THEN
                  PRINTSTR( 'AND MISSES')
                ELSE
                  BEGIN
                    PRINTSTR( 'AND HITS ');
                    PRINTNUM( HITSCNT, 3);
                    PRINTSTR( ' TIMES FOR ');
                    PRINTNUM( HPDAMAGE, 3);
                    PRINTSTR( ' DAMAGE!');
                  END;
                BATTLERC[ VICTIM].A.TEMP04[ SINGLEX].HPLEFT :=
                  BATTLERC[ VICTIM].A.TEMP04[ SINGLEX].HPLEFT - HPDAMAGE;
                IF (CHARACTR[ BATI].CRITHITM) AND (HPDAMAGE > 0) THEN
                  BEGIN
                    TEMPX := CHARACTR[ BATI].CHARLEV * 2;
                    IF TEMPX > 50 THEN
                      TEMPX := 50;
                    IF (RANDOM MOD 100) < TEMPX THEN
                      IF (RANDOM MOD 35) >
                         BATTLERC[ VICTIM].B.HPREC.LEVEL + 10 THEN
                        BEGIN
                          MVCURSOR( 1, 14);
                          PRINTSTR( 'A CRITICAL HIT!');
                          WRITE( '');
                          BATTLERC[ VICTIM].A.TEMP04[ SINGLEX].HPLEFT := 0;
                          PAUSE1;
                          CLRRECT( 1, 14, 38, 1)
                        END;
                  END;
                IF BATTLERC[ VICTIM].A.TEMP04[ SINGLEX].HPLEFT <= 0 THEN
                  BEGIN
                    MVCURSOR( 1, 14);
                    PRNAME( 0, BATI);
                    PRINTSTR( 'KILLS ONE!');
                    BATTLERC[ VICTIM].A.TEMP04[ SINGLEX].HPLEFT := 0;
                    BATTLERC[ VICTIM].A.TEMP04[ SINGLEX].STATUS := DEAD
                  END
              END
          END;
          
          
        BEGIN  (* DOFIGHT *)
          IF BATG = 0 THEN
            DAM2ENMY
          ELSE
            DAM2ME
        END;
        
      
      
      PROCEDURE YELLHELP;  (* P010910 *)
      
        VAR
             YHTEMP2 : INTEGER;
      
      
        PROCEDURE NONECOME;  (* P010911 *)
        
          BEGIN
            PRINTSTR( 'BUT NONE COMES!');
            EXIT( YELLHELP)
          END;
        
        
        BEGIN  (* YELLHELP *)
          PRINTSTR( 'CALLS FOR HELP!');
          MVCURSOR( 1, 12);
          IF BATTLERC[ BATG].A.ALIVECNT = 9 THEN
            NONECOME;
          IF (RANDOM MOD 200) > 10 * BATTLERC[ BATG].B.HPREC.LEVEL THEN
            NONECOME;
          PRINTSTR( 'AND IS HEARD!');
          YHTEMP2 := BATTLERC[ BATG].A.ALIVECNT;
          BATTLERC[ BATG].A.ALIVECNT := YHTEMP2 + 1;
          BATTLERC[ BATG].A.ENMYCNT := BATTLERC[ BATG].A.ENMYCNT + 1;
          WITH BATTLERC[ BATG].A.TEMP04[ YHTEMP2] DO
            BEGIN
              AGILITY  := -1;
              SPELLHSH := 0;
              INAUDCNT := BATTLERC[ BATG].A.TEMP04[ BATI].INAUDCNT;
              ARMORCL  := 0;
              HPLEFT   := CALCHP( BATTLERC[ BATG].B.HPREC);
              STATUS   := OK;
            END
        END;  (* YELLHELP *)
        
        
      PROCEDURE DORUN;  (* P010912 *)
      
        BEGIN
          PRINTSTR( 'FLEES!');
          BATTLERC[ BATG].A.ENMYCNT := BATTLERC[ BATG].A.ENMYCNT - 1;
          WITH BATTLERC[ BATG].A.TEMP04[ BATI] DO
            BEGIN
              STATUS := DEAD;
              HPLEFT := 0
            END
        END;
        
        
      PROCEDURE DODISPEL;  (* P010913 *)
      
        VAR
             DISPLCNT : INTEGER;
             CHARX    : INTEGER;
             DISPCALC : INTEGER;
             
        BEGIN
          PRINTSTR( 'DISPELLS!');
          DISPCALC := 50 + 5 * CHARACTR[ BATI].CHARLEV -
                      10 * BATTLERC[ VICTIM].B.HPREC.LEVEL;
                      
          CASE CHARACTR[ BATI].CLASS OF
            LORD:    DISPCALC := DISPCALC - 40;
            BISHOP:  DISPCALC := DISPCALC - 20;
          END;
          
          DISPLCNT := 0;
          FOR CHARX := 0 TO BATTLERC[ VICTIM].A.ALIVECNT - 1 DO
            IF BATTLERC[ VICTIM].A.TEMP04[ CHARX].STATUS = OK THEN
              IF (RANDOM MOD 100) < DISPCALC THEN
                IF BATTLERC[ VICTIM].B.CLASS = 10 THEN
                  BEGIN
                    DISPLCNT := DISPLCNT + 1;
                    BATTLERC[ VICTIM].A.ENMYCNT := 
                      BATTLERC[ VICTIM].A.ENMYCNT - 1;
                    BATTLERC[ VICTIM].A.TEMP04[ CHARX].STATUS := DEAD;
                    BATTLERC[ VICTIM].A.TEMP04[ CHARX].HPLEFT := 0
                  END;
          MVCURSOR( 1, 12);
          IF DISPLCNT = 0 THEN
            PRINTSTR( 'TO NO AVAIL!')
          ELSE
            IF DISPLCNT = 1 THEN
              PRINTSTR( '1 DISSOLVES!')
            ELSE
              BEGIN
                PRINTNUM( DISPLCNT, 1);
                PRINTSTR( ' DISSOLVE!')
              END
        END;
        
        
      BEGIN  (* SWINGASW P010901 *)
        IF ATTACKTY < -1 THEN
          PRNAME( BATG, BATI);
        CASE ATTACKTY OF
          -5:  DODISPEL;
          -4:  YELLHELP;
          -3:  DOBREATH;
          -2:  DORUN;
          -1:  DOFIGHT;
        END
      END;   (* SWINGASW P010901 *)
      
      
    BEGIN (* MELEE *)
      FOR AGILELEV := 1 TO 10 DO
        FOR BATG := 0 TO 4 DO
          FOR BATI := 0 TO BATTLERC[ BATG].A.ALIVECNT - 1 DO
            IF BATTLERC[ BATG].A.TEMP04[ BATI].STATUS = OK THEN
              IF BATTLERC[ BATG].A.TEMP04[ BATI].AGILITY = AGILELEV THEN
                BEGIN
                  VICTIM := BATTLERC[ BATG].A.TEMP04[ BATI].VICTIM;
                  ATTACKTY := BATTLERC[ BATG].A.TEMP04[ BATI].SPELLHSH;
                  MVCURSOR( 1, 11);
                  IF (ATTACKTY >= -5) AND
                     (ATTACKTY <   0) THEN
                    SWINGASW                (* -5..-1 *)
                  ELSE IF ATTACKTY > 0 THEN
                    CASTASPE;
                  IF ATTACKTY <> 0 THEN
                    BEGIN
                      PAUSE1;
                      CLRRECT( 1, 11, 38, 4)
                    END
                END
    END;  (* MELEE *)
    
    
(* COMBAT SEGMENT *)
      
      
    
    BEGIN (* COMBAT P010401 *)
    
      DONEFIGH := FALSE;
      CINITFL1 := 0;
      CINIT;
      XGOTO := XREWARD;
      REPEAT
        CUTIL;
        IF NOT DONEFIGH THEN
          MELEE;
      UNTIL DONEFIGH;
      CINITFL1 := 2;
      CINIT
    END;  (* COMBAT *)
  