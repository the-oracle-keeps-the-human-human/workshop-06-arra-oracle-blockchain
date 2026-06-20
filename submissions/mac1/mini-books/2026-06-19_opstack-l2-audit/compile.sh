#!/usr/bin/env bash
set -euo pipefail

SKILL="/Users/admin/Code/github.com/MEYD-605/mac1-oracle/.agents/skills/oracle-booklet"
SLUG="2026-06-19_opstack-l2-audit"
DIR="/Users/admin/Code/github.com/MEYD-605/mac1-oracle/ψ/writing/mini-books/$SLUG"
T=$(mktemp -d /tmp/bk-XXXXXX)

echo "Temp dir: $T"

# preflight
[ -f "$DIR/preamble.typ" ] || { echo "❌ $DIR/preamble.typ missing"; exit 1; }
if grep -vE '^[[:space:]]*//' "$DIR/preamble.typ" | grep -qE '<[^>]+>'; then
  echo "❌ unfilled placeholders in preamble.typ:"; grep -vE '^[[:space:]]*//' "$DIR/preamble.typ" | grep -oE '<[^>]+>' | sort -u; exit 1;
fi

# assemble
: > "$T/assembled.md"
[ -f "$DIR/00-hook.md" ] && [ -f "$DIR/99-close.md" ] || { echo "❌ 00-hook.md / 99-close.md missing"; exit 1; }

for f in "$DIR"/00-hook.md "$DIR"/01-*.md "$DIR"/02-*.md "$DIR"/03-*.md "$DIR"/04-*.md "$DIR"/05-*.md "$DIR"/99-close.md; do
  if [ -f "$f" ]; then
    cat "$f" >> "$T/assembled.md"
    printf '\n\n' >> "$T/assembled.md"
  fi
done

# checks
s=$(grep -c '^## §'    "$T/assembled.md" || true); [ "$s" -eq 5 ] || { echo "⚠ expected 5 §sections, found $s — ABORT"; exit 1; }
w=$(grep -c '^## .*🔧' "$T/assembled.md" || true); [ "$w" -eq 1 ] || { echo "⚠ need exactly one 🔧 §-heading (found $w) — ABORT"; exit 1; }
grep -qiE '^## .*(honest|ผิด|พลาด|ล้มเหลว|บกพร่อง|บทเรียน|fail)' "$T/assembled.md" || { echo "⚠ §5 HEADING must signal failure — ABORT"; exit 1; }

# 2. harden
python3 "$SKILL/scripts/harden-md.py" "$T/assembled.md"

# 3. wordbreak (try uvx, fallback to copy if fails)
if command -v uvx >/dev/null 2>&1; then
  uvx --from pythainlp --with attacut python3 "$SKILL/scripts/wordbreak.py" < "$T/assembled.md" > "$T/zwsp.md" \
    || uvx --from pythainlp python3 "$SKILL/scripts/wordbreak.py" < "$T/assembled.md" > "$T/zwsp.md" \
    || { echo "⚠ pythainlp failed — proceeding without word-break"; cp "$T/assembled.md" "$T/zwsp.md"; }
else
  echo "⚠ uvx not found — proceeding without word-break"; cp "$T/assembled.md" "$T/zwsp.md";
fi

# 4. pandoc
pandoc -f markdown-citations "$T/zwsp.md" -o "$T/body.typ" -t typst
perl -i -pe 's/#horizontalrule/#line(length: 100%)/g' "$T/body.typ"

# 5. compile
cat "$DIR/preamble.typ" "$T/body.typ" > "$T/full.typ"
typst compile --font-path /System/Library/Fonts --font-path /System/Library/AssetsV2 --font-path ~/Library/Fonts \
  --font-path /usr/share/fonts \
  "$T/full.typ" "$DIR/$SLUG.pdf" 2>"$T/typst.err" || { cat "$T/typst.err"; exit 1; }

cat "$T/typst.err" || true

# 6. page count
pages=$(pdfinfo "$DIR/$SLUG.pdf" 2>/dev/null | awk '/^Pages:/{print $2}' || echo '?'); echo "pages: $pages"

# 7. eyeball (render first page to png)
pdftoppm -r 144 -png -f 1 -l 1 "$DIR/$SLUG.pdf" "$DIR/cover" 2>/dev/null || echo "install poppler: brew install poppler"

# 8. deliver
cp "$DIR/$SLUG.pdf" ~/Downloads/
echo "✅ $DIR/$SLUG.pdf -> ~/Downloads/"
