from pathlib import Path
import urllib.request
source='https://files2.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip'
target=Path('assets/source/makehuman/system-assets-cc0.zip')
offset=target.stat().st_size
request=urllib.request.Request(source,headers={'Range':f'bytes={offset}-','User-Agent':'OpenSims-asset-import/1.0'})
with urllib.request.urlopen(request,timeout=90) as response:
    if response.status!=206 or not response.headers.get('Content-Range','').startswith(f'bytes {offset}-'):
        raise RuntimeError('Server did not confirm requested resume range; partial file preserved')
    print('RESUMING',offset,response.headers['Content-Range'],flush=True)
    with target.open('ab') as output:
        while True:
            block=response.read(65536)
            if not block:break
            output.write(block);output.flush()
    print('DOWNLOAD COMPLETE',target.stat().st_size,flush=True)
