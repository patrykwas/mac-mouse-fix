//
// --------------------------------------------------------------------------
// ModifierInputReceiver.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ScrollModifiers.h"
#import "ScrollControl.h"

// TODO: Rename to ScrollModifierInputReceiver. Maybe merge this into ScrollControl or put the modifier properties from ScrollControl into this.
@implementation ScrollModifiers

#pragma mark - Public class variables

static BOOL _horizontalScrollModifierKeyEnabled = YES;
+ (BOOL)horizontalScrollModifierKeyEnabled {
    return _horizontalScrollModifierKeyEnabled;
}
+ (void)setHorizontalScrollModifierKeyEnabled:(BOOL)B {
    _horizontalScrollModifierKeyEnabled = B;
}
static BOOL _magnificationScrollModifierKeyEnabled = YES;
+ (BOOL)magnificationScrollModifierKeyEnabled {
    return _magnificationScrollModifierKeyEnabled;
}
+ (void)setMagnificationScrollModifierKeyEnabled:(BOOL)B {
    _magnificationScrollModifierKeyEnabled = B;
}
static CGEventFlags _horizontalScrollModifierKeyMask = 0;
//+ (CGEventFlags)horizontalModifier {
//    return _horizontalModifier;
//}
+ (void)setHorizontalScrollModifierKeyMask:(CGEventFlags)F {
    _horizontalScrollModifierKeyMask = F;
}
static CGEventFlags _magnificationScrollModifierKeyMask = 0;
//+ (CGEventFlags)magnificationModifier {
//    return _magnificationModifier;
//}
+ (void)setMagnificationScrollModifierKeyMask:(CGEventFlags)F {
    _magnificationScrollModifierKeyMask = F;
}

#pragma mark - Private class variables

CFMachPortRef _eventTapKey;

#pragma mark - Public functions

+ (void)initialize {
    setupModifierKeyCallback();
}
+ (void)start {
    CGEventTapEnable(_eventTapKey, true);
}
+ (void)stop {
    CGEventTapEnable(_eventTapKey, false);
}

#pragma mark - Private functions

static void setupModifierKeyCallback() {
    CGEventMask mask = CGEventMaskBit(kCGEventFlagsChanged);
    _eventTapKey = CGEventTapCreate(kCGHIDEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault, mask, Handle_ModifierChanged, NULL);
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTapKey, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    CFRelease(runLoopSource);
}

CGEventRef Handle_ModifierChanged(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    CGEventFlags flags = CGEventGetFlags(event);
    if (flags & _horizontalScrollModifierKeyMask && _horizontalScrollModifierKeyEnabled) {
        ScrollControl.horizontalScrolling = YES;
    } else {
        ScrollControl.horizontalScrolling = NO;
    }
    if (flags & _magnificationScrollModifierKeyMask && _magnificationScrollModifierKeyEnabled) {
        ScrollControl.magnificationScrolling = YES;
    } else {
        ScrollControl.magnificationScrolling = NO;
    }
    
    /*
     if (flags & kCGEventFlagMaskSecondaryFn) {
     [MomentumScroll temporarilyDisable:TRUE];
     } else {
     [MomentumScroll temporarilyDisable:FALSE];
     }
     */
    
    return event;
}

//static CGEventFlags stringToEventFlagMask(NSString *string) {
//    switch(string) {
//        case @"command":
//            return kCGEventFlagMaskCommand;
//            break;
//        case @"control":
//            return kCGEventFlagMaskControl;
//        case @"option":
//            return kCGEventFlagMaskAlternate;
//            break;
//        case @"shift":
//            return kCGEventFlagMaskShift;
//            break;
//    }
//}

@end