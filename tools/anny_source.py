"""Read Anny's CC0 MakeHuman rest mesh in the existing source coordinates."""
from pathlib import Path
import numpy as np
import os

ROOT=Path(__file__).resolve().parent.parent

def active_preset():
    return os.environ.get('ANNY_PRESET','adult-male')

def load_raw_points(preset=None):
    preset=preset or active_preset()
    path=ROOT/'assets/source/anny'/(preset+'.npz')
    if not path.exists():
        return None
    data=np.load(path)
    vertices=data['vertices']
    indices=data['base_indices']
    if len(vertices)!=19158 or not np.array_equal(indices,np.arange(19158)):
        raise ValueError('Anny source must retain the exact MakeHuman vertex indexing')
    raw=np.stack([vertices[:,0]*10,vertices[:,2]*10,-vertices[:,1]*10],axis=1)
    body=set();group=''
    for line in (ROOT/'assets/source/makehuman/base.obj').read_text().splitlines():
        if line.startswith('g '):group=line[2:].strip()
        elif line.startswith('f ') and group=='body':
            body.update(int(token.split('/')[0])-1 for token in line.split()[1:])
    body_height=raw[sorted(body),1]
    floor=float(body_height.min())
    scale=(1.84/.11)/float(body_height.max()-floor)
    raw[:,0]*=scale
    raw[:,2]*=scale
    raw[:,1]=(raw[:,1]-floor)*scale-8.1676
    if preset.startswith('adult-female'):
        # An original restrained face refinement, shared by the base, actions,
        # body variants and every barycentrically fitted accessory. UVs stay native.
        x=raw[:,0]*.11; y=raw[:,2]*.11; z=(raw[:,1]+8.1676)*.11
        jaw=np.exp(-((z-1.610)/.035)**2)
        raw[:,0] *= 1.-.105*jaw
        chin=np.exp(-((z-1.588)/.024)**2)*np.exp(-(x/.070)**4)
        raw[:,1] += (.007*chin)/.11
        cheek=np.exp(-((abs(x)-.060)/.035)**2-((z-1.666)/.032)**2)
        raw[:,0] += (np.sign(x)*.0025*cheek)/.11
        raw[:,2] += (.0025*cheek)/.11
        front=np.clip((y-.045)/.04,0.,1.)
        nose=np.exp(-((x/.022)**2+((z-1.676)/.023)**2))*front
        raw[:,0] *= 1.-.105*nose
        raw[:,2] -= (.002*nose)/.11
        lip=np.exp(-((x/.038)**4+((z-1.649)/.012)**2))*front
        raw[:,2] += (.0020*lip)/.11
    print('ANNY SOURCE:',preset, len(raw),'vertices, normalized height 1.84 m')
    return raw.tolist()
