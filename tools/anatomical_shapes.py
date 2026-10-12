"""Native Anny phenotype deltas, with a combined weight/muscle corrective."""
from mathutils import Vector

def add_body_shapes(body):
    names=['Heavy','Fit','HeavyFit']
    deltas={name:[item.vector.copy() for item in body.data.attributes['Anny'+name+'Delta'].data] for name in names}
    positions=[vertex.co.copy() for vertex in body.data.vertices]
    body.shape_key_add(name='Basis')
    for name in names:
        key=body.shape_key_add(name=name)
        for index,p in enumerate(positions):
            delta=deltas[name][index]
            if name=='HeavyFit':delta=delta-deltas['Heavy'][index]-deltas['Fit'][index]
            # Keep the body/head join fixed until head phenotypes are integrated.
            t=max(0.,min(1.,(1.54-p.z)/.10));fade=t*t*(3-2*t)
            key.data[index].co=p+delta*fade
