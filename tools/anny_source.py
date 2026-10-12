"""Read Anny's CC0 MakeHuman rest mesh in the existing source coordinates."""
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parent.parent

def load_raw_points(preset='adult-male'):
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
    print('ANNY SOURCE: adult male,',len(raw),'vertices, normalized height 1.84 m')
    return raw.tolist()
