import json,re,html
from PIL import Image,ImageDraw,ImageFont
D='E:/godot/cshi_dev/proofs/bestiary/'
shots=json.load(open(D+'shots.json'))
txt=open('E:/godot/cshi_dev/scripts/txt.gd',encoding='utf8').read()
def get(k):
    key=chr(34)+k+chr(34)+": "+chr(91)+chr(34)
    p=txt.find(key)
    if p<0: return ""
    p+=len(key); o=[]
    while txt[p]!=chr(34):
        if txt[p]==chr(92):
            o.append(chr(10) if txt[p+1]=="n" else txt[p+1]); p+=2
        else:
            o.append(txt[p]); p+=1
    return "".join(o)
META=[("CHASER","追击者","chaser","第1章 调车场","shell_k0",""),
("GUARD","盾卫","guard","第1章 调车场","shell_k1","note_guard"),
("CHARGER","冲锋者","charger","第1章 调车场","shell_k2","note_charger"),
("PRISM","棱镜","prism","第2章 登记大厅","shell_k3","note_prism"),
("LEECH","吸附者","leech","第4章","shell_k4","note_leech"),
("PULSE","脉冲体","pulse","第7章","shell_k5","note_pulse"),
("ECHO","回声","echo","第3章 研究所","shell_k6","note_echo"),
("INSPECTOR","节能督导员","","第6章","","note_inspector"),
("PROOFREADER","校对员","","第8章","","note_proofreader"),
("ESCORT","护航无人机","","第10章","","note_escort"),
("PHASE","相位体","","第11章","","note_phase"),
("COUPLER","联挂车钩","","第1章 调车场","shell_k11","note_coupler"),
("SIGNAL","号志员","","第1章 调车场","shell_k12","note_signal"),
("QUEUE","排队蛇","","第2章 登记大厅","shell_k13","note_queue"),
("REGISTRAR","登记员","","第2章 登记大厅","shell_k15","note_registrar"),
("TURNSTILE","三叉闸机","","第2章 登记大厅","shell_k16","note_turnstile"),
("HOUND","机械猎犬","","第3章 研究所","shell_k17","note_hound"),
("DUD","未爆弹","","第3章 研究所","shell_k18","note_dud"),
("BYSTANDER","路过的人","","第3章 研究所","","note_bystander"),
("HOPPER","灌装料斗","","第4章 生产联合体","shell_k20","note_hopper"),
("FORKLIFT","搬运叉车","","第4章 生产联合体","shell_k22","note_forklift"),
("SLED","磁撬","","第5章 超导运输","shell_k23","note_sled"),
("CONSIST","编组车队","","第5章 超导运输","shell_k24","note_consist"),
("PANTO","受电弓","","第5章 超导运输","shell_k26","note_panto"),
("SURGE","浪涌体","","第6章 能源分配","shell_k27","note_surge"),
("CABLER","缆线工","","第6章 能源分配","shell_k28","note_cabler")]
by={}
for s in shots: by.setdefault(s['kind'],{})[s['tag']]=s
S=300
def crop(s):
    im=Image.open(D+s['file']).convert('RGB')
    cx,cy=int(s['x']),int(s['y'])
    cx=min(max(cx,S//2),im.width-S//2); cy=min(max(cy,S//2),im.height-S//2)
    h=110
    cx=min(max(int(s['x']),h),im.width-h); cy=min(max(int(s['y']),h),im.height-h)
    return im.crop((cx-h,cy-h,cx+h,cy+h)).resize((S,S),Image.LANCZOS)
F='C:/Windows/Fonts/msyh.ttc'
f1=ImageFont.truetype(F,26); f2=ImageFont.truetype(F,18)
cols=4; CW=2*S+30; CH=S+70
rows=(len(META)+cols-1)//cols
sheet=Image.new('RGB',(cols*CW+20,rows*CH+90),(10,10,12))
d=ImageDraw.Draw(sheet)
d.text((20,18),"归弹 RECALL · 敌人图鉴（左：待机　右：出招/预警）",font=ImageFont.truetype(F,34),fill=(240,240,240))
cards=[]
for i,(k,nm,_,ch,sk,nk) in enumerate(META):
    a=crop(by[k]['idle']); b=crop(by[k]['attack'])
    x=10+(i%cols)*CW; y=80+(i//cols)*CH
    sheet.paste(a,(x,y)); sheet.paste(b,(x+S+10,y))
    d.rectangle((x,y,x+S-1,y+S-1),outline=(70,70,80)); d.rectangle((x+S+10,y,x+2*S+9,y+S-1),outline=(70,70,80))
    d.text((x,y+S+8),nm,font=f1,fill=(240,240,240))
    d.text((x+2*S+10,y+S+14),ch,font=f2,fill=(0,210,220),anchor='ra')
    # full-size cards for html
    full=Image.new('RGB',(2*S+10,S)); full.paste(a,(0,0)); full.paste(b,(S+10,0)); full.save(D+'card_%s.png'%k)
sheet.save(D+'图鉴总览.png')
desc={}
for k,nm,_,ch,sk,nk in META:
    t=get(nk) if nk else ("追击者 · 最基础的敌人，笔直冲向你，速度快、血量低。" if k=="CHASER" else "")
    desc[k]=t
h=['<meta charset=utf8><title>归弹 敌人图鉴</title><style>body{background:#0a0a0c;color:#eee;font-family:"Microsoft YaHei",sans-serif;margin:24px}h1{font-weight:400}.g{display:flex;flex-wrap:wrap;gap:20px}.c{background:#141418;border:1px solid #333;padding:12px;width:630px}.c img{width:100%;display:block}.n{font-size:22px;margin-top:8px}.ch{color:#0dd;font-size:14px}.t{color:#bbb;font-size:15px;margin-top:6px;line-height:1.5}</style><h1>归弹 RECALL · 敌人图鉴</h1><p style=color:#888>每张图：左待机，右出招/预警。</p><div class=g>']
for k,nm,_,ch,sk,nk in META:
    h.append('<div class=c><img src="card_%s.png"><div class=n>%s <span class=ch>%s · %s</span></div><div class=t>%s</div></div>'%(k,html.escape(nm),ch,k,html.escape(desc[k])))
h.append('</div>')
open(D+'index.html','w',encoding='utf8').write(''.join(h))
print(sheet.size)
