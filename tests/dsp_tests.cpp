#include "../src/DSP.hpp"
#include <iostream>
#include <cstdlib>
#include <limits>
void require(bool yes,const char* msg){if(!yes){std::cerr<<"FAIL: "<<msg<<'\n';std::exit(1);}}
vp::Audio tone(double hz,double amp=0.3,double seconds=2,unsigned channels=1){vp::Audio a;a.channels=channels;a.samples.resize(size_t(seconds*a.sampleRate)*channels);for(size_t i=0;i<a.frames();i++)for(unsigned ch=0;ch<channels;ch++)a.samples[i*channels+ch]=amp*std::sin(2*3.141592653589793*hz*i/a.sampleRate);return a;}
double tailRms(const vp::Audio& a){double e=0;size_t begin=a.samples.size()/2;for(size_t i=begin;i<a.samples.size();i++)e+=a.samples[i]*a.samples[i];return std::sqrt(e/(a.samples.size()-begin));}
int main(){
 int checks=0;
 auto a=tone(1000);auto unity=vp::render(a,{0,0,0});require(a.samples==unity.audio.samples,"bypass settings are exact below protection ceiling");checks++;
 auto low=tone(20),voice=tone(1000);auto filteredLow=vp::render(low,{100,0,0}),filteredVoice=vp::render(voice,{100,0,0});require(vp::db(tailRms(filteredLow.audio)/tailRms(low)) < -27,"20Hz suppression exceeds 27dB at 100Hz cutoff");require(std::abs(vp::db(tailRms(filteredVoice.audio)/tailRms(voice))) < .05,"1kHz passband retained within .05dB");checks+=2;
 auto cutoff=vp::render(tone(100),{100,0,0});require(std::abs(vp::db(tailRms(cutoff.audio)/tailRms(tone(100)))+3.0103)<.02,"Butterworth cutoff matches -3dB");checks++;
 auto quiet=vp::render(tone(1000,.04),{0,1,0}),loud=vp::render(tone(1000,.4),{0,1,0});require(vp::db(tailRms(loud.audio)/tailRms(quiet.audio)) < 13,"20dB input change compressed to less than 13dB");checks++;
 auto stereo=tone(500,.2,2,2);for(size_t i=0;i<stereo.frames();i++)stereo.samples[i*2+1]*=.5;auto linked=vp::render(stereo,{0,.8,0});for(size_t i=0;i<stereo.frames();i++)require(std::abs(linked.audio.samples[i*2+1]-.5*linked.audio.samples[i*2])<1e-7,"stereo link preserves image");checks++;
 auto hot=vp::render(tone(1000,.95),{0,0,12});require(hot.after.peakDb<=-.99999&&hot.after.clipped==0&&hot.peakProtectionDb<0,"sample peak protection below -1dBFS");checks++;
 auto silence=tone(0,0);auto silent=vp::render(silence,{180,1,12});require(silent.after.peakDb==-120,"silence remains silence");checks++;
 auto input=tone(440,.5,1,2);vp::Processor whole(48000,2,{80,.7,3}),blocks(48000,2,{80,.7,3});std::vector<float> x(input.samples.size()),y(x.size());whole.process(input.samples.data(),x.data(),input.frames());for(size_t i=0;i<input.frames();i+=137)blocks.process(input.samples.data()+i*2,y.data()+i*2,std::min(size_t(137),input.frames()-i));require(x==y,"block boundaries do not alter DSP state or output");checks++;
 for(auto sr:{8000.,44100.,48000.,96000.,192000.}){auto sample=tone(300);sample.sampleRate=sr;auto r=vp::render(sample,{180,1,12});for(float z:r.audio.samples)require(std::isfinite(z),"stable over supported sample rates");}checks++;
 bool caught=false;try{auto bad=a;bad.samples[0]=std::numeric_limits<float>::quiet_NaN();vp::render(bad,{});}catch(...){caught=true;}require(caught,"nonfinite samples rejected");checks++;
 caught=false;try{vp::render(a,{999,0,0});}catch(...){caught=true;}require(caught,"invalid settings rejected");checks++;
 for(auto ch:{1u,2u}){auto v=tone(900,.3,.1,ch);auto r=vp::render(v,{});require(r.audio.frames()==v.frames()&&r.audio.channels==ch&&r.audio.sampleRate==v.sampleRate,"render preserves dimensions");}checks++;
 std::cout<<checks<<" DSP checks passed\n";
}
