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
static const NSSize _containerSize = (NSSize) { 572, 752 };
static const NSRect _iconRect = (NSRect) { { 50, 140 }, { 512, 512 } };

// wash the app icon over a white page background
static void drawBackgroundAndApplicationIconInCurrentContext()
{
    [[NSColor whiteColor] setFill];
    NSRect pageRect = { NSZeroPoint, _paperSize };
    NSRectFillUsingOperation(pageRect, NSCompositingOperationSourceOver);
    BOOL isHR = CGContextGetUserSpaceToDeviceSpaceTransform([[NSGraphicsContext currentContext] CGContext]).a > 1.0;
    
    NSURL *iconURL = [[NSBundle mainBundle] URLForImageResource:isHR ? @"Skim_2x" : @"Skim"];
    NSImage *appIcon = [[NSImage alloc] initWithContentsOfURL:iconURL];
    
    [appIcon drawInRect:_iconRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:0.3];
}

// creates a new NSTextStorage/NSLayoutManager/NSTextContainer system suitable for drawing in a thread
static NSTextStorage *createTextStorage()
{
    NSTextStorage *textStorage = [[NSTextStorage alloc] init];
    NSLayoutManager *lm = [[NSLayoutManager alloc] init];
    NSTextContainer *tc = [[NSTextContainer alloc] init];
    [tc setContainerSize:_containerSize];
    [lm addTextContainer:tc];
    // don't let the layout manager use its threaded layout (see header)
    [lm setBackgroundLayoutEnabled:NO];
    [textStorage addLayoutManager:lm];
    // see header; the CircleView example sets it to NO
    //[lm setUsesScreenFonts:YES];

    return textStorage;
}

// assumes that the current NSGraphicsContext is the destination
static void drawAttributedStringInCurrentContext(NSAttributedString *attrString)
{
    CGContextRef ctxt = [[NSGraphicsContext currentContext] CGContext];
    
    NSTextStorage *textStorage = createTextStorage();
    [textStorage beginEditing];
    [textStorage setAttributedString:attrString];
    
    [textStorage endEditing];
    NSRect stringRect = NSZeroRect;
    stringRect.size = _paperSize;
    
    CGContextSaveGState(ctxt);
    
    CGAffineTransform t1 = CGAffineTransformMakeTranslation(_horizontalMargin, _paperSize.height - _verticalMargin);
    CGAffineTransform t2 = CGAffineTransformMakeScale(1, -1);
    CGAffineTransform pageTransform = CGAffineTransformConcat(t2, t1);
    CGContextConcatCTM(ctxt, pageTransform);
    
    // objectAtIndex:0 is safe, since we added these to the text storage (so there's at least one)
    NSLayoutManager *lm = [[textStorage layoutManagers] objectAtIndex:0];
    NSTextContainer *tc = [[lm textContainers] objectAtIndex:0];
    
    NSRange glyphRange;
    
    // we now have a properly flipped graphics context, so force layout and then draw the text
    glyphRange = [lm glyphRangeForBoundingRect:stringRect inTextContainer:tc];
    NSRect usedRect = [lm usedRectForTextContainer:tc];
    
    // NSRunStorage raises if we try drawing a zero length range (happens if you have an empty text file)
    if (glyphRange.length > 0) {
        [lm drawBackgroundForGlyphRange:glyphRange atPoint:usedRect.origin];
        [lm drawGlyphsForGlyphRange:glyphRange atPoint:usedRect.origin];
    }
    CGContextRestoreGState(ctxt);
}

@implementation SKThumbnailProvider

- (void)provideThumbnailForFileRequest:(QLFileThumbnailRequest *)request completionHandler:(void (^)(QLThumbnailReply *, NSError *))handler {
    
    NSURL *fileURL = [request fileURL];
    NSString *type = [[NSWorkspace sharedWorkspace] typeOfFile:[fileURL path] error:NULL];
    QLThumbnailReply *reply = nil;
    
    // Second way: Draw the thumbnail into a context passed to your block, set up with Core Graphics's coordinate system.
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
        
    if ([ws type:type conformsToType:@"net.sourceforge.skim-app.pdfd"]) {
            
        reply = [QLThumbnailReply replyWithContextSize:_paperSize drawingBlock:^BOOL(CGContextRef context) {
            BOOL didGenerate = NO;
            NSURL *pdfURL = SKQLPDFURLForPDFBundleURL(fileURL);
            
            if (pdfURL) {
                // sadly, we can't use the system's QL generator from inside quicklookd, so we don't get the fancy binder on the left edge
                CGPDFDocumentRef pdfDoc = CGPDFDocumentCreateWithURL((__bridge CFURLRef)pdfURL);
                CGPDFPageRef pdfPage = NULL;
                if (pdfDoc && CGPDFDocumentGetNumberOfPages(pdfDoc) > 0)
                    pdfPage = CGPDFDocumentGetPage(pdfDoc, 1);
                
                if (pdfPage) {
                    CGRect pageRect = CGPDFPageGetBoxRect(pdfPage, kCGPDFCropBox);
                    CGRect thumbRect = {CGPointZero, _paperSize};
                    CGFloat color[4] = {1.0, 1.0, 1.0, 1.0};
                    CGAffineTransform t = CGPDFPageGetDrawingTransform(pdfPage, kCGPDFCropBox, thumbRect, 0, true);
                    CGContextConcatCTM(context, t);
                    CGContextClipToRect(context, pageRect);
                    CGContextSetFillColor(context, color);
                    CGContextFillRect(context, pageRect);
                    CGContextDrawPDFPage(context, pdfPage);
                    
                    didGenerate = YES;
                }
                CGPDFDocumentRelease(pdfDoc);
            }
            
            // Return YES if the thumbnail was successfully drawn inside this block.
            return didGenerate;
        }];
        
    } else if ([ws type:type conformsToType:@"net.sourceforge.skim-app.skimnotes"]) {
        
        reply = [QLThumbnailReply replyWithContextSize:_paperSize drawingBlock:^BOOL(CGContextRef context) {
            BOOL didGenerate = NO;
            NSData *data = [[NSData alloc] initWithContentsOfURL:fileURL options:NSDataReadingUncached error:NULL];
            
            if (data) {
                NSArray *notes = [SKQLConverter notesWithData:data];
                NSAttributedString *attrString = [SKQLConverter attributedStringWithNotes:notes];
                
                if (attrString) {
                    NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:YES];
                    [NSGraphicsContext saveGraphicsState];
                    [NSGraphicsContext setCurrentContext:nsContext];
                    
                    drawBackgroundAndApplicationIconInCurrentContext();
                    drawAttributedStringInCurrentContext(attrString);
                    
                    [NSGraphicsContext restoreGraphicsState];
                    
                    didGenerate = YES;
                }
            }
            
            // Return YES if the thumbnail was successfully drawn inside this block.
            return didGenerate;
        }];
        
    } else if ([ws type:type conformsToType:@"com.adobe.postscript"]) {
            
        if (@available(macOS 14.0, *)) {} else {
            reply = [QLThumbnailReply replyWithContextSize:_paperSize drawingBlock:^BOOL(CGContextRef context) {
                BOOL didGenerate = NO;
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
                    CGPDFPageRef pdfPage = NULL;
                    if (pdfDoc && CGPDFDocumentGetNumberOfPages(pdfDoc) > 0)
                        pdfPage = CGPDFDocumentGetPage(pdfDoc, 1);
                    
                    if (pdfPage) {
                        CGRect pageRect = CGPDFPageGetBoxRect(pdfPage, kCGPDFCropBox);
                        CGRect thumbRect = {CGPointZero, _paperSize};
                        CGFloat color[4] = {1.0, 1.0, 1.0, 1.0};
                        CGAffineTransform t = CGPDFPageGetDrawingTransform(pdfPage, kCGPDFCropBox, thumbRect, 0, true);
                        CGContextConcatCTM(context, t);
                        CGContextClipToRect(context, pageRect);
                        CGContextSetFillColor(context, color);
                        CGContextFillRect(context, pageRect);
                        CGContextDrawPDFPage(context, pdfPage);
                        
                        didGenerate = YES;
                    }
                    CGPDFDocumentRelease(pdfDoc);
                    CGDataProviderRelease(provider);
                }
                if (pdfData) CFRelease(pdfData);
                
                // Return YES if the thumbnail was successfully drawn inside this block.
                return didGenerate;
            }];
        }

    }
    
    handler(reply, nil);
}

@end
