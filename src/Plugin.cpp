#include <AudioUnitSDK/AUEffectBase.h>
#include <AudioUnitSDK/AUPlugInDispatch.h>
#include "Realtime.hpp"
#include <cstring>
class VoicePrepAU final : public ausdk::AUEffectBase {
 std::unique_ptr<vp::RealtimeProcessor> engine;
 public:
 explicit VoicePrepAU(AudioComponentInstance ci):AUEffectBase(ci,true){CreateElements();Globals()->UseIndexedParameters(3);SetParameter(0,80);SetParameter(1,50);SetParameter(2,3);}
 UInt32 SupportedNumChannels(const AUChannelInfo** info)override{static const AUChannelInfo channels[]={{1,1},{2,2}};if(info)*info=channels;return 2;}
 bool ValidFormat(AudioUnitScope s,AudioUnitElement e,const AudioStreamBasicDescription& f)override{return f.mSampleRate>=8000&&f.mSampleRate<=192000&&f.mChannelsPerFrame>=1&&f.mChannelsPerFrame<=2&&AUEffectBase::ValidFormat(s,e,f);}
 OSStatus Initialize()override{auto status=AUEffectBase::Initialize();if(status)return status;try{engine=std::make_unique<vp::RealtimeProcessor>(GetSampleRate(),GetNumberOfChannels(),settings());}catch(...){return kAudioUnitErr_FormatNotSupported;}return noErr;}
 void Cleanup()override{engine.reset();AUEffectBase::Cleanup();}
 OSStatus Reset(AudioUnitScope,AudioUnitElement)override{if(engine)*engine=vp::RealtimeProcessor(GetSampleRate(),GetNumberOfChannels(),settings());return noErr;}
 vp::Settings settings(){return {GetParameter(0),GetParameter(1)/100.,GetParameter(2)};}
 Float64 GetLatency()override{return std::ceil(.005*GetSampleRate())/GetSampleRate();}
 bool SupportsTail()override{return true;}
 Float64 GetTailTime()override{return .2;}
 OSStatus GetParameterInfo(AudioUnitScope scope,AudioUnitParameterID id,AudioUnitParameterInfo& p)override{
  if(scope!=kAudioUnitScope_Global||id>2)return kAudioUnitErr_InvalidParameter;
  std::memset(&p,0,sizeof(p));const char* names[]={"Rumble filter","Speech leveling","Output gain"};std::strncpy(p.name,names[id],sizeof(p.name)-1);
  static const CFStringRef cfNames[]={CFSTR("Rumble filter"),CFSTR("Speech leveling"),CFSTR("Output gain")};p.cfNameString=cfNames[id];
  p.flags=kAudioUnitParameterFlag_IsWritable|kAudioUnitParameterFlag_IsReadable|kAudioUnitParameterFlag_HasCFNameString;
  p.minValue=id==2?-12:0;p.maxValue=id==0?180:id==1?100:12;p.defaultValue=id==0?80:id==1?50:3;
  p.unit=id==0?kAudioUnitParameterUnit_Hertz:id==1?kAudioUnitParameterUnit_Percent:kAudioUnitParameterUnit_Decibels;return noErr;
 }
 OSStatus ProcessBufferLists(AudioUnitRenderActionFlags& flags,const AudioBufferList& input,AudioBufferList& output,UInt32 frames)override{
  if(!engine)return kAudioUnitErr_Uninitialized;const unsigned ch=GetNumberOfChannels();if(input.mNumberBuffers!=ch||output.mNumberBuffers!=ch)return kAudioUnitErr_FormatNotSupported;
  engine->setSettings(settings());for(UInt32 i=0;i<frames;i++){float in[2]{},out[2]{};for(unsigned c=0;c<ch;c++)in[c]=static_cast<const float*>(input.mBuffers[c].mData)[i];engine->processFrame(in,out);for(unsigned c=0;c<ch;c++)static_cast<float*>(output.mBuffers[c].mData)[i]=out[c];}
  flags&=~kAudioUnitRenderAction_OutputIsSilence;return noErr;
 }
};
AUSDK_COMPONENT_ENTRY(ausdk::AUBaseFactory, VoicePrepAU)
