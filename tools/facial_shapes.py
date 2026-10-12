"""Original facial sculpt controls over the licensed anatomical base."""
import math

FEATURES=('NoseWidth','JawWidth','EyeSpacing','LipFullness')
def add_face_shapes(obj):
    from anatomical_body import read_base
    _,_,_,landmarks=read_base()
    eye_height=landmarks['joint-l-eye'].z
    obj.shape_key_add(name='Basis')
    for feature in FEATURES:
        key=obj.shape_key_add(name=feature)
        key.slider_min=-1.0
        key.slider_max=1.0
        for vertex in obj.data.vertices:
            x,y,z=vertex.co
            co=vertex.co.copy()
            front=max(0,min(1,(y-.05)/.05))
            if feature=='NoseWidth':
                weight=math.exp(-((x/.028)**2+((z-1.673)/.028)**2))*front
                co.x+=x*.55*weight
            elif feature=='JawWidth':
                weight=math.exp(-((z-1.616)/.041)**2)
                co.x+=x*.20*weight
            elif feature=='EyeSpacing':
                weight=math.exp(-((z-eye_height)/.028)**2)*front
                co.x+=(1 if x>0 else -1)*.007*weight*min(1,abs(x)/.018)
            elif feature=='LipFullness':
                weight=math.exp(-((x/.040)**4+((z-1.650)/.013)**2))*front
                co.y+=.005*weight
                co.z+=(z-1.650)*.32*weight
            key.data[vertex.index].co=co


ACTIONS=('Blink','Smile','Frown','BrowAngry','BrowSad')

def add_action_attributes(head,source_indices):
    """Native facial action deltas survive subdivision and neck cuts with the surface."""
    from anatomical_body import read_base
    from mathutils import Vector
    for action in ACTIONS:
        points,_,_,_=read_base('adult-male-action-'+action)
        attribute=head.data.attributes.new(name='AnnyAction'+action,type='FLOAT_VECTOR',domain='POINT')
        for index,original in enumerate(source_indices):
            p=points[original].copy()
            p.z-=.045*math.exp(-((p.z-1.25)/.25)**2)
            attribute.data[index].vector=p-head.data.vertices[index].co

def add_native_actions(head):
    # Joining native eyes adds zero deltas there, keeping eyeballs fixed under blinking lids.
    deltas={action:[item.vector.copy() for item in head.data.attributes['AnnyAction'+action].data] for action in ACTIONS}
    for action in ACTIONS:
        key=head.shape_key_add(name='Action'+action)
        for vertex in head.data.vertices:
            key.data[vertex.index].co=vertex.co+deltas[action][vertex.index]
