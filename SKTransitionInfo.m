//
//  SKTransitionInfo.m
//  Skim
//
//  Created by Christiaan Hofman on 8/10/09.
/*
 This software is Copyright (c) 2009
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SKTransitionInfo.h"
#import "SKThumbnail.h"
#import <Quartz/Quartz.h>

#define SKStyleNameKey      @"styleName"
#define SKDurationKey       @"duration"
#define SKShouldRestrictKey @"shouldRestrict"

#define TRANSITIONS_PLUGIN @"SkimTransitions.plugin"

NSPasteboardType const SKPasteboardTypeTransition = @"net.sourceforge.skim-app.pasteboard.transition";

@implementation SKTransitionInfo

@synthesize style, duration, shouldRestrict;
@dynamic properties, styleName;

static NSDictionary *oldStyleNames = nil;

+ (void)initialize {
    SKINITIALIZE;
    oldStyleNames = [[NSDictionary alloc] initWithObjectsAndKeys:
                     @"CoreGraphics SKTransitionFade", @"CIDissolveTransition",
                     @"CoreGraphics SKTransitionZoom", @"SKTZoomTransition",
                     @"CoreGraphics SKTransitionReveal", @"SKTRevealTransition",
                     @"CoreGraphics SKTransitionSlide", @"SKTSlideTransition",
                     @"CoreGraphics SKTransitionWarpFade", @"SKTWarpFadeTransition",
                     @"CoreGraphics SKTransitionSwap", @"SKTSwapTransition",
                     @"CoreGraphics SKTransitionCube", @"SKTCubeTransition",
                     @"CoreGraphics SKTransitionWarpSwitch", @"SKTWarpSwitchTransition",
                     @"CoreGraphics SKTransitionWarpFlip", @"SKTFlipTransition",
                     @"SKPTAccelerationTransitionFilter", @"SKTAccelerationTransition",
                     @"SKPTBlindsTransitionFilter", @"SKTBlindsTransition",
                     @"SKPTBlurTransitionFilter", @"SKTBlurTransition",
                     @"SKPTBoxInTransitionFilter", @"SKTBoxInTransition",
                     @"SKPTBoxOutTransitionFilter", @"SKTBoxOutTransition",
                     @"SKPTCoverTransitionFilter", @"SKTCoverTransition",
                     @"SKPTHoleTransitionFilter", @"SKTHoleTransition",
                     @"SKPTMeltdownTransitionFilter", @"SKTMeltdownTransition",
                     @"SKPTPinchTransitionFilter", @"SKTPinchTransition",
                     @"SKPTRadarTransitionFilter", @"SKTRadarTransition",
                     @"SKPTSinkTransitionFilter", @"SKTSinkTransition",
                     @"SKPTSplitInTransitionFilter", @"SKTSplitInTransition",
                     @"SKPTSplitOutTransitionFilter", @"SKSplitOutTransition",
                     @"SKPTStripsTransitionFilter", @"SKTStripsTransition",
                     @"SKPTUncoverTransitionFilter", @"SKTRevealTransition",
                     nil];
}

+ (NSArray *)transitionNames {
    static NSArray *transitionNames = nil;
    
    if (transitionNames == nil) {
        // get our transitions
        NSURL *transitionsURL = [[[NSBundle mainBundle] builtInPlugInsURL] URLByAppendingPathComponent:TRANSITIONS_PLUGIN isDirectory:YES];
        [CIPlugIn loadPlugIn:transitionsURL allowExecutableCode:YES];
        // get all the transition filters
        [CIPlugIn loadAllPlugIns];
        transitionNames = [NSArray arrayWithArray:[CIFilter filterNamesInCategory:kCICategoryTransition]];
    }
    
    return transitionNames;
}

+ (NSArray *)localizedStyleNames {
    NSMutableArray *names = [NSMutableArray arrayWithObject:NSLocalizedString(@"No Transition", @"Transition name")];
    for (NSString *name in [self transitionNames])
        [names addObject:[CIFilter localizedNameForFilterName:name] ?: name];
    return names;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        style = SKNoTransition;
        duration = 1.0;
        shouldRestrict = YES;
    }
    return self;
}

- (instancetype)initWithTransitionInfo:(SKTransitionInfo *)info {
    self = [self init];
    if (self) {
        style = [info style];
        duration = [info duration];
        shouldRestrict = [info shouldRestrict];
    }
    return self;
}

- (instancetype)initWithProperties:(NSDictionary *)dictionary {
    self = [self init];
    if (self) {
        id value;
        if ((value = [dictionary objectForKey:SKStyleNameKey])) {
            NSUInteger idx = NSNotFound;
            if ([value length]) {
                NSArray *names = [[self class] transitionNames];
                idx = [names indexOfObject:value];
                if (idx == NSNotFound && (value = [oldStyleNames objectForKey:value]))
                    idx = [names indexOfObject:value];
            }
            style = idx == NSNotFound ? SKNoTransition : idx + 1;
        }
        if ((value = [dictionary objectForKey:SKDurationKey]))
            duration = [value doubleValue];
        if ((value = [dictionary objectForKey:SKShouldRestrictKey]))
            shouldRestrict = [value boolValue];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard {
    return @[SKPasteboardTypeTransition];
}

+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard {
    if ([type isEqualToString:SKPasteboardTypeTransition])
        return NSPasteboardReadingAsPropertyList;
    return NSPasteboardReadingAsData;
}

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard {
    return @[SKPasteboardTypeTransition];
}

- (id)pasteboardPropertyListForType:(NSString *)type {
    if ([type isEqualToString:SKPasteboardTypeTransition])
        return [self properties];
    return nil;
}

- (instancetype)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type {
    if ([type isEqualToString:SKPasteboardTypeTransition])
        self = [self initWithProperties:propertyList];
    else
        self = nil;
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p> %@", [self class], self, [self properties]];
}

- (NSDictionary *)properties {
    return @{SKStyleNameKey:([self styleName] ?: @""),
             SKDurationKey:[NSNumber numberWithDouble:duration],
             SKShouldRestrictKey:[NSNumber numberWithBool:shouldRestrict]};
}

- (NSString *)styleName {
    if (style > SKNoTransition) {
        NSArray *names = [[self class] transitionNames];
        if (style <= [names count])
            return [names objectAtIndex:style - 1];
    }
    return nil;
}

@end

#pragma mark -

@implementation SKLabeledTransitionInfo

@synthesize thumbnail, toThumbnail;
@dynamic label, localizedStyleName, info;

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    if ([key isEqualToString:@"localizedStyleName"])
        keyPaths = [keyPaths setByAddingObjectsFromSet:[NSSet setWithObjects:@"style", nil]];
    else if ([key isEqualToString:@"label"])
        keyPaths = [keyPaths setByAddingObjectsFromSet:[NSSet setWithObjects:@"thumbnail.label", @"toThumbnail.label", nil]];
    return keyPaths;
}

- (id)copyWithZone:(NSZone *)zone {
    return [[SKTransitionInfo alloc] initWithTransitionInfo:self];
}

- (SKTransitionInfo *)info {
    return [[SKTransitionInfo alloc] initWithTransitionInfo:self];
}

- (void)setInfo:(SKTransitionInfo *)info {
    [self setStyle:[info style]];
    [self setDuration:[info duration]];
    [self setShouldRestrict:[info shouldRestrict]];
}

- (NSString *)localizedStyleName {
    NSString *name = [self styleName];
    if (name)
        return [CIFilter localizedNameForFilterName:name];
    return NSLocalizedString(@"No Transition", @"Transition name");
}

- (NSString *)label {
    if ([self thumbnail] && [self toThumbnail])
        return [NSString stringWithFormat:@"%@\u2192%@", [[self thumbnail] label], [[self toThumbnail] label]];
    return nil;
}

@end
