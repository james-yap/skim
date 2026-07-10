//
//  SKThumbnail.m
//  Skim
//
//  Created by Christiaan Hofman on 2/16/07.
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

#import "SKThumbnail.h"


@implementation SKThumbnail

@synthesize delegate, label, pageIndex, needsUpdate, placeholder;
@dynamic image, size, page;

- (instancetype)initWithImage:(NSImage *)anImage label:(NSString *)aLabel pageIndex:(NSUInteger)anIndex {
    self = [super init];
    if (self) {
        image = anImage;
        label = aLabel;
        pageIndex = anIndex;
        needsUpdate = YES;
        placeholder = YES;
    }
    return self;
}

- (NSImage *)image {
    if (needsUpdate && [delegate generateImageForThumbnail:self])
        needsUpdate = NO;
    return image;
}

- (void)setImage:(NSImage *)newImage {
    if (image != newImage) {
        image = newImage;
        [image setAccessibilityDescription:[NSString stringWithFormat:NSLocalizedString(@"Page %@", @""), [self label]]];
        placeholder = NO;
    }
}

- (NSSize)size {
    return [image size];
}

- (PDFPage *)page {
    return [delegate pageForThumbnail:self];
}

- (void)setLabel:(NSString *)newLabel {
    if (newLabel != label) {
        label = newLabel;
        [image setAccessibilityDescription:[NSString stringWithFormat:NSLocalizedString(@"Page %@", @""), label]];
    }
}

- (void)setNeedsUpdate:(BOOL)flag {
    if (flag) {
        [self willChangeValueForKey:@"image"];
        needsUpdate = YES;
        [self didChangeValueForKey:@"image"];
    } else {
        needsUpdate = NO;
    }
}

@end
