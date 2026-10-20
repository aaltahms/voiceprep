#import <Cocoa/Cocoa.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include "AudioIO.hpp"
#include <memory>
#include <chrono>
#import <AVFoundation/AVFoundation.h>
#import <AudioUnit/AudioUnit.h>
#include <atomic>
static NSColor* Ink(){return [NSColor colorWithSRGBRed:.91 green:.92 blue:.94 alpha:1];}
static NSColor* Accent(){return [NSColor colorWithSRGBRed:.96 green:.53 blue:.28 alpha:1];}
static NSTextField* Text(NSString* str,CGFloat size,BOOL bold=NO){NSTextField* t=[NSTextField labelWithString:str];t.font=bold?[NSFont systemFontOfSize:size weight:NSFontWeightSemibold]:[NSFont systemFontOfSize:size];t.textColor=Ink();t.lineBreakMode=NSLineBreakByTruncatingMiddle;return t;}
static NSStackView* Stack(NSArray* views,NSUserInterfaceLayoutOrientation orient,CGFloat spacing){NSStackView* s=[NSStackView stackViewWithViews:views];s.orientation=orient;s.spacing=spacing;s.alignment=orient==NSUserInterfaceLayoutOrientationVertical?NSLayoutAttributeLeading:NSLayoutAttributeCenterY;return s;}
static NSString* Time(double seconds){int v=(int)seconds;return [NSString stringWithFormat:@"%d:%02d",v/60,v%60];}
@interface VPWave : NSView
@property(nonatomic) NSArray<NSNumber*>* original;
@property(nonatomic) NSArray<NSNumber*>* prepared;
@property(nonatomic) double position;
@property(nonatomic) BOOL usePrepared;
@property(nonatomic,copy) void (^seek)(double);
@end
@implementation VPWave
-(BOOL)isFlipped{return YES;}
-(BOOL)acceptsFirstResponder{return YES;}
-(void)drawRect:(NSRect)dirty{
 (void)dirty;NSRect r=self.bounds;[[NSColor colorWithSRGBRed:.075 green:.08 blue:.10 alpha:1] setFill];[[NSBezierPath bezierPathWithRoundedRect:r xRadius:10 yRadius:10] fill];
 CGFloat mid=r.size.height/2,pad=16,w=r.size.width-pad*2;
 [[NSColor colorWithWhite:.75 alpha:.5] setStroke];NSBezierPath* grid=[NSBezierPath bezierPath];for(int i=1;i<8;i++){CGFloat x=pad+w*i/8;[grid moveToPoint:NSMakePoint(x,25)];[grid lineToPoint:NSMakePoint(x,r.size.height-25)];}[grid moveToPoint:NSMakePoint(pad,mid)];[grid lineToPoint:NSMakePoint(r.size.width-pad,mid)];[grid stroke];
 NSArray<NSNumber*>* vals=self.usePrepared?self.prepared:self.original;
 if(vals.count){[(self.usePrepared?Accent():[NSColor colorWithSRGBRed:.49 green:.57 blue:.66 alpha:1]) setStroke];NSBezierPath* p=[NSBezierPath bezierPath];p.lineWidth=1.6;for(NSUInteger i=0;i<vals.count;i++){CGFloat x=pad+w*i/MAX(1.,vals.count-1),amp=MIN(1.,vals[i].doubleValue)*(mid-25);[p moveToPoint:NSMakePoint(x,mid-amp)];[p lineToPoint:NSMakePoint(x,mid+amp)];}[p stroke];
 CGFloat x=pad+w*self.position;[Ink() setStroke];NSBezierPath* cursor=[NSBezierPath bezierPath];[cursor moveToPoint:NSMakePoint(x,14)];[cursor lineToPoint:NSMakePoint(x,r.size.height-14)];cursor.lineWidth=1.5;[cursor stroke];
 }else{NSDictionary* attrs=@{NSFontAttributeName:[NSFont systemFontOfSize:15],NSForegroundColorAttributeName:[NSColor secondaryLabelColor]};NSString* msg=@"Your recording will appear here";NSSize sz=[msg sizeWithAttributes:attrs];[msg drawAtPoint:NSMakePoint((r.size.width-sz.width)/2,mid-8) withAttributes:attrs];}
}
-(void)mouseDown:(NSEvent*)event{if(!self.original.count)return;NSPoint p=[self convertPoint:event.locationInWindow fromView:nil];if(self.seek)self.seek(std::clamp((p.x-16)/(self.bounds.size.width-32),0.,1.));}
@end
@interface VPController : NSObject<NSApplicationDelegate,NSWindowDelegate>{
 NSWindow* window;NSPanel* livePanel;AVAudioEngine* liveEngine;AVAudioUnitEffect* liveUnit;NSButton *liveStart,*monitor;NSTextField *liveStatus,*liveMeter;NSProgressIndicator* meter;std::atomic<float> livePeak;std::atomic<uint64_t> liveFrames;NSUInteger liveRequest;CFBundleRef pluginBundle;NSTextField *title,*metadata,*status,*clock,*rumbleValue,*levelValue,*gainValue,*soundNote;VPWave* wave;
 NSSlider *rumble,*level,*gain,*position;NSButton *play,*exportButton,*match,*sampleButton,*openButton;NSSegmentedControl* compare;NSProgressIndicator* spinner;
 AVAudioPlayer *player,*originalPlayer,*preparedPlayer;std::shared_ptr<vp::Audio> source;std::shared_ptr<vp::Result> result;NSUInteger generation;BOOL busy;NSString* sourceName;NSURL *originalPreview,*preparedPreview,*sourceURL;NSTimer* timer;double cursorSeconds;NSURL* tempDirectory;
}
@end
@implementation VPController
-(NSButton*)button:(NSString*)label action:(SEL)action{NSButton* b=[NSButton buttonWithTitle:label target:self action:action];b.bezelStyle=NSBezelStyleRounded;return b;}
-(void)applicationDidFinishLaunching:(NSNotification*)notification{
 (void)notification;[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];NSMenu* menu=[NSMenu new];NSMenuItem* root=[NSMenuItem new];[menu addItem:root];NSMenu* appMenu=[NSMenu new];[appMenu addItemWithTitle:@"About VoicePrep" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];[appMenu addItem:[NSMenuItem separatorItem]];[appMenu addItemWithTitle:@"Quit VoicePrep" action:@selector(terminate:) keyEquivalent:@"q"];root.submenu=appMenu;NSMenuItem* fileItem=[NSMenuItem new];fileItem.title=@"File";[menu addItem:fileItem];NSMenu* file=[NSMenu new];NSMenuItem* openItem=[file addItemWithTitle:@"Open Recording…" action:@selector(openRecording:) keyEquivalent:@"o"];openItem.target=self;NSMenuItem* saveItem=[file addItemWithTitle:@"Export Prepared WAV…" action:@selector(exportAudio:) keyEquivalent:@"e"];saveItem.target=self;fileItem.submenu=file;
 NSMenuItem* editItem=[NSMenuItem new];editItem.title=@"Edit";[menu addItem:editItem];NSMenu* edit=[NSMenu new];
 [edit addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
 NSMenuItem* redo=[edit addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"z"];redo.keyEquivalentModifierMask=NSEventModifierFlagCommand|NSEventModifierFlagShift;
 [edit addItem:[NSMenuItem separatorItem]];
 [edit addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
 [edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
 [edit addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
 [edit addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
 editItem.submenu=edit;[NSApp setMainMenu:menu];
 window=[[NSWindow alloc] initWithContentRect:NSMakeRect(100,100,1050,780) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];window.title=@"VoicePrep";window.minSize=NSMakeSize(850,760);window.delegate=self;window.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];window.backgroundColor=[NSColor colorWithSRGBRed:.12 green:.13 blue:.16 alpha:1];
 NSView* content=window.contentView;
 NSTextField* brand=Text(@"VoicePrep",23,YES);NSTextField* purpose=Text(@"Prepare your spoken recordings",12);purpose.textColor=NSColor.secondaryLabelColor;
 NSButton* open=[self button:@"Open recording…" action:@selector(openRecording:)];openButton=open;open.keyEquivalent=@"o";open.keyEquivalentModifierMask=NSEventModifierFlagCommand;
 sampleButton=[self button:@"Try spoken example" action:@selector(openExample:)];
 NSStackView* header=Stack(@[Stack(@[brand,purpose],NSUserInterfaceLayoutOrientationVertical,3),[NSView new],[self button:@"Live microphone…" action:@selector(openLive:)],sampleButton,open],NSUserInterfaceLayoutOrientationHorizontal,14);
 title=Text(@"Make your next take easier to listen to.",27,YES);metadata=Text(@"Open a voice recording to reduce low rumble, even out loud passages, and set the output level.",12);metadata.textColor=NSColor.secondaryLabelColor;
 wave=[VPWave new];wave.accessibilityLabel=@"Recording waveform. Use the playback position slider to seek.";[wave.heightAnchor constraintEqualToConstant:205].active=YES;
 __weak VPController* weakSelf=self;wave.seek=^(double ratio){[weakSelf seekRatio:ratio];};
 play=[self button:@"▶  Play" action:@selector(togglePlayback:)];play.keyEquivalent=@" ";play.keyEquivalentModifierMask=0;[play.widthAnchor constraintEqualToConstant:100].active=YES;
 clock=Text(@"0:00 / 0:00",12);clock.font=[NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
 position=[NSSlider sliderWithValue:0 minValue:0 maxValue:1 target:self action:@selector(seekSlider:)];position.continuous=NO;position.accessibilityLabel=@"Playback position";
 NSStackView* transport=Stack(@[play,position,clock],NSUserInterfaceLayoutOrientationHorizontal,16);
 compare=[NSSegmentedControl segmentedControlWithLabels:@[@"Original",@"Prepared"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(switchVersion:)];compare.selectedSegment=1;compare.accessibilityLabel=@"Listen to original or prepared recording";
 match=[NSButton checkboxWithTitle:@"Match average volume for comparison" target:self action:@selector(matchChanged:)];match.state=NSControlStateValueOn;match.font=[NSFont systemFontOfSize:11];
 NSStackView* audition=Stack(@[compare,match,[NSView new],Text(@"Preview at the same position",11)],NSUserInterfaceLayoutOrientationHorizontal,18);
 rumble=[NSSlider sliderWithValue:80 minValue:0 maxValue:180 target:self action:@selector(soundChanged:)];level=[NSSlider sliderWithValue:50 minValue:0 maxValue:100 target:self action:@selector(soundChanged:)];gain=[NSSlider sliderWithValue:3 minValue:-12 maxValue:12 target:self action:@selector(soundChanged:)];
 rumble.accessibilityLabel=@"Rumble cutoff in hertz";level.accessibilityLabel=@"Leveling amount";gain.accessibilityLabel=@"Output gain in decibels";rumble.continuous=level.continuous=gain.continuous=NO;
 rumbleValue=Text(@"80 Hz",18,YES);levelValue=Text(@"50%",18,YES);gainValue=Text(@"+3.0 dB",18,YES);
 NSStackView* columns=Stack(@[[self controlColumn:@"Rumble filter" value:rumbleValue slider:rumble help:@"Cut low-frequency vibration. 0 Hz bypasses the filter."],[self controlColumn:@"Speech leveling" value:levelValue slider:level help:@"Gently reduce louder passages. 0% keeps the dynamics."],[self controlColumn:@"Output gain" value:gainValue slider:gain help:@"File export: peak protection trims the whole file if needed."]],NSUserInterfaceLayoutOrientationHorizontal,32);columns.distribution=NSStackViewDistributionFillEqually;
 soundNote=Text(@"Listen first. These controls do not remove background conversations or repair clipped audio.",11);soundNote.textColor=NSColor.secondaryLabelColor;
 NSBox* line=[NSBox new];line.boxType=NSBoxSeparator;
 status=Text(@"Files are processed on this Mac. Open WAV, AIFF, MP3, or M4A audio.",11);status.textColor=NSColor.secondaryLabelColor;[status setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];spinner=[NSProgressIndicator new];spinner.style=NSProgressIndicatorStyleSpinning;spinner.controlSize=NSControlSizeSmall;spinner.displayedWhenStopped=NO;
 exportButton=[self button:@"Export prepared WAV…" action:@selector(exportAudio:)];exportButton.bezelColor=Accent();exportButton.contentTintColor=NSColor.whiteColor;
 NSStackView* bottom=Stack(@[spinner,status,[NSView new],exportButton],NSUserInterfaceLayoutOrientationHorizontal,12);
 NSStackView* layout=Stack(@[header,title,metadata,wave,transport,audition,columns,soundNote,line,bottom],NSUserInterfaceLayoutOrientationVertical,14);layout.translatesAutoresizingMaskIntoConstraints=NO;layout.alignment=NSLayoutAttributeLeading;[content addSubview:layout];
 [NSLayoutConstraint activateConstraints:@[[layout.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:30],[layout.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-30],[layout.topAnchor constraintEqualToAnchor:content.topAnchor constant:25],[layout.bottomAnchor constraintLessThanOrEqualToAnchor:content.bottomAnchor constant:-20]]];
 for(NSView* v in @[header,title,metadata,wave,transport,audition,columns,soundNote,line,bottom])[v.widthAnchor constraintEqualToAnchor:layout.widthAnchor].active=YES;
 [self setBusy:NO];play.enabled=exportButton.enabled=compare.enabled=match.enabled=position.enabled=NO;rumble.enabled=level.enabled=gain.enabled=NO;
 tempDirectory=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[@"VoicePrep-" stringByAppendingString:NSUUID.UUID.UUIDString]] isDirectory:YES];[[NSFileManager defaultManager] createDirectoryAtURL:tempDirectory withIntermediateDirectories:YES attributes:nil error:nil];
 timer=[NSTimer scheduledTimerWithTimeInterval:.04 target:self selector:@selector(updateClock) userInfo:nil repeats:YES];[window center];[window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];
 NSArray* args=NSProcessInfo.processInfo.arguments;if(args.count>1)[self loadURL:[NSURL fileURLWithPath:args[1]] example:NO];
}
-(NSStackView*)controlColumn:(NSString*)heading value:(NSTextField*)value slider:(NSSlider*)slider help:(NSString*)help{
 NSTextField* hint=[NSTextField wrappingLabelWithString:help];hint.font=[NSFont systemFontOfSize:11];hint.textColor=NSColor.secondaryLabelColor;[hint.heightAnchor constraintGreaterThanOrEqualToConstant:34].active=YES;NSStackView* col=Stack(@[Text(heading,12,YES),value,slider,hint],NSUserInterfaceLayoutOrientationVertical,8);[slider.widthAnchor constraintEqualToAnchor:col.widthAnchor].active=YES;[hint.widthAnchor constraintEqualToAnchor:col.widthAnchor].active=YES;return col;
}
-(void)setBusy:(BOOL)value{busy=value;openButton.enabled=sampleButton.enabled=!value;play.enabled=exportButton.enabled=compare.enabled=match.enabled=position.enabled=result&&!value;rumble.enabled=level.enabled=gain.enabled=(source||liveEngine.isRunning)&&!value;if(value)[spinner startAnimation:nil];else[spinner stopAnimation:nil];}
-(void)showError:(NSString*)message{NSAlert* a=[NSAlert new];a.messageText=@"VoicePrep couldn’t complete that";a.informativeText=message;[a beginSheetModalForWindow:window completionHandler:nil];}
-(void)openRecording:(id)sender{(void)sender;if(busy)return;NSOpenPanel* p=[NSOpenPanel openPanel];p.allowedContentTypes=@[UTTypeAudio];p.allowsMultipleSelection=NO;[p beginSheetModalForWindow:window completionHandler:^(NSModalResponse response){if(response==NSModalResponseOK)[self loadURL:p.URL example:NO];}];}
-(void)openExample:(id)sender{(void)sender;if(busy)return;NSURL* u=[NSBundle.mainBundle URLForResource:@"spoken-original" withExtension:@"wav"];if(u)[self loadURL:u example:YES];else[self showError:@"The bundled example is missing. Open your own recording instead."];}
-(void)loadURL:(NSURL*)url example:(BOOL)example{
 [self stopLive];[self pause];NSUInteger ticket=++generation;[self setBusy:YES];status.stringValue=@"Opening recording…";
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{try{auto a=std::make_shared<vp::Audio>(vp::readAudio(url));dispatch_async(dispatch_get_main_queue(),^{if(ticket!=self->generation)return;self->source=a;self->sourceURL=url;self->result.reset();self->sourceName=url.lastPathComponent;self->title.stringValue=example?@"Spoken example · uneven level + rumble":url.lastPathComponent;self->metadata.stringValue=[NSString stringWithFormat:@"%@  ·  %.0f Hz  ·  %@  ·  %@",Time(a->frames()/a->sampleRate),a->sampleRate,a->channels==1?@"Mono":@"Stereo",example?@"Open Speech Repository voice; added faults":@"Your original stays unchanged"];self->cursorSeconds=0;if(self->originalPreview)[[NSFileManager defaultManager] removeItemAtURL:self->originalPreview error:nil];self->originalPreview=nil;self->wave.original=[self envelope:*a];[self render];});}catch(const std::exception& e){NSString* message=[NSString stringWithUTF8String:e.what()];dispatch_async(dispatch_get_main_queue(),^{if(ticket!=self->generation)return;[self setBusy:NO];self->status.stringValue=@"Could not open that file. The previous recording is retained.";[self showError:message];});}});
}
-(NSArray*)envelope:(const vp::Audio&)a{NSMutableArray* bins=[NSMutableArray new];size_t n=MIN(size_t(700),a.frames());for(size_t k=0;k<n;k++){size_t begin=k*a.frames()/n,end=(k+1)*a.frames()/n;double peak=0;for(size_t i=begin;i<end;i++)for(unsigned ch=0;ch<a.channels;ch++)peak=std::max(peak,std::abs(double(a.samples[i*a.channels+ch])));[bins addObject:@(peak)];}return bins;}
-(vp::Settings)settings{return {rumble.doubleValue,level.doubleValue/100,gain.doubleValue};}
-(void)soundChanged:(id)sender{(void)sender;[self updateLiveSettings];rumbleValue.stringValue=rumble.doubleValue<1?@"Off":[NSString stringWithFormat:@"%.0f Hz",rumble.doubleValue];levelValue.stringValue=[NSString stringWithFormat:@"%.0f%%",level.doubleValue];gainValue.stringValue=[NSString stringWithFormat:@"%+.1f dB",gain.doubleValue];[self render];}
-(void)render{
 if(!source)return;[self pause];result.reset();auto a=source;auto settings=[self settings];NSUInteger ticket=++generation;[self setBusy:YES];status.stringValue=@"Preparing audio…";
 NSURL* originalURL=[tempDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"original-%lu.wav",(unsigned long)ticket]];NSURL* preparedURL=[tempDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"prepared-%lu.wav",(unsigned long)ticket]];BOOL needsOriginal=!originalPreview;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{try{auto start=std::chrono::steady_clock::now();auto r=std::make_shared<vp::Result>(vp::render(*a,settings));(void)start;if(needsOriginal)vp::writeAudio(*a,originalURL,true);vp::writeAudio(r->audio,preparedURL,true);NSArray* peaks=[self envelope:r->audio];dispatch_async(dispatch_get_main_queue(),^{if(ticket!=self->generation)return;self->result=r;NSURL* oldPrepared=self->preparedPreview;if(needsOriginal)self->originalPreview=originalURL;self->preparedPreview=preparedURL;if(oldPrepared)[[NSFileManager defaultManager] removeItemAtURL:oldPrepared error:nil];self->wave.prepared=peaks;self->wave.usePrepared=self->compare.selectedSegment==1;[self->wave setNeedsDisplay:YES];[self setBusy:NO];self->status.stringValue=@"Ready to listen · Original and Prepared share the same timeline";self->soundNote.stringValue=r->peakProtectionDb<-.01?[NSString stringWithFormat:@"Peak protection applied %.1f dB across the file. Export: 24-bit WAV at the original sample rate.",r->peakProtectionDb]:@"Prepared export: 24-bit WAV at the original sample rate. Comparison volume matching only affects playback.";[self updateClock];});}catch(const std::exception& e){NSString* message=[NSString stringWithUTF8String:e.what()];dispatch_async(dispatch_get_main_queue(),^{if(ticket!=self->generation)return;[self setBusy:NO];self->exportButton.enabled=NO;self->status.stringValue=@"Preparation failed. Adjust the controls or open another recording.";[self showError:message];});}});
}
-(double)duration{return source?source->frames()/source->sampleRate:0;}
-(void)pause{if(player.isPlaying)cursorSeconds=player.currentTime;[originalPlayer stop];[preparedPlayer stop];player=originalPlayer=preparedPlayer=nil;play.title=@"▶  Play";}
-(void)applyAuditionLevels{
 if(!result)return;double target=std::min(result->after.rmsDb,result->before.rmsDb);
 double a=match.state==NSControlStateValueOn?vp::amplitude(target-result->before.rmsDb):1;
 double b=match.state==NSControlStateValueOn?vp::amplitude(target-result->after.rmsDb):1;
 [originalPlayer setVolume:compare.selectedSegment==0?a:0 fadeDuration:.012];
 [preparedPlayer setVolume:compare.selectedSegment==1?b:0 fadeDuration:.012];
}
-(void)togglePlayback:(id)sender{(void)sender;if(busy||!result)return;if(player.isPlaying){[self pause];return;}[self stopLive];if(cursorSeconds>=[self duration]-.01)cursorSeconds=0;NSError* e=nil;
 originalPlayer=[[AVAudioPlayer alloc] initWithContentsOfURL:originalPreview error:&e];preparedPlayer=[[AVAudioPlayer alloc] initWithContentsOfURL:preparedPreview error:&e];
 if(!originalPlayer||!preparedPlayer){[self showError:e.localizedDescription?:@"Could not prepare playback."];return;}
 originalPlayer.currentTime=preparedPlayer.currentTime=cursorSeconds;originalPlayer.volume=preparedPlayer.volume=0;
 [originalPlayer prepareToPlay];[preparedPlayer prepareToPlay];player=originalPlayer;
 NSTimeInterval start=originalPlayer.deviceCurrentTime+.05;
 if([originalPlayer playAtTime:start]&&[preparedPlayer playAtTime:start]){[self applyAuditionLevels];play.title=@"Ⅱ  Pause";}else{[self pause];[self showError:@"Audio playback could not start on the current output device."];}
}
-(void)seekRatio:(double)ratio{BOOL running=player.isPlaying;[self pause];cursorSeconds=std::clamp(ratio,0.,1.)*[self duration];[self updateClock];if(running)[self togglePlayback:nil];}
-(void)seekSlider:(id)sender{(void)sender;[self seekRatio:position.doubleValue];}
-(void)switchVersion:(id)sender{(void)sender;wave.usePrepared=compare.selectedSegment==1;[wave setNeedsDisplay:YES];[self applyAuditionLevels];}
-(void)matchChanged:(id)sender{(void)sender;[self applyAuditionLevels];}
-(void)updateClock{if(liveEngine.isRunning){if(liveFrames.load()>0)liveStatus.stringValue=@"Live · Processing microphone · 5 ms lookahead + device buffering";float p=livePeak.exchange(0);meter.doubleValue=std::min(1.f,p);liveMeter.stringValue=[NSString stringWithFormat:@"Processed peak: %.1f dBFS",vp::db(p)];}if(player){if(player.isPlaying)cursorSeconds=player.currentTime;else{cursorSeconds=[self duration];player=nil;play.title=@"▶  Play";}}double dur=[self duration];position.doubleValue=dur>0?cursorSeconds/dur:0;wave.position=position.doubleValue;[wave setNeedsDisplay:YES];clock.stringValue=[NSString stringWithFormat:@"%@ / %@",Time(cursorSeconds),Time(dur)];}
-(void)exportAudio:(id)sender{(void)sender;if(busy||!result)return;NSSavePanel* panel=[NSSavePanel savePanel];panel.allowedContentTypes=@[UTTypeWAV];panel.nameFieldStringValue=[[[sourceName stringByDeletingPathExtension] stringByAppendingString:@"-prepared"] stringByAppendingPathExtension:@"wav"];[panel beginSheetModalForWindow:window completionHandler:^(NSModalResponse response){if(response!=NSModalResponseOK)return;auto r=self->result;NSUInteger ticket=self->generation;NSURL* url=panel.URL;NSURL* protectedSource=self->sourceURL;[self setBusy:YES];self->status.stringValue=@"Writing prepared WAV…";dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{try{vp::writeAudio(r->audio,url,false,true,protectedSource);dispatch_async(dispatch_get_main_queue(),^{if(ticket!=self->generation)return;[self setBusy:NO];self->status.stringValue=[@"Saved: " stringByAppendingString:url.lastPathComponent];});}catch(const std::exception& e){NSString* message=[NSString stringWithUTF8String:e.what()];dispatch_async(dispatch_get_main_queue(),^{if(ticket!=self->generation)return;[self setBusy:NO];self->status.stringValue=@"Export not saved. Your original is unchanged.";[self showError:message];});}});}];}
-(void)openLive:(id)sender{
 (void)sender;if(livePanel){[livePanel makeKeyAndOrderFront:nil];return;}
 livePanel=[[NSPanel alloc] initWithContentRect:NSMakeRect(0,0,570,320) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];livePanel.title=@"Live microphone · VoicePrep";livePanel.appearance=window.appearance;livePanel.delegate=self;livePanel.releasedWhenClosed=NO;
 NSTextField* explanation=[NSTextField wrappingLabelWithString:@"Use headphones before enabling monitoring. Your microphone stays on this Mac; this window does not record audio. Use the VoicePrep Audio Unit in your recording app to record a processed take."];explanation.font=[NSFont systemFontOfSize:12];
 liveStatus=Text(@"Stopped · Uses the Mac’s current input and output devices",12);liveMeter=Text(@"Processed peak: —",12);meter=[NSProgressIndicator new];meter.indeterminate=NO;meter.minValue=0;meter.maxValue=1;meter.accessibilityLabel=@"Processed microphone peak level";
 monitor=[NSButton checkboxWithTitle:@"Monitor through headphones" target:self action:@selector(monitorChanged:)];monitor.enabled=NO;
 liveStart=[self button:@"Start microphone" action:@selector(toggleLive:)];
 NSStackView* layout=Stack(@[Text(@"Hear your microphone prepared live",20,YES),explanation,liveStatus,meter,liveMeter,monitor,liveStart],NSUserInterfaceLayoutOrientationVertical,14);layout.translatesAutoresizingMaskIntoConstraints=NO;[livePanel.contentView addSubview:layout];
 [NSLayoutConstraint activateConstraints:@[[layout.leadingAnchor constraintEqualToAnchor:livePanel.contentView.leadingAnchor constant:24],[layout.trailingAnchor constraintEqualToAnchor:livePanel.contentView.trailingAnchor constant:-24],[layout.topAnchor constraintEqualToAnchor:livePanel.contentView.topAnchor constant:22]]];[explanation.widthAnchor constraintEqualToAnchor:layout.widthAnchor].active=YES;[meter.widthAnchor constraintEqualToAnchor:layout.widthAnchor].active=YES;[livePanel center];[livePanel makeKeyAndOrderFront:nil];
}
-(void)updateLiveSettings{if(!liveUnit)return;auto s=[self settings];AudioUnitSetParameter(liveUnit.audioUnit,0,kAudioUnitScope_Global,0,s.rumbleHz,0);AudioUnitSetParameter(liveUnit.audioUnit,1,kAudioUnitScope_Global,0,s.leveling*100,0);AudioUnitSetParameter(liveUnit.audioUnit,2,kAudioUnitScope_Global,0,s.gainDb,0);}
-(void)monitorChanged:(id)sender{(void)sender;liveEngine.mainMixerNode.outputVolume=monitor.state==NSControlStateValueOn?.65:0;}
-(void)toggleLive:(id)sender{
 (void)sender;if(liveEngine.isRunning){[self stopLive];return;}liveStart.enabled=NO;NSUInteger request=++liveRequest;
 [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted){dispatch_async(dispatch_get_main_queue(),^{if(request!=self->liveRequest||!self->livePanel.visible)return;self->liveStart.enabled=YES;if(!granted){self->liveStatus.stringValue=@"Microphone access denied. Enable VoicePrep in System Settings → Privacy & Security → Microphone.";return;}[self startLive];});}];
}
-(void)startLive{
 [self pause];
 @try {
 AudioComponentDescription desc={kAudioUnitType_Effect,'Vprp','Aalt',0,0};
 if(!pluginBundle){NSURL* url=[NSBundle.mainBundle.builtInPlugInsURL URLByAppendingPathComponent:@"VoicePrep.component"];pluginBundle=CFBundleCreate(kCFAllocatorDefault,(__bridge CFURLRef)url);if(!pluginBundle||!CFBundleLoadExecutable(pluginBundle))@throw [NSException exceptionWithName:@"Plugin" reason:@"The bundled Audio Unit could not load. Rebuild VoicePrep." userInfo:nil];
 auto factory=(AudioComponentFactoryFunction)CFBundleGetFunctionPointerForName(pluginBundle,CFSTR("VoicePrepAUFactory"));if(!factory||!AudioComponentRegister(&desc,CFSTR("Aymen Al-Tahmschi: VoicePrep"),65536,factory))@throw [NSException exceptionWithName:@"Plugin" reason:@"The bundled Audio Unit could not register." userInfo:nil];}
 liveEngine=[AVAudioEngine new];AVAudioInputNode* input=liveEngine.inputNode;AVAudioFormat* format=[input outputFormatForBus:0];
 if(format.channelCount<1||format.sampleRate<8000||format.sampleRate>192000)@throw [NSException exceptionWithName:@"Input" reason:@"Choose a microphone at 8–192 kHz in Audio MIDI Setup." userInfo:nil];
 AVAudioFormat* mono=[[AVAudioFormat alloc] initStandardFormatWithSampleRate:format.sampleRate channels:1];
 liveUnit=[[AVAudioUnitEffect alloc] initWithAudioComponentDescription:desc];[liveEngine attachNode:liveUnit];[liveEngine connect:input to:liveUnit format:mono];[liveEngine connect:liveUnit to:liveEngine.mainMixerNode format:mono];[self updateLiveSettings];
 __weak VPController* weakSelf=self;[liveUnit installTapOnBus:0 bufferSize:256 format:mono block:^(AVAudioPCMBuffer* buffer,AVAudioTime* when){(void)when;VPController* owner=weakSelf;if(!owner)return;float peak=0;for(AVAudioFrameCount i=0;i<buffer.frameLength;i++)peak=std::max(peak,std::abs(buffer.floatChannelData[0][i]));owner->livePeak.store(peak);owner->liveFrames.fetch_add(buffer.frameLength);}];
 monitor.state=NSControlStateValueOff;liveEngine.mainMixerNode.outputVolume=0;NSError* error=nil;if(![liveEngine startAndReturnError:&error])@throw [NSException exceptionWithName:@"Audio" reason:error.localizedDescription userInfo:nil];
 liveStart.title=@"Stop microphone";monitor.enabled=YES;rumble.enabled=level.enabled=gain.enabled=YES;liveStatus.stringValue=@"Live · 5 ms processing lookahead + device buffering";
 [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(liveDeviceChanged:) name:AVAudioEngineConfigurationChangeNotification object:liveEngine];
 }@catch(NSException* e){[self stopLive];liveStatus.stringValue=e.reason?:@"Microphone could not start.";}
}
-(void)liveDeviceChanged:(NSNotification*)notification{(void)notification;dispatch_async(dispatch_get_main_queue(),^{if(notification.object!=self->liveEngine)return;[self stopLive];self->liveStatus.stringValue=@"Audio device changed. Start the microphone again.";});}
-(void)stopLive{++liveRequest;liveStart.enabled=YES;if(liveEngine){[[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioEngineConfigurationChangeNotification object:liveEngine];[liveEngine stop];[liveUnit removeTapOnBus:0];liveEngine=nil;liveUnit=nil;}livePeak.store(0);liveFrames.store(0);meter.doubleValue=0;liveMeter.stringValue=@"Processed peak: —";monitor.state=NSControlStateValueOff;monitor.enabled=NO;liveStart.title=@"Start microphone";liveStatus.stringValue=@"Stopped · Uses the Mac’s current input and output devices";if(!source)rumble.enabled=level.enabled=gain.enabled=NO;}
-(void)windowWillClose:(NSNotification*)notification{if(notification.object==livePanel)[self stopLive];if(notification.object==window){[self stopLive];[NSApp terminate:nil];}}
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender{(void)sender;return YES;}
-(void)applicationWillTerminate:(NSNotification*)n{(void)n;[timer invalidate];[self stopLive];if(pluginBundle)CFRelease(pluginBundle);[originalPlayer stop];[preparedPlayer stop];[[NSFileManager defaultManager] removeItemAtURL:tempDirectory error:nil];}
@end
int main(int argc,const char** argv){(void)argc;(void)argv;@autoreleasepool{NSApplication* app=[NSApplication sharedApplication];VPController* delegate=[VPController new];app.delegate=delegate;[app run];}return 0;}
