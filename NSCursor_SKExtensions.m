//
//  NSCursor_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 2/16/07.
/*
 This software is Copyright (c) 2007
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

#import "NSCursor_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "SKRuntime.h"
#import "SKAnimatedBorderlessWindow.h"
#import "NSGeometry_SKExtensions.h"
#import "NSWindow_SKExtensions.h"
#import "NSShadow_SKExtensions.h"
#import "NSBezierPath_SKExtensions.h"

static char SKUniversalAccessDefaultsObservationContext;

static inline void hideLaserPointer(void);

@interface NSCursor (SKPrivateDeclarations)
+ (id)_windowResizeNorthWestSouthEastCursor;
+ (id)_windowResizeNorthEastSouthWestCursor;
@end

#pragma mark -

@interface SKLaserPointerCursor : NSCursor
@end

#pragma mark -

@interface SKCustomCursors : NSObject {
    NSUserDefaults *universalaccessDefaults;
    NSMutableDictionary *customCursors;
    NSColor *cursorOutline;
    NSColor *cursorFill;
    BOOL customizedColors;
}

@property(class, nonatomic, readonly) SKCustomCursors *sharedCustomCursors;

@property (nonatomic, readonly) NSUserDefaults *universalaccessDefaults;

- (NSCursor *)cursorWithName:(NSString *)name;

@end

#pragma mark -

@implementation NSCursor (SKExtensions)

static void (*original_set)(id, SEL) = NULL;
static void (*original_hide)(id, SEL) = NULL;

static void replacement_set(id self, SEL _cmd) {
    original_set(self, _cmd);
    hideLaserPointer();
}

static void replacement_hide(id self, SEL _cmd) {
    original_hide(self, _cmd);
    hideLaserPointer();
}

+ (void)load {
    original_set = (void(*)(id, SEL))SKReplaceInstanceMethodImplementation(self, @selector(set), (IMP)replacement_set);
    original_hide = (void(*)(id, SEL))SKReplaceClassMethodImplementation(self, @selector(hide), (IMP)replacement_hide);
}

+ (NSCursor *)zoomInCursor {
    return [[SKCustomCursors sharedCustomCursors] cursorWithName:@"zoomInCursor"];
}

+ (NSCursor *)zoomOutCursor {
    return [[SKCustomCursors sharedCustomCursors] cursorWithName:@"zoomOutCursor"];
}

+ (NSCursor *)resizeDiagonal45Cursor {
    if ([self respondsToSelector:@selector(_windowResizeNorthEastSouthWestCursor)]) {
        return [NSCursor _windowResizeNorthEastSouthWestCursor];
    } else {
        return [[SKCustomCursors sharedCustomCursors] cursorWithName:@"resizeDiagonal45Cursor"];
    }
}

+ (NSCursor *)resizeDiagonal135Cursor {
    if ([self respondsToSelector:@selector(_windowResizeNorthWestSouthEastCursor)]) {
        return [NSCursor _windowResizeNorthWestSouthEastCursor];
    } else {
        return [[SKCustomCursors sharedCustomCursors] cursorWithName:@"resizeDiagonal135Cursor"];
    }
}

+ (NSCursor *)cameraCursor {
    return [[SKCustomCursors sharedCustomCursors] cursorWithName:@"cameraCursor"];
}

+ (NSCursor *)openHandBarCursor {
    return [[SKCustomCursors sharedCustomCursors] cursorWithName:@"openHandBarCursor"];
}

+ (NSCursor *)closedHandBarCursor {
    return [[SKCustomCursors sharedCustomCursors] cursorWithName:@"closedHandBarCursor"];
}

+ (NSCursor *)textNoteCursor {
    return [[SKCustomCursors sharedCustomCursors] cursorWithName:@"textNoteCursor"];
}

+ (NSCursor *)anchoredNoteCursor {
    return [[SKCustomCursors sharedCustomCursors] cursorWithName:@"anchoredNoteCursor"];
}

+ (NSCursor *)circleNoteCursor {
    return [[SKCustomCursors sharedCustomCursors] cursorWithName:@"circleNoteCursor"];
}

+ (NSCursor *)squareNoteCursor {
    return [[SKCustomCursors sharedCustomCursors] cursorWithName:@"squareNoteCursor"];
}

+ (NSCursor *)highlightNoteCursor {
    return [[SKCustomCursors sharedCustomCursors] cursorWithName:@"highlightNoteCursor"];
}

+ (NSCursor *)underlineNoteCursor {
    return [[SKCustomCursors sharedCustomCursors] cursorWithName:@"underlineNoteCursor"];
}

+ (NSCursor *)strikeOutNoteCursor {
    return [[SKCustomCursors sharedCustomCursors] cursorWithName:@"strikeOutNoteCursor"];
}

+ (NSCursor *)lineNoteCursor {
    return [[SKCustomCursors sharedCustomCursors] cursorWithName:@"lineNoteCursor"];
}

+ (NSCursor *)inkNoteCursor {
    return [[SKCustomCursors sharedCustomCursors] cursorWithName:@"inkNoteCursor"];
}

+ (NSCursor *)emptyCursor {
    static NSCursor *emptyCursor = nil;
    if (nil == emptyCursor) {
        NSImage *cursorImage = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
        emptyCursor = [[NSCursor alloc] initWithImage:cursorImage hotSpot:NSMakePoint(8.0, 8.0)];
    }
    return emptyCursor;
}

+ (NSCursor *)laserPointerCursorWithColor:(NSInteger)color {
    static NSPointerArray *laserPointerCursors = nil;
    if (laserPointerCursors == nil) {
        laserPointerCursors = [NSPointerArray strongObjectsPointerArray];
        [laserPointerCursors setCount:7];
    }
    NSCursor *cursor = (__bridge id)[laserPointerCursors pointerAtIndex:color % 7];
    if (nil == cursor) {
        NSImage *cursorImage = [NSImage laserPointerImageWithColor:color % 7];
        cursor = [[NSCursor alloc] initWithImage:cursorImage hotSpot:NSMakePoint(0.5 * [cursorImage size].width, 0.5 * [cursorImage size].height)];
        [laserPointerCursors replacePointerAtIndex:color % 7 withPointer:(__bridge  void *)cursor];
    }
    return cursor;
}

+ (NSCursor *)safeLaserPointerCursorWithColor:(NSInteger)color {
    static NSPointerArray *laserPointerCursors = nil;
    if (laserPointerCursors == nil) {
        laserPointerCursors = [NSPointerArray strongObjectsPointerArray];
        [laserPointerCursors setCount:7];
    }
    NSCursor *cursor = (__bridge id)[laserPointerCursors pointerAtIndex:color % 7];
    if (nil == cursor) {
        NSImage *cursorImage = [NSImage laserPointerImageWithColor:color % 7];
        cursor = [[SKLaserPointerCursor alloc] initWithImage:cursorImage hotSpot:NSMakePoint(0.5 * [cursorImage size].width, 0.5 * [cursorImage size].height)];
        [laserPointerCursors replacePointerAtIndex:color % 7 withPointer:(__bridge  void *)cursor];
    }
    return cursor;
}

@end

#pragma mark -

static NSWindow *laserPointerWindow = nil;

static inline void hideLaserPointer(void) {
    if (laserPointerWindow) {
        [laserPointerWindow close];
        laserPointerWindow = nil;
    }
}

@implementation SKLaserPointerCursor

- (void)set {
    if (original_set)
        original_set([NSCursor emptyCursor], _cmd);
    else
        [[NSCursor emptyCursor] set];
    
    NSPoint p = [NSEvent mouseLocation];
    p = NSMakePoint(round(p.x), round(p.y));
    if (laserPointerWindow) {
        [[[[laserPointerWindow contentView] subviews] firstObject] setImage:[self image]];
        [laserPointerWindow setFrame:SKRectFromCenterAndSize(p, [laserPointerWindow frame].size) display:YES];
    } else {
        NSImage *image = [self image];
        CGFloat size = [[[SKCustomCursors sharedCustomCursors] universalaccessDefaults] doubleForKey:@"mouseDriverCursorSize"];
        CGFloat s = 2.0 * round(0.5 * (size > 0.0 ? size : 1.0) * [image size].width);
        laserPointerWindow = [[SKAnimatedBorderlessWindow alloc] initWithContentRect:SKRectFromCenterAndSquareSize(p, s)];
        [laserPointerWindow setLevel:(NSWindowLevel)kCGCursorWindowLevel];
        [laserPointerWindow addImageViewWithImage:image];
        [laserPointerWindow setHidesOnDeactivate:YES];
        [laserPointerWindow orderFrontRegardless];
    }
}

@end

#pragma mark -

@implementation SKCustomCursors

@dynamic universalaccessDefaults;

+ (SKCustomCursors *)sharedCustomCursors {
    static SKCustomCursors *sharedCustomCursors = nil;
    if (sharedCustomCursors == nil)
        sharedCustomCursors = [[self alloc] init];
    return sharedCustomCursors;
}

- (NSUserDefaults *)universalaccessDefaults {
    if (universalaccessDefaults == nil) {
        universalaccessDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.apple.universalaccess"];
        if (@available(macOS 12.0, *)) {
            [universalaccessDefaults addObserver:self forKeyPath:@"cursorIsCustomized" options:0 context:&SKUniversalAccessDefaultsObservationContext];
            [universalaccessDefaults addObserver:self forKeyPath:@"cursorOutline" options:0 context:&SKUniversalAccessDefaultsObservationContext];
            [universalaccessDefaults addObserver:self forKeyPath:@"cursorFill" options:0 context:&SKUniversalAccessDefaultsObservationContext];
        }
    }
    return universalaccessDefaults;
}

- (NSCursor *)cursorWithName:(NSString *)name {
    if (customCursors == nil) {
        customCursors = [NSMutableDictionary dictionary];
        
        customizedColors = NO;
        cursorOutline = [NSColor whiteColor];
        cursorFill = [NSColor blackColor];
        if (@available(macOS 12.0, *)) {
            if ([[self universalaccessDefaults] boolForKey:@"cursorIsCustomized"]) {
                customizedColors = YES;
                NSDictionary *outlineDict = [[self universalaccessDefaults] dictionaryForKey:@"cursorOutline"];
                NSDictionary *fillDict = [[self universalaccessDefaults] dictionaryForKey:@"cursorFill"];
                if ([outlineDict count] == 4 && [fillDict count] == 4) {
                    cursorOutline = [NSColor colorWithSRGBRed:[[outlineDict objectForKey:@"red"] doubleValue] green:[[outlineDict objectForKey:@"green"] doubleValue] blue:[[outlineDict objectForKey:@"blue"] doubleValue] alpha:[[outlineDict objectForKey:@"alpha"] doubleValue]] ?: cursorOutline;
                    cursorFill = [NSColor colorWithSRGBRed:[[fillDict objectForKey:@"red"] doubleValue] green:[[fillDict objectForKey:@"green"] doubleValue] blue:[[fillDict objectForKey:@"blue"] doubleValue] alpha:[[fillDict objectForKey:@"alpha"] doubleValue]] ?: cursorFill;
                }
            }
        }
    }
    
    NSCursor *cursor = [customCursors objectForKey:name];
    
    if (cursor == nil) {
        NSImage *image = nil;
        NSPoint hotspot = NSZeroPoint;
        
        if ([name isEqualToString:@"resizeDiagonal45Cursor"]) {
            
            image = [[NSImage alloc] initPDFWithSize:NSMakeSize(16.0, 16.0) drawingHandler:^(NSRect dstRect){
                [cursorOutline setFill];
                NSBezierPath *path = [NSBezierPath bezierPath];
                [path moveToPoint:NSMakePoint(2.0, 2.0)];
                [path lineToPoint:NSMakePoint(9.5, 2.0)];
                [path lineToPoint:NSMakePoint(7.0, 4.5)];
                [path lineToPoint:NSMakePoint(8.0, 5.5)];
                [path lineToPoint:NSMakePoint(12.5, 1.0)];
                [path lineToPoint:NSMakePoint(15.0, 3.5)];
                [path lineToPoint:NSMakePoint(10.5, 8.0)];
                [path lineToPoint:NSMakePoint(11.5, 9.0)];
                [path lineToPoint:NSMakePoint(14.0, 6.5)];
                [path lineToPoint:NSMakePoint(14.0, 14.0)];
                [path lineToPoint:NSMakePoint(6.5, 14.0)];
                [path lineToPoint:NSMakePoint(9.0, 11.5)];
                [path lineToPoint:NSMakePoint(8.0, 10.5)];
                [path lineToPoint:NSMakePoint(3.5, 15.0)];
                [path lineToPoint:NSMakePoint(1.0, 12.5)];
                [path lineToPoint:NSMakePoint(5.5, 8.0)];
                [path lineToPoint:NSMakePoint(4.5, 7.0)];
                [path lineToPoint:NSMakePoint(2.0, 9.5)];
                [path closePath];
                [NSGraphicsContext saveGraphicsState];
                [NSShadow setShadowWithWhite:0.0 alpha:0.33333 blurRadius:1.0 yOffset:-1.0];
                [path fill];
                [NSGraphicsContext restoreGraphicsState];
                [cursorFill setFill];
                path = [NSBezierPath bezierPath];
                [path moveToPoint:NSMakePoint(3.0, 3.0)];
                [path lineToPoint:NSMakePoint(7.0, 3.0)];
                [path lineToPoint:NSMakePoint(5.5, 4.5)];
                [path lineToPoint:NSMakePoint(8.0, 7.0)];
                [path lineToPoint:NSMakePoint(12.5, 2.5)];
                [path lineToPoint:NSMakePoint(13.5, 3.5)];
                [path lineToPoint:NSMakePoint(9.0, 8.0)];
                [path lineToPoint:NSMakePoint(11.5, 10.5)];
                [path lineToPoint:NSMakePoint(13.0, 9.0)];
                [path lineToPoint:NSMakePoint(13.0, 13.0)];
                [path lineToPoint:NSMakePoint(9.0, 13.0)];
                [path lineToPoint:NSMakePoint(10.5, 11.5)];
                [path lineToPoint:NSMakePoint(8.0, 9.0)];
                [path lineToPoint:NSMakePoint(3.5, 13.5)];
                [path lineToPoint:NSMakePoint(2.5, 12.5)];
                [path lineToPoint:NSMakePoint(7.0, 8.0)];
                [path lineToPoint:NSMakePoint(4.5, 5.5)];
                [path lineToPoint:NSMakePoint(3.0, 7.0)];
                [path closePath];
                [path fill];
            }];
            hotspot = NSMakePoint(8.0, 8.0);
            
        } else if ([name isEqualToString:@"resizeDiagonal135Cursor"]) {
            
            image = [[NSImage alloc] initPDFWithSize:NSMakeSize(16.0, 16.0) drawingHandler:^(NSRect dstRect){
                [cursorOutline setFill];
                NSBezierPath *path = [NSBezierPath bezierPath];
                [path moveToPoint:NSMakePoint(14.0, 2.0)];
                [path lineToPoint:NSMakePoint(14.0, 9.5)];
                [path lineToPoint:NSMakePoint(11.5, 7.0)];
                [path lineToPoint:NSMakePoint(10.5, 8.0)];
                [path lineToPoint:NSMakePoint(15.0, 12.5)];
                [path lineToPoint:NSMakePoint(12.5, 15.0)];
                [path lineToPoint:NSMakePoint(8.0, 10.5)];
                [path lineToPoint:NSMakePoint(7.0, 11.5)];
                [path lineToPoint:NSMakePoint(9.5, 14.0)];
                [path lineToPoint:NSMakePoint(2.0, 14.0)];
                [path lineToPoint:NSMakePoint(2.0, 6.5)];
                [path lineToPoint:NSMakePoint(4.5, 9.0)];
                [path lineToPoint:NSMakePoint(5.5, 8.0)];
                [path lineToPoint:NSMakePoint(1.0, 3.5)];
                [path lineToPoint:NSMakePoint(3.5, 1.0)];
                [path lineToPoint:NSMakePoint(8.0, 5.5)];
                [path lineToPoint:NSMakePoint(9.0, 4.5)];
                [path lineToPoint:NSMakePoint(6.5, 2.0)];
                [path closePath];
                [NSGraphicsContext saveGraphicsState];
                [NSShadow setShadowWithWhite:0.0 alpha:0.33333 blurRadius:1.0 yOffset:-1.0];
                [path fill];
                [NSGraphicsContext restoreGraphicsState];
                [cursorFill setFill];
                path = [NSBezierPath bezierPath];
                [path moveToPoint:NSMakePoint(13.0, 3.0)];
                [path lineToPoint:NSMakePoint(13.0, 7.0)];
                [path lineToPoint:NSMakePoint(11.5, 5.5)];
                [path lineToPoint:NSMakePoint(9.0, 8.0)];
                [path lineToPoint:NSMakePoint(13.5, 12.5)];
                [path lineToPoint:NSMakePoint(12.5, 13.5)];
                [path lineToPoint:NSMakePoint(8.0, 9.0)];
                [path lineToPoint:NSMakePoint(5.5, 11.5)];
                [path lineToPoint:NSMakePoint(7.0, 13.0)];
                [path lineToPoint:NSMakePoint(3.0, 13.0)];
                [path lineToPoint:NSMakePoint(3.0, 9.0)];
                [path lineToPoint:NSMakePoint(4.5, 10.5)];
                [path lineToPoint:NSMakePoint(7.0, 8.0)];
                [path lineToPoint:NSMakePoint(2.5, 3.5)];
                [path lineToPoint:NSMakePoint(3.5, 2.5)];
                [path lineToPoint:NSMakePoint(8.0, 7.0)];
                [path lineToPoint:NSMakePoint(10.5, 4.5)];
                [path lineToPoint:NSMakePoint(9.0, 3.0)];
                [path closePath];
                [path fill];
            }];
            hotspot = NSMakePoint(8.0, 8.0);
            
        } else if ([name isEqualToString:@"zoomInCursor"]) {

            image = [[NSImage alloc] initPDFWithSize:NSMakeSize(20.0, 20.0) drawingHandler:^(NSRect dstRect){
                [cursorOutline set];
                NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(1.0, 6.0, 14.0, 14.0)];
                [path moveToPoint:NSMakePoint(16.5, 1.5)];
                [path lineToPoint:NSMakePoint(19.5, 4.5)];
                [path lineToPoint:NSMakePoint(14.0, 10.0)];
                [path lineToPoint:NSMakePoint(11.0, 7.0)];
                [path closePath];
                [NSGraphicsContext saveGraphicsState];
                [NSShadow setShadowWithWhite:0.0 alpha:0.33333 blurRadius:1.0 yOffset:-1.0];
                [path fill];
                [NSGraphicsContext restoreGraphicsState];
                [cursorFill setStroke];
                path = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(2.5, 7.5, 11.0, 11.0)];
                [path setLineWidth:1.0];
                [path stroke];
                path = [NSBezierPath bezierPath];
                [path moveToPoint:NSMakePoint(17.25, 3.75)];
                [path lineToPoint:NSMakePoint(11.75, 9.25)];
                [path setLineWidth:2.0];
                [path stroke];
                path = [NSBezierPath bezierPath];
                [path moveToPoint:NSMakePoint(5.0, 13.0)];
                [path lineToPoint:NSMakePoint(11.0, 13.0)];
                [path moveToPoint:NSMakePoint(8.0, 10.0)];
                [path lineToPoint:NSMakePoint(8.0, 16.0)];
                [path setLineWidth:2.0];
                [path stroke];
            }];
            hotspot = NSMakePoint(8.0, 7.0);
            
        } else if ([name isEqualToString:@"zoomOutCursor"]) {
            
            image = [[NSImage alloc] initPDFWithSize:NSMakeSize(20.0, 20.0) drawingHandler:^(NSRect dstRect){
                [cursorOutline set];
                NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(1.0, 6.0, 14.0, 14.0)];
                [path moveToPoint:NSMakePoint(16.5, 1.5)];
                [path lineToPoint:NSMakePoint(19.5, 4.5)];
                [path lineToPoint:NSMakePoint(14.0, 10.0)];
                [path lineToPoint:NSMakePoint(11.0, 7.0)];
                [path closePath];
                [NSGraphicsContext saveGraphicsState];
                [NSShadow setShadowWithWhite:0.0 alpha:0.33333 blurRadius:1.0 yOffset:-1.0];
                [path fill];
                [NSGraphicsContext restoreGraphicsState];
                [cursorFill setStroke];
                path = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(2.5, 7.5, 11.0, 11.0)];
                [path setLineWidth:1.0];
                [path stroke];
                path = [NSBezierPath bezierPath];
                [path moveToPoint:NSMakePoint(17.25, 3.75)];
                [path lineToPoint:NSMakePoint(11.75, 9.25)];
                [path setLineWidth:2.0];
                [path stroke];
                path = [NSBezierPath bezierPath];
                [path moveToPoint:NSMakePoint(5.0, 13.0)];
                [path lineToPoint:NSMakePoint(11.0, 13.0)];
                [path setLineWidth:2.0];
                [path stroke];
            }];
            hotspot = NSMakePoint(8.0, 7.0);
            
        } else if ([name isEqualToString:@"cameraCursor"]) {
            
            image = [[NSImage alloc] initPDFWithSize:NSMakeSize(18.0, 15.0) drawingHandler:^(NSRect dstRect){
                NSBezierPath *path = [NSBezierPath bezierPath];
                [path moveToPoint:NSMakePoint(14.0, 12.0)];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(13.0, 12.0) toPoint:NSMakePoint(12.5, 13.0) radius:1.5];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(12.0, 14.0) toPoint:NSMakePoint(6.5, 14.0) radius:1.5];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(6.0, 14.0) toPoint:NSMakePoint(5.5, 13.0) radius:1.5];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(5.5, 12.0) toPoint:NSMakePoint(5.0, 12.0) radius:1.5];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(1.0, 12.0) toPoint:NSMakePoint(1.0, 10.0) radius:3.0];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(1.0, 2.0) toPoint:NSMakePoint(4.0, 2.0) radius:3.0];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(17.0, 2.0) toPoint:NSMakePoint(17.0, 5.0) radius:3.0];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(17.0, 12.0) toPoint:NSMakePoint(11.0, 12.0) radius:3.0];
                [path closePath];
                [NSGraphicsContext saveGraphicsState];
                [cursorOutline set];
                [NSShadow setShadowWithWhite:0.0 alpha:0.33333 blurRadius:1.0 yOffset:-1.0];
                [path fill];
                [NSGraphicsContext restoreGraphicsState];
                [cursorFill set];
                path = [NSBezierPath bezierPath];
                [path moveToPoint:NSMakePoint(14.0, 11.0)];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(12.5, 11.0) toPoint:NSMakePoint(12.0, 12.0) radius:1.5];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(11.5, 13.0) toPoint:NSMakePoint(6.0, 13.0) radius:1.5];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(6.5, 13.0) toPoint:NSMakePoint(6.0, 12.0) radius:1.5];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(5.5, 11.0) toPoint:NSMakePoint(4.0, 11.0) radius:1.5];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(2.0, 11.0) toPoint:NSMakePoint(2.0, 9.0) radius:2.0];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(2.0, 3.0) toPoint:NSMakePoint(4.0, 3.0) radius:2.0];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(16.0, 3.0) toPoint:NSMakePoint(16.0, 5.0) radius:2.0];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(16.0, 11.0) toPoint:NSMakePoint(14.0, 11.0) radius:2.0];
                [path closePath];
                [path appendBezierPathWithOvalInRect:NSMakeRect(6.0, 5.0, 6.0, 6.0)];
                [path appendBezierPathWithOvalInRect:NSMakeRect(7.5, 6.5, 3.0, 3.0)];
                [path setWindingRule:NSEvenOddWindingRule];
                [path fill];

            }];
            hotspot = NSMakePoint(9.0, 7.0);
            
        } else if ([name isEqualToString:@"openHandBarCursor"]) {
            
            image = [[NSImage alloc] initPDFWithSize:NSMakeSize(32.0, 32.0) drawingHandler:^(NSRect dstRect){
                [cursorOutline setFill];
                [NSGraphicsContext saveGraphicsState];
                [NSShadow setShadowWithWhite:0.0 alpha:0.33333 blurRadius:1.0 yOffset:-1.0];
                [NSBezierPath fillRect:NSMakeRect(1.0, 13.0, 30.0, 6.0)];
                [NSGraphicsContext restoreGraphicsState];
                [cursorFill setFill];
                [NSBezierPath fillRect:NSMakeRect(2.0, 14.0, 28.0, 4.0)];
                NSBezierPath *path = [NSBezierPath openHandBezierPath];
                [NSGraphicsContext saveGraphicsState];
                [(customizedColors ? cursorFill : cursorOutline) setFill];
                [NSShadow setShadowWithWhite:0.0 alpha:0.5 blurRadius:1.0 yOffset:-1.4];
                [path fill];
                [NSGraphicsContext restoreGraphicsState];
                [path moveToPoint:NSMakePoint(19.5664, 11.2656)];
                [path lineToPoint:NSMakePoint(19.5664, 14.7246)];
                [path moveToPoint:NSMakePoint(17.5508, 11.2539)];
                [path lineToPoint:NSMakePoint(17.5348, 14.727)];
                [path moveToPoint:NSMakePoint(15.5547, 14.6953)];
                [path lineToPoint:NSMakePoint(15.5758, 11.2691)];
                [(customizedColors ? cursorOutline : cursorFill) setStroke];
                [path setLineWidth:0.75];
                [path stroke];
            }];
            hotspot = NSMakePoint(16.0, 16.0);
            
        } else if ([name isEqualToString:@"closedHandBarCursor"]) {
            
            image = [[NSImage alloc] initPDFWithSize:NSMakeSize(32.0, 32.0) drawingHandler:^(NSRect dstRect){
                [cursorOutline setFill];
                [NSGraphicsContext saveGraphicsState];
                [NSShadow setShadowWithWhite:0.0 alpha:0.33333 blurRadius:1.0 yOffset:-1.0];
                [NSBezierPath fillRect:NSMakeRect(1.0, 13.0, 30.0, 6.0)];
                [NSGraphicsContext restoreGraphicsState];
                [cursorFill setFill];
                [NSBezierPath fillRect:NSMakeRect(2.0, 14.0, 28.0, 4.0)];
                NSBezierPath *path = [NSBezierPath closedHandBezierPath];
                [NSGraphicsContext saveGraphicsState];
                [(customizedColors ? cursorFill : cursorOutline) setFill];
                [NSShadow setShadowWithWhite:0.0 alpha:0.5 blurRadius:1.0 yOffset:-1.4];
                [path fill];
                [NSGraphicsContext restoreGraphicsState];
                [path moveToPoint:NSMakePoint(19.5664, 11.2656)];
                [path lineToPoint:NSMakePoint(19.5664, 14.7246)];
                [path moveToPoint:NSMakePoint(17.5508, 11.2539)];
                [path lineToPoint:NSMakePoint(17.5348, 14.727)];
                [path moveToPoint:NSMakePoint(15.5547, 14.6953)];
                [path lineToPoint:NSMakePoint(15.5758, 11.2691)];
                [(customizedColors ? cursorOutline : cursorFill) setStroke];
                [path setLineWidth:0.75];
                [path stroke];
            }];
            hotspot = NSMakePoint(16.0, 16.0);
            
        } else if ([name isEqualToString:@"textNoteCursor"]) {
            
            image = [NSImage cursorTextNoteImageWithOutlineColor:cursorOutline fillColor:cursorFill];
            hotspot = NSMakePoint(4.0, 4.0);
            
        } else if ([name isEqualToString:@"anchoredNoteCursor"]) {
            
            image = [NSImage cursorAnchoredNoteImageWithOutlineColor:cursorOutline fillColor:cursorFill];
            hotspot = NSMakePoint(4.0, 4.0);
            
        } else if ([name isEqualToString:@"circleNoteCursor"]) {
            
            image = [NSImage cursorCircleNoteImageWithOutlineColor:cursorOutline fillColor:cursorFill];
            hotspot = NSMakePoint(4.0, 4.0);
            
        } else if ([name isEqualToString:@"squareNoteCursor"]) {
            
            image = [NSImage cursorSquareNoteImageWithOutlineColor:cursorOutline fillColor:cursorFill];
            hotspot = NSMakePoint(4.0, 4.0);
            
        } else if ([name isEqualToString:@"highlightNoteCursor"]) {
            
            image = [NSImage cursorHighlightNoteImageWithOutlineColor:cursorOutline fillColor:cursorFill];
            hotspot = NSMakePoint(4.0, 4.0);
            
        } else if ([name isEqualToString:@"underlineNoteCursor"]) {
            
            image = [NSImage cursorUnderlineNoteImageWithOutlineColor:cursorOutline fillColor:cursorFill];
            hotspot = NSMakePoint(4.0, 4.0);
            
        } else if ([name isEqualToString:@"strikeOutNoteCursor"]) {
            
            image = [NSImage cursorStrikeOutNoteImageWithOutlineColor:cursorOutline fillColor:cursorFill];
            hotspot = NSMakePoint(4.0, 4.0);
            
        } else if ([name isEqualToString:@"lineNoteCursor"]) {
            
            image = [NSImage cursorLineNoteImageWithOutlineColor:cursorOutline fillColor:cursorFill];
            hotspot = NSMakePoint(4.0, 4.0);
            
        } else if ([name isEqualToString:@"inkNoteCursor"]) {
            
            image = [NSImage cursorInkNoteImageWithOutlineColor:cursorOutline fillColor:cursorFill];
            hotspot = NSMakePoint(4.0, 4.0);
            
        }
            
        cursor = [[NSCursor alloc] initWithImage:image hotSpot:hotspot];
        [customCursors setObject:cursor forKey:name];
    }
    
    return cursor ?: [NSCursor arrowCursor];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &SKUniversalAccessDefaultsObservationContext) {
        customCursors = nil;
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
