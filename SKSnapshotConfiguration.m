//
//  SKSnapshotConfiguration.m
//  Skim
//
//  Created by Christiaan Hofman on 08/06/2024.
/*
 This software is Copyright (c) 2024
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

#import "SKSnapshotConfiguration.h"
#import "NSImage_SKExtensions.h"
#import "NSBitmapImageRep_SKExtensions.h"
#import "NSShadow_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "PDFView_SKExtensions.h"


@implementation SKSnapshotConfiguration

- (instancetype)initWithPDFView:(PDFView *)pdfView {
    self = [super init];
    if (self) {
        NSRect bounds = [pdfView unobscuredContentRect];
        size = bounds.size;
        displayBox = [pdfView displayBox];
        scaleFactor = [pdfView scaleFactor];
        interpolationQuality = [pdfView interpolationQuality];
        NSMutableArray *dests = [NSMutableArray array];
        for (PDFPage *page in [pdfView visiblePages]) {
            NSRect pageRect = [pdfView convertRect:[page boundsForBox:displayBox] fromPage:page];
            if (NSIntersectsRect(pageRect, bounds))
                [dests addObject:[[PDFDestination alloc] initWithPage:page atPoint:SKSubstractPoints(pageRect.origin, bounds.origin)]];
        }
        pages = dests;
    }
    return self;
}

- (NSBitmapImageRep *)bitmapImageRepWithSize:(CGFloat)aSize scale:(CGFloat)scale placeholder:(BOOL)placeholder {
    NSAffineTransform *transform = [NSAffineTransform transform];
    NSSize thumbnailSize = size;
    CGFloat shadowBlurRadius = 0.0;
    CGFloat shadowOffset = 0.0;
    NSBitmapImageRep *imageRep;
    
    if (aSize > 0.0) {
        shadowBlurRadius = round(scale * aSize / 32.0) / scale;
        shadowOffset = -ceil(scale * shadowBlurRadius * 0.75) / scale;
        if (size.height > size.width)
            thumbnailSize = NSMakeSize(round((aSize - 2.0 * shadowBlurRadius) * size.width / size.height + 2.0 * shadowBlurRadius), aSize);
        else
            thumbnailSize = NSMakeSize(aSize, round((aSize - 2.0 * shadowBlurRadius) * size.height / size.width + 2.0 * shadowBlurRadius));
        [transform translateXBy:shadowBlurRadius yBy:shadowBlurRadius - shadowOffset];
        [transform scaleXBy:(thumbnailSize.width - 2.0 * shadowBlurRadius) / size.width yBy:(thumbnailSize.height - 2.0 * shadowBlurRadius) / size.height];
    }
    
    imageRep = [NSBitmapImageRep imageRepWithSize:thumbnailSize scale:scale drawingHandler:^(NSRect dstRect){
        
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        if (aSize > 0.0)
            [transform concat];
        
        [NSGraphicsContext saveGraphicsState];
        [[NSColor whiteColor] set];
        if (shadowBlurRadius > 0.0)
            [NSShadow setShadowWithWhite:0.0 alpha:0.3 blurRadius:shadowBlurRadius yOffset:shadowOffset];
        NSRectFill((NSRect){NSZeroPoint, size});
        
        if (placeholder == NO) {
            [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationDefault];
            [NSGraphicsContext restoreGraphicsState];
            [[NSBezierPath bezierPathWithRect:(NSRect){NSZeroPoint, size}] addClip];
            
            CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
            CGContextSetInterpolationQuality(context, interpolationQuality + 1);
            for (PDFDestination *dest in pages) {
                NSPoint point = [dest point];
                CGContextSaveGState(context);
                CGContextTranslateCTM(context, point.x, point.y);
                CGContextScaleCTM(context, scaleFactor, scaleFactor);
                [[dest page] drawWithBox:displayBox toContext:context];
                CGContextRestoreGState(context);
            }
        }
        
    }];
    
    return imageRep;
}

- (NSBitmapImageRep *)bitmapImageRepWithSize:(CGFloat)aSize scale:(CGFloat)scale {
    return [self bitmapImageRepWithSize:aSize scale:scale placeholder:NO];
}

- (NSImage *)thumbnailWithSize:(CGFloat)aSize scale:(CGFloat)scale {
    NSBitmapImageRep *imageRep = [self bitmapImageRepWithSize:aSize scale:scale];
    NSImage *image = [[NSImage alloc] initWithSize:[imageRep size]];
    [image addRepresentation:imageRep];
    return image;
}

- (NSImage *)placeholderThumbnailWithSize:(CGFloat)aSize scale:(CGFloat)scale {
    NSBitmapImageRep *imageRep = [self bitmapImageRepWithSize:aSize scale:scale placeholder:YES];
    NSImage *image = [[NSImage alloc] initWithSize:[imageRep size]];
    [image addRepresentation:imageRep];
    return image;
}

@end
