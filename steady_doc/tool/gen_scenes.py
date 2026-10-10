"""Generates every missing patient picture and object for Steady Doc.

    OPENROUTER_API_KEY=... python3 tool/gen_scenes.py [--only hand_a,thigh_a] [--dry-run]

For each patient scene it makes three pictures in assets/art/:
  <scene>_open.jpg   the opened operating field, styled after belly_a_open.jpg
  <scene>_closed.jpg the same shot with intact skin (edited from _open)
  <scene>_xray.jpg   an X-ray of the same shot (edited from _open)
and finally cuts the missing findings out of one generated picture.
Pictures that already exist are skipped, so it can be re-run safely.
"""
import argparse
import os
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, '..', 'assets', 'art')

STYLE = ('Match the style, camera angle, lighting and quality of the attached image. Camera '
         'directly above, top-down, portrait 3:4. Green sterile drapes cover everything except the '
         'operating field, which fills the center of the frame. Steel retractors hold the wound '
         'edges apart. Glossy wet realistic tissue, razor sharp, 8K. No foreign objects, no hands '
         'of surgeons, no text.')
CLOSED = ('Edit this exact image: same camera, framing, drapes and lighting, but the skin is intact '
          'and closed, no incision, no wound, prepped with orange-brown iodine. Same render quality. '
          'No text.')
XRAY = ('Turn this exact image into a real clinical X-ray radiograph of the same body part, same '
        'framing and scale, bones in white on black. No text, no labels.')

PATIENTS = {
    'hand_a': "Hyper-realistic surgical render of the open palm of a weathered middle-aged man's "
              'right hand lying flat on a surgical arm table, fingers spread. A small incision in '
              'the center of the palm shows tendons and tissue.',
    'appendix_a': 'Hyper-realistic surgical render of the lower right abdomen of a slim young woman '
                  'with olive skin. A short oblique incision shows the bowel and the cecum.',
    'thigh_a': "Hyper-realistic surgical render of the front of a muscular young Black man's thigh. "
               'A long vertical incision shows the thigh muscles.',
    'belly_b': 'Hyper-realistic surgical render of the abdomen of a woman in her thirties with '
               'medium brown skin. A long midline incision shows the stomach, liver and intestines.',
    'gall_a': 'Hyper-realistic surgical render of the upper abdomen of an overweight pale man in his '
              'fifties with some body hair. An incision under the right ribs shows the liver edge '
              'and the gallbladder.',
    'knee_a': 'Hyper-realistic surgical render of the right knee of a fit woman with fair skin, '
              'slightly bent. A vertical incision over the front of the knee shows the knee joint.',
    'flank_a': 'Hyper-realistic surgical render of an elderly tanned man lying on his left side, seen '
               'from above at his right flank. An oblique incision below the ribs shows the kidney.',
    'belly_c': 'Hyper-realistic surgical render of the abdomen of a thin 19-year-old man with light '
               'brown skin. A long midline incision shows the stomach, liver and intestines.',
    'shoulder_a': 'Hyper-realistic surgical render of the right shoulder and upper arm of a strong '
                  'tanned construction worker in his forties. An incision over the shoulder shows '
                  'the deltoid muscle.',
    'belly_d': 'Hyper-realistic surgical render of the soft abdomen of a 70-year-old woman with pale '
               'wrinkled skin. A long midline incision shows the stomach, liver and intestines.',
    'belly_e': 'Hyper-realistic surgical render of the abdomen of a muscular man in his late forties '
               'with dark brown skin. A long midline incision shows the stomach, liver and intestines.',
}

# Findings still drawn as emoji, in the reading order of the generated grid.
OBJECTS = ['fishhook', 'appendix', 'glass', 'bone', 'kidneystone', 'metal']
OBJECTS_PROMPT = ('Six real objects photographed from directly above on a pure white background, in '
                  'a neat 3x2 grid, each isolated in its own cell, not touching, no shadows: a steel '
                  'fish hook, an inflamed appendix (medical specimen), a sharp shard of broken glass, '
                  'a small white bone fragment, a kidney stone, a jagged metal shard. Same style as '
                  'the attached image. Hyper-realistic studio macro photography, 4K, no text.')

parser = argparse.ArgumentParser()
parser.add_argument('--only', default='', help='comma-separated scene ids')
parser.add_argument('--dry-run', action='store_true')
parser.add_argument('--open-model', default='google/gemini-3-pro-image-preview',
                    help='model for the opened scenes (the hardest pictures)')
parser.add_argument('--edit-model', default='google/gemini-2.5-flash-image',
                    help='model for the closed and X-ray edits and the objects')
args = parser.parse_args()

only = set(filter(None, args.only.split(',')))
made = 0


def art(name):
    return os.path.join(ART, name)


def generate(out_jpg, prompt, refs, model, aspect='3:4'):
    global made
    print(f'-> {os.path.basename(out_jpg)} ({model})')
    if args.dry_run:
        return True
    with tempfile.TemporaryDirectory() as tmp:
        raw = os.path.join(tmp, 'raw')
        cmd = [sys.executable, os.path.join(HERE, 'gen_art.py'), raw, prompt,
               '--model', model, '--aspect', aspect]
        for ref in refs:
            cmd += ['--ref', ref]
        result = subprocess.run(cmd, capture_output=True, text=True)
        print('   ' + (result.stdout + result.stderr).strip().replace('\n', '\n   '))
        if result.returncode != 0 or not os.path.exists(raw):
            return False
        Image.open(raw).convert('RGB').save(out_jpg, quality=90)
    made += 1
    return True


for scene, description in PATIENTS.items():
    if only and scene not in only:
        continue
    opened = art(f'{scene}_open.jpg')
    if not os.path.exists(opened):
        if not generate(opened, f'{description} {STYLE}', [art('belly_a_open.jpg')], args.open_model):
            print(f'!! {scene}: the opened picture failed, skipping its edits')
            continue
    for layer, prompt in (('closed', CLOSED), ('xray', XRAY)):
        out = art(f'{scene}_{layer}.jpg')
        if not os.path.exists(out) and (args.dry_run or os.path.exists(opened)):
            generate(out, prompt, [opened], args.edit_model)

missing = [o for o in OBJECTS if not os.path.exists(art(f'obj_{o}.png'))]
if missing and not only:
    with tempfile.TemporaryDirectory() as tmp:
        grid = os.path.join(tmp, 'objects.jpg')
        if generate(grid, OBJECTS_PROMPT, [art('obj_coin.png')], args.edit_model, aspect='3:2') \
                and not args.dry_run:
            subprocess.run([sys.executable, '-I', os.path.join(HERE, 'cutout.py'), grid, ART, *OBJECTS],
                           check=False)

print(f'{made} pictures generated')
