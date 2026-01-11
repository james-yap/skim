//
//  SKDocumentController.h
//  Skim
//
//  Created by Christiaan Hofman on 5/21/07.
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

NS_ASSUME_NONNULL_BEGIN

extern NSString * const SKDocumentTypePDF;
extern NSString * const SKDocumentTypePDFBundle;
extern NSString * const SKDocumentTypeNotes;
extern NSString * const SKDocumentTypeNotesText;
extern NSString * const SKDocumentTypeNotesRTF;
extern NSString * const SKDocumentTypeNotesRTFD;
extern NSString * const SKDocumentTypeNotesFDF;
extern NSString * const SKDocumentTypePostScript;
extern NSString * const SKDocumentTypeEncapsulatedPostScript;
extern NSString * const SKDocumentTypeDVI;
extern NSString * const SKDocumentTypeXDV;
extern NSString * const SKDocumentTypeArchive;
extern NSString * const SKDocumentTypeFolder;

extern NSString * const SKDocumentSetupAliasKey;
extern NSString * const SKDocumentSetupBookmarkKey;
extern NSString * const SKDocumentSetupWindowFrameKey;
extern NSString * const SKDocumentSetupTabsKey;

extern NSNotificationName const SKDocumentControllerWillRemoveDocumentNotification;
extern NSNotificationName const SKDocumentControllerDidRemoveDocumentNotification;

extern NSString * const SKDocumentControllerDocumentKey;

@class SKBookmark;

@interface SKDocumentController : NSDocumentController {
    Class openDocumentClass;
}

- (IBAction)newDocumentFromClipboard:(nullable id)sender;

- (void)openDocumentWithImageFromPasteboard:(NSPasteboard *)pboard completionHandler:(void (^)(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error))completionHandler;
// this method may return an SKDownload instance
- (void)openDocumentWithURLFromPasteboard:(NSPasteboard *)pboard showNotes:(BOOL)showNotes completionHandler:(void (^)(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error))completionHandler;

- (void)openDocumentWithBookmark:(SKBookmark *)bookmark completionHandler:(void (^)(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error))completionHandler;
- (void)openDocumentWithBookmarks:(NSArray<SKBookmark *> *)bookmarks completionHandler:(void (^)(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error))completionHandler;

- (void)printDocumentsWithContentsOfURLs:(NSArray<NSURL *> *)urls withSettings:(NSDictionary<NSString *, id> *)printSettings showPrintPanels:(BOOL)showPrintPanels completionHandler:(void (^)(BOOL didPrintSuccessfully))completionHandler;

- (nullable Class)documentClassForContentsOfURL:(NSURL *)inAbsoluteURL;

@end

NS_ASSUME_NONNULL_END
