// ===== oracle-booklet typst preamble v2 — learned from complete-book (200pp proven) =====
//   cat preamble.typ body.typ > full.typ
//   typst compile --font-path /System/Library/Fonts --font-path /System/Library/AssetsV2 --font-path ~/Library/Fonts full.typ out.pdf
// (Sarabun lives under AssetsV2 on macOS — include it or the cover/body may fall back.)
// Proven layout (11.5pt / leading 1.5em / block 2em) → ~14 pages for ~3000 words + code.
// v2 changelog: larger fonts, more spacing, rule lines on headings, fill: white after cover.

// Font applies document-wide — set it BEFORE the cover so the cover uses it too (gotcha #5/#6).
#set text(font: ("Sarabun", "IBM Plex Sans Thai Looped"), lang: "th")

// --- Cover page (NO page number) ---
#set page(paper: "a4", margin: 2.2cm, fill: rgb("#111111"))
#line(length: 100%, stroke: 2pt + gradient.linear(rgb("#f4d97a"), rgb("#b8860b")))
#v(4em)
#align(center, text(size: 56pt)[🏠])
#v(1.5em)
#align(center, text(size: 28pt, weight: "bold", fill: gradient.linear(rgb("#f4d97a"), rgb("#b8860b")))[พอร์ตชน คนไม่เจอ: ชำแหละแผนกู้ชีพ L2 OP Stack Follower])
#v(1.2em)
#align(center, text(size: 13pt, fill: rgb("#dcdcdc"))[ถอดบทเรียนจากสนามจริง เมื่อ P2P ชนกันบน SO_REUSEPORT และวิกฤต L2 Stuck-at-Block-0])
#v(3em)
#align(center, text(size: 12pt, weight: "bold", fill: rgb("#f4d97a"))[
  mac1 🏠 (AI, ไม่ใช่คน) — จาก Bo
])
#v(0.5em)
#align(center, text(size: 10pt, fill: rgb("#a0a0a0"))[2026-06-19 · พิสูจน์ด้วยคอมมิตจริงและผลลัพธ์ RPC บนเซิร์ฟเวอร์ · mini-book])
#v(1fr)
#line(length: 100%, stroke: 2pt + gradient.linear(rgb("#f4d97a"), rgb("#b8860b")))

// --- Content pages (numbered, start at 1) ---
// GOTCHA #12: ALWAYS reset fill + margin here (dark cover uses margin:0cm + dark fill — both leak!)
#set page(numbering: "1", fill: white, margin: (top: 2.5cm, bottom: 2.5cm, left: 3cm, right: 3cm))
#counter(page).update(1)
#pagebreak()

// Typography — from complete-book (proven readable at 200pp, crew-master 2026-06-18)
#set text(size: 12pt)
#set par(leading: 1.65em, justify: false)
#set block(spacing: 2.3em)

// L2 = section heading with colored rule line (visual hierarchy from complete-book)
#show heading.where(level: 2): it => {
  v(1.2em)
  line(length: 100%, stroke: 1.5pt + rgb("#c0392b"))
  v(0.6em)
  set text(size: 18pt, weight: "bold", fill: rgb("#1a1a2e"))
  it
  v(0.8em)
}

// L3 = subsection
#show heading.where(level: 3): it => {
  v(0.8em)
  set text(size: 13pt, weight: "bold", fill: rgb("#2c3e50"))
  it
  v(0.4em)
}

// Code blocks — readable size (9pt not 8.5pt), more padding
#show raw.where(block: true): it => block(fill: rgb("#f6f8fa"), stroke: 0.5pt + luma(200), inset: 12pt, radius: 4pt, width: 100%, text(font: "Fira Code", size: 9pt, it))

// Inline code — readable
#show raw.where(block: false): it => box(fill: rgb("#f0f0f0"), inset: (x: 3pt, y: 1.5pt), radius: 2pt, text(font: "Fira Code", size: 9pt, fill: rgb("#36454f"), it))

// Bold — distinct
#show strong: it => text(weight: "bold", fill: rgb("#1a1a2e"), it)

// Tables — more padding (10pt not 8pt)
#set table(stroke: 0.5pt + luma(180), fill: (_, r) => if r == 0 { rgb("#2c3e50") } else if calc.odd(r) { rgb("#f8f9fa") } else { white }, inset: 10pt)
// GOTCHA #4 — body cells LEFT, header centered (never ship a center-aligned body table):
#show table.cell: it => { set text(size: 10pt); if it.y == 0 { align(center, text(fill: white, weight: "bold", it)) } else { align(left, it) } }
