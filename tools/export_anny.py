from pathlib import Path
import os
import logging
os.environ['ANNY_CACHE_DIR']=str(Path('.anny-cache').resolve())
logging.basicConfig(level=logging.INFO)
import torch,anny
print('VERSION',anny.__version__,flush=True)
model=anny.Anny(topology='makehuman',rig='makehuman',local_changes='default',facial_actions='all',skinning_method='lbs').to(dtype=torch.float32)
print('CONTROLS',len(model.phenotype_labels),'phenotypes,',len(model.local_change_labels),'local changes,',len(model.facial_action_labels),'facial actions',flush=True)
output=model(phenotype_kwargs={'gender':0.,'age':2/3,'weight':.45,'muscle':.5})
print('OUTPUT',[(key,tuple(value.shape)) for key,value in output.items() if isinstance(value,torch.Tensor)],flush=True)
print('BOUNDS',output['vertices'].amin(dim=1),output['vertices'].amax(dim=1),flush=True)
print('INDICES',model.base_mesh_vertex_indices.shape,model.base_mesh_vertex_indices[:10],flush=True)
Path('assets/source/anny').mkdir(parents=True,exist_ok=True)
import numpy as np
np.savez_compressed('assets/source/anny/adult-male.npz',vertices=output['rest_vertices'][0].detach().numpy(),base_indices=model.base_mesh_vertex_indices.cpu().numpy(),faces=model.faces.cpu().numpy())
print('ANNY MESH EXPORTED',flush=True)
for label,weight,muscle in [('heavy',1.,.5),('fit',.45,1.),('heavy-fit',1.,1.)]:
    variant=model(phenotype_kwargs={'gender':0.,'age':2/3,'weight':weight,'muscle':muscle})
    np.savez_compressed('assets/source/anny/adult-male-'+label+'.npz',vertices=variant['rest_vertices'][0].detach().numpy(),base_indices=model.base_mesh_vertex_indices.cpu().numpy(),faces=model.faces.cpu().numpy())
    print('ANNY PHENOTYPE EXPORTED',label,flush=True)




ACTIONS={
    'Blink':{'eyeBlinkLeft':1.,'eyeBlinkRight':1.},
    'Smile':{'mouthSmileLeft':.7,'mouthSmileRight':.7,'cheekSquintLeft':.25,'cheekSquintRight':.25},
    'Frown':{'mouthFrownLeft':.7,'mouthFrownRight':.7,'mouthPressLeft':.2,'mouthPressRight':.2},
    'BrowAngry':{'browDownLeft':.65,'browDownRight':.65,'eyeSquintLeft':.15,'eyeSquintRight':.15},
    'BrowSad':{'browInnerUp':.55,'browDownLeft':.15,'browDownRight':.15},
}
for name,actions in ACTIONS.items():
    expression=model(phenotype_kwargs={'gender':0.,'age':2/3,'weight':.45,'muscle':.5},facial_actions=actions)
    np.savez_compressed('assets/source/anny/adult-male-action-'+name+'.npz',vertices=expression['rest_vertices'][0].detach().numpy(),base_indices=model.base_mesh_vertex_indices.cpu().numpy(),faces=model.faces.cpu().numpy())
    print('ANNY FACIAL ACTION EXPORTED',name,flush=True)

import json
metadata={"source":"https://github.com/naver/anny","version":anny.__version__,"topology":"makehuman","rig":"makehuman","phenotypes":{"gender":0.0,"age":2/3,"weight":.45,"muscle":.5},"phenotype_labels":model.phenotype_labels,"local_change_labels":model.local_change_labels,"facial_action_labels":model.facial_action_labels,"exported_actions":ACTIONS,"data_license":"CC0","code_license":"Apache-2.0"}
Path('assets/source/anny/preset.json').write_text(json.dumps(metadata,indent=2))
