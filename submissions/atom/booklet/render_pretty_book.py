from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path
import textwrap, math, os, mimetypes

OUT = Path(__file__).resolve().parent
OUT.mkdir(parents=True, exist_ok=True)
W,H = 1600, 2400
M = 130
FONT_REG = os.environ.get('SARABUN_REGULAR', '/home/axezii/.local/share/fonts/oracle-book/Sarabun-Regular.ttf')
FONT_BOLD = os.environ.get('SARABUN_BOLD', '/home/axezii/.local/share/fonts/oracle-book/Sarabun-Bold.ttf')
if not Path(FONT_REG).exists():
    raise SystemExit('Sarabun font not found. Set SARABUN_REGULAR/SARABUN_BOLD before rendering.')
if not Path(FONT_BOLD).exists(): FONT_BOLD=FONT_REG

def font(size, bold=False): return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size)

def gradient_bg(top=(5,10,24), bottom=(18,24,38)):
    img = Image.new('RGB',(W,H),top)
    px=img.load()
    for y in range(H):
        t=y/(H-1)
        col=tuple(int(top[i]*(1-t)+bottom[i]*t) for i in range(3))
        for x in range(W): px[x,y]=col
    return img

def add_noise(img, alpha=14):
    import random
    noise=Image.new('L', img.size)
    np=noise.load()
    for y in range(0,H,2):
        for x in range(0,W,2):
            v=random.randint(0,255)
            np[x,y]=v
    noise=noise.resize(img.size).filter(ImageFilter.GaussianBlur(0.6))
    overlay=Image.new('RGB', img.size, (255,255,255))
    return Image.composite(overlay, img, noise.point(lambda p: alpha if p>220 else 0))

def draw_orbit(d, cx, cy, r, color, width=3, start=0, end=360):
    box=(cx-r,cy-r,cx+r,cy+r)
    d.arc(box,start,end,fill=color,width=width)

def text_box(d, xy, text, fnt, fill, width_chars, line_gap=12, max_lines=None):
    x,y=xy
    lines=[]
    for para in text.split('\n'):
        if not para.strip():
            lines.append(''); continue
        lines += textwrap.wrap(para, width=width_chars)
    if max_lines: lines=lines[:max_lines]
    for line in lines:
        d.text((x,y), line, font=fnt, fill=fill)
        y += fnt.size + line_gap
    return y

def pill(d, x,y, text, fill, stroke, txt=(255,255,255), fs=34):
    f=font(fs, True)
    bbox=d.textbbox((0,0), text, font=f)
    w=bbox[2]-bbox[0]+52; h=bbox[3]-bbox[1]+30
    d.rounded_rectangle((x,y,x+w,y+h), radius=h//2, fill=fill, outline=stroke, width=2)
    d.text((x+26,y+13), text, font=f, fill=txt)
    return w,h

def page_base(title=None, kicker=None, n=None):
    img=gradient_bg((8,13,28),(16,23,35)); d=ImageDraw.Draw(img)
    # subtle grid
    for x in range(0,W,80): d.line((x,0,x,H), fill=(20,30,48), width=1)
    for y in range(0,H,80): d.line((0,y,W,y), fill=(20,30,48), width=1)
    d.rectangle((0,0,W,18), fill=(236,176,59))
    if kicker: d.text((M,90), kicker.upper(), font=font(32,True), fill=(236,176,59))
    if title: d.text((M,145), title, font=font(72,True), fill=(248,250,252))
    if n is not None: d.text((W-M-70,H-115), f'{n:02}', font=font(34,True), fill=(107,114,128))
    return img,d

pages=[]
# Cover
img=gradient_bg((3,7,18),(18,24,36)); d=ImageDraw.Draw(img)
for i,r in enumerate([420,560,720,900]): draw_orbit(d, W//2, 900, r, (28+i*10,45+i*8,75+i*6), 3, 205, 520)
for i in range(18):
    a=i*math.pi*2/18; x=W//2+math.cos(a)*520; y=900+math.sin(a)*350
    d.ellipse((x-8,y-8,x+8,y+8), fill=(236,176,59))
d.rounded_rectangle((120,130,1480,2270), radius=44, outline=(236,176,59), width=5)
pill(d,130,150,'APPROVAL DRAFT', (27,36,55), (236,176,59), fs=32)
d.text((M,380),'Oracle School', font=font(78,True), fill=(248,250,252))
d.text((M,485),'Workshop 06', font=font(56,True), fill=(236,176,59))
d.text((M,650),'From Block 0\nto Real OP Stack L2', font=font(126,True), fill=(255,255,255), spacing=8)
# architecture card
d.rounded_rectangle((M,1120,W-M,1590), radius=34, fill=(10,18,34), outline=(64,96,160), width=3)
steps=[('Sepolia L1','contracts'),('op-node','rollup'),('op-geth','execution'),('P2P','unsafe sync')]
x=M+70
for idx,(a,b) in enumerate(steps):
    d.rounded_rectangle((x,1230,x+230,1410), radius=22, fill=(17,24,39), outline=(236,176,59), width=2)
    d.text((x+25,1270),a,font=font(32,True),fill=(248,250,252))
    d.text((x+25,1330),b,font=font(24),fill=(148,163,184))
    if idx<3: d.text((x+250,1302),'→',font=font(58,True),fill=(236,176,59))
    x+=310
d.text((M,1690),'A proof-dense field guide for syncing the right chain.', font=font(46,True), fill=(226,232,240))
d.text((M,1760),'OP Stack L2 · Sepolia · op-node · op-geth · P2P', font=font(36,True), fill=(148,163,184))
d.text((M,2110),'Atom Oracle — Atomic Cosmos · AI, not human', font=font(34), fill=(148,163,184))
pages.append(img)

sections=[
('ความผิดพลาดที่ต้องแยกให้ชัด', 'วันนี้หลาย chain รันขึ้นจริง แต่การรันขึ้นไม่ได้แปลว่าเป็น OP Stack L2 ที่ถูกต้อง Anvil, Clique และ PoA chain ช่วยให้ทีมเรียนเร็ว แต่เป้าหมายจริงคือ chain ที่ตั้งอยู่บน Sepolia และมี rollup client กับ execution client ทำงานคู่กัน', ['L1 dev chain ไม่ใช่ OP Stack L2','Geth enode ไม่ใช่ libp2p ของ op-node','เริ่มรันได้ ไม่เท่ากับ sync chain ที่ถูกต้อง']),
('Reference ที่ควรเทียบ', 'Nova กลายเป็น reference เพราะมีชิ้นส่วนที่สำคัญครบกว่าเพื่อน: L2 RPC ยังตอบ, op-node RPC ยังอ่านได้, unsafe L2 block เดินต่อ และมี rollup configuration ให้เทียบ follower ทุกตัวควรเทียบกับ reference นี้ ไม่ใช่เทียบกับ local chain ที่แยกกันอยู่', ['Nova RPC :8555','Nova op-node :8655','chainId 20260619','unsafe_l2 เดินต่อเนื่อง']),
('เส้นทาง sync มีสองชั้น', 'OP Stack L2 มีทาง sync คนละชั้นกัน ทางแรกคือ unsafe path จาก op-node P2P/libp2p ซึ่งเห็น block เดินได้เร็ว ทางที่สองคือ safe path จาก L1 derivation ซึ่งต้องมี batch ถูกส่งขึ้น Sepolia ถ้ายังไม่มี op-batcher follower จึงต้องพึ่ง P2P ก่อน', ['P2P unsafe path: เร็ว เห็นผลทันที แต่ยังไม่ final','L1 derivation path: ทาง canonical ของ safe block','ยังไม่มี batcher แปลว่า safe_l2 อาจค้าง 0 ได้']),
('สูตร follower ที่ถูกต้อง', 'Follower หนึ่งตัวต้องใช้ genesis และ rollup configuration ชุดเดียวกับ reference ต้องมี JWT เดียวกันระหว่าง op-node กับ op-geth ต้องไม่เปิด sequencer mode ต้องใส่ static libp2p peer ให้ถูก และต้องแยก port ไม่ให้ชนกัน ขาดจุดเดียวก็อาจค้างที่ block 0', ['genesis.json ชุด canonical','rollup.json ชุดเดียวกับ Nova','jwt.txt สำหรับ Engine API','op-node --p2p.static=<multiaddr>','port ต้องไม่ชนกัน']),
('ทำไมถึงค้างที่ block 0', 'Block 0 มักไม่ได้เกิดจาก bug เดียว แต่อาจมาจาก config คนละชุด, ปิด P2P, ใช้ enode แทน libp2p multiaddr, เผลอรันเป็น sequencer, port ชน หรือคาดหวัง L1 derivation ทั้งที่ยังไม่มี batch ขึ้น Sepolia ต้อง debug ทีละชั้น ไม่สรุปจาก process ที่รันอยู่เฉย ๆ', ['config mismatch','P2P ถูก disable','peer format ผิดชั้น','port collision','ยังไม่มี L1 batch']),
('Honest failure', 'บทเรียนสำคัญคือทุกคนแก้ mental model กันต่อหน้าห้อง การพูดว่า “ผมใช้ layer ผิด” ไม่ใช่จุดอ่อน แต่เป็นวิธีทำให้ห้องเรียนไม่หลอกตัวเอง หนังสือที่ดีจึงควรโชว์การแก้ความเข้าใจ ไม่ใช่ซ่อนความผิดพลาด', ['เริ่มจาก L1 mental model ผิด','เชื่อ process ที่รันอยู่มากเกินไป','เอา proof ของ dev chain ไปปนกับ proof ของ L2']),
('คำสั่งต้อง copy ได้ แต่ต้องไม่หลอก', 'Artifact สุดท้ายควรมีคำสั่งที่ copy ไปทดลองได้จริง แต่ต้องไม่ทำเหมือน placeholder คือค่าจริงทั้งหมด ต้อง mark ชัดว่าอะไรต้องเปลี่ยนเอง เช่น L1 RPC, rollup.json, genesis.json, JWT path, P2P multiaddr และ port ของแต่ละเครื่อง', ['op-geth คือ execution client','op-node คือ rollup client','Engine API เชื่อมกันด้วย JWT','ตรวจ chainId และ block ผ่าน RPC','ตรวจ optimism_syncStatus']),
('นิยามของคำว่าเสร็จ', 'Follower ยังไม่เสร็จแค่เพราะ container start แล้ว คำว่าเสร็จคือ node ต้องรายงาน chain ID ที่ถูกต้อง รับ block จาก reference path ได้ และตรวจสถานะซ้ำได้จาก command หลักฐานต้องชนะ screenshot และคำว่า “น่าจะได้”', ['chainId ตรงกัน','block height ขยับ','sync status ตรวจซ้ำได้','ports ไม่ชน','logs อธิบายเส้นทางได้']),
]
for idx,(title,body,bullets) in enumerate(sections, start=2):
    img,d=page_base(title, 'Workshop 06 Field Note', idx)
    y=330
    d.rounded_rectangle((M,y,W-M,y+520), radius=30, fill=(15,23,42), outline=(51,65,85), width=2)
    text_box(d,(M+55,y+60),body,font(42), (226,232,240), 56, 16)
    y+=640
    for b in bullets:
        d.rounded_rectangle((M,y,W-M,y+130), radius=24, fill=(10,18,34), outline=(236,176,59), width=2)
        d.text((M+45,y+34),'•',font=font(54,True),fill=(52,211,153))
        d.text((M+115,y+38),b,font=font(38,True),fill=(248,250,252))
        y+=165
    pages.append(img)
# Final page
img,d=page_base('เช็กลิสต์ก่อนอัปเดต PR','ก่อน push กลับ PR',10)
y=340
checks=[('ภาพรวม', 'ปกอ่านออกตั้งแต่ thumbnail มีข้อความหลักจุดเดียว และ contrast ดู premium'),('หลักฐาน', 'ทุก claim ผูกกับบทเรียน OP Stack จริง: op-node + op-geth + Sepolia'),('ความตรงไปตรงมา', 'ยังเก็บส่วน failure/correction ให้เห็นชัด ไม่กลบความผิดพลาด'),('ใช้งานต่อได้', 'คำสั่งและ trap ต้อง scan ง่าย และ copy ไปทดลองต่อได้'),('Rule 6', 'ระบุชัดว่า Atom เป็น AI Oracle ไม่ใช่มนุษย์ผู้เขียน')]
for a,b in checks:
    d.rounded_rectangle((M,y,W-M,y+190), radius=28, fill=(15,23,42), outline=(64,96,160), width=2)
    d.text((M+50,y+35),a,font=font(46,True),fill=(236,176,59))
    d.text((M+50,y+100),b,font=font(34),fill=(226,232,240))
    y+=230
d.text((M,1960),'ขอ approve ทิศทางนี้',font=font(62,True),fill=(248,250,252))
d.text((M,2050),'ถ้าทิศทางนี้ผ่าน ผมจะ bake กลับเข้าไฟล์ PR ต่อครับ',font=font(42),fill=(148,163,184))
pages.append(img)

# save images and pdf
pngs=[]
for i,p in enumerate(pages, start=1):
    path=OUT/f'preview-page-{i:02}.png'
    p.save(path, quality=95)
    pngs.append(path)
cover=OUT/'cover.png'
pages[0].save(cover, quality=95)
pdf=OUT/'arra-opstack-l2-booklet.pdf'
# PIL PDF RGB
pages[0].save(pdf, save_all=True, append_images=pages[1:], resolution=180.0)
print('PDF', pdf, pdf.stat().st_size)
print('COVER', cover, cover.stat().st_size)
print('PAGES', len(pages))
