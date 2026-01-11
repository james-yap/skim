//
//  SKNPDFAnnotationNote_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 2/6/07.
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

#import "SKNPDFAnnotationNote_SKExtensions.h"
#import <SkimNotes/SkimNotes.h>
#import "PDFAnnotation_SKExtensions.h"
#import "SKStringConstants.h"
#import "SKFDFParser.h"
#import "NSUserDefaults_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "NSData_SKExtensions.h"
#import "SKNoteText.h"


NSString * const SKPDFAnnotationRichTextKey = @"richText";

NSString * const SKPDFAnnotationScriptingIconTypeKey = @"scriptingIconType";
NSString * const SKPDFAnnotationScriptingImageDataKey = @"scriptingImageData";

@interface SKNPDFAnnotationNote (SKPrivateDeclarations)
- (NSTextStorage *)mutableText;
- (NSArray *)texts;
- (void)setTexts:(NSArray *)texts;
@end

@implementation SKNPDFAnnotationNote (SKExtensions)

+ (NSSet *)keyPathsForValuesAffectingExtendedIconType {
    return [NSSet setWithObjects:SKNPDFAnnotationNameKey, SKNPDFAnnotationDrawsImageKey, nil];
}

+ (NSSet *)keyPathsForValuesAffectingName {
    return [NSSet setWithObjects:SKNPDFAnnotationIconTypeKey, nil];
}

- (void)setDefaultSkimNoteProperties {
    [self setColor:[[NSUserDefaults standardUserDefaults] colorForKey:SKAnchoredNoteColorKey]];
    PDFTextAnnotationIconType iconType = [[NSUserDefaults standardUserDefaults] integerForKey:SKAnchoredNoteIconTypeKey];
    if (iconType == kSKNPDFTextAnnotationIconImage) {
        [self setIconType:kPDFTextAnnotationIconNote];
        [self setDrawsImage:YES];
    } else {
        [self setIconType:iconType];
        [self setDrawsImage:NO];
    }
    [self setTexts:@[[[SKNoteText alloc] initWithNote:self]]];
    [self setPopup:nil];
}

- (BOOL)isNote { return YES; }

- (BOOL)isResizable { return [self isSkimNote] && [self drawsImage]; }

- (BOOL)isMovable { return [self isSkimNote]; }

- (BOOL)hasBorder { return NO; }

- (PDFTextAnnotationIconType)extendedIconType {
    return [self drawsImage] ? kSKNPDFTextAnnotationIconImage : [self iconType];
}

- (void)setExtendedIconType:(PDFTextAnnotationIconType)iconType {
    if (iconType == kSKNPDFTextAnnotationIconImage) {
        if ([self drawsImage] == NO)
            [self setDrawsImage:YES];
    } else {
        if ([self drawsImage])
            [self setDrawsImage:NO];
        [self setIconType:iconType];
        NSRect bounds = [self bounds];
        if (NSEqualSizes(bounds.size, SKNPDFAnnotationNoteSize) == NO) {
            bounds.origin.y = NSMaxY(bounds) - SKNPDFAnnotationNoteSize.height;
            bounds.size = SKNPDFAnnotationNoteSize;
            [self setBounds:bounds];
        }
    }
}

- (NSString *)name {
    return [self valueForAnnotationKey:PDFAnnotationKeyIconName];
}

- (void)setName:(NSString *)name {
    [self setValue:name forAnnotationKey:PDFAnnotationKeyIconName];
}

// override these Leopard methods to avoid showing the standard tool tips over our own
- (NSString *)toolTip { return @""; }

- (BOOL)hasNoteText { return YES; }

- (SKNoteText *)noteText {
    return [[self texts] firstObject];
}

- (NSString *)textString {
    return [[self text] string];
}

- (NSString *)colorDefaultKey { return SKAnchoredNoteColorKey; }

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *noteKeys = nil;
    if (noteKeys == nil) {
        NSMutableSet *mutableKeys = [[super keysForValuesToObserveForUndo] mutableCopy];
        [mutableKeys removeObject:SKNPDFAnnotationBorderKey];
        [mutableKeys addObject:SKNPDFAnnotationNameKey];
        [mutableKeys addObject:SKNPDFAnnotationTextKey];
        [mutableKeys addObject:SKNPDFAnnotationImageKey];
        [mutableKeys addObject:SKNPDFAnnotationDrawsImageKey];
        noteKeys = [mutableKeys copy];
    }
    return noteKeys;
}

#pragma mark Scripting support

+ (NSSet *)customScriptingKeys {
    static NSSet *customNoteScriptingKeys = nil;
    if (customNoteScriptingKeys == nil) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSMutableSet *customKeys = [[super customScriptingKeys] mutableCopy];
#pragma clang diagnostic pop
        [customKeys removeObject:SKNPDFAnnotationLineWidthKey];
        [customKeys removeObject:SKNPDFAnnotationBorderStyleKey];
        [customKeys removeObject:SKNPDFAnnotationDashPatternKey];
        [customKeys addObject:SKPDFAnnotationScriptingIconTypeKey];
        [customKeys addObject:SKPDFAnnotationRichTextKey];
        [customKeys addObject:SKPDFAnnotationScriptingImageDataKey];
        customNoteScriptingKeys = [customKeys copy];
    }
    return customNoteScriptingKeys;
}

- (id)richText {
    return [self mutableText];
}

- (void)setRichText:(id)newText {
    if ([self isEditable] && newText != [self mutableText]) {
        // We are willing to accept either a string or an attributed string.
        if ([newText isKindOfClass:[NSAttributedString class]])
            [[self mutableText] replaceCharactersInRange:NSMakeRange(0, [[self mutableText] length]) withAttributedString:newText];
        else
            [[self mutableText] replaceCharactersInRange:NSMakeRange(0, [[self mutableText] length]) withString:newText];
    }
}

- (id)coerceValueForRichText:(id)value {
    if ([value isKindOfClass:[NSScriptObjectSpecifier class]])
        value = [(NSScriptObjectSpecifier *)value objectsByEvaluatingSpecifier];
    // We want to just get Strings unchanged.  We will detect this and do the right thing in setRichText.  We do this because, this way, we will do more reasonable things about attributes when we are receiving plain text.
    if ([value isKindOfClass:[NSString class]])
        return value;
    else
        return [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:value toClass:[NSTextStorage class]];
}

- (PDFTextAnnotationIconType)scriptingIconType {
    return [self extendedIconType];
}

- (void)setScriptingIconType:(PDFTextAnnotationIconType)iconType {
    if ([self isEditable]) {
        [self setExtendedIconType:iconType];
    }
}

- (NSAppleEventDescriptor *)scriptingImageData {
    NSImage *img = [self image];
    if (img == nil)
        return nil;
    id imageRep = [[img representations] count] == 1 ? [[img representations] firstObject] : nil;
    if ([imageRep isKindOfClass:[NSPDFImageRep class]])
        return [[imageRep PDFRepresentation] scriptingPdfDescriptor];
    else
        return [[img TIFFRepresentation] scriptingTiffPictureDescriptor];
}

- (void)setScriptingImageData:(NSAppleEventDescriptor *)descriptor {
    if ([self isEditable]) {
        if (descriptor)
            [self setImage:[[NSImage alloc] initWithData:[descriptor data]]];
        else
            [self setImage:nil];
    }
}

@end
