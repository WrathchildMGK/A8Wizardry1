SEGMENT PROCEDURE CAMP;  (* P010C01 *)

    VAR
         OBJIDS   : ARRAY[ 0..7] OF INTEGER;
         OBJNAMES : ARRAY[ 0..7] OF ARRAY[ FALSE..TRUE] OF STRING[ 15];
         CURSEDXX : PACKED ARRAY[ 0..7] OF BOOLEAN;
         CANUSE   : PACKED ARRAY[ 0..7] OF BOOLEAN;
         DISPSTAT : BOOLEAN;
         OBJI     : INTEGER;
         
    
    PROCEDURE AASTRAA( ASTRA: STRING);  (* P010C02 *)
    
      BEGIN
        CENTSTR( CONCAT( '** ', ASTRA, ' **'));
      END;
      
      
    PROCEDURE INSPECT;  (* P010C03 *)
    
      VAR
           UNUSEDXX : INTEGER;
           CAMPCHAR : INTEGER;
         
         
      PROCEDURE DSPSPELS;  (* P010C04 *)
      
        VAR
             INDX : INTEGER;
      
        BEGIN
          WITH CHARACTR[ CAMPCHAR] DO
            BEGIN
              GOTOXY(  0, 9);
              WRITE( ' ' : 7);
              WRITE( ' MAGE ');
              FOR INDX := 1 TO 7 DO
                BEGIN
                  WRITE( MAGESP[ INDX]);
                  IF INDX < 7 THEN
                    WRITE( '/')
                END;
              WRITELN;
              WRITE( ' ' :6);
              WRITE( 'PRIEST ');
              FOR INDX := 1 TO 7 DO
                BEGIN
                  WRITE( PRIESTSP[ INDX]);
                  IF INDX < 7 THEN
                    WRITE( '/')
                END
            END
        END;
        
        
      PROCEDURE DSPITEMS;  (* P010C05 *)
      
      VAR
           ITEMX   : INTEGER;
           OBJECT  : TOBJREC;
           
        BEGIN
          GOTOXY( 0, 12);
          WRITE( '*=EQUIP, -=CURSED, ?=UNKNOWN, #=UNUSABLE');
          FOR ITEMX := 14 TO 17 DO
            BEGIN
              GOTOXY( 0, ITEMX);
              WRITE( CHR( 29))
            END;
            
          WITH CHARACTR[ CAMPCHAR] DO
            BEGIN
              IF POSS.POSSCNT = 0 THEN
                EXIT( DSPITEMS);
            
              FOR ITEMX := 1 TO POSS.POSSCNT DO
                BEGIN
                  GOTOXY( 20 -  20 * (ITEMX MOD 2),
                          14 + ((ITEMX - 1) DIV 2) );
                  IF OBJIDS[ ITEMX - 1] <>
                       POSS.POSSESS[ ITEMX].EQINDEX  THEN
                    BEGIN
                      MOVELEFT( IOCACHE[ GETREC(
                                   ZOBJECT,
                                   POSS.POSSESS[ ITEMX].EQINDEX,
                                   SIZEOF( TOBJREC))],
                                OBJECT,
                                SIZEOF( TOBJREC));
                      OBJIDS[ ITEMX - 1] := POSS.POSSESS[ ITEMX].EQINDEX;
                      OBJNAMES[ ITEMX - 1][ TRUE]  := OBJECT.NAME;
                      OBJNAMES[ ITEMX - 1][ FALSE] := OBJECT.NAMEUNK;
                      CANUSE[ ITEMX - 1] := OBJECT.CLASSUSE[ CLASS];
                      CURSEDXX[ ITEMX - 1] := OBJECT.CURSED
                    END;
                    
                  WRITE( ITEMX :1);
                  WRITE( ')');
                  IF POSS.POSSESS[ ITEMX].EQUIPED THEN
                    IF CURSEDXX[ ITEMX - 1] THEN
                      WRITE( '-')
                    ELSE
                      WRITE( '*')
                  ELSE
                    IF POSS.POSSESS[ ITEMX].IDENTIF THEN
                      IF CANUSE[ ITEMX - 1] THEN
                        WRITE( ' ')
                      ELSE
                        WRITE( '#')  (* WAS '^' IN LOL *)
                    ELSE
                      WRITE( '?');
                  WRITE( OBJNAMES[ ITEMX - 1][ POSS.POSSESS[ ITEMX].IDENTIF])
                END
            END
        END;
        
        
      PROCEDURE CASTSPEL( SPELHASH: INTEGER);  (* P010C06 *)
        
        VAR
             USEITEM  : BOOLEAN;
             SPELNAME : STRING;
             UNUSEDXX : INTEGER;
             HASHCALC : INTEGER;
             SPELLI   : INTEGER;
             HEALME   : INTEGER;
      
      
        PROCEDURE EXITCAST( EXITSTR: STRING);  (* P010C07 *)
        
          BEGIN
            AASTRAA( EXITSTR);
            DSPSPELS;
            EXIT( CASTSPEL)
          END;
          
          
        PROCEDURE HEALWHO;  (* P010C08 *)
        
          VAR
               UNUSED : ARRAY[ 0..41] OF INTEGER;
        
          BEGIN
            HEALME := GETCHARX( TRUE, 'CAST ON WHO');
            IF HEALME = -1 THEN
              EXITCAST( 'NOT IN THE PARTY')
          END;
          
          
        PROCEDURE CHKSPCNT( PRIESTGR: INTEGER; (* P010C09 *)
                            SPELLIDX: INTEGER);
        
          BEGIN
            IF USEITEM THEN
              EXIT( CHKSPCNT);
            IF (CHARACTR[ CAMPCHAR].PRIESTSP[ PRIESTGR] <= 0) OR
               (NOT CHARACTR[ CAMPCHAR].SPELLSKN[ SPELLIDX]) THEN
              EXITCAST( 'YOU CANT CAST IT')
          END;
          
          
        PROCEDURE DECPRIEST( PRIESTGR: INTEGER);  (* P010C0A *)
        
          BEGIN
            IF NOT USEITEM THEN
              CHARACTR[ CAMPCHAR].PRIESTSP[ PRIESTGR] :=
                CHARACTR[ CAMPCHAR].PRIESTSP[ PRIESTGR] - 1;
            IF FIZZLES > 0 THEN
              EXITCAST( 'SPELL HAS NO EFFECT')
          END;
          
          
        PROCEDURE DOHEAL( HPTRIES:  INTEGER;  (* P010C0B *)
                          MAXHPTRY: INTEGER;
                          PRIESTGR: INTEGER;
                          SPELLIDX: INTEGER);
        
          VAR
               HPHEALED : INTEGER;
        
          BEGIN
            CHKSPCNT( PRIESTGR, SPELLIDX);
            HEALWHO;
            DECPRIEST( PRIESTGR);
            HPHEALED := 0;
            IF HPTRIES = -1 THEN
              BEGIN
                  (* MADI *)
                HPHEALED := CHARACTR[ HEALME].HPMAX;
                CHARACTR[ HEALME].LOSTXYL.POISNAMT[ 1] := 0;
                IF CHARACTR[ HEALME].STATUS < DEAD THEN
                  CHARACTR[ HEALME].STATUS := OK
              END
            ELSE
              WHILE HPTRIES > 0 DO
                BEGIN
                  HPHEALED := HPHEALED + (RANDOM MOD MAXHPTRY) + 1;
                  HPTRIES := HPTRIES - 1
                END;
            CHARACTR[ HEALME].HPLEFT := CHARACTR[ HEALME].HPLEFT + HPHEALED;
            IF CHARACTR[ HEALME].HPLEFT > CHARACTR[ HEALME].HPMAX THEN
              CHARACTR[ HEALME].HPLEFT := CHARACTR[ HEALME].HPMAX;
            GOTOXY( 0, 23);
            WRITE( 'CURED ');
            WRITE( HPHEALED);
            WRITE( ' HP - NOW ');
            WRITE( CHARACTR[ HEALME].HPLEFT);
            WRITE( '/');
            WRITE( CHARACTR[ HEALME].HPMAX);
            GOTOXY( 41, 0);
            PAUSE2;
            DSPSPELS;
            EXIT( CASTSPEL)
          END;  (* DOHEAL *)
          
          
        PROCEDURE DOKANDI;  (* P010C0C *)
        
          BEGIN
            CHKSPCNT( 5, 42);
            DECPRIEST( 5);
            DISPSTAT := TRUE;
            LLBASE04 := CAMPCHAR;
            BASE12.GOTOX := XCASTLE;
            XGOTO := XCAMPSTF;
            EXIT( CAMP)
          END;
          
          
        PROCEDURE DODIKADO( DIKADOXX: INTEGER);  (* P010C0D *)
        
        
          PROCEDURE DIKADORT;  (* P010C0E *)
          
            BEGIN
              IF (RANDOM MOD 100) <=
                 4 * CHARACTR[ HEALME].ATTRIB[ VITALITY] THEN
                BEGIN
                  CHARACTR[ HEALME].STATUS := OK;
                  IF DIKADOXX = 5 THEN
                    CHARACTR[ HEALME].HPLEFT := 1
                  ELSE
                    CHARACTR[ HEALME].HPLEFT := 
                      CHARACTR[ HEALME].HPMAX;
                  IF CHARACTR[ HEALME].ATTRIB[ VITALITY] = 3 THEN
                    CHARACTR[ HEALME].STATUS := LOST
                  ELSE
                    CHARACTR[ HEALME].ATTRIB[ VITALITY] :=
                      CHARACTR[ HEALME].ATTRIB[ VITALITY] - 1
                END;
              IF CHARACTR[ HEALME].STATUS = OK THEN
                EXITCAST( 'EXCELSIOR')
              ELSE
                BEGIN
                  CHARACTR[ HEALME].STATUS := SUCC( CHARACTR[ HEALME].STATUS);
                  EXITCAST( 'OOPPS!')
                END
            END;  (* DIKADORT *)
            
            
          BEGIN  (* DODIKADO *)
            IF DIKADOXX = 5 THEN
              CHKSPCNT( DIKADOXX, 43)
            ELSE
              CHKSPCNT( DIKADOXX, 50);
            HEALWHO;
            DECPRIEST( DIKADOXX);
            IF DIKADOXX = 5 THEN
              BEGIN
                IF CHARACTR[ HEALME].STATUS = DEAD THEN
                  DIKADORT
                ELSE
                  IF CHARACTR[ HEALME].STATUS = ASHES THEN
                    EXITCAST( '"KADORTO" NEEDED')
              END
            ELSE
              IF (CHARACTR[ HEALME].STATUS = DEAD) OR
                 (CHARACTR[ HEALME].STATUS = ASHES) THEN
                DIKADORT
              ELSE
                IF CHARACTR[ HEALME].STATUS = LOST THEN
                  EXITCAST( 'LOST');
            EXITCAST( 'NOT DEAD')
          END;  (* DODIKADO *)
          
          
        PROCEDURE DODUMAPI;  (* P010C0F *)
        
          BEGIN
            IF NOT (USEITEM) THEN
              IF (CHARACTR[ CAMPCHAR].MAGESP[ 1] = 0) OR
                 NOT CHARACTR[ CAMPCHAR].SPELLSKN[ 4] THEN
                EXITCAST( 'YOU CANT CAST IT');
            IF FIZZLES > 0 THEN
              EXITCAST( 'SPELL FAILS');
            IF NOT USEITEM THEN
              CHARACTR[ CAMPCHAR].MAGESP[ 1] :=
                CHARACTR[ CAMPCHAR].MAGESP[ 1] - 1;
            LLBASE04 := CAMPCHAR;
            BASE12.GOTOX := XGILGAMS;
            XGOTO := XCAMPSTF;
            EXIT( CAMP)
          END;  (* DODUMAPI *)
          
          
        PROCEDURE DOMALOR;  (* P010C10 *)
        
          BEGIN
            IF NOT USEITEM THEN
              IF (CHARACTR[ CAMPCHAR].MAGESP[ 7] = 0) OR
                 (NOT CHARACTR[ CAMPCHAR].SPELLSKN[ 19]) THEN
                EXITCAST( 'YOU CANT CAST IT');
            IF FIZZLES > 0 THEN
              EXITCAST( 'SPELL FAILS');
            IF NOT USEITEM THEN
              CHARACTR[ CAMPCHAR].MAGESP[ 7] :=
                CHARACTR[ CAMPCHAR].MAGESP[ 7] - 1;
            LLBASE04 := CAMPCHAR;
            BASE12.GOTOX := XINSPECT;
            XGOTO := XCAMPSTF;
            EXIT( CAMP)
          END;  (* DOMALOR *)
          
          
        BEGIN (* CASTSPEL *)
          DISPSTAT := FALSE;
          USEITEM := SPELHASH > 0;
          IF SPELHASH = -1 THEN
            BEGIN
              GOTOXY( 0, 18);
              WRITE( CHR( 11));
              WRITE( 'WHAT SPELL ? >' : 24);
              GETLINE( SPELNAME);
              SPELHASH := LENGTH( SPELNAME);
              FOR SPELLI := 1 TO LENGTH( SPELNAME) DO
                BEGIN
                  HASHCALC := ORD( SPELNAME[ SPELLI]) - 64;
                  SPELHASH := SPELHASH + HASHCALC * HASHCALC * SPELLI
                END;
            END;
            
          GOTOXY( 41, 0);
          WRITE( SPELHASH : 6);
          WRITE( ' ');
          
          IF SPELHASH = DIOS THEN
            DOHEAL( 1, 8, 1, 23)
          ELSE IF SPELHASH = MILWA THEN
            BEGIN
              CHKSPCNT( 1, 25);
              DECPRIEST( 1);
              LIGHT := 15 + (RANDOM MOD 15)
            END
          ELSE IF SPELHASH = DUMAPI THEN
            DODUMAPI
          ELSE IF SPELHASH = KANDI THEN
            DOKANDI
          ELSE IF SPELHASH = LOMILWA THEN
            BEGIN
              CHKSPCNT( 3, 31);
              DECPRIEST( 3);
              LIGHT := 32000
            END
          ELSE IF SPELHASH = LATUMOFI THEN
            BEGIN
              CHKSPCNT( 4, 37);
              HEALWHO;
              DECPRIEST( 4);
              CHARACTR[ HEALME].LOSTXYL.POISNAMT[ 1] := 0
            END
          ELSE IF SPELHASH = DIALKO THEN
            BEGIN
              CHKSPCNT( 3, 32);
              HEALWHO;
              DECPRIEST( 3);
              IF (CHARACTR[ HEALME].STATUS = PLYZE) OR
                 (CHARACTR[ HEALME].STATUS = ASLEEP) THEN
                CHARACTR[ HEALME].STATUS := OK;
            END
          ELSE IF SPELHASH = DIAL THEN
            DOHEAL( 2, 8, 4, 35)
          ELSE IF SPELHASH = MAPORFIC THEN
            BEGIN
              CHKSPCNT( 4, 38);
              DECPRIEST( 4);
              ACMOD2 := 2
            END
          ELSE IF SPELHASH = DIALMA THEN
            DOHEAL( 3, 8, 5, 39)
          ELSE IF SPELHASH = DI THEN
            DODIKADO( 5)
          ELSE IF SPELHASH = MADI THEN
            DOHEAL( -1, -1, 6, 46)
          ELSE IF SPELHASH = KADORTO THEN
            DODIKADO( 7)
          ELSE IF SPELHASH = MALOR THEN
            DOMALOR
          ELSE
            EXITCAST( 'WHAT?');
          EXITCAST( 'DONE!')
        END;  (* CASTSPEL *)
        
        
      PROCEDURE USEITEM;  (* P010C11 *)
        
        VAR
             THEITEM  : TOBJREC;
             UNUSEDXX : INTEGER;
             UNUSEDYY : INTEGER;
             UNUSEDZZ : INTEGER;
             ITEMX    : INTEGER;
             
             
        PROCEDURE EXITUSE( EXITSTR: STRING);  (* P010C12 *)
        
          BEGIN
            AASTRAA( EXITSTR);
            EXIT( USEITEM)
          END;
          
          
        BEGIN (* USEITEM *)
          DISPSTAT := FALSE;
          REPEAT
            GOTOXY( 0, 18);
            WRITE( CHR( 11));
            WRITE( 'USE ITEM (0=EXIT) ? >');
            GETKEY;
            WRITELN;
            ITEMX := ORD( INCHAR) - ORD( '0');
            IF ITEMX = 0 THEN
              EXIT( USEITEM);
          UNTIL (ITEMX > 0) AND
                (ITEMX <= CHARACTR[ CAMPCHAR].POSS.POSSCNT);
          MOVELEFT( IOCACHE[ GETREC(
                       ZOBJECT,
                       CHARACTR[ CAMPCHAR].POSS.POSSESS[ ITEMX].EQINDEX,
                       SIZEOF( TOBJREC))],
                    THEITEM,
                    SIZEOF( TOBJREC));
          IF THEITEM.SPELLPWR = 0 THEN
            EXITUSE( 'POWERLESS');
          IF THEITEM.OBJTYPE <> SPECIAL THEN
            IF NOT CHARACTR[ CAMPCHAR].POSS.POSSESS[ ITEMX].EQUIPED THEN
              EXITUSE( 'NOT EQUIPPED');
          IF (RANDOM MOD 100) < THEITEM.CHGCHANC THEN
            CHARACTR[ CAMPCHAR].POSS.POSSESS[ ITEMX].EQINDEX := 
              THEITEM.CHANGETO;
          CASTSPEL( SCNTOC.SPELLHSH[ THEITEM.SPELLPWR])
        END;  (* USEITEM *)
        
        

      
  PROCEDURE DROPITEM;  (* P010C13 *)
      
      VAR
           UNUSEDXX : INTEGER;
           UNUSEDYY : INTEGER;
           POSSX    : INTEGER;
           POSSI    : INTEGER;
        
        
        PROCEDURE EXITDROP( EXITSTR: STRING);  (* P010C14 *)
        
          BEGIN
            AASTRAA( EXITSTR);
            EXIT( DROPITEM)
          END;
          
          
        BEGIN  (* DROPITEM *)
          DISPSTAT := FALSE;
          REPEAT
            GOTOXY( 0, 18);
            WRITE( CHR( 11));
            WRITE(  'DROP ITEM (0=EXIT) ? >');
            GETKEY;
            POSSI := ORD( INCHAR) - ORD( '0');
            IF POSSI = 0 THEN
              EXIT( DROPITEM);
          UNTIL (POSSI > 0) AND
                (POSSI <= CHARACTR[ CAMPCHAR].POSS.POSSCNT);
          IF CHARACTR[ CAMPCHAR].POSS.POSSESS[ POSSI].CURSED THEN
            EXITDROP( 'CURSED');
          IF CHARACTR[ CAMPCHAR].POSS.POSSESS[ POSSI].EQUIPED THEN
            EXITDROP( 'EQUIPPED');
          FOR POSSX := POSSI + 1 TO CHARACTR[ CAMPCHAR].POSS.POSSCNT DO
            CHARACTR[ CAMPCHAR].POSS.POSSESS[ POSSX - 1] :=
              CHARACTR[ CAMPCHAR].POSS.POSSESS[ POSSX];
          CHARACTR[ CAMPCHAR].POSS.POSSCNT :=
                                          CHARACTR[ CAMPCHAR].POSS.POSSCNT - 1;
          DSPITEMS;
          EXITDROP( 'DROPPED')
        END;  (* DROPITEM *)
        
    PROCEDURE IDENTIFY_PROC;  (* P010C15 *)
      
        VAR
             UNUSEDXX : INTEGER;
             
             
      PROCEDURE EXITIDNT( EXITSTR: STRING);  (* P010C16 *)
        
          BEGIN
            AASTRAA( EXITSTR);
            EXIT( IDENTIFY_PROC)
          END;
          
          
        BEGIN (* IDENTIFY *)
          DISPSTAT := FALSE;
          IF CHARACTR[ CAMPCHAR].CLASS <> BISHOP THEN
              EXITIDNT( 'NOT BISHOP');
          LLBASE04 := CAMPCHAR;
          BASE12.GOTOX := XTRAININ;
          XGOTO := XCAMPSTF;
          EXIT( CAMP)
        END;  (* IDENTIFY *)
        
        
      PROCEDURE DOTRADE;  (* P010C17 *)
      
        VAR
             GOLD2TRA : TWIZLONG;
             TRADETO  : INTEGER;
             GOLDSTR  : STRING;
             GOLDX    : INTEGER;
             TEMP0001 : INTEGER; (* MULTIPLE USES *)
             ITEMX    : INTEGER;
             
             
        PROCEDURE EXITTRAD( EXITSTR: STRING);  (* P010C18 *)
        
          BEGIN
            AASTRAA( EXITSTR);
            EXIT( DOTRADE)
          END;
          
          
        PROCEDURE TRADGOLD;  (* P010C19 *)
        
          VAR
               TEMPGOLD : TWIZLONG;
               MULT10   : INTEGER;
        
          BEGIN
            GOTOXY( 0, 18);
            WRITE( CHR( 11));
            WRITE( 'AMT OF GOLD ? >');
            GETLINE( GOLDSTR);
            FILLCHAR( TEMPGOLD, 6, 0);
            FILLCHAR( GOLD2TRA, 6, 0);
            TEMP0001 := 0;
            MULT10 := 10;
            FOR GOLDX := 1 TO LENGTH( GOLDSTR) DO
              IF (ORD( GOLDSTR[ GOLDX]) < ORD( '0')) OR
                 (ORD( GOLDSTR[ GOLDX]) > ORD( '9')) OR
                 (GOLDX > 12) OR
                 (TEMP0001 = -1)    THEN
                TEMP0001 := -1
              ELSE
                BEGIN
                  MULTLONG( GOLD2TRA, MULT10);
                  TEMPGOLD.LOW := ORD( GOLDSTR[ GOLDX]) - ORD( '0');
                  ADDLONGS( GOLD2TRA, TEMPGOLD)
                END;
            IF TEMP0001 = -1 THEN
              EXITTRAD( 'BAD AMT');
            IF TESTLONG( CHARACTR[ CAMPCHAR].GOLD, GOLD2TRA) < 0 THEN
              EXITTRAD( 'NOT ENOUGH $');
            ADDLONGS( CHARACTR[ TRADETO].GOLD, GOLD2TRA);
            SUBLONGS( CHARACTR[ CAMPCHAR].GOLD, GOLD2TRA)
          END;  (* TRADGOLD *)
          
          
        PROCEDURE TRADITEM;  (* P010C1A *)
        
          BEGIN
            REPEAT
              REPEAT
                GOTOXY( 0, 18);
                WRITE( CHR( 11));
                WRITE( 'WHAT ITEM ([RET] EXITS) ? >');
                GETKEY;
                ITEMX := ORD( INCHAR) - ORD( '0');
                IF INCHAR = CHR( CRETURN) THEN
                  EXIT( DOTRADE)
              UNTIL (ITEMX > 0) AND
                    (ITEMX <= CHARACTR[ CAMPCHAR].POSS.POSSCNT);
              IF CHARACTR[ TRADETO].POSS.POSSCNT = 8 THEN
                EXITTRAD( 'FULL');
              IF CHARACTR[ CAMPCHAR].POSS.POSSESS[ ITEMX].CURSED THEN
                EXITTRAD( 'CURSED');
              IF CHARACTR[ CAMPCHAR].POSS.POSSESS[ ITEMX].EQUIPED THEN
                EXITTRAD( 'EQUIPPED');
              TEMP0001 := CHARACTR[ TRADETO].POSS.POSSCNT + 1;
              CHARACTR[ TRADETO].POSS.POSSESS[ TEMP0001] :=
                CHARACTR[ CAMPCHAR].POSS.POSSESS[ ITEMX];
              CHARACTR[ TRADETO].POSS.POSSCNT := TEMP0001;
              FOR TEMP0001 := ITEMX + 1 TO CHARACTR[ CAMPCHAR].POSS.POSSCNT DO
                CHARACTR[ CAMPCHAR].POSS.POSSESS[ TEMP0001 - 1] :=
                  CHARACTR[ CAMPCHAR].POSS.POSSESS[ TEMP0001];
              CHARACTR[ CAMPCHAR].POSS.POSSCNT :=
                                          CHARACTR[ CAMPCHAR].POSS.POSSCNT - 1;
              DSPITEMS
            UNTIL FALSE
          END;  (* TRADITEM *)
      
      
        BEGIN (* DOTRADE *)
          DISPSTAT := FALSE;
          REPEAT
            TRADETO := GETCHARX( TRUE, 'TRADE WITH');
            IF TRADETO = -1 THEN
              EXIT( DOTRADE);
          UNTIL TRADETO <> CAMPCHAR;
          TRADGOLD;
          TRADITEM
        END;  (* DOTRADE *)
        
        
      PROCEDURE CAMPDO;  (* P010C1B *)
      
        VAR
             MENUTYPE : INTEGER;
      
      
        PROCEDURE CAMPMENU;  (* P010C1C *)
        
        
          PROCEDURE DSPSTATS;  (* P010C1D *)


            PROCEDURE CHEVRONS;  (* P010C1E *)
      
              VAR
                   INDX     : INTEGER;
                   LOSTXYL4 : PACKED ARRAY[ 0..15] OF BOOLEAN;
            
              BEGIN
                MOVELEFT( CHARACTR[ CAMPCHAR].LOSTXYL.AWARDS[ 4], LOSTXYL4, 2);
                WRITE( '"');   (* 1 DOUBLE QUOTE *)
                FOR INDX := 0 TO 15 DO
                  IF LOSTXYL4[ INDX] THEN
                    WRITE( COPY( '>!$#&*<?BCPKODG@', INDX + 1, 1) );
                WRITE(  '" ')
              END;  (* CHEVRONS *)
        
        
        
            BEGIN  (* DSPSTATS *)
              WITH CHARACTR[ CAMPCHAR] DO
                BEGIN
                  WRITE( CHR( 12));
                  WRITE( NAME);
                  WRITE( ' ');
                  IF LOSTXYL.AWARDS[ 4] > 0 THEN
                    CHEVRONS;
                  WRITE( SCNTOC.RACE[ RACE]);
                  WRITE( ' ');
                  WRITE( COPY( SCNTOC.ALIGN[ ALIGN], 1, 1) );
                  WRITE( '-');
                  WRITE( SCNTOC.CLASS[ CLASS]);
                  WRITELN;
                  WRITELN;
                  WRITE( 'STRENGTH' :12);
                  WRITE( ATTRIB[ STRENGTH] :3);
                  WRITE( 'GOLD ' :9);
                  PRNTLONG( GOLD);
                  WRITELN;
                  WRITE( 'I.Q.' :12);
                  WRITE( ATTRIB[ IQ] :3);
                  WRITE( 'EXP ' :9);
                  PRNTLONG( EXP);
                  WRITELN;
                  WRITE( 'PIETY' :12);
                  WRITE( ATTRIB[ PIETY] :3);
                  WRITELN;
                  WRITE( 'VITALITY' :12);
                  WRITE( ATTRIB[ VITALITY] :3);
                  WRITE( 'LEVEL ' :9);
                  WRITE( CHARLEV :3);
                  WRITE( 'AGE ' :9);
                  WRITE( (AGE DIV 52) :3);
                  WRITELN;
                  WRITE( 'AGILITY' :12);
                  WRITE( ATTRIB[ AGILITY] :3);
                  WRITE( 'HITS ' :9);
                  WRITE( HPLEFT :3);
                  WRITE( '/');
                  WRITE( HPMAX :3);
                  WRITE( 'AC' :4);
                  WRITE( (ARMORCL - ACMOD2) :4);
                  WRITELN;
                  WRITE( 'LUCK' : 12);
                  WRITE( ATTRIB[ LUCK] :3);
                  WRITE( 'STATUS ' :9);
                  WRITE( SCNTOC.STATUS[ STATUS]);
                  IF LOSTXYL.POISNAMT[ 1] > 0 THEN
                    WRITE( ' & POISONED');
                  WRITELN;
                  DSPSPELS;
                  DSPITEMS
                END
            END;
        
        
          BEGIN  (* CAMPMENU *)
            WITH CHARACTR[ CAMPCHAR] DO
              BEGIN
                IF DISPSTAT THEN
                  DSPSTATS;
                GOTOXY( 0, 18);
                IF XGOTO = XINSPCT3 THEN
                  MENUTYPE := 0
                ELSE IF XGOTO = XINSPECT THEN
                  MENUTYPE := 1
                ELSE IF STATUS = OK THEN
                  MENUTYPE := 2
                ELSE
                  MENUTYPE := 1;
                  
                IF MENUTYPE = 2 THEN
                  BEGIN
                    WRITE( CHR( 11));
                    WRITELN( 'YOU MAY E)QUIP, D)ROP AN ITEM, T)RADE,');
                    WRITE( ' ' :8);
                    WRITELN( 'R)EAD SPELL BOOKS, CAST S)PELLS,');
                    WRITE( ' ' :8);
                    WRITELN( 'U)SE AN ITEM, I)DENTIFY AN ITEM,');
                    WRITE( ' ' :8);
                    WRITELN( 'OR L)EAVE.')
                  END
                ELSE IF MENUTYPE = 1 THEN
                  BEGIN
                    WRITE( CHR( 11));
                    WRITELN( 'YOU MAY E)QUIP, D)ROP AN ITEM, T)RADE,');
                    WRITE( ' ' :8);
                    WRITELN( 'R)EAD SPELL BOOKS, OR L)EAVE.')
                  END
                ELSE
                  BEGIN
                    WRITE( CHR( 11));
                    WRITELN( 'YOU MAY R)EAD SPELL BOOKS OR L)EAVE.')
                  END;
              END
          END;  (* CAMPMENU *)
          
          
        BEGIN (* CAMPDO *)
          CAMPMENU;
          DISPSTAT := TRUE;
          REPEAT
            GOTOXY( 41, 0);
            GETKEY
          UNTIL (INCHAR = 'R') OR (INCHAR = 'L') OR
                ((MENUTYPE > 0) AND
                 ((INCHAR = 'T') OR (INCHAR = 'D') OR (INCHAR = 'E'))) OR
                ((MENUTYPE > 1) AND
                 ((INCHAR = 'I') OR (INCHAR = 'S') OR (INCHAR = 'U')));
          
          CASE INCHAR OF
            'L':  EXIT( CAMPDO);
            'E':  IF MENUTYPE > 0 THEN
                    BEGIN
                      XGOTO := XEQPDSP;
                      LLBASE04 := CAMPCHAR;
                      EXIT( CAMP)
                    END;
            'R':  BEGIN
                    XGOTO := XCAMPSTF;
                    BASE12.GOTOX := XDONE;
                    LLBASE04 := CAMPCHAR;
                    EXIT( CAMP)
                  END;
            'D':  IF MENUTYPE > 0 THEN
                    DROPITEM;
            'I':  IF MENUTYPE = 2 THEN
                    IDENTIFY_PROC;
            'S':  IF MENUTYPE = 2 THEN
                    CASTSPEL( -1);
            'U':  IF MENUTYPE = 2 THEN
                    USEITEM;
            'T':  DOTRADE
           END
        END;  (* CAMPDO *)
        
        
      BEGIN  (* INSPECT *)
        CAMPCHAR := LLBASE04;
        XGOTO2 := XGOTO;
        WRITE( CHR( 12));
        REPEAT
          CAMPDO;
        UNTIL INCHAR = 'L';
        WRITE( CHR( 12))
      END;   (* INSPECT *)
      
      
  PROCEDURE CAMPMEN2;  (* P010C1F *)
  
    VAR
         CHARX : INTEGER;
      
      
    PROCEDURE DSP1LINE( CHARX: INTEGER);  (* P010C20 *)
    
      BEGIN
        GOTOXY(  0, 3 + CHARX);
        WRITE( CHR( 29));
        WRITE( (CHARX + 1) : 2);
        WRITE( ' ');
        WRITE( CHARACTR[ CHARX].NAME);
        GOTOXY( 19, 3 + CHARX);
        WRITE( COPY( SCNTOC.ALIGN[ CHARACTR[ CHARX].ALIGN], 1, 1));
        WRITE( '-');
        WRITE( COPY( SCNTOC.CLASS[ CHARACTR[ CHARX].CLASS], 1, 3));
        WRITE( ' ');
        IF CHARACTR[ CHARX].ARMORCL - ACMOD2 > -10 THEN
          WRITE( (CHARACTR[ CHARX].ARMORCL - ACMOD2) : 2)
        ELSE
          WRITE( 'LO');
        WRITE( CHARACTR[ CHARX].HPLEFT : 5);
        LLBASE04 := CHARACTR[ CHARX].HEALPTS -
                    CHARACTR[ CHARX].LOSTXYL.POISNAMT[ 1];
        IF LLBASE04 > 0 THEN
          WRITE( '+')
        ELSE IF LLBASE04 < 0 THEN
          WRITE( '-')
        ELSE
          WRITE( ' ');
                    
        IF CHARACTR[ CHARX].STATUS = OK THEN
          IF CHARACTR[ CHARX].LOSTXYL.POISNAMT[ 1] <> 0 THEN
            WRITELN( 'POISON')
          ELSE
            WRITELN( CHARACTR[ CHARX].HPMAX :4)
        ELSE
          WRITELN( SCNTOC.STATUS[ CHARACTR[ CHARX].STATUS]);
      END;
      
      
    BEGIN (* CAMPMEN2 *)
      WRITE( CHR( 12));
      WRITELN( 'CAMP' :22);
      WRITELN;
      WRITELN( ' # CHARACTER NAME  CLASS AC HITS STATUS');
      FOR CHARX := 0 TO PARTYCNT - 1 DO
        BEGIN
          DSP1LINE( CHARX)
        END;
      GOTOXY( 0, 12);
      WRITELN( 'YOU MAY R)EORDER, E)QUIP, D)ISBAND,');
      WRITE( ' ' :8);
      WRITELN( '#) TO INSPECT, OR');
      WRITE( ' ' :8);
      WRITELN( 'L)EAVE THE CAMP.')
    END;  (* CAMPMEN2 *)
      
      
  PROCEDURE DISBAND;  (* P010C21 *)
  
  
    PROCEDURE CONFIRM( NULLRE :STRING);  (* P010C22 *)
    
      BEGIN (* CONFIRM *)
        WRITE( CHR( 12));
        WRITE( NULLRE);
        WRITE( 'CONFIRM (Y/N) ?');
        REPEAT
          GOTOXY( 41, 0);
          READ( INCHAR)
        UNTIL (INCHAR = 'Y') OR (INCHAR = 'N');
        IF INCHAR = 'N' THEN
          EXIT( DISBAND)
      END;  (* CONFIRM *)
      
      
    BEGIN (* DISBAND *)
      CONFIRM( '');
      CONFIRM( 'RE-');
      FOR LLBASE04 := 0 TO PARTYCNT - 1 DO
        BEGIN
          WITH CHARACTR[ LLBASE04] DO
            BEGIN
              INMAZE := FALSE;
              LOSTXYL.LOCATION[ 1] := MAZEX;
              LOSTXYL.LOCATION[ 2] := MAZEY;
              LOSTXYL.LOCATION[ 3] := MAZELEV;
              AGE := AGE + 25;
              MOVELEFT( CHARACTR[ LLBASE04],
                        IOCACHE[ GETRECW(
                                         ZCHAR,
                                         CHARDISK[ LLBASE04],
                                         SIZEOF( TCHAR))],
                        SIZEOF( TCHAR) )
            END
        END;
        
        MOVELEFT( IOCACHE[ GETREC( ZZERO, 0, SIZEOF( TSCNTOC))], 
                  SCNTOC,
                  SIZEOF( TSCNTOC) );
        LLBASE04 := -2;
        XGOTO := XSCNMSG;
        EXIT( CAMP)
    END;  (* DISBAND *)
        
        
    BEGIN  (* CAMP *)
      DISPSTAT := TRUE;
      FOR OBJI := 1 TO 8 DO
        OBJIDS[ OBJI - 1] := -1;
      TEXTMODE;
      IF (XGOTO = XBCK2CMP) OR
         (XGOTO = XBK2CMP2) THEN
        BEGIN
          XGOTO := XGOTO2;
          IF XGOTO = XINSPCT2 THEN
            INSPECT
        END;
      IF XGOTO = XINSPECT THEN
        BEGIN
          INSPECT;
          XGOTO := XGILGAMS;
          EXIT( CAMP)
        END;
      IF XGOTO = XINSPCT3 THEN
        BEGIN
          LLBASE04 := 0;
          INSPECT;
          XGOTO := XBCK2ROL;
          EXIT( CAMP)
        END;
      
      REPEAT
        UNITCLEAR( 1);
        CAMPMEN2;
        GOTOXY( 41, 0);
        GETKEY;
        IF (INCHAR > '0') AND (INCHAR <= CHR( ORD( '0') + PARTYCNT)) THEN
          BEGIN
            LLBASE04 := ORD( INCHAR) - ORD( '1');
            FOR OBJI := 1 TO 8 DO
              OBJIDS[ OBJI - 1] := -1;
            INSPECT
          END
        ELSE
          BEGIN
            CASE INCHAR OF
             'R':  BEGIN
                     XGOTO := XREORDER;
                     EXIT( CAMP)
                   END;
             'L':  BEGIN
                     XGOTO := XCMP2EQ6;
                     EXIT( CAMP)
                   END;
             'E':  BEGIN
                     XGOTO := XEQPDSP;
                     LLBASE04 := -1;
                     EXIT( CAMP)
                   END;
             'D':  DISBAND;
            END;
          END;
          
      UNTIL FALSE
    END;  (* CAMP *)
  