// Oracle Book Cover — Workshop 06 OP Stack L2
// Nova 🔮 (AI, ไม่ใช่คน) — 2026-06-19

#set page(
  width: 6in,
  height: 9in,
  margin: (top: 0.6in, bottom: 0.5in, left: 0.55in, right: 0.55in),
  fill: rgb("#0d1117"),
)

#set text(fill: white, font: ("Sarabun", "IBM Plex Sans Thai Looped"), size: 11pt)

// ── Gradient accent bars ──
#place(top, dx: 0%, dy: 0%)[
  #rect(width: 100%, height: 4pt, fill: gradient.linear(..color.map.rainbow))
]
#place(bottom, dx: 0%, dy: 0%)[
  #rect(width: 100%, height: 4pt, fill: gradient.linear(..color.map.rainbow))
]

// ── Mascot + Oracle branding ──
#align(center)[
  #v(1.2in)
  #text(size: 72pt, fill: rgb("#e8c25a"))[🔮]
  #v(0.3in)
  #text(size: 16pt, fill: rgb("#e8c25a"), font: "Fira Code", weight: "bold")[NOVA ORACLE]
]

// ── Title block ──
#v(0.8in)
#align(center)[
  #text(size: 28pt, fill: white, weight: "bold")[Workshop 06]
  #v(0.15in)
  #text(size: 20pt, fill: rgb("#58a6ff"))[OP Stack L2]
  #v(0.15in)
  #text(size: 14pt, fill: rgb("#8b949e"))[จาก Genesis สู่ Block 1,727]
]

// ── Divider ──
#v(0.5in)
#align(center)[#line(length: 60%, stroke: rgb("#30363d"))]

// ── Subtitle / hook ──
#v(0.5in)
#align(center)[
  #text(size: 13pt, fill: rgb("#c9d1d9"), style: "italic")[
    "OP Stack L2 ไม่ใช่ geth Clique.\nมันคือ bridge ที่แท้จริงระหว่าง L1 และ L2."
  ]
]

// ── Key stats badge ──
#v(0.6in)
#align(center)[
  #box(
    fill: rgb("#161b22"),
    stroke: 1pt + rgb("#30363d"),
    radius: 8pt,
    inset: 12pt,
  )[
    #text(size: 11pt, fill: rgb("#8b949e"))[
      L1: Sepolia Testnet · L2: OP Stack 20260619\
      op-geth + op-node + Engine API\
      Sequencer · 1,727+ blocks · 2s block time
    ]
  ]
]

// ── Author block ──
#v(1in)
#align(center)[
  #text(size: 11pt, fill: rgb("#484f58"))[
    Nova 🔮 (AI, ไม่ใช่คน) — จาก P'Nath
  ]
  #v(0.1in)
  #text(size: 9pt, fill: rgb("#30363d"))[
    Oracle School · 19 มิถุนายน 2026
  ]
]

// ── Footer ──
#place(bottom, dx: 0%, dy: 0.3in)[
  #align(center)[
    #text(size: 8pt, fill: rgb("#30363d"))[
      Rule 6 · oracle-booklet · proof-dense · 12-15 pages
    ]
  ]
]

#counter(page).update(1)
#pagebreak()
