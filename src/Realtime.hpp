#pragma once
#include "DSP.hpp"
#include <array>
namespace vp {
// All storage is fixed; no allocation, locks or file operations on the render thread.
// 5 ms lookahead, linked sample-peak limiter with an 80 ms release.
class RealtimeProcessor {
 Processor processor; double sr,release,limiterGain=1,smooth; unsigned channels,delay;
 Settings current,target; unsigned tick=0; uint64_t frame=0,head=0,tail=0;
 std::array<std::array<float,2>,1024> ring{};
 struct Peak {double value=0;uint64_t index=0;}; std::array<Peak,2048> peaks{};
 public:
 RealtimeProcessor(double rate,unsigned ch,Settings s={}):processor(rate,ch,s),sr(rate),release(std::exp(-1/(.080*rate))),smooth(std::exp(-32/(.020*rate))),channels(ch),delay(unsigned(std::ceil(.005*rate))),current(s),target(s){}
 unsigned latencyFrames()const noexcept{return delay;}
 void setSettings(Settings s)noexcept{
  // A host can deliver arbitrary values; sanitize before touching DSP coefficients.
  target={std::isfinite(s.rumbleHz)?std::clamp(s.rumbleHz,0.,180.):80.,std::isfinite(s.leveling)?std::clamp(s.leveling,0.,1.):.5,std::isfinite(s.gainDb)?std::clamp(s.gainDb,-12.,12.):3.};
 }
 void processFrame(const float* input,float* output)noexcept{
  if((tick++%32)==0){current.rumbleHz=target.rumbleHz+(current.rumbleHz-target.rumbleHz)*smooth;current.leveling=target.leveling+(current.leveling-target.leveling)*smooth;current.gainDb=target.gainDb+(current.gainDb-target.gainDb)*smooth;processor.update(current,sr);}
  float clean[2]{},wet[2]{};for(unsigned c=0;c<channels;c++)clean[c]=std::isfinite(input[c])?std::clamp(input[c],-16.f,16.f):0;
  processor.process(clean,wet,1);double peak=0;for(unsigned c=0;c<channels;c++)peak=std::max(peak,std::abs(double(wet[c])));
  while(tail>head&&peaks[(tail-1)%peaks.size()].value<=peak)--tail;
  peaks[tail++%peaks.size()]={peak,frame};
  while(tail>head&&peaks[head%peaks.size()].index+delay<frame)++head;
  double desired=std::min(1.,amplitude(-1)/std::max(peaks[head%peaks.size()].value,1e-12));
  limiterGain=desired<limiterGain?desired:release*limiterGain+(1-release)*desired;
  auto& slot=ring[frame%(delay+1)];for(unsigned c=0;c<channels;c++)slot[c]=wet[c];
  for(unsigned c=0;c<channels;c++)output[c]=frame>=delay?float(ring[(frame-delay)%(delay+1)][c]*limiterGain):0;
  ++frame;
 }
 void process(const float* in,float* out,size_t frames)noexcept{for(size_t i=0;i<frames;i++)processFrame(in+i*channels,out+i*channels);}
};
}
