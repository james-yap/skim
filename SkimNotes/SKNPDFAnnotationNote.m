//
//  SKNPDFAnnotationNote.m
//  SkimNotes
//
//  Created by Christiaan Hofman on 6/15/08.
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

#import "SKNPDFAnnotationNote.h"
#import "PDFAnnotation_SKNExtensions.h"

NSString * const SKNPDFAnnotationTextKey = @"text";
NSString * const SKNPDFAnnotationImageKey = @"image";
NSString * const SKNPDFAnnotationDrawsImageKey = @"drawsImage";

const PDFSize SKNPDFAnnotationNoteSize = {16.0, 16.0};

#if !defined(PDFKIT_PLATFORM_IOS)

#import <CoreGraphics/CoreGraphics.h>

#if !defined(MAC_OS_X_VERSION_10_15) || MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_15
static inline void drawIcon(CGContextRef context, NSRect bounds, PDFTextAnnotationIconType iconType);

#define SKNAppKitVersionNumber10_12 1504
#define SKNAppKitVersionNumber10_14 1671

#if !defined(MAC_OS_X_VERSION_10_12) || MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_12
@interface PDFAnnotation (SKNSierraDeclarations)
- (void)drawWithBox:(PDFDisplayBox)box inContext:(CGContextRef)context;
- (id)valueForAnnotationKey:(NSString *)key;
- (BOOL)setValue:(id)value forAnnotationKey:(NSString *)key;
@end
@interface PDFPage (SKNSierraDeclarations)
- (void)transformContext:(CGContextRef)context forBox:(PDFDisplayBox)box;
@end
#endif
#endif

@interface SKNPDFAnnotationNote ()
@property (nonatomic, readonly) NSTextStorage *mutableText;
@property (nonatomic, strong, nullable) NSArray *texts;
@end

#endif

@interface PDFAnnotation (SKNPrivateDeclarations)
- (NSMutableDictionary *)genericSkimNoteProperties;
@end

@implementation SKNPDFAnnotationNote

@synthesize string = _string;
@synthesize text = _text;
@synthesize image = _image;
@synthesize drawsImage = _drawsImage;
#if !defined(PDFKIT_PLATFORM_IOS)
@dynamic mutableText;
@synthesize texts = _texts;
#endif

- (void)updateContents {
    NSMutableString *contents = [NSMutableString string];
    if ([_string length])
        [contents appendString:_string];
    if ([_text length]) {
        [contents appendString:@"  "];
        [contents appendString:[_text string]];
    }
    [super setContents:contents];
}

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class attrStringClass = [NSAttributedString class];
        Class stringClass = [NSString class];
        Class imageClass = [PDFKitPlatformImage class];
        Class dataClass = [NSData class];
        NSString *aName = [dict objectForKey:SKNPDFAnnotationNameKey];
        NSAttributedString *aText = [dict objectForKey:SKNPDFAnnotationTextKey];
        PDFKitPlatformImage *anImage = [dict objectForKey:SKNPDFAnnotationImageKey];
        NSNumber *drawImage = [dict objectForKey:SKNPDFAnnotationDrawsImageKey];
        if ([aName isKindOfClass:stringClass] && [self respondsToSelector:@selector(setValue:forAnnotationKey:)])
            [self setValue:aName forAnnotationKey:@"/Name"];
        if ([drawImage respondsToSelector:@selector(boolValue)])
            [self setDrawsImage:[drawImage boolValue]];
        else
            [self setDrawsImage:[[dict objectForKey:SKNPDFAnnotationTypeKey] isEqualToString:SKNStampString]];
        if ([anImage isKindOfClass:imageClass])
            _image = anImage;
        else if ([anImage isKindOfClass:dataClass])
            _image = [[PDFKitPlatformImage alloc] initWithData:(NSData *)anImage];
        if ([aText isKindOfClass:stringClass])
            aText = [[NSAttributedString alloc] initWithString:(NSString *)aText];
        else if ([aText isKindOfClass:dataClass])
            aText = [[NSAttributedString alloc] initWithData:(NSData *)aText options:[NSDictionary dictionary] documentAttributes:NULL error:NULL];
        if ([aText isKindOfClass:attrStringClass])
            [self setText:aText];
        [self updateContents];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties{
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    [dict setValue:[NSNumber numberWithInteger:[self iconType]] forKey:SKNPDFAnnotationIconTypeKey];
    if ([self drawsImage]) {
        [dict setValue:[NSNumber numberWithBool:YES] forKey:SKNPDFAnnotationDrawsImageKey];
        if ([self respondsToSelector:@selector(valueForAnnotationKey:)]) {
            NSString *name = [self valueForAnnotationKey:@"/Name"];
            if (name && [[NSSet setWithObjects:@"/Comment", @"/Key", @"/Note", @"/Help", @"/NewParagraph", @"/Paragraph", @"/Insert", nil] containsObject:name] == NO)
                [dict setValue:name forKey:SKNPDFAnnotationNameKey];
        }
    }
    [dict setValue:[self text] forKey:SKNPDFAnnotationTextKey];
    [dict setValue:[self image] forKey:SKNPDFAnnotationImageKey];
    return dict;
}

- (NSString *)type {
    return SKNNoteString;
}

- (void)setDrawsImage:(BOOL)drawsImage {
    _drawsImage = drawsImage;
    if ([self respondsToSelector:@selector(setValue:forAnnotationKey:)])
        [self setValue:drawsImage ? @"/Stamp" : @"/Text" forAnnotationKey:@"/Subtype"];
}

- (void)setString:(NSString *)string {
    if (_string != string) {
        _string = [string copy];
        // update the contents to string + text
        [self updateContents];
    }
}

#if defined(PDFKIT_PLATFORM_IOS)

- (void)setText:(NSAttributedString *)text {
    if (_text != text) {
        _text = [text copy];
        // update the contents to string + text
        [self updateContents];
    }
}

- (void)drawWithBox:(PDFDisplayBox)box inContext:(CGContextRef)context {
    if ([self drawsImage] && [self hasAppearanceStream] == NO && [self image] != nil) {
        NSRect bounds = [self bounds];
        CGContextSaveGState(context);
        [[self page] transformContext:context forBox:box];
        UIGraphicsPushContext(context);
        CGContextTranslateCTM(context, CGRectGetMinX(bounds), CGRectGetMaxY(bounds));
        CGContextScaleCTM(context, 1.0, -1.0);
        bounds.origin = CGPointZero;
        [[self image] drawInRect:bounds];
        UIGraphicsPopContext(context);
        CGContextRestoreGState(context);
    } else {
        [super drawWithBox:box inContext:context];
    }
}

#else

- (void)setText:(NSAttributedString *)text {
    if ([self mutableText] != text) {
        // edit the textStorage, this will trigger KVO and update the text automatically
        if (text)
            [_textStorage replaceCharactersInRange:NSMakeRange(0, [_textStorage length]) withAttributedString:text];
        else
            [_textStorage deleteCharactersInRange:NSMakeRange(0, [_textStorage length])];
    }
}

// changes to text are made through textStorage, this allows Skim to provide edits through AppleScript, which works directly on the textStorage
// KVO is triggered manually when the textStorage is edited, either through setText: or through some other means, e.g. through AppleScript
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    if ([key isEqualToString:SKNPDFAnnotationTextKey])
        return NO;
    else
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [super automaticallyNotifiesObserversForKey:key];
#pragma clang diagnostic pop
}

- (void)textDidChange:(NSNotification *)notification {
    // texts should be an array of objects wrapping the text of the note, used by Skim to provide a data source for the children in the outlineView
    [_texts makeObjectsPerformSelector:@selector(willChangeValueForKey:) withObject:SKNPDFAnnotationTextKey];
    // trigger KVO manually
    [self willChangeValueForKey:SKNPDFAnnotationTextKey];
    // update the text
    _text = [[NSAttributedString alloc] initWithAttributedString:_textStorage];
    [self didChangeValueForKey:SKNPDFAnnotationTextKey];
    [_texts makeObjectsPerformSelector:@selector(didChangeValueForKey:) withObject:SKNPDFAnnotationTextKey];
    // update the contents to string + text
    [self updateContents];
}

- (NSTextStorage *)mutableText {
    if (_textStorage == nil) {
        _textStorage = [[NSTextStorage alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:NSTextStorageDidProcessEditingNotification object:_textStorage];
    }
    return _textStorage;
}

- (void)drawWithBox:(PDFDisplayBox)box inContext:(CGContextRef)context {
    if ([self drawsImage] && [self hasAppearanceStream] == NO && [self image] != nil) {
        CGContextSaveGState(context);
        [[self page] transformContext:context forBox:box];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:context flipped:NO]];
        [[self image] drawInRect:[self bounds]];
        [NSGraphicsContext restoreGraphicsState];
        CGContextRestoreGState(context);
#if !defined(MAC_OS_X_VERSION_10_15) || MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_15
    } else if ([self hasAppearanceStream] == NO && floor(NSAppKitVersionNumber) <= SKNAppKitVersionNumber10_14 && floor(NSAppKitVersionNumber) >= SKNAppKitVersionNumber10_12) {
        // on 10.12 through 10.14 draws based on the type rather than the /Subtype
        // as PDFKit does not know type Note we need to draw ourselves
        // type Text does just draws a dumb filled square anyway
        NSRect bounds = [self bounds];
        CGContextSaveGState(context);
        [[self page] transformContext:context forBox:box];
        if (NSWidth(bounds) > 2.0 && NSHeight(bounds) > 2.0) {
            CGContextSetFillColorWithColor(context, [[self color] CGColor]);
            CGContextSetStrokeColorWithColor(context, CGColorGetConstantColor(kCGColorBlack));
            drawIcon(context, bounds, [self iconType]);
        } else {
            CGContextSetFillColorWithColor(context, CGColorGetConstantColor(kCGColorBlack));
            CGContextFillRect(context, NSRectToCGRect(bounds));
        }
        CGContextRestoreGState(context);
#endif
    } else {
        [super drawWithBox:box inContext:context];
    }
}

#if !defined(MAC_OS_X_VERSION_10_12) || MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_12

- (void)drawWithBox:(PDFDisplayBox)box {
    if ([self drawsImage] && [self hasAppearanceStream] == NO && [self image] != nil) {
        [NSGraphicsContext saveGraphicsState];
        [[self page] transformContextForBox:box];
        [[self image] drawInRect:[self bounds]];
        [NSGraphicsContext restoreGraphicsState];
    } else {
        [super drawWithBox:box];
    }
}

#endif

#endif

@end

#if !defined(PDFKIT_PLATFORM_IOS) && (!defined(MAC_OS_X_VERSION_10_15) || MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_15)

#define KAPPA   0.552284749830793398402251632279597438
#define KAPPA2  0.265216489839544009215463496859568305

static inline void drawIconComment(CGContextRef context, NSRect bounds) {
    bounds = NSInsetRect(bounds, 0.5, 0.5);
    CGFloat x = NSMinX(bounds), y = NSMinY(bounds), w = NSWidth(bounds), h = NSHeight(bounds);
    CGContextMoveToPoint(context, x + 0.3 * w, y + 0.3 * h - 0.5);
    CGContextAddLineToPoint(context, x + 0.1 * w, y + 0.3 * h - 0.5);
    CGContextAddCurveToPoint(context, x + (0.1 - 0.1 * KAPPA) * w, y + 0.3 * h - 0.5, x, y + (0.4 - 0.1 * KAPPA) * h - 0.5, x, y + 0.4 * h - 0.5);
    CGContextAddLineToPoint(context, x, y + 0.9 * h);
    CGContextAddCurveToPoint(context, x, y + (0.9 + 0.1 * KAPPA) * h, x + (0.1 - 0.1 * KAPPA) * w, y + h, x + 0.1 * w, y + h);
    CGContextAddLineToPoint(context, x + 0.9 * w, y + h);
    CGContextAddCurveToPoint(context, x + (0.9 + 0.1 * KAPPA) * w, y + h, x + w, y + (0.9 + 0.1 * KAPPA) * h, x + w, y + 0.9 * h);
    CGContextAddLineToPoint(context, x + w, y + 0.4 * h - 0.5);
    CGContextAddCurveToPoint(context, x + w, y + (0.4 - 0.1 * KAPPA) * h - 0.5, x + (0.9 + 0.1 * KAPPA) * w, y + 0.3 * h - 0.5, x + 0.9 * w, y + 0.3 * h - 0.5);
    CGContextAddLineToPoint(context, x + 0.5 * w, y + 0.3 * h - 0.5);
    CGContextAddLineToPoint(context, x + 0.25 * w, y);
    CGContextClosePath(context);
    CGContextDrawPath(context, kCGPathFillStroke);
    x += 0.5; y += 0.5; w -= 1.0; h -= 1.0;
    CGPoint points3[6] = {{x + 0.1 * w, y + 0.85 * h},
        {x + 0.9 * w, y + 0.85 * h},
        {x + 0.1 * w, y + 0.65 * h},
        {x + 0.9 * w, y + 0.65 * h},
        {x + 0.1 * w, y + 0.45 * h},
        {x + 0.7 * w, y + 0.45 * h}};
    CGContextSetLineWidth(context, 0.1 * h);
    CGContextStrokeLineSegments(context, points3, 6);
}

static inline void drawIconKey(CGContextRef context, NSRect bounds) {
    bounds = NSInsetRect(bounds, 0.5, 0.5);
    CGFloat x = NSMinX(bounds), y = NSMinY(bounds), w = NSWidth(bounds), h = NSHeight(bounds);
    CGPoint points[9] = {{x + 0.55 * w, y + 0.65 * h},
        {x + w, y + 0.15 * h},
        {x + w, y},
        {x + 0.7 * w, y},
        {x + 0.7 * w, y + 0.15 * h},
        {x + 0.55 * w, y + 0.15 * h},
        {x + 0.55 * w, y + 0.3 * h},
        {x + 0.4 * w, y + 0.3 * h},
        {x + 0.4 * w, y + 0.45 * h}};
    CGContextAddLines(context, points, 9);
    CGContextAddLineToPoint(context, x + 0.1 * w, y + 0.45 * h);
    CGContextAddCurveToPoint(context, x + (0.1 - 0.1 * KAPPA) * w, y + 0.45 * h, x, y + (0.55 - 0.1 * KAPPA) * h, x, y + 0.55 * h);
    CGContextAddLineToPoint(context, x, y + 0.8 * h);
    CGContextAddCurveToPoint(context, x, y + (0.8 + 0.2 * KAPPA) * h, x + (0.2 - 0.2 * KAPPA) * w, y + h, x + 0.2 * w, y + h);
    CGContextAddLineToPoint(context, x + 0.45 * w, y + h);
    CGContextAddCurveToPoint(context, x + (0.45 + 0.1 * KAPPA) * w, y + h, x + 0.55 * w, y + (0.9 + 0.1 * KAPPA) * h, x + 0.55 * w, y + 0.9 * h);
    CGContextClosePath(context);
    CGContextAddEllipseInRect(context, CGRectMake(x + 0.1 * w, y + h - 0.3 * h, 0.2 * w, 0.2 * h));
    CGContextDrawPath(context, kCGPathEOFillStroke);
}

static inline void drawIconNote(CGContextRef context, NSRect bounds) {
    bounds = NSInsetRect(bounds, 0.075 * NSWidth(bounds) + 0.5, 0.5);
    CGFloat x = NSMinX(bounds), y = NSMinY(bounds), w = NSWidth(bounds), h = NSHeight(bounds);
    CGPoint points1[5] = {{x, y},
        {x, y + h},
        {x + w, y + h},
        {x + w, y + 0.25 * h},
        {x + 0.75 * w, y}};
    CGPoint points2[3] = {{x + 0.75 * w, y},
        {x + 0.75 * w, y + 0.25 * h},
        {x + w, y + 0.25 * h}};
    CGContextAddLines(context, points1, 5);
    CGContextClosePath(context);
    CGContextAddLines(context, points2, 3);
    CGContextDrawPath(context, kCGPathFillStroke);
    x += 0.5; y += 0.5; w -= 1.0; h -= 1.0;
    CGPoint points3[6] = {{x + 0.1 * w, y + 0.85 * h},
        {x + 0.9 * w, y + 0.85 * h},
        {x + 0.1 * w, y + 0.65 * h},
        {x + 0.9 * w, y + 0.65 * h},
        {x + 0.1 * w, y + 0.45 * h},
        {x + 0.7 * w, y + 0.45 * h}};
    CGContextSetLineWidth(context, 0.1 * h);
    CGContextStrokeLineSegments(context, points3, 6);
}

static inline void drawIconHelp(CGContextRef context, NSRect bounds) {
    bounds = NSInsetRect(bounds, 0.5, 0.5);
    CGFloat x = NSMinX(bounds), y = NSMinY(bounds), w = NSWidth(bounds), h = NSHeight(bounds);
    CGContextMoveToPoint(context, x + 0.275 * w, y + 0.65 * h);
    CGContextAddCurveToPoint(context, x + 0.275 * w, y + (0.65 + 0.225 * KAPPA) * h, x + (0.5 - 0.225 * KAPPA) * w, y + 0.875 * h, x + 0.5 * w, y + 0.875 * h);
    CGContextAddCurveToPoint(context, x + (0.5 + 0.225 * KAPPA) * w, y + 0.875 * h, x + 0.725 * w, y + (0.65 + 0.225 * KAPPA) * h, x + 0.725 * w, y + 0.65 * h);
    CGContextAddCurveToPoint(context, x + 0.725 * w, y + (0.65 - 0.225 * KAPPA2) * h, x + (0.5 + 0.225 * M_SQRT1_2 + 0.225 * M_SQRT1_2 * KAPPA2) * w, y + (0.65 - 0.225 * M_SQRT1_2 + 0.225 * M_SQRT1_2 * KAPPA2) * h, x + (0.5 + 0.225 * M_SQRT1_2) * w, y + (0.65 - 0.225 * M_SQRT1_2) * h);
    CGContextAddLineToPoint(context, x + (0.675 - 0.125 * M_SQRT1_2) * w, y + (0.825 - 0.575 * M_SQRT1_2) * h);
    CGContextAddCurveToPoint(context, x + (0.675 - 0.125 * M_SQRT1_2 - 0.125 * M_SQRT1_2 * KAPPA2) * w, y + (0.825 - 0.575 * M_SQRT1_2 - 0.125 * M_SQRT1_2 * KAPPA2) * h, x + 0.55 * w, y + (0.825 - 0.7 * M_SQRT1_2 + 0.125 * KAPPA2) * h, x + 0.55 * w, y + (0.825 - 0.7 * M_SQRT1_2) * h);
    CGContextAddLineToPoint(context, x + 0.45 * w, y + (0.825 - 0.7 * M_SQRT1_2) * h);
    CGContextAddCurveToPoint(context, x + 0.45 * w, y + (0.825 - 0.7 * M_SQRT1_2 + 0.225 * KAPPA2) * h, x + (0.675 - 0.225 * M_SQRT1_2 - 0.225 * M_SQRT1_2 * KAPPA2) * w, y + (0.825 - 0.475 * M_SQRT1_2 - 0.225 * M_SQRT1_2 * KAPPA2) * h, x + (0.675 - 0.225 * M_SQRT1_2) * w, y + (0.825 - 0.475 * M_SQRT1_2) * h);
    CGContextAddLineToPoint(context, x + (0.5 + 0.125 * M_SQRT1_2) * w, y + (0.65 - 0.125 * M_SQRT1_2) * h);
    CGContextAddCurveToPoint(context,x + (0.5 + 0.125 * M_SQRT1_2 + 0.125 * M_SQRT1_2 * KAPPA2) * w, y + (0.65 - 0.125 * M_SQRT1_2 + 0.125 * M_SQRT1_2 * KAPPA2) * h, x + 0.625 * w, y + (0.65 - 0.125 * KAPPA2) * h, x + 0.625 * w, y + 0.65 * h);
    CGContextAddCurveToPoint(context, x + 0.625 * w, y + (0.65 + 0.125 * KAPPA) * h, x + (0.5 + 0.125 * KAPPA) * w, y + 0.775 * h, x + 0.5 * w, y + 0.775 * h);
    CGContextAddCurveToPoint(context, x + (0.5 - 0.125 * KAPPA) * w, y + 0.775 * h, x + 0.375 * w, y + (0.65 + 0.125 * KAPPA) * h, x + 0.375 * w, y + 0.65 * h);
    CGContextClosePath(context);
    CGContextAddEllipseInRect(context, CGRectMake(x + 0.425 * w, y + 0.1 * h, 0.15 * w, 0.15 * h));
    CGContextAddEllipseInRect(context, NSRectToCGRect(bounds));
    CGContextClosePath(context);
    CGContextDrawPath(context, kCGPathEOFillStroke);
}

static inline void drawIconNewParagraph(CGContextRef context, NSRect bounds) {
    bounds = NSInsetRect(bounds, 0.075 * NSWidth(bounds) + 0.5, 0.5);
    CGFloat x = NSMinX(bounds), y = NSMinY(bounds), w = NSWidth(bounds), h = NSHeight(bounds);
    CGPoint points1[3] = {{x + 0.1 * w, y + 0.5 * h},
        {x + 0.5 * w, y + h},
        {x + 0.9 * w, y + 0.5 * h}};
    CGContextAddLines(context, points1, 3);
    CGContextClosePath(context);
    CGContextDrawPath(context, kCGPathFillStroke);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGPoint points2[4] = {{x + 0.1 * w, y},
        {x + 0.1 * w, y + 0.4 * h},
        {x + 0.4 * w, y},
        {x + 0.4 * w, y + 0.4 * h}};
    CGContextAddLines(context, points2, 4);
    CGContextMoveToPoint(context, x + 0.6 * w, y);
    CGContextAddLineToPoint(context, x + 0.6 * w, y + 0.4 * h);
    CGContextAddLineToPoint(context, x + 0.8 * w, y + 0.4 * h);
    CGContextAddCurveToPoint(context, x + (0.8 + 0.1 * KAPPA) * w, y + 0.4 * h, x + 0.9 * w, y + (0.3 + 0.1 * KAPPA) * h, x + 0.9 * w, y + 0.3 * h);
    CGContextAddCurveToPoint(context, x + 0.9 * w, y + (0.3 - 0.1 * KAPPA) * h, x + (0.8 + 0.1 * KAPPA) * w, y + 0.2 * h, x + 0.8 * w, y + 0.2 * h);
    CGContextAddLineToPoint(context, x + 0.6 * w, y + 0.2 * h);
    CGContextStrokePath(context);
}

static inline void drawIconParagraph(CGContextRef context, NSRect bounds) {
    bounds = NSInsetRect(bounds, 0.075 * NSWidth(bounds) + 0.5, 0.5);
    CGFloat x = NSMinX(bounds), y = NSMinY(bounds), w = NSWidth(bounds), h = NSHeight(bounds);
    CGPoint points[8] = {{x + 0.9 * w, y + h},
        {x + 0.9 * w, y},
        {x + 0.76 * w, y},
        {x + 0.76 * w, y + 0.8 * h},
        {x + 0.63 * w, y + 0.8 * h},
        {x + 0.63 * w, y},
        {x + 0.5 * w, y},
        {x + 0.5 * w, y + 0.5 * h}};
    CGContextAddLines(context, points, 8);
    CGContextAddLineToPoint(context, x + 0.35 * w, y + 0.5 * h);
    CGContextAddCurveToPoint(context, x + (0.35 - 0.25 * KAPPA) * w, y + 0.5 * h, x + 0.1 * w, y + (0.75 - 0.25 * KAPPA) * h, x + 0.1 * w, y + 0.75 * h);
    CGContextAddCurveToPoint(context, x + 0.1 * w, y + (0.75 + 0.25 * KAPPA) * h, x + (0.35 - 0.25 * KAPPA) * w, y + h, x + 0.35 * w, y + h);
    CGContextClosePath(context);
    CGContextDrawPath(context, kCGPathFillStroke);
}

static inline void drawIconInsert(CGContextRef context, NSRect bounds) {
    bounds = NSInsetRect(bounds, 0.5, 0.5);
    CGFloat x = NSMinX(bounds), y = NSMinY(bounds), w = NSWidth(bounds), h = NSHeight(bounds);
    CGContextMoveToPoint(context, x, y);
    CGContextAddLineToPoint(context, x + 0.5 * w, y + h);
    CGContextAddLineToPoint(context, x + w, y);
    CGContextClosePath(context);
    CGContextDrawPath(context, kCGPathFillStroke);
}

static inline void drawIcon(CGContextRef context, NSRect bounds, PDFTextAnnotationIconType iconType) {
    CGContextSetLineWidth(context, 1.0);
    CGContextSetLineCap(context, kCGLineCapButt);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextClipToRect(context, NSRectToCGRect(bounds));
    switch (iconType) {
        case kPDFTextAnnotationIconComment:      drawIconComment(context, bounds);      break;
        case kPDFTextAnnotationIconKey:          drawIconKey(context, bounds);          break;
        case kPDFTextAnnotationIconNote:         drawIconNote(context, bounds);         break;
        case kPDFTextAnnotationIconHelp:         drawIconHelp(context, bounds);         break;
        case kPDFTextAnnotationIconNewParagraph: drawIconNewParagraph(context, bounds); break;
        case kPDFTextAnnotationIconParagraph:    drawIconParagraph(context, bounds);    break;
        case kPDFTextAnnotationIconInsert:       drawIconInsert(context, bounds);       break;
        default:                                 drawIconNote(context, bounds);         break;
    }
}

#endif
