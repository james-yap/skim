//
//  PDFAnnotation_SKExtensions.m
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

#import "PDFAnnotation_SKExtensions.h"
#import "SKNPDFAnnotationNote_SKExtensions.h"
#import "SKStringConstants.h"
#import "SKFDFParser.h"
#import "PDFPage_SKExtensions.h"
#import "PDFSelection_SKExtensions.h"
#import "SKPDFView.h"
#import "NSGraphics_SKExtensions.h"
#import "NSData_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "NSBezierPath_SKExtensions.h"
#import "SKVersionNumber.h"
#import "NSColor_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"
#import "SKMainDocument.h"
#import "NSView_SKExtensions.h"
#import "SKNoteText.h"
#import "PDFView_SKExtensions.h"
#import "NSDate_SKExtensions.h"
#import "NSPointerArray_SKExtensions.h"
#import "NSShadow_SKExtensions.h"
#import "NSCharacterSet_SKExtensions.h"
#import "SKRuntime.h"
#import <objc/runtime.h>

NSString * const SKPDFAnnotationBezierPathsKey = @"bezierPaths";

NSString * const SKPDFAnnotationScriptingColorKey = @"scriptingColor";
NSString * const SKPDFAnnotationScriptingModificationDateKey = @"scriptingModificationDate";
NSString * const SKPDFAnnotationScriptingUserNameKey = @"scriptingUserName";
NSString * const SKPDFAnnotationScriptingTextContentsKey = @"textContents";
NSString * const SKPDFAnnotationScriptingInteriorColorKey = @"scriptingInteriorColor";
NSString * const SKPDFAnnotationScriptingFontColorKey = @"scriptingFontColor";
NSString * const SKPDFAnnotationScriptingAlignmentKey = @"scriptingAlignment";
NSString * const SKPDFAnnotationStartPointAsQDPointKey = @"startPointAsQDPoint";
NSString * const SKPDFAnnotationEndPointAsQDPointKey = @"endPointAsQDPoint";
NSString * const SKPDFAnnotationScriptingStartLineStyleKey = @"scriptingStartLineStyle";
NSString * const SKPDFAnnotationScriptingEndLineStyleKey = @"scriptingEndLineStyle";
NSString * const SKPDFAnnotationScriptingPointListsKey = @"scriptingPointLists";
NSString * const SKPDFAnnotationSelectionSpecifierKey = @"selectionSpecifier";

NSString * const SKPDFAnnotationBoundsOrderKey = @"boundsOrder";

NSPasteboardType const SKPasteboardTypeSkimNote = @"net.sourceforge.skim-app.pasteboard.skimnote";

static char SKLineRectsKey;
static char SKTextStringKey;
static char SKNoteTextKey;

/*
 http://www.cocoabuilder.com/archive/message/cocoa/2007/2/16/178891
  The docs are wrong (as is Adobe's spec).  The ordering on the rotated page is:
 --------
 | 0  1 |
 | 2  3 |
 --------
 */
static NSArray *quadPointsForLineRects(NSPointerArray *lines, NSPoint origin, NSInteger lineDirection) {
    NSMutableArray *quadPoints = [[NSMutableArray alloc] init];
    NSUInteger i, iMax = [lines count];
    for (i = 0; i < iMax; i++) {
        NSInteger offset[4] = {0, 1, 3, 2};
        NSRect r = NSOffsetRect([lines rectAtIndex:i], -origin.x, -origin.y);
        NSInteger j = lineDirection;
        NSPoint p[4];
        memset(&p, 0, 4 * sizeof(NSPoint));
        p[offset[j]] = SKBottomLeftPoint(r);
        p[offset[++j%4]] = SKTopLeftPoint(r);
        p[offset[++j%4]] = SKTopRightPoint(r);
        p[offset[++j%4]] = SKBottomRightPoint(r);
        for (j = 0; j < 4; j++)
            [quadPoints addObject:[NSValue valueWithPoint:p[j]]];
    }
    return quadPoints;
}

static NSPointerArray *lineRectsForQuadPoints(NSArray *quadPoints, NSPoint origin) {
    NSPointerArray *lineRects = [[NSPointerArray alloc] initForRectPointers];
    NSUInteger j, jMax = [quadPoints count] / 4;
    NSRange range = NSMakeRange(0, 4);
    for (j = 0; j < jMax; j++) {
        range.location = 4 * j;
        NSPoint point;
        NSUInteger i;
        CGFloat minX = CGFLOAT_MAX, maxX = -CGFLOAT_MAX, minY = CGFLOAT_MAX, maxY = -CGFLOAT_MAX;
        for (i = 0; i < 4; i++) {
            point = [[quadPoints objectAtIndex:4 * j + i] pointValue];
            minX = fmin(minX, point.x);
            maxX = fmax(maxX, point.x);
            minY = fmin(minY, point.y);
            maxY = fmax(maxY, point.y);
        }
        NSRect lineRect = NSMakeRect(origin.x + minX, origin.y + minY, maxX - minX, maxY - minY);
        [lineRects addPointer:&lineRect];
    }
    return lineRects;
}

// NSTextAlignment enum values depend on the architecture, on arm64 right=2 and center=1
static inline NSTextAlignment textAlignmentFromAlignment(NSInteger alignment) {
    return alignment == 2 ? NSTextAlignmentCenter : alignment == 1 ? NSTextAlignmentRight : 0;
}

static inline NSInteger alignmentFromTextAlignment(NSTextAlignment alignment) {
    return alignment == NSTextAlignmentCenter ? 2 : alignment == NSTextAlignmentRight ? 1 : NSTextAlignmentLeft;
}

@implementation PDFAnnotation (SKExtensions)

static CGAffineTransform (*CGContextGetBaseCTM_func)(CGContextRef) = NULL;

static void (*original_setColor)(id, SEL, id) = NULL;
static void (*original_setBounds)(id, SEL, NSRect) = NULL;

// PDFView raises an exception when a highlight has a sRGB black color
static void replacement_setColor(id self, SEL _cmd, NSColor *color) {
    if ([[(PDFAnnotation *)self type] isEqualToString:SKNHighlightString]) {
        static NSColor *blackColor = nil;
        if (blackColor == nil)
            blackColor = [NSColor colorWithSRGBRed:0.0 green:0.0 blue:0.0 alpha:1.0];
        if ([color isEqual:blackColor])
            color = [NSColor blackColor];
    }
    original_setColor(self, _cmd, color);
}

static void replacement_setBounds(id self, SEL _cmd , NSRect newBounds) {
    if ([[(PDFAnnotation *)self type] isEqualToString:SKNLineString]) {
        NSArray *points = [self valueForAnnotationKey:PDFAnnotationKeyLinePoints];
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
            [self setValue:points forAnnotationKey:PDFAnnotationKeyLinePoints];
    } else {
        original_setBounds(self, _cmd, newBounds);
    }
}

+ (void)load {
    CGContextGetBaseCTM_func = (typeof(CGContextGetBaseCTM_func))CFBundleGetFunctionPointerForName(CFBundleGetBundleWithIdentifier(CFSTR("com.apple.CoreGraphics")), CFSTR("CGContextGetBaseCTM"));
    original_setColor = (void (*)(id, SEL, id))SKReplaceInstanceMethodImplementation(self, @selector(setColor:), (IMP)replacement_setColor);
    if (@available(macOS 10.14, *)) {} else {
        original_setBounds = (void (*)(id, SEL, NSRect))SKReplaceInstanceMethodImplementation(self, @selector(setBounds:), (IMP)replacement_setBounds);
    }
}

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard {
    return @[SKPasteboardTypeSkimNote];
}

+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard {
    return NSPasteboardReadingAsData;
}

+ (NSSet *)keyPathsForValuesAffectingObjectValue {
    return [NSSet setWithObjects:SKNPDFAnnotationStringKey, nil];
}

- (instancetype)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type {
    if ([type isEqualToString:SKPasteboardTypeSkimNote] &&
        [propertyList isKindOfClass:[NSData class]]) {
        self = [self initSkimNoteWithProperties: [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSArray class], [NSString class], [NSNumber class], [NSData class], [NSDate class], [NSColor class], [NSFont class], [NSAttributedString class], [NSImage class], nil] fromData:propertyList error:NULL]];
    } else {
        self = [self init];
        self = nil;
    }
    return self;
}

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard {
    return @[SKPasteboardTypeSkimNote];
}

- (id)pasteboardPropertyListForType:(NSString *)type {
    if ([type isEqualToString:SKPasteboardTypeSkimNote])
        return [NSKeyedArchiver archivedDataWithRootObject:[self SkimNoteProperties] requiringSecureCoding:YES error:NULL];
    return nil;
}

+ (Class)annotationClassForType:(NSString *)type {
    if ([type isEqualToString:SKNNoteString] || [type isEqualToString:SKNTextString] || [type isEqualToString:SKNStampString])
        return [SKNPDFAnnotationNote class];
    else
        return self;
}

+ (PDFAnnotation *)newSkimNoteWithBounds:(NSRect)bounds forType:(NSString *)type {
    return [[[self annotationClassForType:type] alloc] initSkimNoteWithBounds:bounds forType:type];
}

+ (PDFAnnotation *)newSkimNoteWithProperties:(NSDictionary *)dict {
    PDFAnnotation *annotation = [[[self annotationClassForType:[dict objectForKey:SKNPDFAnnotationTypeKey]] alloc] initSkimNoteWithProperties:dict];
    if ([annotation isMarkup]) {
        // generate the lineRects now, for thread safety
        NSPointerArray *lines = lineRectsForQuadPoints([annotation quadrilateralPoints], [annotation bounds].origin);
        objc_setAssociatedObject(annotation, &SKLineRectsKey, lines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return annotation;
}

+ (PDFAnnotation *)newSkimNoteWithSelection:(PDFSelection *)selection onPage:(PDFPage *)page forType:(NSString *)type {
    NSRect bounds = NSZeroRect;
    NSPointerArray *lines = nil;
    if ([selection safeIndexOfFirstCharacterOnPage:page] != NSNotFound) {
        for (PDFSelection *sel in [selection connectedSelectionsOnPage:page]) {
            NSRect lineRect = [sel boundsForPage:page];
            if (NSIsEmptyRect(lineRect) == NO && isfinite(NSMinX(lineRect)) && isfinite(NSMinY(lineRect)) && [[sel string] rangeOfCharacterFromSet:[NSCharacterSet nonWhitespaceAndNewlineCharacterSet]].length) {
                if (lines == nil)
                    lines = [[NSPointerArray alloc] initForRectPointers];
                [lines addPointer:&lineRect];
                bounds = NSUnionRect(lineRect, bounds);
            }
        }
    }
    if (lines == nil)
        return nil;
    
    PDFAnnotation *annotation = [[self alloc] initSkimNoteWithBounds:bounds forType:type];
    
    if (annotation) {
        NSArray *quadPoints = quadPointsForLineRects(lines, bounds.origin, [page lineDirectionAngle] / 90);
        [annotation setQuadrilateralPoints:quadPoints];
        objc_setAssociatedObject(annotation, &SKLineRectsKey, lines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return annotation;
}

+ (PDFAnnotation *)newSkimNoteWithPaths:(NSArray *)paths {
    NSRect bounds = NSZeroRect;
    NSAffineTransform *transform = [NSAffineTransform transform];
    
    for (NSBezierPath *path in paths)
        bounds = NSUnionRect(bounds, [path nonEmptyBounds]);
    bounds = NSInsetRect(NSIntegralRect(bounds), -8.0, -8.0);
    [transform translateXBy:-NSMinX(bounds) yBy:-NSMinY(bounds)];
    
    PDFAnnotation *annotation = [[self alloc] initSkimNoteWithBounds:bounds forType:SKNInkString];
    
    for (NSBezierPath *path in paths)
        [annotation addBezierPath:[transform transformBezierPath:path]];
    
    return annotation;
}

+ (NSDictionary *)normalizedSkimNoteProperties:(NSDictionary *)properties {
    NSString *type = [properties objectForKey:SKNPDFAnnotationTypeKey];
    if ([type isEqualToString:SKNTextString] == NO && [type isEqualToString:SKNStampString] == NO)
        return properties;
    NSMutableDictionary *mutableProperties = [properties mutableCopy];
    [mutableProperties setObject:SKNNoteString forKey:SKNPDFAnnotationTypeKey];
    NSAttributedString *attrString = [properties objectForKey:SKNPDFAnnotationTextKey];
    NSString *contents;
    if (attrString) {
        if ([attrString isKindOfClass:[NSData class]])
            attrString = [[NSAttributedString alloc] initWithData:(NSData *)attrString options:@{} documentAttributes:NULL error:NULL];
        NSRange r;
        if ([[attrString attributesAtIndex:0 effectiveRange:&r] count] == 0 && r.length == [attrString length]) {
            NSFont *font = [[NSUserDefaults standardUserDefaults] fontForNameKey:SKAnchoredNoteFontNameKey sizeKey:SKAnchoredNoteFontSizeKey];
            attrString = [[NSAttributedString alloc] initWithString:[attrString string]
                                                attributes:[NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil]];
            [mutableProperties setObject:attrString forKey:SKNPDFAnnotationTextKey];
        }
    } else if ((contents = [properties objectForKey:SKNPDFAnnotationContentsKey])) {
        NSRange r = [contents rangeOfString:@"  "];
        NSRange r1 = [contents rangeOfString:@"\n"];
        if (r1.location < r.location)
            r = r1;
        if (NSMaxRange(r) < [contents length]) {
            NSFont *font = [[NSUserDefaults standardUserDefaults] fontForNameKey:SKAnchoredNoteFontNameKey sizeKey:SKAnchoredNoteFontSizeKey];
            attrString = [[NSAttributedString alloc] initWithString:[contents substringFromIndex:NSMaxRange(r)]
                                                attributes:[NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil]];
            [mutableProperties setObject:attrString forKey:SKNPDFAnnotationTextKey];
            [mutableProperties setObject:[contents substringToIndex:r.location] forKey:SKNPDFAnnotationContentsKey];
        }
    }
    if ([type isEqualToString:SKNTextString]) {
        NSRect bounds = NSRectFromString([properties objectForKey:SKNPDFAnnotationBoundsKey]);
        if (NSEqualSizes(bounds.size, SKNPDFAnnotationNoteSize) == NO) {
            bounds.origin.y = NSMaxY(bounds) - SKNPDFAnnotationNoteSize.height;
            bounds.size = SKNPDFAnnotationNoteSize;
            bounds.origin.y = NSMaxY(bounds) - SKNPDFAnnotationNoteSize.height;
            bounds.size = SKNPDFAnnotationNoteSize;
            [mutableProperties setObject:NSStringFromRect(bounds) forKey:SKNPDFAnnotationBoundsKey];
        }
    } else if ([type isEqualToString:SKNStampString]) {
        [mutableProperties setObject:@YES forKey:SKNPDFAnnotationDrawsImageKey];
    }
    return mutableProperties;
}

- (void)setDefaultSkimNoteProperties {
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    NSString *type = [self type];
    if ([type isEqualToString:SKNFreeTextString]) {
        NSFont *font = [sud fontForNameKey:SKFreeTextNoteFontNameKey sizeKey:SKFreeTextNoteFontSizeKey];
        if (font)
            [self setFont:font];
        [self setColor:[sud colorForKey:SKFreeTextNoteColorKey]];
        [self setFontColor:[sud colorForKey:SKFreeTextNoteFontColorKey]];
        [self setAlignment:textAlignmentFromAlignment([sud integerForKey:SKFreeTextNoteAlignmentKey])];
        PDFBorder *border = [[PDFBorder alloc] init];
        [border setLineWidth:[sud floatForKey:SKFreeTextNoteLineWidthKey]];
        [border setDashPattern:[sud arrayForKey:SKFreeTextNoteDashPatternKey]];
        [border setStyle:[sud floatForKey:SKFreeTextNoteLineStyleKey]];
        if ([border lineWidth] > 0.0) {
            [self setBorder:border];
        } else {
            [self setBorder:nil];
            // on 10.12 you can't set the border to nil, so set its lineWidth to 0
            [[self border] setLineWidth:0.0];
        }
    } else if ([type isEqualToString:SKNCircleString]) {
        NSColor *color = [sud colorForKey:SKCircleNoteInteriorColorKey];
        if ([color alphaComponent] > 0.0)
            [self setInteriorColor:color];
        [self setColor:[sud colorForKey:SKCircleNoteColorKey]];
        [[self border] setLineWidth:[sud floatForKey:SKCircleNoteLineWidthKey]];
        [[self border] setDashPattern:[sud arrayForKey:SKCircleNoteDashPatternKey]];
        [[self border] setStyle:[sud floatForKey:SKCircleNoteLineStyleKey]];
    } else if ([type isEqualToString:SKNSquareString]) {
        NSColor *color = [sud colorForKey:SKSquareNoteInteriorColorKey];
        if ([color alphaComponent] > 0.0)
            [self setInteriorColor:color];
        [self setColor:[sud colorForKey:SKSquareNoteColorKey]];
        [[self border] setLineWidth:[sud floatForKey:SKSquareNoteLineWidthKey]];
        [[self border] setDashPattern:[sud arrayForKey:SKSquareNoteDashPatternKey]];
        [[self border] setStyle:[sud floatForKey:SKSquareNoteLineStyleKey]];
    } else if ([type isEqualToString:SKNHighlightString]) {
        [self setColor:[sud colorForKey:SKHighlightNoteColorKey]];
    } else if ([type isEqualToString:SKNUnderlineString]) {
        [self setColor:[sud colorForKey:SKUnderlineNoteColorKey]];
    } else if ([type isEqualToString:SKNStrikeOutString]) {
        [self setColor:[sud colorForKey:SKStrikeOutNoteColorKey]];
    } else if ([type isEqualToString:SKNLineString]) {
        NSRect bounds = [self bounds];
        [self setColor:[sud colorForKey:SKLineNoteColorKey]];
        NSColor *color = [sud colorForKey:SKLineNoteInteriorColorKey];
        if ([color alphaComponent] > 0.0)
            [self setInteriorColor:color];
        [self setStartLineStyle:[sud integerForKey:SKLineNoteStartLineStyleKey]];
        [self setEndLineStyle:[sud integerForKey:SKLineNoteEndLineStyleKey]];
        [self setStartPoint:NSMakePoint(0.0, 0.0)];
        [self setEndPoint:NSMakePoint(NSWidth(bounds), NSHeight(bounds))];
        PDFBorder *border = [[PDFBorder alloc] init];
        [border setLineWidth:[sud floatForKey:SKLineNoteLineWidthKey]];
        [border setDashPattern:[sud arrayForKey:SKLineNoteDashPatternKey]];
        [border setStyle:[sud floatForKey:SKLineNoteLineStyleKey]];
        [self setBorder:[border lineWidth] > 0.0 ? border : nil];
    } else if ([type isEqualToString:SKNInkString]) {
        [self setColor:[sud colorForKey:SKInkNoteColorKey]];
        PDFBorder *border = [[PDFBorder alloc] init];
        [border setLineWidth:[sud floatForKey:SKInkNoteLineWidthKey]];
        [border setDashPattern:[sud arrayForKey:SKInkNoteDashPatternKey]];
        [border setStyle:[sud floatForKey:SKInkNoteLineStyleKey]];
        [self setBorder:[border lineWidth] > 0.0 ? border : nil];
    }
}

- (NSString *)fdfString {
    NSMutableString *fdfString = [NSMutableString string];
    NSRect bounds = [self bounds];
    CGFloat r, g, b, a = 0.0;
    PDFBorder *border = [self border];
    NSString *contents = [self contents];
    NSDate *modDate = [self modificationDate];
    NSString *userName = [self userName];
    NSString *type = [self type];
    [[[self color] colorUsingColorSpaceName:NSDeviceRGBColorSpace] getRed:&r green:&g blue:&b alpha:&a];
    [fdfString appendFDFName:SKFDFTypeKey];
    [fdfString appendFDFName:SKFDFAnnotation];
    [fdfString appendFDFName:SKFDFAnnotationTypeKey];
    [fdfString appendString:[self valueForAnnotationKey:PDFAnnotationKeySubtype]];
    [fdfString appendFDFName:SKFDFAnnotationBoundsKey];
    [fdfString appendFormat:@"[%g %g %g %g]", NSMinX(bounds), NSMinY(bounds), NSMaxX(bounds), NSMaxY(bounds)];
    [fdfString appendFDFName:SKFDFAnnotationPageIndexKey];
    [fdfString appendFormat:@" %lu", (unsigned long)[self pageIndex]];
    [fdfString appendFDFName:SKFDFAnnotationFlagsKey];
    [fdfString appendString:@" 4"];
    if (a > 0.0) {
        [fdfString appendFDFName:SKFDFAnnotationColorKey];
        [fdfString appendFormat:@"[%g %g %g]", r, g, b];
    }
    if (border) {
        [fdfString appendFDFName:SKFDFAnnotationBorderStylesKey];
        [fdfString appendString:@"<<"];
        if ([border lineWidth] > 0.0) {
            [fdfString appendFDFName:SKFDFAnnotationLineWidthKey];
            [fdfString appendFormat:@" %g", [border lineWidth]];
            [fdfString appendFDFName:SKFDFAnnotationBorderStyleKey];
            [fdfString appendFDFName:SKFDFBorderStyleFromPDFBorderStyle([border style])];
            if ([border style] == kPDFBorderStyleDashed) {
                [fdfString appendFDFName:SKFDFAnnotationDashPatternKey];
                [fdfString appendFormat:@"[%@]", [[[border dashPattern] valueForKey:@"stringValue"] componentsJoinedByString:@" "]];
            }
        } else {
            [fdfString appendFDFName:SKFDFAnnotationLineWidthKey];
            [fdfString appendString:@" 0"];
        }
        [fdfString appendString:@">>"];
    }
    if (contents) {
        [fdfString appendFDFName:SKFDFAnnotationContentsKey];
        [fdfString appendString:@"("];
        [fdfString appendString:[[contents lossyStringUsingEncoding:NSISOLatin1StringEncoding] stringByEscapingParenthesis]];
        [fdfString appendString:@")"];
    }
    if (modDate) {
        [fdfString appendFDFName:SKFDFAnnotationModificationDateKey];
        [fdfString appendFormat:@"(%@)", [modDate PDFDescription]];
    }
    if (userName) {
        [fdfString appendFDFName:SKFDFAnnotationUserNameKey];
        [fdfString appendFormat:@"(%@) ", [[userName lossyStringUsingEncoding:NSISOLatin1StringEncoding] stringByEscapingParenthesis]];
    }
    if ([self hasInteriorColor]) {
        a = 0.0;
        [[[self interiorColor] colorUsingColorSpaceName:NSDeviceRGBColorSpace] getRed:&r green:&g blue:&b alpha:&a];
        if (a > 0.0) {
            [fdfString appendFDFName:SKFDFAnnotationInteriorColorKey];
            [fdfString appendFormat:@"[%g %g %g]", r, g, b];
        }
    }
    if ([type isEqualToString:SKNFreeTextString]) {
        [fdfString appendFDFName:SKFDFDefaultAppearanceKey];
        NSString *da = [self valueForAnnotationKey:PDFAnnotationKeyDefaultAppearance];
        if (da) {
            [fdfString appendFormat:@"(%@)", da];
        } else {
            NSColor *color = [self fontColor];
            if ([[color colorSpace] colorSpaceModel] == NSGrayColorSpaceModel) {
                [[color colorUsingColorSpaceName:NSDeviceWhiteColorSpace] getWhite:&g alpha:&a];
                [fdfString appendFormat:@"(/%@ %g Tf %g g)", [self fontName], [self fontSize], g];
            } else {
                [[color colorUsingColorSpaceName:NSDeviceRGBColorSpace] getRed:&r green:&g blue:&b alpha:&a];
                [fdfString appendFormat:@"(/%@ %g Tf %g %g %g rg)", [self fontName], [self fontSize], r, g, b];
            }
        }
        [fdfString appendFDFName:SKFDFAnnotationAlignmentKey];
        [fdfString appendFormat:@" %ld", (long)SKFDFFreeTextAnnotationAlignmentFromPDFFreeTextAnnotationAlignment([self alignment])];
    } else if ([type isEqualToString:SKNHighlightString] || [type isEqualToString:SKNUnderlineString] || [type isEqualToString:SKNStrikeOutString]) {
        [fdfString appendFDFName:SKFDFAnnotationQuadrilateralPointsKey];
        [fdfString appendString:@"["];
        for (NSValue *value in [self quadrilateralPoints]) {
            NSPoint point = [value pointValue];
            [fdfString appendFormat:@"%g %g ", point.x + NSMinX(bounds), point.y + NSMinY(bounds)];
        }
        [fdfString appendString:@"]"];
    } else if ([type isEqualToString:SKNLineString]) {
        [fdfString appendFDFName:SKFDFAnnotationLineStylesKey];
        [fdfString appendString:@"["];
        [fdfString appendFDFName:SKFDFLineStyleFromPDFLineStyle([self startLineStyle])];
        [fdfString appendFDFName:SKFDFLineStyleFromPDFLineStyle([self endLineStyle])];
        [fdfString appendString:@"]"];
        NSPoint startPoint = SKAddPoints([self startPoint], bounds.origin);
        NSPoint endPoint = SKAddPoints([self endPoint], bounds.origin);
        [fdfString appendFDFName:SKFDFAnnotationLinePointsKey];
        [fdfString appendFormat:@"[%g %g %g %g]", startPoint.x, startPoint.y, endPoint.x, endPoint.y];
    } else if ([type isEqualToString:SKNInkString]) {
        NSPoint point;
        NSInteger i, iMax;
        [fdfString appendFDFName:SKFDFAnnotationInkListKey];
        [fdfString appendString:@"["];
        for (NSBezierPath *path in [self paths]) {
            iMax = [path elementCount];
            [fdfString appendString:@"["];
            for (i = 0; i < iMax; i++) {
                NSPoint p[3];
                point = NSCurveToBezierPathElement == [path elementAtIndex:i associatedPoints:p] ? p[2] : p[0];
                [fdfString appendFormat:@"%g %g ", point.x + NSMinX(bounds), point.y + NSMinY(bounds)];
            }
            [fdfString appendString:@"]"];
        }
        [fdfString appendString:@"]"];
    } else if ([type isEqualToString:SKNNoteString] || [type isEqualToString:SKNTextString] || [type isEqualToString:SKNStampString]) {
        [fdfString appendFDFName:SKFDFAnnotationIconTypeKey];
        [fdfString appendFDFName:SKFDFTextAnnotationIconTypeFromPDFTextAnnotationIconType([self iconType])];
    } else if ([type isEqualToString:SKNWidgetString]) {
        NSString *ft = [self widgetFieldType];
        [fdfString appendFDFName:SKFDFAnnotationFieldTypeKey];
        [fdfString appendString:ft];
        [fdfString appendFDFName:SKFDFAnnotationFieldNameKey];
        [fdfString appendFormat:@"(%@)", [[[self fieldName] ?: @"" lossyStringUsingEncoding:NSISOLatin1StringEncoding] stringByEscapingParenthesis]];
        [fdfString appendFDFName:SKFDFAnnotationFieldValueKey];
        if ([ft isEqualToString:PDFAnnotationWidgetSubtypeButton]) {
            [fdfString appendFormat:@"/%@", [self buttonWidgetState] == kPDFWidgetOnState ? [self buttonWidgetStateString] : @"Off"];
        } else {
            [fdfString appendFormat:@"(%@)", [[[self widgetStringValue] ?: @"" lossyStringUsingEncoding:NSISOLatin1StringEncoding] stringByEscapingParenthesis]];
        }
        
    }
    return fdfString;
}

- (NSUInteger)pageIndex {
    PDFPage *page = [self page];
    return page ? [page pageIndex] : NSNotFound;
}

- (PDFBorderStyle)borderStyle {
    return [[self border] style];
}

- (void)setBorderStyle:(PDFBorderStyle)style {
    if ([self isEditable] && [self hasBorder]) {
        PDFBorder *oldBorder = [self border];
        PDFBorder *border = nil;
        if (oldBorder || style)
            border = [[PDFBorder alloc] init];
        if (oldBorder) {
            [border setLineWidth:[oldBorder lineWidth]];
            [border setDashPattern:[oldBorder dashPattern]];
        }
        if (border)
            [border setStyle:style];
        [self setBorder:border];
    }
}

- (CGFloat)lineWidth {
    PDFBorder *border = [self border];
    return border ? [border lineWidth] : 0.0;
}

- (void)setLineWidth:(CGFloat)width {
    if ([self isEditable] && [self hasBorder]) {
        PDFBorder *border = nil;
        if (width > 0.0) {
            PDFBorder *oldBorder = [self border];
            border = [[PDFBorder alloc] init];
            if (oldBorder && [oldBorder lineWidth] > 0.0) {
                [border setDashPattern:[oldBorder dashPattern]];
                [border setStyle:[oldBorder style]];
            }
            [border setLineWidth:width];
            [self setBorder:border];
        } else {
            [self setBorder:nil];
            if ([self border] != nil) {
                border = [[PDFBorder alloc] init];
                [border setLineWidth:0.0];
                [self setBorder:border];
            }
        }
    }
}

- (NSArray *)dashPattern {
    return [[self border] dashPattern];
}

- (void)setDashPattern:(NSArray *)pattern {
    if ([self isEditable] && [self hasBorder]) {
        PDFBorder *oldBorder = [self border];
        PDFBorder *border = nil;
        if (oldBorder || [pattern count])
            border = [[PDFBorder alloc] init];
        if (oldBorder) {
            [border setLineWidth:[oldBorder lineWidth]];
            [border setStyle:[oldBorder style]];
        }
        if (border)
            [border setDashPattern:pattern];
        [self setBorder:border];
    }
}

- (CGFloat)pathInset {
    NSRect bounds = NSZeroRect;
    NSSize size = [self bounds].size;
    for (NSBezierPath *path in [self paths])
        bounds = NSUnionRect(bounds, [path nonEmptyBounds]);
    return floor(fmin(8.0, fmax(0.0, fmin(NSMinX(bounds), fmin(NSMinY(bounds), fmin(size.width - NSMaxX(bounds), size.height - NSMaxY(bounds)))))));
}

// use a copy of the paths so to ensure different old and new values for undo
- (NSArray *)bezierPaths {
    return [[self paths] copy];
}

- (void)setBezierPaths:(NSArray *)newPaths {
    NSArray *paths = [[self paths] copy];
    for (NSBezierPath *path in paths)
        [self removeBezierPath:path];
    for (NSBezierPath *path in newPaths)
        [self addBezierPath:path];
}

- (NSArray *)pagePaths {
    NSMutableArray *paths = [[NSMutableArray alloc] init];
    NSRect bounds = [self bounds];
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform translateXBy:NSMinX(bounds) yBy:NSMinY(bounds)];
    for (NSBezierPath *path in [self paths])
        [paths addObject:[transform transformBezierPath:path]];
    return paths;
}

- (NSImage *)image { return nil; }

- (NSAttributedString *)text { return nil; }

- (PDFTextAnnotationIconType)extendedIconType { return [self iconType]; }

- (BOOL)hasNoteText { return [self isMarkup] && [self isEditable]; }

- (SKNoteText *)noteText {
    if ([self isMarkup] == NO || [self isEditable] == NO)
        return nil;
    SKNoteText *noteText = objc_getAssociatedObject(self, &SKNoteTextKey);
    if (noteText == nil) {
        noteText = [[SKNoteText alloc] initWithNote:self];
        objc_setAssociatedObject(self, &SKNoteTextKey, noteText, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return noteText;
}

- (PDFSelection *)selectionWithPage:(PDFPage *)page {
    PDFSelection *selection = nil;
    NSMutableArray *selections = nil;
    NSPointerArray *lines = [self lineRects];
    NSUInteger i, iMax = [lines count];
    
    for (i = 0; i < iMax; i++) {
        // slightly outset the rect to avoid rounding errors, as selectionForRect is pretty strict in some OS versions, but unfortunately not in others
        PDFSelection *sel = [page selectionForRect:NSInsetRect([lines rectAtIndex:i], -1.0, -1.0)];
        if ([sel hasCharacters]) {
            if (selection == nil)
                selection = sel;
            else if (selections)
                [selections addObject:sel];
            else
                selections = [NSMutableArray arrayWithObject:sel];
        }
    }
    if (selections)
        [selection addSelections:selections];
    return selection;
}

- (PDFSelection *)selection {
    if ([self isMarkup])
        return [self selectionWithPage:[self page]];
    return nil;
}

- (id)objectValue {
    if ([[self type] isEqualToString:SKNWidgetString] == NO)
        return [self string];
    else if ([self widgetType] == kSKNPDFWidgetTypeButton)
        return [NSNumber numberWithInteger:[self buttonWidgetState]];
    else
        return [self widgetStringValue];
}

- (void)setObjectValue:(id)newObjectValue {
    if ([[self type] isEqualToString:SKNWidgetString]) {
        if ([self widgetType] == kSKNPDFWidgetTypeButton)
            [self setButtonWidgetState:[newObjectValue integerValue]];
        else
            [self setWidgetStringValue:newObjectValue];
    } else if ([newObjectValue isKindOfClass:[NSString class]] || newObjectValue == nil) {
        [self setString:newObjectValue];
    }
}

- (SKNPDFWidgetType)widgetType {
    if ([[self type] isEqualToString:SKNWidgetString]) {
        NSString *ft = [self widgetFieldType];
        if ([ft isEqualToString:PDFAnnotationWidgetSubtypeText])
            return kSKNPDFWidgetTypeText;
        else if ([ft isEqualToString:PDFAnnotationWidgetSubtypeButton])
            return kSKNPDFWidgetTypeButton;
        else if ([ft isEqualToString:PDFAnnotationWidgetSubtypeChoice])
            return kSKNPDFWidgetTypeChoice;
    }
    return kSKNPDFWidgetTypeUnknown;
}

- (NSString *)textString {
    if ([self isMarkup] == NO || [[self page] pageRef] == NULL)
        return nil;
    NSString *textString = objc_getAssociatedObject(self, &SKTextStringKey);
    if (textString == nil) {
        textString = [[self selection] cleanedString] ?: @"";
        objc_setAssociatedObject(self, &SKTextStringKey, textString, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return textString;
}

- (NSPointerArray *)lineRects {
    if ([self isMarkup] == NO)
        return nil;
    NSPointerArray *lineRects = objc_getAssociatedObject(self, &SKLineRectsKey);
    if (lineRects == nil) {
        lineRects = lineRectsForQuadPoints([self quadrilateralPoints], [self bounds].origin);
        objc_setAssociatedObject(self, &SKLineRectsKey, lineRects, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return lineRects;
}

- (BOOL)isMarkup {
    NSString *type = [self type];
    return [type isEqualToString:SKNHighlightString] || [type isEqualToString:SKNUnderlineString] || [type isEqualToString:SKNStrikeOutString];
}

- (BOOL)isNote { return NO; }

- (BOOL)isText { return [[self type] isEqualToString:SKNFreeTextString]; }

- (BOOL)isShape {
    NSString *type = [self type];
    return [type isEqualToString:SKNCircleString] || [type isEqualToString:SKNSquareString];
}

- (BOOL)isLine { return [[self type] isEqualToString:SKNLineString]; }

- (BOOL)isInk { return [[self type] isEqualToString:SKNInkString]; }

- (BOOL)isLink { return [[self type] isEqualToString:@"Link"]; }

- (BOOL)isWidget {
    SKNPDFWidgetType widgetType = [self widgetType];
    if (widgetType == kSKNPDFWidgetTypeUnknown)
        return NO;
    if (widgetType != kSKNPDFWidgetTypeButton)
        return YES;
    PDFWidgetControlType controlType = [self widgetControlType];
    return controlType == kPDFWidgetCheckBoxControl || controlType == kPDFWidgetRadioButtonControl;
}

- (BOOL)isResizable {
    if ([self isSkimNote] == NO)
        return NO;
    static NSSet *resizableTypes = nil;
    if (resizableTypes == nil)
        resizableTypes = [NSSet setWithObjects:SKNFreeTextString, SKNCircleString, SKNSquareString, SKNLineString, SKNInkString, nil];
    return [resizableTypes containsObject:[self type]];
}

- (BOOL)isMovable {
    if ([self isSkimNote] == NO)
        return NO;
    static NSSet *movableTypes = nil;
    if (movableTypes == nil)
        movableTypes = [NSSet setWithObjects:SKNFreeTextString, SKNNoteString, SKNCircleString, SKNSquareString, SKNLineString, SKNInkString, nil];
    return [movableTypes containsObject:[self type]];
}

- (BOOL)isEditable { return [self isSkimNote] && ([self page] == nil || [[self page] isEditable]); }

- (BOOL)hasBorder {
    static NSSet *borderedTypes = nil;
    if (borderedTypes == nil)
        borderedTypes = [NSSet setWithObjects:SKNFreeTextString, SKNCircleString, SKNSquareString, SKNLineString, SKNInkString, nil];
    return [borderedTypes containsObject:[self type]];
}

- (BOOL)hasInteriorColor {
    if ([self isSkimNote] == NO)
        return NO;
    NSString *type = [self type];
    return [type isEqualToString:SKNCircleString] || [type isEqualToString:SKNSquareString] || [type isEqualToString:SKNLineString];
}

- (BOOL)isConvertibleAnnotation {
    static NSSet *convertibleTypes = nil;
    if (convertibleTypes == nil)
        convertibleTypes = [[NSSet alloc] initWithObjects:SKNFreeTextString, SKNTextString, SKNStampString, SKNNoteString, SKNCircleString, SKNSquareString, SKNHighlightString, SKNUnderlineString, SKNStrikeOutString, SKNLineString, SKNInkString, nil];
    return [convertibleTypes containsObject:[self type]];
}

- (BOOL)hitTest:(NSPoint)point {
    if ([self shouldDisplay] == NO || [self isSkimNote] == NO)
        return NO;
    NSString *type = [self type];
    if ([type isEqualToString:SKNLineString])
        return SKPointNearLineFromPointToPoint(SKSubstractPoints(point, [self bounds].origin), [self startPoint], [self endPoint], fmax(4.0, 0.5 * [self lineWidth]));
    NSRect bounds = [self bounds];
    if (NSPointInRect(point, bounds) == NO)
        return NO;
    if ([type isEqualToString:SKNCircleString]) {
        CGFloat dx = 2.0 * (point.x - NSMidX(bounds)) / NSWidth(bounds);
        CGFloat dy = 2.0 * (point.y - NSMidY(bounds)) / NSHeight(bounds);
        if (dx * dx + dy * dy > 1.0)
            return NO;
        if ([self interiorColor])
            return YES;
        CGFloat delta = fmax(8.0, [self lineWidth]);
        if (NSWidth(bounds) <= 2.0 * delta || NSHeight(bounds) <= 2.0 * delta)
            return YES;
        bounds = NSInsetRect(bounds, delta, delta);
        dx = 2.0 * (point.x - NSMidX(bounds)) / NSWidth(bounds);
        dy = 2.0 * (point.y - NSMidY(bounds)) / NSHeight(bounds);
        return dx * dx + dy * dy >= 1.0;
    } else if ([type isEqualToString:SKNSquareString]) {
        if ([self interiorColor])
            return YES;
        CGFloat delta = fmax(8.0, [self lineWidth]);
        return NSWidth(bounds) <= 2.0 * delta || NSHeight(bounds) <= 2.0 * delta || NSPointInRect(point, NSInsetRect(bounds, delta, delta)) == NO;
    } else if ([type isEqualToString:SKNHighlightString] || [type isEqualToString:SKNUnderlineString] || [type isEqualToString:SKNStrikeOutString]) {
        NSPointerArray *lines = [self lineRects];
        NSUInteger i = [lines count];
        while (i--) {
            if (NSPointInRect(point, [lines rectAtIndex:i]))
                return YES;
        }
        return NO;
    }
    return YES;
}

- (CGFloat)boundsOrder {
    NSString *type = [self type];
    if ([type isEqualToString:SKNLineString]) {
        CGFloat delta = ceil(fmax(4.0 * [self lineWidth], 4.0));
        NSPoint origin = [self bounds].origin;
        NSRect startBounds = SKRectFromCenterAndSquareSize(SKAddPoints(origin, [self startPoint]), delta);
        NSRect endBounds = SKRectFromCenterAndSquareSize(SKAddPoints(origin, [self endPoint]), delta);
        PDFPage *page = [self page];
        return fmin([page sortOrderForBounds:startBounds], [page sortOrderForBounds:endBounds]);
    } else if ([type isEqualToString:SKNHighlightString] || [type isEqualToString:SKNUnderlineString] || [type isEqualToString:SKNStrikeOutString]) {
        NSPointerArray *lines = [self lineRects];
        NSRect bounds = [lines count] > 0 ? [lines rectAtIndex:0] : [self bounds];
        return [[self page] sortOrderForBounds:bounds];
    }
    return [[self page] sortOrderForBounds:[self bounds]];
}

- (SKRectEdges)resizeHandleForPoint:(NSPoint)point scaleFactor:(CGFloat)scaleFactor {
    if ([self isResizable] == NO)
        return SKRectEdgesNone;
    if ([[self type] isEqualToString:SKNLineString]) {
        NSSize size = SKMakeSquareSize(8.0 / scaleFactor);
        point = SKSubstractPoints(point, [self bounds].origin);
        if (NSPointInRect(point, SKRectFromCenterAndSize([self endPoint], size)))
            return SKRectEdgesMaxX;
        else if (NSPointInRect(point, SKRectFromCenterAndSize([self startPoint], size)))
            return SKRectEdgesMinX;
        else
            return SKRectEdgesNone;
    }
    return SKResizeHandleForPointFromRect(point, [self bounds], 4.0 / scaleFactor);
}

- (void)drawShadowWithUnitWidth:(CGFloat)unitWidth inContext:(CGContextRef)context {
    NSRect bounds = [self bounds];
    CGFloat r = fmin(2.0, 2.0 * unitWidth);
    CGRect rect = NSRectToCGRect(NSInsetRect(bounds, 2.0 * r, 2.0 * r));
    CGAffineTransform t = CGAffineTransformConcat(CGContextGetCTM(context), CGAffineTransformInvert(CGContextGetBaseCTM_func(context)));
    r = fabs(CGSizeApplyAffineTransform(CGSizeMake(r, r), t).height);
    t = CGAffineTransformMakeTranslation(NSMinX(bounds), NSMinY(bounds));
    CGMutablePathRef path = CGPathCreateMutable();
    for (NSBezierPath *aPath in [self paths])
        [aPath addToCGPath:path transform:&t];
    CGContextSaveGState(context);
    CGContextSetAlpha(context, [[self color] alphaComponent]);
    CGContextBeginTransparencyLayerWithRect(context, rect, NULL);
    CGContextSetLineWidth(context, [self lineWidth]);
    if ([self borderStyle] == kPDFBorderStyleDashed) {
        NSArray *dashPattern = [self dashPattern];
        NSUInteger i, count = [dashPattern count];
        CGFloat pattern[count];
        for (i = 0; i < count; i++)
            pattern[i] = [[dashPattern objectAtIndex:i] doubleValue];
        CGContextSetLineDash(context, 0.0, pattern, count);
        CGContextSetLineCap(context, kCGLineCapButt);
    } else {
        CGContextSetLineCap(context, kCGLineCapRound);
    }
    CGContextSetShadow(context, CGSizeMake(0.0, -r), r);
    CGContextAddPath(context, path);
    CGContextStrokePath(context);
    CGContextSetShadowWithColor(context, CGSizeZero, 0.0, NULL);
    CGContextSetBlendMode(context, kCGBlendModeClear);
    CGContextAddPath(context, path);
    CGContextStrokePath(context);
    CGContextEndTransparencyLayer(context);
    CGContextRestoreGState(context);
    CGPathRelease(path);
}

- (void)drawFallbackShadowWithUnitWidth:(CGFloat)unitWidth inContext:(CGContextRef)context {
    CGFloat r = fmin(2.0 / unitWidth, 2.0);
    NSSize offset = NSZeroSize;
    switch ([[self page] rotation]) {
        case 0:   offset.height = -r; break;
        case 90:  offset.width = r;   break;
        case 180: offset.height = r;  break;
        case 270: offset.width = -r;  break;
        default:  offset.height = -r; break;
    }
    NSRect bounds = [self bounds];
    NSRect rect = NSIntersectionRect(NSOffsetRect(NSInsetRect(bounds, -r * unitWidth, -r * unitWidth), offset.width * unitWidth, offset.height * unitWidth), NSRectFromCGRect(CGContextGetClipBoundingBox(context)));
    if (NSIsEmptyRect(rect) == NO) {
        NSRect imgRect = NSMakeRect(0.0, 0.0, ceil(NSWidth(rect) / unitWidth), ceil(NSHeight(rect) / unitWidth));
        rect.size = NSMakeSize(NSWidth(imgRect) * unitWidth, NSHeight(imgRect) * unitWidth);
        NSImage *image = [NSImage imageWithSize:imgRect.size flipped:NO drawingHandler:^(NSRect dstRect){
            NSAffineTransform *transform = [NSAffineTransform transform];
            [transform scaleBy:1.0 / unitWidth];
            [transform translateXBy:NSMinX(bounds) - NSMinX(rect) yBy:NSMinY(bounds) - NSMinY(rect)];
            [transform concat];
            NSBezierPath *path = [NSBezierPath bezierPath];
            for (NSBezierPath *aPath in [self paths])
                [path appendBezierPath:aPath];
            [path setLineWidth:fmax(1.0, [self lineWidth])];
            [path setLineJoinStyle:NSRoundLineJoinStyle];
            if ([self borderStyle] == kPDFBorderStyleDashed) {
                [path setDashPattern:[self dashPattern]];
                [path setLineCapStyle:NSButtLineCapStyle];
            } else {
                [path setLineCapStyle:NSRoundLineCapStyle];
            }
            [NSGraphicsContext saveGraphicsState];
            [NSShadow setShadowWithColor:[NSColor colorWithGenericGamma22White:0.0 alpha:0.33333] blurRadius:r offset:offset];
            [path stroke];
            [NSGraphicsContext restoreGraphicsState];
            [[NSGraphicsContext currentContext] setCompositingOperation:NSCompositingOperationClear];
            [path stroke];
            return YES;
        }];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:context flipped:NO]];
        [image drawInRect:rect fromRect:imgRect operation:NSCompositingOperationSourceOver fraction:[[self color] alphaComponent]];
        [NSGraphicsContext restoreGraphicsState];
    }
}

- (void)drawSelectionHighlightWithUnitWidth:(CGFloat)unitWidth active:(BOOL)active inContext:(CGContextRef)context {
    if (NSIsEmptyRect([self bounds]))
        return;
    if ([self isSkimNote]) {
        NSString *type = [self type];
        if ([type isEqualToString:SKNLineString]) {
            NSPoint origin = [self bounds].origin;
            SKDrawResizeHandlePair(context, SKAddPoints(origin, [self startPoint]), SKAddPoints(origin, [self endPoint]), unitWidth, active);
        } else if ([type isEqualToString:SKNHighlightString] || [type isEqualToString:SKNUnderlineString] || [type isEqualToString:SKNStrikeOutString]) {
            NSPointerArray *lines = [self lineRects];
            NSUInteger i, iMax = [lines count];
            CGColorRef color = [[NSColor selectionHighlightColor:active] CGColor];
            
            CGContextSaveGState(context);
            CGContextSetStrokeColorWithColor(context, color);
            CGContextSetLineWidth(context, unitWidth);
            for (i = 0; i < iMax; i++) {
                CGRect rect = CGContextConvertRectToUserSpace(context, CGRectIntegral(CGContextConvertRectToDeviceSpace(context, NSRectToCGRect([lines rectAtIndex:i]))));
                CGContextStrokeRect(context, CGRectInset(rect, -0.5 * unitWidth, -0.5 * unitWidth));
            }
            CGContextRestoreGState(context);
        } else {
            if ([type isEqualToString:SKNInkString]) {
                if (NSIsEmptyRect([self bounds]) == NO && [self isSkimNote]) {
                    if (CGContextGetBaseCTM_func != NULL)
                        [self drawShadowWithUnitWidth:unitWidth inContext:context];
                    else
                        [self drawFallbackShadowWithUnitWidth:unitWidth inContext:context];
                }
            }
            CGRect rect = CGContextConvertRectToUserSpace(context, CGRectIntegral(CGContextConvertRectToDeviceSpace(context, NSRectToCGRect([self bounds]))));
            CGContextSaveGState(context);
            if ([self isResizable]) {
                SKDrawResizeHandles(context, NSRectFromCGRect(rect), unitWidth, YES, active);
            } else {
                CGColorRef color = [[NSColor selectionHighlightColor:active] CGColor];
                CGContextSetStrokeColorWithColor(context, color);
                CGContextStrokeRectWithWidth(context, CGRectInset(rect, -0.5 * unitWidth, -0.5 * unitWidth), unitWidth);
            }
            CGContextRestoreGState(context);
        }
    } else if ([self isLink]) {
        CGContextSaveGState(context);
        CGColorRef color = CGColorCreateGenericGray(0.0, 0.2);
        CGContextSetFillColorWithColor(context, color);
        CGColorRelease(color);
        CGContextFillRect(context, NSRectToCGRect([self bounds]));
        CGContextRestoreGState(context);
    }
}

- (void)registerUserName {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKUseUserNameKey]) {
        NSString *userName = [[NSUserDefaults standardUserDefaults] stringForKey:SKUserNameKey];
        [self setUserName:[userName length] ? userName : NSFullUserName()];
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisableModificationDateKey] == NO)
        [self setModificationDate:[NSDate date]];
}

- (void)autoUpdateStringWithPage:(PDFPage *)page {
    NSString *type = [self type];
    if ([type isEqualToString:SKNCircleString]) {
        // this calculation is roughly the inverse of -[PDFView addOtherAnnotationWithType:selection:point:]
        NSRect bounds = NSInsetRect([self bounds], [self lineWidth] - 1.0, [self lineWidth] - 1.0);
        CGFloat t, w = NSWidth(bounds), h = NSWidth(bounds);
        if (w <= 0.0 || h <= 0.0)
            return;
        t = 0.5 * w * h * (w + h - sqrt(2.0 * w * h)) / (w * w + h * h);
        bounds = NSInsetRect(bounds, t, t);
        NSString *selString = [[page selectionForRect:bounds] cleanedString];
        if ([selString length])
            [self setString:selString];
    } else if ([type isEqualToString:SKNSquareString]) {
        NSRect bounds = NSInsetRect([self bounds], [self lineWidth] - 1.0, [self lineWidth] - 1.0);
        if (NSWidth(bounds) <= 0.0 || NSHeight(bounds) <= 0.0)
            return;
        NSString *selString = [[page selectionForRect:bounds] cleanedString];
        if ([selString length])
            [self setString:selString];
    } else if ([type isEqualToString:SKNHighlightString] || [type isEqualToString:SKNUnderlineString] || [type isEqualToString:SKNStrikeOutString]) {
        NSString *selString = [[self selectionWithPage:page] cleanedString];
        if ([selString length]) {
            // page should be future [self page] and textString will not have been called
            objc_setAssociatedObject(self, &SKTextStringKey, selString, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [self setString:selString];
        }
    }
}

- (NSString *)colorDefaultKey {
    NSString *type = [self type];
    if ([type isEqualToString:SKNFreeTextString])
        return SKFreeTextNoteColorKey;
    else if ([type isEqualToString:SKNCircleString])
        return SKCircleNoteColorKey;
    else if ([type isEqualToString:SKNSquareString])
        return SKSquareNoteColorKey;
    else if ([type isEqualToString:SKNHighlightString])
        return SKHighlightNoteColorKey;
    else if ([type isEqualToString:SKNUnderlineString])
        return SKUnderlineNoteColorKey;
    else if ([type isEqualToString:SKNStrikeOutString])
        return SKStrikeOutNoteColorKey;
    else if ([type isEqualToString:SKNLineString])
        return SKLineNoteColorKey;
    else if ([type isEqualToString:SKNInkString])
        return SKInkNoteColorKey;
    else
        return nil;
}

- (NSString *)alternateColorDefaultKey {
    NSString *type = [self type];
    if ([type isEqualToString:SKNFreeTextString])
        return SKFreeTextNoteFontColorKey;
    else if ([type isEqualToString:SKNCircleString])
        return SKCircleNoteInteriorColorKey;
    else if ([type isEqualToString:SKNSquareString])
        return SKSquareNoteInteriorColorKey;
    else if ([type isEqualToString:SKNLineString])
        return SKLineNoteInteriorColorKey;
    else
        return nil;
}

- (NSString *)lineWidthDefaultKey {
    NSString *type = [self type];
    if ([type isEqualToString:SKNFreeTextString])
        return SKFreeTextNoteLineWidthKey;
    else if ([type isEqualToString:SKNCircleString])
        return SKCircleNoteLineWidthKey;
    else if ([type isEqualToString:SKNSquareString])
        return SKSquareNoteLineWidthKey;
    else if ([type isEqualToString:SKNLineString])
        return SKLineNoteLineWidthKey;
    else if ([type isEqualToString:SKNInkString])
        return SKInkNoteLineWidthKey;
    else
        return nil;
}

- (NSString *)borderStyleDefaultKey {
    NSString *type = [self type];
    if ([type isEqualToString:SKNFreeTextString])
        return SKFreeTextNoteLineStyleKey;
    else if ([type isEqualToString:SKNCircleString])
        return SKCircleNoteLineStyleKey;
    else if ([type isEqualToString:SKNSquareString])
        return SKSquareNoteLineStyleKey;
    else if ([type isEqualToString:SKNLineString])
        return SKLineNoteLineStyleKey;
    else if ([type isEqualToString:SKNInkString])
        return SKInkNoteLineStyleKey;
    else
        return nil;
}

- (NSString *)dashPatternDefaultKey {
    NSString *type = [self type];
    if ([type isEqualToString:SKNFreeTextString])
        return SKFreeTextNoteDashPatternKey;
    else if ([type isEqualToString:SKNCircleString])
        return SKCircleNoteDashPatternKey;
    else if ([type isEqualToString:SKNSquareString])
        return SKSquareNoteDashPatternKey;
    else if ([type isEqualToString:SKNLineString])
        return SKLineNoteDashPatternKey;
    else if ([type isEqualToString:SKNInkString])
        return SKInkNoteDashPatternKey;
    else
        return nil;
}

- (NSString *)startLineStyleDefaultKey {
    if ([[self type] isEqualToString:SKNLineString])
        return SKLineNoteStartLineStyleKey;
    else
        return nil;
}

- (NSString *)endLineStyleDefaultKey {
    if ([[self type] isEqualToString:SKNLineString])
        return SKLineNoteEndLineStyleKey;
    else
        return nil;
}

- (void)setColor:(NSColor *)color alternate:(BOOL)alternate updateDefaults:(BOOL)update {
    BOOL isFill = alternate && [self hasInteriorColor];
    BOOL isText = alternate && [self isText];
    NSColor *oldColor = (isFill ? [(id)self interiorColor] : (isText ? [(id)self fontColor] : [self color])) ?: [NSColor clearColor];
    if ([oldColor isEqual:color] == NO) {
        if (isFill)
            [(id)self setInteriorColor:[color alphaComponent] > 0.0 ? color : nil];
        else if (isText)
            [(id)self setFontColor:[color alphaComponent] > 0.0 ? color : nil];
        else
            [self setColor:color];
    }
    if (update) {
        NSString *key = (isFill || isText) ? [self alternateColorDefaultKey] : [self colorDefaultKey];
        if (key)
            [[NSUserDefaults standardUserDefaults] setColor:color forKey:key];
    }
}

- (void)setLineWidth:(CGFloat)width updateDefaults:(BOOL)update {
    [self setLineWidth:width];
    if (update) {
        NSString *key = [self lineWidthDefaultKey];
        if (key)
            [[NSUserDefaults standardUserDefaults] setDouble:width forKey:key];
    }
}

- (void)setBorderStyle:(PDFBorderStyle)borderStyle updateDefaults:(BOOL)update {
    [self setBorderStyle:borderStyle];
    if (update) {
        NSString *key = [self borderStyleDefaultKey];
        if (key)
            [[NSUserDefaults standardUserDefaults] setInteger:borderStyle forKey:key];
    }
}

- (void)setDashPattern:(NSArray *)dashPattern updateDefaults:(BOOL)update {
    [self setDashPattern:dashPattern];
    if (update) {
        NSString *key = [self dashPatternDefaultKey];
        if (key)
            [[NSUserDefaults standardUserDefaults] setObject:dashPattern forKey:key];
    }
}

- (void)setStartLineStyle:(PDFLineStyle)startLineStyle updateDefaults:(BOOL)update {
    [self setStartLineStyle:startLineStyle];
    if (update) {
        NSString *key = [self startLineStyleDefaultKey];
        if (key)
            [[NSUserDefaults standardUserDefaults] setInteger:startLineStyle forKey:key];
    }
}

- (void)setEndLineStyle:(PDFLineStyle)endLineStyle updateDefaults:(BOOL)update {
    [self setEndLineStyle:endLineStyle];
    if (update) {
        NSString *key = [self endLineStyleDefaultKey];
        if (key)
            [[NSUserDefaults standardUserDefaults] setInteger:endLineStyle forKey:key];
    }
}

- (NSURL *)skimURL {
    return [[self page] skimURL];
}

- (NSSet *)keysForValuesToObserveForUndo {
    NSString *type = [self type];
    if ([type isEqualToString:SKNFreeTextString]) {
        static NSSet *keys = nil;
        if (keys == nil)
            keys = [[NSSet alloc] initWithObjects:SKNPDFAnnotationBoundsKey, SKNPDFAnnotationStringKey, SKNPDFAnnotationColorKey, SKNPDFAnnotationBorderKey, SKNPDFAnnotationModificationDateKey, SKNPDFAnnotationUserNameKey, SKNPDFAnnotationFontKey, SKNPDFAnnotationFontColorKey, SKNPDFAnnotationAlignmentKey, nil];
        return keys;
    } else if ([type isEqualToString:SKNNoteString]) {
        static NSSet *keys = nil;
        if (keys == nil)
            keys = [[NSSet alloc] initWithObjects:SKNPDFAnnotationBoundsKey, SKNPDFAnnotationStringKey, SKNPDFAnnotationColorKey, SKNPDFAnnotationModificationDateKey, SKNPDFAnnotationUserNameKey, SKNPDFAnnotationNameKey, SKNPDFAnnotationTextKey, SKNPDFAnnotationImageKey, SKNPDFAnnotationDrawsImageKey, nil];
        return keys;
    } else if ([type isEqualToString:SKNCircleString] || [type isEqualToString:SKNSquareString]) {
        static NSSet *keys = nil;
        if (keys == nil)
            keys = [[NSSet alloc] initWithObjects:SKNPDFAnnotationBoundsKey, SKNPDFAnnotationStringKey, SKNPDFAnnotationColorKey, SKNPDFAnnotationBorderKey, SKNPDFAnnotationModificationDateKey, SKNPDFAnnotationUserNameKey, SKNPDFAnnotationInteriorColorKey, nil];
        return keys;
    } else if ([type isEqualToString:SKNHighlightString] || [type isEqualToString:SKNUnderlineString] || [type isEqualToString:SKNStrikeOutString]) {
        static NSSet *keys = nil;
        if (keys == nil)
            keys = [[NSSet alloc] initWithObjects:SKNPDFAnnotationBoundsKey, SKNPDFAnnotationStringKey, SKNPDFAnnotationColorKey, SKNPDFAnnotationModificationDateKey, SKNPDFAnnotationUserNameKey, nil];
        return keys;
    } else if ([type isEqualToString:SKNLineString]) {
        static NSSet *keys = nil;
        if (keys == nil)
            keys = [[NSSet alloc] initWithObjects:SKNPDFAnnotationBoundsKey, SKNPDFAnnotationStringKey, SKNPDFAnnotationColorKey, SKNPDFAnnotationBorderKey, SKNPDFAnnotationModificationDateKey, SKNPDFAnnotationUserNameKey, SKNPDFAnnotationStartLineStyleKey, SKNPDFAnnotationEndLineStyleKey, SKNPDFAnnotationStartPointKey, SKNPDFAnnotationEndPointKey, SKNPDFAnnotationInteriorColorKey, nil];
        return keys;
    } else if ([type isEqualToString:SKNInkString]) {
        static NSSet *keys = nil;
        if (keys == nil)
            keys = [[NSSet alloc] initWithObjects:SKNPDFAnnotationBoundsKey, SKNPDFAnnotationStringKey, SKNPDFAnnotationColorKey, SKNPDFAnnotationBorderKey, SKNPDFAnnotationModificationDateKey, SKNPDFAnnotationUserNameKey, SKPDFAnnotationBezierPathsKey, nil];
        return keys;
    } else if ([type isEqualToString:SKNWidgetString] && [self isWidget]) {
        return [NSSet setWithObject:@"objectValue"];
    } else {
        return [NSSet set];
    }
}

#pragma mark Scripting support

- (NSScriptObjectSpecifier *)objectSpecifier {
    NSScriptObjectSpecifier *containerRef = [[self page] objectSpecifier];
    return [[NSUniqueIDSpecifier alloc
             ] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"notes" uniqueID:[self uniqueID]];
}

- (NSString *)uniqueID {
    return [NSString stringWithFormat:@"%p", (void *)self];
}

static NSArray *invalidScriptingKeysForType(NSString *type) {
    if ([type isEqualToString:SKNFreeTextString]) {
        static NSArray *keys = nil;
        if (keys == nil)
            keys = @[SKPDFAnnotationStartPointAsQDPointKey, SKPDFAnnotationEndPointAsQDPointKey, SKPDFAnnotationScriptingStartLineStyleKey, SKPDFAnnotationScriptingEndLineStyleKey, SKPDFAnnotationScriptingInteriorColorKey, SKPDFAnnotationScriptingPointListsKey, SKPDFAnnotationSelectionSpecifierKey, SKPDFAnnotationScriptingIconTypeKey, SKPDFAnnotationRichTextKey, SKPDFAnnotationScriptingImageDataKey];
        return keys;
    } else if ([type isEqualToString:SKNNoteString]) {
        static NSArray *keys = nil;
        if (keys == nil)
            keys = @[SKNPDFAnnotationLineWidthKey, SKNPDFAnnotationBorderStyleKey, SKNPDFAnnotationDashPatternKey, SKPDFAnnotationStartPointAsQDPointKey, SKPDFAnnotationEndPointAsQDPointKey, SKPDFAnnotationScriptingStartLineStyleKey, SKPDFAnnotationScriptingEndLineStyleKey, SKPDFAnnotationScriptingInteriorColorKey, SKNPDFAnnotationFontNameKey, SKNPDFAnnotationFontSizeKey, SKPDFAnnotationScriptingFontColorKey, SKPDFAnnotationScriptingAlignmentKey, SKPDFAnnotationScriptingPointListsKey, SKPDFAnnotationSelectionSpecifierKey];
        return keys;
    } else if ([type isEqualToString:SKNCircleString] || [type isEqualToString:SKNSquareString]) {
        static NSArray *keys = nil;
        if (keys == nil)
            keys = @[SKPDFAnnotationStartPointAsQDPointKey, SKPDFAnnotationEndPointAsQDPointKey, SKPDFAnnotationScriptingStartLineStyleKey, SKPDFAnnotationScriptingEndLineStyleKey, SKNPDFAnnotationFontNameKey, SKNPDFAnnotationFontSizeKey, SKPDFAnnotationScriptingFontColorKey, SKPDFAnnotationScriptingAlignmentKey, SKPDFAnnotationScriptingPointListsKey, SKPDFAnnotationSelectionSpecifierKey, SKPDFAnnotationScriptingIconTypeKey, SKPDFAnnotationRichTextKey, SKPDFAnnotationScriptingImageDataKey];
        return keys;
    } else if ([type isEqualToString:SKNHighlightString] || [type isEqualToString:SKNUnderlineString] || [type isEqualToString:SKNStrikeOutString]) {
        static NSArray *keys = nil;
        if (keys == nil)
            keys = @[SKNPDFAnnotationLineWidthKey, SKNPDFAnnotationBorderStyleKey, SKNPDFAnnotationDashPatternKey, SKPDFAnnotationStartPointAsQDPointKey, SKPDFAnnotationEndPointAsQDPointKey, SKPDFAnnotationScriptingStartLineStyleKey, SKPDFAnnotationScriptingEndLineStyleKey, SKPDFAnnotationScriptingInteriorColorKey, SKNPDFAnnotationFontNameKey, SKNPDFAnnotationFontSizeKey, SKPDFAnnotationScriptingFontColorKey, SKPDFAnnotationScriptingAlignmentKey, SKPDFAnnotationScriptingIconTypeKey, SKPDFAnnotationRichTextKey, SKPDFAnnotationScriptingImageDataKey];
        return keys;
    } else if ([type isEqualToString:SKNLineString]) {
        static NSArray *keys = nil;
        if (keys == nil)
            keys = @[SKNPDFAnnotationFontNameKey, SKNPDFAnnotationFontSizeKey, SKPDFAnnotationScriptingFontColorKey, SKPDFAnnotationScriptingAlignmentKey, SKPDFAnnotationScriptingPointListsKey, SKPDFAnnotationSelectionSpecifierKey, SKPDFAnnotationScriptingIconTypeKey, SKPDFAnnotationRichTextKey, SKPDFAnnotationScriptingImageDataKey];
        return keys;
    } else if ([type isEqualToString:SKNInkString]) {
        static NSArray *keys = nil;
        if (keys == nil)
            keys = @[SKPDFAnnotationStartPointAsQDPointKey, SKPDFAnnotationEndPointAsQDPointKey, SKPDFAnnotationScriptingStartLineStyleKey, SKPDFAnnotationScriptingEndLineStyleKey, SKPDFAnnotationScriptingInteriorColorKey, SKNPDFAnnotationFontNameKey, SKNPDFAnnotationFontSizeKey, SKPDFAnnotationScriptingFontColorKey, SKPDFAnnotationScriptingAlignmentKey, SKPDFAnnotationSelectionSpecifierKey, SKPDFAnnotationScriptingIconTypeKey, SKPDFAnnotationRichTextKey, SKPDFAnnotationScriptingImageDataKey];
        return keys;
    } else if ([type isEqualToString:SKNWidgetString]) {
        static NSArray *keys = nil;
        if (keys == nil)
            keys = @[SKNPDFAnnotationLineWidthKey, SKNPDFAnnotationBorderStyleKey, SKNPDFAnnotationDashPatternKey, SKPDFAnnotationStartPointAsQDPointKey, SKPDFAnnotationEndPointAsQDPointKey, SKPDFAnnotationScriptingStartLineStyleKey, SKPDFAnnotationScriptingEndLineStyleKey, SKPDFAnnotationScriptingInteriorColorKey, SKNPDFAnnotationFontNameKey, SKNPDFAnnotationFontSizeKey, SKPDFAnnotationScriptingFontColorKey, SKPDFAnnotationScriptingAlignmentKey, SKPDFAnnotationScriptingPointListsKey, SKPDFAnnotationSelectionSpecifierKey, SKPDFAnnotationScriptingIconTypeKey, SKPDFAnnotationRichTextKey, SKPDFAnnotationScriptingImageDataKey];
        return keys;
    } else {
        return [NSArray array];
    }
}

- (NSDictionary *)scriptingProperties {
    // remove all custom properties that are not valid for this class
    NSMutableDictionary *properties = [[super scriptingProperties] mutableCopy];
    [properties removeObjectsForKeys:invalidScriptingKeysForType([self type])];
    return properties;
}

- (void)setScriptingProperties:(NSDictionary *)properties {
    [super setScriptingProperties:properties];
    // set the borderStyle afterwards, as this may have been changed when setting the dash pattern
    id style = [properties objectForKey:SKNPDFAnnotationBorderStyleKey];
    if ([style respondsToSelector:@selector(integerValue)] && [properties objectForKey:SKNPDFAnnotationDashPatternKey])
        [self setBorderStyle:[style integerValue]];
}

- (NSColor *)scriptingColor {
    return [self color];
}

- (void)setScriptingColor:(NSColor *)newColor {
    if ([self isEditable]) {
        [self setColor:newColor];
    }
}

- (PDFPage *)scriptingPage {
    return [self page];
}

- (NSDate *)scriptingModificationDate {
    return [self modificationDate];
}

- (void)setScriptingModificationDate:(NSDate *)date {
    if ([self isEditable]) {
        [self setModificationDate:date];
    }
}

- (NSString *)scriptingUserName {
    return [self userName];
}

- (void)setScriptingUserName:(NSString *)name {
    if ([self isEditable]) {
        [self setUserName:name];
    }
}

- (PDFTextAnnotationIconType)scriptingIconType {
    return kPDFTextAnnotationIconNote;
}

- (NSAppleEventDescriptor *)scriptingImageData {
    return nil;
}

- (id)textContents;
{
    if ([self string] == nil)
        return nil;
    NSTextStorage *textContents = [[NSTextStorage alloc] initWithString:[self string]];
    if ([[self type] isEqualToString:SKNFreeTextString]) {
        if ([self font])
            [textContents addAttribute:NSFontAttributeName value:[self font] range:NSMakeRange(0, [textContents length])];
        if ([self fontColor])
            [textContents addAttribute:NSForegroundColorAttributeName value:[self fontColor] range:NSMakeRange(0, [textContents length])];
    }
    return textContents;
}

- (void)setTextContents:(id)text;
{
    if ([self isEditable]) {
        [self setString:[text string]];
    }
}

- (id)coerceValueForTextContents:(id)value {
    if ([value isKindOfClass:[NSScriptObjectSpecifier class]])
        value = [(NSScriptObjectSpecifier *)value objectsByEvaluatingSpecifier];
    return [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:value toClass:[NSTextStorage class]];
}

- (id)richText {
    return nil;
}

- (NSData *)boundsAsQDRect {
    return [NSData dataWithRectAsQDRect:[self bounds]];
}

- (void)setBoundsAsQDRect:(NSData *)inQDBoundsAsData {
    if ([self isMovable] && [self isEditable]) {
        NSRect newBounds = [inQDBoundsAsData rectValueAsQDRect];
        if ([self isResizable] == NO) {
            newBounds.size = [self bounds].size;
        } else if ([[self type] isEqualToString:SKNInkString]) {
            CGFloat margin = [self pathInset];
            NSRect bounds = [self bounds];
            
            if (NSWidth(newBounds) < 2.0 * margin)
                newBounds.size.width = 2.0 * margin;
            if (NSHeight(newBounds) < 2.0 * margin)
                newBounds.size.height = 2.0 * margin;
            
            if (NSEqualSizes(bounds.size, newBounds.size) == NO) {
                NSMutableArray *paths = [NSMutableArray array];
                NSAffineTransform *transform = [NSAffineTransform transform];
                [transform translateXBy:margin yBy:margin];
                [transform scaleXBy:fmax(1.0, NSWidth(newBounds) - 2.0 * margin) / fmax(1.0, NSWidth(bounds) - 2.0 * margin) yBy:fmax(1.0, NSHeight(newBounds) - 2.0 * margin) / fmax(1.0, NSHeight(bounds) - 2.0 * margin)];
                [transform translateXBy:-margin yBy:-margin];
                
                for (NSBezierPath *path in [self paths])
                    [paths addObject:[transform transformBezierPath:path]];
                
                [self setBezierPaths:paths];
            }
        } else {
            if (NSWidth(newBounds) < 0.0)
                newBounds.size.width = 0.0;
            if (NSHeight(newBounds) < 0.0)
                newBounds.size.height = 0.0;
        }
        [self setBounds:newBounds];
    }
}

- (NSColor *)scriptingInteriorColor {
    return [self interiorColor];
}

- (void)setScriptingInteriorColor:(NSColor *)color {
    if ([self isEditable] && [self hasInteriorColor]) {
        [self setInteriorColor:color];
    }
}

- (NSString *)fontName {
    if ([[self type] isEqualToString:SKNFreeTextString]) {
        return [[self font] fontName];
    } else {
        return nil;
    }
}

- (void)setFontName:(NSString *)fontName {
    if ([self isEditable] && [[self type] isEqualToString:SKNFreeTextString]) {
        NSFont *font = [NSFont fontWithName:fontName size:[[self font] pointSize]];
        if (font)
            [self setFont:font];
    }
}

- (CGFloat)fontSize {
    if ([[self type] isEqualToString:SKNFreeTextString]) {
        return [[self font] pointSize];
    } else {
        return 0.0;
    }
}

- (void)setFontSize:(CGFloat)pointSize {
    if ([self isEditable] && [[self type] isEqualToString:SKNFreeTextString]) {
        NSFont *font = [NSFont fontWithName:[[self font] fontName] size:pointSize];
        if (font)
            [self setFont:font];
    }
}

- (NSColor *)scriptingFontColor {
    if ([[self type] isEqualToString:SKNFreeTextString]) {
        return [self fontColor];
    } else {
        return nil;
    }
}

- (void)setScriptingFontColor:(NSColor *)newScriptingFontColor {
    if ([self isEditable] && [[self type] isEqualToString:SKNFreeTextString]) {
        [self setFontColor:newScriptingFontColor];
    }
}

- (NSInteger)scriptingAlignment {
    if ([[self type] isEqualToString:SKNFreeTextString]) {
        return alignmentFromTextAlignment([self alignment]);
    } else {
        return NSTextAlignmentLeft;
    }
}

- (void)setScriptingAlignment:(NSInteger)alignment {
    if ([self isEditable] && [[self type] isEqualToString:SKNFreeTextString]) {
        [self setAlignment:textAlignmentFromAlignment(alignment)];
    }
}

- (NSData *)startPointAsQDPoint {
    if ([[self type] isEqualToString:SKNLineString]) {
        NSRect bounds = [self bounds];
        NSPoint startPoint = SKAddPoints([self startPoint], bounds.origin);
        startPoint.x = floor(startPoint.x);
        startPoint.y = floor(startPoint.y);
        return [NSData dataWithPointAsQDPoint:startPoint];
    } else {
        return nil;
    }
}

- (void)setStartPointAsQDPoint:(NSData *)inQDPointAsData {
    if ([self isEditable] && [[self type] isEqualToString:SKNLineString] && inQDPointAsData && [inQDPointAsData isEqual:[NSNull null]] == NO) {
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

- (NSData *)endPointAsQDPoint {
    if ([[self type] isEqualToString:SKNLineString]) {
        NSRect bounds = [self bounds];
        NSPoint endPoint = SKAddPoints([self endPoint], bounds.origin);
        endPoint.x = floor(endPoint.x);
        endPoint.y = floor(endPoint.y);
        return [NSData dataWithPointAsQDPoint:endPoint];
    } else {
        return nil;
    }
}

- (void)setEndPointAsQDPoint:(NSData *)inQDPointAsData {
    if ([self isEditable] && [[self type] isEqualToString:SKNLineString] && inQDPointAsData && [inQDPointAsData isEqual:[NSNull null]] == NO) {
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

- (PDFLineStyle)scriptingStartLineStyle {
    if ([[self type] isEqualToString:SKNLineString]) {
        return [self startLineStyle];
    } else {
        return kPDFLineStyleNone;
    }
}

- (void)setScriptingStartLineStyle:(PDFLineStyle)style {
    if ([self isEditable] && [[self type] isEqualToString:SKNLineString]) {
        [self setStartLineStyle:style];
    }
}

- (PDFLineStyle)scriptingEndLineStyle {
    if ([[self type] isEqualToString:SKNLineString]) {
        return [self endLineStyle];
    } else {
        return kPDFLineStyleNone;
    }
}

- (void)setScriptingEndLineStyle:(PDFLineStyle)style {
    if ([self isEditable] && [[self type] isEqualToString:SKNLineString]) {
        [self setEndLineStyle:style];
    }
}

- (id)selectionSpecifier {
    if ([self isMarkup]) {
        PDFSelection *sel = [self selection];
        return [sel hasCharacters] ? [sel objectSpecifiers] : @[];
    } else {
        return nil;
    }
}

- (NSArray *)scriptingPointLists {
    if ([[self type] isEqualToString:SKNInkString]) {
        NSPoint origin = [self bounds].origin;
        NSMutableArray *pointLists = [NSMutableArray array];
        NSMutableArray *pointValues;
        NSPoint point;
        NSInteger i, iMax;
        for (NSBezierPath *path in [self paths]) {
            iMax = [path elementCount];
            pointValues = [[NSMutableArray alloc] initWithCapacity:iMax];
            for (i = 0; i < iMax; i++) {
                NSPoint p[3];
                point = NSCurveToBezierPathElement == [path elementAtIndex:i associatedPoints:p] ? p[2] : p[0];
                [pointValues addObject:[NSData dataWithPointAsNSPoint:SKAddPoints(point, origin)]];
            }
            [pointLists addObject:pointValues];
        }
        return pointLists;
    } else if ([self isMarkup]) {
        NSPoint origin = [self bounds].origin;
        NSMutableArray *pointLists = [NSMutableArray array];
        NSMutableArray *pointValues;
        NSPoint point;
        NSInteger i, j, iMax = [[self quadrilateralPoints] count] / 4;
        for (i = 0; i < iMax; i++) {
            pointValues = [[NSMutableArray alloc] initWithCapacity:iMax];
            for (j = 0; j < 4; j++) {
                point = [[[self quadrilateralPoints] objectAtIndex:4 * i + j] pointValue];
                [pointValues addObject:[NSData dataWithPointAsNSPoint:SKAddPoints(point, origin)]];
            }
            [pointLists addObject:pointValues];
        }
        return pointLists;
    } else {
        return nil;
    }
}

- (SKPDFView *)containingPdfView {
    NSDocument *doc = [[self page] containingDocument];
    return [doc isPDFDocument] ? [(SKMainDocument *)doc pdfView] : nil;
}

- (void)handleEditScriptCommand:(NSScriptCommand *)command {
    if ([self isEditable]) {
        [[self containingPdfView] editAnnotation:self];
    }
}

- (BOOL)accessibilityPerformPress {
    if ([self isSkimNote] == NO)
        return NO;
    SKPDFView *pdfView = [self containingPdfView];
    [pdfView editAnnotation:self];
    return pdfView != nil;
}

- (BOOL)accessibilityPerformPick {
    if ([self isSkimNote] == NO)
        return NO;
    SKPDFView *pdfView = [self containingPdfView];
    [pdfView setCurrentAnnotation:self];
    return pdfView != nil;
}

- (BOOL)accessibilityPerformShowMenu {
    if ([self isSkimNote] == NO)
        return NO;
    SKPDFView *pdfView = [self containingPdfView];
    if (pdfView == nil)
        return NO;
    NSPoint point = SKCenterPoint([pdfView convertRect:[self bounds] fromPage:[self page]]);
    NSEvent *event = [NSEvent mouseEventWithType:NSEventTypeRightMouseDown
                                        location:[pdfView convertPoint:point toView:nil]
                                   modifierFlags:0
                                       timestamp:0
                                    windowNumber:[[pdfView window] windowNumber]
                                         context:nil
                                     eventNumber:0
                                      clickCount:1
                                        pressure:0.0];
    NSMenu *menu = [pdfView menuForEvent:event];
    [NSMenu popUpContextMenu:menu withEvent:event forView:pdfView];
    return YES;
}

@end
