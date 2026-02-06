//
//  SKSyncTeXParser.m
//  Skim
//
//  Created by Christiaan Hofman on 04/04/2024.
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

#import "SKSyncTeXParser.h"


@implementation SKSyncTeXParser

@dynamic syncFileName;

- (instancetype)initWithFileName:(NSString *)fileName {
    self = [super init];
    if (self) {
        scanner = synctex_scanner_new_with_output_file([fileName UTF8String], NULL, 1);
        if (scanner == NULL) {
            self = nil;
        }
    }
    return self;
}

- (void)dealloc {
    if (scanner) synctex_scanner_free(scanner);
    scanner = NULL;
}

- (NSString *)syncFileName {
    const char *fileRep = synctex_scanner_get_synctex(scanner);
    return fileRep ? [NSString stringWithUTF8String:fileRep] : nil;
}

- (void)enumerateSourceFilesUsingBlock:(void (^)(NSString *file))block {
    synctex_node_p node = synctex_scanner_input(scanner);
    do {
        const char *fileRep = synctex_scanner_get_name(scanner, synctex_node_tag(node));
        if (fileRep)
            block([NSString stringWithUTF8String:fileRep]);
    } while ((node = synctex_node_next(node)));
}

- (BOOL)findFile:(NSString * _Nullable __autoreleasing * _Nonnull)filePtr line:(NSInteger *)linePtr forLocation:(NSPoint)point inRect:(NSRect)rect pageBounds:(NSRect)bounds atPageIndex:(NSUInteger)pageIndex {
    BOOL rv = NO;
    if (synctex_edit_query(scanner, (int)pageIndex + 1, point.x, NSMaxY(bounds) - point.y) > 0) {
        synctex_node_p node;
        const char *file;
        while (rv == NO && (node = synctex_scanner_next_result(scanner))) {
            if ((file = synctex_scanner_get_name(scanner, synctex_node_tag(node)))) {
                *linePtr = MAX(synctex_node_line(node), 1) - 1;
                *filePtr = [NSString stringWithUTF8String:file];
                rv = YES;
            }
        }
    }
    if (rv == NO)
        NSLog(@"SyncTeX was unable to find file and line.");
    return rv;
}

- (BOOL)findPage:(NSUInteger *)pageIndexPtr location:(NSPoint *)pointPtr forLine:(NSInteger)line inFile:(NSString *)file {
    BOOL rv = NO;
    const char *filename = [file UTF8String];
    NSUInteger pageIndex = *pageIndexPtr == NSNotFound ? 0 : 1 + *pageIndexPtr;
    if (synctex_display_query(scanner, filename, (int)line + 1, 0, pageIndex) > 0) {
        synctex_node_p node = synctex_scanner_next_result(scanner);
        if (node) {
            NSUInteger page = synctex_node_page(node);
            *pageIndexPtr = MAX(page, 1ul) - 1;
            *pointPtr = NSMakePoint(synctex_node_visible_h(node), synctex_node_visible_v(node));
            rv = YES;
        }
    }
    if (rv == NO)
        NSLog(@"SyncTeX was unable to find location and page.");
    return rv;
}

@end
