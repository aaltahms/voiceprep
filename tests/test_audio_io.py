import array,json,math,subprocess,tempfile,unittest,wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
CLI=ROOT/'build/voiceprep-cli'
def write(path,channels=1,rate=48000,seconds=.3):
    samples=array.array('h')
    for i in range(round(rate*seconds)):
        for ch in range(channels):samples.append(round(.15/(ch+1)*32767*math.sin(2*math.pi*500*i/rate)))
    with wave.open(str(path),'wb') as f:f.setnchannels(channels);f.setsampwidth(2);f.setframerate(rate);f.writeframes(samples.tobytes())
class AudioIO(unittest.TestCase):
 def test_export_format_dimensions_and_existing_file_preservation(self):
  with tempfile.TemporaryDirectory() as d:
   d=Path(d);src=d/'input.wav';out=d/'out.wav';write(src,2,44100);before=src.read_bytes()
   p=subprocess.run([str(CLI),str(src),str(out),'80','50','3'],capture_output=True,text=True);self.assertEqual(p.returncode,0,p.stderr)
   stats=json.loads(p.stdout);self.assertEqual(stats['channels'],2);self.assertEqual(stats['frames'],13230)
   with wave.open(str(out),'rb') as f:self.assertEqual((f.getnchannels(),f.getsampwidth(),f.getframerate(),f.getnframes()),(2,3,44100,13230))
   saved=out.read_bytes();p=subprocess.run([str(CLI),str(src),str(out),'80','50','3'],capture_output=True);self.assertNotEqual(p.returncode,0);self.assertEqual(out.read_bytes(),saved);self.assertEqual(src.read_bytes(),before)
 def test_malformed_audio_and_controls_create_no_output(self):
  with tempfile.TemporaryDirectory() as d:
   d=Path(d);src=d/'bad.wav';src.write_text('not an audio file');out=d/'out.wav'
   p=subprocess.run([str(CLI),str(src),str(out),'80','50','3'],capture_output=True);self.assertNotEqual(p.returncode,0);self.assertFalse(out.exists())
   write(src)
   for value in ['nan','80garbage','inf','-3']:
    p=subprocess.run([str(CLI),str(src),str(out),value,'50','3'],capture_output=True);self.assertNotEqual(p.returncode,0);self.assertFalse(out.exists())
 def test_aiff_and_m4a_import_preserve_decoded_audio_dimensions(self):
  with tempfile.TemporaryDirectory() as directory:
   d=Path(directory);src=d/'source.wav';write(src,channels=2,rate=48000)
   for extension,container,encoding in [('aiff','AIFF','BEI16'),('m4a','m4af','aac')]:
    with self.subTest(format=extension):
     imported=d/('input.'+extension);exported=d/(extension+'-out.wav')
     conversion=subprocess.run(['/usr/bin/afconvert','-f',container,'-d',encoding,str(src),str(imported)],capture_output=True,text=True)
     self.assertEqual(conversion.returncode,0,conversion.stderr)
     output=subprocess.run([str(CLI),str(imported),str(exported),'80','50','3'],capture_output=True,text=True)
     self.assertEqual(output.returncode,0,output.stderr);stats=json.loads(output.stdout)
     self.assertEqual(stats['channels'],2);self.assertEqual(stats['sample_rate'],48000)
     self.assertAlmostEqual(stats['duration_s'],.3,delta=.06)
     with wave.open(str(exported),'rb') as audio:
      self.assertEqual((audio.getnchannels(),audio.getframerate(),audio.getnframes()),(2,48000,stats['frames']))
 def test_sample_fixture_dimensions_and_deterministic_output(self):
  src=ROOT/'examples/spoken-original.wav'
  with tempfile.TemporaryDirectory() as d:
   paths=[Path(d)/'a.wav',Path(d)/'b.wav']
   for path in paths:
    p=subprocess.run([str(CLI),str(src),str(path),'80','50','3'],capture_output=True,text=True);self.assertEqual(p.returncode,0,p.stderr)
    stats=json.loads(p.stdout);self.assertEqual(stats['frames'],144000);self.assertEqual(stats['sample_rate'],8000);self.assertLessEqual(stats['output_peak_dbfs'],-1)
   self.assertEqual(paths[0].read_bytes(),paths[1].read_bytes())
if __name__=='__main__':unittest.main()
