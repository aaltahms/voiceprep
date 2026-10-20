#import <Foundation/Foundation.h>
#include "AudioIO.hpp"
#include <iostream>
#include <chrono>
int main(int argc,const char** argv){@autoreleasepool{
 try{
  if(argc!=6){std::cerr<<"Usage: voiceprep-cli INPUT OUTPUT.wav RUMBLE_HZ LEVELING_0_TO_100 GAIN_DB\n";return 2;}
  NSString* output=[NSString stringWithUTF8String:argv[2]];
  if([[NSFileManager defaultManager] fileExistsAtPath:output])throw std::runtime_error("Output already exists. Choose a new filename.");
  auto input=vp::readAudio([NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]]);
  auto numeric=[](const char* text){std::string value(text);size_t consumed=0;double result=std::stod(value,&consumed);if(consumed!=value.size())throw std::runtime_error("Use numeric sound-control values without trailing text.");return result;};
  vp::Settings s{numeric(argv[3]),numeric(argv[4])/100,numeric(argv[5])};
  auto start=std::chrono::steady_clock::now();auto r=vp::render(input,s);double elapsed=std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count();
  vp::writeAudio(r.audio,[NSURL fileURLWithPath:output]);
  std::cout<<"{\"frames\":"<<input.frames()<<",\"channels\":"<<input.channels<<",\"sample_rate\":"<<input.sampleRate<<",\"duration_s\":"<<input.frames()/input.sampleRate<<",\"render_s\":"<<elapsed<<",\"input_peak_dbfs\":"<<r.before.peakDb<<",\"output_peak_dbfs\":"<<r.after.peakDb<<",\"input_rms_dbfs\":"<<r.before.rmsDb<<",\"output_rms_dbfs\":"<<r.after.rmsDb<<",\"peak_protection_db\":"<<r.peakProtectionDb<<"}\n";return 0;
 }catch(const std::exception& e){std::cerr<<e.what()<<"\n";return 1;}
}}
