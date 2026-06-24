#!/usr/bin/env python3
"""Insert ZWSP at Thai word boundaries for proper line breaking in Typst."""
import sys
import re

# We wrap pythainlp import in a function to verify it or run it on the fly
try:
    from pythainlp.tokenize import word_tokenize
except ImportError:
    print("Error: pythainlp is not installed. Run with `uvx --from pythainlp python3 thai-wordbreak.py`", file=sys.stderr)
    sys.exit(1)

ZWSP = "​"  # Zero-Width Space (U+200B)

def has_thai(text):
    return bool(re.search(r'[\u0e00-\u0e7f]', text))

def insert_zwsp(text):
    if not has_thai(text):
        return text
    # Preserve inline code blocks
    parts = re.split(r'(`[^`]+`)', text)
    result = []
    for part in parts:
        if part.startswith('`'):
            result.append(part)
        elif has_thai(part):
            # Split into Thai and non-Thai chunks to preserve non-Thai formatting
            segments = re.split(r'([\u0e00-\u0e7f]+)', part)
            for seg in segments:
                if has_thai(seg):
                    result.append(ZWSP.join(word_tokenize(seg, engine="newmm")))
                else:
                    result.append(seg)
        else:
            result.append(part)
    return ''.join(result)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 thai-wordbreak.py <file.md>", file=sys.stderr)
        sys.exit(1)
        
    filepath = sys.argv[1]
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    broken_content = insert_zwsp(content)
    sys.stdout.write(broken_content)

if __name__ == '__main__':
    main()
