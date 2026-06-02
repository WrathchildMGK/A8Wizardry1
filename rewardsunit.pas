SEGMENT PROCEDURE REWARDS;    (* P010D01 *)
    
    VAR
         EXPPERCH : TWIZLONG;
         ALIVECNT : INTEGER;
         ONEORTWO : INTEGER;
         REWARDI  : INTEGER;
         TRAP3TYP : INTEGER;
  
      
    PROCEDURE PIC2SCRN( BUFFERI: INTEGER);  (* P010D02 *)
    
      TYPE
           BYTE = PACKED ARRAY[ 0..1] OF CHAR;
    
      VAR
           PIXLIN : INTEGER;
           UNUSED : INTEGER;
           MEMLOC : RECORD CASE INTEGER OF
               1 : (I : INTEGER);
               2 : (P : ^BYTE);
             END;
           
      BEGIN
        CLRPICT( 0, 0, 0, 100);  (* CLEAR PICTURE *)
        FOR PIXLIN := 23 TO 72 DO
          BEGIN
            MEMLOC.I := 8193 + 1024 * (PIXLIN MOD 8) +
                        128 * ((PIXLIN MOD 64) DIV 8) +
                        40 * (PIXLIN DIV 64);
            MOVELEFT( IOCACHE[ BUFFERI], MEMLOC.P^, 10);
            BUFFERI := BUFFERI + 10
          END;
      END;  (* PIC2SCRN *)
      
      
    PROCEDURE PRLONG2( VAR MP01 : TWIZLONG);  (* P010D03 *)
    
      VAR
           BCDNUM   : TBCD;
           NONZEROI : INTEGER;
           SUPPRESI : INTEGER;
           
      BEGIN
        LONG2BCD( MP01, BCDNUM);
        SUPPRESI := 1;
        WHILE (SUPPRESI < 12) AND (BCDNUM[ SUPPRESI] = 0) DO
          SUPPRESI := SUPPRESI + 1;
        FOR NONZEROI := SUPPRESI TO 12 DO
          PRINTCHR( CHR( BCDNUM[ NONZEROI] + ORD( '0')))
      END;
      
      
    PROCEDURE ENMYREWD;  (* P010D04 *)
    
      VAR
           ENEMY : TENEMY;
    
      BEGIN
        MOVELEFT( IOCACHE[ GETREC( ZENEMY, ENEMYINX, SIZEOF( TENEMY))],
                  ENEMY,
                  SIZEOF( TENEMY));
        IF ENEMY.UNIQUE > 0 THEN
          BEGIN
            ENEMY.UNIQUE := ENEMY.UNIQUE - 1;
            MOVELEFT( ENEMY,
                      IOCACHE[ GETRECW( ZENEMY, ENEMYINX, SIZEOF( TENEMY))],
                      SIZEOF( TENEMY))
          END;
        ONEORTWO := 1;
        IF ATTK012 = 0 THEN
          REWARDI := ENEMY.REWARD1
        ELSE IF ATTK012 = 1 THEN
          BEGIN
            REWARDI := ENEMY.REWARD1;
            ONEORTWO := 2
          END
        ELSE
          REWARDI := ENEMY.REWARD2
      END;  (* ENMYREWD *)
      
      
    PROCEDURE FOUNDITM( FNDCHARX: INTEGER;  (* P010D05 *)
                        POSSX   : INTEGER;
                        ITEMINDX: INTEGER);
    
      VAR
           OBJECTRC : TOBJREC;
    
        
      BEGIN  (* FOUNDITM *)
        MOVELEFT( IOCACHE[ GETREC( ZOBJECT,
                                   ITEMINDX,
                                   SIZEOF( TOBJREC))],
                  OBJECTRC,
                  SIZEOF( TOBJREC));
        CLRRECT( 1, 11, 38, 4);
        MVCURSOR( 1, 12);
        PRINTSTR( CHARACTR[ FNDCHARX].NAME);
        PRINTSTR( ' FOUND - ');
        PRINTSTR( OBJECTRC.NAMEUNK);
        WITH CHARACTR[ FNDCHARX].POSS DO
          BEGIN
            POSSX := POSSCNT + 1;
            POSSESS[ POSSX].EQUIPED := FALSE;
            POSSESS[ POSSX].IDENTIF := FALSE;
            POSSESS[ POSSX].CURSED  := FALSE;
            POSSESS[ POSSX].EQINDEX := ITEMINDX;
            POSSCNT := POSSX
          END
      END;   (* FOUNDITM *)
      
      
    PROCEDURE CHSTGOLD;  (* P010D06 *)

      TYPE
      
        TREWARDX = RECORD
            REWDPERC : INTEGER;
            BITEM    : INTEGER;
            REWDCALC : RECORD CASE INTEGER OF
                1: (GOLD:  RECORD
                      TRIES   : INTEGER;
                      AVEAMT  : INTEGER;
                      MINADD  : INTEGER;
                      MULTX   : INTEGER;
                      TRIES2  : INTEGER;
                      AVEAMT2 : INTEGER;
                      MINADD2 : INTEGER;
                    END);
                2: (ITEM:  RECORD
                      MININDX  : INTEGER;
                      MFACTOR  : INTEGER;
                      MAXTIMES : INTEGER;
                      RANGE    : INTEGER;
                      PERCBIGR : INTEGER;
                      UNUSEDXX : INTEGER;
                      UNUSEDYY : INTEGER;
                    END);
              END;
          END;
          
        TREWARD = RECORD
            BCHEST   : BOOLEAN;
            BTRAPTYP : PACKED ARRAY[ 0..7] OF BOOLEAN;
            REWRDCNT : INTEGER;
            REWARDXX : ARRAY[ 1..9] OF TREWARDX;
          END;
      
      VAR
           CHRXCHST : INTEGER;
           INDX     : INTEGER;
           GOLD2ONE : TWIZLONG;
           REWARDZ  : TREWARD;
    
    
      PROCEDURE RDREWARD;  (* P010D07 *)
      
        BEGIN
          MOVELEFT( IOCACHE[ GETREC( ZREWARD, REWARDI, SIZEOF( TREWARD))],
                    REWARDZ,
                    SIZEOF( TREWARD))
        END;
        
        
      PROCEDURE ACHEST;  (* P010D08 *)
      
        VAR
             WHOTRIED : ARRAY[ 0..5] OF BOOLEAN;
             TRAPTYPE : INTEGER;
             
             
        PROCEDURE GTTRAPTY;  (* P010D09 *)
        
        VAR
             BTRAPPED : BOOLEAN;
             UNUSEDXX : INTEGER;
             UNUSEDYY : INTEGER;
             ZERO99   : INTEGER;
        
          BEGIN
            BTRAPPED := FALSE;
            FOR TRAPTYPE := 0 TO 7 DO
              IF REWARDZ.BTRAPTYP[ TRAPTYPE] THEN
                BTRAPPED := TRUE;
            TRAP3TYP := (RANDOM MOD 5);
            IF NOT BTRAPPED THEN
              TRAPTYPE := 0
            ELSE
              IF (RANDOM MOD 15) > (4 + MAZELEV) THEN
                TRAPTYPE := 0
              ELSE
                BEGIN
                  ZERO99 := RANDOM MOD 100;
                  TRAPTYPE := 0;
                  WHILE ZERO99 > 0 DO
                    
                    REPEAT
                      IF TRAPTYPE < 7 THEN
                        BEGIN
                          IF TRAPTYPE = 3 THEN
                            ZERO99 := ZERO99 - 5
                          ELSE
                            ZERO99 := ZERO99 - 1;
                          TRAPTYPE := TRAPTYPE + 1
                        END
                      ELSE
                        TRAPTYPE := 0 + 1
                    UNTIL REWARDZ.BTRAPTYP[ TRAPTYPE]
                    
                END
          END;  (* GTTRAPTY *)
          
          
        PROCEDURE EXITRWDS;  (* P010D0A *)
        
          BEGIN
            EXIT( REWARDS)
          END;
          
          
        PROCEDURE PRTRAPTY( TRAPTYPE: INTEGER;  (* P010D0B *)
                            TRAP3TY:  INTEGER);
          
          VAR
               UNUSEDXX : INTEGER;
        
          BEGIN
            CASE TRAPTYPE OF
              0:  PRINTSTR( 'TRAPLESS CHEST');
              1:  PRINTSTR( 'POISON NEEDLE');
              2:  PRINTSTR( 'GAS BOMB');
              3:  CASE TRAP3TY OF
                    0:  PRINTSTR( 'CROSSBOW BOLT');
                    1:  PRINTSTR( 'EXPLODING BOX');
                    2:  PRINTSTR( 'SPLINTERS');
                    3:  PRINTSTR( 'BLADES');
                    4:  PRINTSTR( 'STUNNER');
                  END;
              4:  PRINTSTR( 'TELEPORTER');
              5:  PRINTSTR( 'ANTI-MAGE');
              6:  PRINTSTR( 'ANTI-PRIEST');
              7:  PRINTSTR( 'ALARM');
            END;
            PAUSE2
          END;  (* PRTRAPTY *)
          
          
        PROCEDURE DOTRAPDM;  (* P010D0C *)
        
          VAR
               UNUSEDXX : INTEGER;
               UNUSEDYY : INTEGER;
               CHARX    : INTEGER;
        
        
          PROCEDURE HPDAMAGE( CHARXHIT: INTEGER;  (* P010D0D *)
                              HITCNT:   INTEGER;
                              HITDAM:   INTEGER);
          
            VAR
                 TOTDAM : INTEGER;
          
            BEGIN
              TOTDAM := 0;
              WHILE HITCNT > 0 DO
                BEGIN
                  TOTDAM := TOTDAM + (RANDOM MOD HITDAM) + 1;
                  HITCNT := HITCNT - 1
                END;
              CHARACTR[ CHARXHIT].HPLEFT := CHARACTR[ CHARXHIT].HPLEFT - TOTDAM;
              IF CHARACTR[ CHARXHIT].HPLEFT < 1 THEN
                BEGIN
                  CHARACTR[ CHARXHIT].HPLEFT := 0;
                  CHARACTR[ CHARXHIT].STATUS := DEAD;
                  CLRRECT( 1, 11, 38, 4);
                  MVCURSOR( 1, 12);
                  PRINTSTR( CHARACTR[ CHARXHIT].NAME);
                  PRINTSTR( ' DIES!');
                  ALIVECNT := ALIVECNT - 1;
                  IF ALIVECNT = 0 THEN
                    BEGIN
                      XGOTO := XCEMETRY;
                      EXIT( REWARDS)
                    END
                END
            END;  (* HPDAMAGE *)
            
            
          PROCEDURE ANTIPM( BMAGEDAM: BOOLEAN);  (* P010D0E *)
          
           VAR
                PLYZSTON : BOOLEAN;
                CHARPM   : INTEGER;
          
          
            PROCEDURE ISSTONED;  (* P010D0F *)
            
              BEGIN
                IF CHARACTR[ CHARPM].STATUS < STONED THEN
                  CHARACTR[ CHARPM].STATUS := STONED
              END;
              
              
            PROCEDURE ISPLYZE;  (* P010D10 *)
            
              BEGIN
                IF CHARACTR[ CHARPM].STATUS < PLYZE THEN
                  CHARACTR[ CHARPM].STATUS := PLYZE
              END;
              
              
            BEGIN  (* ANTIPM *)
              FOR CHARPM := 0 TO PARTYCNT - 1 DO
                BEGIN
                  PLYZSTON := (RANDOM MOD 20) < CHARACTR[ CHARPM].LUCKSKIL[ 4];
                  
                  CASE CHARACTR[ CHARPM].CLASS OF
                  
                       MAGE:  IF BMAGEDAM THEN
                                IF PLYZSTON THEN
                                  ISPLYZE
                                ELSE
                                  ISSTONED;
                                  
                    SAMURAI:  IF BMAGEDAM THEN
                                IF NOT PLYZSTON THEN
                                  ISPLYZE;
                                 
                     PRIEST:  IF NOT BMAGEDAM THEN
                                IF PLYZSTON THEN
                                  ISPLYZE
                                ELSE
                                  ISSTONED;
                                  
                     BISHOP:  IF NOT BMAGEDAM THEN
                                IF NOT PLYZSTON THEN  (* IF NOT SET... *)
                                  ISPLYZE;
                  END
                END
            END;   (* ANTIPM *)
          
          
          PROCEDURE TYPE3DAM;  (* P010D11 *)
          
          
            PROCEDURE HPDAMALL( CHANCHIT: INTEGER;  (* P010D12 *)
                                HITCNT:   INTEGER;
                                HITDAM:   INTEGER);
                               
              VAR
                   CHARXHIT : INTEGER;
            
              BEGIN
                FOR CHARXHIT := 0 TO PARTYCNT - 1 DO
                  IF (RANDOM MOD 100) < CHANCHIT THEN
                    HPDAMAGE( CHARXHIT, HITCNT, HITDAM)
                  ELSE
                    IF (RANDOM MOD 100) < CHANCHIT THEN
                      HPDAMAGE( CHARXHIT, HITCNT, (HITDAM DIV 2) + 1)
              END;  (* HPDAMALL *)
              
              
            BEGIN (* TYPE3DAM *)
              CASE TRAP3TYP OF
                0:  HPDAMAGE( CHRXCHST, MAZELEV, 8);  (* CROSSBOW BOLT *)
                1:  HPDAMALL(       50, MAZELEV, 8);  (* EXPLODING BOX *)
                2:  HPDAMALL(       70, MAZELEV, 6);  (* SPLINTERS     *)
                3:  HPDAMALL(       30, MAZELEV, 12); (* BLADES        *)
                4:  CHARACTR[ CHRXCHST].STATUS := PLYZE;  (* STUNNER       *)
              END
            END;  (* TYPE3DAM *)
        
        
          BEGIN (* DOTRAPDM *)
            CLRRECT( 13, 8, 26, 2);
            MVCURSOR( 13, 8);
            IF TRAPTYPE <> 0 THEN
              BEGIN
                PRINTSTR( 'OOPPS! A ');
                PRTRAPTY( TRAPTYPE, TRAP3TYP)
              END
            ELSE
              PRINTSTR( 'THE CHEST WAS NOT TRAPPED');
            PAUSE2;
            
            CASE TRAPTYPE OF
            
              1:  (* POISON *)
              
                    CHARACTR[ CHRXCHST].LOSTXYL.POISNAMT[ 1] :=
                      CHARACTR[ CHRXCHST].LOSTXYL.POISNAMT[ 1] + 1;
                   
              2:  (* GAS *)
              
                    FOR CHARX := 0 TO PARTYCNT - 1 DO
                      IF (RANDOM MOD 20) < CHARACTR[ CHARX].LUCKSKIL[ 3] THEN
                        CHARACTR[ CHARX].LOSTXYL.POISNAMT[ 1] := 1;
                        
              3:  (* CROSSBOW BOLT *)
                  (* EXPLODING     *)
                  (* SPLINTERS     *)
                  (* BLADES        *)
                  (* STUNNER       *)
                  
                    TYPE3DAM;
                
              4:  (* TELEPORTER    *)
              
                    BEGIN
                      MAZEX := RANDOM MOD (19 + 1);
                      MAZEY := RANDOM MOD (19 + 1);
                      DIRECTIO := RANDOM MOD 4
                    END;
                    
              5:  (* ANTI-MAGE *)
                  
                    ANTIPM( TRUE);
                
              6:  (* ANTI-PRIEST *)
              
                    ANTIPM( FALSE);
                
              7:  (* ALARM *)
              
                    BEGIN
                      CHSTALRM := 1;
                      EXIT( REWARDS)
                    END;
            END;
            
            EXIT( ACHEST)
          END;  (* DOTRAPDAM *)
          
          
        PROCEDURE PRTRAP;  (* P010D13 *)
        
          BEGIN
            CLRRECT( 13, 8, 26, 2);
            MVCURSOR( 13, 8);
            PRTRAPTY( TRAPTYPE, TRAP3TYP);
            PAUSE2
          END;
          
          
        PROCEDURE PRRNDTRP;  (* P010D14 *)
        
          VAR
               RNDX   : INTEGER;
               LOOPER : INTEGER;
               TRAP   : INTEGER;
        
          BEGIN
            TRAP := 0;
            RNDX := RANDOM MOD 50;
            FOR LOOPER := 1 TO RNDX DO
              IF TRAP = 7 THEN
                TRAP := 0
              ELSE
                TRAP := TRAP + 1;
            CLRRECT( 13, 8, 26, 2);
            MVCURSOR( 13, 8);
            PRTRAPTY( TRAP, RANDOM MOD 5);
            PAUSE2
          END;  (* PRRNDTRP *)
          
          
        PROCEDURE INSPCHST;  (* P010D15 *)
        
          VAR
               UNUSEDXX : INTEGER;
               CHNCGOOD : INTEGER;
               CHARINSP : INTEGER;
               
          BEGIN
            CLRRECT( 13, 8, 26, 2);
            MVCURSOR( 15, 8);
            PRINTSTR( 'WHO (#) WILL INSPECT?');
            GETKEY;
            CHARINSP := ORD( INCHAR) - ORD( '0') - 1;
            
            IF (CHARINSP < 0) OR (CHARINSP >= PARTYCNT) THEN
              EXIT( INSPCHST);
            IF CHARACTR[ CHARINSP].STATUS <> OK THEN
              EXIT( INSPCHST);
            IF WHOTRIED[ CHARINSP] THEN
              BEGIN
                CLRRECT( 13, 8, 26, 1);
                MVCURSOR( 16, 8);
                PRINTSTR( 'YOU ALREADY LOOKED!');
                PAUSE2;
                EXIT( INSPCHST)
              END;
            WHOTRIED[ CHARINSP] := TRUE;
            CHNCGOOD := CHARACTR[ CHARINSP].ATTRIB[ AGILITY];
            IF CHARACTR[ CHARINSP].CLASS = THIEF THEN
              CHNCGOOD := CHNCGOOD * 6
            ELSE
              IF CHARACTR[ CHARINSP].CLASS = NINJA THEN
                CHNCGOOD := CHNCGOOD * 4;
            IF CHNCGOOD > 95 THEN
              CHNCGOOD := 95;
            CHRXCHST := CHARINSP;
            IF (RANDOM MOD 100) < CHNCGOOD THEN
              PRTRAP
            ELSE
              IF (RANDOM MOD 20) > CHARACTR[ CHARINSP].ATTRIB[ AGILITY] THEN
                DOTRAPDM
              ELSE
                PRRNDTRP;
          END;  (* INSPCHST *)
          
          
        PROCEDURE CALFOCH;  (* P010D16 *)
        
          BEGIN
            CLRRECT( 13, 8, 26, 2);
            MVCURSOR( 14, 8);
            PRINTSTR( 'WHO (#) WILL CAST CALFO?');
            GETKEY;
            CHRXCHST := ORD( INCHAR) - ORD( '0') - 1;
            
            IF (CHRXCHST < 0) OR (CHRXCHST >= PARTYCNT) THEN
              EXIT( CALFOCH);
            IF NOT (CHARACTR[ CHRXCHST].SPELLSKN[ 28]) THEN
              EXIT( CALFOCH);
            IF CHARACTR[ CHRXCHST].PRIESTSP[ 2] = 0 THEN
              EXIT( CALFOCH);
            IF CHARACTR[ CHRXCHST].STATUS <> OK THEN
              EXIT( CALFOCH);
            WITH CHARACTR[ CHRXCHST] DO
              BEGIN
                PRIESTSP[ 2] := PRIESTSP[ 2] - 1;
                IF (RANDOM MOD 100) < 95 THEN
                  PRTRAP
                ELSE
                  PRRNDTRP
              END
          END;  (* CALFOCH *)
          
          
        PROCEDURE DISARMTR;  (* P010D17 *)
        
          VAR
               UNUSEDXX : INTEGER;
               UNUSEDYY : INTEGER;
               UNUSEDZZ : INTEGER;
               TRAPSTR  : STRING;
        
        
          PROCEDURE DISARM;  (* P010D18 *)
          
            BEGIN
              CLRRECT( 13, 8, 26, 2);
              MVCURSOR( 18, 8);
              IF (RANDOM MOD 70) < 
                 (  CHARACTR[ CHRXCHST].CHARLEV
                  - MAZELEV
                  + (50 * ORD( ((CHARACTR[ CHRXCHST].CLASS = THIEF) OR
                                (CHARACTR[ CHRXCHST].CLASS = NINJA)))
                    )
                 ) THEN
                BEGIN
                  PRINTSTR( 'YOU DISARMED IT!');
                  PAUSE2;
                  EXIT( ACHEST)
                END
              ELSE
                IF (RANDOM MOD 20) < CHARACTR[ CHRXCHST].ATTRIB[ AGILITY] THEN
                  BEGIN
                    PRINTSTR( 'DISARM FAILED!!');
                    PAUSE2;
                    EXIT( DISARMTR)
                  END
                ELSE
                  BEGIN
                    PRINTSTR( 'YOU SET IT OFF!');
                    PAUSE2;
                    DOTRAPDM
                  END
            END;  (* DISARM *)
          
          
          BEGIN  (* DISARMTR *)
            CLRRECT( 13, 8, 26, 2);
            MVCURSOR( 16, 8);
            PRINTSTR( 'WHO (#) WILL DISARM?');
            GETKEY;
            CHRXCHST := ORD( INCHAR) - ORD( '0') - 1;
            
            IF (CHRXCHST < 0) OR (CHRXCHST >= PARTYCNT) THEN
              EXIT( DISARMTR);
            IF CHARACTR[ CHRXCHST].STATUS <> OK THEN
              EXIT( DISARMTR);
            CLRRECT( 13, 8, 26, 2);
            MVCURSOR( 13, 8);
            PRINTSTR( 'WHAT TRAP >');
            GETSTR( TRAPSTR, 24, 8);
            IF (TRAPSTR = 'POISON NEEDLE') AND (TRAPTYPE = 1) THEN
              DISARM
            ELSE IF (TRAPSTR = 'GAS BOMB') AND (TRAPTYPE = 2) THEN
              DISARM
            ELSE IF TRAPTYPE = 3 THEN
              BEGIN
                CASE TRAP3TYP OF
                  0:  IF TRAPSTR = 'CROSSBOW BOLT' THEN
                        DISARM;
                       
                  1:  IF TRAPSTR = 'EXPLODING BOX' THEN
                        DISARM;
                       
                  2:  IF TRAPSTR = 'SPLINTERS' THEN
                        DISARM;
                       
                  3:  IF TRAPSTR = 'BLADES' THEN
                        DISARM;
                       
                  4:  IF TRAPSTR = 'STUNNER' THEN
                        DISARM;
                END;
                
                (* DOTRAPDM *)
              END
            ELSE IF (TRAPSTR = 'TELEPORTER') AND (TRAPTYPE = 4) THEN
              DISARM
            ELSE IF (TRAPSTR = 'ANTI-MAGE') AND (TRAPTYPE = 5) THEN
              DISARM
            ELSE IF (TRAPSTR = 'ANTI-PRIEST') AND (TRAPTYPE = 6) THEN
              DISARM
            ELSE IF (TRAPSTR = 'ALARM') AND (TRAPTYPE = 7) THEN
              DISARM
            ELSE
              DOTRAPDM
          END;   (* DISARMTR *)
          
          
        PROCEDURE OPENCHST;  (* P010D19 *)
        
          BEGIN
            CLRRECT( 13, 8, 26, 2);
            MVCURSOR( 17, 8);
            PRINTSTR( 'WHO (#) WILL OPEN?');
            GETKEY;
            CHRXCHST := ORD( INCHAR) - ORD( '0') - 1;
            
            IF (CHRXCHST < 0) OR (CHRXCHST >= PARTYCNT) THEN
              EXIT( OPENCHST);
            IF CHARACTR[ CHRXCHST].STATUS <> OK THEN
              EXIT( OPENCHST);
            IF TRAPTYPE = 0 THEN
              EXIT( ACHEST);
            IF (RANDOM MOD 1000) < CHARACTR[ CHRXCHST].CHARLEV THEN
              EXIT( ACHEST);
            DOTRAPDM
          END;  (* OPENCHST *)
          
          
        BEGIN (* ACHEST *)
          PIC2SCRN( GETREC( ZSPCCHRS, 18, 512));
          FILLCHAR( WHOTRIED, 12, 0);
          GTTRAPTY;
          CLRRECT( 13, 6, 26, 4);
          MVCURSOR( 13, 6);
          PRINTSTR( 'A CHEST! YOU MAY:');
          REPEAT
            CLRRECT( 13, 8, 26, 2);
            MVCURSOR( 13, 8);
            PRINTSTR( 'O)PEN     C)ALFO   L)EAVE');
            MVCURSOR( 13, 9);
            PRINTSTR( 'I)NSPECT  D)ISARM');
            GETKEY;
            
            IF      INCHAR = 'O' THEN
              OPENCHST
            ELSE IF INCHAR = 'L' THEN
              EXITRWDS
            ELSE IF INCHAR = 'I' THEN
              INSPCHST
            ELSE IF INCHAR = 'C' THEN
              CALFOCH
            ELSE IF INCHAR = 'D' THEN
              DISARMTR
          UNTIL FALSE
        END;  (* ACHEST *)
        
        
      PROCEDURE GETREWRD( REWARDM: TREWARDX);  (* P010D1A *)
      
        VAR
             ITEMINDX : INTEGER;
             CHARIIII : INTEGER;
             CHARXXXX : INTEGER;  (* MULTIPLE USES *)
      
      
        FUNCTION CALCULAT( TRIES:  INTEGER;  (* P010D1B *)
                           AVEAMT: INTEGER;
                           MINADD: INTEGER) : INTEGER;
        
          VAR
               TOTAL : INTEGER;
               
          BEGIN
            TOTAL := MINADD;
            WHILE TRIES > 0 DO
              BEGIN
                TOTAL := TOTAL + (RANDOM MOD AVEAMT) + 1;
                TRIES := TRIES - 1
              END;
            CALCULAT := TOTAL
          END;  (* CALCULAT *)
          
          
        PROCEDURE GOLDREWD;  (* P010D1C *)
        
        VAR
             GOLDAMT : TWIZLONG;
        
          BEGIN
            FILLCHAR( GOLDAMT, 6, 0);
            GOLDAMT.LOW := CALCULAT( REWARDM.REWDCALC.GOLD.TRIES,
                                     REWARDM.REWDCALC.GOLD.AVEAMT,
                                     REWARDM.REWDCALC.GOLD.MINADD);
            MULTLONG( GOLDAMT, REWARDM.REWDCALC.GOLD.MULTX);
            CHARXXXX := CALCULAT( REWARDM.REWDCALC.GOLD.TRIES2,
                                  REWARDM.REWDCALC.GOLD.AVEAMT2,
                                  REWARDM.REWDCALC.GOLD.MINADD2);
            MULTLONG( GOLDAMT, CHARXXXX);
            MULTLONG( GOLDAMT, ONEORTWO);
            ADDLONGS( GOLD2ONE, GOLDAMT)
          END;  (* GOLDREWD *)
          
          
        PROCEDURE ITEMREWD;  (* P010D1D *)
        
          BEGIN
            CHARXXXX := RANDOM MOD PARTYCNT;
            WHILE CHARACTR[ CHARXXXX].STATUS <> OK DO
              CHARXXXX := (CHARXXXX + 1) MOD PARTYCNT;
            IF CHARACTR[ CHARXXXX].POSS.POSSCNT = 8 THEN
              EXIT( ITEMREWD);  (* IF RANDOM CHARACTER IS OK AND HAS 8 
                                   POSSESSIONS,  THEN EXIT !! *)
            CHARIIII := 0;
            WHILE (CALCULAT( 01, 100, 1) <
                                     REWARDM.REWDCALC.ITEM.PERCBIGR) AND
                  (CHARIIII < REWARDM.REWDCALC.ITEM.MAXTIMES) DO
              CHARIIII := CHARIIII + 1;
            ITEMINDX := REWARDM.REWDCALC.ITEM.MININDX +
               (CALCULATE( 1, REWARDM.REWDCALC.ITEM.RANGE, 1)) +
               (REWARDM.REWDCALC.ITEM.MFACTOR * CHARIIII);
            FOUNDITM( CHARXXXX, CHARIIII, ITEMINDX);
            PAUSE2
          END;  (* ITEMREWD *)
          
          
        BEGIN  (* GETREWRD *)
          IF REWARDM.REWDPERC < (RANDOM MOD 100) THEN
            EXIT( GETREWRD);
          IF REWARDM.BITEM = 0 THEN
            GOLDREWD
          ELSE
            ITEMREWD
        END;   (* GETREWRD *)
        
        
      PROCEDURE GIVEGOLD;  (* P010D1E *)
      
        BEGIN
          DIVLONG( GOLD2ONE, ALIVECNT);
          CLRRECT( 1, 11, 38, 4);
          MVCURSOR( 1, 12);
          PRINTSTR( 'EACH SHARE IS WORTH ');
          PRLONG2( GOLD2ONE);
          PRINTSTR( ' GP!');
          FOR INDX := 0 TO PARTYCNT - 1 DO
            IF CHARACTR[ INDX].STATUS = OK THEN
              ADDLONGS( CHARACTR[ INDX].GOLD, GOLD2ONE);
          PAUSE2
        END;  (* GIVEGOLD *)
        
        
      BEGIN (* CHSTGOLD *)
        FILLCHAR( GOLD2ONE, 6, 0);
        ENMYREWD;
        RDREWARD;
        UNITCLEAR( 1);
        IF REWARDZ.BCHEST AND (CHSTALRM <> 1) THEN
          BEGIN
            ACHEST;
            CLRRECT( 3, 5, 9, 5)
          END
        ELSE
          CHSTALRM := 0;
        CLRRECT( 1, 11, 38, 4);
        PIC2SCRN( GETREC( ZSPCCHRS, 19, 512));
        FOR INDX := 1 TO REWARDZ.REWRDCNT DO
          GETREWRD( REWARDZ.REWARDXX[ INDX]);
        GIVEGOLD
      END;  (* CHSTGOLD *)
    
  PROCEDURE GIVEEXP;  (* P010D1F *)
  
    VAR
         WEPSTY3I : INTEGER;
         SPPCI    : INTEGER;
         BATRESLT : TBATRSLT;
         CHARXXX  : INTEGER;  (* MULTIPLE USES *)
         KILLEXP  : TWIZLONG; (* MULTIPLE USES *)
                  
                  
    PROCEDURE CNTALIVE;  (* P010D20 *)
    
      BEGIN
        ALIVECNT := 0;
        FOR LLBASE04 := 0 TO PARTYCNT - 1 DO
          IF CHARACTR[ LLBASE04].STATUS = OK THEN
            ALIVECNT := ALIVECNT + 1;
        IF ALIVECNT = 0 THEN
          BEGIN
            XGOTO := XCEMETRY;
            EXIT( REWARDS)
          END
      END;  (* CNTALIVE *)
      
      
    PROCEDURE CALC1EXP;  (* P010D21 *)
    
      VAR
            MULT2040 : INTEGER;
    
    
      PROCEDURE TOTALEXP;  (* P010D22 *)
      
        VAR
             ENEMYREC : TENEMY;
      
          PROCEDURE CALCKILL;  (* P010D23 *)
          
            VAR
                 KILLEXPX: TWIZLONG;
          
          
            PROCEDURE SETKILLX( AMOUNT : INTEGER);  (* P010D24 *)
            
              BEGIN (* SETKILLX *)
                KILLEXPX.HIGH := 0;
                KILLEXPX.MID  := 0;
                KILLEXPX.LOW  := AMOUNT
              END;  (* SETKILLX *)
              
              
            PROCEDURE MLTADDKX( MULTIPLY : INTEGER;  (* P010D25 *)
                                AMOUNT   : INTEGER);
                               
              BEGIN (* MLTADDKX *)
                IF MULTIPLY = 0 THEN
                  EXIT( MLTADDKX);
                SETKILLX( AMOUNT);
                WHILE MULTIPLY > 1 DO
                  BEGIN
                    MULTIPLY := MULTIPLY - 1;
                    ADDLONGS( KILLEXPX, KILLEXPX)
                  END;
                ADDLONGS( KILLEXP, KILLEXPX)
              END;  (* MLTADDKX *)
              
          
            BEGIN (* CALCKILL *)
              FILLCHAR( KILLEXP, 6, CHR( 0));
              FILLCHAR( KILLEXPX, 6, CHR( 0));
              SETKILLX( ENEMYREC.HPREC.LEVEL * ENEMYREC.HPREC.HPFAC);
              IF ENEMYREC.BREATHE = 0 THEN
                MULT2040:= 20
              ELSE
                MULT2040:= 40;
              MULTLONG( KILLEXPX, MULT2040);
              ADDLONGS( KILLEXP, KILLEXPX);
              MLTADDKX( ENEMYREC.MAGSPELS, 35);
              MLTADDKX( ENEMYREC.PRISPELS, 35);
              MLTADDKX( ENEMYREC.DRAINAMT, 200);
              MLTADDKX( ENEMYREC.HEALPTS, 90);
              
              SETKILLX( 40 * (11 - ENEMYREC.AC));
              ADDLONGS( KILLEXP, KILLEXPX);
              IF ENEMYREC.RECSN > 1 THEN
                MLTADDKX( ENEMYREC.RECSN, 30);
              IF ENEMYREC.UNAFFCT > 0 THEN
                MLTADDKX( (ENEMYREC.UNAFFCT DIV 10) + 1, 40);
              LLBASE04 := 0;
              FOR WEPSTY3I := 1 TO 6 DO
                IF ENEMYREC.WEPVSTY3[ WEPSTY3I] THEN
                  LLBASE04 := LLBASE04 + 1;
              MLTADDKX( LLBASE04, 35);
              LLBASE04 := 0;
              FOR SPPCI := 0 TO 6 DO
                IF ENEMYREC.SPPC[ SPPCI] THEN
                  LLBASE04 := LLBASE04 + 1;
              MLTADDKX( LLBASE04, 40)
            END;  (* CALCKILL *)
            
        BEGIN (* TOTALEXP *)
          MOVELEFT( IOCACHE[ GETREC( ZENEMY,
                                     BATRESLT.ENMYID[ CHARXXX],
                                     SIZEOF( TENEMY))],
                    ENEMYREC,
                    SIZEOF( TENEMY));
          CALCKILL;   (* KILLEXP := ENEMYREC.EXPAMT;  LOL *)

          MULTLONG( KILLEXP, BATRESLT.ENMYCNT[ CHARXXX]);
          ADDLONGS( EXPPERCH, KILLEXP)
        END;  (* TOTALEXP *)
      
      
      BEGIN  (* CALC1EXP *)
        FILLCHAR( EXPPERCH, 6, 0);
        FOR CHARXXX := 1 TO 4 DO
          IF BATRESLT.ENMYID[ CHARXXX] >= 0 THEN
            TOTALEXP;
        DIVLONG( EXPPERCH, ALIVECNT)
      END;   (* CALC1EXP *)
      
      
    PROCEDURE CHKDRAIN;  (* P010D26 *)
    
      VAR
           EXPTABLE : TEXP;
           
           
      PROCEDURE DROPLEVL( VAR CHAREXP:  TWIZLONG;  (* P010D27 *)
                              CURRLEVL: INTEGER;
                              CLASS:    TCLASS);
                         
        BEGIN
          MVCURSOR( 1, 13);
          PRINTSTR( 'HE HAD ');
          PRLONG2( CHAREXP);
          PRINTSTR( ' EP');
        
          CURRLEVL := CURRLEVL - 1;
          IF CURRLEVL = 0 THEN
            FILLCHAR( CHAREXP, 6, 0)
          ELSE
            IF CURRLEVL < 13 THEN
              CHAREXP := EXPTABLE[ CLASS][ CURRLEVL]
            ELSE
              BEGIN
                CHAREXP := EXPTABLE[ CLASS][ 12];
                FOR CHARXXX := 13 TO CURRLEVL DO
                  ADDLONGS( CHAREXP, EXPTABLE[ CLASS][ 0])
              END;
          ADDLONGS( CHAREXP, KILLEXP);
          MVCURSOR( 1, 14);
          PRINTSTR( 'HE HAS ');
          PRLONG2( CHAREXP);
          PRINTSTR( ' EP NOW');
          PAUSE2
        END;  (* DROPLEVL *)
        
        
      BEGIN (* CHKDRAIN *)
        MOVELEFT( IOCACHE[ GETREC( ZEXP, 0, SIZEOF( TEXP))],
                  EXPTABLE,
                  SIZEOF( TEXP));
        KILLEXP.HIGH := 0;
        KILLEXP.MID  := 0;
        KILLEXP.LOW  := 1;
        FOR CHARXXX := 0 TO PARTYCNT - 1 DO
          BEGIN
            IF  BATRESLT.DRAINED[ CHARXXX] THEN
              BEGIN
                CLRRECT( 1, 11, 38, 4);
                MVCURSOR( 1, 11);
                PRINTSTR( CHARACTR[ CHARXXX].NAME);
                PRINTSTR( ' WAS DRAINED!');
                DROPLEVL( CHARACTR[ CHARXXX].EXP,
                          CHARACTR[ CHARXXX].CHARLEV,
                          CHARACTR[ CHARXXX].CLASS)
              END
          END;
        CLRRECT( 1, 11, 38, 4);
        IF XGOTO = XREWARD2 THEN
          EXIT( GIVEEXP);
        FOR CHARXXX := 0 TO PARTYCNT - 1 DO
          IF CHARACTR[ CHARXXX].STATUS = OK THEN
            EXIT( CHKDRAIN);
        XGOTO := XCEMETRY;
        EXIT( REWARDS)
      END;  (* CHKDRAIN *)
      
      
    BEGIN  (* GIVEEXP *)
      MOVELEFT( IOCACHE, BATRESLT, SIZEOF( TBATRSLT));
      CACHEWRI := FALSE;
      CNTALIVE;
      CHKDRAIN;
      CALC1EXP;
      CLRRECT( 13, 1, 26, 4);
      MVCURSOR( 13, 1);
      PRINTSTR( 'FOR KILLING THE MONSTERS');
      MVCURSOR( 13, 2);
      PRINTSTR( 'EACH SURVIVOR GETS ');
      PRLONG2( EXPPERCH);
      MVCURSOR( 13, 3);
      PRINTSTR( 'EXPERIENCE POINTS');
      PAUSE2;
      FOR LLBASE04 := 0 TO PARTYCNT - 1 DO
        IF CHARACTR[ LLBASE04].STATUS = OK THEN
          ADDLONGS( CHARACTR[ LLBASE04].EXP, EXPPERCH)
    END;   (* GIVEEXP *)
  
  
  BEGIN  (* REWARDS *)
    
    CASE XGOTO OF
    
       XREWARD:  BEGIN
                   XGOTO := XRUNNER;
                   GIVEEXP;
                   CHSTGOLD
                 END;
                 
      XREWARD2:  BEGIN
                   GIVEEXP;
                   LLBASE04 := 0;
                   XGOTO := XSCNMSG
                 END
    END
  END;  (* REWARDS *)
  