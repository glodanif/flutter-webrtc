#if TARGET_OS_IPHONE

#import <Foundation/Foundation.h>

/// Keeps WebRTC's AVAudioEngine audio device module from instantiating the
/// microphone input node in apps that never record. Install once, as early as
/// possible — see the implementation for the failure it prevents.
@interface AudioEngineInputGuard : NSObject
+ (void)install;
@end

#endif
