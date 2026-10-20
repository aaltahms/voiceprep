"""Measured behavior on an attributed speech recording with introduced faults."""
import array,json,math,subprocess,wave
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=root/'examples/spoken-original.wav';out=root/'build/listening-prepared.wav'
if out.exists():out.unlink()
p=subprocess.run([str(root/'build/voiceprep-cli'),str(source),str(out),'80','50','3'],text=True,capture_output=True,check=True)
def samples(path):
 with wave.open(str(path),'rb') as f:
  data=f.readframes(f.getnframes());width=f.getsampwidth();sr=f.getframerate()
  if width==2:values=[v/32768 for v in array.array('h',data)]
  else:values=[int.from_bytes(data[i:i+3],'little',signed=True)/8388608 for i in range(0,len(data),3)]
 return values,sr
def component(v,sr,hz):
 n=len(v);real=sum(x*math.cos(2*math.pi*hz*i/sr) for i,x in enumerate(v));imag=sum(x*math.sin(2*math.pi*hz*i/sr) for i,x in enumerate(v));return 2*math.hypot(real,imag)/n
before,sr=samples(source);after,sr2=samples(out);assert sr==sr2 and len(before)==len(after)
change=20*math.log10(component(after,sr,35)/component(before,sr,35))
assert change < -10,change
record={'description':'Human speech with deliberately added 35Hz rumble and changing gain; 80Hz filter, 50% leveling, +3dB output.','introduced_35hz_component_change_db':change,'render':json.loads(p.stdout),'perceived_quality_claim':False}
(root/'build/speech-measurement.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2))
