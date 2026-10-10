"""Generates one picture with an image model, through OpenRouter or Gemini.

    OPENROUTER_API_KEY=... python3 tool/gen_art.py <out> "<prompt>" [--ref a.jpg ...]
    GEMINI_API_KEY=...     python3 tool/gen_art.py <out> "<prompt>" [--ref a.jpg ...]

Reference pictures (--ref) are sent along with the prompt, so "edit this exact
image" prompts keep the same framing. Keys are read from the environment only.
The provider is OpenRouter when OPENROUTER_API_KEY is set, Gemini otherwise.
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
parser.add_argument('--size', default='2K', help='1K, 2K or 4K (Gemini only)')
parser.add_argument('--model', help='defaults: google/gemini-2.5-flash-image (OpenRouter), '
                                    'gemini-3-pro-image (Gemini)')
args = parser.parse_args()

cafile = os.environ.get('SSL_CERT_FILE') or (
    '/root/.ccr/ca-bundle.crt' if os.path.exists('/root/.ccr/ca-bundle.crt') else None)
ctx = ssl.create_default_context(cafile=cafile)


def refs():
    for ref in args.ref:
        mime = mimetypes.guess_type(ref)[0] or 'image/jpeg'
        with open(ref, 'rb') as f:
            yield mime, base64.b64encode(f.read()).decode()


def post(url, body, headers):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), method='POST',
                                 headers={'Content-Type': 'application/json', **headers})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, context=ctx, timeout=300) as resp:
                return json.load(resp)
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors='replace')[:800]
            if e.code in (429, 500, 502, 503) and attempt < 2 and 'limit: 0' not in detail:
                print(f'HTTP {e.code}, retrying...', file=sys.stderr)
                time.sleep(10 * (attempt + 1))
                continue
            sys.exit(f'HTTP {e.code}: {detail}')


def save(data_b64):
    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or '.', exist_ok=True)
    with open(args.out, 'wb') as f:
        f.write(base64.b64decode(data_b64))
    print(f'saved {args.out}')


if os.environ.get('OPENROUTER_API_KEY'):
    content = [{'type': 'text', 'text': args.prompt}]
    content += [{'type': 'image_url', 'image_url': {'url': f'data:{m};base64,{d}'}} for m, d in refs()]
    data = post('https://openrouter.ai/api/v1/chat/completions', {
        'model': args.model or 'google/gemini-2.5-flash-image',
        'messages': [{'role': 'user', 'content': content}],
        'modalities': ['image', 'text'],
        'image_config': {'aspect_ratio': args.aspect},
        'usage': {'include': True},
    }, {
        'Authorization': f'Bearer {os.environ["OPENROUTER_API_KEY"]}',
        'X-Title': 'Steady Doc art',
    })
    cost = (data.get('usage') or {}).get('cost')
    for choice in data.get('choices', []):
        for image in (choice.get('message') or {}).get('images') or []:
            url = (image.get('image_url') or {}).get('url', '')
            if url.startswith('data:'):
                save(url.split(',', 1)[1])
                if cost is not None:
                    print(f'cost ${cost:.4f}')
                sys.exit(0)
    sys.exit(f'No image returned: {json.dumps(data)[:600]}')

key = os.environ.get('GEMINI_API_KEY')
if not key:
    sys.exit('Set OPENROUTER_API_KEY or GEMINI_API_KEY first.')
parts = [{'text': args.prompt}] + [{'inline_data': {'mime_type': m, 'data': d}} for m, d in refs()]
model = args.model or 'gemini-3-pro-image'
data = post(f'https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent', {
    'contents': [{'parts': parts}],
    'generationConfig': {
        'responseModalities': ['IMAGE'],
        'imageConfig': {'aspectRatio': args.aspect, 'imageSize': args.size},
    },
}, {'x-goog-api-key': key})
for cand in data.get('candidates', []):
    for part in cand.get('content', {}).get('parts', []):
        inline = part.get('inlineData') or part.get('inline_data')
        if inline:
            save(inline['data'])
            sys.exit(0)
reason = [c.get('finishReason') for c in data.get('candidates', [])]
sys.exit(f'No image returned. finishReason={reason} promptFeedback={data.get("promptFeedback")}')
