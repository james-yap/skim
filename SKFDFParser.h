//
//  SKFDFParser.h
//  Skim
//
//  Created by Christiaan Hofman on 9/6/07.
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

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

NS_ASSUME_NONNULL_BEGIN

typedef const char *SKFDFString;

extern SKFDFString const SKFDFFDFKey;
extern SKFDFString const SKFDFAnnotationsKey;
extern SKFDFString const SKFDFFileKey;
extern SKFDFString const SKFDFFileIDKey;
extern SKFDFString const SKFDFRootKey;

extern SKFDFString const SKFDFTypeKey;

extern SKFDFString const SKFDFAnnotationFlagsKey;
extern SKFDFString const SKFDFAnnotationTypeKey;
extern SKFDFString const SKFDFAnnotationBoundsKey;
extern SKFDFString const SKFDFAnnotationPageIndexKey;
extern SKFDFString const SKFDFAnnotationContentsKey;
extern SKFDFString const SKFDFAnnotationColorKey;
extern SKFDFString const SKFDFAnnotationInteriorColorKey;
extern SKFDFString const SKFDFAnnotationBorderStylesKey;
extern SKFDFString const SKFDFAnnotationLineWidthKey;
extern SKFDFString const SKFDFAnnotationDashPatternKey;
extern SKFDFString const SKFDFAnnotationBorderStyleKey;
extern SKFDFString const SKFDFAnnotationBorderKey;
extern SKFDFString const SKFDFAnnotationModificationDateKey;
extern SKFDFString const SKFDFAnnotationUserNameKey;
extern SKFDFString const SKFDFAnnotationAlignmentKey;
extern SKFDFString const SKFDFAnnotationIconTypeKey;
extern SKFDFString const SKFDFAnnotationLineStylesKey;
extern SKFDFString const SKFDFAnnotationLinePointsKey;
extern SKFDFString const SKFDFAnnotationInkListKey;
extern SKFDFString const SKFDFAnnotationQuadrilateralPointsKey;
extern SKFDFString const SKFDFAnnotationFieldNameKey;
extern SKFDFString const SKFDFAnnotationFieldTypeKey;
extern SKFDFString const SKFDFAnnotationFieldValueKey;
extern SKFDFString const SKFDFDefaultAppearanceKey;
extern SKFDFString const SKFDFDefaultStyleKey;

extern SKFDFString const SKFDFAnnotation;

extern SKFDFString const SKFDFBorderStyleSolid;
extern SKFDFString const SKFDFBorderStyleDashed;
extern SKFDFString const SKFDFBorderStyleBeveled;
extern SKFDFString const SKFDFBorderStyleInset;
extern SKFDFString const SKFDFBorderStyleUnderline;

extern SKFDFString const SKFDFTextAnnotationIconComment;
extern SKFDFString const SKFDFTextAnnotationIconKey;
extern SKFDFString const SKFDFTextAnnotationIconNote;
extern SKFDFString const SKFDFTextAnnotationIconNewParagraph;
extern SKFDFString const SKFDFTextAnnotationIconParagraph;
extern SKFDFString const SKFDFTextAnnotationIconInsert;

extern SKFDFString const SKFDFLineStyleNone;
extern SKFDFString const SKFDFLineStyleSquare;
extern SKFDFString const SKFDFLineStyleCircle;
extern SKFDFString const SKFDFLineStyleDiamond;
extern SKFDFString const SKFDFLineStyleOpenArrow;
extern SKFDFString const SKFDFLineStyleClosedArrow;

extern SKFDFString const SKFDFFieldTypeText;
extern SKFDFString const SKFDFFieldTypeButton;
extern SKFDFString const SKFDFFieldTypeChoice;

extern PDFBorderStyle SKPDFBorderStyleFromFDFBorderStyle(SKFDFString name);
extern SKFDFString SKFDFBorderStyleFromPDFBorderStyle(PDFBorderStyle borderStyle);

extern NSTextAlignment SKPDFFreeTextAnnotationAlignmentFromFDFFreeTextAnnotationAlignment(NSInteger anInt);
extern NSInteger SKFDFFreeTextAnnotationAlignmentFromPDFFreeTextAnnotationAlignment(NSTextAlignment alignment);

extern PDFTextAnnotationIconType SKPDFTextAnnotationIconTypeFromFDFTextAnnotationIconType(SKFDFString name);
extern SKFDFString SKFDFTextAnnotationIconTypeFromPDFTextAnnotationIconType(PDFTextAnnotationIconType iconType);

extern PDFLineStyle SKPDFLineStyleFromFDFLineStyle(SKFDFString name);
extern SKFDFString SKFDFLineStyleFromPDFLineStyle(PDFLineStyle lineStyle);


@interface SKFDFParser : NSObject
+ (nullable NSArray<NSDictionary<NSString *, id> *> *)noteDictionariesFromFDFData:(NSData *)data;
@end


@interface NSMutableString (SKFDFExtensions)
- (void)appendFDFName:(SKFDFString)name;
@end

NS_ASSUME_NONNULL_END
