#include "../src/Realtime.hpp"
#include <iostream>
#include <limits>
#include <cstdlib>
void require(bool b,const char* label){if(!b){std::cerr<<"FAIL "<<label<<'\n';std::exit(1);}}
int main(){int checks=0;
 for(double sr:{8000.,44100.,48000.,96000.,192000.}){
  vp::RealtimeProcessor p(sr,2,{0,0,12});float in[2],out[2];
  for(int i=0;i<int(sr);i++){in[0]=i%499==0?8.f:float(.95*std::sin(i*.13));in[1]=in[0]*.5f;p.processFrame(in,out);require(std::isfinite(out[0])&&std::abs(out[0])<=vp::amplitude(-1)+1e-7,"lookahead bounds transient and sustained sample peaks");require(std::abs(out[1]-out[0]*.5f)<1e-7,"limiter stereo image");}checks+=2;
 }
 {vp::RealtimeProcessor p(48000,1,{0,0,0});float in=0,out;for(unsigned i=0;i<1000;i++){in=i==0?.2f:0;p.processFrame(&in,&out);require(out==(i==240?.2f:0),"5ms exact latency and dry gain below limiter threshold");}checks++;}
 {vp::RealtimeProcessor a(48000,2),b(48000,2);std::vector<float> input(48000),x(input.size()),y(input.size());for(size_t i=0;i<input.size();i++)input[i]=.6f*std::sin(i*.4);a.process(input.data(),x.data(),24000);for(size_t i=0;i<24000;i+=137)b.process(input.data()+2*i,y.data()+2*i,std::min(size_t(137),24000-i));require(x==y,"arbitrary callback block boundaries");checks++;}
 {vp::RealtimeProcessor p(48000,2);float in[2]={.6f,.3f},out[2];for(int i=0;i<48000;i++){if(i%127==0)p.setSettings({double(i%181),double(i%100)/100,double(i%25)-12});p.processFrame(in,out);require(std::isfinite(out[0])&&std::abs(out[0])<.892,"rapid automation stable and bounded");}p.setSettings({NAN,INFINITY,NAN});in[0]=NAN;in[1]=INFINITY;for(int i=0;i<1000;i++){p.processFrame(in,out);require(std::isfinite(out[0])&&std::isfinite(out[1]),"host nonfinite inputs sanitized");}checks+=2;}
 {vp::RealtimeProcessor p(48000,1,{0,0,0});float in=.01f,out,previous=0;double jump=0;for(int i=0;i<12000;i++){if(i==2000)p.setSettings({0,0,12});p.processFrame(&in,&out);if(i>1000)jump=std::max(jump,std::abs(double(out-previous)));previous=out;}require(jump<.001,"output gain automation smoothed");checks++;}
 std::cout<<checks<<" realtime checks passed\n";
}
