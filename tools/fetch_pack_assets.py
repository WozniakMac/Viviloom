"""Fetch selected CC0 pack entries with validated HTTP byte ranges, without restarting the pack download."""
import io, urllib.request, zipfile, sys
from pathlib import Path
URL='https://files2.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip'
SIZE=280737770
PACK='system-assets'
if '--pack=hair01' in sys.argv:
    sys.argv.remove('--pack=hair01')
    PACK='hair01'
    URL='https://files2.makehumancommunity.org/asset_packs/hair01/hair01_cc0.zip'
    SIZE=227775853
class RemoteZip(io.RawIOBase):
    def __init__(self): self.position=0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.position
    def seek(self,offset,whence=0):
        self.position=offset if whence==0 else self.position+offset if whence==1 else SIZE+offset
        return self.position
    def read(self,count=-1):
        count=min(count if count>=0 else SIZE-self.position,SIZE-self.position)
        if count<=0:return b''
        start=self.position;end=start+count-1
        req=urllib.request.Request(URL,headers={'Range':f'bytes={start}-{end}'})
        with urllib.request.urlopen(req,timeout=90) as response:
            if response.status!=206 or response.headers.get('Content-Range')!=f'bytes {start}-{end}/{SIZE}':raise ValueError('Server did not honor exact byte range')
            data=response.read()
        if len(data)!=count:raise ValueError('Incomplete range')
        self.position+=count
        return data
root=Path('assets/source/makehuman'/Path(PACK)).resolve()
with zipfile.ZipFile(RemoteZip()) as archive:
    entries=archive.infolist()
    if '--list-all' not in sys.argv and len(sys.argv)==1:entries=[entry for entry in entries if entry.filename.startswith('hair/')]
    if len(sys.argv)==1 or '--list-all' in sys.argv:
        for entry in entries: print(entry.filename,entry.file_size,flush=True)
    else:
        for entry in entries:
            if not any(entry.filename.startswith(name if '/' in name else 'hair/'+name+'/') for name in sys.argv[1:]):continue
            target=(root/entry.filename).resolve()
            if root not in target.parents:raise ValueError('Unsafe asset path')
            if entry.is_dir() or target.exists():continue
            data=archive.read(entry)
            target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
            print('FETCHED',entry.filename,len(data),flush=True)
