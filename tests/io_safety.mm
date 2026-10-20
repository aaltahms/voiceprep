#import <Foundation/Foundation.h>
#include "../src/AudioIO.hpp"
#include <iostream>
#include <cstdlib>
static void require(bool condition,const char* message){if(!condition){std::cerr<<"FAIL: "<<message<<"\n";std::exit(1);}}
int main(){@autoreleasepool{
 NSURL* directory=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[@"VoicePrep-io-check-" stringByAppendingString:NSUUID.UUID.UUIDString]] isDirectory:YES];
 NSFileManager* fs=NSFileManager.defaultManager;NSError* error=nil;
 require([fs createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&error],"create test directory");
 vp::Audio original;original.samples.assign(4800,.05f);vp::Audio changed=original;changed.samples.assign(4800,.1f);
 NSURL* source=[directory URLByAppendingPathComponent:@"source.wav"];
 vp::writeAudio(original,source);NSData* before=[NSData dataWithContentsOfURL:source];
 NSURL* symlink=[directory URLByAppendingPathComponent:@"symlink.wav"];
 NSURL* hardlink=[directory URLByAppendingPathComponent:@"hardlink.wav"];
 require([fs createSymbolicLinkAtURL:symlink withDestinationURL:source error:&error],"create symlink");
 require([fs linkItemAtURL:source toURL:hardlink error:&error],"create hardlink");
 for(NSURL* destination in @[source,symlink,hardlink]){
  bool rejected=false;try{vp::writeAudio(changed,destination,false,true,source);}catch(const std::runtime_error& e){rejected=std::string(e.what()).find("original recording")!=std::string::npos;}
  require(rejected,"reject original or same-file alias before export");
  require([[NSData dataWithContentsOfURL:source] isEqualToData:before],"original bytes preserved");
 }
 NSURL* occupied=[directory URLByAppendingPathComponent:@"occupied.wav"];
 vp::writeAudio(original,occupied);NSData* occupiedBefore=[NSData dataWithContentsOfURL:occupied];
 bool rejected=false;try{vp::writeAudio(changed,occupied);}catch(...){rejected=true;}
 require(rejected,"create-only writer rejects occupied destination");require([[NSData dataWithContentsOfURL:occupied] isEqualToData:occupiedBefore],"occupied destination bytes preserved");
 vp::writeAudio(changed,occupied,false,true,source);
 require(![[NSData dataWithContentsOfURL:occupied] isEqualToData:occupiedBefore],"explicit replacement of a different file succeeds");
 require([[NSData dataWithContentsOfURL:source] isEqualToData:before],"replacement leaves original untouched");
 require([fs contentsOfDirectoryAtPath:directory.path error:&error].count==4,"no temporary exports left behind");
 [fs removeItemAtURL:directory error:nil];std::cout<<"5 native export-safety scenarios passed\n";
}}
