#if TARGET_OS_IPHONE
#import "AudioEngineInputGuard.h"

#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

// WebRTC's AVAudioEngine audio device module reads `engine.inputNode`
// unconditionally in the "Recreate AVAudioEngine" and "Release AVAudioEngine"
// steps of AudioEngineDevice::ApplyDeviceEngineState, to stop the input audio
// unit before tearing the graph down. Reading that property instantiates
// AVAudioInputNode, which asks iOS for microphone authorization — even for a
// playout-only engine whose input was never enabled.
//
// So a receive-only app gets a microphone permission request when the last
// audio track goes away (stream teardown) or when a route change forces an
// engine recreate, and TCC kills the process outright when Info.plist carries
// no NSMicrophoneUsageDescription.
//
// Introduced by webrtc-sdk/webrtc#228 (7af9351, 2026-03-24), still present on
// main. The SDK's own inputNode accessor asserts the node is only touched when
// input is enabled; these two teardown sites read the ivar and bypass it.
// See webrtc-sdk/webrtc#281 and #2142.
//
// 1.3.0 is unaffected: it used the AudioEngine ADM against WebRTC-SDK
// 137.7151.x, which predates the read. 1.3.1-1.4.1 use the CoreAudio ADM
// (#1990), which has the crash reported in #2007 instead.
//
// An app without NSMicrophoneUsageDescription can never capture audio, so for
// those apps we swizzle the getter to return nil rather than materialize the
// node. WebRTC nil-checks the result and skips the input unit, and the rest of
// its teardown proceeds untouched. Apps that declare the key keep the stock
// getter, so the common case is bit-for-bit unchanged.

static AVAudioInputNode* guardedInputNode(id self, SEL _cmd) {
  return nil;
}

@implementation AudioEngineInputGuard

+ (void)install {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    if ([NSBundle mainBundle].infoDictionary[@"NSMicrophoneUsageDescription"] != nil) {
      return;
    }
    Method inputNode = class_getInstanceMethod([AVAudioEngine class], @selector(inputNode));
    if (inputNode == NULL) {
      NSLog(@"AudioEngineInputGuard: -[AVAudioEngine inputNode] not found, guard not installed");
      return;
    }
    method_setImplementation(inputNode, (IMP)guardedInputNode);
    NSLog(@"AudioEngineInputGuard: no NSMicrophoneUsageDescription in Info.plist; stubbing out "
          @"AVAudioEngine.inputNode so audio engine teardown cannot request microphone access");
  });
}

@end
#endif
