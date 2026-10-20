"""Reproducible, labeled faults on real speech from Open Speech Repository."""
import array,math,wave,hashlib,json
from pathlib import Path
root=Path(__file__).parent
with wave.open(str(root/'osr-source.wav'),'rb') as f:
    assert f.getnchannels()==1 and f.getsampwidth()==2
    sr=f.getframerate();raw=array.array('h',f.readframes(f.getnframes()))
# First 18 seconds, with changing speech gain and a deliberately added 35 Hz rumble.
raw=raw[:18*sr];out=array.array('h')
for i,v in enumerate(raw):
    t=i/sr
    # Smooth gain changes avoid artificial discontinuities between sections.
    quiet=.28 if t<6 else .95 if t<12 else .45
    if 5.9<t<6.1:quiet=.28+(.95-.28)*(t-5.9)/.2
    if 11.9<t<12.1:quiet=.95+(.45-.95)*(t-11.9)/.2
    rumble=.035*math.sin(2*math.pi*35*t)
    edge=min(1,t/.03,(18-t)/.03)
    sample=(v/32768*quiet+rumble)*max(0,edge)
    out.append(round(max(-.999,min(.999,sample))*32767))
with wave.open(str(root/'spoken-original.wav'),'wb') as f:
    f.setnchannels(1);f.setsampwidth(2);f.setframerate(sr);f.writeframes(out.tobytes())
manifest={'source':'Open Speech Repository','source_url':'https://www.voiptroubleshooter.com/open_speech/american/OSR_us_000_0010_8k.wav','conditions':'https://www.voiptroubleshooter.com/open_speech/','source_sha256':hashlib.sha256((root/'osr-source.wav').read_bytes()).hexdigest(),'example_sha256':hashlib.sha256((root/'spoken-original.wav').read_bytes()).hexdigest(),'description':'First 18 seconds of a human speech recording; deliberately added 35Hz rumble and smoothly varying speech gain. Source is 8kHz mono telephone-band speech.','sample_rate':sr}
(root/'provenance.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
