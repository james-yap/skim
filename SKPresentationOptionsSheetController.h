//
//  SKPresentationOptionsSheetController.h
//  Skim
//
//  Created by Christiaan Hofman on 9/28/08.
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

#import <Cocoa/Cocoa.h>
#import "SKTableView.h"

NS_ASSUME_NONNULL_BEGIN

@class SKMainWindowController, SKLabeledTransitionInfo, SKPDFPageView;

@interface SKPresentationOptionsSheetController : NSWindowController <NSWindowDelegate, SKTableViewDelegate, NSTableViewDataSource, NSTouchBarDelegate> {
    NSPopUpButton *notesDocumentPopUpButton;
    SKTableView *tableView;
    NSPopUpButton *stylePopUpButton;
    NSButton *okButton;
    NSButton *cancelButton;
    NSButton *previewButton;
    NSLayoutConstraint *boxLeadingConstraint;
    NSLayoutConstraint *tableWidthConstraint;
    NSArrayController *arrayController;
    BOOL separate;
    SKLabeledTransitionInfo *transition;
    NSArray<SKLabeledTransitionInfo *> *transitions;
    __weak SKMainWindowController *controller;
    NSUndoManager *undoManager;
    NSMutableSet<SKLabeledTransitionInfo *> *changedTransitions;
    NSPanel *previewWindow;
    SKPDFPageView *previewView;
    BOOL previewing;
}

@property (nonatomic, nullable, strong) IBOutlet NSPopUpButton *notesDocumentPopUpButton;
@property (nonatomic, nullable, strong) IBOutlet SKTableView *tableView;
@property (nonatomic, nullable, strong) IBOutlet NSPopUpButton *stylePopUpButton;
@property (nonatomic, nullable, strong) IBOutlet NSButton *okButton, *cancelButton, *previewButton;
@property (nonatomic, nullable, strong) IBOutlet NSLayoutConstraint *boxLeadingConstraint, *tableWidthConstraint;
@property (nonatomic, nullable, strong) IBOutlet NSArrayController *arrayController;

@property (nonatomic, readonly) NSArray<NSString *> *availableTransitions;

@property (nonatomic) BOOL separate;
@property (nonatomic, copy) NSArray<SKLabeledTransitionInfo *> *transitions;

- (instancetype)initForController:(SKMainWindowController *)aController NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithWindow:(nullable NSWindow *)window NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (IBAction)preview:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
