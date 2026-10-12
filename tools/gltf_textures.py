"""Move a selected GLB image into an external runtime texture without recompression."""
import json
import struct
from pathlib import Path


def externalize_image(path, image_name, filename):
    path=Path(path)
    source=path.read_bytes()
    magic,version,length=struct.unpack_from('<III',source)
    if magic!=0x46546c67 or version!=2 or length!=len(source):
        raise ValueError('Expected a valid glTF 2 binary')
    size,kind=struct.unpack_from('<II',source,12)
    if kind!=0x4e4f534a:raise ValueError('Missing GLB JSON chunk')
    document=json.loads(source[20:20+size])
    offset=20+size
    binary_size,binary_kind=struct.unpack_from('<II',source,offset)
    if binary_kind!=0x004e4942:raise ValueError('Missing GLB binary chunk')
    binary=source[offset+8:offset+8+binary_size]
    image=next(item for item in document['images'] if item.get('name')==image_name)
    if 'bufferView' not in image:raise ValueError('Image is already external')
    removed=image['bufferView']
    view=document['bufferViews'][removed]
    if view.get('buffer',0)!=0:raise ValueError('Expected one embedded buffer')
    start=view.get('byteOffset',0)
    texture=binary[start:start+view['byteLength']]
    if len(texture)!=view['byteLength']:raise ValueError('Truncated image')
    (path.parent/filename).write_bytes(texture)
    image.pop('bufferView')
    image['uri']=filename
    remap={};views=[];chunks=[];binary_length=0
    for old,original in enumerate(document['bufferViews']):
        if old==removed:continue
        if original.get('buffer',0)!=0:raise ValueError('Expected one embedded buffer')
        padding=(-binary_length)%4
        chunks.append(bytes(padding));binary_length+=padding
        view=dict(original);start=view.get('byteOffset',0)
        chunk=binary[start:start+view['byteLength']]
        if len(chunk)!=view['byteLength']:raise ValueError('Truncated buffer view')
        view['byteOffset']=binary_length
        chunks.append(chunk);binary_length+=len(chunk)
        remap[old]=len(views);views.append(view)
    for accessor in document.get('accessors',[]):
        if 'bufferView' in accessor:accessor['bufferView']=remap[accessor['bufferView']]
        for item in accessor.get('sparse',{}).values():
            if isinstance(item,dict) and 'bufferView' in item:item['bufferView']=remap[item['bufferView']]
    for image in document['images']:
        if 'bufferView' in image:image['bufferView']=remap[image['bufferView']]
    document['bufferViews']=views
    document['buffers'][0]['byteLength']=binary_length
    payload=b''.join(chunks);payload+=bytes((-len(payload))%4)
    encoded=json.dumps(document,separators=(',',':'),ensure_ascii=False).encode('utf-8')
    encoded+=b' '*((-len(encoded))%4)
    result=struct.pack('<III',magic,version,28+len(encoded)+len(payload))
    result+=struct.pack('<II',len(encoded),0x4e4f534a)+encoded
    result+=struct.pack('<II',len(payload),0x004e4942)+payload
    path.write_bytes(result)
    print('EXTERNAL TEXTURE',filename,len(texture),'bytes; GLB',len(result),'bytes',flush=True)
