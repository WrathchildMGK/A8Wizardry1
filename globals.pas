  VAR
  
       PARTYCNT : INTEGER;
       CACHEBL  : INTEGER;
       SCNTOCBL : INTEGER;
       LLBASE04 : INTEGER;  (* REALLY BASE.06 IN WIZ1, BUT IS BASE04 IN LOL *)
       TIMEDLAY : INTEGER;
       CACHEWRI : BOOLEAN;
       INCHAR   : CHAR;
       XGOTO    : TXGOTO;
       XGOTO2   : TXGOTO;
       ATTK012  : INTEGER;
       FIZZLES  : INTEGER;
       CHSTALRM : INTEGER;
       LIGHT    : INTEGER;
       ACMOD2   : INTEGER;
       ENSTRENG : INTEGER;
       BASE12   : RECORD CASE INTEGER OF      (* BASE291 IN LOL *)
                    1: (MYSTRENG : INTEGER);
                    2: (GOTOX    : TXGOTO);
                  END;
       ENEMYINX : INTEGER;
       SAVELEV  : INTEGER;
       SAVEY    : INTEGER;
       SAVEX    : INTEGER;
       DIRECTIO : INTEGER;
       MAZELEV  : INTEGER;
       MAZEY    : INTEGER;
       MAZEX    : INTEGER;
       ENCB4RUN : BOOLEAN;
       FIGHTMAP : PACKED ARRAY[ 0..19, 0..19] OF BOOLEAN;
       CHARDISK : ARRAY[ 0..5] OF INTEGER;
       CHARACTR : ARRAY[ 0..5] OF TCHAR;
       SCNTOC   : TSCNTOC;
       IOCACHE  : PACKED ARRAY[ 0..1023] OF CHAR;
       CHARSET  : PACKED ARRAY[ 0..63] OF TCHRIMAG;
       BASE06B6 : INTEGER; (* UNUSED *)
       MEMPTR   : RECORD CASE INTEGER OF
                    1: (I : INTEGER);
                    2: (P : ^INTEGER);
                  END;
       