#include "../src/DSP.hpp"
#include <chrono>
#include <iostream>
int main(){vp::Audio a;a.channels=2;a.samples.resize(48000*30*2);for(size_t i=0;i<a.frames();i++){double v=.25*std::sin(2*3.141592653589793*200*i/48000.);a.samples[i*2]=v;a.samples[i*2+1]=v*.7;}double times[5];double peak=0;for(int k=0;k<5;k++){auto start=std::chrono::steady_clock::now();auto r=vp::render(a,{80,.5,3});times[k]=std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count();peak=r.after.peakDb;}std::sort(times,times+5);std::cout<<"{\"duration_s\":30,\"channels\":2,\"sample_rate\":48000,\"runs\":5,\"median_render_s\":"<<times[2]<<",\"slowest_render_s\":"<<times[4]<<",\"output_peak_dbfs\":"<<peak<<"}\n";}
