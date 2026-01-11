//
//  PDFAnnotationLine_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 4/1/08.
/*
 This software is Copyright (c) 2008
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

#import "PDFAnnotationLine_SKExtensions.h"
#import <SkimNotes/SkimNotes.h>
#import "PDFAnnotation_SKExtensions.h"
#import "SKStringConstants.h"
#import "SKFDFParser.h"
#import "NSUserDefaults_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSData_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "SKRuntime.h"
#import "NSBezierPath_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "PDFView_SKExtensions.h"

NSString * const SKPDFAnnotationStartPointAsQDPointKey = @"startPointAsQDPoint";
NSString * const SKPDFAnnotationEndPointAsQDPointKey = @"endPointAsQDPoint";
NSString * const SKPDFAnnotationScriptingStartLineStyleKey = @"scriptingStartLineStyle";
NSString * const SKPDFAnnotationScriptingEndLineStyleKey = @"scriptingEndLineStyle";

@implementation PDFAnnotationLine (SKExtensions)

static void (*original_setBounds)(id, SEL, NSRect) = NULL;

static void replacement_setBounds(id self, SEL _cmd , NSRect newBounds) {
    NSArray *points = [self valueForAnnotationKey:@"/L"];
    if ([points isKindOfClass:[NSArray class]] && [points count] == 4) {
        NSPoint d = SKSubstractPoints(newBounds.origin, [self bounds].origin);
        if (NSEqualPoints(d, NSZeroPoint))
            points = nil;
        else
            points = @[@([points[0] doubleValue] + d.x), @([points[1] doubleValue] + d.y), @([points[2] doubleValue] + d.x), @([points[3] doubleValue] + d.y)];
    } else if (points) {
        points = nil;
    }
    original_setBounds(self, _cmd, newBounds);
    if (points)
        [self setValue:points forAnnotationKey:@"/L"];
}

+ (void)load {
    if (@available(macOS 10.14, *)) {} else {
        original_setBounds = (void (*)(id, SEL, NSRect))SKReplaceInstanceMethodImplementation(self, @selector(setBounds:), (IMP)replacement_setBounds);
    }
}

- (void)setDefaultSkimNoteProperties {
    NSRect bounds = [self bounds];
    [self setColor:[[NSUserDefaults standardUserDefaults] colorForKey:SKLineNoteColorKey]];
    NSColor *color = [[NSUserDefaults standardUserDefaults] colorForKey:SKLineNoteInteriorColorKey];
    if ([color alphaComponent] > 0.0)
        [self setInteriorColor:color];
    [self setStartLineStyle:[[NSUserDefaults standardUserDefaults] integerForKey:SKLineNoteStartLineStyleKey]];
    [self setEndLineStyle:[[NSUserDefaults standardUserDefaults] integerForKey:SKLineNoteEndLineStyleKey]];
    [self setStartPoint:NSMakePoint(0.0, 0.0)];
    [self setEndPoint:NSMakePoint(NSWidth(bounds), NSHeight(bounds))];
    PDFBorder *border = [[PDFBorder alloc] init];
    [border setLineWidth:[[NSUserDefaults standardUserDefaults] floatForKey:SKLineNoteLineWidthKey]];
    [border setDashPattern:[[NSUserDefaults standardUserDefaults] arrayForKey:SKLineNoteDashPatternKey]];
    [border setStyle:[[NSUserDefaults standardUserDefaults] floatForKey:SKLineNoteLineStyleKey]];
    [self setBorder:[border lineWidth] > 0.0 ? border : nil];
}

- (NSString *)fdfString {
    NSMutableString *fdfString = [[super fdfString] mutableCopy];
    [fdfString appendFDFName:SKFDFAnnotationLineStylesKey];
    [fdfString appendString:@"["];
    [fdfString appendFDFName:SKFDFLineStyleFromPDFLineStyle([self startLineStyle])];
    [fdfString appendFDFName:SKFDFLineStyleFromPDFLineStyle([self endLineStyle])];
    [fdfString appendString:@"]"];
    NSPoint startPoint = SKAddPoints([self startPoint], [self bounds].origin);
    NSPoint endPoint = SKAddPoints([self endPoint], [self bounds].origin);
    [fdfString appendFDFName:SKFDFAnnotationLinePointsKey];
    [fdfString appendFormat:@"[%f %f %f %f]", startPoint.x, startPoint.y, endPoint.x, endPoint.y];
    CGFloat r, g, b, a = 0.0;
    [[self interiorColor] getRed:&r green:&g blue:&b alpha:&a];
    if (a > 0.0) {
        [fdfString appendFDFName:SKFDFAnnotationInteriorColorKey];
        [fdfString appendFormat:@"[%f %f %f]", r, g, b];
    }
    return fdfString;
}

- (BOOL)isLine { return YES; }

- (BOOL)isWidget { return NO; }

- (BOOL)isLnk { return NO; }

- (BOOL)isResizable { return [self isSkimNote]; }

- (BOOL)isMovable { return [self isSkimNote]; }

- (BOOL)hasInteriorColor { return [self isSkimNote]; }

- (BOOL)isConvertibleAnnotation { return YES; }

- (BOOL)hitTest:(NSPoint)point {
    if ([self shouldDisplay] == NO || [self isSkimNote] == NO)
        return NO;
    CGFloat delta = fmax(4.0, 0.5 * [self lineWidth]);
    return SKPointNearLineFromPointToPoint(SKSubstractPoints(point, [self bounds].origin), [self startPoint], [self endPoint], delta);
}

- (CGFloat)boundsOrder {
    CGFloat delta = ceil(fmax(4.0 * [self lineWidth], 4.0));
    NSPoint origin = [self bounds].origin;
    NSRect startBounds = SKRectFromCenterAndSquareSize(SKAddPoints(origin, [self startPoint]), delta);
    NSRect endBounds = SKRectFromCenterAndSquareSize(SKAddPoints(origin, [self endPoint]), delta);
    PDFPage *page = [self page];
    return fmin([page sortOrderForBounds:startBounds], [page sortOrderForBounds:endBounds]);
}

- (SKRectEdges)resizeHandleForPoint:(NSPoint)point scaleFactor:(CGFloat)scaleFactor {
    if ([self isResizable] == NO)
        return SKRectEdgesNone;
    NSSize size = SKMakeSquareSize(8.0 / scaleFactor);
    point = SKSubstractPoints(point, [self bounds].origin);
    if (NSPointInRect(point, SKRectFromCenterAndSize([self endPoint], size)))
        return SKRectEdgesMaxX;
    else if (NSPointInRect(point, SKRectFromCenterAndSize([self startPoint], size)))
        return SKRectEdgesMinX;
    else
        return SKRectEdgesNone;
}

- (void)drawSelectionHighlightWithUnitWidth:(CGFloat)unitWidth active:(BOOL)active inContext:(CGContextRef)context {
    if (NSIsEmptyRect([self bounds]))
        return;
    NSPoint origin = [self bounds].origin;
    SKDrawResizeHandlePair(context, SKAddPoints(origin, [self startPoint]), SKAddPoints(origin, [self endPoint]), unitWidth, active);
}

- (NSString *)colorDefaultKey { return SKLineNoteColorKey; }

- (NSString *)lineWidthDefaultKey { return SKLineNoteLineWidthKey; }

- (NSString *)borderStyleDefaultKey { return SKLineNoteLineStyleKey; }

- (NSString *)dashPatternDefaultKey { return SKLineNoteDashPatternKey; }

- (PDFLineStyle)startLineStyleDefaultKey { return SKLineNoteStartLineStyleKey; }

- (PDFLineStyle)endLineStyleDefaultKey { return SKLineNoteEndLineStyleKey; }

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *lineKeys = nil;
    if (lineKeys == nil) {
        NSMutableSet *mutableKeys = [[super keysForValuesToObserveForUndo] mutableCopy];
        [mutableKeys addObject:SKNPDFAnnotationStartLineStyleKey];
        [mutableKeys addObject:SKNPDFAnnotationEndLineStyleKey];
        [mutableKeys addObject:SKNPDFAnnotationStartPointKey];
        [mutableKeys addObject:SKNPDFAnnotationEndPointKey];
        [mutableKeys addObject:SKNPDFAnnotationInteriorColorKey];
        lineKeys = [mutableKeys copy];
    }
    return lineKeys;
}

#pragma mark Scripting support

+ (NSSet *)customScriptingKeys {
    static NSSet *customLineScriptingKeys = nil;
    if (customLineScriptingKeys == nil) {
        NSMutableSet *customKeys = [[super customScriptingKeys] mutableCopy];
        [customKeys addObject:SKPDFAnnotationStartPointAsQDPointKey];
        [customKeys addObject:SKPDFAnnotationEndPointAsQDPointKey];
        [customKeys addObject:SKPDFAnnotationScriptingStartLineStyleKey];
        [customKeys addObject:SKPDFAnnotationScriptingEndLineStyleKey];
        [customKeys addObject:SKPDFAnnotationScriptingInteriorColorKey];
        customLineScriptingKeys = [customKeys copy];
    }
    return customLineScriptingKeys;
}

- (void)setStartPointAsQDPoint:(NSData *)inQDPointAsData {
    if ([self isEditable] && inQDPointAsData && [inQDPointAsData isEqual:[NSNull null]] == NO) {
        NSPoint startPoint = [inQDPointAsData pointValueAsQDPoint];
        
        NSRect bounds = [self bounds];
        NSPoint endPoint = SKIntegralPoint(SKAddPoints([self endPoint], bounds.origin));
        
        bounds = SKIntegralRectFromPoints(startPoint, endPoint);
        
        if (NSWidth(bounds) < 8.0) {
            bounds.size.width = 8.0;
            bounds.origin.x = floor(0.5 * (startPoint.x + endPoint.x) - 4.0);
        }
        if (NSHeight(bounds) < 8.0) {
            bounds.size.height = 8.0;
            bounds.origin.y = floor(0.5 * (startPoint.y + endPoint.y) - 4.0);
        }
        
        startPoint = SKSubstractPoints(startPoint, bounds.origin);
        endPoint = SKSubstractPoints(endPoint, bounds.origin);
        
        [self setBounds:bounds];
        [self setStartPoint:startPoint];
        [self setEndPoint:endPoint];
    }

}

- (NSData *)startPointAsQDPoint {
    NSRect bounds = [self bounds];
    NSPoint startPoint = SKAddPoints([self startPoint], bounds.origin);
    startPoint.x = floor(startPoint.x);
    startPoint.y = floor(startPoint.y);
    return [NSData dataWithPointAsQDPoint:startPoint];
}

- (void)setEndPointAsQDPoint:(NSData *)inQDPointAsData {
    if ([self isEditable] && inQDPointAsData && [inQDPointAsData isEqual:[NSNull null]] == NO) {
        NSPoint endPoint = [inQDPointAsData pointValueAsQDPoint];
        
        NSRect bounds = [self bounds];
        NSPoint startPoint = SKIntegralPoint(SKAddPoints([self startPoint], bounds.origin));
        
        bounds = SKIntegralRectFromPoints(startPoint, endPoint);
        
        if (NSWidth(bounds) < 8.0) {
            bounds.size.width = 8.0;
            bounds.origin.x = floor(0.5 * (startPoint.x + endPoint.x) - 4.0);
        }
        if (NSHeight(bounds) < 8.0) {
            bounds.size.height = 8.0;
            bounds.origin.y = floor(0.5 * (startPoint.y + endPoint.y) - 4.0);
        }
        
        startPoint = SKSubstractPoints(startPoint, bounds.origin);
        endPoint = SKSubstractPoints(endPoint, bounds.origin);
        
        [self setBounds:bounds];
        [self setStartPoint:startPoint];
        [self setEndPoint:endPoint];
    }

}

- (NSData *)endPointAsQDPoint {
    NSRect bounds = [self bounds];
    NSPoint endPoint = SKAddPoints([self endPoint], bounds.origin);
    endPoint.x = floor(endPoint.x);
    endPoint.y = floor(endPoint.y);
    return [NSData dataWithPointAsQDPoint:endPoint];
}

- (PDFLineStyle)scriptingStartLineStyle {
    return [self startLineStyle];
}

- (PDFLineStyle)scriptingEndLineStyle {
    return [self endLineStyle];
}

- (void)setScriptingStartLineStyle:(PDFLineStyle)style {
    if ([self isEditable]) {
        [self setStartLineStyle:style];
    }
}

- (void)setScriptingEndLineStyle:(PDFLineStyle)style {
    if ([self isEditable]) {
        [self setEndLineStyle:style];
    }
}

- (NSColor *)scriptingInteriorColor {
    return [self interiorColor];
}

- (void)setScriptingInteriorColor:(NSColor *)newColor {
    if ([self isEditable]) {
        [self setInteriorColor:newColor];
    }
}

@end
