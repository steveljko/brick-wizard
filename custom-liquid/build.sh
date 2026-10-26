#!/bin/sh
# Builds custom-liquid/brickset-wizard.liquid (paste-ready for a "Custom Liquid" field) from
# brickset-wizard.src.liquid plus the CSS/JS of blocks/brickset-wizard.liquid, minified to fit the 50,000-character limit.
set -e
cd "$(dirname "$0")"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

awk '/{% stylesheet %}/{f=1;next}/{% endstylesheet %}/{f=0}f' ../blocks/brickset-wizard.liquid > "$tmp/wiz.css"
awk '/{% javascript %}/{f=1;next}/{% endjavascript %}/{f=0}f' ../blocks/brickset-wizard.liquid > "$tmp/wiz.js"
npx -y esbuild@0.24.0 "$tmp/wiz.css" --minify --log-level=warning > "$tmp/wiz.min.css"
npx -y esbuild@0.24.0 "$tmp/wiz.js" --minify --target=es2019 --log-level=warning > "$tmp/wiz.min.js"

python3 - "$tmp" <<'EOF'
import re, sys
tmp = sys.argv[1]
src = open('brickset-wizard.src.liquid', encoding='utf-8').read()
# Drop indentation, blank lines and the comments below the settings; the field counts every character.
head, marker, body = src.partition('{%- comment -%} ===== End of settings ===== {%- endcomment -%}')
body = re.sub(r'\{%- comment -%\}.*?\{%- endcomment -%\}', '', body, flags=re.S)
src = '\n'.join(l.strip() for l in (head + marker + body).split('\n') if l.strip())
css = open(f'{tmp}/wiz.min.css', encoding='utf-8').read().strip()
js = open(f'{tmp}/wiz.min.js', encoding='utf-8').read().strip()
out = src.replace('/*BW_CSS*/', css).replace('/*BW_JS*/', js) + '\n'
open('brickset-wizard.liquid', 'w', encoding='utf-8').write(out)
size = len(out.encode('utf-8'))
print(f'brickset-wizard.liquid: {len(out):,} characters, {size:,} bytes (limit 50,000)')
if size > 50000:
    sys.exit('Too big for a Custom Liquid field')
EOF
