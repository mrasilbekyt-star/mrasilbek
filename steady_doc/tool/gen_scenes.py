"""Generates every missing patient picture and object for Steady Doc.

    OPENROUTER_API_KEY=... python3 tool/gen_scenes.py [--only hand_a,torso_a] [--dry-run]
    OPENROUTER_API_KEY=... python3 tool/gen_scenes.py --redo belly_b,hand_a_xray

For each patient scene it makes three pictures in assets/art/:
  <scene>_open.jpg   the opened operating field, in the quality of belly_a_open.jpg
  <scene>_closed.jpg the same shot with intact skin (edited from _open)
  <scene>_xray.jpg   an X-ray of the same shot (edited from _open)
and finally cuts the missing findings out of one generated picture.
Pictures that already exist are skipped, so it can be re-run safely.
--redo makes pictures again: a scene id redoes all three layers, a name like
hand_a_xray redoes just that layer.
"""
import argparse
import os
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, '..', 'assets', 'art')

STYLE = ('The attached picture is only a reference for render quality, lighting and the top-down '
         'camera. Make a NEW patient and a NEW operation: do not copy its organs, wound outline, '
         'retractors or drapes. Camera directly above, portrait 3:4. Sterile drapes cover everything '
         'except the operating field in the center of the frame; they always cover the chest and '
         'the groin. Steel retractors hold the wound edges apart. Super realistic, like a real '
         'photograph from a real operating room: real '
         'human skin with pores, fine hair, freckles and natural imperfections, glossy wet tissue, '
         'real blood vessels, razor sharp, 8K. Not a cartoon, not an illustration. No foreign '
         'objects, no surgeons hands, no text.')
CLOSED = ('Edit this exact image: same camera, framing, drapes and lighting, no retractors. The '
          'body part is whole: intact closed skin, no incision, no wound, no exposed tissue anywhere, '
          'including at the edges of the field. Skin prepped with orange-brown iodine, real skin '
          'texture with pores and fine hair. Super realistic photograph. No text.')
XRAY = ('Turn this exact image into a real clinical X-ray radiograph of the same body part, same '
        'framing and scale: black background, bones bright white with real trabecular texture, soft '
        'tissue faint grey. It must look like a real hospital radiograph, not a photo. No '
        'instruments, no text, no labels.')

# Per scene: the opened field, and optional extra words for the closed and X-ray edits.
PATIENTS = {
    'hand_a': {
        'open': "Hyper-realistic surgical photograph of the open palm of a weathered middle-aged "
                "man's right hand lying flat on a surgical arm table, fingers spread. A small "
                'incision in the center of the palm shows tendons and tissue.',
        'xray': 'It is a PA radiograph of an adult right hand: phalanges, metacarpals, carpal '
                'bones, the ends of the radius and ulna, all in white on black.',
    },
    'appendix_a': {
        'open': 'Hyper-realistic surgical photograph of the lower right abdomen of a slim young '
                'woman with olive skin. A short oblique incision shows the bowel and the cecum.',
    },
    'torso_a': {
        'open': "Hyper-realistic surgical photograph of the abdomen of a muscular young Black man. "
                'A long vertical incision shows the rectus abdominis muscles of the abdominal wall.',
    },
    'belly_b': {
        'open': 'Hyper-realistic surgical photograph of the abdomen of a woman in her thirties with '
                'medium brown skin and a few freckles; blue drapes cover her chest and everything '
                'above the lower ribs. A short upper midline incision; the pale pink stomach fills '
                'most of the wound, the left lobe of the liver at the top, a little omentum below.',
        'closed': 'The blue drapes still cover her chest; only the abdomen is visible.',
    },
    'gall_a': {
        'open': 'Hyper-realistic surgical photograph of the upper abdomen of an overweight pale man '
                'in his fifties with some body hair. An incision under the right ribs shows the '
                'liver edge and the gallbladder.',
    },
    'knee_a': {
        'open': 'Hyper-realistic surgical photograph of the right knee of a fit woman with fair '
                'skin, slightly bent. A vertical incision over the front of the knee shows the '
                'knee joint.',
        'closed': 'It is a natural, slender right knee with the kneecap visible under the skin, '
                  'the thigh above it and the shin below it.',
        'xray': 'It is a frontal knee radiograph: femur, patella, tibia and fibula.',
    },
    'flank_a': {
        'open': 'Hyper-realistic surgical photograph of an elderly tanned man lying on his left '
                'side, seen from above at his right flank. An oblique incision below the ribs '
                'shows the kidney.',
    },
    'belly_c': {
        'open': 'Hyper-realistic surgical photograph of the abdomen of a very thin 19-year-old man '
                'with light brown skin, ribs showing under the skin, almost no fat, grey-green '
                'drapes. A long midline incision; glistening loops of small intestine and their '
                'mesentery fill the whole wound, no liver visible.',
    },
    'shoulder_a': {
        'open': 'Hyper-realistic surgical photograph of the right shoulder and upper arm of a '
                'strong tanned construction worker in his forties. An incision over the shoulder '
                'shows the deltoid muscle.',
        'closed': 'It is a natural, muscular rounded right shoulder and upper arm with the '
                  'collarbone visible, sun-tanned skin with a few scars.',
        'xray': 'It is an AP shoulder radiograph: humeral head, glenoid, scapula, clavicle, '
                'acromion and the upper ribs.',
    },
    'belly_d': {
        'open': 'Hyper-realistic surgical photograph of the soft abdomen of a 70-year-old woman '
                'with pale wrinkled skin, stretch marks and an old caesarean scar, teal drapes. A '
                'lower midline incision through a thick yellow fat layer shows the pink colon and '
                'the sigmoid loop.',
    },
    'belly_e': {
        'open': 'Hyper-realistic surgical photograph of the abdomen of a muscular hairy man in his '
                'late forties with very dark brown skin, dark green drapes. A long midline '
                'incision between thick red rectus muscles shows the stomach, the duodenum and '
                'the transverse colon, with a large self-retaining ring retractor.',
    },
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
parser.add_argument('--redo', default='',
                    help='comma-separated scene ids or pictures (like hand_a_xray) to make again')
parser.add_argument('--dry-run', action='store_true')
parser.add_argument('--open-model', default='google/gemini-3-pro-image-preview',
                    help='model for the opened scenes (the hardest pictures)')
parser.add_argument('--edit-model', default='google/gemini-2.5-flash-image',
                    help='model for the closed and X-ray edits and the objects')
args = parser.parse_args()

only = set(filter(None, args.only.split(',')))
redo = set(filter(None, args.redo.split(',')))
for name in redo:
    scene = name.rsplit('_', 1)[0] if name.endswith(('_open', '_closed', '_xray')) else name
    if scene not in PATIENTS:
        sys.exit(f'Unknown scene in --redo: {name}')
if redo:
    only |= {n.rsplit('_', 1)[0] if n.endswith(('_open', '_closed', '_xray')) else n for n in redo}
made = 0


def art(name):
    return os.path.join(ART, name)


def wanted(scene, layer):
    """Whether this picture should be (re)made now."""
    if scene in redo or f'{scene}_open' in redo or f'{scene}_{layer}' in redo:
        return True
    return not os.path.exists(art(f'{scene}_{layer}.jpg'))


def generate(out_jpg, prompt, refs, model, aspect='3:4', size=None):
    """Makes one picture; edits are resized to [size] so every layer lines up."""
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
        image = Image.open(raw).convert('RGB')
        if size and image.size != size:
            image = image.resize(size, Image.LANCZOS)
        image.save(out_jpg, quality=92)
    made += 1
    return True


for scene, spec in PATIENTS.items():
    if only and scene not in only:
        continue
    opened = art(f'{scene}_open.jpg')
    if wanted(scene, 'open'):
        if not generate(opened, f"{spec['open']} {STYLE}", [art('belly_a_open.jpg')], args.open_model):
            print(f'!! {scene}: the opened picture failed, skipping its edits')
            continue
        redo.add(scene)  # a new opened picture needs new edits to line up with it
    size = Image.open(opened).size if os.path.exists(opened) else None
    for layer, prompt in (('closed', CLOSED), ('xray', XRAY)):
        if wanted(scene, layer) and (args.dry_run or size):
            extra = spec.get(layer, '')
            generate(art(f'{scene}_{layer}.jpg'), f'{prompt} {extra}'.strip(), [opened],
                     args.edit_model, size=size)

missing = [o for o in OBJECTS if not os.path.exists(art(f'obj_{o}.png'))]
if missing and not only:
    with tempfile.TemporaryDirectory() as tmp:
        grid = os.path.join(tmp, 'objects.jpg')
        if generate(grid, OBJECTS_PROMPT, [art('obj_coin.png')], args.edit_model, aspect='3:2') \
                and not args.dry_run:
            subprocess.run([sys.executable, '-I', os.path.join(HERE, 'cutout.py'), grid, ART, *OBJECTS],
                           check=False)

print(f'{made} pictures generated')
