unit CONSTS;

{ Wizardry I — constants for Atari 8-bit port.
  Source: apple/wiz1a/WIZ.TEXT and mads/wiz.pas.

  Spell hash values: each spell name is hashed into an integer used by the
  spell lookup table (TSCNTOC.SPELLS.SPELLHSH).  Values are unchanged from
  the original Apple Pascal source.

  BLOCKSZ, DRIVE1, CRETURN: disk I/O parameters.  DRIVE1 = 4 is the Apple
  Pascal unit number; the Atari port will use different I/O but the constant
  is kept as a placeholder until the disk layer is implemented.
}

interface

const

  { --- Disk I/O --- }
  BLOCKSZ = 512;
  DRIVE1  = 4;      { Apple Pascal unit number — replace with Atari SIO unit }
  CRETURN = 13;     { Carriage return delimiter used in spell name blocks }

  { --- Mage spell hashes (levels 1-7) --- }
  HALITO   =  4178;  { L1: fire }
  MOGREF   =  2409;  { L1: armor }
  KATINO   =  3983;  { L1: sleep }
  DUMAPI   =  3245;  { L1: identify }

  DILTO    =  3340;  { L2: darkness }
  SOPIC    =  1953;  { L2: invisible }

  MAHALITO =  6181;  { L3: fireball }
  MOLITO   =  4731;  { L3: lightning }

  MORLIS   =  4744;  { L4: fear }
  DALTO    =  3180;  { L4: ice storm }
  LAHALITO =  6156;  { L4: fire storm }

  MAMORLIS =  7525;  { L5: terror }
  MAKANITO =  6612;  { L5: kill all }
  MADALTO  =  4925;  { L5: blizzard }

  LAKANITO =  6587;  { L6: asphyxiation }
  ZILWAN   =  4573;  { L6: dispel undead }
  MASOPIC  =  3990;  { L6: mass invisible }
  HAMAN    =  1562;  { L6: change }

  MALOR    =  3128;  { L7: teleport }
  MAHAMAN  =  2597;  { L7: change }
  TILTOWAI = 11157;  { L7: sleep all }

  { --- Priest spell hashes (levels 1-7) --- }
  KALKI    =  1449;  { L1: armor }
  DIOS     =  2301;  { L1: cure light }
  BADIOS   =  3675;  { L1: harm }
  MILWA    =  2889;  { L1: light }
  PORFIC   =  2287;  { L1: shield }

  MATU     =  3139;  { L2: boost morale }
  CALFO    =     0;  { L2: identify trap (hash 0 = unused/unknown) }
  MANIFO   =  2619;  { L2: silence }
  MONTINO  =  5970;  { L2: freeze }

  LOMILWA  =  5333;  { L3: continuous light }
  DIALKO   =  2718;  { L3: remove paralysis }
  LATUMAPI =  6491;  { L3: poison cure }
  BAMATU   =  5169;  { L3: protection }

  DIAL     =   761;  { L4: cure serious }
  BADIAL   =  1253;  { L4: harm serious }
  LATUMOFI =  9463;  { L4: poison }
  MAPORFIC =  4322;  { L4: magic screen }

  DIALMA   =  1614;  { L5: cure critical }
  BADIALMA =  2446;  { L5: harm critical }
  LITOKAN  =  4396;  { L5: fire column }
  KANDI    =  1185;  { L5: locate person }
  DI       =   180;  { L5: raise dead }
  BADI     =   382;  { L5: slay }

  LORTO    =  4296;  { L6: blades }
  MADI     =   547;  { L6: full heal }
  MABADI   =   759;  { L6: full harm }
  LOKTOFEI =  8330;  { L6: turn stoned }

  MALIKTO  =  5514;  { L7: blades all }
  KADORTO  =  6673;  { L7: full blades }

implementation

end.
