SEGMENT PROCEDURE UTILITIE;  (* P010101 *)

  VAR
       CHARI : INTEGER;
       CHARX : INTEGER;  (* MULTIPLE USES   SVBASE04, SAVBASE4, ETC.
                                            SAVECAST, ETC. *)
       EQUIPALL : BOOLEAN;


  PROCEDURE RDSPELLS;  (* P010102 *)
  
    CONST
         SCNMAGE = 4;
         SCNPRST = 5;
  
    VAR
         SPELLGRP : INTEGER;
         SPLISTX  : INTEGER;
         DSKSPLNM : INTEGER;
         SPELLX   : INTEGER;
         
         
    PROCEDURE LISTSPLS;  (* P010103 *)
    
      VAR
           SPELLNM : STRING;
           CHPTR   : INTEGER;
           
           
      PROCEDURE PRSPELL( SPELLNM: STRING);  (* P010104 *)
      
        BEGIN
          IF SPELLNM[ 1] = '*' THEN
            BEGIN
              SPELLNM := COPY( SPELLNM, 2, LENGTH( SPELLNM) - 1);
              SPLISTX := SPLISTX + 1
            END;
          GOTOXY( 10 * (SPLISTX DIV 20), 2 + SPLISTX MOD 20);
          IF CHARACTR[ CHARX].SPELLSKN[ SPELLX] THEN
            BEGIN
              WRITE( SPELLNM);
              SPLISTX := SPLISTX + 1
            END;
          SPELLX := SPELLX + 1
        END;  (* PRSPELL *)
        
        
      PROCEDURE SPRETURN;  (* P010105 *)
      
        BEGIN
          GOTOXY( 0, 23);
          WRITE( 'L)EAVE WHEN READY');
          REPEAT
            GOTOXY( 41, 0);
            GETKEY
          UNTIL INCHAR = 'L';
          INCHAR := CHR( 0)
        END;  (* SPRETURN *)
      
      
      BEGIN  (* LISTSPLS *)
        MOVELEFT( IOCACHE[ GETREC( ZZERO, 0, SIZEOF( TSCNTOC))],
                  SCNTOC,
                  SIZEOF( TSCNTOC));
        UNITREAD( DRIVE1, IOCACHE, BLOCKSZ, SCNTOCBL + DSKSPLNM, 0);
        CHPTR := 0;
        SPLISTX := 0;
        WHILE IOCACHE[ CHPTR] <> CHR( CRETURN) DO
          BEGIN
            LLBASE04 := 0;
            WHILE IOCACHE[ CHPTR] <> CHR( CRETURN) DO
              BEGIN
                LLBASE04 := LLBASE04 + 1;
                SPELLNM[ LLBASE04] :=  IOCACHE[ CHPTR];
                CHPTR := CHPTR + 1
              END;
            SPELLNM[ 0] := CHR( LLBASE04);
            PRSPELL( SPELLNM);
            CHPTR := CHPTR + 1
          END;
        UNITREAD( DRIVE1, IOCACHE, SIZEOF( IOCACHE), SCNTOCBL, 0);
        SPRETURN
      END;  (* LISTSPLS *)
      
      
    PROCEDURE PRPRIEST;  (* P010106 *)
    
      BEGIN
        WRITE( CHR( 12));
        WRITE( 'KNOWN PRIEST SPELLS');
        DSKSPLNM := SCNPRST;
        SPELLX := 22;
        LISTSPLS
      END;  (* PRPRIEST *)
      
      
    PROCEDURE PRMAGE;  (* P010107 *)
    
      BEGIN
        DSKSPLNM := SCNMAGE;
        SPELLX := 1;
        WRITE( CHR(12));
        WRITE( 'KNOWN MAGE SPELLS');
        LISTSPLS
      END;  (* PRMAGE *)
      
    
    BEGIN  (* RDSPELLS *)
      CHARX := LLBASE04;
      REPEAT
        WRITE( CHR(12));
        WRITE( 'MAGE   SPELLS LEFT = ');
        WRITE( CHARACTR[ CHARX].MAGESP[ 1]);
        SPELLGRP := 1 + 1;
        WHILE SPELLGRP <= 7 DO
          BEGIN
            WRITE( '/');
            WRITE( CHARACTR[ CHARX].MAGESP[ SPELLGRP]);
            SPELLGRP := SPELLGRP + 1
          END;
        WRITELN;
        WRITE( 'PRIEST SPELLS LEFT = ');
        WRITE( CHARACTR[ CHARX].PRIESTSP[ 1]);
        SPELLGRP := 1 + 1;
        WHILE SPELLGRP <= 7 DO
          BEGIN
            WRITE( '/');
            WRITE( CHARACTR[ CHARX].PRIESTSP[ SPELLGRP]);
            SPELLGRP := SPELLGRP + 1
          END;
        WRITELN;
        WRITELN;
        WRITELN( 'YOU MAY SEE M)AGE OR P)RIEST SPELL BOOKS');
        WRITELN( 'OR L)EAVE.' :22);
        GOTOXY( 41, 15);
        GETKEY;
        CASE INCHAR OF
          'M' :  PRMAGE;
          'P' :  PRPRIEST;
        END
      UNTIL INCHAR = 'L';
      INCHAR := CHR( 0);
      XGOTO := XBK2CMP2;
      LLBASE04 := CHARX;
      EXIT( UTILITIE)
    END;  (* RDSPELLS *)
    

  PROCEDURE IDITEM;  (* P010108 *)
  
    VAR
         ITEMX    : INTEGER;
         OBJECT   : TOBJREC;
  
  
    PROCEDURE EXITIDIT;  (* P010109 *)
    
      BEGIN
        LLBASE04 := CHARX;
        EXIT( UTILITIE)
      END;  (* EXITIDIT *)
    
    
    BEGIN (* IDITEM *)
      CHARX := LLBASE04;
      XGOTO := XBK2CMP2;
      REPEAT
        GOTOXY( 0, 18);
        WRITE( CHR(11));
        WRITE( 'IDENTIFY WHAT ITEM (0=EXIT) ? >');
        GETKEY;
        ITEMX := ORD( INCHAR) - ORD( '0');
        IF ITEMX =  0 THEN
          EXITIDIT
      UNTIL (ITEMX > 0) OR (ITEMX <= CHARACTR[ CHARX].POSS.POSSCNT);
      IF CHARACTR[ CHARX].POSS.POSSESS[ ITEMX].IDENTIF THEN
        EXITIDIT;
      CHARACTR[ CHARX].POSS.POSSESS[ ITEMX].IDENTIF :=
        (RANDOM MOD 100) < (10 +  5 * CHARACTR[ CHARX].CHARLEV);
      IF CHARACTR[ CHARX].POSS.POSSESS[ ITEMX].IDENTIF THEN
        CENTSTR( 'SUCCESS!')
      ELSE
        CENTSTR( 'FAILURE');
      IF (RANDOM MOD 100) < (35 - (3 * CHARACTR[ CHARX].CHARLEV)) THEN
        BEGIN
          MOVELEFT( IOCACHE[ GETREC(
                      ZOBJECT,
                      CHARACTR[ CHARX].POSS.POSSESS[ ITEMX].EQINDEX,
                      SIZEOF( TOBJREC))],
                    OBJECT,
                    SIZEOF( TOBJREC));
          CHARACTR[ CHARX].POSS.POSSESS[ ITEMX].CURSED := OBJECT.CURSED;
          XGOTO := XEQPDSP
        END;
      EXITIDIT
    END;  (* IDITEM *)
    
  PROCEDURE KANDIFND;  (* P01010A *)
  
    VAR
        CHARXDSK  : INTEGER;
        LOCSTRING : STRING;
        LOSTCHAR  : TCHAR;
  
  
    PROCEDURE EXITKAND;  (* P01010B *)
    
      BEGIN
        WRITELN;
        WRITELN( 'L)EAVE WHEN READY');
        GOTOXY( 41, 0);
        REPEAT
          GETKEY;
        UNTIL INCHAR = 'L';
        INCHAR := 'A';
        LLBASE04 := CHARX;
        XGOTO := XBK2CMP2;
        EXIT( UTILITIE)
      END;  (* EXITKAND *)
      
      
    PROCEDURE KANDILOC;  (* P01010C *)
    
      BEGIN
        IF LOSTCHAR.STATUS = LOST THEN
          EXIT( KANDILOC);
        IF LOSTCHAR.STATUS < DEAD THEN
          WRITELN( 'STILL WITH US!')
        ELSE
          BEGIN
            IF (LOSTCHAR.LOSTXYL.LOCATION[ 1] = 0) AND
               (LOSTCHAR.LOSTXYL.LOCATION[ 2] = 0) AND
               (LOSTCHAR.LOSTXYL.LOCATION[ 3] = 0)     THEN
              WRITELN( 'IN THE MOURGE')
            ELSE
              IF LOSTCHAR.LOSTXYL.LOCATION[ 3] <= 0 THEN
                BEGIN
                  WRITELN( 'UNREACHABLE!')
                END
              ELSE
                BEGIN
                  WRITE( 'IN THE ');
                  
                  IF LOSTCHAR.LOSTXYL.LOCATION[ 2] > 9 THEN
                    WRITE( 'NORTH ')
                  ELSE
                    WRITE( 'SOUTH ');
                    
                  IF LOSTCHAR.LOSTXYL.LOCATION[ 1] > 9 THEN
                    WRITE( 'EAST')
                  ELSE
                    WRITE( 'WEST');
                    
                  WRITE( ' OF LEVEL ');
                  WRITELN(  LOSTCHAR.LOSTXYL.LOCATION[ 3]);
                END
          END;
        EXITKAND
      END;  (* KANDILOC *)
      
      
    BEGIN  (* KANDIFND *)
      CHARX :=  LLBASE04;
      WRITE( CHR(12));
      WRITELN( 'LOCATE BODIES');
      WRITELN;
      WRITE('FIND WHO ? >');
      GETLINE( LOCSTRING);
      WRITE( CHR(12));
      WRITE( 'THE SOUL OF ');
      WRITE( LOCSTRING);
      WRITELN( ' IS..');
      WRITELN;
      FOR CHARXDSK := 0 TO SCNTOC.RECPERDK[ ZCHAR] - 1 DO
        BEGIN
          MOVELEFT( IOCACHE[ GETREC( ZCHAR, CHARXDSK, SIZEOF( TCHAR))],
                    LOSTCHAR,
                    SIZEOF( TCHAR));
          IF LOSTCHAR.NAME = LOCSTRING THEN
            KANDILOC
        END;
      WRITELN( 'LOST FOREVER!');
      EXITKAND
    END;   (* KANDIFND *)
    

    PROCEDURE DUMAPIC;  (* P01010D *)
    
      BEGIN
        XGOTO := XBK2CMP2;
        IF MAZELEV = 10 THEN
          BEGIN
            WRITE( CHR( 12));
            WRITELN( 'ENCHANTMENTS PREVENT SPELL FROM WORKING');
            EXIT( UTILITIE)
          END;
        CHARX := LLBASE04;
        WRITE( CHR( 12));
        WRITELN( 'PARTY LOCATION:');
        WRITELN;
        WRITE( 'THE PARTY IS FACING ');
        CASE DIRECTIO OF
          0:  WRITELN( 'NORTH.');
          1:  WRITELN( 'EAST.');
          2:  WRITELN( 'SOUTH.');
          3:  WRITELN( 'WEST.');
        END;
        WRITELN;
        WRITE( 'YOU ARE ');
        WRITE( MAZEX);
        WRITELN( ' SQUARES EAST AND');
        WRITE( MAZEY);
        WRITELN( ' SQUARES NORTH OF THE STAIRS');
        WRITE( 'TO THE CASTLE, AND ');
        WRITE( MAZELEV);
        WRITELN( ' LEVELS');
        WRITELN( 'BELOW IT.');
        WRITELN;
        WRITELN( 'L)EAVE WHEN READY');
        REPEAT
          GOTOXY( 41, 0);
          GETKEY
        UNTIL INCHAR = 'L';
        INCHAR := 'A';
        LLBASE04 := CHARX;
        EXIT( UTILITIE)
      END;  (* DUMAPIC *)
  

  PROCEDURE MALOR_PROC;    (* P01010E *)
  
    VAR
         DELTAUD  : INTEGER;
         DELTANS  : INTEGER;
         DELTAEW  : INTEGER;
  
  
    PROCEDURE TELEPORT;  (* P01010F *)
    
      PROCEDURE ROCK;  (* P010110 *)
      
        VAR
             X : INTEGER;
      
        BEGIN
          WRITELN( 'YOU LANDED IN SOLID ROCK OUTSIDE THE');
          WRITELN( 'DUNGEON - YOU ARE LOST FOREVER!');
          FOR X := 0 TO PARTYCNT - 1 DO
            BEGIN
              CHARACTR[ X].INMAZE := FALSE;
              CHARACTR[ X].STATUS := LOST
            END;
          XGOTO := XCEMETRY;
          EXIT( UTILITIE)
        END;
              
        
      PROCEDURE VOLCANO;  (* P010111 *)
      
        VAR
             X : INTEGER;
      
        BEGIN
          WRITELN( 'YOU MATERIALIZED IN MID-AIR AND FELL');
          WRITELN( 'TO A PAINFUL DEATH!');
          FOR X := 0 TO PARTYCNT - 1 DO
            IF CHARACTR[ X].STATUS < DEAD THEN
              CHARACTR[ X].STATUS := DEAD;
          MAZELEV := 0;
          XGOTO := XCHK4WIN;
          EXIT( UTILITIE)
        END;
        
        
      PROCEDURE MOAT;   (* P010112 *)
      
        VAR
             X : INTEGER;
      
        BEGIN
          WRITELN( 'YOU APPEARED IN THE CASTLE MOAT AND');
          WRITELN( 'PROBABLY DROWNED!');
          FOR X := 0 TO PARTYCNT - 1 DO
            IF CHARACTR[ X].STATUS < DEAD THEN
              IF (RANDOM MOD 25) > CHARACTR[ X].ATTRIB[ AGILITY] THEN
                CHARACTR[ X].STATUS := DEAD;
          MAZELEV := 0;
          XGOTO := XCHK4WIN;
          EXIT( UTILITIE)
        END;
    
    
      PROCEDURE TOSHOPS;  (* P010113 *)
      
        BEGIN
          XGOTO := XCHK4WIN;
          EXIT( UTILITIE)
        END;
    
    
      PROCEDURE BOUNCE;  (* P010114 *)
      
        BEGIN
          WRITELN( 'YOU BOUNCED BACK TO WHERE YOU WERE!');
          EXIT( UTILITIE)
        END;
    
    
      BEGIN (* TELEPORT *)
        WRITE( CHR(12));
        XGOTO := XNEWMAZE;
        IF MAZELEV + DELTAUD = SCNTOC.RECPERDK[ ZMAZE] THEN
          BOUNCE;
        MAZEX := MAZEX + DELTAEW;
        MAZEY := MAZEY + DELTANS;
        MAZELEV := MAZELEV + DELTAUD;
        IF ( (MAZEX < 0) OR (MAZEX > 19) OR
             (MAZEY < 0) OR (MAZEY > 19) OR
             (MAZELEV > SCNTOC.RECPERDK[ ZMAZE]))
           AND
           (MAZELEV > 0) THEN
            ROCK
        ELSE
          BEGIN
            IF MAZELEV < 0 THEN
              VOLCANO
            ELSE
              IF MAZELEV = 0 THEN
                IF (MAZEX = 0) AND (MAZEY = 0) THEN
                  TOSHOPS
                ELSE
                  MOAT
          END;
        EXIT( UTILITIE)
      END;
  
  
    BEGIN (* MALOR *)
      CHARX := LLBASE04;
      WRITE( CHR(12));
      WRITELN( 'PARTY TELEPORT:');
      WRITELN;
      WRITELN( 'ENTER NSEWU OR D TO  SET DISPLACEMENT,');
      WRITELN( 'THEN [RETURN] TO TELEPORT, OR [ESC] TO');
      WRITELN( 'CHICKEN OUT!');
      WRITELN;
      WRITELN( '# SQUARES EAST  =');
      WRITELN( '# SQUARES NORTH =');
      WRITELN( '# SQUARES DOWN  =');
      DELTAEW := 0;
      DELTANS := 0;
      DELTAUD := 0;
      REPEAT
        GOTOXY( 18, 6);
        WRITE( DELTAEW : 4);
        GOTOXY( 18, 7);
        WRITE( DELTANS : 4);
        GOTOXY( 18, 8);
        WRITE( DELTAUD : 4);
        GOTOXY( 41, 0);
        GETKEY;
        IF INCHAR = CHR( CRETURN) THEN
          TELEPORT
        ELSE
          BEGIN
            CASE INCHAR OF
              'N': DELTANS := DELTANS + 1;
              'S': DELTANS := DELTANS - 1;
              'E': DELTAEW := DELTAEW + 1;
              'W': DELTAEW := DELTAEW - 1;
              'D': DELTAUD := DELTAUD + 1;
              'U': DELTAUD := DELTAUD - 1;
            END
          END
      UNTIL INCHAR = CHR( 27);
      XGOTO := XBK2CMP2;
      LLBASE04 := CHARX;
      EXIT( UTILITIE)
    END;
    

  PROCEDURE NEWMAZE;  (* P010115 *)
  
    VAR
         MAZEMAP  : TMAZE;
         UNUSED   : ARRAY[ 0..2] OF INTEGER;
         
  
    PROCEDURE FIGHTS;  (* P010116 *)
    
      VAR
           FIGHTY : INTEGER;
           FIGHTX : INTEGER;
           Y      : INTEGER;
           X      : INTEGER;
    
    
      PROCEDURE FINDSPOT;  (* P010117 *)
      
        VAR
            Y1 : INTEGER;
            X1 : INTEGER;
      
        BEGIN (* FINDSPOT *)
          X1 := RANDOM MOD 20;
          Y1 := RANDOM MOD 20;
          FIGHTX := X1;
          FIGHTY := Y1;
          REPEAT
            IF MAZEMAP.FIGHTS[ FIGHTX][ FIGHTY] = 1 THEN
              IF NOT (FIGHTMAP[ FIGHTX][ FIGHTY]) THEN
                BEGIN
                  EXIT( FINDSPOT)
                END;
            FIGHTX := FIGHTX + 1;
            IF FIGHTX > 19 THEN
              BEGIN
                FIGHTX := 0;
                FIGHTY := FIGHTY + 1;
                IF FIGHTY > 19 THEN
                  FIGHTY := 0
              END;
          UNTIL (FIGHTX = X1) AND (FIGHTY = Y1);
          EXIT( FIGHTS)
        END;   (* FINDSPOT *)
        
        
      PROCEDURE FILLROOM( X : INTEGER; Y : INTEGER);  (* P010118 *)
        
        BEGIN
        
          X := (X + 20) MOD 20;
          Y := (Y + 20) MOD 20;
          IF (MAZEMAP.FIGHTS[ X][ Y] = 0) OR
             FIGHTMAP[ X][ Y] THEN
             BEGIN
               EXIT( FILLROOM)
             END;
             
          FIGHTMAP[ X][ Y] := TRUE;
          
          IF MAZEMAP.N[ X][ Y] = OPEN THEN
            FILLROOM( X, Y + 1);
            
          IF MAZEMAP.E[ X][ Y] = OPEN THEN
            FILLROOM( X + 1, Y);
            
          IF MAZEMAP.S[ X][ Y] = OPEN THEN
            FILLROOM( X, Y - 1);
            
          IF MAZEMAP.W[ X][ Y] = OPEN THEN
            FILLROOM( X - 1, Y)
            
        END;   (* FILLROOM *)
    
    
      BEGIN (* FIGHTS *)
        FILLCHAR( FIGHTMAP, 80, 0);
        FOR X := 1 TO 9 DO
          BEGIN
            FINDSPOT;
            FILLROOM( FIGHTX, FIGHTY)
          END;
          
        FOR X := 0 TO 19 DO
          BEGIN
            FOR Y := 0 TO 19 DO
              BEGIN
                IF MAZEMAP.SQRETYPE[ MAZEMAP.SQREXTRA[ X][ Y]] = ENCOUNTE THEN
                  FILLROOM( X, Y)
              END;
          END;
      END;  (* FIGHTS *)
  
  
    BEGIN (* NEWMAZE *)
      IF MAZELEV = 0 THEN
        BEGIN
          WRITE( CHR(12));
          XGOTO := XCHK4WIN;
          EXIT( UTILITIE)
        END;
        
      IF MAZELEV < 0 THEN
        BEGIN
          MAZELEV := 1;
          XGOTO := XEQUIP6
        END
      ELSE
        BEGIN
          XGOTO := XRUNNER
        END;
      MOVELEFT( IOCACHE[ GETREC( ZMAZE, MAZELEV - 1, SIZEOF( TMAZE))],
                MAZEMAP,
                SIZEOF( TMAZE));
      FIGHTS;
      CLRRECT( 1, 11, 38, 4);
      EXIT( UTILITIE)
    END;  (* NEWMAZE *)
    

	PROCEDURE EQUIPCHR( CHARI : INTEGER);  (* P010119 *)
    
    VAR
         UNARMED  : BOOLEAN;
         CANUSE   : ARRAY[ TOBJTYPE] OF BOOLEAN;
         UNUSED   : BOOLEAN;
         TEMPX    : INTEGER; (* MULTIPLE USES *)
         POSSI    : INTEGER;
         POSSCNT  : INTEGER;
         LUCKI    : INTEGER;
         OBJI     : TOBJTYPE;
         OBJECT   : TOBJREC;
         OBJLIST  : ARRAY[ 1..8] OF INTEGER;
         
    
    PROCEDURE CHSPCPOW;  (* P01011A *)
      
      
        PROCEDURE SPCPOWER;  (* P01011B *)
        
          VAR
               SPCTEMP  : INTEGER;
               GOLD50K  : TWIZLONG;
        
        
          PROCEDURE SPC1TO12( ATTR2MOD: INTEGER;  (* P01011C *)
                              MODAMT:   INTEGER);
          
            VAR
                 ATTRX : TATTRIB;
          
            BEGIN
              ATTRX := STRENGTH;
              WHILE ATTR2MOD > 1 DO
                BEGIN
                  ATTRX := SUCC( ATTRX);
                  ATTR2MOD := ATTR2MOD - 1
                END;
              SPCTEMP := CHARACTR[ CHARI].ATTRIB[ ATTRX] + MODAMT;
              IF (SPCTEMP > 2) AND (SPCTEMP < 19) THEN
                CHARACTR[ CHARI].ATTRIB[ ATTRX] := SPCTEMP;
            END;
          
        
          BEGIN  (* SPCPOWER *)
            FILLCHAR( GOLD50K, 6, 0);
            GOLD50K.MID := 5;
            WRITE( CHR( 12));
            WRITELN( 'WILL YOU INVOKE THE SPECIAL POWER OF');
            WRITE( 'YOUR ');
            IF CHARACTR[ CHARI].POSS.POSSESS[ POSSI].IDENTIF THEN
              WRITE( OBJECT.NAME)
            ELSE
              WRITE( OBJECT.NAMEUNK);
            WRITE( ' (Y/N) ? >');
            REPEAT
              GETKEY
            UNTIL (INCHAR = 'Y') OR (INCHAR = 'N');
            IF INCHAR = 'N' THEN
              EXIT( SPCPOWER);
            IF (RANDOM MOD 100) < OBJECT.CHGCHANC THEN
              CHARACTR[ CHARI].POSS.POSSESS[ POSSI].EQINDEX :=
                OBJECT.CHANGETO;
            IF OBJECT.SPECIAL < 7 THEN
              BEGIN
                SPC1TO12( OBJECT.SPECIAL, 1)
              END
            ELSE
              BEGIN
                IF OBJECT.SPECIAL < 13 THEN
                  SPC1TO12( OBJECT.SPECIAL - 6, - 1)
                ELSE 
                  BEGIN
                    WITH CHARACTR[ CHARI] DO
                      BEGIN
                        CASE OBJECT.SPECIAL OF
                          13: IF AGE > 1040 THEN
                                AGE := AGE - 52;
                          14: AGE := AGE + 52;
                          15: CLASS := SAMURAI;
                          16: CLASS := LORD;
                          17: CLASS := NINJA;
                          18: ADDLONGS( GOLD, GOLD50K);
                          19: ADDLONGS( EXP, GOLD50K);
                          20: STATUS := LOST;
                          21: BEGIN
                                STATUS := OK;
                                HPLEFT := HPMAX;
                                LOSTXYL.POISNAMT[ 1] := 0
                              END;
                          22: HPMAX := HPMAX + 1;
                          23: BEGIN
                                (* LOOKS LIKE BUG!  PARTYCNT - 1  !!! *)
                                FOR SPCTEMP := 0 TO PARTYCNT DO
                                    CHARACTR[ SPCTEMP].HPLEFT :=
                                      CHARACTR[ SPCTEMP].HPMAX
                              END;
                        END
                    END
                  END
              END;
          END;  (* SPCPOWER *)
      
      
        BEGIN (* CHSPCPOW *)
          FOR POSSI := 1 TO CHARACTR[ CHARI].POSS.POSSCNT DO
            IF CHARACTR[ CHARI].POSS.POSSESS[ POSSI].EQINDEX > 0 THEN
              BEGIN
                MOVELEFT( IOCACHE[ GETREC( 
                            ZOBJECT,
                            CHARACTR[ CHARI].POSS.POSSESS[ POSSI].EQINDEX,
                            SIZEOF( TOBJREC))],
                          OBJECT,
                          SIZEOF( TOBJREC));
                IF OBJECT.SPECIAL > 0 THEN
                  SPCPOWER
              END;
        END;
    
    
      PROCEDURE NORMPOW;  (* P01011D *)
      
        VAR
             TEMPX : INTEGER;
             TEMPY : INTEGER;
             POSSX : INTEGER;
      
        BEGIN
          FILLCHAR( CANUSE, 14, 0);
          FOR POSSX := 1 TO CHARACTR[ CHARI].POSS.POSSCNT DO
            BEGIN
              MOVELEFT( IOCACHE[ GETREC( ZOBJECT,
                                         CHARACTR[ CHARI].
                                           POSS.POSSESS[ POSSX].EQINDEX,
                                         SIZEOF( TOBJREC))],
                        OBJECT,
                        SIZEOF( TOBJREC));
              IF OBJECT.CLASSUSE[ CHARACTR[ CHARI].CLASS] THEN
                CANUSE[ OBJECT.OBJTYPE] := TRUE;
              IF CHARACTR[ CHARI].HEALPTS < OBJECT.HEALPTS THEN
                CHARACTR[ CHARI].HEALPTS := OBJECT.HEALPTS;
              FOR TEMPX := 0 TO 13 DO
                CHARACTR[ CHARI].WEPVSTY2[ 0][ TEMPX] :=
                CHARACTR[ CHARI].WEPVSTY2[ 0][ TEMPX] OR OBJECT.WEPVSTY2[ TEMPX];
              FOR TEMPY := 0 TO 6 DO
                CHARACTR[ CHARI].WEPVSTY3[ 0][ TEMPY] :=
                CHARACTR[ CHARI].WEPVSTY3[ 0][ TEMPY] OR OBJECT.WEPVSTY3[ TEMPY]
            END
        END;  (* NORMPOW *)
        
        
      PROCEDURE ARMORPOW( CHARX: INTEGER;  (* P01011E *)
                          POSSX: INTEGER;
                          OBJID: INTEGER);
      
        VAR
             MP04XX : INTEGER;  (* UNUSED *)
      
        BEGIN
          UNARMED := FALSE;
          MOVELEFT( IOCACHE[ GETREC( ZOBJECT,
                                     OBJID,
                                     SIZEOF( TOBJREC))],
                    OBJECT,
                    SIZEOF( TOBJREC));
          WITH CHARACTR[ CHARX] DO
            BEGIN
              POSS.POSSESS[ POSSX].CURSED := OBJECT.CURSED;
              IF (OBJECT.ALIGN = UNALIGN) OR (OBJECT.ALIGN = ALIGN) THEN
                BEGIN
                  IF OBJECT.XTRASWNG > SWINGCNT THEN
                    SWINGCNT := OBJECT.XTRASWNG;
                  ARMORCL := ARMORCL - OBJECT.ARMORMOD;
                  HPCALCMD := HPCALCMD + OBJECT.WEPHITMD;
                  IF OBJECT.OBJTYPE = WEAPON THEN
                    BEGIN
                      LLBASE04 := HPDAMRC.HPMINAD;
                      HPDAMRC := OBJECT.WEPHPDAM;
                      HPDAMRC.HPMINAD := HPDAMRC.HPMINAD + LLBASE04;
                      CRITHITM := CRITHITM OR OBJECT.CRITHITM;
                      WEPVSTYP := OBJECT.WEPVSTYP
                    END
                END
              ELSE
                BEGIN
                  HPCALCMD := HPCALCMD - 1;
                  ARMORCL := ARMORCL + 1;
                  CRITHITM := FALSE;
                  POSS.POSSESS[ POSSX].CURSED := TRUE
                END
            END;
        END;  (* ARMORPOW *)
        
        
      PROCEDURE ARM4CHAR;  (* P01011F *)
      
      VAR
           POSSX : INTEGER;
      
        BEGIN
          FOR POSSX := 1 TO CHARACTR[ CHARI].POSS.POSSCNT DO
            IF CHARACTR[ CHARI].POSS.POSSESS[ POSSX].EQUIPED THEN
              ARMORPOW( CHARI, POSSX,
                                 CHARACTR[ CHARI].POSS.POSSESS[ POSSX].EQINDEX)
        END;
        
        
      PROCEDURE DOEQUIP;  (* P010120 *)
      
      
        PROCEDURE EQUIPONE;  (* P010121 *)
        
          BEGIN
            REPEAT
              GOTOXY( 0, 15);
              WRITE( CHR( 11));
              WRITE( 'WHICH ONE ([RET] FOR NONE) ? >');
              GETKEY;
              IF INCHAR = CHR( CRETURN) THEN
                EXIT( EQUIPONE);
              POSSI := ORD( INCHAR) - ORD( '0')
            UNTIL (POSSI > 0) AND (POSSI <= POSSCNT);
            CHARACTR[ CHARI].POSS.POSSESS[ OBJLIST[ POSSI]].EQUIPED := TRUE;
            ARMORPOW( CHARI,
                      OBJLIST[ POSSI],
                      CHARACTR[ CHARI].POSS.POSSESS[ OBJLIST[ POSSI]].EQINDEX)
          END;  (* EQUIPONE *)
      
      
        PROCEDURE CURSBELL( CURSSTR : STRING);  (* P010122 *)
        
          VAR
               X : INTEGER;
        
          BEGIN
            FOR X := 1 TO LENGTH( CURSSTR) DO
              BEGIN
                WRITE( CURSSTR[ X]);
                WRITE( CHR( 7));
                WRITE( CHR( 7))
              END;
          END;
        
        
        BEGIN (* DOEQUIP *)
          IF NOT CANUSE[ OBJI] THEN
            EXIT (DOEQUIP);
          WRITE( CHR( 12));
          WRITE( 'SELECT ');
          CASE OBJI OF
              WEAPON : WRITE( 'WEAPON');
               ARMOR : WRITE( 'ARMOR');
              SHIELD : WRITE( 'SHIELD');
              HELMET : WRITE( 'HELMET');
            GAUNTLET : WRITE( 'GAUNTLETS');
                MISC : WRITE( 'MISC. ITEM');
          END;
          WRITE( ' FOR ');
          WRITELN( CHARACTR[ CHARI].NAME);
          WRITELN;
          WRITELN;
          POSSCNT := 0;
          FOR POSSI := 1 TO CHARACTR[ CHARI].POSS.POSSCNT DO
            BEGIN
              IF CHARACTR[ CHARI].POSS.POSSESS[ POSSI].EQINDEX > 0 THEN
                BEGIN
                  MOVELEFT( IOCACHE[ GETREC(
                                ZOBJECT,
                                CHARACTR[ CHARI].POSS.POSSESS[ POSSI].EQINDEX,
                                SIZEOF( TOBJREC))],
                            OBJECT,
                            SIZEOF( TOBJREC));
                  IF (OBJECT.OBJTYPE = OBJI) AND
                     (OBJECT.CLASSUSE[ CHARACTR[ CHARI].CLASS]) THEN
                    BEGIN
                      POSSCNT := POSSCNT + 1;
                      OBJLIST[ POSSCNT] := POSSI;
                      WRITE( ' ' :10);
                      WRITE( POSSCNT : 1);
                      WRITE( ')');
                      IF CHARACTR[ CHARI].POSS.POSSESS[ POSSI].CURSED THEN
                        WRITE( '-')
                      ELSE IF CHARACTR[ CHARI].POSS.POSSESS[ POSSI].IDENTIF
                                                                         THEN
                        WRITE( ' ')
                      ELSE
                        WRITE( '?');
                      IF CHARACTR[ CHARI].POSS.POSSESS[ POSSI].IDENTIF THEN
                        WRITELN( OBJECT.NAME)
                      ELSE
                        WRITELN( OBJECT.NAMEUNK);
                    END
                END
            END;
            
            TEMPX := 0;
            FOR POSSI := 1 TO POSSCNT DO
              IF CHARACTR[ CHARI].POSS.POSSESS[ OBJLIST[ POSSI]].CURSED THEN
                TEMPX := POSSI;
            IF TEMPX = 0 THEN
              EQUIPONE;
              
            TEMPX := 0;
            FOR POSSI := 1 TO POSSCNT DO
              IF CHARACTR[ CHARI].POSS.POSSESS[ OBJLIST[ POSSI]].CURSED THEN
                TEMPX := POSSI;
            IF TEMPX > 0 THEN
              BEGIN
                GOTOXY( 7, 23);
                CURSBELL( '** CURSED **');
                CHARACTR[ CHARI].POSS.POSSESS[ OBJLIST[ TEMPX]].EQUIPED :=
                                                                          TRUE;
                ARMORPOW( CHARI,
                          OBJLIST[ TEMPX],
                       CHARACTR[ CHARI].POSS.POSSESS[ OBJLIST[ TEMPX]].EQINDEX)
              END
        END;  (* DOEQUIP *)
        
        
      PROCEDURE UPLCKSKL( LSSUB:    INTEGER;  (* P010123 *)
                          LSMODAMT: INTEGER);
      
        BEGIN
          LSMODAMT := CHARACTR[ CHARI].LUCKSKIL[ LSSUB] - LSMODAMT;
          IF LSMODAMT < 1 THEN
            LSMODAMT := 1;
          CHARACTR[ CHARI].LUCKSKIL[ LSSUB] := LSMODAMT
        END;
        
        
      PROCEDURE INITSTUF;  (* P010124 *)
      
        VAR
             X : INTEGER;
             Y : INTEGER;
      
        BEGIN
          WITH CHARACTR[ CHARI] DO
            BEGIN
              FOR X := 0 TO 13 DO
                BEGIN
                  WEPVSTY2[ 0][ X] := FALSE;
                  WEPVSTY2[ 1][ X] := FALSE;
                  WEPVSTYP[ X] := FALSE
                END;
              FOR Y := 0 TO 6 DO
                BEGIN
                  WEPVSTY3[ 0][ Y] := FALSE;
                  WEPVSTY3[ 1][ Y] := FALSE
                END
            END
        END;
        
        
      BEGIN  (* EQUIPCHR *)
        WITH CHARACTR[ CHARI] DO
          BEGIN
            TEMPX := (20 - CHARLEV DIV 5) - (ATTRIB[ LUCK] DIV 6);
            IF TEMPX < 1 THEN
              TEMPX := 1;
            FOR LUCKI := 0 TO 4 DO
              LUCKSKIL[ LUCKI] := TEMPX;
              
            CASE CLASS OF
            
              FIGHTER :   UPLCKSKL( 0, 3);
                 MAGE :   UPLCKSKL( 4, 3);
               PRIEST :   UPLCKSKL( 1, 3);
                THIEF :   UPLCKSKL( 3, 3);
                
               BISHOP : BEGIN
                          UPLCKSKL( 2, 2);
                          UPLCKSKL( 4, 2);
                          UPLCKSKL( 1, 2);
                        END;
                        
              SAMURAI : BEGIN
                          UPLCKSKL( 0, 2);
                          UPLCKSKL( 4, 2);
                        END;
                        
                 LORD : BEGIN
                          UPLCKSKL( 0, 2);
                          UPLCKSKL( 1, 2);
                        END;
                          
                NINJA : BEGIN
                          UPLCKSKL( 0, 3);
                          UPLCKSKL( 1, 2);
                          UPLCKSKL( 2, 4);
                          UPLCKSKL( 3, 3);
                          UPLCKSKL( 4, 2);
                        END;
               
            END;
            
            CASE RACE OF
               HUMAN:  UPLCKSKL( 0, 1);
                 ELF:  UPLCKSKL( 2, 2);
               DWARF:  UPLCKSKL( 3, 4);
               GNOME:  UPLCKSKL( 1, 2);
              HOBBIT:  UPLCKSKL( 4, 3);
            END;
            
            IF NOT EQUIPALL THEN
              FOR TEMPX := 1 TO 8 DO
                POSS.POSSESS[ TEMPX].EQUIPED := FALSE;
            
            IF (CLASS = PRIEST) OR
               (CLASS = FIGHTER) OR
               (CLASS >= SAMURAI) THEN
              HPCALCMD := 2 + CHARLEV DIV 3
            ELSE
              HPCALCMD := CHARLEV DIV 5;
            
            HPDAMRC.LEVEL   := 2;
            HPDAMRC.HPFAC   := 2;
            HPDAMRC.HPMINAD := 0;
            
            IF ATTRIB[ STRENGTH] > 15 THEN
              BEGIN
                HPCALCMD := HPCALCMD + ATTRIB[ STRENGTH] - 15;
                HPDAMRC.HPMINAD := ATTRIB[ STRENGTH] - 15
              END
            ELSE
              IF ATTRIB[ STRENGTH] < 6 THEN
                HPCALCMD := HPCALCMD + ATTRIB[ STRENGTH] - 6;
            
            HEALPTS := 0;
            
            CRITHITM := CLASS = NINJA;
            
            SWINGCNT := 1;
            
            IF CLASS = NINJA THEN
              HPDAMRC.HPFAC := 4;
              
            ARMORCL := 10;
              
            IF (CLASS = FIGHTER) OR
               (CLASS >= SAMURAI) THEN
              SWINGCNT := SWINGCNT + (CHARLEV DIV 5) + ORD( (CLASS = NINJA)); 
              
            IF SWINGCNT > 10 THEN
              SWINGCNT := 10;
              
            INITSTUF;
            NORMPOW;
            UNARMED := TRUE
          END;
            
          IF NOT EQUIPALL THEN
            BEGIN
              FOR OBJI := WEAPON TO GAUNTLET DO
                DOEQUIP;
              OBJI := MISC;
              DOEQUIP;
              CHSPCPOW
            END
          ELSE
            ARM4CHAR;
          
          IF CHARACTR[ CHARI].CLASS = NINJA THEN
            IF UNARMED THEN
              CHARACTR[ CHARI].ARMORCL := (CHARACTR[ CHARI].ARMORCL -
                (CHARACTR[ CHARI].CHARLEV DIV 3)) - 2
      END;  (* EQUIPCHR *)



    PROCEDURE EQUIP6;  (* P010125 *)
    
      VAR
           PARTYX : INTEGER;
           
      BEGIN
        EQUIPALL := TRUE;
        FOR PARTYX := 0 TO (PARTYCNT - 1) DO
          EQUIPCHR( PARTYX);
        IF XGOTO = XEQUIP6 THEN
          XGOTO := XINSPCT2
        ELSE
          BEGIN
            XGOTO := XRUNNER;
            GRAPHICS
          END
      END;
      
      
    PROCEDURE EQUIP1( CHARX : INTEGER);  (* P010126 *)
    
      BEGIN
        EQUIPALL := FALSE;
        EQUIPCHR( CHARX);
        XGOTO := XBCK2CMP;
        LLBASE04 := CHARX
      END;
      
      

    PROCEDURE REORDER;  (* P010127 *)
    
      VAR
           SWITCH   : INTEGER;
           PARTYNUM : INTEGER;
           PARTYX   : INTEGER;
           CHARREC  : TCHAR;
           DONE     : BOOLEAN;
           LIST     : ARRAY[ 0..5] OF INTEGER;
           
      BEGIN
        XGOTO := XINSPCT2;
        IF PARTYCNT < 2 THEN
          EXIT( REORDER);
        GOTOXY( 0, 11);
        WRITE( CHR( 11));
        WRITE( 'REORDERING' :25);
        FOR PARTYX := 0 TO PARTYCNT - 1 DO
          BEGIN
            LIST[ PARTYX] := 99;
            GOTOXY( 0, 13 + PARTYX);
            WRITE( (PARTYX + 1) :1);
            WRITE( ')')
          END;
        FOR PARTYX := 0 TO PARTYCNT - 2 DO
          BEGIN
            REPEAT
              DONE := FALSE;
              GOTOXY( 1, 13 + PARTYX);
              WRITE( '   ');
              GOTOXY( 1, 13 + PARTYX);
              WRITE( '>>');
              GETKEY;
              PARTYNUM := ORD( INCHAR) - ORD( '1');
              IF (PARTYNUM >= 0) AND (PARTYNUM < PARTYCNT) THEN
                IF LIST[ PARTYNUM] = 99 THEN
                  BEGIN
                    LIST[ PARTYNUM] := PARTYX;
                    DONE := TRUE
                  END
            UNTIL DONE;
            GOTOXY( 1, 13 + PARTYX);
            WRITE( ') ');
            WRITE( CHARACTR[ PARTYNUM].NAME)
          END;
        FOR PARTYX := 0 TO PARTYCNT - 2 DO
          FOR PARTYNUM := PARTYX + 1 TO PARTYCNT - 1 DO
            IF LIST[ PARTYNUM] < LIST[ PARTYX] THEN
              BEGIN
                CHARREC := CHARACTR[ PARTYX];
                CHARACTR[ PARTYX] := CHARACTR[ PARTYNUM];
                CHARACTR[ PARTYNUM] := CHARREC;
                SWITCH := CHARDISK[ PARTYX];
                CHARDISK[ PARTYX] := CHARDISK[ PARTYNUM];
                CHARDISK[ PARTYNUM] := SWITCH;
                SWITCH := LIST[ PARTYX];
                LIST[ PARTYX] := LIST[ PARTYNUM];
                LIST[ PARTYNUM] := SWITCH
              END;
        GOTOXY( 1, 13 + PARTYCNT - 1);
        WRITE( ') ');
        WRITE( CHARACTR[ PARTYCNT - 1].NAME)
      END; (* REORDER *)


  BEGIN (* UTILITIE *)
  
    IF XGOTO <> XNEWMAZE THEN
      TEXTMODE;
      
    CASE XGOTO OF
    
      XCAMPSTF:
                CASE BASE12.GOTOX OF
                  XDONE    : RDSPELLS;
                  XTRAININ : IDITEM;
                  XCASTLE  : KANDIFND;
                  XGILGAMS : DUMAPIC;
                  XINSPECT : MALOR_PROC;
                END;
        
      XNEWMAZE:  NEWMAZE;
      
      XEQUIP6,
      XCMP2EQ6:  EQUIP6;
      
      XREORDER:  REORDER;
      
      XEQPDSP:   IF LLBASE04 >= 0 THEN
                   EQUIP1( LLBASE04)
                 ELSE
                   BEGIN
                     FOR CHARI := 0 TO PARTYCNT - 1 DO
                       EQUIP1( CHARI);
                     XGOTO := XINSPCT2
                   END;
    END;

  END; (* UTILITIE *)
