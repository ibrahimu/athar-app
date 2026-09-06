"""Regenerate Wallet artwork and sign locally. Private keys never enter the repository.
Usage: python3 store/wallet/rebuild.py --key /path/pass.key --certificate /path/pass.pem --chain /path/wwdr.pem
"""
import argparse, hashlib, json, pathlib, subprocess, tempfile, zipfile, shutil
parser=argparse.ArgumentParser()
for flag in ('key','certificate','chain'): parser.add_argument('--'+flag,required=True,type=pathlib.Path)
args=parser.parse_args()
root=pathlib.Path(__file__).resolve().parents[2]
folder=root/'Athar/Resources/WalletPasses'
cards=json.loads((folder/'passes.json').read_text())
with tempfile.TemporaryDirectory(prefix='athar-wallet-') as temp:
    tmp=pathlib.Path(temp); jobs=[]
    for card in cards:
        work=tmp/card['id']; work.mkdir()
        source=folder/(card['id']+'-cream.pkpass')
        with zipfile.ZipFile(source) as archive:
            # Only the pass assets, never arbitrary archive paths.
            for name in archive.namelist():
                if '/' not in name and name not in ('manifest.json','signature'): (work/name).write_bytes(archive.read(name))
        metadata=json.loads((work/'pass.json').read_text())
        text=metadata['storeCard']['backFields'][0]['value'].lstrip('\u200f')
        jobs.append(dict(text=text,title=card['title'],out=str(work)))
        metadata.pop('barcodes',None)
        metadata['storeCard']['headerFields']=[dict(key='title',label='بطاقة قرآنية' if card['kind']=='quran' else 'بطاقة ذكر',value=card['title'],textAlignment='PKTextAlignmentRight')]
        count=card['count']
        repetition='مرة واحدة' if count<=1 else 'مرتان' if count==2 else f'{count} مرات' if count<=10 else f'{count} مرة'
        metadata['storeCard']['secondaryFields']=[dict(key='category',label='القسم',value=card['category'],textAlignment='PKTextAlignmentRight')]
        if card['kind']=='dhikr': metadata['storeCard']['auxiliaryFields']=[dict(key='count',label='التكرار',value=repetition,textAlignment='PKTextAlignmentRight')]
        for field in metadata['storeCard']['backFields']:
            field['textAlignment']='PKTextAlignmentRight'
            if field['key']!='app': field['value']='\u200f'+field['value'].lstrip('\u200f')
        # Stable serial numbers replace an existing card instead of duplicating it.
        assert metadata['serialNumber']==card['serial']
        (work/'pass.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2))
    (tmp/'jobs.json').write_text(json.dumps(jobs,ensure_ascii=False))
    subprocess.run(['swiftc','-module-cache-path',str(tmp/'module-cache'),str(root/'store/wallet/render.swift'),'-o',str(tmp/'renderer')],check=True)
    subprocess.run([str(tmp/'renderer'),str(root),str(tmp/'jobs.json')],check=True)
    for card in cards:
        work=tmp/card['id']
        manifest={p.name:hashlib.sha1(p.read_bytes()).hexdigest() for p in work.iterdir() if p.is_file()}
        (work/'manifest.json').write_text(json.dumps(manifest,sort_keys=True))
        subprocess.run(['openssl','smime','-binary','-sign','-certfile',str(args.chain),'-signer',str(args.certificate),'-inkey',str(args.key),'-in',str(work/'manifest.json'),'-out',str(work/'signature'),'-outform','DER'],check=True)
        subprocess.run(['openssl','smime','-verify','-binary','-inform','DER','-in',str(work/'signature'),'-content',str(work/'manifest.json'),'-noverify','-out',str(tmp/'verified')],check=True,stderr=subprocess.DEVNULL)
        with zipfile.ZipFile(tmp/(card['id']+'.pkpass'),'w',zipfile.ZIP_DEFLATED) as archive:
            for asset in sorted(work.iterdir()): archive.write(asset,asset.name)
    # Only replace shipped files after every signature has been verified.
    for card in cards:
        shutil.copyfile(tmp/(card['id']+'.pkpass'),folder/(card['id']+'-cream.pkpass'))
        shutil.copyfile(tmp/card['id']/'strip@3x.png',folder/(card['id']+'-preview.png'))
print(f'Rebuilt and verified {len(cards)} passes.')
