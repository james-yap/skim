//
//  SKPDFSyncParser.m
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

#import "SKPDFSyncParser.h"
#import "SKPDFSyncRecord.h"
#import "NSPointerFunctions_SKExtensions.h"

// Offset of coordinates in PDFKit and what pdfsync tells us. Don't know what they are; is this implementation dependent?
static NSPoint pdfOffset = {0.0, 0.0};

#define SKPDFSynchronizerPdfsyncExtension @"pdfsync"

#define PDFSYNC_TO_PDF(coord) ((CGFloat)coord / 65536.0)

static BOOL scanCharacter(NSScanner *scanner, unichar *ch);

@implementation SKPDFSyncParser

@synthesize syncFileName;

- (instancetype)initWithFileName:(NSString *)fileName {
    self = [super init];
    if (self) {
        if ([[fileName pathExtension] isEqualToString:SKPDFSynchronizerPdfsyncExtension])
            syncFileName = fileName;
        else
            syncFileName = [[fileName stringByDeletingPathExtension] stringByAppendingPathExtension:SKPDFSynchronizerPdfsyncExtension];
        if ([[NSURL fileURLWithPath:syncFileName isDirectory:NO] checkResourceIsReachableAndReturnError:NULL]) {
            pages = [[NSMutableArray alloc] init];
            lines = [[NSMapTable alloc] initWithKeyPointerFunctions:[NSPointerFunctions caseInsensitiveStringPointerFunctions] valuePointerFunctions:[NSPointerFunctions strongPointerFunctions] capacity:0];
            [self loadPdfsyncFile];
        } else {
            self = nil;
        }
    }
    return self;
}

static inline NSString *removeQuotes(NSString *file) {
    if ([file length] > 2 && [file characterAtIndex:0] == '"' && [file characterAtIndex:[file length] - 1] == '"')
        return [file substringWithRange:NSMakeRange(1, [file length] - 2)];
    return file;
}

static inline SKPDFSyncRecord *recordForIndex(NSMapTable *records, NSInteger recordIndex) {
    SKPDFSyncRecord *record = (__bridge SKPDFSyncRecord *)NSMapGet(records, (void *)recordIndex);
    if (record == nil) {
        record = [[SKPDFSyncRecord alloc] initWithRecordIndex:recordIndex];
        NSMapInsert(records, (void *)recordIndex, (__bridge void *)record);
    }
    return record;
}

- (void)loadPdfsyncFile {

    NSString *pdfsyncString = [NSString stringWithContentsOfFile:syncFileName encoding:NSUTF8StringEncoding error:NULL];
    
    if ([pdfsyncString length]) {
        
        NSMapTable *records = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsIntegerPersonality valueOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality capacity:0];
        NSMutableArray *files = [[NSMutableArray alloc] init];
        NSString *file;
        NSInteger recordIndex, line, pageIndex;
        double x, y;
        SKPDFSyncRecord *record;
        unichar ch;
        NSScanner *sc = [[NSScanner alloc] initWithString:pdfsyncString];
        NSCharacterSet *newlines = [NSCharacterSet newlineCharacterSet];
        
        [sc setCharactersToBeSkipped:[NSCharacterSet whitespaceCharacterSet]];
        
        if ([sc scanUpToCharactersFromSet:newlines intoString:&file] &&
            [sc scanCharactersFromSet:newlines intoString:NULL]) {
            
            file = removeQuotes(file);
            [files addObject:file];
            
            [lines setObject:[NSMutableArray array] forKey:file];
            
            // we ignore the version
            if ([sc scanString:@"version" intoString:NULL] && [sc scanInteger:NULL]) {
                
                [sc scanCharactersFromSet:newlines intoString:NULL];
                
                while (scanCharacter(sc, &ch)) {
                    
                    switch (ch) {
                        case 'l':
                            if ([sc scanInteger:&recordIndex] && [sc scanInteger:&line]) {
                                // we ignore the column
                                [sc scanInteger:NULL];
                                record = recordForIndex(records, recordIndex);
                                [record setFile:file];
                                [record setLine:line];
                                [[lines objectForKey:file] addObject:record];
                            }
                            break;
                        case 'p':
                            // we ignore * and + modifiers
                            if ([sc scanString:@"*" intoString:NULL] == NO)
                                [sc scanString:@"+" intoString:NULL];
                            if ([sc scanInteger:&recordIndex] && [sc scanDouble:&x] && [sc scanDouble:&y]) {
                                record = recordForIndex(records, recordIndex);
                                [record setPageIndex:[pages count] - 1];
                                [record setPoint:NSMakePoint(PDFSYNC_TO_PDF(x) + pdfOffset.x, PDFSYNC_TO_PDF(y) + pdfOffset.y)];
                                [[pages lastObject] addObject:record];
                            }
                            break;
                        case 's':
                            // start of a new page, the scanned integer should always equal [pages count]+1
                            if ([sc scanInteger:&pageIndex] == NO) pageIndex = [pages count] + 1;
                            while (pageIndex > (NSInteger)[pages count])
                                [pages addObject:[NSMutableArray array]];
                            break;
                        case '(':
                            // start of a new source file
                            if ([sc scanUpToCharactersFromSet:newlines intoString:&file]) {
                                file = removeQuotes(file);
                                [files addObject:file];
                                if ([lines objectForKey:file] == nil)
                                    [lines setObject:[NSMutableArray array] forKey:file];
                            }
                            break;
                        case ')':
                            // closing of a source file
                            if ([files count]) {
                                [files removeLastObject];
                                file = [files lastObject];
                            }
                            break;
                        default:
                            // shouldn't reach
                            break;
                    }
                    
                    [sc scanUpToCharactersFromSet:newlines intoString:NULL];
                    [sc scanCharactersFromSet:newlines intoString:NULL];
                }
                
                NSArray *lineSortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"line" ascending:YES]];
                NSArray *pointSortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"x" ascending:YES], [[NSSortDescriptor alloc] initWithKey:@"y" ascending:NO]];
                
                for (NSMutableArray *array in [lines objectEnumerator])
                    [array sortUsingDescriptors:lineSortDescriptors];
                [pages makeObjectsPerformSelector:@selector(sortUsingDescriptors:)
                                       withObject:pointSortDescriptors];
                
            }
        }
    }
}

- (void)enumerateSourceFilesUsingBlock:(void (^)(NSString *file))block {
    for (NSString *file in lines)
        block(file);
}

- (BOOL)findFile:(NSString * _Nullable __autoreleasing * _Nonnull)filePtr line:(NSInteger *)linePtr forLocation:(NSPoint)point inRect:(NSRect)rect pageBounds:(NSRect)bounds atPageIndex:(NSUInteger)pageIndex {
    BOOL rv = NO;
    if (pageIndex < [pages count]) {
        
        SKPDFSyncRecord *beforeRecord = nil;
        SKPDFSyncRecord *afterRecord = nil;
        NSMutableDictionary *atRecords = [NSMutableDictionary dictionary];
        
        for (SKPDFSyncRecord *record in [pages objectAtIndex:pageIndex]) {
            if ([record line] == 0)
                continue;
            NSPoint p = [record point];
            if (p.y > NSMaxY(rect)) {
                beforeRecord = record;
            } else if (p.y < NSMinY(rect)) {
                afterRecord = record;
                break;
            } else if (p.x < NSMinX(rect)) {
                beforeRecord = record;
            } else if (p.x > NSMaxX(rect)) {
                afterRecord = record;
                break;
            } else {
                [atRecords setObject:record forKey:[NSNumber numberWithDouble:fabs(p.x - point.x)]];
            }
        }
        
        SKPDFSyncRecord *record = nil;
        if ([atRecords count]) {
            NSNumber *nearest = [[[atRecords allKeys] sortedArrayUsingSelector:@selector(compare:)] objectAtIndex:0];
            record = [atRecords objectForKey:nearest];
        } else if (beforeRecord && afterRecord) {
            NSPoint beforePoint = [beforeRecord point];
            NSPoint afterPoint = [afterRecord point];
            if (beforePoint.y - point.y < point.y - afterPoint.y)
                record = beforeRecord;
            else if (beforePoint.y - point.y > point.y - afterPoint.y)
                record = afterRecord;
            else if (beforePoint.x - point.x < point.x - afterPoint.x)
                record = beforeRecord;
            else if (beforePoint.x - point.x > point.x - afterPoint.x)
                record = afterRecord;
            else
                record = beforeRecord;
        } else if (beforeRecord) {
            record = beforeRecord;
        } else if (afterRecord) {
            record = afterRecord;
        }
        
        if (record) {
            *linePtr = [record line];
            *filePtr = [record file];
            rv = YES;
        }
    }
    if (rv == NO)
        NSLog(@"PDFSync was unable to find file and line.");
    return rv;
}

- (BOOL)findPage:(NSUInteger *)pageIndexPtr location:(NSPoint *)pointPtr forLine:(NSInteger)line inFile:(NSString *)file {
    BOOL rv = NO;
    NSUInteger pageIndex = *pageIndexPtr == NSNotFound ? 0 : *pageIndexPtr;
    NSArray *theLines = [lines objectForKey:file];
    if (theLines) {
        
        SKPDFSyncRecord *beforeRecord = nil;
        SKPDFSyncRecord *afterRecord = nil;
        NSMutableArray *atRecords = [NSMutableArray array];
        
        for (SKPDFSyncRecord *record in theLines) {
            if ([record pageIndex] == NSNotFound)
                continue;
            NSInteger l = [record line];
            if (l < line) {
                beforeRecord = record;
            } else if (l > line) {
                afterRecord = record;
                break;
            } else {
                [atRecords addObject:record];
                break;
            }
        }
        
        SKPDFSyncRecord *record = nil;
        if ([atRecords count]) {
            record = [atRecords firstObject];
            for (SKPDFSyncRecord *atRecord in atRecords) {
                if (ABS([atRecord pageIndex] - (NSInteger)pageIndex) < ABS([record pageIndex] - (NSInteger)pageIndex))
                    record = atRecord;
            }
        } else if (beforeRecord && afterRecord) {
            NSInteger beforeLine = [beforeRecord line];
            NSInteger afterLine = [afterRecord line];
            if (beforeLine - line > line - afterLine)
                record = afterRecord;
            else
                record = beforeRecord;
        } else if (beforeRecord) {
            record = beforeRecord;
        } else if (afterRecord) {
            record = afterRecord;
        }
        
        if (record) {
            *pageIndexPtr = [record pageIndex];
            *pointPtr = [record point];
            rv = YES;
        }
    }
    if (rv == NO)
        NSLog(@"PDFSync was unable to find location and page.");
    return rv;
}

@end

static BOOL scanCharacter(NSScanner *scanner, unichar *ch) {
    NSInteger location, length = [[scanner string] length];
    unichar character = 0;
    BOOL success = NO;
    for (location = [scanner scanLocation]; success == NO && location < length; location++) {
        character = [[scanner string] characterAtIndex:location];
        success = [[scanner charactersToBeSkipped] characterIsMember:character] == NO;
    }
    if (success) {
        *ch = character;
        [scanner setScanLocation:location];
    }
    return success;
}
