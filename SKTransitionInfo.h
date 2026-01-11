//
//  SKTransitionInfo.h
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

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

extern NSPasteboardType const SKPasteboardTypeTransition;

// further values are defined at runtime
typedef NSUInteger SKTransitionStyle;
static const SKTransitionStyle SKNoTransition = 0;

@interface SKTransitionInfo : NSObject <NSCopying, NSPasteboardReading, NSPasteboardWriting> {
    SKTransitionStyle style;
    CGFloat duration;
    BOOL shouldRestrict;
}

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithTransitionInfo:(SKTransitionInfo *)info;
- (instancetype)initWithProperties:(NSDictionary<NSString *, id> *)dictionary;

@property (nonatomic) SKTransitionStyle style;
@property (nonatomic) CGFloat duration;
@property (nonatomic) BOOL shouldRestrict;

@property (nonatomic, readonly) NSDictionary<NSString *, id> *properties;

@property (nonatomic, nullable, readonly) NSString *styleName;

@property (class, nonatomic, readonly) NSArray<NSString *> *localizedStyleNames;

@end

#pragma mark -

@class SKThumbnail;

@interface SKLabeledTransitionInfo : SKTransitionInfo {
    SKThumbnail *thumbnail;
    SKThumbnail *toThumbnail;
}

@property (nonatomic, nullable, strong) SKThumbnail *thumbnail, *toThumbnail;

@property (nonatomic, nullable, readonly) NSString *label;

@property (nonatomic, nullable, readonly) NSString *localizedStyleName;

@property (nonatomic, copy) SKTransitionInfo *info;

@end

NS_ASSUME_NONNULL_END
