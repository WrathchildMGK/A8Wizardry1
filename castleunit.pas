  SEGMENT PROCEDURE CASTLE;     (* P010A01 *)
  
    TYPE
         BYTE = PACKED ARRAY[ 0..1] OF 0..255;
         
    VAR
         CPCALLED : RECORD CASE INTEGER OF  (* COPY PROTECTION CALLED *)
           1: (I: INTEGER);
           2: (P: ^BYTE);
         END;
      
      
    PROCEDURE GETPASS( VAR PASSWORD: STRING);  (* P010A02 *)
                        
      VAR
           UNUSEDXX : INTEGER;
           RANDX    : INTEGER;
           CHRCNT   : INTEGER;
                        
      BEGIN
        CHRCNT := 0;
        REPEAT
          GETKEY;
          IF INCHAR <> CHR( CRETURN) THEN
            IF CHRCNT < 15 THEN
              BEGIN
                FOR RANDX := 0 TO (RANDOM MOD 2) DO
                  WRITE( CHR( 88));
                CHRCNT := CHRCNT + 1;
                PASSWORD[ CHRCNT] := INCHAR
              END
            ELSE
              WRITE( CHR(7))
        UNTIL INCHAR = CHR( CRETURN);
        WRITELN;
        PASSWORD[ 0] := CHR( CHRCNT)
      END;  (* GETPASS *)
      
      
    PROCEDURE CHARINFO( CHARX: INTEGER);  (* P010A03 *)
    
      BEGIN
        GOTOXY( 0, 5 + CHARX);
        WRITE( CHR( 29));      (* ??? *)
        WRITE( (CHARX + 1): 2);
        WRITE( ' ');
        WRITE( CHARACTR[ CHARX].NAME);
        GOTOXY( 19, 5 + CHARX);
        WRITE( COPY( SCNTOC.ALIGN[ CHARACTR[ CHARX].ALIGN], 1, 1));
        WRITE( '-');
        WRITE( COPY( SCNTOC.CLASS[ CHARACTR[ CHARX].CLASS], 1, 3));
        WRITE( ' ');
        IF CHARACTR[ CHARX].ARMORCL > - 10 THEN
          WRITE( CHARACTR[ CHARX].ARMORCL :2)
        ELSE
          WRITE( 'LO');
        WRITE( CHARACTR[ CHARX].HPLEFT :5);
        WRITE( ' ');
        IF CHARACTR[ CHARX].STATUS = OK THEN
          IF CHARACTR[ CHARX].LOSTXYL.POISNAMT[ 1] <> 0 THEN
            WRITELN( 'POISON')
          ELSE
            WRITELN( CHARACTR[ CHARX].HPMAX :4)
        ELSE
          WRITELN( SCNTOC.STATUS[ CHARACTR[ CHARX].STATUS])
      END;
      
      
    PROCEDURE DSPTITLE( TITLESTR: STRING); (* P010A04 *)
    
      BEGIN
        IF CPCALLED.P^[ 0] <> 10 THEN
          MVCURSOR( 70, 0);  (* CRASH AND BURN *)
        GOTOXY( 0, 1);
        WRITE( '! CASTLE');
        WRITE( TITLESTR :30);
        WRITE( ' !')
      END;
      
      
    PROCEDURE DSPPARTY( TITLE : STRING);  (* P010A05 *)
    
      VAR
           CHARX : INTEGER;
    
      BEGIN
        GOTOXY( 0, 0);
        WRITELN( '+--------------------------------------+');
        DSPTITLE( TITLE);
        WRITELN;
        WRITELN( '+----------- CURRENT PARTY: -----------+');
        WRITELN;
        WRITELN( ' # CHARACTER NAME  CLASS AC HITS STATUS' );
        
        FOR CHARX := 0 TO 5 DO
          IF CHARX < PARTYCNT THEN
            CHARINFO( CHARX)
          ELSE
            WRITELN( CHR( 29));
        WRITELN( '+--------------------------------------+');
        WRITE( CHR( 11))
      END;  (* DSPPARTY *)
      
      
    PROCEDURE GILGAMSH;  (*  P010A06 *)
    
      VAR
           PRTYALGN : TALIGN;
    
    
      PROCEDURE GETALIGN;  (* P010A07 *)
      
        BEGIN
          PRTYALGN := NEUTRAL;
          FOR LLBASE04 := 0 TO PARTYCNT - 1 DO
            IF CHARACTR[ LLBASE04].ALIGN <> NEUTRAL THEN
              PRTYALGN := CHARACTR[ LLBASE04].ALIGN
        END;  (* GETALIGN *)
        
        
      PROCEDURE GILGMENU;  (* P010A08 *)
      
        VAR
             UNUSED : INTEGER;
      
      
        BEGIN (* P010A08 *)
          GOTOXY( 0, 13);
          WRITE( CHR( 11));
          WRITE( 'YOU MAY ');
          IF PARTYCNT < 6 THEN
            BEGIN
              WRITE( 'A)DD A MEMBER');
              IF PARTYCNT = 0 THEN
                WRITELN
              ELSE
                WRITELN( ',');
              WRITE( ' ' :8);
            END;
          IF PARTYCNT > 0 THEN
            BEGIN
              WRITELN( 'R)EMOVE A MEMBER,');
              WRITE( ' ' :8);
              WRITELN( '#) SEE A MEMBER,')
            END
          ELSE
            BEGIN
              WRITELN( CHR( 29));
              WRITELN( CHR( 29))
            END;
          WRITELN;
          WRITELN( 'OR PRESS [RETURN] TO LEAVE');
          WRITE( CHR(11))
        END;  (* P010A08 *)
        
        
      PROCEDURE ADDPARTY;  (* P010A09 *)
      
        VAR
             CHARI    : INTEGER;
             CHARNAME : STRING;  (* MULTIPLE USES *)
             

        PROCEDURE EXITADDP( EXITSTR: STRING);  (* P010A09 *)
        
          BEGIN
            CENTSTR( EXITSTR);
            EXIT( ADDPARTY)
          END;  (* EXITADDP *)
          
          
        BEGIN (* ADDPARTY *)
          GOTOXY( 0, 19);
          WRITE( 'WHO WILL JOIN ? >');
          GETLINE( CHARNAME);
          IF (CHARNAME = '') OR (LENGTH( CHARNAME) > 15) THEN
            EXIT( ADDPARTY);
          CHARI := 0;
          MOVELEFT( IOCACHE[ GETREC( ZCHAR, CHARI, SIZEOF( TCHAR))],
                    CHARACTR[ PARTYCNT],
                    SIZEOF( TCHAR));
          WHILE (CHARI < SCNTOC.RECPERDK[ ZCHAR]) AND
                ( (CHARNAME <> CHARACTR[ PARTYCNT].NAME) OR
                  (CHARACTR[ PARTYCNT].STATUS = LOST) ) DO
            BEGIN
              CHARI := CHARI + 1;
              MOVELEFT( IOCACHE[ GETREC( ZCHAR, CHARI, SIZEOF( TCHAR))],
                        CHARACTR[ PARTYCNT],
                        SIZEOF( TCHAR))
            END;
          IF CHARI = SCNTOC.RECPERDK[ ZCHAR] THEN
            EXITADDP( '** WHO? **')
          ELSE
            IF CHARACTR[ PARTYCNT].INMAZE OR
               (CHARACTR[ PARTYCNT].LOSTXYL.LOCATION[ 3] <> 0) THEN
              EXITADDP( '** OUT **')
            ELSE
              IF (PRTYALGN <> NEUTRAL) THEN
                IF (CHARACTR[ PARTYCNT].ALIGN <> NEUTRAL) THEN
                  IF (PRTYALGN <> CHARACTR[ PARTYCNT].ALIGN) THEN
                    EXITADDP( '** BAD ALIGNMENT **');
          GOTOXY( 0, 20);
          WRITE( 'ENTER PASSWORD  >');
          GETPASS(  CHARNAME);
          GOTOXY( 0, 21);
          IF CHARNAME <> CHARACTR[ PARTYCNT].PASSWORD THEN
            EXITADDP( '** THATS NOT IT **');
          CHARDISK[ PARTYCNT] := CHARI;
          CHARACTR[ PARTYCNT].INMAZE := TRUE;
          MOVELEFT( CHARACTR[ PARTYCNT],
                    IOCACHE[ GETRECW( ZCHAR, CHARI, SIZEOF( TCHAR))],
                    SIZEOF( TCHAR));
          IF IORESULT > 0 THEN
            EXITADDP( '** WRITE-PROTECT CHEAT! **');
          PARTYCNT := PARTYCNT + 1;
          GETALIGN;
          MOVELEFT( IOCACHE[ GETREC( ZZERO, 0, SIZEOF( TSCNTOC))],
                    SCNTOC,
                    SIZEOF( TSCNTOC));
          CHARINFO( PARTYCNT - 1);
        END;  (* ADDPARTY *)
        
        
      PROCEDURE REMOVE;  (* P010A0B *)
      
        VAR
             CHARX : INTEGER;
             CHARI : INTEGER;
      
        BEGIN
          CHARI := GETCHARX( FALSE, 'WHO WILL LEAVE');
          IF (CHARI < 0) OR (CHARI = PARTYCNT) THEN
            EXIT( REMOVE);
          CHARACTR[ CHARI].INMAZE := FALSE;
          MOVELEFT( CHARACTR[ CHARI],
                    IOCACHE[ GETRECW( ZCHAR,
                                      CHARDISK[ CHARI],
                                      SIZEOF( TCHAR))],
                    SIZEOF( TCHAR));
          IF CHARI <> (PARTYCNT - 1) THEN
            FOR CHARX := (CHARI + 1) TO (PARTYCNT - 1) DO
              BEGIN
                CHARACTR[ CHARX - 1] := CHARACTR[ CHARX];
                CHARDISK[ CHARX - 1] := CHARDISK[ CHARX]
              END;
          PARTYCNT := PARTYCNT - 1;
          GETALIGN;
          DSPPARTY( 'TAVERN')
        END;   (* REMOVE *)
        
        
      PROCEDURE EXITCASL;  (* P010A0C *)
      
        VAR
             UNUSEDX : INTEGER;
             
        BEGIN
          LLBASE04 := ORD( INCHAR) - ORD( '1');
          IF (LLBASE04 < 0) OR (LLBASE04 >= PARTYCNT) THEN
            EXIT( EXITCASL);
          MAZELEV := -1;
          XGOTO := XINSPECT;
          EXIT( CASTLE)
        END;
        
        
      BEGIN  (* GILGAMSH *)
        GETALIGN;
        DSPTITLE( 'TAVERN');
        REPEAT
          UNITCLEAR( 1);
          GILGMENU;
          GOTOXY( 41, 0);
          GETKEY;
          IF INCHAR = CHR( CRETURN) THEN
            EXIT( GILGAMSH);
          CASE INCHAR OF
            'A':  IF PARTYCNT < 6 THEN
                    ADDPARTY;
                   
            'R':  IF PARTYCNT > 0 THEN
                    REMOVE;
                   
            '1', '2', '3', '4', '5', '6':
                  IF PARTYCNT > 0 THEN
                    EXITCASL;
          END
        UNTIL FALSE
      END;   (* GILGAMSH *)
      
      
    PROCEDURE GOBOLTAC;  (* P010A0D *)
    
      BEGIN
        DSPTITLE( 'SHOP');
        XGOTO := XBOLTAC;
        XGOTO2 := XBOLTAC;
        EXIT( CASTLE)
      END;
      
      
    PROCEDURE GOTEMPLE;  (* P010A0E *)
    
      BEGIN
        DSPTITLE( 'TEMPLE');
        XGOTO := XCANT;
        XGOTO2 := XBOLTAC;
        EXIT( CASTLE)
      END;
    

    PROCEDURE ADVNTINN;  (* P010A0F *)
    
      CONST
           STABLES  = 65;
           COTS     = 66;
           ECONOMY  = 67;
           MERCHANT = 68;
           ROYAL    = 69;
           
      VAR
           PARTYX : INTEGER;
    
    
      PROCEDURE GETWHO;  (* P010A10 *)
      
        BEGIN
          DSPTITLE( 'INN');
          GOTOXY( 0, 13);
          WRITE( CHR( 11));
          PARTYX := GETCHARX( FALSE, 'WHO WILL STAY');
          IF PARTYX < 0 THEN
            EXIT( ADVNTINN)
        END;
        
        
      PROCEDURE INNMENU;  (* P010A11 *)
      
        BEGIN
          GOTOXY( 0, 13);
          WRITE( CHR( 11));
          WRITE( '   WELCOME ');
          WRITE( CHARACTR[ PARTYX].NAME);
          WRITELN( '. WE HAVE:');
          WRITELN;
          WRITELN(  '[A] THE STABLES (FREE!)');
          WRITELN(  '[B] COTS. 10 GP/WEEK.');
          WRITELN(  '[C] ECONOMY ROOMS. 50 GP/WEEK.');
          WRITELN(  '[D] MERCHANT SUITES. 200 GP/WEEK.');
          WRITELN(  '[E] ROYAL SUITES. 500 GP/WEEK.');
          WRITE(    '    OR [RETURN] TO LEAVE')
        END;
        
        
      PROCEDURE SETSPELS;  (* P010A12 *)
      
      
        PROCEDURE SPLPERLV( VAR SPELGRPS: TSPELL7G;  (* P010A13 *)
                                LEVELMOD: INTEGER;
                                LEVMOD2:  INTEGER);
                           
          VAR
               UNUSEDXX : INTEGER;
               SPGRPI   : INTEGER;
               SPELLCNT : INTEGER;
        
          BEGIN
            SPELLCNT :=  CHARACTR[ PARTYX].CHARLEV - LEVELMOD;
            IF SPELLCNT <=0 THEN
              EXIT (SPLPERLV);
            SPGRPI := 1;
            WHILE (SPGRPI >= 1) AND (SPGRPI <= 7) AND (SPELLCNT > 0) DO
              BEGIN
                IF SPELLCNT > SPELGRPS[ SPGRPI] THEN
                  SPELGRPS[ SPGRPI] := SPELLCNT;
                SPGRPI := SPGRPI + 1;
                SPELLCNT := SPELLCNT - LEVMOD2
              END;
            FOR SPGRPI := 1 TO 7 DO
              IF SPELGRPS[ SPGRPI] > 9 THEN
                SPELGRPS[ SPGRPI] := 9
          END;  (* SPLPERLV *)
          
          
        PROCEDURE NWPRIEST( MOD1: INTEGER;  (* P010A14 *)
                            MOD2: INTEGER);
        
          BEGIN
            SPLPERLV( CHARACTR[ PARTYX].PRIESTSP, MOD1, MOD2)
          END;
          
          
        PROCEDURE NWMAGE( MOD1: INTEGER;  (* P010A15 *)
                          MOD2: INTEGER);
        
          BEGIN
            SPLPERLV( CHARACTR[ PARTYX].MAGESP, MOD1, MOD2)
          END;
          
          
        PROCEDURE MINSPCNT( VAR SPLGRPS:  TSPELL7G;  (* P010A16 *)
                                GROUPI:   INTEGER;
                                LOWINDX:  INTEGER;
                                HIGHINDX: INTEGER);
                           
          VAR
               SPELLI   : INTEGER;
               SPELKNOW : INTEGER;
                           
          BEGIN
            SPELKNOW := 0;
            FOR SPELLI := LOWINDX TO HIGHINDX DO
              IF CHARACTR[ PARTYX].SPELLSKN[ SPELLI] THEN
                SPELKNOW := SPELKNOW + 1;
            SPLGRPS[ GROUPI] := SPELKNOW
          END;
          
          
        PROCEDURE MINMAG;  (* P010A17 *)
        
          BEGIN
            WITH CHARACTR[ PARTYX] DO
              BEGIN
                MINSPCNT( MAGESP, 1,  1,  4);
                MINSPCNT( MAGESP, 2,  5,  6);
                MINSPCNT( MAGESP, 3,  7,  8);
                MINSPCNT( MAGESP, 4,  9, 11);
                MINSPCNT( MAGESP, 5, 12, 14);
                MINSPCNT( MAGESP, 6, 15, 18);
                MINSPCNT( MAGESP, 7, 19, 21)
              END
          END;
          
          
        PROCEDURE MINPRI;  (* P010A18 *)
        
          BEGIN
            WITH CHARACTR[ PARTYX] DO
              BEGIN
                MINSPCNT( PRIESTSP, 1, 22, 26);
                MINSPCNT( PRIESTSP, 2, 27, 30);
                MINSPCNT( PRIESTSP, 3, 31, 34);
                MINSPCNT( PRIESTSP, 4, 35, 38);
                MINSPCNT( PRIESTSP, 5, 39, 44);
                MINSPCNT( PRIESTSP, 6, 45, 48);
                MINSPCNT( PRIESTSP, 7, 49, 50)
              END
          END;  (* MINPRI *)
      
      
        BEGIN  (* SETSPELS *)
          MINPRI;
          MINMAG;
          CASE CHARACTR[ PARTYX].CLASS OF
             PRIEST:  NWPRIEST( 0, 2);
               MAGE:  NWMAGE(   0, 2);
             BISHOP:  BEGIN
                        NWPRIEST( 3, 4);
                        NWMAGE(   0, 4)
                      END;
               LORD:  NWPRIEST( 3, 2);
            SAMURAI:  NWMAGE(   3, 3)
          END
        END;  (* SETSPELS *)
        
        
      PROCEDURE CHNEWLEV;  (* P010A19 *)
      
        VAR
             EXP2NEXT : TEXP;
             UNUSEDXX : TWIZLONG;
             BIGLEV   : INTEGER;
             EXPNXTLV : TWIZLONG;
      
      
        PROCEDURE MADELEV;  (* P010A1A *)
        
          VAR
               CHARLEV  : INTEGER;
               NEWHPMAX : INTEGER;
        
        
          FUNCTION MOREHP : INTEGER;  (* P010A1B *)
          
            VAR
                 HITPTS : INTEGER;
          
            BEGIN
              CASE CHARACTR[ PARTYX].CLASS OF
                FIGHTER, LORD:         HITPTS := RANDOM MOD 10;
                PRIEST, SAMURAI:       HITPTS := RANDOM MOD 8;
                THIEF, BISHOP, NINJA:  HITPTS := RANDOM MOD 6;
                MAGE:                  HITPTS := RANDOM MOD 4;
              END;
              
              HITPTS := HITPTS + 1;
              
              CASE CHARACTR[ PARTYX].ATTRIB[ VITALITY] OF
                3:     HITPTS := HITPTS - 2;
                4, 5:  HITPTS := HITPTS - 1;
                16:    HITPTS := HITPTS + 1;
                17:    HITPTS := HITPTS + 2;
                18:    HITPTS := HITPTS + 3;
              END;
              
              IF HITPTS < 1 THEN
                HITPTS := 1;
              MOREHP := HITPTS
            END;  (* MOREHP *)
            
            
          PROCEDURE TRYLEARN;  (* P010A1C *)
          
            VAR
                 IQPIETY : TATTRIB;
                 LEARNED : BOOLEAN;
          
          
            PROCEDURE TRY2LRN( LOWINDX:  INTEGER;  (* P010A1D *)
                               HIGHINDX: INTEGER);
            
              VAR
                   SPELLI   : INTEGER;
                   SPLKNOWN : BOOLEAN;
            
              BEGIN
                SPLKNOWN := FALSE;
                FOR SPELLI := LOWINDX TO HIGHINDX DO
                  SPLKNOWN := SPLKNOWN OR CHARACTR[ PARTYX].SPELLSKN[ SPELLI];
                FOR SPELLI := LOWINDX TO HIGHINDX DO
                  IF NOT (CHARACTR[ PARTYX].SPELLSKN[ SPELLI]) THEN
                    IF ((RANDOM MOD 30) <
                        CHARACTR[ PARTYX].ATTRIB[ IQPIETY]) OR
                       (NOT SPLKNOWN) THEN
                      BEGIN
                        LEARNED := TRUE;
                        SPLKNOWN := TRUE;
                        CHARACTR[ PARTYX].SPELLSKN[ SPELLI] := TRUE
                      END
              END;  (* TRY2LRN *)
              
              
            PROCEDURE TRYMAGE;  (* P010A1E *)
            
              BEGIN
                IQPIETY := IQ;
                WITH CHARACTR[ PARTYX] DO
                  BEGIN
                    IF MAGESP[ 1] > 0 THEN
                      TRY2LRN( 1, 4);
                    IF MAGESP[ 2] > 0 THEN
                      TRY2LRN( 5, 6);
                    IF MAGESP[ 3] > 0 THEN
                      TRY2LRN( 7, 8);
                    IF MAGESP[ 4] > 0 THEN
                      TRY2LRN( 9, 11);
                    IF MAGESP[ 5] > 0 THEN
                      TRY2LRN( 12, 14);
                    IF MAGESP[ 6] > 0 THEN
                      TRY2LRN( 15, 18);
                    IF MAGESP[ 7] > 0 THEN
                      TRY2LRN( 19, 21)
                  END
              END;  (* TRYMAGE *)
              
              
            PROCEDURE TRYPRI;  (* P010A1F *)
            
              BEGIN
                IQPIETY := PIETY;
                WITH CHARACTR[ PARTYX] DO
                  BEGIN
                    IF PRIESTSP[ 1] > 0 THEN
                      TRY2LRN( 22, 26);
                    IF PRIESTSP[ 2] > 0 THEN
                      TRY2LRN( 27, 30);
                    IF PRIESTSP[ 3] > 0 THEN
                      TRY2LRN( 31, 34);
                    IF PRIESTSP[ 4] > 0 THEN
                      TRY2LRN( 35, 38);
                    IF PRIESTSP[ 5] > 0 THEN
                      TRY2LRN( 39, 44);
                    IF PRIESTSP[ 6] > 0 THEN
                      TRY2LRN( 45, 48);
                    IF PRIESTSP[ 7] > 0 THEN
                      TRY2LRN( 49, 50)
                  END
              END;  (* TRYPRI *)
              
              
            BEGIN  (* TRYLEARN *)
              LEARNED := FALSE;
              TRYMAGE;
              TRYPRI;
              IF LEARNED THEN
                WRITELN( 'YOU LEARNED NEW SPELLS!!!!');
              SETSPELS
            END;   (* TRYLEARN *)
        
        
          PROCEDURE GAINLOST;  (* P010A20 *)
          
            VAR
                 ATTRVAL : INTEGER;
                 ATTRIBX : TATTRIB;
          
          
            PROCEDURE PRATTRIB;  (* P010A21 *)
            
              BEGIN
                CASE ATTRIBX OF
                  STRENGTH:  WRITELN( 'STRENGTH');
                        IQ:  WRITELN( 'I.Q.');
                     PIETY:  WRITELN( 'PIETY');
                  VITALITY:  WRITELN( 'VITALITY');
                   AGILITY:  WRITELN( 'AGILITY');
                      LUCK:  WRITELN( 'LUCK');
                END;
              END;  (* PRATTRIB *)
              
              
            PROCEDURE OLDAGE;  (* P010A22 *)
            
              BEGIN
                WRITE(  '** YOU HAVE DIED OF OLD AGE **');
                WRITELN;
                CHARACTR[ PARTYX].STATUS := LOST;
                CHARACTR[ PARTYX].HPLEFT := 0;
                EXIT( GAINLOST)
              END;
          
          
            BEGIN (* GAINLOST *)
              FOR ATTRIBX := STRENGTH TO LUCK DO
                BEGIN
                  IF (RANDOM MOD 4) <> 0 THEN
                    BEGIN
                      ATTRVAL := CHARACTR[ PARTYX].ATTRIB[ ATTRIBX];
                      IF (RANDOM MOD 130) <
                         (CHARACTR[ PARTYX].AGE DIV 52) THEN
                        IF (ATTRVAL = 18) AND
                           ((RANDOM MOD 6) <> 4) THEN
                          (* NOTHING *)
                        ELSE
                          BEGIN
                            ATTRVAL := ATTRVAL - 1;
                            WRITE(  'YOU LOST ');
                            PRATTRIB;
                            IF ATTRIBX = VITALITY THEN
                              IF ATTRVAL = 2 THEN
                                OLDAGE
                          END
                      ELSE
                        BEGIN
                          IF ATTRVAL <> 18 THEN
                            BEGIN
                              ATTRVAL := ATTRVAL + 1;
                              WRITE(  'YOU GAINED ');
                              PRATTRIB
                            END
                        END;
                      CHARACTR[ PARTYX].ATTRIB[ ATTRIBX] := ATTRVAL
                    END
                END
            END;  (* GAINLOST *)
        
        
          BEGIN  (* MADELEV *)
            WRITE( 'YOU MADE A LEVEL!');
            WRITELN;
            CHARACTR[ PARTYX].CHARLEV := CHARACTR[ PARTYX].CHARLEV + 1;
            IF CHARACTR[ PARTYX].CHARLEV > CHARACTR[ PARTYX].MAXLEVAC THEN
              CHARACTR[ PARTYX].MAXLEVAC := CHARACTR[ PARTYX].CHARLEV;
            SETSPELS;
            TRYLEARN;
            GAINLOST;
            
            NEWHPMAX := 0;
            FOR CHARLEV := 1 TO CHARACTR[ PARTYX].CHARLEV DO
              NEWHPMAX := NEWHPMAX + MOREHP;
            IF CHARACTR[ PARTYX].CLASS = SAMURAI THEN
              NEWHPMAX := NEWHPMAX + MOREHP;
            IF NEWHPMAX <= CHARACTR[ PARTYX].HPMAX THEN
              NEWHPMAX := CHARACTR[ PARTYX].HPMAX + 1;
            CHARACTR[ PARTYX].HPMAX := NEWHPMAX
        END;  (* MADELEV *)
        
        
        BEGIN (* CHNEWLEV *)
          MOVELEFT( IOCACHE[ GETREC( ZEXP, 0, SIZEOF( TEXP))],
                    EXP2NEXT,
                    SIZEOF( TEXP));
          WITH CHARACTR[ PARTYX] DO
            BEGIN
              IF CHARLEV <= 12 THEN
                EXPNXTLV := EXP2NEXT[ CLASS][ CHARLEV]
              ELSE
                BEGIN
                  EXPNXTLV := EXP2NEXT[ CLASS][ 12];
                  FOR BIGLEV := 13 TO CHARLEV DO
                    ADDLONGS( EXPNXTLV, EXP2NEXT[ CLASS][ 0])
                END;
                
              IF TESTLONG( EXPNXTLV, EXP) <= 0 THEN
                MADELEV
              ELSE
                BEGIN
                  WRITE( 'YOU NEED ');
                  SUBLONGS( EXPNXTLV, EXP);
                  PRNTLONG( EXPNXTLV);
                  WRITELN( ' MORE');
                  WRITELN( 'EXPERIENCE POINTS TO MAKE LEVEL')
                END
            END
        END;  (* CHNEWLEV *)
        
        
      PROCEDURE TAKENAP( HPADD:   INTEGER;  (* P010A23 *)
                         GOLDAMT: INTEGER);
      
        VAR
             GOLD4NAP : TWIZLONG;
             PAUSEX   : INTEGER;
      
      
        PROCEDURE HEALHP;  (* P010A24 *)
        
          BEGIN
            GOTOXY( 0, 13);
            CHARACTR[ PARTYX].HPLEFT := CHARACTR[ PARTYX].HPLEFT + HPADD;
            IF CHARACTR[ PARTYX].HPLEFT > CHARACTR[ PARTYX].HPMAX THEN
              CHARACTR[ PARTYX].HPLEFT := CHARACTR[ PARTYX].HPMAX;
            SUBLONGS( CHARACTR[ PARTYX].GOLD, GOLD4NAP);
            WRITE( CHARACTR[ PARTYX].NAME);
            WRITELN( ' IS HEALING UP');
            WRITELN;
            WRITELN;
            WRITE( '         HIT POINTS (');
            WRITE( CHARACTR[ PARTYX].HPLEFT);
            WRITE( '/');
            WRITE( CHARACTR[ PARTYX].HPMAX);
            WRITE( ')');
            WRITELN;
            WRITELN;
            WRITE( '               GOLD  ');
            PRNTLONG( CHARACTR[ PARTYX].GOLD);
            GOTOXY( 41, 10);
            FOR PAUSEX := 1 TO 500 DO
              ;
            
          END;  (* HEALHP *)
          
          
        BEGIN  (* TAKENAP *)
          GOLD4NAP.HIGH := 0;
          GOLD4NAP.MID  := 0;
          GOLD4NAP.LOW  := GOLDAMT;
          GOTOXY( 0, 13);
          WRITE( CHR( 11));
          IF GOLDAMT > 0 THEN
            WHILE (TESTLONG( CHARACTR[ PARTYX].GOLD, GOLD4NAP) >= 0) AND
                  (CHARACTR[ PARTYX].HPLEFT < CHARACTR[ PARTYX].HPMAX) AND
                   (NOT KEYAVAIL) DO
              HEALHP
          ELSE
            BEGIN
              WRITE( CHARACTR[ PARTYX].NAME);
              WRITELN( ' IS NAPPING');
            END;
          IF KEYAVAIL THEN
            BEGIN
              GOTOXY( 41, 0);
              GETKEY
            END;
          GOTOXY( 0, 13);
          WRITE( CHR(11));
          CHNEWLEV;
          SETSPELS;
          GOTOXY(  0, 23);
          WRITE(  'PRESS [RETURN] TO LEAVE');
          GOTOXY( 41, 0);
          REPEAT
            GETKEY
          UNTIL INCHAR = CHR( CRETURN);
          INCHAR := CHR( 0)
        END;   (* TAKENAP *)
        
        
      BEGIN  (* ADVNTINN *)
        REPEAT
          GETWHO;
          IF CHARACTR[ PARTYX].STATUS = OK THEN
            REPEAT
              UNITCLEAR( 1);
              INNMENU;
              GOTOXY( 41, 0);
              GETKEY;
              CASE ORD( INCHAR) OF
                 STABLES:  TAKENAP(  0,   0);
                    COTS:  TAKENAP(  1,  10);
                 ECONOMY:  TAKENAP(  3,  50);
                MERCHANT:  TAKENAP(  7, 200);
                   ROYAL:  TAKENAP( 10, 500);
              END;
              CHARINFO( PARTYX)
            UNTIL (INCHAR = CHR( CRETURN)) OR
                  (CHARACTR[ PARTYX].STATUS <> OK)
        UNTIL FALSE
      END;  (* ADVNTINN *)
      
      
    PROCEDURE EXTCASTL;  (* P010A25 *)
    
      BEGIN
        DSPTITLE( 'EXIT');
        XGOTO := XEDGTOWN;
        EXIT( CASTLE)
      END;
      
      
    PROCEDURE P010A26;  (* P010A26 *)
    
      BEGIN
        GOTOXY( 0, 13);
        WRITE( CHR( 11));
        WRITE( ' ' : 13);
        WRITELN( 'YOU MAY GO TO:');
        WRITELN;
        WRITELN( 'THE A)DVENTURER''S INN, G)ILGAMESH''');
        WRITELN( 'TAVERN, B)OLTAC''S TRADING POST, THE');
        WRITELN( 'TEMPLE OF C)ANT, OR THE E)DGE OF TOWN.')
      END;
      
    
    BEGIN  (* CASTLE  P010A01 *)
      ACMOD2   := 0;
      LIGHT    := 0;
      CHSTALRM := 0;
      
      CPCALLED.I := 1145;  (* $0479  SLOT#1 RAM SPACE *)
      
      ATTK012  := 0;
      FIZZLES  := 0;
      TEXTMODE;
      IF CPCALLED.P^[ 0] <> 10 THEN
        MVCURSOR( 70, 0);  (* CRASH AND BURN *)
      IF XGOTO2 <> XBOLTAC THEN
        DSPPARTY( '');
      XGOTO2 := XGILGAMS;
      IF XGOTO = XGILGAMS THEN
        GILGAMSH;
      REPEAT
        DSPTITLE( 'MARKET');
        P010A26;
        REPEAT
          REPEAT
            GOTOXY( 41, 0);
            GETKEY
          UNTIL (INCHAR = 'A') OR (INCHAR = 'G') OR (INCHAR = 'B') OR
                (INCHAR = 'C') OR (INCHAR = 'E');
        UNTIL (PARTYCNT > 0) OR (INCHAR = 'E') OR (INCHAR = 'G');
              
        CASE INCHAR OF
          'G':  GILGAMSH;
          'A':  ADVNTINN;
          'C':  GOTEMPLE;
          'B':  GOBOLTAC;
          'E':  EXTCASTL
        END
      UNTIL FALSE
    END;   (* CASTLE  P010A01 *)