#import <AVFoundation/AVFoundation.h>
#import <AudioUnit/AudioUnit.h>
#include <iostream>
#include <cmath>
#include <stdexcept>
static void require(bool ok,const char* label){if(!ok)throw std::runtime_error(label);}
int main(int argc,const char** argv){@autoreleasepool{try{
 require(argc==2,"Pass component path");NSURL* url=[NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];CFBundleRef bundle=CFBundleCreate(kCFAllocatorDefault,(__bridge CFURLRef)url);require(bundle&&CFBundleLoadExecutable(bundle),"load component");auto factory=(AudioComponentFactoryFunction)CFBundleGetFunctionPointerForName(bundle,CFSTR("VoicePrepAUFactory"));require(factory,"factory symbol");AudioComponentDescription desc={kAudioUnitType_Effect,'Vprp','Aalt',0,0};require(AudioComponentRegister(&desc,CFSTR("Aymen Al-Tahmschi: VoicePrep"),65536,factory),"register component");
 for(unsigned channels:{1u,2u}){
  AVAudioEngine* graph=[AVAudioEngine new];AVAudioFormat* format=[[AVAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:channels];
  __block uint64_t cursor=0;AVAudioSourceNode* source=[[AVAudioSourceNode alloc] initWithFormat:format renderBlock:^OSStatus(BOOL* silence,const AudioTimeStamp* time,AVAudioFrameCount frames,AudioBufferList* output){(void)time;*silence=NO;for(AVAudioFrameCount i=0;i<frames;i++,cursor++)for(unsigned ch=0;ch<channels;ch++)static_cast<float*>(output->mBuffers[ch].mData)[i]=float(.8*std::sin(2*3.141592653589793*1000*cursor/48000))*(ch==1?.5f:1);return noErr;}];
  AVAudioUnitEffect* effect=[[AVAudioUnitEffect alloc] initWithAudioComponentDescription:desc];[graph attachNode:source];[graph attachNode:effect];[graph connect:source to:effect format:format];[graph connect:effect to:graph.mainMixerNode format:format];NSError* error=nil;
  require([graph enableManualRenderingMode:AVAudioEngineManualRenderingModeOffline format:format maximumFrameCount:512 error:&error],"manual render setup");require([graph startAndReturnError:&error],"graph start");
  require(AudioUnitSetParameter(effect.audioUnit,0,kAudioUnitScope_Global,0,100,0)==noErr,"set filter");require(AudioUnitSetParameter(effect.audioUnit,2,kAudioUnitScope_Global,0,12,0)==noErr,"set gain");
  AVAudioPCMBuffer* buffer=[[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:512];double energy=0,peak=0;unsigned rendered=0;
  for(int b=0;b<100;b++){auto state=[graph renderOffline:512 toBuffer:buffer error:&error];require(state==AVAudioEngineManualRenderingStatusSuccess,"Audio Unit graph render");for(unsigned i=0;i<buffer.frameLength;i++){float x=buffer.floatChannelData[0][i];require(std::isfinite(x),"finite graph output");peak=std::max(peak,std::abs(double(x)));energy+=x*x;if(channels==2)require(std::abs(buffer.floatChannelData[1][i]-.5*x)<2e-6,"graph stereo link");}rendered+=buffer.frameLength;}
  require(rendered==51200&&energy>1&&peak<=std::pow(10.,-1./20)+1e-6,"real graph audio and ceiling");
  CFPropertyListRef state=nullptr;UInt32 size=sizeof(state);require(AudioUnitGetProperty(effect.audioUnit,kAudioUnitProperty_ClassInfo,kAudioUnitScope_Global,0,&state,&size)==noErr&&state,"save plugin state");AudioUnitSetParameter(effect.audioUnit,0,kAudioUnitScope_Global,0,20,0);require(AudioUnitSetProperty(effect.audioUnit,kAudioUnitProperty_ClassInfo,kAudioUnitScope_Global,0,&state,sizeof(state))==noErr,"restore state");CFRelease(state);Float32 value=0;AudioUnitGetParameter(effect.audioUnit,0,kAudioUnitScope_Global,0,&value);require(value==100,"restored parameter value");
  Float64 latency=0;size=sizeof(latency);require(AudioUnitGetProperty(effect.audioUnit,kAudioUnitProperty_Latency,kAudioUnitScope_Global,0,&latency,&size)==noErr&&std::abs(latency-.005)<1e-10,"host latency reporting");
  [graph stop];std::cout<<channels<<"-channel Audio Unit graph: "<<rendered<<" frames, peak "<<20*std::log10(peak)<<" dBFS; state and latency passed\n";
 }
 // Keep the loaded bundle alive while AVFoundation can still own instances.
 return 0;
 }catch(const std::exception& e){std::cerr<<"FAIL "<<e.what()<<'\n';return 1;}}}
