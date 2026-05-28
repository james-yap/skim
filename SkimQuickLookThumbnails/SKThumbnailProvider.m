//
//  SKThumbnailProvider.m
//  SkimQuickLookThumbnails
//
//  Created by Christiaan Hofman on 22/05/2026.
/*
 This software is Copyright (c) 2026
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

#import "SKThumbnailProvider.h"
#import <Cocoa/Cocoa.h>
#import "SKQLConverter.h"

// Same size as [[NSPrintInfo sharedPrintInfo] paperSize] on my system
// NSPrintInfo must not be used in a non-main thread (and it's hellishly slow in some circumstances)
static const NSSize _paperSize = (NSSize) { 612, 792 };

// page margins 20 pt on all edges
static const CGFloat _horizontalMargin = 20;
static const CGFloat _verticalMargin = 20;

@implementation SKThumbnailProvider

// creates a new NSTextStorage/NSLayoutManager/NSTextContainer system suitable for drawing in a thread
+ (NSTextStorage *)textStorageWithSize:(NSSize)size {
    NSTextStorage *textStorage = [[NSTextStorage alloc] init];
    NSLayoutManager *lm = [[NSLayoutManager alloc] init];
    NSTextContainer *tc = [[NSTextContainer alloc] init];
    [tc setContainerSize:size];
    [lm addTextContainer:tc];
    // don't let the layout manager use its threaded layout (see header)
    [lm setBackgroundLayoutEnabled:NO];
    [textStorage addLayoutManager:lm];
    // see header; the CircleView example sets it to NO
    //[lm setUsesScreenFonts:YES];

    return textStorage;
}

+ (void)drawAttributedString:(NSAttributedString *)attrString inContext:(CGContextRef)context {
    NSRect stringRect = NSMakeRect(0, 0, _paperSize.width - 2 * _horizontalMargin, _paperSize.height - 2 * _verticalMargin);
    NSTextStorage *textStorage = [self textStorageWithSize:stringRect.size];
    [textStorage beginEditing];
    [textStorage setAttributedString:attrString];
    
    [textStorage endEditing];
    
    CGContextSaveGState(context);
    
    CGRect thumbnailRect = CGContextGetClipBoundingBox(context);
    
    CGContextSetGrayFillColor(context, 1, 1);
    CGContextFillRect(context, thumbnailRect);
    
    CGFloat scale = thumbnailRect.size.height / _paperSize.height;
    CGAffineTransform pageTransform = CGAffineTransformScale(CGAffineTransformTranslate(CGAffineTransformMakeScale(scale, scale), _horizontalMargin, _paperSize.height - _verticalMargin), 1, -1);
    CGContextConcatCTM(context, pageTransform);
    
    // objectAtIndex:0 is safe, since we added these to the text storage (so there's at least one)
    NSLayoutManager *lm = [[textStorage layoutManagers] objectAtIndex:0];
    NSTextContainer *tc = [[lm textContainers] objectAtIndex:0];
    
    // we now have a properly flipped graphics context, so force layout and then draw the text
    NSRange glyphRange = [lm glyphRangeForBoundingRect:stringRect inTextContainer:tc];
    stringRect = [lm usedRectForTextContainer:tc];
    
    // NSRunStorage raises if we try drawing a zero length range (happens if you have an empty text file)
    if (glyphRange.length > 0) {
        NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:YES];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:nsContext];
        
        [lm drawBackgroundForGlyphRange:glyphRange atPoint:stringRect.origin];
        [lm drawGlyphsForGlyphRange:glyphRange atPoint:stringRect.origin];
        
        [NSGraphicsContext restoreGraphicsState];
    }
    CGContextRestoreGState(context);
}

+ (void)drawPDFPage:(CGPDFPageRef)pdfPage inContext:(CGContextRef)context {
    CGRect pageRect = CGPDFPageGetBoxRect(pdfPage, kCGPDFCropBox);
    CGRect thumbRect = CGContextGetClipBoundingBox(context);
    CGAffineTransform t = CGPDFPageGetDrawingTransform(pdfPage, kCGPDFCropBox, thumbRect, 0, true);
    CGContextSaveGState(context);
    CGContextSetGrayFillColor(context, 1, 1);
    CGContextFillRect(context, pageRect);
    CGContextConcatCTM(context, t);
    CGContextClipToRect(context, pageRect);
    CGContextSetGrayFillColor(context, 1, 1);
    CGContextFillRect(context, pageRect);
    CGContextDrawPDFPage(context, pdfPage);
    CGContextRestoreGState(context);
    
    CGRect binderRect, ignored;
    CGRectDivide(thumbRect, &binderRect, &ignored, 0.07 * fmax(CGRectGetWidth(thumbRect), CGRectGetHeight(thumbRect)), CGRectMinXEdge);
    CGFloat components1[8] = {0.5, 1.0, 0.0, 1.0};
    CGFloat components2[8] = {0.8, 0.2, 0.1, 1.0};
    CGFloat locations[2] = {0.0, 1.0};
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceGray();
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorspace, components1, locations, 2);
    CGPoint startPoint = CGPointMake(CGRectGetMinX(binderRect), CGRectGetMaxY(binderRect));
    CGPoint endPoint = CGPointMake(CGRectGetMinX(binderRect), CGRectGetMinY(binderRect));
    CGContextSaveGState(context);
    CGContextClipToRect(context, binderRect);
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
    CGGradientRelease(gradient);
    gradient = CGGradientCreateWithColorComponents(colorspace, components2, locations, 2);
    CGColorSpaceRelease(colorspace);
    endPoint = CGPointMake(CGRectGetMaxX(binderRect), CGRectGetMaxY(binderRect));
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
    CGGradientRelease(gradient);
    CGContextRestoreGState(context);
}

- (void)provideThumbnailForFileRequest:(QLFileThumbnailRequest *)request completionHandler:(void (^)(QLThumbnailReply *, NSError *))handler {
    
    NSURL *fileURL = [request fileURL];
    NSString *type = [[NSWorkspace sharedWorkspace] typeOfFile:[fileURL path] error:NULL];
    
    // Second way: Draw the thumbnail into a context passed to your block, set up with Core Graphics's coordinate system.
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
        
    if ([ws type:type conformsToType:@"net.sourceforge.skim-app.pdfd"]) {
            
        NSURL *pdfURL = SKQLPDFURLForPDFBundleURL(fileURL);
        
        if (pdfURL) {
            // sadly, we can't use the system's QL generator from inside quicklookd, so we don't get the fancy binder on the left edge
            CGPDFDocumentRef pdfDoc = CGPDFDocumentCreateWithURL((__bridge CFURLRef)pdfURL);
            CGPDFPageRef pdfPage = NULL;
            if (pdfDoc && CGPDFDocumentGetNumberOfPages(pdfDoc) > 0)
                pdfPage = CGPDFDocumentGetPage(pdfDoc, 1);
            
            if (pdfPage) {
                CGRect pageRect = CGPDFPageGetBoxRect(pdfPage, kCGPDFCropBox);
                CGSize size = [request maximumSize];
                if (pageRect.size.height > pageRect.size.width)
                    size.width = round(size.height * pageRect.size.width / pageRect.size.height);
                else if (pageRect.size.height < pageRect.size.width)
                    size.height = round(size.width * pageRect.size.height / pageRect.size.width);
                if ((CGPDFPageGetRotationAngle(pdfPage) % 180))
                    size = CGSizeMake(size.height, size.width);
                
                handler([QLThumbnailReply replyWithContextSize:size drawingBlock:^BOOL(CGContextRef context) {
            
                    [SKThumbnailProvider drawPDFPage:pdfPage inContext:context];
                    
                    CGPDFDocumentRelease(pdfDoc);
                    
                    // Return YES if the thumbnail was successfully drawn inside this block.
                    return YES;
                }], nil);
            } else {
                CGPDFDocumentRelease(pdfDoc);
                handler(nil, nil);
            }
        } else {
            handler(nil, nil);
        }
        
    } else if ([ws type:type conformsToType:@"net.sourceforge.skim-app.skimnotes"]) {
        
        CGSize size = [request maximumSize];;
        if (_paperSize.height <= size.height)
            size = NSSizeToCGSize(_paperSize);
        else
            size.width = round(size.height * _paperSize.width / _paperSize.height);
        
        handler([QLThumbnailReply replyWithContextSize:size drawingBlock:^BOOL(CGContextRef context) {
            BOOL didGenerate = NO;
            NSData *data = [[NSData alloc] initWithContentsOfURL:fileURL options:NSDataReadingUncached error:NULL];
            
            if (data) {
                NSArray *notes = [SKQLConverter notesWithData:data];
                NSAttributedString *attrString = [SKQLConverter attributedStringWithNotes:notes];
                
                if (attrString) {
                    [SKThumbnailProvider drawAttributedString:attrString inContext:context];
                    didGenerate = YES;
                }
            }
            
            // Return YES if the thumbnail was successfully drawn inside this block.
            return didGenerate;
        }], nil);
        
    } else if ([ws type:type conformsToType:@"com.adobe.postscript"]) {
        
        if (@available(macOS 14.0, *)) {
            handler(nil, nil);
        } else {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                bool converted = false;
                CGPSConverterCallbacks converterCallbacks = { 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL };
                CGPSConverterRef converter = CGPSConverterCreate(NULL, &converterCallbacks, NULL);
                CGDataProviderRef provider = CGDataProviderCreateWithURL((__bridge CFURLRef)fileURL);
                CFMutableDataRef pdfData = CFDataCreateMutable(NULL, 0);
                CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData(pdfData);
                if (provider != NULL && consumer != NULL)
                    converted = CGPSConverterConvert(converter, provider, consumer, NULL);
                CGDataProviderRelease(provider);
                CGDataConsumerRelease(consumer);
                CFRelease(converter);
                if (converted) {
                    // sadly, we can't use the system's QL generator from inside quicklookd, so we don't get the fancy binder on the left edge
                    provider = CGDataProviderCreateWithCFData(pdfData);
                    CGPDFDocumentRef pdfDoc = CGPDFDocumentCreateWithProvider(provider);
                    CGDataProviderRelease(provider);
                    CGPDFPageRef pdfPage = NULL;
                    if (pdfDoc && CGPDFDocumentGetNumberOfPages(pdfDoc) > 0)
                        pdfPage = CGPDFDocumentGetPage(pdfDoc, 1);
                    
                    if (pdfPage) {
                        CGRect pageRect = CGPDFPageGetBoxRect(pdfPage, kCGPDFCropBox);
                        CGSize size = [request maximumSize];
                        if (pageRect.size.height > pageRect.size.width)
                            size.width = round(size.height * pageRect.size.width / pageRect.size.height);
                        else if (pageRect.size.height < pageRect.size.width)
                            size.height = round(size.width * pageRect.size.height / pageRect.size.width);
                        if ((CGPDFPageGetRotationAngle(pdfPage) % 180))
                            size = CGSizeMake(size.height, size.width);
                        
                        handler([QLThumbnailReply replyWithContextSize:size drawingBlock:^BOOL(CGContextRef context) {
                            
                            [SKThumbnailProvider drawPDFPage:pdfPage inContext:context];
                            
                            CGPDFDocumentRelease(pdfDoc);
                            
                            // Return YES if the thumbnail was successfully drawn inside this block.
                            return YES;
                        }], nil);
                    } else {
                        CGPDFDocumentRelease(pdfDoc);
                        handler(nil, nil);
                    }
                } else {
                    handler(nil, nil);
                }
                if (pdfData) CFRelease(pdfData);
            });
        }
        
    } else {
        handler(nil, nil);
    }
}

@end
