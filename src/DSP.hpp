#pragma once
#include <vector>
#include <cmath>
#include <algorithm>
#include <stdexcept>
#include <cstdint>
namespace vp {
struct Audio { double sampleRate=48000; unsigned channels=1; std::vector<float> samples; size_t frames() const{return samples.size()/channels;} };
struct Settings { double rumbleHz=80, leveling=.5, gainDb=3; };
struct Stats { double peakDb=-120,rmsDb=-120; size_t clipped=0; };
inline double db(double x){return 20*std::log10(std::max(x,1e-6));}
inline double amplitude(double d){return std::pow(10.,d/20);}
inline void validate(const Audio& a,const Settings& s){
 if(a.channels<1||a.channels>2||!std::isfinite(a.sampleRate)||a.sampleRate<8000||a.sampleRate>192000||a.samples.empty()||a.samples.size()%a.channels)throw std::runtime_error("Use a nonempty mono or stereo recording at 8–192 kHz.");
 if(a.samples.size()>24000000)throw std::runtime_error("This version accepts up to 24 million samples (about four minutes of stereo at 48 kHz).");
 if(!std::isfinite(s.rumbleHz)||s.rumbleHz<0||s.rumbleHz>180||!std::isfinite(s.leveling)||s.leveling<0||s.leveling>1||!std::isfinite(s.gainDb)||s.gainDb < -12||s.gainDb>12)throw std::runtime_error("Sound controls are outside their supported range.");
 for(float x:a.samples)if(!std::isfinite(x)||std::abs(x)>16)throw std::runtime_error("The recording contains invalid or unsupported sample values.");
}
inline Stats measure(const Audio& a){
 Stats out;double energy=0,peak=0;
 for(float x:a.samples){peak=std::max(peak,std::abs(double(x)));energy+=double(x)*x;if(std::abs(x)>=1)out.clipped++;}
 out.peakDb=db(peak);out.rmsDb=db(std::sqrt(energy/std::max(size_t(1),a.samples.size())));return out;
}
// Stateful, interleaved block processor. Coefficients are set before processing;
// process() allocates no memory and takes no locks. Stereo gain is linked.
class Processor {
 double b0=1,b1=0,b2=0,a1=0,a2=0,z1[2]{},z2[2]{},gr=0,attack,release,ratio,makeup;unsigned channels;
 public:
 Processor(double sr,unsigned ch,Settings s):channels(ch){
  if(ch<1||ch>2||!std::isfinite(sr)||sr<8000||sr>192000||!std::isfinite(s.rumbleHz)||s.rumbleHz<0||s.rumbleHz>180||!std::isfinite(s.leveling)||s.leveling<0||s.leveling>1||!std::isfinite(s.gainDb)||std::abs(s.gainDb)>12)throw std::runtime_error("Invalid processor configuration.");
  update(s,sr);
  attack=std::exp(-1/(.008*sr));release=std::exp(-1/(.180*sr));
 }
 void update(Settings s,double sr) noexcept {
  b0=1;b1=b2=a1=a2=0;
  if(s.rumbleHz>0){double w=2*3.141592653589793*s.rumbleHz/sr,c=std::cos(w),al=std::sin(w)/(2*std::sqrt(.5)),a0=1+al;b0=(1+c)/2/a0;b1=-(1+c)/a0;b2=b0;a1=-2*c/a0;a2=(1-al)/a0;}
  ratio=1+3*s.leveling;makeup=amplitude(s.gainDb);
 }
 void process(const float* in,float* out,size_t frames){
  for(size_t i=0;i<frames;i++){
   double v[2]{},peak=0;
   for(unsigned ch=0;ch<channels;ch++){double x=in[i*channels+ch];v[ch]=b0*x+z1[ch];z1[ch]=b1*x-a1*v[ch]+z2[ch];z2[ch]=b2*x-a2*v[ch];peak=std::max(peak,std::abs(v[ch]));}
   double over=std::max(0.,db(peak)+24),desired=-over*(1-1/ratio),coef=desired<gr?attack:release;
   gr=coef*gr+(1-coef)*desired;double gain=amplitude(gr)*makeup;
   for(unsigned ch=0;ch<channels;ch++)out[i*channels+ch]=float(v[ch]*gain);
  }
 }
};
struct Result { Audio audio; Stats before,after; double peakProtectionDb=0; };
inline Result render(const Audio& input,Settings settings){
 validate(input,settings);Result r;r.before=measure(input);r.audio.sampleRate=input.sampleRate;r.audio.channels=input.channels;r.audio.samples.resize(input.samples.size());
 Processor p(input.sampleRate,input.channels,settings);p.process(input.samples.data(),r.audio.samples.data(),input.frames());
 // Offline look-ahead over the complete file: one transparent global gain trim,
 // rather than sample clipping. This bounds sample peaks, not inter-sample peaks.
 double peak=0;for(float x:r.audio.samples)peak=std::max(peak,std::abs(double(x)));
 double ceiling=amplitude(-1);if(peak>ceiling){double trim=ceiling/peak;r.peakProtectionDb=db(trim);for(float& x:r.audio.samples)x=float(x*trim);}
 r.after=measure(r.audio);return r;
}
}
