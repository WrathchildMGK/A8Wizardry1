  TYPE
  
        TXGOTO = (XDONE,    XTRAININ, XCASTLE,  XGILGAMS, XINSPECT, XBOLTAC,
                  XCANT,    XRUNNER,  XCOMBAT,  XNEWMAZE, XCHK4WIN, XREWARD,
                  XINSPCT2, XEQUIP6,  XEQPDSP,  XREORDER, XCEMETRY, XINSPCT3,
                  XBCK2CMP, XBCK2ROL, XCMP2EQ6, XUNUSED,  XREWARD2, XSCNMSG,
                  XCAMPSTF, XEDGTOWN, XINSAREA, XBK2CMP2);
                  
        TWIZLONG = RECORD
            LOW  : INTEGER;
            MID  : INTEGER;
            HIGH : INTEGER;
          END;
                   
        TRACE = (NORACE, HUMAN, ELF, DWARF, GNOME, HOBBIT);
        
        TCLASS = (FIGHTER, MAGE, PRIEST, THIEF,
                  BISHOP, SAMURAI, LORD, NINJA);
          
        TALIGN = (UNALIGN, GOOD, NEUTRAL, EVIL);
          
        TSTATUS = (OK, AFRAID, ASLEEP, PLYZE, 
                   STONED, DEAD, ASHES, LOST);
        
        TATTRIB = (STRENGTH, IQ, PIETY, VITALITY, AGILITY, LUCK);
        
        TSPELL7G = ARRAY[ 1..7] OF INTEGER;
        
        THPREC = RECORD
            LEVEL   : INTEGER;
            HPFAC   : INTEGER;
            HPMINAD : INTEGER;
          END;
                 
        TCHAR = RECORD
            NAME     : STRING[ 15];
            PASSWORD : STRING[ 15];
            INMAZE   : BOOLEAN;
            RACE     : TRACE;
            CLASS    : TCLASS;
            AGE      : INTEGER;
            STATUS   : TSTATUS;
            ALIGN    : TALIGN;
            ATTRIB   : PACKED ARRAY[ STRENGTH..LUCK] OF 0..18;
            LUCKSKIL : PACKED ARRAY[ 0..4] OF 0..31;
            GOLD     : TWIZLONG;
            POSS     : RECORD
                POSSCNT : INTEGER;
                POSSESS : ARRAY[ 1..8] OF RECORD
                    EQUIPED : BOOLEAN;
                    CURSED  : BOOLEAN;
                    IDENTIF : BOOLEAN;
                    EQINDEX : INTEGER;
                  END;
              END;
            EXP      : TWIZLONG;
            MAXLEVAC : INTEGER;
            CHARLEV  : INTEGER;
            HPLEFT   : INTEGER;
            HPMAX    : INTEGER;
            SPELLSKN : PACKED ARRAY[ 0..49] OF BOOLEAN;
            MAGESP   : TSPELL7G;
            PRIESTSP : TSPELL7G;
            HPCALCMD : INTEGER;
            ARMORCL  : INTEGER;
            HEALPTS  : INTEGER;
            CRITHITM : BOOLEAN;
            SWINGCNT : INTEGER;
            HPDAMRC  : THPREC;
            WEPVSTY2 : PACKED ARRAY[ 0..1, 0..13] OF BOOLEAN;
            WEPVSTY3 : PACKED ARRAY[ 0..1, 0..6] OF BOOLEAN;
            WEPVSTYP : PACKED ARRAY[ 0..13] OF BOOLEAN;
            LOSTXYL  : RECORD CASE INTEGER OF
                1:  (LOCATION : ARRAY[ 1..4] OF INTEGER);
                2:  (POISNAMT : ARRAY[ 1..4] OF INTEGER);
                3:  (AWARDS   : ARRAY[ 1..4] OF INTEGER);
              END;
          END;
              
        TOBJTYPE = (WEAPON, ARMOR, SHIELD, HELMET, GAUNTLET,
                    SPECIAL, MISC);
                          
        TOBJREC = RECORD
            NAME     : STRING[ 15];
            NAMEUNK  : STRING[ 15];
            OBJTYPE  : TOBJTYPE;
            ALIGN    : TALIGN;
            CURSED   : BOOLEAN;
            SPECIAL  : INTEGER;
            CHANGETO : INTEGER;
            CHGCHANC : INTEGER;
            PRICE    : TWIZLONG;
            BOLTACXX : INTEGER;
            SPELLPWR : INTEGER;
            CLASSUSE : PACKED ARRAY[ TCLASS] OF BOOLEAN;
            HEALPTS  : INTEGER;
            WEPVSTY2 : PACKED ARRAY[ 0..15] OF BOOLEAN;
            WEPVSTY3 : PACKED ARRAY[ 0..15] OF BOOLEAN;
            ARMORMOD : INTEGER;
            WEPHITMD : INTEGER;
            WEPHPDAM : THPREC;
            XTRASWNG : INTEGER;
            CRITHITM : BOOLEAN;
            WEPVSTYP : PACKED ARRAY[ 0..13] OF BOOLEAN;
          END;

        TWALL = (OPEN, WALL, DOOR, HIDEDOOR);
   
        TSQUARE = (NORMAL, STAIRS, PIT, CHUTE, SPINNER, DARK, TRANSFER,
                   OUCHY, BUTTONZ, ROCKWATE, FIZZLE, SCNMSG, ENCOUNTE);
   
        TMAZE = RECORD
            W : PACKED ARRAY[ 0..19] OF PACKED ARRAY[ 0..19] OF TWALL;
            S : PACKED ARRAY[ 0..19] OF PACKED ARRAY[ 0..19] OF TWALL;
            E : PACKED ARRAY[ 0..19] OF PACKED ARRAY[ 0..19] OF TWALL;
            N : PACKED ARRAY[ 0..19] OF PACKED ARRAY[ 0..19] OF TWALL;
            
            FIGHTS : PACKED ARRAY[ 0..19] OF PACKED ARRAY[ 0..19] OF 0..1;
                       
            SQREXTRA : PACKED ARRAY[ 0..19] OF PACKED ARRAY[ 0..19] OF 0..15;
                       
            SQRETYPE : PACKED ARRAY[ 0..15] OF TSQUARE;
            
            AUX0   : PACKED ARRAY[ 0..15] OF INTEGER;
            AUX1   : PACKED ARRAY[ 0..15] OF INTEGER;
            AUX2   : PACKED ARRAY[ 0..15] OF INTEGER;
                       
            ENMYCALC : PACKED ARRAY[ 1..3] OF RECORD
                         MINENEMY : INTEGER;
                         MULTWORS : INTEGER;
                         WORSE01  : INTEGER;
                         RANGE0N  : INTEGER;
                         PERCWORS : INTEGER;
                       END;
          END;
        
        TENEMY = RECORD
            NAMEUNK  : STRING[ 15];
            NAMEUNKS : STRING[ 15];
            NAME     : STRING[ 15];
            NAMES    : STRING[ 15];
            PIC      : INTEGER;
            CALC1    : TWIZLONG;
            HPREC    : THPREC;
            CLASS    : INTEGER;
            AC       : INTEGER;
            RECSN    : INTEGER;
            RECS     : ARRAY[ 1..7] OF THPREC;
            EXPAMT   : TWIZLONG;
            DRAINAMT : INTEGER;
            HEALPTS  : INTEGER;
            REWARD1  : INTEGER;
            REWARD2  : INTEGER;
            ENMYTEAM : INTEGER;
            TEAMPERC : INTEGER;
            MAGSPELS : INTEGER;
            PRISPELS : INTEGER;
            UNIQUE   : INTEGER;
            BREATHE  : INTEGER;
            UNAFFCT  : INTEGER;
            WEPVSTY3 : PACKED ARRAY[ 0..15] OF BOOLEAN;
            SPPC     : PACKED ARRAY[ 0..15] OF BOOLEAN;
          END;
                 
        TENEMY2 = RECORD
            A : RECORD
                    IDENTIFI : BOOLEAN;
                    ALIVECNT : INTEGER;
                    ENMYCNT  : INTEGER;
                    ENEMYID  : INTEGER;
                    TEMP04   : ARRAY[ 0..8] OF RECORD
                        VICTIM   : INTEGER;
                        SPELLHSH : INTEGER;
                        AGILITY  : INTEGER;
                        HPLEFT   : INTEGER;
                        ARMORCL  : INTEGER;
                        INAUDCNT : INTEGER;
                        STATUS   : TSTATUS;
                      END;
                  END;
                
            B : TENEMY;
          END;
                   
        TEXP = ARRAY[ FIGHTER..NINJA] OF ARRAY[ 0..12] OF TWIZLONG;
        
        TBCD = ARRAY[ 0..13] OF INTEGER;
                   
        TSPEL012 = (GENERIC, PERSON, GROUP);
        
        TZSCN = (ZZERO, ZMAZE, ZENEMY, ZREWARD, ZOBJECT,
                        ZCHAR, ZSPCCHRS, ZEXP);
                   
        TSCNTOC = RECORD
            GAMENAME : STRING[ 40];
            RECPER2B : ARRAY[ ZZERO..ZEXP] OF INTEGER;
            RECPERDK : ARRAY[ ZZERO..ZEXP] OF INTEGER;
            UNUSEDXX : ARRAY[ ZZERO..ZEXP] OF INTEGER;
            BLOFF    : ARRAY[ ZZERO..ZEXP] OF INTEGER;
            RACE     : ARRAY[ NORACE..HOBBIT]         OF STRING[ 9];
            CLASS    : PACKED ARRAY[ FIGHTER..NINJA]  OF STRING[ 9];
            STATUS   : ARRAY[ OK..LOST]               OF STRING[ 8];
            ALIGN    : PACKED ARRAY[ UNALIGN..EVIL]   OF STRING[ 9];
            SPELLHSH : PACKED ARRAY[ 0..50] OF INTEGER;
            SPELLGRP : PACKED ARRAY[ 0..50] OF 0..7;
            SPELL012 : PACKED ARRAY[ 0..50] OF TSPEL012;
          END;
    
        TBATRSLT = RECORD
            ENMYCNT : ARRAY[ 1..4] OF INTEGER;
            ENMYID  : ARRAY[ 1..4] OF INTEGER;
            DRAINED : ARRAY[ 0..5] OF BOOLEAN;
          END;
          
        TCHRIMAG = PACKED ARRAY[ 0..7] OF 0..255;
        