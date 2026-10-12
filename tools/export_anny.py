"""Export matching native Anny body and facial presets for both creator frames."""
from pathlib import Path
import os,json,logging,sys
os.environ['ANNY_CACHE_DIR']=str(Path('.anny-cache').resolve())
logging.basicConfig(level=logging.INFO)
import torch,anny,numpy as np
model=anny.Anny(topology='makehuman',rig='makehuman',local_changes='default',facial_actions='all',skinning_method='lbs').to(dtype=torch.float32)
ROOT=Path('assets/source/anny');ROOT.mkdir(parents=True,exist_ok=True)
# Native hand weights are independent of phenotype and preserve finger ownership.
hand_labels=[name for name in model.bone_labels if name.startswith('finger')]
hand_weights=np.zeros((19158,len(hand_labels)),dtype=np.float32)
indices=model.vertex_bone_indices.cpu().numpy()
weights=model.vertex_bone_weights.cpu().numpy()
for column,name in enumerate(hand_labels):
    hand_weights[:,column]=(weights*(indices==model.bone_labels.index(name))).sum(axis=1)
np.savez_compressed(ROOT/'native-hand-weights.npz',weights=hand_weights,labels=np.asarray(hand_labels),base_indices=model.base_mesh_vertex_indices.cpu().numpy())
if '--hands-only' in sys.argv:
    metadata=json.loads((ROOT/'preset.json').read_text())
    metadata['native_hand_weights']='native-hand-weights.npz'
    (ROOT/'preset.json').write_text(json.dumps(metadata,indent=2))
    print('NATIVE HAND WEIGHTS EXPORTED',hand_weights.shape,flush=True)
    sys.exit(0)
ACTIONS={
    'Blink':{'eyeBlinkLeft':1.,'eyeBlinkRight':1.},
    'Smile':{'mouthSmileLeft':.7,'mouthSmileRight':.7,'cheekSquintLeft':.25,'cheekSquintRight':.25},
    'Frown':{'mouthFrownLeft':.7,'mouthFrownRight':.7,'mouthPressLeft':.2,'mouthPressRight':.2},
    'BrowAngry':{'browDownLeft':.65,'browDownRight':.65,'eyeSquintLeft':.15,'eyeSquintRight':.15},
    'BrowSad':{'browInnerUp':.55,'browDownLeft':.15,'browDownRight':.15},
}

def export(name,gender,weight=.45,muscle=.5,actions=None,age=2/3):
    output=model(phenotype_kwargs={'gender':gender,'age':age,'weight':weight,'muscle':muscle},facial_actions=actions)
    np.savez_compressed(ROOT/(name+'.npz'),vertices=output['rest_vertices'][0].detach().numpy(),base_indices=model.base_mesh_vertex_indices.cpu().numpy(),faces=model.faces.cpu().numpy())
    print('ANNY EXPORTED',name,flush=True)

AGES={'toddler':.14,'child':1/3,'teen':.54,'adult':.83,'elder':1.}
if '--ages-only' in sys.argv:
    for frame,gender in [('male',0.),('female',1.)]:
        for stage,age in AGES.items():export('adult-'+frame+'-age-'+stage,gender,age=age)
    metadata=json.loads((ROOT/'preset.json').read_text())
    metadata['age_presets']=AGES
    (ROOT/'preset.json').write_text(json.dumps(metadata,indent=2))
    print('NATIVE AGE PRESETS EXPORTED',flush=True)
    sys.exit(0)

for frame,gender in [('male',0.),('female',1.)]:
    prefix='adult-'+frame
    export(prefix,gender)
    for label,weight,muscle in [('heavy',1.,.5),('fit',.45,1.),('heavy-fit',1.,1.)]:export(prefix+'-'+label,gender,weight,muscle)
    for name,actions in ACTIONS.items():export(prefix+'-action-'+name,gender,actions=actions)
    for stage,age in AGES.items():export(prefix+'-age-'+stage,gender,age=age)
metadata={'source':'https://github.com/naver/anny','version':anny.__version__,'topology':'makehuman','rig':'makehuman','phenotypes':{'gender':0.,'age':2/3,'weight':.45,'muscle':.5},'frames':{'masculine':{'preset':'adult-male','gender':0.},'feminine':{'preset':'adult-female','gender':1.}},'phenotype_labels':model.phenotype_labels,'local_change_labels':model.local_change_labels,'facial_action_labels':model.facial_action_labels,'exported_actions':ACTIONS,'age_presets':AGES,'native_hand_weights':'native-hand-weights.npz','data_license':'CC0','code_license':'Apache-2.0'}
(ROOT/'preset.json').write_text(json.dumps(metadata,indent=2))
