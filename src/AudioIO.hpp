#pragma once
#import <AVFoundation/AVFoundation.h>
#include "DSP.hpp"
namespace vp {
inline Audio readAudio(NSURL* url){
 NSError* error=nil;AVAudioFile* f=[[AVAudioFile alloc] initForReading:url commonFormat:AVAudioPCMFormatFloat32 interleaved:NO error:&error];
 if(!f)throw std::runtime_error("This file could not be decoded. Try a valid WAV or AIFF recording, or export a fresh copy from your recorder.");
 auto fmt=f.processingFormat;auto frames=f.length;
 if(fmt.channelCount<1||fmt.channelCount>2||frames<=0||frames>24000000/fmt.channelCount||fmt.sampleRate<8000||fmt.sampleRate>192000)throw std::runtime_error("Open mono/stereo audio at 8–192 kHz, with at most 24 million samples.");
 AVAudioPCMBuffer* b=[[AVAudioPCMBuffer alloc] initWithPCMFormat:fmt frameCapacity:(AVAudioFrameCount)frames];
 if(!b||![f readIntoBuffer:b error:&error])throw std::runtime_error("The audio could not be read completely. Try exporting a fresh copy from your recorder.");
 Audio a;a.channels=fmt.channelCount;a.sampleRate=fmt.sampleRate;a.samples.resize(size_t(b.frameLength)*a.channels);
 for(size_t i=0;i<b.frameLength;i++)for(unsigned ch=0;ch<a.channels;ch++)a.samples[i*a.channels+ch]=b.floatChannelData[ch][i];
 validate(a,Settings{});return a;
}
inline AVAudioPCMBuffer* makeBuffer(const Audio& a){
 AVAudioFormat* fmt=[[AVAudioFormat alloc] initStandardFormatWithSampleRate:a.sampleRate channels:a.channels];
 AVAudioPCMBuffer* b=[[AVAudioPCMBuffer alloc] initWithPCMFormat:fmt frameCapacity:(AVAudioFrameCount)a.frames()];
 if(!b)throw std::runtime_error("There is not enough memory to prepare this recording.");
 b.frameLength=(AVAudioFrameCount)a.frames();
 for(size_t i=0;i<a.frames();i++)for(unsigned ch=0;ch<a.channels;ch++)b.floatChannelData[ch][i]=a.samples[i*a.channels+ch];return b;
}
inline bool sameFile(NSURL* first,NSURL* second){
 if(!first||!second)return false;
 NSString* a=first.URLByResolvingSymlinksInPath.URLByStandardizingPath.path;
 NSString* b=second.URLByResolvingSymlinksInPath.URLByStandardizingPath.path;
 if([a isEqualToString:b])return true;
 id firstID=nil,secondID=nil;
 return [first getResourceValue:&firstID forKey:NSURLFileResourceIdentifierKey error:nil] &&
        [second getResourceValue:&secondID forKey:NSURLFileResourceIdentifierKey error:nil] &&
        firstID && [firstID isEqual:secondID];
}
inline void writeAudio(const Audio& a,NSURL* destination,bool floatingPreview=false,bool replaceExisting=false,NSURL* protectedSource=nil){
 validate(a,Settings{});
 if(sameFile(destination,protectedSource))throw std::runtime_error("Keep the original recording. Choose a different filename or folder for the prepared WAV.");
 // Work beside the destination, then let Foundation replace/move atomically.
 NSURL* temporary=[[destination URLByDeletingLastPathComponent] URLByAppendingPathComponent:[NSString stringWithFormat:@".voiceprep-%@.wav",NSUUID.UUID.UUIDString]];
 NSError* error=nil;NSDictionary* settings=@{AVFormatIDKey:@(kAudioFormatLinearPCM),AVSampleRateKey:@(a.sampleRate),AVNumberOfChannelsKey:@(a.channels),AVLinearPCMBitDepthKey:@(floatingPreview?32:24),AVLinearPCMIsFloatKey:@(floatingPreview),AVLinearPCMIsBigEndianKey:@NO,AVLinearPCMIsNonInterleaved:@NO};
 @autoreleasepool {
 AVAudioFile* f=[[AVAudioFile alloc] initForWriting:temporary settings:settings commonFormat:AVAudioPCMFormatFloat32 interleaved:NO error:&error];
 if(!f||![f writeFromBuffer:makeBuffer(a) error:&error]){[[NSFileManager defaultManager] removeItemAtURL:temporary error:nil];throw std::runtime_error(error.localizedDescription.UTF8String?:"Export failed.");}
 }
 BOOL exists=[[NSFileManager defaultManager] fileExistsAtPath:destination.path];BOOL ok=exists&&replaceExisting?[[NSFileManager defaultManager] replaceItemAtURL:destination withItemAtURL:temporary backupItemName:nil options:0 resultingItemURL:nil error:&error]:[[NSFileManager defaultManager] moveItemAtURL:temporary toURL:destination error:&error];
 if(!ok){[[NSFileManager defaultManager] removeItemAtURL:temporary error:nil];throw std::runtime_error(error.localizedDescription.UTF8String?:"Could not save the WAV.");}
}
}
