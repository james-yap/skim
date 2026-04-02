//
//  SKPDFSynchronizer.m
//  Skim
//
//  Created by Christiaan Hofman on 4/21/07.
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

#import "SKPDFSynchronizer.h"
#import "SKSyncTeXParser.h"
#import "SKPDFSyncParser.h"

static NSArray *SKPDFSynchronizerTexExtensions = nil;

@interface SKPDFSynchronizer ()
@property (nonatomic, nullable, strong) NSString *syncFileName;
@property (nonatomic, nullable, readonly) NSDate *lastModDate;
@end

@implementation SKPDFSynchronizer

@synthesize delegate, syncFileName, lastModDate;
@dynamic fileName;

+ (void)initialize {
    SKINITIALIZE;
    SKPDFSynchronizerTexExtensions = @[@"tex", @"ltx", @"latex", @"ctx", @"lyx", @"rnw"];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        queue = dispatch_queue_create("net.sourceforge.skim-app.queue.SKPDFSynchronizer", DISPATCH_QUEUE_SERIAL);
        
        lock = [[NSLock alloc] init];
        
        fileName = nil;
        syncFileName = nil;
        lastModDate = nil;
        
        parser = nil;
        sourceFileNames = nil;
        
        shouldKeepRunning = YES;
    }
    return self;
}

- (void)terminate {
    // make sure we're not calling our delegate
    delegate = nil;
    // set the stop flag immediately, so any running task may stop in its tracks
    atomic_store(&shouldKeepRunning, NO);
}

#pragma mark Thread safe accessors

- (NSString *)fileName {
    [lock lock];
    NSString *file = fileName;
    [lock unlock];
    return file;
}

- (void)setFileName:(NSString *)newFileName {
    // we compare filenames in canonical form throughout, so we need to make sure fileName also is in canonical form
    newFileName = [[newFileName stringByResolvingSymlinksInPath] stringByStandardizingPath];
    [lock lock];
    if (fileName != newFileName) {
        if ([fileName isEqualToString:newFileName] == NO) {
            syncFileName = nil;
            lastModDate = nil;
        }
        fileName = newFileName;
    }
    [lock unlock];
}

// this should only be used from the server thread
- (void)setSyncFileName:(NSString *)newSyncFileName {
    // make sure the path is absolute and standardized
    if ([newSyncFileName isAbsolutePath] == NO)
        newSyncFileName = [[[self fileName] stringByDeletingLastPathComponent] stringByAppendingPathComponent:newSyncFileName];
    newSyncFileName = [[newSyncFileName stringByResolvingSymlinksInPath] stringByStandardizingPath];
    [lock lock];
    if (syncFileName != newSyncFileName) {
        syncFileName = newSyncFileName;
    }
    NSDate *modDate = nil;
    if (syncFileName)
        [[NSURL fileURLWithPath:syncFileName isDirectory:NO] getResourceValue:&modDate forKey:NSURLContentModificationDateKey error:NULL];
    lastModDate = modDate;
    [lock unlock];
}

#pragma mark Support

- (NSString *)sourceFileForFileName:(NSString *)file {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([file isAbsolutePath] == NO)
        file = [[[self fileName] stringByDeletingLastPathComponent] stringByAppendingPathComponent:file];
    if (file && [fm fileExistsAtPath:file] == NO && [SKPDFSynchronizerTexExtensions containsObject:[[file pathExtension] lowercaseString]] == NO) {
        for (NSString *extension in SKPDFSynchronizerTexExtensions) {
            NSString *tryFile = [file stringByAppendingPathExtension:extension];
            if ([fm fileExistsAtPath:tryFile]) {
                file = tryFile;
                break;
            }
        }
    }
    // the docs say -stringByStandardizingPath uses -stringByResolvingSymlinksInPath, but it doesn't 
    return [[file stringByResolvingSymlinksInPath] stringByStandardizingPath];
}

- (NSString *)sourceFileNameForFile:(NSString *)file {
    file = [self sourceFileForFileName:file];
    NSString *sourceFile = [sourceFileNames objectForKey:file];
    if (sourceFile)
        return sourceFile;
    file = [file lastPathComponent];
    for (NSString *fn in sourceFileNames) {
        if ([[fn lastPathComponent] caseInsensitiveCompare:file] == NSOrderedSame)
            return [sourceFileNames objectForKey:fn];
    }
    return file;
}

- (NSString *)defaultSourceFile {
    NSString *file = [[self fileName] stringByDeletingPathExtension];
    if (file == nil)
        return nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *extension in SKPDFSynchronizerTexExtensions) {
        NSString *tryFile = [file stringByAppendingPathExtension:extension];
        if ([fm fileExistsAtPath:tryFile])
            return tryFile;
    }
    return [file stringByAppendingPathExtension:[SKPDFSynchronizerTexExtensions firstObject]];
}

#pragma mark Loading sync file

- (BOOL)loadSyncFile:(BOOL)pdfSync forFileName:(NSString *)theFileName {
    BOOL rv = NO;
    if (pdfSync)
        parser = [[SKPDFSyncParser alloc] initWithFileName:theFileName];
    else
        parser = [[SKSyncTeXParser alloc] initWithFileName:theFileName];
    if (parser) {
        isPdfsync = pdfSync;
        [self setSyncFileName:[parser syncFileName]];
        if (sourceFileNames == nil)
            sourceFileNames = [[NSMutableDictionary alloc] init];
        else
            [sourceFileNames removeAllObjects];
        [parser enumerateSourceFilesUsingBlock:^(NSString *file){
            [sourceFileNames setObject:file forKey:[self sourceFileForFileName:file]];
        }];
        rv = atomic_load(&shouldKeepRunning);
    }
    return rv;
}

- (BOOL)loadSyncFileIfNeeded {
    NSString *theFileName = [self fileName];
    BOOL rv = NO;
    
    if (theFileName) {
        [lock lock];
        NSString *theSyncFileName = [self syncFileName];
        NSDate *currentModDate = [self lastModDate];
        [lock unlock];
        
        if (theSyncFileName && [[NSFileManager defaultManager] fileExistsAtPath:theSyncFileName]) {
            NSDate *modDate = nil;
            if (currentModDate)
                [[NSURL fileURLWithPath:theSyncFileName isDirectory:NO] getResourceValue:&modDate forKey:NSURLContentModificationDateKey error:NULL];
        
            if (currentModDate && [modDate compare:currentModDate] != NSOrderedDescending)
                rv = YES;
            else if (isPdfsync)
                rv = [self loadSyncFile:YES forFileName:theSyncFileName];
            if (rv == NO)
                rv = [self loadSyncFile:NO forFileName:theFileName];
        } else {
            rv = [self loadSyncFile:NO forFileName:theFileName];
            if (rv == NO)
                rv = [self loadSyncFile:YES forFileName:theFileName];
        }
    }
    if (rv == NO)
        NSLog(@"Unable to find or load synctex or pdfsync file.");
    return rv;
}

#pragma mark Finding API

- (void)findFileAndLineForLocation:(NSPoint)point inRect:(NSRect)rect pageBounds:(NSRect)bounds atPageIndex:(NSUInteger)pageIndex {
    dispatch_async(queue, ^{
        if (atomic_load(&shouldKeepRunning) && [self loadSyncFileIfNeeded]) {
            NSInteger foundLine = 0;
            NSString *foundFile = nil;
            BOOL success = [parser findFile:&foundFile line:&foundLine forLocation:point inRect:rect pageBounds:bounds atPageIndex:pageIndex];
            
            if (success && atomic_load(&shouldKeepRunning)) {
                foundFile = [[sourceFileNames allKeysForObject:foundFile] firstObject] ?: [self sourceFileForFileName:foundFile];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate synchronizerFoundLine:foundLine inFile:foundFile];
                });
            }
        }
    });
}

- (void)findPageAndLocationForLine:(NSInteger)line inFile:(NSString *)file fromPageIndex:(NSUInteger)pageIndex options:(SKPDFSynchronizerOptions)options {
    if (file == nil)
        file = [self defaultSourceFile];
    if (file == nil)
        return;
    dispatch_async(queue, ^{
        if (atomic_load(&shouldKeepRunning) && [self loadSyncFileIfNeeded]) {
            NSUInteger foundPageIndex = pageIndex;
            NSPoint foundPoint = NSZeroPoint;
            SKPDFSynchronizerOptions foundOptions = options;
            BOOL success = NO;
            NSString *sourceFile = [self sourceFileNameForFile:file];
            success = [parser findPage:&foundPageIndex location:&foundPoint forLine:line inFile:sourceFile];
            
            if (success && atomic_load(&shouldKeepRunning)) {
                if (isPdfsync)
                    foundOptions &= ~SKPDFSynchronizerFlipped;
                else
                    foundOptions |= SKPDFSynchronizerFlipped;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate synchronizerFoundLocation:foundPoint atPageIndex:foundPageIndex options:foundOptions];
                });
            }
        }
    });
}

@end
