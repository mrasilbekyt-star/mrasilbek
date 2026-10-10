"""Generates a picture with the Gemini API.

    GEMINI_API_KEY=... python3 tool/gen_art.py <out.jpg> "<prompt>" [--ref a.jpg ...]
                                              [--aspect 3:4] [--model gemini-3-pro-image]

Reference pictures (--ref) are sent along with the prompt, so "edit this exact
image" style prompts keep the same framing. The key is read from the
GEMINI_API_KEY environment variable only.
"""
import argparse
import base64
import json
import mimetypes
import os
import ssl
import sys
import time
import urllib.error
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('out')
parser.add_argument('prompt')
parser.add_argument('--ref', action='append', default=[])
parser.add_argument('--aspect', default='3:4')
parser.add_argument('--size', default='2K', help='1K, 2K or 4K')
parser.add_argument('--model', default='gemini-3-pro-image')
args = parser.parse_args()

key = os.environ.get('GEMINI_API_KEY')
if not key:
    sys.exit('Set GEMINI_API_KEY first.')

parts = [{'text': args.prompt}]
for ref in args.ref:
    mime = mimetypes.guess_type(ref)[0] or 'image/jpeg'
    with open(ref, 'rb') as f:
        parts.append({'inline_data': {'mime_type': mime, 'data': base64.b64encode(f.read()).decode()}})

body = {
    'contents': [{'parts': parts}],
    'generationConfig': {
        'responseModalities': ['IMAGE'],
        'imageConfig': {'aspectRatio': args.aspect, 'imageSize': args.size},
    },
}
url = f'https://generativelanguage.googleapis.com/v1beta/models/{args.model}:generateContent'
req = urllib.request.Request(url, data=json.dumps(body).encode(), method='POST', headers={
    'Content-Type': 'application/json',
    'x-goog-api-key': key,
})
cafile = os.environ.get('SSL_CERT_FILE') or ('/root/.ccr/ca-bundle.crt' if os.path.exists('/root/.ccr/ca-bundle.crt') else None)
ctx = ssl.create_default_context(cafile=cafile)

for attempt in range(3):
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=300) as resp:
            data = json.load(resp)
        break
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors='replace')[:600]
        if e.code in (429, 500, 503) and attempt < 2:
            print(f'HTTP {e.code}, retrying...', file=sys.stderr)
            time.sleep(10 * (attempt + 1))
            continue
        sys.exit(f'HTTP {e.code}: {detail}')

for cand in data.get('candidates', []):
    for part in cand.get('content', {}).get('parts', []):
        inline = part.get('inlineData') or part.get('inline_data')
        if inline:
            os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
            with open(args.out, 'wb') as f:
                f.write(base64.b64decode(inline['data']))
            print(f'saved {args.out} ({inline.get("mimeType") or inline.get("mime_type")})')
            sys.exit(0)
reason = [c.get('finishReason') for c in data.get('candidates', [])]
feedback = data.get('promptFeedback')
sys.exit(f'No image returned. finishReason={reason} promptFeedback={feedback}')
