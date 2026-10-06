//
//  PDFAnnotation_SKNExtensions.m
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

#import "PDFAnnotation_SKNExtensions.h"
#import <tgmath.h>

#ifdef PDFKIT_PLATFORM_IOS

#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>

#define SKNMakePoint(x, y)          CGPointMake(x, y)
#define SKNPointFromString(string)  CGPointFromString(string)
#define SKNStringFromPoint(point)   NSStringFromCGPoint(point)
#define SKNRectFromString(string)   CGRectFromString(string)
#define SKNStringFromRect(point)    NSStringFromCGRect(point)
#define SKNPointFromValue(value)    [value CGPointValue]

#else

#import <objc/objc-runtime.h>

#ifndef PDFKitPlatformColor
#define PDFKitPlatformColor         NSColor
#endif
#ifndef PDFKitPlatformFont
#define PDFKitPlatformFont          NSFont
#endif
#ifndef PDFPoint
#define PDFPoint                    NSPoint
#endif
#ifndef PDFPointZero
#define PDFPointZero                NSZeroPoint
#endif
#ifndef PDFRectZero
#define PDFRectZero                 NSZeroRect
#endif

#define SKNMakePoint(x, y)          NSMakePoint(x, y)
#define SKNPointFromString(string)  NSPointFromString(string)
#define SKNStringFromPoint(point)   NSStringFromPoint(point)
#define SKNRectFromString(string)   NSRectFromString(string)
#define SKNStringFromRect(point)    NSStringFromRect(point)
#define SKNPointFromValue(value)    [value pointValue]

#endif

NSString * const SKNFreeTextString = @"FreeText";
NSString * const SKNTextString = @"Text";
NSString * const SKNStampString = @"Stamp";
NSString * const SKNNoteString = @"Note";
NSString * const SKNCircleString = @"Circle";
NSString * const SKNSquareString = @"Square";
NSString * const SKNMarkUpString = @"MarkUp";
NSString * const SKNHighlightString = @"Highlight";
NSString * const SKNUnderlineString = @"Underline";
NSString * const SKNStrikeOutString = @"StrikeOut";
NSString * const SKNLineString = @"Line";
NSString * const SKNInkString = @"Ink";
NSString * const SKNWidgetString = @"Widget";

NSString * const SKNPDFAnnotationTypeKey = @"type";
NSString * const SKNPDFAnnotationBoundsKey = @"bounds";
NSString * const SKNPDFAnnotationPageKey = @"page";
NSString * const SKNPDFAnnotationPageIndexKey = @"pageIndex";
NSString * const SKNPDFAnnotationContentsKey = @"contents";
NSString * const SKNPDFAnnotationStringKey = @"string";
NSString * const SKNPDFAnnotationColorKey = @"color";
NSString * const SKNPDFAnnotationBorderKey = @"border";
NSString * const SKNPDFAnnotationLineWidthKey = @"lineWidth";
NSString * const SKNPDFAnnotationBorderStyleKey = @"borderStyle";
NSString * const SKNPDFAnnotationDashPatternKey = @"dashPattern";
NSString * const SKNPDFAnnotationModificationDateKey = @"modificationDate";
NSString * const SKNPDFAnnotationUserNameKey = @"userName";

NSString * const SKNPDFAnnotationInteriorColorKey = @"interiorColor";

NSString * const SKNPDFAnnotationStartLineStyleKey = @"startLineStyle";
NSString * const SKNPDFAnnotationEndLineStyleKey = @"endLineStyle";
NSString * const SKNPDFAnnotationStartPointKey = @"startPoint";
NSString * const SKNPDFAnnotationEndPointKey = @"endPoint";

NSString * const SKNPDFAnnotationFontKey = @"font";
NSString * const SKNPDFAnnotationFontColorKey = @"fontColor";
NSString * const SKNPDFAnnotationFontNameKey = @"fontName";
NSString * const SKNPDFAnnotationFontSizeKey = @"fontSize";
NSString * const SKNPDFAnnotationAlignmentKey = @"alignment";
NSString * const SKNPDFAnnotationRotationKey = @"rotation";

NSString * const SKNPDFAnnotationQuadrilateralPointsKey = @"quadrilateralPoints";

NSString * const SKNPDFAnnotationIconTypeKey = @"iconType";

NSString * const SKNPDFAnnotationNameKey = @"name";

NSString * const SKNPDFAnnotationPointListsKey = @"pointLists";

NSString * const SKNPDFAnnotationStringValueKey = @"stringValue";
NSString * const SKNPDFAnnotationStateKey = @"state";
NSString * const SKNPDFAnnotationWidgetTypeKey = @"widgetType";
NSString * const SKNPDFAnnotationFieldNameKey = @"fieldName";

NSString * const SKNPDFAnnotationTextKey = @"text";
NSString * const SKNPDFAnnotationImageKey = @"image";
NSString * const SKNPDFAnnotationDrawsImageKey = @"drawsImage";

const PDFSize SKNPDFAnnotationNoteSize = {16.0, 16.0};

#define SKNSquigglyString @"Squiggly"

static PDFKitPlatformColor *SKNColorFromArray(NSArray *array) {
    if ([array count] > 2) {
        CGFloat c[4] = {0.0, 0.0, 0.0, 1.0};
        NSUInteger i;
        for (i = 0; i < MAX([array count], 4); i++)
            c[i] = [[array objectAtIndex:i] doubleValue];
#ifdef PDFKIT_PLATFORM_IOS
        return [UIColor colorWithRed:c[0] green:c[1] blue:c[2] alpha:c[3]];
#else
        return [NSColor colorWithColorSpace:[NSColorSpace sRGBColorSpace] components:c count:4];
#endif
    } else if ([array count] > 0) {
        CGFloat c[2] = {0.0, 1.0};
        c[0] = [[array objectAtIndex:0] doubleValue];
        if ([array count] == 2)
            c[1] = [[array objectAtIndex:1] doubleValue];
#ifdef PDFKIT_PLATFORM_IOS
        return [UIColor colorWithWhite:c[0] alpha:c[1]];
#else
        return [NSColor colorWithColorSpace:[NSColorSpace genericGamma22GrayColorSpace] components:c count:2];
#endif
    } else {
        return [PDFKitPlatformColor clearColor];
    }
}

#if defined(PDFKIT_PLATFORM_IOS) || (defined(MAC_OS_X_VERSION_10_11) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_11)

static inline NSInteger SKNAlignmentFromTextAlignment(NSTextAlignment alignment) {
    return alignment == NSTextAlignmentCenter ? 2 : alignment == NSTextAlignmentRight ? 1 : 0;
}

static inline NSTextAlignment SKNTextAlignmentFromAlignment(NSInteger alignment) {
    return alignment == 2 ? NSTextAlignmentCenter : alignment == 1 ? NSTextAlignmentRight : NSTextAlignmentLeft;
}

#else

static inline NSInteger SKNAlignmentFromTextAlignment(NSTextAlignment alignment) {
    return alignment == NSCenterTextAlignment ? 2 : alignment == NSRightTextAlignment ? 1 : 0;
}

static inline NSTextAlignment SKNTextAlignmentFromAlignment(NSInteger alignment) {
    return alignment == 2 ? NSCenterTextAlignment : alignment == 1 ? NSRightTextAlignment : NSLeftTextAlignment;
}

#endif

#ifndef PDFKIT_PLATFORM_IOS

#if !defined(MAC_OS_X_VERSION_10_12) || MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_12
@interface PDFAnnotation (SKNSierraDeclarations)
- (id)valueForAnnotationKey:(NSString *)key;
- (BOOL)setValue:(id)value forAnnotationKey:(NSString *)key;
- (void)removeValueForAnnotationKey:(NSString *)key;
- (void)drawWithBox:(PDFDisplayBox)box inContext:(CGContextRef)context;
@end
@interface PDFPage (SKNSierraDeclarations)
- (void)transformContext:(CGContextRef)context forBox:(PDFDisplayBox)box;
@end
#endif

#if !defined(MAC_OS_X_VERSION_10_13) || MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_13
@interface PDFAnnotation (SKNHighSierraDeclarations)
- (NSString *)stampName;
- (NSString *)widgetFieldType;
- (NSInteger)buttonWidgetState;
- (NSString *)widgetStringValue;
@end
#endif

@interface PDFAnnotation (SKNPrivateDeclarations)
- (NSString *)widgetOnStateString;
@end

#endif

static inline PDFKitPlatformImage *appearanceImageForAnnotation(PDFAnnotation *annotation);

static inline NSArray *quadrilateralPointsFromPointStrings(NSArray *pointStrings);

#pragma mark -

#ifdef SKIMNOTES_USE_LEGACY_PDFANNOTATION_SUBCLASSES

@interface PDFAnnotationCircle (SKNExtensions)
@end

@interface PDFAnnotationSquare (SKNExtensions)
@end

@interface PDFAnnotationLine (SKNExtensions)
@end

@interface PDFAnnotationFreeText (SKNExtensions)
@end

@interface PDFAnnotationMarkup (SKNExtensions)
@end

@interface PDFAnnotationInk (SKNExtensions)
@end

@interface PDFAnnotationText (SKNExtensions)
@end

@interface PDFAnnotationStamp (SKNExtensions)
@end

@interface PDFAnnotationTextWidget (SKNExtensions)
@end

@interface PDFAnnotationButtonWidget (SKNExtensions)
@end

@interface PDFAnnotationChoiceWidget (SKNExtensions)
@end

static inline Class SKNAnnotationClassForWidgetType(SKNPDFWidgetType widgetType) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    switch (widgetType) {
        case kSKNPDFWidgetTypeText: return [PDFAnnotationTextWidget class];
        case kSKNPDFWidgetTypeButton: return [PDFAnnotationButtonWidget class];
        case kSKNPDFWidgetTypeChoice: return [PDFAnnotationChoiceWidget class];
        default: return Nil;
    }
#pragma clang diagnostic pop
}

#elif !defined(PDFKIT_PLATFORM_IOS) && (!defined(MAC_OS_X_VERSION_10_13) || MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_13)

#error "Deployment target before macOS 10.13 not supported without legacy PDFAnnotation classes"

#endif

static BOOL isMarkupType(NSString *type) {
    static NSSet *markupTypes = nil;
    if (markupTypes == nil)
        markupTypes = [[NSSet alloc] initWithObjects:SKNHighlightString, SKNUnderlineString, SKNStrikeOutString, SKNMarkUpString, SKNSquigglyString, nil];
    return [markupTypes containsObject:type];
}

static BOOL isNoteType(NSString *type) {
    static NSSet *noteTypes = nil;
    if (noteTypes == nil)
        noteTypes = [[NSSet alloc] initWithObjects:SKNNoteString, SKNTextString, SKNStampString, nil];
    return [noteTypes containsObject:type];
}

static inline Class SKNAnnotationClassForType(NSString *type) {
    if ([type isKindOfClass:[NSString class]] == NO)
        return Nil;
    else if (isNoteType(type))
        return [SKNPDFAnnotationNote class];
#ifndef SKIMNOTES_USE_LEGACY_PDFANNOTATION_SUBCLASSES
    else
        return [PDFAnnotation class];
#else
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    else if ([type isEqualToString:SKNFreeTextString])
        return [PDFAnnotationFreeText class];
    else if ([type isEqualToString:SKNCircleString])
        return [PDFAnnotationCircle class];
    else if ([type isEqualToString:SKNSquareString])
        return [PDFAnnotationSquare class];
    else if (isMarkupType(type]))
        return [PDFAnnotationMarkup class];
    else if ([type isEqualToString:SKNLineString])
        return [PDFAnnotationLine class];
    else if ([type isEqualToString:SKNInkString])
        return [PDFAnnotationInk class];
    else
        return Nil;
#pragma clang diagnostic pop
#endif
}

#pragma mark -

@implementation PDFAnnotation (SKNExtensions)

char SKNIsSkimNoteKey;

- (id)initSkimNoteWithBounds:(PDFRect)bounds forType:(NSString *)type {
    if ([type hasPrefix:@"/"])
        type = [type substringFromIndex:1];
    
    if ([self isMemberOfClass:[PDFAnnotation class]]) {
        // possibly replace by a subclass
        Class annotationClass = SKNAnnotationClassForType(type);
        if ([self isMemberOfClass:annotationClass] == NO) {
            self = [self init];
            self = [[annotationClass alloc] initSkimNoteWithBounds:bounds forType:type];
            return self;
        }
    } else if ([self isKindOfClass:[SKNPDFAnnotationNote class]] && [type isEqualToString:SKNNoteString]) {
        // set Text as the type in the annotationDictionary to fool PDFKit
        type = SKNTextString;
    }
    
#ifndef SKIMNOTES_USE_LEGACY_PDFANNOTATION_SUBCLASSES
    
    self = [self initWithBounds:bounds forType:[@"/" stringByAppendingString:type] withProperties:nil];
    if (self) {
        [self setShouldPrint:YES];
        [self setSkimNote:YES];
        [self setUserName:nil];
    }
    
#else
    
    self = [self initSkimNoteWithBounds:bounds];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([self isKindOfClass:[PDFAnnotationMarkup class]]) {
#pragma clang diagnostic pop
        NSInteger markupType = kPDFMarkupTypeHighlight;
        if ([type isEqualToString:SKNUnderlineString] || [type isEqualToString:SKNSquigglyString])
            markupType = kPDFMarkupTypeUnderline;
        else if ([type isEqualToString:SKNStrikeOutString])
            markupType = kPDFMarkupTypeStrikeOut;
        [(id)self setMarkupType:markupType];
        if ([[self class] respondsToSelector:@selector(defaultSkimNoteColorForMarkupType:)]) {
            NSColor *color = [[self class] defaultSkimNoteColorForMarkupType:markupType];
            if (color)
                [self setColor:color];
        }
    }
    
#endif
    
    if ([self respondsToSelector:@selector(setDefaultSkimNoteProperties)])
        [self setDefaultSkimNoteProperties];
    
    return self;
}

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    Class stringClass = [NSString class];
    NSString *type = [dict objectForKey:SKNPDFAnnotationTypeKey];
    
    if ([self isMemberOfClass:[PDFAnnotation class]]) {
        // possibly replace by a subclass
        Class annotationClass = SKNAnnotationClassForType(type);
#ifdef SKIMNOTES_USE_LEGACY_PDFANNOTATION_SUBCLASSES
        if (annotationClass == Nil && [type isEqualToString:SKNWidgetString])
            annotationClass = SKNAnnotationClassForWidgetType([[dict objectForKey:SKNPDFAnnotationWidgetTypeKey] integerValue]);
#endif
        if ([self isMemberOfClass:annotationClass] == NO) {
            self = [self init];
            self = [[annotationClass alloc] initSkimNoteWithProperties:dict];
            return self;
        }
    }
    
    NSString *boundsString = [dict objectForKey:SKNPDFAnnotationBoundsKey];
    PDFRect bounds = [boundsString isKindOfClass:stringClass] ? SKNRectFromString(boundsString) : PDFRectZero;
    self = [self initSkimNoteWithBounds:bounds forType:type];
    if (self) {
        Class colorClass = [PDFKitPlatformColor class];
        Class arrayClass = [NSArray class];
        Class dateClass = [NSDate class];
        NSString *contents = [dict objectForKey:SKNPDFAnnotationContentsKey];
        PDFKitPlatformColor *color = [dict objectForKey:SKNPDFAnnotationColorKey];
        NSDate *modificationDate = [dict objectForKey:SKNPDFAnnotationModificationDateKey];
        NSString *userName = [dict objectForKey:SKNPDFAnnotationUserNameKey];
        NSNumber *lineWidth = [dict objectForKey:SKNPDFAnnotationLineWidthKey];
        NSNumber *borderStyle = [dict objectForKey:SKNPDFAnnotationBorderStyleKey];
        NSArray *dashPattern = [dict objectForKey:SKNPDFAnnotationDashPatternKey];
        
        if ([contents isKindOfClass:stringClass])
            [self setString:contents];
        if ([color isKindOfClass:colorClass])
            [self setColor:color];
        else if ([color isKindOfClass:arrayClass])
            [self setColor:SKNColorFromArray((NSArray *)color)];
        if ([modificationDate isKindOfClass:dateClass])
            [self setModificationDate:modificationDate];
        if ([userName isKindOfClass:stringClass])
            [self setUserName:userName];
        if (lineWidth || borderStyle || dashPattern) {
            if ([borderStyle respondsToSelector:@selector(integerValue)] == NO)
                borderStyle = nil;
            if ([self border] == nil)
                [self setBorder:[[PDFBorder alloc] init]];
            if ([lineWidth respondsToSelector:@selector(doubleValue)])
                [[self border] setLineWidth:[lineWidth doubleValue]];
            if ([dashPattern isKindOfClass:arrayClass])
                [[self border] setDashPattern:dashPattern];
            else if ([borderStyle integerValue] == kPDFBorderStyleDashed)
                [[self border] setDashPattern:[NSArray array]];
            else
                [[self border] setDashPattern:nil];
            if (borderStyle)
                [[self border] setStyle:[borderStyle integerValue]];
        } else if ([self border]) {
            [self setBorder:nil];
            // On 10.12 a border with lineWith 1 is inserted, so set its lineWidth to 0
            [[self border] setLineWidth:0.0];
        }
        
#ifndef SKIMNOTES_USE_LEGACY_PDFANNOTATION_SUBCLASSES
        
        color = [dict objectForKey:SKNPDFAnnotationInteriorColorKey];
        if ([color isKindOfClass:colorClass])
            [self setInteriorColor:color];
        else if ([color isKindOfClass:arrayClass])
            [self setInteriorColor:SKNColorFromArray((NSArray *)color)];
        
        if ([type isEqualToString:SKNLineString]) {
            
            NSString *startPoint = [dict objectForKey:SKNPDFAnnotationStartPointKey];
            NSString *endPoint = [dict objectForKey:SKNPDFAnnotationEndPointKey];
            NSNumber *startLineStyle = [dict objectForKey:SKNPDFAnnotationStartLineStyleKey];
            NSNumber *endLineStyle = [dict objectForKey:SKNPDFAnnotationEndLineStyleKey];
            if ([startPoint isKindOfClass:stringClass])
                [self setStartPoint:SKNPointFromString(startPoint)];
            if ([endPoint isKindOfClass:stringClass])
                [self setEndPoint:SKNPointFromString(endPoint)];
            if ([startLineStyle respondsToSelector:@selector(integerValue)])
                [self setStartLineStyle:[startLineStyle integerValue]];
            if ([endLineStyle respondsToSelector:@selector(integerValue)])
                [self setEndLineStyle:[endLineStyle integerValue]];
            
        } else if ([type isEqualToString:SKNFreeTextString]) {
            
            Class fontClass = [PDFKitPlatformFont class];
            PDFKitPlatformFont *font = [dict objectForKey:SKNPDFAnnotationFontKey];
            PDFKitPlatformColor *fontColor = [dict objectForKey:SKNPDFAnnotationFontColorKey];
            NSNumber *alignment = [dict objectForKey:SKNPDFAnnotationAlignmentKey];
            if (font == nil) {
                NSString *fontName = [dict objectForKey:SKNPDFAnnotationFontNameKey];
                NSNumber *fontSize = [dict objectForKey:SKNPDFAnnotationFontSizeKey];
                if ([fontName isKindOfClass:[NSString class]])
                    font = [PDFKitPlatformFont fontWithName:fontName size:[fontSize respondsToSelector:@selector(doubleValue)] ? [fontSize doubleValue] : 0.0];
            }
            if ([font isKindOfClass:fontClass])
                [self setFont:font];
            if ([fontColor isKindOfClass:colorClass])
                [self setFontColor:fontColor];
            else if ([fontColor isKindOfClass:arrayClass])
                [self setFontColor:SKNColorFromArray((NSArray *)fontColor)];
            if ([alignment respondsToSelector:@selector(integerValue)])
                [self setAlignment:SKNTextAlignmentFromAlignment([alignment integerValue])];
            
        } else if (isMarkupType(type)) {
            
            NSArray *pointStrings = [dict objectForKey:SKNPDFAnnotationQuadrilateralPointsKey];
            if ([pointStrings isKindOfClass:arrayClass])
                [self setQuadrilateralPoints:quadrilateralPointsFromPointStrings(pointStrings)];
            
        } else if ([type isEqualToString:SKNInkString]) {
            
            NSArray *pointLists = [dict objectForKey:SKNPDFAnnotationPointListsKey];
            if ([pointLists isKindOfClass:arrayClass]) {
                for (NSArray *pointStrings in pointLists) {
                    if ([pointStrings isKindOfClass:arrayClass]) {
                        PDFKitPlatformBezierPath *path = [[PDFKitPlatformBezierPath alloc] init];
                        [[self class] setPoints:pointStrings ofSkimNotePath:path];
                        [self addBezierPath:path];
                    }
                }
            }
            
        } else if (isNoteType(type)) {
            
            NSString *name = [dict objectForKey:SKNPDFAnnotationNameKey];
            NSNumber *iconType = [dict objectForKey:SKNPDFAnnotationIconTypeKey];
            if ([iconType respondsToSelector:@selector(integerValue)])
                [self setIconType:[iconType integerValue]];
            if ([name isKindOfClass:stringClass])
                [self setStampName:name];
            
        } else if ([type isEqualToString:SKNWidgetString]) {
            
            SKNPDFWidgetType widgetType = [[dict objectForKey:SKNPDFAnnotationWidgetTypeKey] integerValue];
            NSString *fieldName = [dict objectForKey:SKNPDFAnnotationFieldNameKey];
            NSString *stringValue = [dict objectForKey:SKNPDFAnnotationStringValueKey];
            NSNumber *state = [dict objectForKey:SKNPDFAnnotationStateKey];
            switch (widgetType) {
                case kSKNPDFWidgetTypeText:
                    [self setWidgetFieldType:PDFAnnotationWidgetSubtypeText];
                    break;
                case kSKNPDFWidgetTypeButton:
                    [self setWidgetFieldType:PDFAnnotationWidgetSubtypeButton];
                    break;
                case kSKNPDFWidgetTypeChoice:
                    [self setWidgetFieldType:PDFAnnotationWidgetSubtypeChoice];
                    break;
                default:
                    break;
            }
            if ([fieldName isKindOfClass:stringClass])
                [self setFieldName:fieldName];
            if ([stringValue isKindOfClass:stringClass])
                [self setWidgetStringValue:stringValue];
            if ([state respondsToSelector:@selector(integerValue)])
                [self setButtonWidgetState:[state integerValue]];
            [self setModificationDate:nil];
            
        }
        
#endif
    }
    return self;
}

- (NSMutableDictionary *)genericSkimNoteProperties{
    PDFPage *page = [self page];
    NSUInteger pageIndex = page ? [[page document] indexForPage:page] : NSNotFound;
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:5];
    [dict setValue:[self type] forKey:SKNPDFAnnotationTypeKey];
    [dict setValue:[self string] forKey:SKNPDFAnnotationContentsKey];
    [dict setValue:[self color] forKey:SKNPDFAnnotationColorKey];
    [dict setValue:[self modificationDate] forKey:SKNPDFAnnotationModificationDateKey];
    [dict setValue:[self userName] forKey:SKNPDFAnnotationUserNameKey];
    [dict setValue:SKNStringFromRect([self bounds]) forKey:SKNPDFAnnotationBoundsKey];
    [dict setValue:[NSNumber numberWithUnsignedInteger:pageIndex == NSNotFound ? 0 : pageIndex] forKey:SKNPDFAnnotationPageIndexKey];
    if ([self border] && [[self border] lineWidth] > 0.0) {
        [dict setValue:[NSNumber numberWithDouble:[[self border] lineWidth]] forKey:SKNPDFAnnotationLineWidthKey];
        [dict setValue:[NSNumber numberWithInteger:[[self border] style]] forKey:SKNPDFAnnotationBorderStyleKey];
        [dict setValue:[[self border] dashPattern] forKey:SKNPDFAnnotationDashPatternKey];
    }
    return dict;
}

static PDFKitPlatformColor *SKNColorFromAnnotationValue(id value) {
    if ([value isKindOfClass:[PDFKitPlatformColor class]])
        return value;
    else if ([value isKindOfClass:[NSArray class]] == NO || [value count] == 0)
        return nil;
#ifdef PDFKIT_PLATFORM_IOS
    CGFloat c[5] = {0.0, 1.0, 0.0, 1.0, 1.0};
    NSUInteger i;
    for (i = 0; i < MIN([value count], 4); i++)
        c[i] = [[value objectAtIndex:i] doubleValue];
    CGColorSpaceRef cs = [value count] < 3 ? CGColorSpaceCreateDeviceGray() : [value count] < 4 ? CGColorSpaceCreateDeviceRGB() : CGColorSpaceCreateDeviceCMYK();
    CGColorRef cgColor = CGColorCreate(cs, c);
    UIColor *color = [UIColor colorWithCGColor:cgColor];
    CGColorRelease(cgColor);
    CGColorSpaceRelease(cs);
    return color;
#else
    if ([value count] < 3)
        return [NSColor colorWithDeviceWhite:[[value objectAtIndex:0] doubleValue] alpha:1.0];
    else if ([value count] < 4)
        return [NSColor colorWithDeviceRed:[[value objectAtIndex:0] doubleValue] green:[[value objectAtIndex:1] doubleValue] blue:[[value objectAtIndex:2] doubleValue] alpha:1.0];
    else
        return [NSColor colorWithDeviceCyan:[[value objectAtIndex:0] doubleValue] magenta:[[value objectAtIndex:1] doubleValue] yellow:[[value objectAtIndex:2] doubleValue] black:[[value objectAtIndex:3] doubleValue] alpha:1.0];
#endif
}

static inline PDFTextAnnotationIconType SKNIconTypeFromAnnotationValue(id value) {
    if ([value isKindOfClass:[NSString class]] == NO)
        return kPDFTextAnnotationIconNote;
    else if ([value isEqualToString:@"/Comment"])
        return kPDFTextAnnotationIconComment;
    else if ([value isEqualToString:@"/Key"])
        return kPDFTextAnnotationIconKey;
    else if ([value isEqualToString:@"/Note"])
        return kPDFTextAnnotationIconNote;
    else if ([value isEqualToString:@"/Help"])
        return kPDFTextAnnotationIconHelp;
    else if ([value isEqualToString:@"/NewParagraph"])
        return kPDFTextAnnotationIconNewParagraph;
    else if ([value isEqualToString:@"/Paragraph"])
        return kPDFTextAnnotationIconParagraph;
    else if ([value isEqualToString:@"/Insert"])
        return kPDFTextAnnotationIconInsert;
    else
        return kPDFTextAnnotationIconNote;
}

static inline PDFLineStyle SKNPDFLineStyleFromAnnotationValue(id value) {
    if ([value isKindOfClass:[NSString class]] == NO)
        return kPDFLineStyleNone;
    else if ([value isEqualToString:@"/None"])
        return kPDFLineStyleNone;
    else if ([value isEqualToString:@"/Square"])
        return kPDFLineStyleSquare;
    else if ([value isEqualToString:@"/Circle"])
        return kPDFLineStyleCircle;
    else if ([value isEqualToString:@"/Diamond"])
        return kPDFLineStyleDiamond;
    else if ([value isEqualToString:@"/OpenArrow"])
        return kPDFLineStyleOpenArrow;
    else if ([value isEqualToString:@"/ClosedArrow"])
        return kPDFLineStyleClosedArrow;
    else
        return kPDFLineStyleNone;
}

static inline SKNPDFWidgetType SKNPDFWidgetTypeFromAnnotationValue(id value) {
    if ([value isKindOfClass:[NSString class]] == NO)
        return kSKNPDFWidgetTypeUnknown;
    else if ([value isEqualToString:@"/Tx"])
        return kSKNPDFWidgetTypeText;
    else if ([value isEqualToString:@"/Btn"])
        return kSKNPDFWidgetTypeButton;
    else if ([value isEqualToString:@"/Ch"])
        return kSKNPDFWidgetTypeChoice;
    else
        return kSKNPDFWidgetTypeUnknown;
}

- (NSDictionary *)SkimNoteProperties{
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    
    if ([self respondsToSelector:@selector(valueForAnnotationKey:)]) {
        
        NSString *type = [self type];
        id value = nil;
        Class arrayClass = [NSArray class];
        Class stringClass = [NSString class];
        
        if ([type isEqualToString:SKNCircleString] || [type isEqualToString:SKNSquareString] || [type isEqualToString:SKNLineString]) {
            
            PDFKitPlatformColor *color = nil;
            if ([self respondsToSelector:@selector(interiorColor)])
                color = [(id)self interiorColor];
            if (color == nil && (value = [self valueForAnnotationKey:@"/IC"]))
                color = SKNColorFromAnnotationValue(value);
            if (color)
                [dict setValue:color forKey:SKNPDFAnnotationInteriorColorKey];
            
            if ([type isEqualToString:SKNLineString]) {
                
                if ([self respondsToSelector:@selector(startLineStyle)] && [self respondsToSelector:@selector(endLineStyle)]) {
                    [dict setValue:[NSNumber numberWithInteger:[(id)self startLineStyle]] forKey:SKNPDFAnnotationStartLineStyleKey];
                    [dict setValue:[NSNumber numberWithInteger:[(id)self endLineStyle]] forKey:SKNPDFAnnotationStartLineStyleKey];
                } else if ((value = [self valueForAnnotationKey:@"/LE"])) {
                    if ([value isKindOfClass:arrayClass] && [value count] == 2) {
                        [dict setValue:[NSNumber numberWithInteger:SKNPDFLineStyleFromAnnotationValue([value objectAtIndex:0])] forKey:SKNPDFAnnotationStartLineStyleKey];
                        [dict setValue:[NSNumber numberWithInteger:SKNPDFLineStyleFromAnnotationValue([value objectAtIndex:1])] forKey:SKNPDFAnnotationEndLineStyleKey];
                    }
                }
                
                if ([self respondsToSelector:@selector(startPoint)] && [self respondsToSelector:@selector(endPoint)]) {
                    [dict setValue:SKNStringFromPoint([(id)self startPoint]) forKey:SKNPDFAnnotationStartPointKey];
                    [dict setValue:SKNStringFromPoint([(id)self endPoint]) forKey:SKNPDFAnnotationEndPointKey];
                } else if ((value = [self valueForAnnotationKey:@"/L"])) {
                    if ([value isKindOfClass:arrayClass] && [value count] == 4) {
                        PDFRect bounds = [self bounds];
                        PDFPoint p = SKNMakePoint([[value objectAtIndex:0] doubleValue] - bounds.origin.x, [[value objectAtIndex:1] doubleValue] - bounds.origin.y);
                        [dict setValue:SKNStringFromPoint(p) forKey:SKNPDFAnnotationStartPointKey];
                        p = SKNMakePoint([[value objectAtIndex:2] doubleValue] - bounds.origin.x, [[value objectAtIndex:3] doubleValue] - bounds.origin.y);
                        [dict setValue:SKNStringFromPoint(p) forKey:SKNPDFAnnotationEndPointKey];
                    }
                }
                
            }
            
        } else if ([type isEqualToString:SKNFreeTextString]) {
            
            if ([self respondsToSelector:@selector(alignment)]) {
                [dict setValue:[NSNumber numberWithInteger:SKNAlignmentFromTextAlignment([(id)self alignment])] forKey:SKNPDFAnnotationAlignmentKey];
            } else if ((value = [self valueForAnnotationKey:@"/Q"])) {
                [dict setValue:[NSNumber numberWithInteger:SKNAlignmentFromTextAlignment([value integerValue])] forKey:SKNPDFAnnotationAlignmentKey];
            }
            
            PDFKitPlatformFont *font = nil;
            if ([self respondsToSelector:@selector(font)])
                font = [(id)self font];
            PDFKitPlatformColor *fontColor = nil;
            if ([self respondsToSelector:@selector(fontColor)])
                fontColor = [(id)self fontColor];
            if ((font == nil || fontColor == nil) && (value = [self valueForAnnotationKey:@"/DA"])) {
                NSScanner *scanner = [[NSScanner alloc] initWithString:value];
                if (font == nil) {
                    if ([scanner scanUpToString:@"Tf" intoString:NULL] && [scanner isAtEnd] == NO) {
                        NSUInteger location = [scanner scanLocation];
                        NSRange r = [value rangeOfString:@"/" options:NSBackwardsSearch range:NSMakeRange(0, location)];
                        if (r.location != NSNotFound) {
                            NSString *fontName;
                            double fontSize;
                            [scanner setScanLocation:NSMaxRange(r)];
                            if ([scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&fontName] &&
                                [scanner scanDouble:&fontSize] &&
                                [scanner scanString:@"Tf" intoString:NULL] &&
                                [scanner scanLocation] == location + 2) {
                                font = [PDFKitPlatformFont fontWithName:fontName size:fontSize];
                            }
                        }
                    }
                }
                if (fontColor == nil) {
                    NSUInteger end = [value rangeOfString:@"rg"].location;
                    if (end == NSNotFound) {
                        end = [value rangeOfString:@"g"].location;
                        if (end == NSNotFound)
                            end = [value rangeOfString:@"k"].location;
                    }
                    if (end != NSNotFound) {
                        NSCharacterSet *numberChars = [NSCharacterSet characterSetWithCharactersInString:@"0123456789. "];
                        NSUInteger start = end;
                        while (start > 0 && [numberChars characterIsMember:[value characterAtIndex:start--]]) {}
                        if (start < end) {
                            [scanner setScanLocation:start];
                            CGFloat c;
                            NSMutableArray *array = [NSMutableArray array];
                            while ([scanner scanDouble:&c])
                                [array addObject:[NSNumber numberWithDouble:c]];
                            fontColor = SKNColorFromArray(array);
                        }
                    }
                }
                
            }
            if (font)
                [dict setValue:font forKey:SKNPDFAnnotationFontKey];
            if (fontColor)
                [dict setValue:fontColor forKey:SKNPDFAnnotationFontColorKey];
            
        } else if (isMarkupType(type)) {
            
            if ([self respondsToSelector:@selector(quadrilateralPoints)]) {
                NSArray *quadPoints = [(id)self quadrilateralPoints];
                if (quadPoints) {
                    NSMutableArray *quadPointStrings = [[NSMutableArray alloc] initWithCapacity:[quadPoints count]];
                    for (NSValue *pointValue in quadPoints)
                        [quadPointStrings addObject:SKNStringFromPoint(SKNPointFromValue(pointValue))];
                    [dict setValue:quadPointStrings forKey:SKNPDFAnnotationQuadrilateralPointsKey];
                }
            } else if ((value = [self valueForAnnotationKey:@"/QuadPoints"])) {
                if ([value isKindOfClass:arrayClass] && [value count] % 4 == 0) {
                    PDFRect bounds = [self bounds];
                    Class numberClass = [NSNumber class];
                    Class valueClass = [NSValue class];
                    NSMutableArray *quadPoints = [NSMutableArray array];
                    NSUInteger i, iMax = [value count];
                    for (i = 0; i < iMax; i++) {
                        NSValue *val = [value objectAtIndex:i];
                        PDFPoint p;
                        if ([val isKindOfClass:numberClass])
                            p = SKNMakePoint([(NSNumber *)val doubleValue], [(NSNumber *)[value objectAtIndex:++i] doubleValue]);
                        else if ([val isKindOfClass:valueClass])
                            p = SKNPointFromValue(val);
                        else
                            continue;
                        p.x -= bounds.origin.x;
                        p.y -= bounds.origin.y;
                        [quadPoints addObject:SKNStringFromPoint(p)];
                    }
                    [dict setValue:quadPoints forKey:SKNPDFAnnotationQuadrilateralPointsKey];
                }
            }
            
        } else if ([type isEqualToString:SKNInkString]) {
            
            if ([self respondsToSelector:@selector(paths)]) {
                NSArray *paths = [(id)self paths];
                if (paths) {
                    Class selfClass = [self class];
                    NSMutableArray *pointLists = [[NSMutableArray alloc] initWithCapacity:[paths count]];
                    for (PDFKitPlatformBezierPath *path in paths) {
                        NSArray *pointStrings = [selfClass pointsFromSkimNotePath:path];
                        if ([pointStrings count])
                            [pointLists addObject:pointStrings];
                    }
                    [dict setValue:pointLists forKey:SKNPDFAnnotationPointListsKey];
                }
                
           } else if ((value = [self valueForAnnotationKey:@"/Inklist"])) {
               
                if ([value isKindOfClass:arrayClass]) {
                    Class pathClass = [PDFKitPlatformBezierPath class];
                    Class numberClass = [NSNumber class];
                    Class valueClass = [NSValue class];
                    NSMutableArray *pointLists = [NSMutableArray array];
                    for (id path in value) {
                        NSMutableArray *points = [NSMutableArray array];
                        if ([path isKindOfClass:pathClass]) {
                            [points addObjectsFromArray:[[self class] pointsFromSkimNotePath:path]];
                        } else if ([path isKindOfClass:arrayClass]) {
                            PDFRect bounds = [self bounds];
                            NSUInteger i, iMax = [path count];
                            for (i = 0; i < iMax; i++) {
                                NSValue *val = [path objectAtIndex:i];
                                PDFPoint p;
                                if ([val isKindOfClass:numberClass])
                                    p = SKNMakePoint([(NSNumber *)val doubleValue], [(NSNumber *)[value objectAtIndex:++i] doubleValue]);
                                else if ([val isKindOfClass:valueClass])
                                    p = SKNPointFromValue(val);
                                else
                                    continue;
                                p.x -= bounds.origin.x;
                                p.y -= bounds.origin.y;
                                [points addObject:SKNStringFromPoint(p)];
                            }
                        }
                        [pointLists addObject:points];
                    }
                    [dict setValue:pointLists forKey:SKNPDFAnnotationPointListsKey];
                }
            }
            
        } else if (isNoteType(type)) {
            
            value = [self valueForAnnotationKey:@"/SkimContents"];
            if ([value isKindOfClass:stringClass]) {
                NSString *contents = [self contents];
                if ([contents hasPrefix:value] && [contents length] > [value length] + 1) {
                    NSUInteger i = [value length];
                    while (i < [contents length] && [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[contents characterAtIndex:i]])
                        ++i;
                    if (i < [contents length] && i > [value length]) {
                        [dict setValue:value forKey:SKNPDFAnnotationContentsKey];
                        [dict setValue:[[NSAttributedString alloc] initWithString:[contents substringFromIndex:i]] forKey:SKNPDFAnnotationTextKey];
                    }
                }
            }
            
            if ([type isEqualToString:SKNStampString]) {
                
                if ([self respondsToSelector:@selector(stampName)])
                    value = [self stampName];
                else
                    value = [self valueForAnnotationKey:@"/Name"];
                if (value) {
                    [dict setValue:value forKey:SKNPDFAnnotationNameKey];
                    if ([[NSSet setWithObjects:@"/Comment", @"/Key", @"/Note", @"/Help", @"/NewParagraph", @"/Paragraph", @"/Insert", nil] containsObject:value]) {
                        if ([self respondsToSelector:@selector(iconType)])
                            [dict setValue:[NSNumber numberWithInteger:[(id)self iconType]] forKey:SKNPDFAnnotationIconTypeKey];
                        else
                            [dict setValue:[NSNumber numberWithInteger:SKNIconTypeFromAnnotationValue(value)] forKey:SKNPDFAnnotationIconTypeKey];
                    }
                }
                [dict setValue:appearanceImageForAnnotation(self) forKey:SKNPDFAnnotationImageKey];
                
            } else {
                
                if ([self respondsToSelector:@selector(iconType)])
                    [dict setValue:[NSNumber numberWithInteger:[(id)self iconType]] forKey:SKNPDFAnnotationIconTypeKey];
                else if ((value = [self valueForAnnotationKey:@"/Name"]))
                    [dict setValue:[NSNumber numberWithInteger:SKNIconTypeFromAnnotationValue(value)] forKey:SKNPDFAnnotationIconTypeKey];
                
            }
            
        } else if ([type isEqualToString:SKNWidgetString]) {
            
            [dict removeObjectsForKeys:[NSArray arrayWithObjects:SKNPDFAnnotationContentsKey, SKNPDFAnnotationColorKey, SKNPDFAnnotationModificationDateKey, SKNPDFAnnotationUserNameKey, nil]];
            
            SKNPDFWidgetType widgetType = kSKNPDFWidgetTypeUnknown;
            if ([self respondsToSelector:@selector(widgetFieldType)]) {
                widgetType = SKNPDFWidgetTypeFromAnnotationValue([self widgetFieldType]);
            } else if ((value = [self valueForAnnotationKey:@"/FT"])) {
                widgetType = SKNPDFWidgetTypeFromAnnotationValue(value);
            }
            [dict setValue:[NSNumber numberWithInteger:widgetType] forKey:SKNPDFAnnotationWidgetTypeKey];
            
            NSString *fieldName = nil;
            if ([self respondsToSelector:@selector(fieldName)])
                fieldName = [(id)self fieldName];
            if (fieldName == nil && (value = [self valueForAnnotationKey:@"/T"]) && [value isKindOfClass:stringClass])
                fieldName = value;
            if (fieldName)
                [dict setValue:fieldName forKey:SKNPDFAnnotationFieldNameKey];
            
            if (widgetType == kSKNPDFWidgetTypeButton) {
                if ([self respondsToSelector:@selector(buttonWidgetState)])
                    [dict setValue:[NSNumber numberWithInteger:[self buttonWidgetState]] forKey:SKNPDFAnnotationStateKey];
                else if ((value = [self valueForAnnotationKey:@"/V"]))
                    [dict setValue:[NSNumber numberWithInteger:[value isEqualToString:@"Off"] ? 0 : 1] forKey:SKNPDFAnnotationStateKey];
            } else {
                if ([self respondsToSelector:@selector(widgetStringValue)])
                    [dict setValue:[self widgetStringValue] forKey:SKNPDFAnnotationStringValueKey];
                else if ((value = [self valueForAnnotationKey:@"/V"]))
                    [dict setValue:value forKey:SKNPDFAnnotationStringValueKey];
            }
            
        }
        
    }
    
    return dict;
}

- (BOOL)isSkimNote {
    return [objc_getAssociatedObject(self, &SKNIsSkimNoteKey) boolValue];
}

- (void)setSkimNote:(BOOL)flag {
    objc_setAssociatedObject(self, &SKNIsSkimNoteKey, flag ? [NSNumber numberWithBool:YES] : nil, OBJC_ASSOCIATION_RETAIN);
}

- (NSString *)string {
#if defined(PDFKIT_PLATFORM_IOS) || (defined(MAC_OS_X_VERSION_10_13) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_13 && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_10)
    if (@available(macOS 27.0, iOS 27.0, *)) {
        if (isMarkupType([self type])) {
            return [self valueForAnnotationKey:@"/SkimContents"] ?: [self contents];
        }
    }
#endif
    if ([[self type] isEqualToString:SKNWidgetString] == NO) {
        return [self contents];
    } else if ([self respondsToSelector:@selector(valueForAnnotationKey:)]) {
        SKNPDFWidgetType widgetType;
        if ([self respondsToSelector:@selector(widgetFieldType)])
            widgetType = SKNPDFWidgetTypeFromAnnotationValue([self widgetFieldType]);
        else
            widgetType = SKNPDFWidgetTypeFromAnnotationValue([self valueForAnnotationKey:@"/FT"]);
        if (widgetType == kSKNPDFWidgetTypeButton) {
            if ([self respondsToSelector:@selector(buttonWidgetState)])
                return [NSString stringWithFormat:@"%ld", (long)[self buttonWidgetState]];
            else
                return [[self valueForAnnotationKey:@"/V"] isEqual:@"Off"] ? @"0" : @"1";
        } else {
            if ([self respondsToSelector:@selector(widgetStringValue)])
                return [self widgetStringValue];
            else
                return [self valueForAnnotationKey:@"/V"];
        }
    }
    return nil;
}

- (void)setString:(NSString *)string {
#if defined(PDFKIT_PLATFORM_IOS) || (defined(MAC_OS_X_VERSION_10_13) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_13 && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_10)
    if (@available(macOS 27.0, iOS 27.0, *)) {
        if (isMarkupType([self type])) {
            if (string)
                [self setValue:[string copy] forAnnotationKey:@"/SkimContents"];
            else
                [self removeValueForAnnotationKey:@"/SkimContents"];
            return;
        }
    }
#endif
    if ([[self type] isEqualToString:SKNWidgetString] == NO) {
        [self setContents:string];
    } else if ([self respondsToSelector:@selector(setValue:forAnnotationKey:)]) {
        SKNPDFWidgetType widgetType;
        if ([self respondsToSelector:@selector(widgetFieldType)])
            widgetType = SKNPDFWidgetTypeFromAnnotationValue([self widgetFieldType]);
        else
            widgetType = SKNPDFWidgetTypeFromAnnotationValue([self valueForAnnotationKey:@"/FT"]);
        if (widgetType == kSKNPDFWidgetTypeButton) {
            if ([self respondsToSelector:@selector(setButtonWidgetState:)])
                [self setButtonWidgetState:[string integerValue]];
            else if ([string boolValue] == NO)
                [self setValue:@"Off" forAnnotationKey:@"/V"];
            else if ([self respondsToSelector:@selector(widgetOnStateString)])
                [self setValue:[self widgetOnStateString] forAnnotationKey:@"/V"];
            else
                [self setValue:@"On" forAnnotationKey:@"/V"];
        } else {
            if ([self respondsToSelector:@selector(setWidgetStringValue:)])
                [self setWidgetStringValue:string];
            else if (string)
                [self setValue:string forAnnotationKey:@"/V"];
            else
                [self removeValueForAnnotationKey:@"/V"];
        }
    }
}

+ (NSArray *)pointsFromSkimNotePath:(PDFKitPlatformBezierPath *)path {
    NSMutableArray *points = [NSMutableArray array];
#ifdef PDFKIT_PLATFORM_IOS
    CGPathApplyWithBlock([path CGPath], ^(const CGPathElement *element){
        CGPoint *p = element->points;
        NSUInteger i = 0;
        switch (element->type) {
            case kCGPathElementAddQuadCurveToPoint: i = 1; break;
            case kCGPathElementAddCurveToPoint: i = 2; break;
            case kCGPathElementCloseSubpath: return;
            default: i = 0; break;
        }
        [points addObject:NSStringFromCGPoint(p[i])];
    });
#else
    NSInteger i, iMax = [path elementCount];
    for (i = 0; i < iMax; i++) {
        NSPoint p[3];
        NSUInteger j = 0;
        if (NSCurveToBezierPathElement == [path elementAtIndex:i associatedPoints:p])
            j = 2;
        [points addObject:NSStringFromPoint(p[j])];
    }
#endif
    return points;
}

+ (void)setPoints:(NSArray *)points ofSkimNotePath:(PDFKitPlatformBezierPath *)path {
    [path removeAllPoints];
    
    Class stringClass = [NSString class];
    Class valueClass = [NSValue class];
    NSUInteger i, iMax = [points count];
    PDFPoint point, controlPoint1, diff;
    CGFloat d2;
    BOOL wasEdge = YES;
    
    for (i = 0; i < iMax; i++) {
        id pointValue = [points objectAtIndex:i];
        PDFPoint prevPoint = point;
        point = [pointValue isKindOfClass:stringClass] ? SKNPointFromString(pointValue) : [pointValue isKindOfClass:valueClass] ? SKNPointFromValue(pointValue) : PDFPointZero;
        
        if (i == 0) {
            [path moveToPoint:point];
        } else if (i == 1) {
            diff.x = point.x - prevPoint.x;
            diff.y = point.y - prevPoint.y;
            d2 = sqrt(diff.x * diff.x + diff.y * diff.y);
            controlPoint1 = prevPoint;
        } else {
            PDFPoint diff1, controlPoint2;
            CGFloat d0, d1;
            
            diff1 = diff;
            d1 = d2;
            
            diff.x = point.x - prevPoint.x;
            diff.y = point.y - prevPoint.y;
            d2 = sqrt(diff.x * diff.x + diff.y * diff.y);
            
            controlPoint2 = prevPoint;
            if (d1 > 0.0 && d2 > 0.0) {
                diff1.x = d2 * diff1.x + d1 * diff.x;
                diff1.y = d2 * diff1.y + d1 * diff.y;
                d0 = sqrt(d1 * d2);
                
                controlPoint2.x -= diff1.x / (3.0 * (d0 + d2));
                controlPoint2.y -= diff1.y / (3.0 * (d0 + d2));
            }
            
#ifdef PDFKIT_PLATFORM_IOS
            if (d1 <= 0.0 || (d2 <= 0 && wasEdge))
                [path addLineToPoint:prevPoint];
            else
                [path addCurveToPoint:prevPoint controlPoint1:controlPoint1 controlPoint2:controlPoint2];
#else
            if (d1 <= 0.0 || (d2 <= 0 && wasEdge))
                [path lineToPoint:prevPoint];
            else
                [path curveToPoint:prevPoint controlPoint1:controlPoint1 controlPoint2:controlPoint2];
#endif
            
            controlPoint1 = prevPoint;
            if (d1 > 0.0 && d2 > 0.0) {
                controlPoint1.x += diff1.x / (3.0 * (d0 + d1));
                controlPoint1.y += diff1.y / (3.0 * (d0 + d1));
            }
            
            wasEdge = d1 <= 0.0;
        }
    }
    
#ifdef PDFKIT_PLATFORM_IOS
    if (iMax == 2 || d2 <= 0.0 || wasEdge)
        [path addLineToPoint:point];
    else if (iMax > 2)
        [path addCurveToPoint:point controlPoint1:controlPoint1 controlPoint2:point];
#else
    if (iMax == 2 || d2 <= 0.0 || wasEdge)
        [path lineToPoint:point];
    else if (iMax > 2)
        [path curveToPoint:point controlPoint1:controlPoint1 controlPoint2:point];
#endif
}

+ (void)addPoint:(PDFPoint)point toSkimNotesPath:(PDFKitPlatformBezierPath *)path {
#ifdef PDFKIT_PLATFORM_IOS
    NSMutableArray *points = [NSMutableArray array];
    
    CGPathApplyWithBlock([path CGPath], ^(const CGPathElement *element){
        CGPoint *p = element->points;
        NSUInteger i = 0;
        switch (element->type) {
            case kCGPathElementAddQuadCurveToPoint: i = 1; break;
            case kCGPathElementAddCurveToPoint: i = 2; break;
            case kCGPathElementCloseSubpath: return;
            default: i = 0; break;
        }
        [points addObject:[NSValue valueWithCGPoint:p[i]]];
    });
    
    [points addObject:[NSValue valueWithCGPoint:point]];
    
    [self setPoints:points ofSkimNotePath:path];
#else
    NSUInteger count = [path elementCount];
    
    if (count == 0) {
        
        [path moveToPoint:point];
        
    } else if (count == 1) {
        
        [path lineToPoint:point];
        
    } else {
        
        NSBezierPathElement elt;
        NSPoint points[3];
        NSPoint diff1, diff2, controlPoint, point0, point1;
        CGFloat d0, d1, d2;
        
        elt = [path elementAtIndex:count - 2 associatedPoints:points];
        point0 = elt == NSCurveToBezierPathElement ? points[2] : points[0];
        
        elt = [path elementAtIndex:count - 1 associatedPoints:points];
        point1 = elt == NSCurveToBezierPathElement ? points[2] : points[0];
        
        diff1.x = point1.x - point0.x;
        diff1.y = point1.y - point0.y;
        d1 = sqrt(diff1.x * diff1.x + diff1.y * diff1.y);
        
        diff2.x = point.x - point1.x;
        diff2.y = point.y - point1.y;
        d2 = sqrt(diff2.x * diff2.x + diff2.y * diff2.y);
        
        controlPoint = point1;
        if (d1 > 0.0 && d2 > 0.0) {
            diff1.x = d2 * diff1.x + d1 * diff2.x;
            diff1.y = d2 * diff1.y + d1 * diff2.y;
            d0 = sqrt(d1 * d2);
            
            controlPoint.x -= diff1.x / (3.0 * (d0 + d2));
            controlPoint.y -= diff1.y / (3.0 * (d0 + d2));
        }
         
        if (elt == NSCurveToBezierPathElement) {
            points[1] = controlPoint;
            [path setAssociatedPoints:points atIndex:count - 1];
        } else if (count == 2 && d1 > 0.0) {
            [path removeAllPoints];
            [path moveToPoint:point0];
            [path curveToPoint:point1 controlPoint1:point0 controlPoint2:controlPoint];
        }
        
        controlPoint = point1;
        if (d1 > 0.0 && d2 > 0.0) {
            controlPoint.x += diff1.x / (3.0 * (d0 + d1));
            controlPoint.y += diff1.y / (3.0 * (d0 + d1));
        }
        
        if (d2 > 0.0)
            [path curveToPoint:point controlPoint1:controlPoint controlPoint2:point];
        else
            [path lineToPoint:point];
        
    }
#endif
}

@end

#pragma mark -

#ifdef SKIMNOTES_USE_LEGACY_PDFANNOTATION_SUBCLASSES

@implementation PDFAnnotation (SKNLegacyExtensions)

- (id)initSkimNoteWithBounds:(NSRect)bounds {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    self = [self initWithBounds:bounds];
#pragma clang diagnostic pop
    if (self) {
        [self setShouldPrint:YES];
        [self setSkimNote:YES];
        [self setUserName:nil];
    }
    return self;
}

@end

#pragma mark -

@implementation PDFAnnotationCircle (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class colorClass = [NSColor class];
        Class arrayClass = [NSArray class];
        NSColor *interiorColor = [dict objectForKey:SKNPDFAnnotationInteriorColorKey];
        if ([interiorColor isKindOfClass:colorClass])
            [self setInteriorColor:interiorColor];
        else if ([interiorColor isKindOfClass:arrayClass])
            [self setInteriorColor:SKNColorFromArray((NSArray *)interiorColor)];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties{
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    [dict setValue:[self interiorColor] forKey:SKNPDFAnnotationInteriorColorKey];
    return dict;
}

- (NSString *)string {
    return [self contents];
}

- (void)setString:(NSString *)string {
    [self setContents:string];
}

@end

#pragma mark -

@implementation PDFAnnotationSquare (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class colorClass = [NSColor class];
        Class arrayClass = [NSArray class];
        NSColor *interiorColor = [dict objectForKey:SKNPDFAnnotationInteriorColorKey];
        if ([interiorColor isKindOfClass:colorClass])
            [self setInteriorColor:interiorColor];
        else if ([interiorColor isKindOfClass:arrayClass])
            [self setInteriorColor:SKNColorFromArray((NSArray *)interiorColor)];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties{
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    [dict setValue:[self interiorColor] forKey:SKNPDFAnnotationInteriorColorKey];
    return dict;
}

- (NSString *)string {
    return [self contents];
}

- (void)setString:(NSString *)string {
    [self setContents:string];
}

@end

#pragma mark -

@implementation PDFAnnotationLine (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class stringClass = [NSString class];
        Class colorClass = [NSColor class];
        Class arrayClass = [NSArray class];
        NSString *startPoint = [dict objectForKey:SKNPDFAnnotationStartPointKey];
        NSString *endPoint = [dict objectForKey:SKNPDFAnnotationEndPointKey];
        NSNumber *startLineStyle = [dict objectForKey:SKNPDFAnnotationStartLineStyleKey];
        NSNumber *endLineStyle = [dict objectForKey:SKNPDFAnnotationEndLineStyleKey];
        NSColor *interiorColor = [dict objectForKey:SKNPDFAnnotationInteriorColorKey];
        if ([startPoint isKindOfClass:stringClass])
            [self setStartPoint:NSPointFromString(startPoint)];
        if ([endPoint isKindOfClass:stringClass])
            [self setEndPoint:NSPointFromString(endPoint)];
        if ([startLineStyle respondsToSelector:@selector(integerValue)])
            [self setStartLineStyle:[startLineStyle integerValue]];
        if ([endLineStyle respondsToSelector:@selector(integerValue)])
            [self setEndLineStyle:[endLineStyle integerValue]];
        if ([interiorColor isKindOfClass:colorClass])
            [self setInteriorColor:interiorColor];
        else if ([interiorColor isKindOfClass:arrayClass])
            [self setInteriorColor:SKNColorFromArray((NSArray *)interiorColor)];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties {
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    [dict setValue:[NSNumber numberWithInteger:[self startLineStyle]] forKey:SKNPDFAnnotationStartLineStyleKey];
    [dict setValue:[NSNumber numberWithInteger:[self endLineStyle]] forKey:SKNPDFAnnotationEndLineStyleKey];
    [dict setValue:NSStringFromPoint([self startPoint]) forKey:SKNPDFAnnotationStartPointKey];
    [dict setValue:NSStringFromPoint([self endPoint]) forKey:SKNPDFAnnotationEndPointKey];
    [dict setValue:[self interiorColor] forKey:SKNPDFAnnotationInteriorColorKey];
    return dict;
}

- (NSString *)string {
    return [self contents];
}

- (void)setString:(NSString *)string {
    [self setContents:string];
}

@end

#pragma mark -

@implementation PDFAnnotationFreeText (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class fontClass = [NSFont class];
        Class colorClass = [NSColor class];
        Class arrayClass = [NSArray class];
        NSFont *font = [dict objectForKey:SKNPDFAnnotationFontKey];
        NSColor *fontColor = [dict objectForKey:SKNPDFAnnotationFontColorKey];
        NSNumber *alignment = [dict objectForKey:SKNPDFAnnotationAlignmentKey];
        if (font == nil) {
            NSString *fontName = [dict objectForKey:SKNPDFAnnotationFontNameKey];
            NSNumber *fontSize = [dict objectForKey:SKNPDFAnnotationFontSizeKey];
            if ([fontName isKindOfClass:[NSString class]])
                font = [NSFont fontWithName:fontName size:[fontSize respondsToSelector:@selector(doubleValue)] ? [fontSize doubleValue] : 0.0];
        }
        if ([font isKindOfClass:fontClass])
            [self setFont:font];
        if ([fontColor isKindOfClass:colorClass])
            [self setFontColor:fontColor];
        else if ([fontColor isKindOfClass:arrayClass])
            [self setFontColor:SKNColorFromArray((NSArray *)fontColor)];
        if ([alignment respondsToSelector:@selector(integerValue)])
            [self setAlignment:SKNTextAlignmentFromAlignment([alignment integerValue])];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties{
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    NSColor *fontColor = [self fontColor];
    [dict setValue:[self font] forKey:SKNPDFAnnotationFontKey];
    if ([[fontColor colorSpace] colorSpaceModel] != NSGrayColorSpaceModel || [fontColor whiteComponent] > 0.0 || [fontColor alphaComponent] < 1.0)
        [dict setValue:fontColor forKey:SKNPDFAnnotationFontColorKey];
    [dict setValue:[NSNumber numberWithInteger:SKNAlignmentFromTextAlignment([self alignment])] forKey:SKNPDFAnnotationAlignmentKey];
    return dict;
}

- (NSString *)string {
    return [self contents];
}

- (void)setString:(NSString *)string {
    [self setContents:string];
}

@end

#pragma mark -

@implementation PDFAnnotationMarkup (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class arrayClass = [NSArray class];
        NSArray *pointStrings = [dict objectForKey:SKNPDFAnnotationQuadrilateralPointsKey];
        if ([pointStrings isKindOfClass:arrayClass])
            [self setQuadrilateralPoints:quadrilateralPointsFromPointStrings(pointStrings)];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties {
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    NSArray *quadPoints = [self quadrilateralPoints];
    if (quadPoints) {
        NSMutableArray *quadPointStrings = [[NSMutableArray alloc] initWithCapacity:[quadPoints count]];
        for (NSValue *quadPoint in quadPoints)
            [quadPointStrings addObject:NSStringFromPoint([quadPoint pointValue])];
        [dict setValue:quadPointStrings forKey:SKNPDFAnnotationQuadrilateralPointsKey];
    }
    return dict;
}

- (NSString *)string {
#if defined(PDFKIT_PLATFORM_IOS) || (defined(MAC_OS_X_VERSION_10_13) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_13 && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_10)
    if (@available(macOS 27.0, iOS 27.0, *))
        return [self valueForAnnotationKey:@"/SkimContents"] ?: [self contents];
    else
#endif
        return [self contents];
}

- (void)setString:(NSString *)string {
#if defined(PDFKIT_PLATFORM_IOS) || (defined(MAC_OS_X_VERSION_10_13) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_13 && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_10)
    if (@available(macOS 27.0, iOS 27.0, *)) {
        if (string)
            [self setValue:[string copy] forAnnotationKey:@"/SkimContents"];
        else
            [self removeValueForAnnotationKey:@"/SkimContents"];
    } else
#endif
        [self setContents:string];
}

@end

#pragma mark -

@implementation PDFAnnotationInk (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class arrayClass = [NSArray class];
        Class selfClass = [self class];
        NSArray *pointLists = [dict objectForKey:SKNPDFAnnotationPointListsKey];
        if ([pointLists isKindOfClass:arrayClass]) {
            for (NSArray *pointStrings in pointLists) {
                if ([pointStrings isKindOfClass:arrayClass]) {
                    NSBezierPath *path = [[NSBezierPath alloc] init];
                    [selfClass setPoints:pointStrings ofSkimNotePath:path];
                    [self addBezierPath:path];
                }
            }
        }
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties{
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    NSArray *paths = [self paths];
    if (paths) {
        Class selfClass = [self class];
        NSMutableArray *pointLists = [[NSMutableArray alloc] initWithCapacity:[paths count]];
        for (NSBezierPath *path in paths) {
            NSArray *pointStrings = [selfClass pointsFromSkimNotePath:path];
            if ([pointStrings count])
                [pointLists addObject:pointStrings];
        }
        [dict setValue:pointLists forKey:SKNPDFAnnotationPointListsKey];
    }
    return dict;
}

- (NSString *)string {
    return [self contents];
}

- (void)setString:(NSString *)string {
    [self setContents:string];
}

@end

#pragma mark -

@implementation PDFAnnotationText (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        NSNumber *iconType = [dict objectForKey:SKNPDFAnnotationIconTypeKey];
        if ([iconType respondsToSelector:@selector(integerValue)])
            [self setIconType:[iconType integerValue]];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties{
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    [dict setValue:[NSNumber numberWithInteger:[self iconType]] forKey:SKNPDFAnnotationIconTypeKey];
    return dict;
}

- (NSString *)string {
    return [self contents];
}

- (void)setString:(NSString *)string {
    [self setContents:string];
}

@end

#pragma mark -

@implementation PDFAnnotationStamp (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class stringClass = [NSString class];
        NSString *name = [dict objectForKey:SKNPDFAnnotationNameKey];
        if ([name isKindOfClass:stringClass])
            [self setName:name];
        NSNumber *iconType = [dict objectForKey:SKNPDFAnnotationIconTypeKey];
        if ([iconType respondsToSelector:@selector(integerValue)] && [self respondsToSelector:@selector(setIconType:)])
            [self setIconType:[iconType integerValue]];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties{
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    NSString *name = [self name];
    [dict setValue:name forKey:SKNPDFAnnotationNameKey];
    if (name && [[NSSet setWithObjects:@"/Comment", @"/Key", @"/Note", @"/Help", @"/NewParagraph", @"/Paragraph", @"/Insert", nil] containsObject:name] && [self respondsToSelector:@selector(iconType)])
        [dict setValue:[NSNumber numberWithInteger:[self iconType]] forKey:SKNPDFAnnotationIconTypeKey];
    [dict setValue:appearanceImageForAnnotation(self) forKey:SKNPDFAnnotationImageKey];
    return dict;
}

- (NSString *)string {
    return [self contents];
}

- (void)setString:(NSString *)string {
    [self setContents:string];
}

@end

#pragma mark -

@implementation PDFAnnotationTextWidget (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class stringClass = [NSString class];
        NSString *stringValue = [dict objectForKey:SKNPDFAnnotationStringValueKey];
        if ([stringValue isKindOfClass:stringClass])
            [self setStringValue:stringValue];
        [self setModificationDate:nil];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties {
    PDFPage *page = [self page];
    NSUInteger pageIndex = page ? [[page document] indexForPage:page] : NSNotFound;
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:5];
    [dict setValue:[self type] forKey:SKNPDFAnnotationTypeKey];
    [dict setValue:NSStringFromRect([self bounds]) forKey:SKNPDFAnnotationBoundsKey];
    [dict setValue:[NSNumber numberWithUnsignedInteger:pageIndex == NSNotFound ? 0 : pageIndex] forKey:SKNPDFAnnotationPageIndexKey];
    [dict setValue:[NSNumber numberWithInteger:kSKNPDFWidgetTypeText] forKey:SKNPDFAnnotationWidgetTypeKey];
    [dict setValue:[self fieldName] forKey:SKNPDFAnnotationFieldNameKey];
    [dict setValue:[self stringValue] forKey:SKNPDFAnnotationStringValueKey];
    return dict;
}

- (NSString *)string {
    return [self stringValue];
}

- (void)setString:(NSString *)string {
    [self setStringValue:string];
}

@end

#pragma mark -

@implementation PDFAnnotationButtonWidget (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        NSNumber *state = [dict objectForKey:SKNPDFAnnotationStateKey];
        if ([state respondsToSelector:@selector(integerValue)])
            [self setState:[state integerValue]];
        [self setModificationDate:nil];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties {
    PDFPage *page = [self page];
    NSUInteger pageIndex = page ? [[page document] indexForPage:page] : NSNotFound;
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:5];
    [dict setValue:[self type] forKey:SKNPDFAnnotationTypeKey];
    [dict setValue:NSStringFromRect([self bounds]) forKey:SKNPDFAnnotationBoundsKey];
    [dict setValue:[NSNumber numberWithUnsignedInteger:pageIndex == NSNotFound ? 0 : pageIndex] forKey:SKNPDFAnnotationPageIndexKey];
    [dict setValue:[NSNumber numberWithInteger:kSKNPDFWidgetTypeButton] forKey:SKNPDFAnnotationWidgetTypeKey];
    [dict setValue:[self fieldName] forKey:SKNPDFAnnotationFieldNameKey];
    [dict setValue:[NSNumber numberWithInteger:[self state]] forKey:SKNPDFAnnotationStateKey];
    return dict;
}

- (NSString *)string {
    return [NSString stringWithFormat:@"%ld", (long)[self state]];
}

- (void)setString:(NSString *)string {
    [self setState:[string integerValue]];
}

@end

#pragma mark -

@implementation PDFAnnotationChoiceWidget (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class stringClass = [NSString class];
        NSString *stringValue = [dict objectForKey:SKNPDFAnnotationStringValueKey];
        if ([stringValue isKindOfClass:stringClass])
            [self setStringValue:stringValue];
        [self setModificationDate:nil];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties {
    PDFPage *page = [self page];
    NSUInteger pageIndex = page ? [[page document] indexForPage:page] : NSNotFound;
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:5];
    [dict setValue:[self type] forKey:SKNPDFAnnotationTypeKey];
    [dict setValue:NSStringFromRect([self bounds]) forKey:SKNPDFAnnotationBoundsKey];
    [dict setValue:[NSNumber numberWithUnsignedInteger:pageIndex == NSNotFound ? 0 : pageIndex] forKey:SKNPDFAnnotationPageIndexKey];
    [dict setValue:[NSNumber numberWithInteger:kSKNPDFWidgetTypeChoice] forKey:SKNPDFAnnotationWidgetTypeKey];
    [dict setValue:[self fieldName] forKey:SKNPDFAnnotationFieldNameKey];
    [dict setValue:[self stringValue] forKey:SKNPDFAnnotationStringValueKey];
    return dict;
}

- (NSString *)string {
    return [self stringValue];
}

- (void)setString:(NSString *)string {
    [self setStringValue:string];
}

@end

#endif

#pragma mark -

#ifndef PDFKIT_PLATFORM_IOS
@interface SKNPDFAnnotationNote ()
@property (nonatomic, readonly) NSTextStorage *mutableText;
@property (nonatomic, strong, nullable) NSArray *texts;
@end
#endif

@implementation SKNPDFAnnotationNote

@synthesize text = _text;
@synthesize image = _image;
@dynamic drawsImage;
#ifndef PDFKIT_PLATFORM_IOS
@dynamic mutableText;
@synthesize texts = _texts;
#endif

- (void)updateContents {
    NSMutableString *contents = [NSMutableString string];
    NSString *string = [self string];
    if ([string length])
        [contents appendString:string];
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

- (BOOL)drawsImage {
#if !defined(MAC_OS_X_VERSION_10_12) || MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_12
    return _drawsImage;
#else
    return [[self valueForAnnotationKey:@"/Subtype"] isEqualToString:@"/Stamp"];
#endif
}

- (void)setDrawsImage:(BOOL)drawsImage {
#if !defined(MAC_OS_X_VERSION_10_12) || MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_12
    _drawsImage = drawsImage;
    if ([self respondsToSelector:@selector(setValue:forAnnotationKey:)])
#endif
    [self setValue:drawsImage ? @"/Stamp" : @"/Text" forAnnotationKey:@"/Subtype"];
}

- (NSString *)string {
#if !defined(MAC_OS_X_VERSION_10_12) || MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_12
    return _string;
#else
    return [self valueForAnnotationKey:@"/SkimContents"];
#endif
}

- (void)setString:(NSString *)string {
#if !defined(MAC_OS_X_VERSION_10_12) || MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_12
    _string = [string copy];
#else
    if (string)
        [self setValue:[string copy] forAnnotationKey:@"/SkimContents"];
    else
        [self removeValueForAnnotationKey:@"/SkimContents"];
#endif
    // update the contents to string + text
    [self updateContents];
}

#ifdef PDFKIT_PLATFORM_IOS

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

#if !defined(MAC_OS_X_VERSION_10_15) || MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_15
static inline void drawIcon(CGContextRef context, NSRect bounds, PDFTextAnnotationIconType iconType);
#define SKNAppKitVersionNumber10_12 1504
#define SKNAppKitVersionNumber10_14 1671
#endif

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

#pragma mark -

#ifdef PDFKIT_PLATFORM_IOS

static inline UIImage *appearanceImageForAnnotation(PDFAnnotation *annotation) {
    CGRect rect = [annotation bounds];
    if (CGRectIsEmpty(rect))
        return nil;
    BOOL needsRemove = NO;
    PDFPage *page = [annotation page];
    if (page == nil) {
        page = [[PDFPage alloc] init];
        [page setBounds:CGRectMake(0.0, 0.0, CGRectGetMaxX(rect), CGRectGetMaxY(rect)) forBox:kPDFDisplayBoxMediaBox];
        [page addAnnotation:annotation];
        needsRemove = YES;
    }
    CGRect bounds = [page boundsForBox:kPDFDisplayBoxMediaBox];
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:rect.size];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGContextRef *ctxt = [context CGContext];
        CGContextScaleCTM(ctxt, 1.0, -1.0);
        switch ([page rotation]) {
            case 0:
                CGContextTranslateCTM(ctxt, CGRectGetMinX(bounds) - CGRectGetMinX(rect), CGRectGetMinY(bounds) - CGRectGetMaxY(rect));
                break;
            case 90:
                CGContextTranslateCTM(ctxt, CGRectGetMaxX(bounds) - CGRectGetMinX(rect), CGRectGetMinY(bounds) - CGRectGetMaxY(rect));
                break;
            case 180:
                CGContextTranslateCTM(ctxt, CGRectGetMaxX(bounds) - CGRectGetMinX(rect), CGRectGetMaxY(bounds) - CGRectGetMaxY(rect));
                break;
            case 270:
                CGContextTranslateCTM(ctxt, CGRectGetMinX(bounds) - CGRectGetMinX(rect), CGRectGetMaxY(bounds) - CGRectGetMaxY(rect));
                break;
        }
        CGContextRotateCTM(ctx, [page rotation] * M_PI / 180.0);
        [annotation drawWithBox:kPDFDisplayBoxMediaBox inContext:ctxt];
    }];
    if (needsRmove)
        [page removeAnnotation:annotation];
    return image;
}

static inline NSArray *quadrilateralPointsFromPointStrings(NSArray *pointStrings) {
    NSMutableArray *quadPoints = [[NSMutableArray alloc] initWithCapacity:[pointStrings count]];
    for (NSString *pointString in pointStrings) {
        CGPoint p = CGPointFromString(pointString);
        [quadPoints addObject:[[NSValue alloc] initWithBytes:&p objCType:@encode(CGPoint)]];
    }
}

#else

static inline NSImage *appearanceImageForAnnotation(PDFAnnotation *annotation) {
    NSRect rect = [annotation bounds];
    if (NSIsEmptyRect(rect))
        return nil;
    BOOL needsRemove = NO;
    PDFPage *page = [annotation page];
    if (page == nil) {
        page = [[PDFPage alloc] init];
        [page setBounds:NSMakeRect(0.0, 0.0, NSMaxX(rect), NSMaxY(rect)) forBox:kPDFDisplayBoxMediaBox];
        [page addAnnotation:annotation];
        needsRemove = YES;
    }
    NSRect bounds = [page boundsForBox:kPDFDisplayBoxMediaBox];
    NSImage *image = [[NSImage alloc] initWithSize:rect.size];
    [image lockFocus];
    NSAffineTransform *transform = [NSAffineTransform transform];
    switch ([page rotation]) {
        case 0:   [transform translateXBy:NSMinX(bounds) - NSMinX(rect) yBy:NSMinY(bounds) - NSMinY(rect)]; break;
        case 90:  [transform translateXBy:NSMaxX(bounds) - NSMinX(rect) yBy:NSMinY(bounds) - NSMinY(rect)]; break;
        case 180: [transform translateXBy:NSMaxX(bounds) - NSMinX(rect) yBy:NSMaxY(bounds) - NSMinY(rect)]; break;
        case 270: [transform translateXBy:NSMinX(bounds) - NSMinX(rect) yBy:NSMaxY(bounds) - NSMinY(rect)]; break;
    }
    [transform rotateByDegrees:[page rotation]];
    [transform concat];
#if !defined(MAC_OS_X_VERSION_10_12) || MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_12
    if ([annotation respondsToSelector:@selector(drawWithBox:inContext:)])
        [annotation drawWithBox:kPDFDisplayBoxMediaBox inContext:[[NSGraphicsContext currentContext] graphicsPort]];
    else
        [annotation drawWithBox:kPDFDisplayBoxMediaBox];
#else
    [annotation drawWithBox:kPDFDisplayBoxMediaBox inContext:[[NSGraphicsContext currentContext] CGContext]];
#endif
    [image unlockFocus];
    if (needsRemove)
        [page removeAnnotation:annotation];
    return image;
}

/*
 http://www.cocoabuilder.com/archive/message/cocoa/2007/2/16/178891
 The docs are wrong (as is Adobe's spec).  The ordering on the rotated page is:
 --------
 | 0  1 |
 | 2  3 |
 --------
 */

static inline NSArray *quadrilateralPointsFromPointStrings(NSArray *pointStrings) {
    NSMutableArray *quadPoints = [[NSMutableArray alloc] initWithCapacity:[pointStrings count]];
    // fix the order, as we have done it wrong for a long time
    NSUInteger i, iMax = [pointStrings count] / 4;
    for (i = 0; i < iMax; i++) {
        NSPoint p[4];
        NSUInteger j;
        for (j = 0; j < 4; j++)
            p[j] = NSPointFromString([pointStrings objectAtIndex:4 * i + j]);
        // p[0]-p[1] should be in the same direction as p[2]-p[3]
        if ((p[1].x - p[0].x) * (p[3].x - p[2].x) + (p[1].y - p[0].y) * (p[3].y - p[2].y) < 0.0) {
            NSPoint tmp = p[2];
            p[2] = p[3];
            p[3] = tmp;
        }
        for (j = 0; j < 4; j++)
            [quadPoints addObject:[NSValue valueWithPoint:p[j]]];
    }
    return quadPoints;
}

#if !defined(MAC_OS_X_VERSION_10_15) || MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_15

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

#endif
