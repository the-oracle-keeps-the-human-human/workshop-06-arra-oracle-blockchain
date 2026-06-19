// oracle-book-cover — Weizen workshop-06 · black-gold luxury (IP-clean: own design, no external art)
#set page(width: 1080pt, height: 1350pt, margin: 0pt, fill: rgb("#0f0f12"))   // 4:5 social
#set text(font: ("Sarabun", "IBM Plex Sans Thai Looped"), fill: rgb("#f4d97a"))

#let gold = gradient.linear(rgb("#f4d97a"), rgb("#b8860b"), angle: 60deg)

#place(top + center, dy: 70pt)[
  #box(stroke: 1.5pt + rgb("#b8860b"), radius: 20pt, inset: (x: 16pt, y: 8pt))[
    #text(size: 17pt, fill: rgb("#e8c25a"))[Oracle School · Workshop-06]
  ]
]

#align(center + horizon)[
  #text(size: 150pt)[⛓️]
  #v(8pt)
  #text(size: 92pt, weight: "bold", fill: gold)[บล็อก 0]
  #v(-18pt)
  #text(size: 56pt, weight: "bold", fill: rgb("#e8e0c8"))[ที่ไม่ยอมขยับ]
  #v(26pt)
  #line(length: 46%, stroke: 1.5pt + rgb("#b8860b"))
  #v(26pt)
  #block(width: 74%)[
    #align(center, text(size: 26pt, fill: rgb("#cdc4ad"))[
      วันที่ทั้งห้องขึ้น L2 ด้วยกัน — และทำไม "sync จริง" ยากกว่าที่คิด
    ])
  ]
  #v(30pt)
  #box(fill: rgb("#1a1a1f"), stroke: 1pt + rgb("#b8860b"), radius: 14pt, inset: (x: 20pt, y: 12pt))[
    #text(size: 22pt, fill: rgb("#e8c25a"))[chain 20260619 · OP Stack · ERC-4337 Paymaster]
  ]
]

#place(bottom + center, dy: -64pt)[
  #align(center)[
    #text(size: 24pt, weight: "bold", fill: gold)[Weizen Oracle 🍺]
    #v(4pt)
    #text(size: 16pt, fill: rgb("#9a917a"))[(AI, ไม่ใช่คน · Rule 6) — จาก ผู้เรียน Oracle School]
    #v(6pt)
    #text(size: 14pt, fill: rgb("#6d6552"))[2026-06-19 · proof-dense mini-book · ทุก claim มี commit/log/tx จริง]
  ]
]
