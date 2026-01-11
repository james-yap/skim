//
//  PDFAnnotation_SKNExtensions.h
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

/*!
    @header      
    @abstract    An <code>PDFAnnotation</code> category to manage Skim notes.
    @discussion  This header file provides API for an <code>PDFAnnotation</code> categories to convert Skim note dictionaries to <code>PDFAnnotations</code> and back.
*/
#import <Foundation/Foundation.h>
#import <PDFKit/PDFKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifndef PDFRect
#define PDFRect NSRect
#endif
#ifndef PDFKitPlatformBezierPath
#define PDFKitPlatformBezierPath NSBezierPath
#endif

/*!
    @discussion  Global string for Free Text note type.
*/
PDFKIT_EXTERN NSString * const SKNFreeTextString;
/*!
    @discussion  Global string for Text note type.
*/
PDFKIT_EXTERN NSString * const SKNTextString;
/*!
    @discussion  Global string for Stamp note type.
*/
PDFKIT_EXTERN NSString * const SKNStampString;
/*!
    @discussion  Global string for Note note type.
*/
PDFKIT_EXTERN NSString * const SKNNoteString;
/*!
    @discussion  Global string for Circle note type.
*/
PDFKIT_EXTERN NSString * const SKNCircleString;
/*!
    @discussion  Global string for Square note type.
*/
PDFKIT_EXTERN NSString * const SKNSquareString;
/*!
    @discussion  Global string for Mark Up note type.
*/
PDFKIT_EXTERN NSString * const SKNMarkUpString;
/*!
    @discussion  Global string for Highlight note type.
*/
PDFKIT_EXTERN NSString * const SKNHighlightString;
/*!
    @discussion  Global string for Underline note type.
*/
PDFKIT_EXTERN NSString * const SKNUnderlineString;
/*!
    @discussion  Global string for Strike Out note type.
*/
PDFKIT_EXTERN NSString * const SKNStrikeOutString;
/*!
    @discussion  Global string for Line note type.
*/
PDFKIT_EXTERN NSString * const SKNLineString;
/*!
    @discussion  Global string for Ink note type.
*/
PDFKIT_EXTERN NSString * const SKNInkString;
/*!
    @discussion  Global string for Widget note type.
*/
PDFKIT_EXTERN NSString * const SKNWidgetString;

/*!
    @discussion  Global string for annotation type key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationTypeKey;
/*!
    @discussion  Global string for annotation bounds key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationBoundsKey;
/*!
    @discussion  Global string for annotation page key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationPageKey;
/*!
    @discussion  Global string for annotation page index key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationPageIndexKey;
/*!
    @discussion  Global string for annotation contents key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationContentsKey;
/*!
    @discussion  Global string for annotation string key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationStringKey;
/*!
    @discussion  Global string for annotation color key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationColorKey;
/*!
    @discussion  Global string for annotation border key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationBorderKey;
/*!
    @discussion  Global string for annotation line width key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationLineWidthKey;
/*!
    @discussion  Global string for annotation border style key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationBorderStyleKey;
/*!
    @discussion  Global string for annotation dash pattern key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationDashPatternKey;
/*!
    @discussion  Global string for annotation modification date key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationModificationDateKey;
/*!
    @discussion  Global string for annotation user name key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationUserNameKey;

/*!
    @discussion  Global string for annotation interior color key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationInteriorColorKey;

/*!
    @discussion  Global string for annotation start line style key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationStartLineStyleKey;
/*!
    @discussion  Global string for annotation end line style key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationEndLineStyleKey;
/*!
    @discussion  Global string for annotation start point key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationStartPointKey;
/*!
    @discussion  Global string for annotation end point key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationEndPointKey;

/*!
    @discussion  Global string for annotation font key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationFontKey;
/*!
    @discussion  Global string for annotation font color key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationFontColorKey;
/*!
    @discussion  Global string for annotation font name key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationFontNameKey;
/*!
    @discussion  Global string for annotation font size key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationFontSizeKey;
/*!
    @discussion  Global string for annotation text alignment key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationAlignmentKey;
/*!
    @discussion  Global string for annotation rotation key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationRotationKey;

/*!
    @discussion  Global string for annotation quadrilateral points key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationQuadrilateralPointsKey;

/*!
    @discussion  Global string for annotation icon type key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationIconTypeKey;

/*!
    @discussion  Global string for annotation icon or stamp name key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationNameKey;

/*!
    @discussion  Global string for annotation point lists key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationPointListsKey;

/*!
    @discussion  Global string for annotation string value key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationStringValueKey;

/*!
    @discussion  Global string for annotation state key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationStateKey;

/*!
    @discussion  Global string for annotation widget type key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationWidgetTypeKey;

/*!
    @discussion  Global string for annotation field name key.
*/
PDFKIT_EXTERN NSString * const SKNPDFAnnotationFieldNameKey;

/**
 @enum        SKNWidgetType
 @abstract    Type of widget annotations.
 @discussion  These enum values indicate the type of a widget annotation.
 @constant    kSKNPDFWidgetTypeUnknown No widget annotation.
 @constant    kSKNPDFWidgetTypeText    A text widget annotation.
 @constant    kSKNPDFWidgetTypeButton  A button widget annotation.
 @constant    kSKNPDFWidgetTypeChoice  A choice widget annotation.
 */
typedef NS_ENUM(NSInteger, SKNPDFWidgetType) {
    kSKNPDFWidgetTypeUnknown = -1,
    kSKNPDFWidgetTypeText = 0,
    kSKNPDFWidgetTypeButton = 1,
    kSKNPDFWidgetTypeChoice = 2
};

/*!
    @abstract    Provides methods to translate between dictionary representations of Skim notes and <code>PDFAnnotation</code> objects on macOS.
    @discussion  Methods from this category are used by the <code>PDFDocument (SKNExtensions)</code> category to add new annotations from Skim notes.
*/
@interface PDFAnnotation (SKNExtensions)

#if !defined(PDFKIT_PLATFORM_IOS)
/*!
    @abstract   Initializes a new Skim note annotation.  This is the designated initializer for a Skim note on macOS.
    @discussion This method can be implemented in subclasses to provide default properties for Skim notes.
    @param      bounds The bounding box of the annotation, in page space.
    @result     An initialized Skim note annotation instance, or <code>nil</code> if the object could not be initialized.
*/
- (nullable id)initSkimNoteWithBounds:(NSRect)bounds;
#endif

/*!
    @abstract   Initializes a new Skim note annotation.  This is the designated initializer for a Skim noteon iOS.
    @discussion On macOS this returns a subclasses initialized with <code>initSkimNoteWithBounds:</code>.
    @param      bounds The bounding box of the annotation, in page space.
    @param      type The type of the note .
    @result     An initialized Skim note annotation instance, or <code>nil</code> if the object could not be initialized.
*/
- (nullable id)initSkimNoteWithBounds:(PDFRect)bounds forType:(NSString *)type;

/*!
    @abstract   Initializes a new Skim note annotation with the given properties.
    @discussion This method determines the proper subclass from the value for the <code>"type"</code> key in dict, initializes an instance using <code>initSkimNoteWithBounds:</code>, and sets the known properties from dict. Implementations in subclasses should call it on super and set their properties from dict if available.
    @param      dict A dictionary with Skim notes properties, as returned from properties.  This is required to contain values for <code>"type"</code> and <code>"bounds"</code>.
    @result     An initialized Skim note annotation instance, or <code>nil</code> if the object could not be initialized.
*/
- (nullable id)initSkimNoteWithProperties:(NSDictionary<NSString *, id> *)dict;

/*!
    @abstract   The Skim notes properties.
    @discussion These properties can be used to initialize a new copy, and to save to extended attributes or file.
    @result     A dictionary with properties of the Skim note.  All values are standard Cocoa objects conforming to <code>NSCoding</code> and <code>NSCopying</code>.
*/
@property (nonatomic, readonly) NSDictionary<NSString *, id> *SkimNoteProperties;

/*!
    @abstract   Returns whether the annotation is a Skim note.  
    @discussion An annotation initalized with initializers starting with initSkimNote will return <code>YES</code> by default.  You normally would not set this yourself, but rely on the initializer to set the <code>isSkimNote</code> flag.
    @result     YES if the annotation is a Skim note; otherwise NO.
*/
@property (nonatomic, getter=isSkimNote) BOOL SkimNote;

/*!
    @abstract   The string value of the annotation.
    @discussion By default, this is just the same as the contents.  However for <code>SKNPDFAnnotationNote</code> the contents will contain both string and text.  Normally you set this by setting the <code>content</code> property.
    @result     A string representing the string value associated with the annotation.
*/
@property (nonatomic, strong, nullable) NSString *string;

/*!
    @abstract   Method to get the points from a path of an Ink Skim note.
    @param      path The bezier path for which to get the points.
    @discussion This method gets the points between which the path interpolates.
    @result     An array of point strings.
*/
+ (NSArray<NSString *> *)pointsFromSkimNotePath:(PDFKitPlatformBezierPath *)path;

/*!
    @abstract   Method to set the points from a path of an Ink Skim note.
    @param      path The bezier path for which to set the points.
    @param      points The points wrapped in strings or values.
    @discussion This method sets the elements to cubic curves interpolating between the points.  It rebuilds a path appropriate for a Skim note.
*/
+ (void)setPoints:(NSArray *)points ofSkimNotePath:(PDFKitPlatformBezierPath *)path;

#if !defined(PDFKIT_PLATFORM_IOS)
/*!
    @abstract   Method to add a point to a path, to be used to build the path for a Skim note.
    @param      point The point to add to the path.
    @param      path The bezier path to add the point to.
    @discussion This method adds a cubic curve element to path to point.  It is used to build up paths for the Skim note from the points.  This method is only available on macOS.
*/
+ (void)addPoint:(NSPoint)point toSkimNotesPath:(NSBezierPath *)path;
#endif

@end

#pragma mark -

@interface PDFAnnotation (SKNOptional)
/*!
    @abstract   Optional method to set default values for a new Skim note created using <code>initSkimNoteWithBounds:forType:</code> or <code>initSkimNoteWithProperties:</code>.
    @discussion This optional method can be implemented in another category to provide a default values for Skim notes.  On macOS you can also override <code>initSkimNoteWithBounds:</code> in the subclasses to provide default values, or implement this method in the subclasses.  This method is not implemented by default.
*/
- (void)setDefaultSkimNoteProperties;
@end

#pragma mark -

#if !defined(PDFKIT_PLATFORM_IOS)

/*!
    @abstract    Provides methods to translate between dictionary representations of Skim notes and <code>PDFAnnotation</code> objects.
    @discussion  Implements <code>initSkimNotesWithProperties:</code> and properties to take care of the extra properties of a circle annotation.
*/
@interface PDFAnnotationCircle (SKNExtensions)
@end

#pragma mark -

/*!
    @abstract    Provides methods to translate between dictionary representations of Skim notes and <code>PDFAnnotation</code> objects.
    @discussion  Implements <code>initSkimNotesWithProperties:</code> and properties to take care of the extra properties of a square annotation.
*/
@interface PDFAnnotationSquare (SKNExtensions)
@end

#pragma mark -

/*!
    @abstract    Provides methods to translate between dictionary representations of Skim notes and <code>PDFAnnotation</code> objects.
    @discussion  Implements <code>initSkimNotesWithProperties:</code> and properties to take care of the extra properties of a line annotation.
*/
@interface PDFAnnotationLine (SKNExtensions)
@end

#pragma mark -

/*!
    @abstract    Provides methods to translate between dictionary representations of Skim notes and <code>PDFAnnotation</code> objects.
    @discussion  Implements <code>initSkimNotesWithProperties:</code> and properties to take care of the extra properties of a free text annotation.
*/
@interface PDFAnnotationFreeText (SKNExtensions)
@end

#pragma mark -

/*!
    @abstract    Provides methods to translate between dictionary representations of Skim notes and <code>PDFAnnotation</code> objects.
    @discussion  Implements <code>initSkimNotesWithProperties:</code> and properties to take care of the extra properties of a markup annotation.
*/
@interface PDFAnnotationMarkup (SKNExtensions)
@end

/*!
    @abstract    An informal protocol providing a method name for an optional method that may be implemented in a category.
    @discussion  This defines an optional method that another <code>PDFAnnotationMarkup</code> category may implement to provide a default color.
*/
@interface PDFAnnotationMarkup (SKNOptional)
/*!
    @abstract   Optional method to implement to return the default color to use for markup initialized with properties that do not contain a color.
    @param      markupType The markup style for which to return the default color.
    @discussion This optional method can be implemented in another category to provide a default color for Skim notes that have no color set in the properties dictionary.  This method is not implemented by default.
    @result     The default color for an annotation with the passed in markup style.
*/
+ (NSColor *)defaultSkimNoteColorForMarkupType:(NSInteger)markupType;
@end

#pragma mark -

/*!
    @abstract    Provides methods to translate between dictionary representations of Skim notes and <code>PDFAnnotation</code> objects.
    @discussion  Implements <code>initSkimNotesWithProperties:</code> and properties to take care of the extra properties of a text annotation.
*/
@interface PDFAnnotationText (SKNExtensions)
@end

#pragma mark -

/*!
    @abstract    Provides methods to translate between dictionary representations of Skim notes and <code>PDFAnnotation</code> objects.
    @discussion  Implements <code>initSkimNotesWithProperties:</code> and properties to take care of the extra properties of a stamp annotation.
*/
@interface PDFAnnotationStamp (SKNExtensions)
@end

#pragma mark -

/*!
    @abstract    Provides methods to translate between dictionary representations of Skim notes and <code>PDFAnnotation</code> objects.
    @discussion  Implements <code>initSkimNotesWithProperties:</code> and properties to take care of the extra properties of a text annotation.
*/
@interface PDFAnnotationInk (SKNExtensions)
@end

#pragma mark -

/*!
    @abstract    Provides methods to save data for a widget object.
    @discussion  Implements <code>SkimNoteProperties</code> for a text widget annotation.
*/
@interface PDFAnnotationTextWidget (SKNExtensions)
@end

#pragma mark -

/*!
    @abstract    Provides methods to save data for a widget object.
    @discussion  Implements <code>SkimNoteProperties</code> for a button widget annotation.
*/
@interface PDFAnnotationButtonWidget (SKNExtensions)
@end

#pragma mark -

/*!
    @abstract    Provides methods to save data for a widget object.
    @discussion  Implements <code>SkimNoteProperties</code> for a choice widget annotation.
*/
@interface PDFAnnotationChoiceWidget (SKNExtensions)
@end

#endif

NS_ASSUME_NONNULL_END
