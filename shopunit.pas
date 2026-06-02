SEGMENT PROCEDURE SHOPS;  (* P010201 *)
  
    PROCEDURE CANT;  (* P010202 *)
    
      VAR
           WHOHELP  : INTEGER;
           UNUSEDXX : INTEGER;
           WHOPAY   : INTEGER;
           WHOHELPX : INTEGER;
           DISABLED : STRING;
           WHO      : TCHAR;
    
      
      PROCEDURE CANTSHOP;  (* P010203 *)
      
      
        PROCEDURE DSP2STR( STR1: STRING; STR2: STRING);  (* P010204 *)
        
          BEGIN
            CENTSTR( CONCAT('** ', STR1, STR2, ' **') );
            EXIT( CANTSHOP)
          END;
          
          
        PROCEDURE WELCOME;  (* P010205 *)
        
          BEGIN
            GOTOXY( 0, 13);
            WRITE( CHR( 11));
            WRITELN( ' WELCOME TO THE TEMPLE OF RADIANT CANT!');
            WRITELN;
            WRITE( 'WHO ARE YOU HELPING ? >');
            GETLINE( DISABLED);
            IF DISABLED = '' THEN
              EXIT( CANT);
            WHOHELPX := 0;
            MOVELEFT( IOCACHE[ GETREC( ZCHAR, WHOHELPX, SIZEOF( TCHAR))],
                      WHO,
                      SIZEOF( TCHAR));
            WHILE (WHOHELPX < SCNTOC.RECPERDK[ ZCHAR]) AND
                  (DISABLED <> WHO.NAME) DO
              BEGIN
                WHOHELPX := WHOHELPX + 1;
                MOVELEFT( IOCACHE[ GETREC( ZCHAR, WHOHELPX, SIZEOF( TCHAR))],
                          WHO,
                          SIZEOF( TCHAR))
              END;
            IF WHOHELPX = SCNTOC.RECPERDK[ ZCHAR] THEN
              DSP2STR( '', 'WHO?');
            
            IF ((WHO.LOSTXYL.LOCATION[ 1] +
                 WHO.LOSTXYL.LOCATION[ 2] +
                 WHO.LOSTXYL.LOCATION[ 3] ) <> 0)
                     OR
                 WHO.INMAZE THEN
              DSP2STR( WHO.NAME, ' IS NOT HERE');
            IF WHO.STATUS = LOST THEN
              DSP2STR( WHO.NAME, ' IS LOST');
            IF WHO.STATUS = OK THEN
              DSP2STR( WHO.NAME, ' IS OK');
            WHOHELP := WHOHELPX
          END;
          
          
        PROCEDURE PAYCANT;  (* P010206 *)
        
          VAR
               PAYAMT : TWIZLONG;
        
        
          PROCEDURE GETPAYER;  (* P010207 *)
          
            BEGIN
              PAYAMT.HIGH := 0;
              PAYAMT.MID := 0;
              CASE WHO.STATUS OF
                PLYZE  : PAYAMT.LOW := 100;
                STONED : PAYAMT.LOW := 200;
                DEAD   : PAYAMT.LOW := 250;
                ASHES  : PAYAMT.LOW := 500;
              END;
              MULTLONG( PAYAMT, WHO.CHARLEV);
              GOTOXY( 0, 17);
              WRITE( CHR( 11));
              WRITE( 'THE DONATION WILL BE ');
              PRNTLONG( PAYAMT);
              WRITELN;
              WHOPAY := GETCHARX( FALSE, 'WHO WILL TITHE');
              IF WHOPAY = -1 THEN
                EXIT( CANTSHOP);
              IF TESTLONG( PAYAMT, CHARACTR[ WHOPAY].GOLD) > 0 THEN
                DSP2STR( '', 'CHEAP APOSTATES! OUT!');
              SUBLONGS( CHARACTR[ WHOPAY].GOLD, PAYAMT)
            END;
            
            
          PROCEDURE DOCANT;  (* P010208 *)
          
          
            PROCEDURE ASHLOST;  (* P010209 *)
            
              BEGIN
                IF WHO.STATUS = DEAD THEN
                  WHO.STATUS := ASHES
                ELSE
                  WHO.STATUS := LOST;
                WHO.INMAZE := FALSE;
                MOVELEFT( WHO,
                          IOCACHE[ GETRECW( ZCHAR, WHOHELP, SIZEOF( TCHAR))],
                          SIZEOF( TCHAR));
                WRITELN;
                IF WHO.STATUS = LOST THEN
                  DSP2STR( WHO.NAME, ' WILL BE BURIED') 
                ELSE
                  DSP2STR( WHO.NAME, ' NEEDS KADORTO NOW')
              END; (* ASHLOST *)
              
              
            BEGIN (* DOCANT *)
              GOTOXY( 0, 17);
              WRITE( CHR( 11));
              WRITE( 'MURMUR - ');
              PAUSE2;
              WRITE( 'CHANT - ');
              PAUSE2;
              WRITE( 'PRAY - ');
              PAUSE2;
              WRITE( 'INVOKE!');
              WRITELN;
              
              IF WHO.STATUS = DEAD THEN
                BEGIN
                  IF (RANDOM MOD 100) > (50 + 3 * WHO.ATTRIB[ VITALITY]) THEN
                    ASHLOST
                  ELSE
                    WHO.HPLEFT := 1
                END
              ELSE IF WHO.STATUS = ASHES THEN
                BEGIN
                  IF (RANDOM MOD 100) > (40 + 3 * WHO.ATTRIB[ VITALITY]) THEN
                    ASHLOST
                  ELSE
                    WHO.HPLEFT := WHO.HPMAX
                END;
                
              WHO.AGE := WHO.AGE + (RANDOM MOD 52) + 1;
              WHO.STATUS := OK;
              MOVELEFT( WHO, 
                        IOCACHE[ GETRECW( ZCHAR, WHOHELP, SIZEOF( TCHAR))],
                        SIZEOF( TCHAR));
              WRITELN;
              DSP2STR( WHO.NAME, ' IS WELL')
            END;
            
            
          BEGIN (* PAYCANT *)
            GETPAYER;
            DOCANT
          END;
          
          
        BEGIN (* CANTSHOP *)
          WELCOME;
          PAYCANT
        END;
        
        
      BEGIN (* CANT *)
        XGOTO := XCASTLE;
        REPEAT
          CANTSHOP
        UNTIL FALSE;
        EXIT( SHOPS)
      END; (* CANT *)
  
  
    PROCEDURE BOLTAC;  (* P01020A *)
    
      VAR
           INVENTX  : INTEGER;
           HALFPRIC : INTEGER;
           OBJECT   : TOBJREC;
           CHARI    : INTEGER;
           UNUSEDXX : ARRAY[ 1..41] OF INTEGER;
           
           
      PROCEDURE DOPLAYER;  (* P01020B *)
      
        CONST
        
        (* ACTION *)
             SELL     = 0;
             UNCURSE  = 1;
             IDENTIFY = 2;
             BUY      = 3;
             POOLGOLD = 4;
             LEAVE    = 5;
      
        VAR
            OBJLIST  : ARRAY[ 1..6] OF INTEGER;
            UNUSEDXX : INTEGER;
            UNUSEDYY : INTEGER;
            POSSCNT  : INTEGER;
      
      
        PROCEDURE DOBUY;  (* P01020C *)
        
          VAR
               NOTPURCH : BOOLEAN;
               SCROLDIR : INTEGER;
               BUYX     : INTEGER;
        
            
          PROCEDURE SCROLPOS;  (* P01020D *)
          
            VAR
                 X : INTEGER;
          
            BEGIN
              INVENTX := OBJLIST[ 6] - 1;
              FOR X := 1 TO 6 DO
                BEGIN
                  GOTOXY( 0, 12 + X);
                  WRITE( CHR( 29));
                  REPEAT
                    INVENTX := INVENTX + 1;
                    IF INVENTX >= SCNTOC.RECPERDK[ ZOBJECT] THEN
                      INVENTX := 1;
                    MOVELEFT( IOCACHE[ GETREC( ZOBJECT,
                                               INVENTX,
                                               SIZEOF( TOBJREC))],
                              OBJECT,
                              SIZEOF( TOBJREC));
                  UNTIL (OBJECT.BOLTACXX <> 0) AND
                        (NOT OBJECT.CURSED);
                  OBJLIST[ X] := INVENTX;
                  WRITE( X : 1);
                  WRITE( ')');
                  WRITE( OBJECT.NAME : 15);
                  WRITE( ' ');
                  PRNTLONG( OBJECT.PRICE);
                  IF NOT OBJECT.CLASSUSE[ CHARACTR[ CHARI].CLASS] THEN
                    WRITE( ' UNUSABLE')
                END
            END;
            
            
          PROCEDURE SCROLNEG;  (* P01020E *)
          
            VAR
                 X : INTEGER;
          
            BEGIN
              INVENTX := OBJLIST[ 1] + 1;
              FOR X := 6 DOWNTO 1 DO
                BEGIN
                  GOTOXY( 0, 12 + X);
                  WRITE( CHR( 29));
                  REPEAT
                    INVENTX := INVENTX - 1;
                    IF INVENTX < 1 THEN
                      INVENTX := SCNTOC.RECPERDK[ ZOBJECT] - 1;
                    MOVELEFT( IOCACHE[ GETREC( ZOBJECT,
                                               INVENTX,
                                               SIZEOF( TOBJREC))],
                              OBJECT,
                              SIZEOF( TOBJREC))
                  UNTIL (OBJECT.BOLTACXX <> 0) AND
                        (NOT OBJECT.CURSED);
                  OBJLIST[ X] := INVENTX;
                  WRITE( X : 1);
                  WRITE( ')');
                  WRITE( OBJECT.NAME : 15);
                  WRITE( ' ');
                  PRNTLONG( OBJECT.PRICE);
                  IF NOT OBJECT.CLASSUSE[ CHARACTR[ CHARI].CLASS] THEN
                    WRITE( ' UNUSABLE')
                END
            END;
          
          
          PROCEDURE PURCHASE;  (* P01020F *)
          
            VAR
                 INSERTX : INTEGER;
          
          
            PROCEDURE AASTRAA( ASTR: STRING);  (* P010210 *)
            
              BEGIN
                CENTSTR( CONCAT( '** ', ASTR, ' **'));
                EXIT( PURCHASE);
              END;
              
              
            BEGIN (* PURCHASE *)
              REPEAT
                NOTPURCH := FALSE;
                GOTOXY( 0, 21);
                WRITELN( CHR( 11));
                WRITE( 'PURCHASE WHICH ITEM ([RETURN] EXITS) ? >');
                GETKEY;
                BUYX := ORD( INCHAR) - ORD( '0');
                IF INCHAR = CHR( CRETURN) THEN
                  EXIT( PURCHASE);
              UNTIL (BUYX > 0) AND (BUYX <= 6);
              
              MOVELEFT( IOCACHE[ GETREC( ZOBJECT,
                                         OBJLIST[ BUYX],
                                         SIZEOF( TOBJREC))],
                        OBJECT,
                        SIZEOF( TOBJREC));
                        
              IF OBJECT.BOLTACXX = 0 THEN
                AASTRAA( 'YOU BOUGHT THE LAST ONE')
              ELSE IF CHARACTR[ CHARI].POSS.POSSCNT = 8 THEN
                AASTRAA( 'YOU CANT CARRY ANYTHING MORE')
              ELSE IF TESTLONG( CHARACTR[ CHARI].GOLD, OBJECT.PRICE) < 0 THEN
                AASTRAA( 'YOU CANNOT AFFORD IT');
                
              IF NOT (OBJECT.CLASSUSE[ CHARACTR[ CHARI].CLASS]) THEN
                BEGIN
                  GOTOXY( 0, 22);
                  WRITE( CHR( 11));
                  WRITE( 'UNUSABLE ITEM - CONFIRM BUY (Y/N) ? >');
                  REPEAT
                    GETKEY
                  UNTIL (INCHAR = 'Y') OR (INCHAR = 'N');
                  IF INCHAR = 'N' THEN
                    AASTRAA( 'WE ALL MAKE MISTAKES')
                END
              ELSE
                INCHAR := ' ';
              SUBLONGS( CHARACTR[ CHARI].GOLD, OBJECT.PRICE);
              INSERTX := CHARACTR[ CHARI].POSS.POSSCNT + 1;
              
              WITH CHARACTR[ CHARI].POSS.POSSESS[ INSERTX] DO
                BEGIN
                  EQUIPED := FALSE;
                  IDENTIF := TRUE;
                  CURSED  := FALSE;
                  EQINDEX := OBJLIST[ BUYX];
                END;
              CHARACTR[ CHARI].POSS.POSSCNT := INSERTX;
              IF OBJECT.BOLTACXX > 0 THEN
                OBJECT.BOLTACXX := OBJECT.BOLTACXX - 1;
              MOVELEFT( OBJECT,
                        IOCACHE[ GETRECW( ZOBJECT,
                                          OBJLIST[ BUYX],
                                          SIZEOF( TOBJREC))],
                        SIZEOF( TOBJREC));
              IF ORD( INCHAR) = ORD( 'Y') THEN
                AASTRAA( 'ITS YOUR MONEY')
              ELSE
                AASTRAA( 'JUST WHAT YOU NEEDED')
            END; (* PURCHASE *)
            
            
          BEGIN (* DOBUY *)
            INVENTX := 1;
            NOTPURCH := TRUE;
            OBJLIST[ 1] := 1;
            OBJLIST[ 6] := 1;
            SCROLDIR := 1;
            GOTOXY( 0, 13);
            WRITE( CHR(11));
            REPEAT
              IF NOTPURCH THEN
                IF SCROLDIR = 1 THEN
                  SCROLPOS
                ELSE
                  SCROLNEG;
              NOTPURCH := TRUE;
              SCROLDIR := 1;
              GOTOXY(  0, 20);
              WRITE( CHR( 11));
              WRITE( 'YOU HAVE ');
              PRNTLONG( CHARACTR[ CHARI].GOLD);
              WRITELN( ' GOLD');
              WRITELN( 'YOU MAY P)URCHASE, SCROLL');
              WRITE( ' ' :8);
              WRITELN( 'F)ORWARD OR B)ACK, GO TO THE');
              WRITE( ' ' :8);
              WRITE( 'S)TART, OR L)EAVE');
              GOTOXY( 41, 0);
              REPEAT
                GETKEY
              UNTIL (INCHAR = 'P') OR (INCHAR = 'F') OR
                    (INCHAR = 'B') OR (INCHAR = 'S') OR
                    (INCHAR = 'L');
              
              CASE INCHAR OF
                'P': PURCHASE;
                'S': OBJLIST[ 6] := 1;
                'B': SCROLDIR := - 1;
              END
            UNTIL INCHAR = 'L'
          END;
          
          
        PROCEDURE SELLIDUN( ACTION: INTEGER);  (* P010211 *)
        
          VAR
               UNUSEDXX : ARRAY[ 1..3] OF INTEGER;
               TRANOBJX : INTEGER;
        
        
          PROCEDURE LISTPOSS;  (* P010212 *)
          
            BEGIN
              GOTOXY( 0, 13);
              WRITE( CHR( 11));
              POSSCNT := CHARACTR[ CHARI].POSS.POSSCNT;
              FOR TRANOBJX := 1 TO POSSCNT DO
                BEGIN
                  OBJLIST[ TRANOBJX] :=
                    CHARACTR[ CHARI].POSS.POSSESS[ TRANOBJX].EQINDEX;
                  MOVELEFT( IOCACHE[ GETREC( ZOBJECT,
                                             OBJLIST[ TRANOBJX],
                                             SIZEOF( TOBJREC))],
                            OBJECT,
                            SIZEOF( TOBJREC));
                  WRITE( TRANOBJX : 1);
                  WRITE( CHR( 41));
                  IF CHARACTR[ CHARI].POSS.POSSESS[ TRANOBJX].IDENTIF THEN
                    WRITE( OBJECT.NAME : 15)
                  ELSE
                    WRITE( OBJECT.NAMEUNK : 15);
                  WRITE( ' ');
                  DIVLONG( OBJECT.PRICE, HALFPRIC);
                  IF ACTION = SELL THEN
                    BEGIN
                      IF NOT (CHARACTR[ CHARI].POSS.POSSESS[ TRANOBJX].IDENTIF)
                      THEN
                        BEGIN
                          OBJECT.PRICE.HIGH := 0;
                          OBJECT.PRICE.MID  := 0;
                          OBJECT.PRICE.LOW  := 1
                        END
                    END;
                  PRNTLONG(  OBJECT.PRICE);
                  WRITELN
                END
            END;
            
            
          PROCEDURE TRANSACT;  (* P010213 *)
          
            VAR
                 POSSX : INTEGER;
          
          
            PROCEDURE AASTRAA( ASTR: STRING);  (* P010214 *)
            
              BEGIN
                CENTSTR( ASTR);
                EXIT( TRANSACT)
              END;
              
              
            BEGIN (* TRANSACT *)
              MOVELEFT( IOCACHE[ GETREC( ZOBJECT,
                                         OBJLIST[ TRANOBJX],
                                         SIZEOF( TOBJREC))],
                        OBJECT,
                        SIZEOF( TOBJREC));
              DIVLONG( OBJECT.PRICE, HALFPRIC);
              IF ACTION = SELL THEN
                BEGIN
                  IF NOT CHARACTR[ CHARI].POSS.POSSESS[ TRANOBJX].IDENTIF THEN
                    BEGIN
                      OBJECT.PRICE.HIGH := 0;
                      OBJECT.PRICE.MID  := 0;
                      OBJECT.PRICE.LOW  := 1
                    END;
                  IF CHARACTR[ CHARI].POSS.POSSESS[ TRANOBJX].CURSED THEN
                    AASTRAA( '** WE DONT BUY CURSED ITEMS **')
                END
              ELSE
                BEGIN
                  IF NOT (CHARACTR[ CHARI].POSS.POSSESS[ TRANOBJX].CURSED) AND
                     (ACTION = UNCURSE) THEN
                    AASTRAA( '** THAT IS NOT A CURSED ITEM **');
                    
                  IF CHARACTR[ CHARI].POSS.POSSESS[ TRANOBJX].IDENTIF AND
                      (ACTION = IDENTIFY) THEN
                    AASTRAA( '** THAT HAS BEEN IDENTIFIED **');
                    
                  IF TESTLONG( CHARACTR[ CHARI].GOLD, OBJECT.PRICE) < 0 THEN
                    AASTRAA( '** YOU CANT AFFORD THE FEE **');
                END;
              
              IF ACTION = SELL THEN
                ADDLONGS( CHARACTR[ CHARI].GOLD, OBJECT.PRICE)
              ELSE
                SUBLONGS( CHARACTR[ CHARI].GOLD, OBJECT.PRICE);
                
              IF ACTION = IDENTIFY THEN
                CHARACTR[ CHARI].POSS.POSSESS[ TRANOBJX].IDENTIF := TRUE
              ELSE
                BEGIN
                  IF TRANOBJX < CHARACTR[ CHARI].POSS.POSSCNT THEN
                    FOR POSSX := (TRANOBJX + 1) TO
                                   CHARACTR[ CHARI].POSS.POSSCNT DO
                      CHARACTR[ CHARI].POSS.POSSESS[ POSSX - 1] :=
                        CHARACTR[ CHARI].POSS.POSSESS[ POSSX];
                        
                  CHARACTR[ CHARI].POSS.POSSCNT :=
                                             CHARACTR[ CHARI].POSS.POSSCNT - 1;
                  MOVELEFT( IOCACHE[ GETREC( ZOBJECT,
                                             OBJLIST[ TRANOBJX],
                                             SIZEOF( TOBJREC))],
                            OBJECT,
                            SIZEOF( TOBJREC));
                  IF ACTION = SELL THEN
                    IF OBJECT.BOLTACXX > - 1 THEN
                      OBJECT.BOLTACXX := OBJECT.BOLTACXX + 1;
                    
                  MOVELEFT( OBJECT,
                            IOCACHE[ GETRECW( ZOBJECT,
                                              OBJLIST[ TRANOBJX],
                                              SIZEOF( TOBJREC))],
                            SIZEOF( TOBJREC));
                END;
                
              CENTSTR( '** ANYTHING ELSE, SIRE? **');
              LISTPOSS
            END; (* TRANSACT *)
            
            
          BEGIN (* SELLIDUN *)
            LISTPOSS;
            REPEAT
              IF POSSCNT = 0 THEN
                EXIT( SELLIDUN);
              GOTOXY(  0, 22);
              IF ACTION = SELL THEN
                BEGIN
                  WRITE( CHR( 11));
                  WRITE( 'WHICH DO YOU WISH TO SELL ? >')
                END
              ELSE IF ACTION = UNCURSE THEN
                BEGIN
                  WRITE( CHR( 11));
                  WRITE( 'WHICH DO YOU WISH UNCURSED ? >')
                END
              ELSE
                BEGIN
                  WRITE( CHR( 11));
                  WRITE( 'WHICH DO YOU WISH IDENTIFIED ? >')
                END;
              GETKEY;
              IF ORD( INCHAR) = CRETURN THEN
                EXIT( SELLIDUN);
              TRANOBJX := ORD( INCHAR) - ORD( '0');
              IF (TRANOBJX > 0) AND (TRANOBJX <= POSSCNT) THEN
                TRANSACT
            UNTIL FALSE
          END;
          
          
        BEGIN (* DOPLAYER *)
          REPEAT
            GOTOXY( 0, 13);
            WRITE( CHR( 11));
            WRITE( '      WELCOME ');
            WRITE(  CHARACTR[ CHARI].NAME);
            WRITELN;
            WRITE( '     YOU HAVE ');
            PRNTLONG( CHARACTR[ CHARI].GOLD);
            WRITELN( ' GOLD');
            WRITELN;
            WRITELN( 'YOU MAY B)UY  AN ITEM,');
            WRITELN( '        S)ELL AN ITEM, HAVE AN ITEM');
            WRITELN( '        U)NCURSED,  OR HAVE AN ITEM');
            WRITELN( '        I)DENTIFIED, OR L)EAVE');
            GOTOXY( 41, 0);
            GETKEY;
                           
            CASE INCHAR OF
              'U': SELLIDUN( UNCURSE);
              'I': SELLIDUN( IDENTIFY);
              'S': SELLIDUN( SELL);
              'B': DOBUY;
              'L': EXIT( DOPLAYER);
            END
          UNTIL FALSE
        END; (* DOPLAYER *)
        
        
      BEGIN (* BOLTAC *)
        HALFPRIC := 2;
        XGOTO := XCASTLE;
        REPEAT
          GOTOXY( 0, 13);
          WRITE( CHR( 11));
          WRITE( '       WELCOME TO THE TRADING POST');
          WRITELN;
          CHARI := GETCHARX( FALSE, 'WHO WILL ENTER');
          IF CHARI = -1 THEN
            EXIT( SHOPS);
          
          IF (CHARI < PARTYCNT) THEN
            DOPLAYER
        UNTIL FALSE
      END;


    PROCEDURE CEMETARY;  (* P010215 *)
    
      VAR
           TWO : INTEGER;
           
           
      PROCEDURE TOMBSTON( CHARI: INTEGER);  (* P010216 *)
      
        VAR
            TOMBY : INTEGER;
            TOMBX : INTEGER;
        
        
        PROCEDURE DSPTOMBL( TOMBCHRS: STRING);  (* P010217 *)
          
          BEGIN
            MVCURSOR( TOMBX, TOMBY);
            PRINTSTR( TOMBCHRS);
            TOMBY := TOMBY + 1
          END;
          
          
        BEGIN  (* TOMBSTON *)
          TOMBX := 20 * (CHARI MOD 2);
          TOMBY :=  6 * (CHARI DIV 2);
          UNITREAD( DRIVE1, CHARSET, BLOCKSZ, SCNTOCBL + 2, 0);
          MVCURSOR( TOMBX, TOMBY);
          
          DSPTOMBL( '+,-.');  (*  CHR(43)  CHR(44)  CHR(45)  CHR(46)  *)
          DSPTOMBL( '/012');  (*  CHR(47)  CHR(48)  CHR(49)  CHR(50)  *)  
          DSPTOMBL( '3456');  (*  CHR(51)  CHR(52)  CHR(53)  CHR(54)  *)
          DSPTOMBL( '789:');  (*  CHR(55)  CHR(56)  CHR(57)  CHR(58)  *)
          DSPTOMBL( ';<=>');  (*  CHR(59)  CHR(60)  CHR(61)  CHR(62)  *)
          DSPTOMBL( '?XYZ');  (*  CHR(63)  CHR(88)  CHR(89)  CHR(90)  *)
                              (* NOTE LAST LINE JUMPS TO XYZ *)
                              
          UNITREAD( DRIVE1, CHARSET, BLOCKSZ, SCNTOCBL + 1, 0);
          MVCURSOR( TOMBX + 1, TOMBY - 2);
          PRINTNUM( CHARACTR[ CHARI].AGE DIV 52, 2);
          MVCURSOR( TOMBX + 4, TOMBY - 4);
          PRINTSTR( CHARACTR[ CHARI].NAME)
        END;  (* TOMBSTON *)
        
        
      PROCEDURE BADSTUFF;  (* P010218 *)
      
      
        PROCEDURE BREAKPOS;  (* P010219 *)
        
          VAR
               X     : INTEGER;
               POSSX : INTEGER;
        
          BEGIN
            WITH CHARACTR[ LLBASE04] DO
              BEGIN
                FOR POSSX := 1 TO POSS.POSSCNT DO
                  IF NOT POSS.POSSESS[ POSSX].CURSED THEN
                    IF (RANDOM MOD 21 > ATTRIB[ LUCK]) THEN
                      POSS.POSSESS[ POSSX].EQINDEX := 0;
                X := 0;
                FOR POSSX := 1 TO POSS.POSSCNT DO
                  IF POSS.POSSESS[ POSSX].EQINDEX <> 0 THEN
                    BEGIN
                      X := X + 1;
                      POSS.POSSESS[ X] := POSS.POSSESS[ POSSX]
                    END;
                POSS.POSSCNT := X
            END
          END;
          
          
        BEGIN (* BADSTUFF *)
          TWO := 2;
          FOR LLBASE04 := 0 TO PARTYCNT - 1 DO
            BEGIN
              IF CHARACTR[ LLBASE04].STATUS <> LOST THEN
                BEGIN
                  WITH CHARACTR[ LLBASE04] DO
                    BEGIN
                      IF STATUS < DEAD THEN
                        STATUS := DEAD;
                      INMAZE := FALSE;
                      DIVLONG( GOLD, TWO);
                      BREAKPOS;
                      IF (RANDOM MOD 50) < MAZELEV THEN
                        BEGIN
                          LOSTXYL.LOCATION[ 1] := -1;
                          LOSTXYL.LOCATION[ 2] := -1;
                          LOSTXYL.LOCATION[ 3] := -1
                        END
                      ELSE
                        BEGIN
                          LOSTXYL.LOCATION[ 1] := MAZEX;
                          LOSTXYL.LOCATION[ 2] := MAZEY;
                          LOSTXYL.LOCATION[ 3] := MAZELEV
                        END;
                      MOVELEFT( CHARACTR[ LLBASE04],
                                IOCACHE[ GETRECW( ZCHAR,
                                                  CHARDISK[ LLBASE04],
                                                  SIZEOF( TCHAR))],
                                SIZEOF( TCHAR))
                    END
                END
            END;  (* END FOR *)
            
          MOVELEFT( IOCACHE[ GETREC(  ZZERO, 0, SIZEOF( TSCNTOC))],
                    SCNTOC,
                    SIZEOF( TSCNTOC))
        END;
        
        
      BEGIN (* CEMETARY *)
        BADSTUFF;
        CLRRECT( 0, 0, 40, 24);
        GRAPHICS;
        FOR LLBASE04 := 0 TO PARTYCNT - 1 DO
          TOMBSTON( LLBASE04);
        UNITREAD( DRIVE1, CHARSET, BLOCKSZ, SCNTOCBL + 2, 0);
        MVCURSOR( 0, 19);
        PRINTCHR( CHR(33));         (* UPPER LEFT CORNER  *)
        FOR LLBASE04 := 1 TO 38 DO
          PRINTCHR( CHR(34));       (* HORIZONTAL LINE    *)
        PRINTCHR( CHR(35));         (* UPPER RIGHT CORNER *)
        MVCURSOR( 0, 20);
        PRINTCHR( CHR(36));         (* VERTICAL BAR       *)
        MVCURSOR( 39, 20);
        PRINTCHR( CHR(36));
        MVCURSOR( 0, 21);
        PRINTCHR( CHR(39));
        FOR LLBASE04 := 1 TO 38 DO
          PRINTCHR( CHR(34));
        PRINTCHR( CHR(40));
        MVCURSOR( 0, 22);
        PRINTCHR( CHR(36));
        MVCURSOR( 39, 22);
        PRINTCHR( CHR(36));
        MVCURSOR( 0, 23);
        PRINTCHR( CHR(37));
        FOR LLBASE04 := 1 TO 38 DO
          PRINTCHR( CHR(34));
        PRINTCHR( CHR(38));
        UNITREAD( DRIVE1, CHARSET, BLOCKSZ, SCNTOCBL + 1, 0);
        MVCURSOR( 1, 20);
        PRINTSTR( 'YOUR ENTIRE PARTY HAS BEEN SLAUGHTERED');
        MVCURSOR( 1, 22);
        PRINTSTR( '  PRESS RETURN TO LEAVE THE CEMETERY  ');
        PARTYCNT := 0;
        REPEAT
          GETKEY
        UNTIL INCHAR = CHR( CRETURN);
        WRITE( CHR( 12));
        GOTOXY( 41, 0);
        LLBASE04 := -2;
        XGOTO := XSCNMSG;
        EXIT( SHOPS)
      END;
  
  
    PROCEDURE EDGETOWN;  (* P01021A *)
    
    
      PROCEDURE ENTMAZE;  (* P01021B *)
      
        VAR
             X : INTEGER;
      
        BEGIN
          GOTOXY( 0, 13);
          WRITELN( CHR(11));
          WRITELN( 'ENTERING' :24);
          WRITELN( SCNTOC.GAMENAME : 20 + LENGTH( SCNTOC.GAMENAME) DIV 2);
          GOTOXY( 41, 0);
          XGOTO := XNEWMAZE;
          MAZEX    :=  0;
          MAZEY    :=  0;
          MAZELEV  := -1;
          DIRECTIO :=  0;
          EXIT( SHOPS)
        END;
        
        
      PROCEDURE UPDCHARS;  (* P01021C *)
      
        VAR
             X : INTEGER;
      
        BEGIN
          FOR X := 0 TO PARTYCNT - 1 DO
            BEGIN
              CHARACTR[ X].INMAZE := FALSE;
              MOVELEFT( CHARACTR[ X],
                        IOCACHE[ GETRECW( ZCHAR,
                                          CHARDISK[ X],
                                          SIZEOF( TCHAR))],
                        SIZEOF( TCHAR));
            END;
          PARTYCNT := 0;
          MOVELEFT( IOCACHE[ GETREC( ZZERO, 0, SIZEOF( TSCNTOC))],
                    X,
                    2);
          EXIT( SHOPS)
        END;  (* UPDCHARS *)
        
        
      BEGIN (* EDGETOWN *)
        GOTOXY( 0, 13);
        IF PARTYCNT = 0 THEN
          BEGIN
            WRITE( CHR( 11));
            WRITELN( 'YOU MAY GO TO THE T)RAINING GROUNDS,');
            WRITELN( 'RETURN TO THE C)ASTLE, OR L)EAVE THE');
            WRITELN( 'GAME.') 
          END
        ELSE
          BEGIN
            WRITE( CHR( 11));
            WRITELN( 'YOU MAY ENTER THE M)AZE, THE T)RAINING');
            WRITELN( 'GROUNDS, C)ASTLE,  OR L)EAVE THE GAME.')
          END;
        REPEAT
          GOTOXY( 41, 0);
          GETKEY
        UNTIL (INCHAR = 'T') OR (INCHAR = 'C') OR (INCHAR = 'L') OR
              ((INCHAR = 'M') AND (PARTYCNT > 0));
          
        IF INCHAR = 'M' THEN
          ENTMAZE
        ELSE IF INCHAR = 'T' THEN
          BEGIN
            XGOTO := XTRAININ;
            UPDCHARS
          END
        ELSE IF INCHAR = 'L' THEN
          BEGIN
            XGOTO := XDONE;
            UPDCHARS
          END
        ELSE
          BEGIN
            XGOTO := XCASTLE;
            EXIT( SHOPS)
          END
      END;
  
  
    PROCEDURE CHK4WIN;  (* P01021D *)
    
      VAR
          POSSI    : INTEGER;   (* MULTIPLE USES *)
          CHARX    : INTEGER;
          THISCHAR : TCHAR;
          WONGAME  : BOOLEAN;
          
          
      PROCEDURE CONGRATS;  (* P01021E *)
    
        VAR
             EXPBONUS : TWIZLONG;
             AWARDOVR : PACKED ARRAY[ 0..15] OF BOOLEAN;
      
        BEGIN
          EXPBONUS.HIGH := 0;
          EXPBONUS.LOW  := 0;
          EXPBONUS.MID  := 25;
          FOR CHARX := 0 TO PARTYCNT - 1 DO
            BEGIN
              CHARACTR[ CHARX].POSS.POSSCNT := 0;
              CHARACTR[ CHARX].GOLD.HIGH := 0;
              CHARACTR[ CHARX].GOLD.MID  := 0;
              ADDLONGS( CHARACTR[ CHARX].EXP, EXPBONUS);
              MOVELEFT( CHARACTR[ CHARX].LOSTXYL.AWARDS[ 4], AWARDOVR, 2);
              AWARDOVR[ 0] := TRUE;
              MOVELEFT( AWARDOVR, CHARACTR[ CHARX].LOSTXYL.AWARDS[ 4], 2)
            END;
          WRITE( CHR( 12));
          WRITELN( '*** CONGRATULATIONS ***' : 32);
          TEXTMODE;
          WRITELN;
          WRITELN( 'YOU HAVE COMPLETED YOUR QUEST AND THE');
          WRITELN( 'AMULET IS NOW BACK IN THE HANDS OF');
          WRITELN( 'YOUR BENIFICENT RULER, TREBOR.');
          WRITELN;
          WRITELN( 'IN RETURN FOR THIS, HE GRANTS YOU A');
          WRITELN( 'BOON OF 250,000 EXPERIENCE POINTS');
          WRITELN( 'EACH!');
          WRITELN;
          WRITELN( 'ADDITIONALLY, YOU WILL BE INITIATED');
          WRITELN( 'INTO THE OVERLORD''S HONOR GUARD AND');
          WRITELN( 'THUS WILL BE ENTITLED TO WEAR THE');
          WRITELN( 'CHEVRON (>) OF THIS RANK EVERMORE.');
          WRITELN;
          WRITELN( 'HOWEVER, YOU MUST GIVE UP ALL YOUR');
          WRITELN( 'EQUIPMENT AND MOST OF YOUR MONEY TO');
          WRITELN( 'PAY FOR YOUR INITIATION.');
          WRITELN;
          WRITELN( 'PRESS [RETURN], HONORED ONES');
          GOTOXY( 41, 0);
          READLN( INPUT);
          WRITE( CHR( 12))
        END;
        
        
      BEGIN (* CHK4WIN *)
        WONGAME := FALSE;
        FOR CHARX := 0 TO PARTYCNT -1 DO
          BEGIN
            FOR POSSI := 1 TO CHARACTR[ CHARX].POSS.POSSCNT DO
              IF CHARACTR[ CHARX].POSS.POSSESS[ POSSI].EQINDEX = 94 THEN
                WONGAME := TRUE;
            CHARACTR[ CHARX].LOSTXYL.LOCATION[ 1] := 0;
            CHARACTR[ CHARX].LOSTXYL.LOCATION[ 2] := 0;
            CHARACTR[ CHARX].LOSTXYL.LOCATION[ 3] := 0
          END;
        IF WONGAME THEN
          CONGRATS;
        FOR CHARX := 0 TO PARTYCNT - 1 DO
          BEGIN
            CHARACTR[ CHARX].INMAZE :=
              CHARACTR[ CHARX].STATUS = OK;
            MOVELEFT( CHARACTR[ CHARX],
                      IOCACHE[ GETRECW( ZCHAR,
                                        CHARDISK[ CHARX],
                                        SIZEOF( TCHAR))],
                      SIZEOF( TCHAR))
          END;
          
        MOVELEFT( IOCACHE[ GETREC( ZZERO, 0, SIZEOF( TSCNTOC))],
                  CHARX,
                  2);
        CHARX := 0;
        POSSI := 0;
        WHILE CHARX < PARTYCNT DO
          BEGIN
            CHARACTR[ POSSI] := CHARACTR[ CHARX];
            CHARDISK[ POSSI] := CHARDISK[ CHARX];
            IF CHARACTR[ POSSI].STATUS = OK THEN
              POSSI := POSSI + 1;
            CHARX := CHARX + 1
          END;
        PARTYCNT := POSSI;
        XGOTO := XCASTLE;
        EXIT( SHOPS)
    END;  (* CHK4WIN *)
  
  
    BEGIN (* SHOPS *)
    
      CASE XGOTO OF
        XCEMETRY:  CEMETARY;
           XCANT:  CANT;
         XBOLTAC:  BOLTAC;
        XCHK4WIN:  CHK4WIN;
        XEDGTOWN:  EDGETOWN;
      END;
      
    END;  (* SHOPS *)