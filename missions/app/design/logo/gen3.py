import sys,os; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from gen import *
def plane(bg,f1c,f2c,line=INK,shadow=INK,trail=INK):
    f1="M170 480 L870 190 L450 600 Z"; f2="M450 600 L870 190 L570 840 Z"
    m=(f'<path d="M420 650 C330 720 250 700 200 780 S120 900 90 930" fill="none" stroke="{trail}" stroke-width="30" stroke-linecap="round" stroke-dasharray="1 70"/>'
       f'<path d="M170 480 L870 190 L570 840 L450 600 Z" fill="{shadow}" stroke="{shadow}" stroke-width="{SW}" stroke-linejoin="round" transform="translate({SH} {SH})"/>'
       f'<path d="{f2}" fill="{f2c}" stroke="{line}" stroke-width="{SW}" stroke-linejoin="round"/>'
       f'<path d="{f1}" fill="{f1c}" stroke="{line}" stroke-width="{SW}" stroke-linejoin="round"/>')
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024"><rect width="1024" height="1024" fill="{bg}"/>{m}</svg>'
V=[("p1","Yellow sky",plane(Y,PAPER,PK)),
   ("p2","Pink",plane(PK,PAPER,Y)),
   ("p3","Purple",plane(PU,PAPER,LI)),
   ("p4","Night",plane(INK,Y,PK,line=PAPER,shadow=PU,trail=PAPER)),
   ("p5","Lime",plane(LI,PAPER,PU)),
   ("p6","Paper",plane(PAPER,Y,PK)),
   ("p7","Sand",plane(SA,PK,PU)),
   ("p8","Original green",plane(GR,PAPER,SA))]
if __name__=="__main__":
    for k,_,s in V: open(f"out/plane-{k}-icon.svg","w").write(s)
