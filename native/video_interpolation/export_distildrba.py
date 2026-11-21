"""Export the MIT DistilDRBA v2 Lite checkpoint to the ncnn graph used by Kazumi.

Usage: python export_distildrba.py path/to/v2_lite.pkl assets/models/distildrba-v2-lite
Weights and architecture: routineLife1/DistilDRBA@db51bdeb452685cba9aee227c6dba42e67753b55.
Requires numpy and torch only at export time. The final warp runs on native video planes.
"""
import argparse
from collections import Counter
from hashlib import sha256
from pathlib import Path
import struct

import torch

SHA256 = '9de2437c40928d13c48fff0d5e1021b78c8446d544143a964d56c8a2b387c3ed'


class Graph:
    def __init__(self, weights):
        self.weights = weights
        self.layers = []
        self.binary = bytearray()

    def op(self, kind, *inputs, args='', name=None):
        name = name or f'v{len(self.layers)}'
        self.layers.append((kind, name, inputs, args))
        return name

    def conv(self, x, key, stride=1, transpose=False, beta=None):
        w, b = (self.weights[key + suffix].numpy() for suffix in ('.weight', '.bias'))
        if transpose:
            w = w.transpose(1, 0, 2, 3)
        if beta is not None:
            scale = self.weights[beta].numpy().reshape(-1)
            w, b = w * scale[:, None, None, None], b * scale
        self.binary.extend(struct.pack('<I', 0x01306B47))
        self.binary.extend(w.astype('<f2').tobytes())
        self.binary.extend(bytes((-len(self.binary)) % 4))
        self.binary.extend(b.astype('<f4').tobytes())
        return self.op('Deconvolution' if transpose else 'Convolution', x,
                       args=f'0={b.size} 1={w.shape[2]} 3={stride} 4=1 5=1 6={w.size}')

    def relu(self, x):
        return self.op('ReLU', x, args='0=0.2')

    def resize(self, x, scale):
        return x if scale == 1 else self.op('Interp', x, args=f'0=2 1={scale} 2={scale}')

    def channels(self, x, start, end, name=None):
        return self.op('Crop', x, args=f'-23309=1,{start} -23310=1,{end} -23311=1,0', name=name)

    def select(self, a, b, before, after):
        left = self.op('BinaryOp', a, before, args='0=2')
        right = self.op('BinaryOp', b, after, args='0=2')
        return self.op('BinaryOp', left, right, args='0=0')

    def head(self, x):
        for i in range(3):
            x = self.relu(self.conv(x, f'encode.cnn{i}', stride=2 if i == 0 else 1))
        return self.conv(x, 'encode.cnn3', stride=2, transpose=True)

    def block(self, inputs, index):
        root = f'block{index}'
        x = self.op('Concat', *inputs, args='0=0')
        for i in range(2):
            x = self.relu(self.conv(x, f'{root}.conv0.{i}.0', stride=2))
        for i in range(8):
            layer = f'{root}.convblock.{i}'
            y = self.conv(x, layer + '.conv', beta=layer + '.beta')
            x = self.relu(self.op('BinaryOp', x, y, args='0=0'))
        x = self.conv(x, root + '.lastconv.0', stride=2, transpose=True)
        return self.op('PixelShuffle', x, args='0=2')

    def build(self):
        images = [self.op('Input', name=f'rgb{s}') for s in (16, 8, 4)]
        time = self.op('Input', name='time16')
        after = self.op('Input', name='after')
        before = self.op('BinaryOp', after, args='0=7 1=1 2=1')
        heads = [self.head(self.channels(images[2], k, k + 3)) for k in (0, 3, 6)]
        all_heads = self.op('Concat', *heads, args='0=0')
        partner_head = self.select(heads[0], heads[2], before, after)
        for i, rgb in enumerate(images):
            scale = (0.25, 0.5, 1)[i]
            inputs = [rgb, self.resize(all_heads, scale)]
            if i:
                center = self.channels(rgb, 3, 6)
                partner = self.select(self.channels(rgb, 0, 3), self.channels(rgb, 6, 9), before, after)
                for source, start in ((center, 0), (partner, 2), (self.resize(heads[1], scale), 0),
                                      (self.resize(partner_head, scale), 2)):
                    inputs.append(self.op('rife.Warp', source, self.channels(flow, start, start + 2)))
            inputs.append(self.resize(time, 2**i))
            if i:
                inputs.extend((mask, feat, flow))
            result = self.block(inputs, i)
            if i < 2:
                flow = self.resize(self.channels(result, 0, 4), 2)
                flow = self.op('BinaryOp', flow, args='0=2 1=1 2=2')
                mask = self.resize(self.channels(result, 4, 5), 2)
                feat = self.resize(self.channels(result, 5, 13), 2)
        self.channels(result, 0, 5, name='motion')

    def save(self, directory):
        uses = Counter(x for _, _, inputs, _ in self.layers for x in inputs)
        indices = Counter()
        lines = []
        blobs = 0
        for kind, name, inputs, args in self.layers:
            ports = []
            for x in inputs:
                ports.append(f'{x}_{indices[x]}' if uses[x] > 1 else x)
                indices[x] += 1
            lines.append(' '.join([kind, name, str(len(inputs)), '1', *ports, name, args]).rstrip())
            blobs += 1
            if uses[name] > 1:
                outputs = [f'{name}_{n}' for n in range(uses[name])]
                lines.append(' '.join(['Split', f'split_{name}', '1', str(len(outputs)), name, *outputs]))
                blobs += len(outputs)
        directory.mkdir(parents=True, exist_ok=True)
        (directory / 'flownet.param').write_text(f'7767517\n{len(lines)} {blobs}\n' + '\n'.join(lines) + '\n',
                                                encoding='ascii', newline='\n')
        (directory / 'flownet.bin').write_bytes(self.binary)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('weights', type=Path)
    p.add_argument('destination', type=Path)
    args = p.parse_args()
    if sha256(args.weights.read_bytes()).hexdigest() != SHA256:
        p.error('Expected the pinned DistilDRBA v2 Lite checkpoint')
    graph = Graph(torch.load(args.weights, map_location='cpu', weights_only=True))
    graph.build()
    graph.save(args.destination)
