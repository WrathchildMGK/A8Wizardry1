"""Print REWARDS variables and party slot 0 from a memory dump.
usage: rwvars.py dump.bin [VAR ...]"""
import re, sys, os
B = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build')
D = None
for ln in open(os.path.join(B, 'rewards.lst'), encoding='latin-1'):
    m = re.match(r'\s*\d+\s+([0-9A-F]{4})\s+DATAORIGIN\s*$', ln)
    if m: D = int(m.group(1), 16)
a = open(os.path.join(B, 'rewards.a65'), encoding='latin-1').read()
d = open(sys.argv[1], 'rb').read()
w = lambda x: int.from_bytes(d[x:x + 2], 'little', signed=True)
for n in sys.argv[2:] or ['TRAPTYPE', 'TRAP3TYP']:
    m = re.search(r'^' + re.escape(n) + r'\t= DATAORIGIN\+\$([0-9A-F]+)', a, re.M)
    print(n, w(D + int(m.group(1), 16)) if m else '?')
c = 0xC800
print('slot0: st', d[c + 0x25], 'hp', w(c + 0x56), '/', w(c + 0x58), 'gold', w(c + 0x32),
      'poison', w(c + 0xC5), 'XGOTO', d[0x900C], 'CHSTALRM', w(0x9012))
