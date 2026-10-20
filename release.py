"""Scoped source release; exclude recordings chosen by the user and runtime data."""
from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parent
ROOT_FILES=['README.md','LICENSE','.gitignore','build.sh','Info.plist','release.py','build-plugin.sh','install-plugin.sh','Plugin-Info.plist']
DIRS=['src','tests','docs','examples','.github']
def main():
 paths=[ROOT/p for p in ROOT_FILES]
 for name in DIRS:
  paths.extend(p for p in (ROOT/name).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc' and p.name!='.DS_Store')
 paths.extend([ROOT/'vendor/README.md',ROOT/'vendor/AudioUnitSDK/LICENSE.txt',ROOT/'vendor/AudioUnitSDK/readme.md'])
 for name in ['include','src']:
  paths.extend(p for p in (ROOT/'vendor/AudioUnitSDK'/name).rglob('*') if p.is_file())
 paths=sorted(set(paths));manifest={'version':'0.1.0','files':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}}
 target=ROOT/'dist';target.mkdir(exist_ok=True)
 archive=target/'voiceprep-0.1.0-source.zip'
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
  for p in paths:z.write(p,'voiceprep/'+str(p.relative_to(ROOT)))
  z.writestr('voiceprep/RELEASE-MANIFEST.json',json.dumps(manifest,indent=2)+'\n')
 digest=hashlib.sha256(archive.read_bytes()).hexdigest();archive.with_suffix('.zip.sha256').write_text(digest+'  '+archive.name+'\n')
 print(f'{len(paths)} scoped files\n{archive}\nSHA256 {digest}')
if __name__=='__main__':main()
