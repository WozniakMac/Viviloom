"""Original region-aware weighting for the adapted anatomical mesh."""



def bind_body(body, rig):
    groups = {bone.name: body.vertex_groups.get(bone.name) or body.vertex_groups.new(name=bone.name) for bone in rig.data.bones}
    def smooth(value, low, high):
        t = max(0.0, min(1.0, (value-low)/(high-low)))
        return t*t*(3-2*t)
    def distance(point, bone):
        a = bone.head_local
        axis = bone.tail_local-a
        t = max(0.0, min(1.0, (point-a).dot(axis)/axis.length_squared))
        return (point-a-axis*t).length
    mask=body.data.attributes.get('AnatomicalArm')
    arm_values=[item.value for item in mask.data] if mask else [0.0]*len(body.data.vertices)
    hand_mask=body.data.attributes.get('AnatomicalHand')
    hand_values=[item.value for item in hand_mask.data] if hand_mask else [0.]*len(body.data.vertices)
    finger_values={attribute.name.removeprefix('NativeFinger_'):[item.value for item in attribute.data] for attribute in body.data.attributes if attribute.name.startswith('NativeFinger_')}
    vertex_ids=list(range(len(body.data.vertices)))
    for group in body.vertex_groups:
        group.remove(vertex_ids)
    for vertex in body.data.vertices:
        p = vertex.co
        side = 'L' if p.x >= 0 else 'R'
        arm_blend=arm_values[vertex.index]
        if p.z < .95:
            knee = smooth(p.z, .43, .57)
            ankle = smooth(p.z, .055, .16)
            pelvis = smooth(p.z, .82, .95)
            weights = {'foot.'+side: 1-ankle, 'shin.'+side: ankle*(1-knee), 'thigh.'+side: knee*(1-pelvis), 'hips': knee*pelvis}
        else:
            torso = ['hips', 'spine', 'chest', 'neck', 'head']

            candidates = torso
            weights = {name: 1/max(distance(p,rig.data.bones[name]),.008)**4 for name in candidates}
        total = sum(weights.values())
        weights = {name: weight/total*(1-arm_blend) for name,weight in weights.items()}
        arm_weights={name:1/max(distance(p,rig.data.bones[name]),.008)**4 for name in ['upperarm.'+side,'forearm.'+side,'hand.'+side]}
        arm_total=sum(arm_weights.values())
        for name,weight in arm_weights.items():
            weights[name]=weight/arm_total*arm_blend
        hand_blend=hand_values[vertex.index]
        weights={name:weight*(1-hand_blend) for name,weight in weights.items()}
        fingers={name:values[vertex.index] for name,values in finger_values.items() if name.endswith('.'+side) and values[vertex.index]>0.000001}
        total_finger=min(1.,sum(fingers.values()))
        weights['hand.'+side]=weights.get('hand.'+side,0.)+hand_blend*(1-total_finger)
        for name,weight in fingers.items():
            weights[name]=hand_blend*weight
        weights=dict(sorted(weights.items(),key=lambda item:item[1],reverse=True)[:4])
        total = sum(weights.values())
        for name, weight in weights.items():
            if weight > 0:
                groups[name].add([vertex.index],weight/total,'REPLACE')
