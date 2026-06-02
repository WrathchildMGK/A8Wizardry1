SEGMENT PROCEDURE RUNNER;     (* P010E01 *)
  
    CONST
         NORTH = 0;
         EAST  = 1;
         SOUTH = 2;
         WEST  = 3;
  
    VAR
         QUICKPLT : BOOLEAN;
         INITTURN : BOOLEAN;
         NEEDDRMZ : BOOLEAN;
         MAZE     : TMAZE;
         
         
    PROCEDURE DRAWMAZE;  (* P010E02 *)
    
      VAR
           GOTLIGHT : BOOLEAN;
           WALHEIGH : INTEGER;
           DOORFRAM : INTEGER;
           DOORWIDT : INTEGER; (* 1/2 DOOR WIDTH *)
           WALWIDTH : INTEGER; (* 1/2 WALL WIDTH *)
           
           (* IMAGINE A SMALLER BOX DRAWN INSIDE AN OUTER BOX.  THE OUTER BOX
              HAS UPPER LEFT CORNER AS 0,0 AND LOWER RIGHT CORNER AS 81,78.
              THE INSIDE BOX HAS COORDINATES (UL, UL) AND (LR, LR).       *)
              
           LR  : INTEGER; (* LOWER RIGHT INNER BOX BOUNDARY *)
           UL  : INTEGER; (* UPPER LEFT  INNER BOX BOUNDARY *)
           
           SQREDESC : INTEGER;
           XUPPER   : INTEGER;
           XLOWER   : INTEGER;
           
           Y4DRAW   : INTEGER;
           X4DRAW   : INTEGER;
           LIGHTDIS : INTEGER;
           WALLTYPE : TWALL;
    
        
      PROCEDURE SHFTPOS( VAR X:        INTEGER;  (* P010E03 *)
                         VAR Y:        INTEGER;
                             RIGHSHFT: INTEGER;
                             FRWDSHFT: INTEGER);
      
        BEGIN
          CASE DIRECTIO OF
            NORTH:  BEGIN
                      X := X + RIGHSHFT;
                      Y := Y + FRWDSHFT
                    END;
                    
             EAST:  BEGIN
                      X := X + FRWDSHFT;
                      Y := Y - RIGHSHFT
                    END;
                    
            SOUTH:  BEGIN
                      X := X - RIGHSHFT;
                      Y := Y - FRWDSHFT
                    END;
                    
             WEST:  BEGIN
                      X := X - FRWDSHFT;
                      Y := Y + RIGHSHFT
                    END;
          END;
          X := (X + 20) MOD 20;
          Y := (Y + 20) MOD 20
        END;  (* SHFTPOS *)
        
        
      
        FUNCTION FRWDVIEW( DELTAR: INTEGER) : TWALL;  (* P010E04 *)
        
          VAR
               Y : INTEGER;
               X : INTEGER;
               
          BEGIN
            X := X4DRAW;
            Y := Y4DRAW;
            SHFTPOS( X, Y, DELTAR, 0);
            CASE DIRECTIO OF
              NORTH:  FRWDVIEW := MAZE.N[ X][ Y];
               EAST:  FRWDVIEW := MAZE.E[ X][ Y];
              SOUTH:  FRWDVIEW := MAZE.S[ X][ Y];
               WEST:  FRWDVIEW := MAZE.W[ X][ Y];
            END
          END;  (* FRWDVIEW *)
          
          
        FUNCTION LEFTVIEW( DELTAR: INTEGER) : TWALL;  (* P010E05 *)
        
          VAR
               Y : INTEGER;
               X : INTEGER;
               
          BEGIN
            X := X4DRAW;
            Y := Y4DRAW;
            SHFTPOS( X, Y, DELTAR, 0);
            CASE DIRECTIO OF
              NORTH:  LEFTVIEW := MAZE.W[ X][ Y];
               EAST:  LEFTVIEW := MAZE.N[ X][ Y];
              SOUTH:  LEFTVIEW := MAZE.E[ X][ Y];
               WEST:  LEFTVIEW := MAZE.S[ X][ Y];
            END
          END;  (* LEFTVIEW *)
          
          
        FUNCTION RIGHVIEW( DELTAR: INTEGER) : TWALL;  (* P010E06 *) 
        
          VAR
               Y : INTEGER;
               X : INTEGER;
               
          BEGIN
            X := X4DRAW;
            Y := Y4DRAW;
            SHFTPOS( X, Y, DELTAR, 0);
            CASE DIRECTIO OF
              NORTH:  RIGHVIEW := MAZE.E[ X][ Y];
               EAST:  RIGHVIEW := MAZE.S[ X][ Y];
              SOUTH:  RIGHVIEW := MAZE.W[ X][ Y];
               WEST:  RIGHVIEW := MAZE.N[ X][ Y];
            END
          END;  (* RIGHVIEW *)
          
          
        PROCEDURE DRAWLEFT;  (* P010E07 *)
        
          BEGIN
            XLOWER := UL;
            DRAWLINE( UL, UL, -1, -1, WALWIDTH);             (* TOP EDGE *)
            DRAWLINE( UL, UL,  0,  1, WALHEIGH);             (* RIGHT EDGE *)
            DRAWLINE( UL, LR, -1,  1, WALWIDTH);             (* BOTTOM EDGE *)
            DRAWLINE( UL - WALWIDTH, UL - WALWIDTH,          (* LEFT EDGE *)
                               0,  1, WALHEIGH + WALHEIGH);
            IF (WALLTYPE = OPEN) OR
               (WALLTYPE = WALL) OR 
               ((WALLTYPE = HIDEDOOR) AND
                (NOT GOTLIGHT AND ((RANDOM MOD 6) <> 3))) THEN
              EXIT( DRAWLEFT);
              
            (* DRAW THE DOOR:  TOP, RIGHT, LEFT *)
              
            DRAWLINE( UL - DOORFRAM, UL, -1, -1, DOORWIDT);
            DRAWLINE( UL - DOORFRAM, UL,  0,  1, WALHEIGH + DOORFRAM);
            DRAWLINE( UL - DOORFRAM - DOORWIDT, UL - DOORWIDT, 0, 1,
                        WALHEIGH + WALWIDTH + DOORFRAM)
          END;
          
          
        PROCEDURE DRAWRIGH;  (* P010E08 *)
        
          BEGIN
            XUPPER := LR;
            DRAWLINE( LR, UL, 1, -1, WALWIDTH);
            DRAWLINE( LR, UL, 0,  1, WALHEIGH);
            DRAWLINE( LR, LR, 1,  1, WALWIDTH);
            DRAWLINE( LR + WALWIDTH, UL - WALWIDTH,
                              0,  1, WALHEIGH + WALHEIGH);
            IF (WALLTYPE = OPEN) OR
               (WALLTYPE = WALL) OR 
               ((WALLTYPE = HIDEDOOR) AND
                (NOT GOTLIGHT AND ((RANDOM MOD 6) <> 3))) THEN
              EXIT( DRAWRIGH);
              
            (* DRAW THE DOOR *)
              
            DRAWLINE( LR + DOORFRAM, UL, 1, -1, DOORWIDT);
            DRAWLINE( LR + DOORFRAM, UL, 0,  1,
                      WALHEIGH + DOORFRAM);
            DRAWLINE( LR + DOORFRAM + DOORWIDT, UL - DOORWIDT,
                                         0,  1, WALHEIGH + WALWIDTH + DOORFRAM)
          END;
          
          
        PROCEDURE DRAWFRNT( FRNTWALL : TWALL; LRCENT : INTEGER); (* P010E09 *)
        
        
          (* DRAW FRONT FACING WALL PANEL:  TOP, LEFT, RIGHT, BOTTOM.
             (WHY DOES RIGHT EDGE HAVE +1 FOR LENGTH???)              *)
        
          BEGIN
            DRAWLINE( UL + LRCENT, UL,            1, 0, WALHEIGH);
            DRAWLINE( UL + LRCENT, UL,            0, 1, WALHEIGH);
            DRAWLINE( UL + LRCENT + WALHEIGH, UL, 0, 1, WALHEIGH + 1);
            DRAWLINE( UL + LRCENT, UL + WALHEIGH, 1, 0, WALHEIGH);
            IF (FRNTWALL = OPEN) OR
               (FRNTWALL = WALL) OR 
               ((FRNTWALL = HIDEDOOR) AND
                (NOT GOTLIGHT AND ((RANDOM MOD 6) <> 3))) THEN
              EXIT( DRAWFRNT);
              
            (* DRAW DOOR:  LEFT, RIGHT, TOP *)
             
            DRAWLINE( UL + LRCENT + DOORFRAM, LR,
                        0, -1, WALWIDTH + DOORWIDT + DOORFRAM);
                        
            DRAWLINE( UL + LRCENT + WALWIDTH + DOORWIDT + DOORFRAM, LR,
                        0, -1, WALWIDTH + DOORWIDT + DOORFRAM);
                        
            DRAWLINE( UL + LRCENT + DOORFRAM,
                        LR - WALWIDTH - DOORWIDT- DOORFRAM,
                        1,  0, WALWIDTH + DOORWIDT + 1)
          END;
          
        
      BEGIN (* DRAWMAZE *)
        GOTLIGHT := LIGHT > 0;
        IF GOTLIGHT THEN
          BEGIN
            IF QUICKPLT THEN
              LIGHTDIS := 3
            ELSE
                LIGHTDIS := 5;
            LIGHT := LIGHT - 1
          END
        ELSE
          LIGHTDIS := 2;
        
        UL :=  8;
        LR := 72;
        WALWIDTH := 32;
        DOORWIDT := 16;
        DOORFRAM :=  8;
        WALHEIGH := 64;
        
        X4DRAW := MAZEX;
        Y4DRAW := MAZEY;
        CLEARPIC;
        XLOWER := 0;
        XUPPER := 81;
        WHILE LIGHTDIS > 0 DO
          BEGIN
            SQREDESC := MAZE.SQREXTRA[ X4DRAW][ Y4DRAW];
            IF MAZE.SQRETYPE[ SQREDESC] = DARK THEN
              EXIT( DRAWMAZE)
            ELSE
              IF MAZE.SQRETYPE[ SQREDESC] = TRANSFER THEN
                IF MAZE.AUX0[ SQREDESC] = MAZELEV THEN
                  BEGIN
                    X4DRAW := MAZE.AUX2[ SQREDESC];
                    Y4DRAW := MAZE.AUX1[ SQREDESC]
                  END;
            
            CLRPICT( XLOWER, 0, XUPPER, 79);
            
              (* $0679 := XLOWER
                 $06F9 := 0
                 $0779 := XUPPER
                 $07F9 := 79
                 
                 THESE MEMORY LOCATIONS ARE ACCESSED BY DRAWLINE.
                 
                 WITH THESE PARAMETERS, THERE IS NO PICTURE CLEARING. *)
            
            WALLTYPE := LEFTVIEW( 0);
            IF WALLTYPE <> OPEN THEN
                DRAWLEFT
            ELSE
              BEGIN
                WALLTYPE := FRWDVIEW( -1);  (* STEP LEFT ONE SQUARE *)
                IF WALLTYPE <> OPEN THEN
                  BEGIN
                    DRAWFRNT( WALLTYPE, -( 2 * WALWIDTH));
                    XLOWER := UL
                  END;
              END;
            
            WALLTYPE := RIGHVIEW( 0);
            IF WALLTYPE <> OPEN THEN
              DRAWRIGH
            ELSE
              BEGIN
                WALLTYPE := FRWDVIEW( 1);  (* STEP RIGHT ONE SQUARE *)
                IF WALLTYPE <> OPEN THEN
                  BEGIN
                    DRAWFRNT( WALLTYPE, 2 * WALWIDTH);
                    XUPPER := LR
                  END;
              END;
            
            WALLTYPE := FRWDVIEW( 0);
            IF WALLTYPE <> OPEN THEN
              BEGIN
                DRAWFRNT( WALLTYPE, 0);
                EXIT( DRAWMAZE)
              END;
            
            WALWIDTH := WALWIDTH DIV 2;
            DOORWIDT := WALWIDTH DIV 2;
            WALHEIGH := WALWIDTH * 2;
            DOORFRAM := WALWIDTH DIV 4;
            UL := UL + WALWIDTH;
            LR := LR - WALWIDTH;
            
            SHFTPOS( X4DRAW, Y4DRAW, 0, 1);  (* STEP FORWARD *)
            LIGHTDIS := LIGHTDIS - 1
              
          END; (* WHILE *)
      END;  (* DRAWMAZE *)
    PROCEDURE READMAZE;  (* P010E0A *)
    
      BEGIN
        MOVELEFT( IOCACHE[ GETREC( ZMAZE, MAZELEV - 1, SIZEOF( TMAZE))],
                  MAZE,
                  SIZEOF( TMAZE))
      END;
      
    
    PROCEDURE PRSTATS;  (* P010E0B *)
    
      VAR
          SAVE1    : INTEGER;
          TEMPX    : INTEGER;  (* MULTIPLE USES *)
          CHARX    : INTEGER;
          CHARREC  : TCHAR;
          ANYALIVE : BOOLEAN;
    
    
      PROCEDURE PRSTATUS;  (* P010E0C *)
      
        BEGIN
          IF CHARACTR[ CHARX].STATUS = OK THEN
            BEGIN
              ANYALIVE := TRUE;
              IF CHARACTR[ CHARX].LOSTXYL.POISNAMT[ 1] = 0 THEN
                PRINTNUM( CHARACTR[ CHARX].HPMAX, 4)
              ELSE
                PRINTSTR( 'POISON')
            END
          ELSE
            PRINTSTR( SCNTOC.STATUS[ CHARACTR[ CHARX].STATUS])
        END;  (* PRSTATUS *)
        
        
      BEGIN  (* PRSTATS *)
        FOR CHARX := 0 TO PARTYCNT - 2 DO
          BEGIN
            FOR TEMPX := CHARX + 1 TO PARTYCNT - 1 DO
              BEGIN
                IF CHARACTR[ CHARX].STATUS > CHARACTR[ TEMPX].STATUS THEN
                  BEGIN
                    CHARREC := CHARACTR[ CHARX];
                    CHARACTR[ CHARX] := CHARACTR[ TEMPX];
                    CHARACTR[ TEMPX] := CHARREC;
                    
                    SAVE1 := CHARDISK[ CHARX];
                    CHARDISK[ CHARX] := CHARDISK[ TEMPX];
                    CHARDISK[ TEMPX] := SAVE1
                  END
              END;
          END;
          
        CLRRECT( 1, 17, 38, 6);
      
        ANYALIVE := FALSE;
        FOR CHARX := 0 TO PARTYCNT - 1 DO
          BEGIN
          
            WITH CHARACTR[ CHARX] DO
              BEGIN
                MVCURSOR( 1, 17 + CHARX);
                PRINTNUM( CHARX + 1, 1);
                PRINTSTR( ' ');
                PRINTSTR( NAME);
                MVCURSOR( 19, 17 + CHARX);
                PRINTSTR( COPY( SCNTOC.ALIGN[ CHARACTR[ CHARX].ALIGN], 1, 1));
                PRINTCHR( '-');
                PRINTSTR( COPY( SCNTOC.CLASS[ CLASS], 1, 3));
                LLBASE04 := ARMORCL - ACMOD2;
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
                IF STATUS >= DEAD THEN
                  HPLEFT := 0;
                  
                PRINTNUM( HPLEFT, 5);
                TEMPX := CHARACTR[ CHARX].HEALPTS -
                           CHARACTR[ CHARX].LOSTXYL.POISNAMT[ 1];
                IF TEMPX = 0 THEN
                  PRINTCHR( ' ')
                ELSE IF TEMPX < 0 THEN
                  PRINTCHR( '-')
                ELSE
                  PRINTCHR( '+');
                PRSTATUS;
              END;  (* 'WITH' *)
          END;  (* 'FOR' *)
              
          IF NOT ANYALIVE THEN
            BEGIN
              XGOTO := XCEMETRY;
              EXIT( RUNNER)
            END
          
      END;   (* PRSTATS *)
      
      
      
    PROCEDURE ENCOUNTR;  (* P010E0D *)
    
      VAR
           ENCTYPE  : INTEGER;
           ENEMYI   : INTEGER;
           ENCCALC  : INTEGER;
    
      BEGIN
        ENCB4RUN := TRUE;
        CLRRECT( 1, 11, 38, 4);
        MVCURSOR( 14, 12);
        PRINTSTR( 'AN ENCOUNTER');
        ENCTYPE := 1;
        WHILE ((RANDOM MOD 4) = 2) AND (ENCTYPE < 3) DO
          ENCTYPE := ENCTYPE + 1;
        WITH MAZE.ENMYCALC[ ENCTYPE] DO
          BEGIN
            ENCCALC := 0;
            WHILE ((RANDOM MOD 100) < PERCWORS) AND
                   (ENCCALC < WORSE01) DO
              ENCCALC := ENCCALC + 1;
            ENEMYI := MINENEMY +
                        (RANDOM MOD RANGE0N) +
                        (MULTWORS * ENCCALC);
            IF CHSTALRM = 1 THEN
              ATTK012 := 2
            ELSE
              IF MAZE.FIGHTS[ MAZEX][ MAZEY] = 1 THEN
                IF FIGHTMAP[ MAZEX][ MAZEY] THEN
                  ATTK012 := 2
                ELSE
                  ATTK012 := 1
              ELSE
                ATTK012 := 0;
            ENEMYINX := ENEMYI;
            XGOTO := XCOMBAT;
            EXIT( RUNNER)
          END
      END;  (* ENCOUNTR *)
      
      
    PROCEDURE RUNMAIN;  (* P010E0E *)
    
    
      PROCEDURE EXITRUN( MAZELVL: INTEGER);  (* P010E0F *)
      
        BEGIN
          MAZELEV := MAZELVL;
          CLEARPIC;
          XGOTO := XNEWMAZE;
          EXIT( RUNNER)
        END;  (* EXITRUN *)
        
        
      PROCEDURE SPECSQAR;  (* P010E10 *)
      
        VAR
             SQTYPE : INTEGER;
      
      
        PROCEDURE SPINDIR;  (* P010E11 *)
        
          BEGIN
            DIRECTIO := RANDOM MOD 4;
            DRAWMAZE
          END;
          
          
        PROCEDURE QUIETXFR;  (* P010E12 *)
        
          BEGIN
            MAZEX := MAZE.AUX2[ SQTYPE];
            MAZEY := MAZE.AUX1[ SQTYPE];
            IF MAZELEV <> MAZE.AUX0[ SQTYPE] THEN
              EXITRUN( MAZE.AUX0[ SQTYPE])
          END;  (* QUIETXFR *)
          
          
        PROCEDURE ACHUTE;  (* P010E13 *)
        
          BEGIN
            PRINTSTR( 'A CHUTE!');
            QUIETXFR
          END;
          
          
        PROCEDURE STAIRSYN;  (* P010E14 *)
        
          BEGIN
            PRINTSTR( 'STAIRS GOING ');
            IF MAZELEV > MAZE.AUX0[ SQTYPE] THEN
              PRINTSTR( 'UP.')
            ELSE
              PRINTSTR( 'DOWN.');
            MVCURSOR( 1, 12);
            PRINTSTR( 'TAKE THEM (Y/N) ?');
            REPEAT
              GETKEY
            UNTIL (INCHAR = 'Y') OR (INCHAR = 'N');
            IF INCHAR = 'Y' THEN
              QUIETXFR
          END;  (* STAIRSYN *)
          
          
        PROCEDURE VERYDARK;  (* P010E15 *)
        
          BEGIN
            MVCURSOR( 2, 5);
            PRINTSTR( 'IT''S VERY');
            MVCURSOR( 2, 6);
            PRINTSTR( 'DARK HERE');
            LIGHT := 0
          END;  (* VERYDARK *)
          
          
        PROCEDURE ROCKWATR;  (* P010E16 *)
        
          VAR
               HPDAM   : INTEGER;
               HPTIMES : INTEGER;
               PARTYI  : INTEGER;
            
          BEGIN (* ROCKWATR *)
            WRITE( CHR( 7));
            PAUSE2;
            FOR PARTYI := 0 TO PARTYCNT - 1 DO
              BEGIN
                IF CHARACTR[ PARTYI].STATUS < DEAD THEN
                  BEGIN
                    IF ((RANDOM MOD 25) + MAZELEV) > 
                       CHARACTR[ PARTYI].ATTRIB[ AGILITY] THEN
                      BEGIN
                        HPDAM := MAZE.AUX0[ SQTYPE];
                        FOR HPTIMES := 1 TO MAZE.AUX2[ SQTYPE] DO
                          HPDAM := HPDAM + (RANDOM MOD MAZE.AUX1[ SQTYPE]) + 1;
                        CHARACTR[ PARTYI].HPLEFT := CHARACTR[ PARTYI].HPLEFT -
                                                                         HPDAM;
                        IF CHARACTR[ PARTYI].HPLEFT < 0 THEN
                          BEGIN
                            CHARACTR[ PARTYI].HPLEFT := 0;
                            CHARACTR[ PARTYI].STATUS := DEAD;
                            CLRRECT( 1, 11, 38, 1);
                            MVCURSOR( 1, 11);
                            PRINTSTR( CHARACTR[ PARTYI].NAME);
                            PRINTSTR( ' DIED');
                            PAUSE2
                          END;
                      END;
                  END;
              END;
            PRSTATS
          END;  (* ROCKWATR *)
        
          
        PROCEDURE APIT;  (* P010E17 *)
        
          BEGIN
            PRINTSTR( 'A PIT!');
            ROCKWATR
          END;
          
          
        PROCEDURE OUCH;  (* P010E18 *)
        
          BEGIN
            PRINTSTR( 'OUCH!');
            ROCKWATR
          END;
          
          
        PROCEDURE DOSCNMSG;  (* P010E19 *)
        
          BEGIN
            LLBASE04 := SQTYPE;
            XGOTO := XSCNMSG;
            XGOTO2 := XRUNNER;
            EXIT( RUNNER)
          END;  (* DOSCNMSG *)
          
          
        PROCEDURE CHENCOUN;  (* P010E1A *)
        
          VAR
               UNUSEDXX : INTEGER;
               UNUSEDYY : INTEGER;
        
          BEGIN
            IF MAZE.AUX0[ SQTYPE] = 0 THEN
              EXIT( CHENCOUN);
            IF NOT FIGHTMAP[ MAZEX][ MAZEY] THEN
              EXIT( CHENCOUN);
            MVCURSOR( 14, 12);
            PRINTSTR( 'AN ENCOUNTER');
            ENCB4RUN := FALSE;
            ATTK012 := 2;
            XGOTO := XCOMBAT;
            ENEMYINX := MAZE.AUX2[ SQTYPE];
            IF MAZE.AUX1[ SQTYPE] > 1 THEN
              ENEMYINX := ENEMYINX + (RANDOM MOD MAZE.AUX1[ SQTYPE]);
            IF MAZE.AUX0[ SQTYPE] > 0 THEN
              BEGIN
                MAZE.AUX0[ SQTYPE] := MAZE.AUX0[ SQTYPE] - 1;
                IF MAZE.AUX0[ SQTYPE] = 0 THEN
                  MAZE.SQRETYPE[ SQTYPE] := NORMAL;
                MOVELEFT( MAZE,  
                          IOCACHE[ GETRECW( ZMAZE, MAZELEV - 1, SIZEOF( TMAZE))],
                          SIZEOF( TMAZE));
              END;
            EXIT( RUNNER)
          END;  (* CHENCOUN *)
          
          
        PROCEDURE BUTTONS;  (* P010E1B *)
        
          VAR
               MAXBUT   : INTEGER;
               MINBUT   : INTEGER;
               UNUSEDXX : INTEGER;
               UNUSEDYY : INTEGER;
               
          BEGIN
            MINBUT := MAZE.AUX2[ SQTYPE];
            MAXBUT := MAZE.AUX1[ SQTYPE];
            PRINTSTR( 'THERE ARE BUTTONS ON THE WALL');
            MVCURSOR( 1, 12);
            PRINTSTR( 'MARKED A THROUGH ');
            PRINTCHR( CHR( ORD('A') + MAXBUT - MINBUT));
            PRINTCHR( '.');
            MVCURSOR( 1, 14);
            PRINTSTR( 'PRESS ONE (OR RETURN TO LEAVE THEM)');
            REPEAT
              GETKEY
            UNTIL (INCHAR = CHR( CRETURN)) OR 
                  ( (INCHAR >= 'A') AND 
                    (INCHAR <= CHR( ORD('A') + MAXBUT - MINBUT)));
            CLRRECT( 1, 11, 38, 4);
            IF INCHAR = CHR( CRETURN) THEN
              EXIT( BUTTONS);
            IF MAZE.AUX0[ SQTYPE] > 0 THEN
              BEGIN
                MAZEX := RANDOM MOD 20;
                MAZEY := RANDOM MOD 20
              END;
            EXITRUN( MINBUT + ORD( INCHAR) - ORD( 'A'))
          END;  (* BUTTONS *)
          
          
        BEGIN  (* SPECSQAR *)
          CLRRECT( 1, 11, 38, 4);
          MVCURSOR( 1, 11);
          SQTYPE := MAZE.SQREXTRA[ MAZEX][ MAZEY];
          FIZZLES := 0;
          NEEDDRMZ:= TRUE;
          CASE MAZE.SQRETYPE[ SQTYPE] OF
          
              FIZZLE:  FIZZLES := 1;
              
            ROCKWATE:  BEGIN
                         MAZELEV := -99;
                         XGOTO := XNEWMAZE;
                         EXIT( RUNNER)
                       END;
                       
             BUTTONZ:  BUTTONS;
             
              STAIRS:  IF INITTURN THEN
                         STAIRSYN;
                         
                 PIT:  IF INITTURN THEN
                         APIT;
                         
               OUCHY:  OUCH;
               
               CHUTE:  ACHUTE;
               
             SPINNER:  IF INITTURN THEN
                         SPINDIR;
            TRANSFER:  QUIETXFR;
            
                DARK:  VERYDARK;
                
              SCNMSG:  DOSCNMSG;
              
            ENCOUNTE:  CHENCOUN;
          END
        END;   (* SPECSQAR *)
      

    PROCEDURE UPDATEHP;  (* P010E1C *)
    
      VAR
           UNUSEDXX : INTEGER;
           CHARX    : INTEGER;
           
      BEGIN
        FOR CHARX := 0 TO PARTYCNT - 1 DO
          WITH CHARACTR[ CHARX] DO
            BEGIN
            
              IF (RANDOM MOD 4) = 2 THEN
                HPLEFT := HPLEFT - LOSTXYL.POISNAMT[ 1] + HEALPTS;
              IF HPLEFT <= 0 THEN
                BEGIN
                  LOSTXYL.POISNAMT[ 1] := 0;
                  IF STATUS < DEAD THEN
                    BEGIN
                      MVCURSOR( 1, 11);
                      PRINTSTR( NAME);
                      PRINTSTR( ' DIED');
                      PAUSE2;
                      CLRRECT( 1, 11, 38, 1);
                      HPLEFT := 0;
                      STATUS := DEAD;
                      PRSTATS
                    END
                END
              ELSE
                IF HPLEFT > HPMAX THEN
                  HPLEFT := HPMAX
            END
      END;  (* UPDATEHP *)
      
      
      PROCEDURE MOVEFRWD;  (* P010E1D *)
      
        BEGIN
          NEEDDRMZ := TRUE;
          INITTURN := TRUE;
          SAVEX    := MAZEX;
          SAVEY    := MAZEY;
          SAVELEV  := MAZELEV;
          CASE DIRECTIO OF
            NORTH:  MAZEY := MAZEY + 1;
             EAST:  MAZEX := MAZEX + 1;
            SOUTH:  MAZEY := MAZEY - 1;
             WEST:  MAZEX := MAZEX - 1;
          END;
          MAZEY := (MAZEY + 20) MOD 20;
          MAZEX := (MAZEX + 20) MOD 20
        END;  (* MOVEFRWD *)
        
        
      PROCEDURE BUMPWALL;  (* P010E1E *)
      
        BEGIN
          CLRRECT( 4, 3, 5, 1);
          MVCURSOR( 4, 3);
          PRINTSTR( 'OUCH!');
          WRITE( CHR( 7))
        END;
        
        
      PROCEDURE FORWRD;  (* P010E1F *)
      
        BEGIN
          CASE DIRECTIO OF
            NORTH:  IF MAZE.N[ MAZEX][ MAZEY] = OPEN THEN
                      MOVEFRWD;
                      
             EAST:  IF MAZE.E[ MAZEX][ MAZEY] = OPEN THEN
                      MOVEFRWD;
                      
            SOUTH:  IF MAZE.S[ MAZEX][ MAZEY] = OPEN THEN
                      MOVEFRWD;
                      
             WEST:  IF MAZE.W[ MAZEX][ MAZEY] = OPEN THEN
                      MOVEFRWD;
          END;
          IF NOT INITTURN THEN
            BUMPWALL
        END;  (* FORWRD *)
        
        
      PROCEDURE KICK;  (* P010E20 *)
      
        BEGIN
          CASE DIRECTIO OF
            NORTH:  IF MAZE.N[ MAZEX][ MAZEY] <> WALL THEN
                      MOVEFRWD;
                      
             EAST:  IF MAZE.E[ MAZEX][ MAZEY] <> WALL THEN
                      MOVEFRWD;
                      
            SOUTH:  IF MAZE.S[ MAZEX][ MAZEY] <> WALL THEN
                      MOVEFRWD;
                      
             WEST:  IF MAZE.W[ MAZEX][ MAZEY] <> WALL THEN
                      MOVEFRWD;
          END;
          IF NOT INITTURN THEN
            BUMPWALL
        END;  (* KICK *)
        
        
      PROCEDURE DOTURN( LEFTRIGH: INTEGER);  (* P010E21 *)
      
        BEGIN
          NEEDDRMZ := TRUE;
          DIRECTIO := (DIRECTIO + LEFTRIGH) MOD 4
        END;
        
        
      PROCEDURE SETTIME;  (* P010E22 *)
      
        VAR
             TIMEVAL : INTEGER;
             TIMESTR : STRING;
      
        PROCEDURE EXITTIME;  (* P010E23 *)
        
          BEGIN
            CLRRECT( 1, 13, 38, 1);
            EXIT( SETTIME)
          END;
          
          
        BEGIN  (* SETTIME *)
          MVCURSOR( 1, 13);
          PRINTSTR( 'NEW DELAY (1-5000) >');
          GETSTR( TIMESTR, 21, 13);
          TIMEVAL := 0;
          IF LENGTH( TIMESTR) > 4 THEN
            EXITTIME;
          FOR LLBASE04 := 1 TO LENGTH( TIMESTR) DO
            IF (TIMESTR[ LLBASE04] >= '0') AND
               (TIMESTR[ LLBASE04] <= '9') THEN
              TIMEVAL := 10 * TIMEVAL + ORD( TIMESTR[ LLBASE04]) - ORD( '0')
            ELSE
              EXITTIME;
          IF (TIMEVAL > 0) AND
             (TIMEVAL <= 5000) THEN
               TIMEDLAY := TIMEVAL;
          EXITTIME
        END;  (* SETTIME *)
        
        
      PROCEDURE QUIKPLOT;  (* P010E24 *)
      
        BEGIN
          MVCURSOR( 1, 13);
          PRINTSTR( 'QUICK PLOT ');
          QUICKPLT := NOT QUICKPLT;
          IF QUICKPLT THEN
            PRINTSTR( 'ON')
          ELSE
            PRINTSTR( 'OFF');
          DRAWMAZE;
          CLRRECT( 1, 13, 38, 1)
        END;
        
        
      PROCEDURE RUNINIT;  (* P010E25 *)
      
        BEGIN
          CLRRECT( 13, 1, 26, 4);
          CLRRECT( 13, 6, 26, 4);
          MVCURSOR( 13, 1);
          PRINTSTR( 'F)ORWARD  C)AMP    S)TATUS');
          MVCURSOR( 13, 2);
          PRINTSTR( 'L)EFT     Q)UICK   A<-W->D');
          MVCURSOR( 13, 3);
          PRINTSTR( 'R)IGHT    T)IME    CLUSTER');
          MVCURSOR( 13, 4);
          PRINTSTR( 'K)ICK     I)NSPECT');
          MVCURSOR( 13, 7);
          PRINTSTR( 'SPELLS :');
          GRAPHICS;
          PRSTATS;
          NEEDDRMZ := TRUE;
          INITTURN := TRUE
        END;  (* RUNINIT *)
    
    
      BEGIN (* RUNMAIN *)
        RUNINIT;
        REPEAT
          MVCURSOR( 22, 7);
          IF LIGHT > 0 THEN
            PRINTSTR( 'LIGHT')
          ELSE
            PRINTSTR( '     ');
            
          MVCURSOR( 22, 8);
          IF ACMOD2 > 0 THEN
            PRINTSTR( 'PROTECT')
          ELSE
            PRINTSTR( '       ');
            
          IF NEEDDRMZ THEN
            DRAWMAZE;
          IF MAZE.SQRETYPE[ MAZE.SQREXTRA[ MAZEX][ MAZEY]] <> NORMAL THEN
            IF XGOTO2 <> XSCNMSG THEN
              IF INITTURN THEN
                SPECSQAR;
          IF XGOTO2 <> XSCNMSG THEN
            IF INITTURN THEN
              CLRRECT( 1, 11, 38, 4);
          XGOTO2 := XRUNNER;
          NEEDDRMZ := FALSE;
          
          IF (((RANDOM MOD 99) = 35)      OR
              (CHSTALRM = 1)              OR
              (FIGHTMAP[ MAZEX][ MAZEY])) OR
             
             (INITTURN AND (INCHAR = CHR( 75)) AND
             (MAZE.FIGHTS[ MAZEX][ MAZEY] = 1)) AND
             ((RANDOM MOD 8) = 3)
          THEN
            ENCOUNTR;
            
          IF INITTURN THEN
            UPDATEHP;
          INITTURN := FALSE;
          
          GETKEY;
          CASE INCHAR OF
          
            'F', 'W':  FORWRD;
            
            'A', 'L':  DOTURN( 3);
            
            'D', 'R':  DOTURN( 1);
            
                 'K':  KICK;
                 
                 'S':  PRSTATS;
                 
                 'T':  SETTIME;
                 
                 'Q':  QUIKPLOT;
                 
                 'C':  BEGIN
                         XGOTO := XINSPCT2;
                         WRITE( CHR( 12));
                         EXIT( RUNNER)
                       END;
                       
                 'I':  BEGIN
                         XGOTO := XINSAREA;
                         WRITE( CHR( 12));
                         EXIT( RUNNER)
                       END;
          END
        UNTIL FALSE
      END;  (* RUNMAIN *)
      
      
    PROCEDURE CLROOMFG( XLOOP: INTEGER;  (* P010026 *)
                        YLOOP: INTEGER);
    
           
      BEGIN  (* CLROOMFG *)
        XLOOP := (XLOOP + 20) MOD 20;
        YLOOP := (YLOOP + 20) MOD 20;
        IF NOT FIGHTMAP[ XLOOP][ YLOOP] THEN
          EXIT( CLROOMFG);
          
        FIGHTMAP[ XLOOP][ YLOOP] := FALSE;
        
        IF MAZE.N[ XLOOP][ YLOOP] = OPEN THEN
          CLROOMFG( XLOOP, YLOOP + 1);
        IF MAZE.E[ XLOOP][ YLOOP] = OPEN THEN
          CLROOMFG( XLOOP + 1, YLOOP);
        IF MAZE.S[ XLOOP][ YLOOP] = OPEN THEN
          CLROOMFG( XLOOP, YLOOP - 1);
        IF MAZE.W[ XLOOP][ YLOOP] = OPEN THEN
          CLROOMFG( XLOOP - 1, YLOOP);
      END;   (* CLROOMFG *)
      
      
      
    BEGIN  (* RUNNER *)
      QUICKPLT := FALSE;
      READMAZE;
      CLROOMFG( MAZEX, MAZEY);
      REPEAT
        RUNMAIN
      UNTIL FALSE
    END;
  