//
//  SKApplicationController.m
//  Skim
//
//  Created by Michael McCracken on 12/6/06.
/*
 This software is Copyright (c) 2006
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "SKApplicationController.h"
#import "SKApplication.h"
#import "SKLineInspector.h"
#import "SKNotesPanelController.h"
#import "SKPreferenceController.h"
#import "SKReleaseNotesController.h"
#import "SKInfoWindowController.h"
#import "SKStringConstants.h"
#import "SKMainDocument.h"
#import "SKMainWindowController.h"
#import "SKMainWindowController_Actions.h"
#import "SKBookmarkController.h"
#import "SKBookmark.h"
#import "SKVersionNumber.h"
#import "NSUserDefaults_SKExtensions.h"
#import <Quartz/Quartz.h>
#import <Sparkle/Sparkle.h>
#import "NSImage_SKExtensions.h"
#import "SKDownloadController.h"
#import "SKDownload.h"
#import "NSURL_SKExtensions.h"
#import "SKDocumentController.h"
#import "NSDocument_SKExtensions.h"
#import "NSFileManager_SKExtensions.h"
#import <SkimNotes/SkimNotes.h>
#import "NSGeometry_SKExtensions.h"
#import "SKFDFParser.h"
#import "SKScriptMenu.h"
#import "NSScreen_SKExtensions.h"
#import "NSError_SKExtensions.h"
#import "NSValueTransformer_SKExtensions.h"
#import "SKAnimatedBorderlessWindow.h"
#import "NSGraphics_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "SKNoteOutlineView.h"
#import "NSView_SKExtensions.h"
#import "SKColorList.h"
#import "NSCharacterSet_SKExtensions.h"
#import "SKNotePrefs.h"
#import "SKDisplayPrefs.h"
#import "NSData_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "NSWindow_SKExtensions.h"

#define WEBSITE_URL @"https://skim-app.sourceforge.io/"
#define WIKI_URL    @"https://sourceforge.net/p/skim-app/wiki/"

#define INITIAL_USER_DEFAULTS_FILENAME  @"InitialUserDefaults"
#define REGISTERED_DEFAULTS_KEY         @"RegisteredDefaults"
#define RESETTABLE_KEYS_KEY             @"ResettableKeys"

#define VIEW_MENU_INDEX      4
#define PDF_MENU_INDEX       5

#define REOPEN_WARNING_LIMIT 50

#define CURRENTDOCUMENTSETUP_INTERVAL 300.0

#define CURRENTDOCUMENTSETUP_KEY @"currentDocumentSetup"

#define SKIsRelaunchKey                     @"SKIsRelaunch"
#define SKLastVersionLaunchedKey            @"SKLastVersionLaunched"
#define SKSpotlightVersionInfoKey           @"SKSpotlightVersionInfo"
#define SKSpotlightLastImporterVersionKey   @"lastImporterVersion"
#define SKSpotlightLastSysVersionKey        @"lastSysVersion"

#define SKCircleInteriorString  @"CircleInterior"
#define SKSquareInteriorString  @"SquareInterior"
#define SKLineInteriorString    @"LineInterior"
#define SKFreeTextFontString    @"FreeTextFont"

static char SKApplicationControllerDefaultsObservationContext;

enum {
    SKReopenNever = 0,
    SKReopenOnDefaultLaunch = 1,
    SKReopenAlways = 2
};

@interface SKApplicationController ()
@property (nonatomic, readonly) SKDownloadController *downloadController;
@end

@implementation SKApplicationController

@synthesize noteColumnsMenu, noteTypeMenu;
@dynamic downloadController, favoriteColors, bookmarks, downloads;

+ (void)initialize{
    SKINITIALIZE;
    
    // load the default values for the user defaults
    NSURL *initialUserDefaultsURL = [[NSBundle mainBundle] URLForResource:INITIAL_USER_DEFAULTS_FILENAME withExtension:@"plist"];
    NSDictionary *initialUserDefaultsDict = [NSDictionary dictionaryWithContentsOfURL:initialUserDefaultsURL error:NULL];
    NSMutableDictionary *initialValuesDict = [[initialUserDefaultsDict objectForKey:REGISTERED_DEFAULTS_KEY] mutableCopy];
    NSArray *resettableUserDefaultsKeys;
    
    [initialValuesDict setValue:NSFullUserName() forKey:SKUserNameKey];
    
    NSURL *downloadsURL = [[NSFileManager defaultManager] URLForDirectory:NSDownloadsDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
    if (downloadsURL)
        [initialValuesDict setValue:[[downloadsURL path] stringByAbbreviatingWithTildeInPath] forKey:SKDownloadsDirectoryKey];
    
    // set them in the standard user defaults
    [[NSUserDefaults standardUserDefaults] registerDefaults:initialValuesDict];
    
    // if your application supports resetting a subset of the defaults to
    // factory values, you should set those values 
    // in the shared user defaults controller
    
    resettableUserDefaultsKeys = [[[initialUserDefaultsDict objectForKey:RESETTABLE_KEYS_KEY] allValues] valueForKeyPath:@"@unionOfArrays.self"];
    
    // Set the initial values in the shared user defaults controller 
    [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:[initialValuesDict dictionaryWithValuesForKeys:resettableUserDefaultsKeys]];
}

- (void)registerCurrentDocuments:(id)timerOrNotification {
    [[NSUserDefaults standardUserDefaults] setObject:[[NSApp orderedDocuments] valueForKey:CURRENTDOCUMENTSETUP_KEY] forKey:SKLastOpenFileNamesKey];
    BOOL forced = timerOrNotification == nil;
    [[[NSDocumentController sharedDocumentController] documents] makeObjectsPerformSelector:forced ? @selector(saveRecentDocumentInfo) : @selector(saveRecentDocumentInfoIfNeeded)];
}


- (void)startObservingCurrentDocuments {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(registerCurrentDocuments:)
                             name:SKDocumentDidShowNotification object:nil];
    [nc addObserver:self selector:@selector(registerCurrentDocuments:)
                             name:SKDocumentControllerDidRemoveDocumentNotification object:nil];
    
    currentDocumentsTimer = [NSTimer scheduledTimerWithTimeInterval:CURRENTDOCUMENTSETUP_INTERVAL target:self selector:@selector(registerCurrentDocuments:) userInfo:nil repeats:YES];
}

- (void)stopObservingCurrentDocuments {
    [currentDocumentsTimer invalidate];
    currentDocumentsTimer = nil;
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:SKDocumentDidShowNotification object:nil];
    [nc removeObserver:self name:SKDocumentControllerDidRemoveDocumentNotification object:nil];
}

- (void)reopenLastOpenFiles {
    didReopen = YES;
    
    SKBookmark *previousSession = [[SKBookmarkController sharedBookmarkController] previousSession];
    if (previousSession)
        [[NSDocumentController sharedDocumentController] openDocumentWithBookmark:previousSession completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error){
            if (document == nil && error && [error isUserCancelledError] == NO)
                [NSApp presentError:error];
        }];
}

#pragma mark NSApplication delegate

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    
    [NSImage makeImages];
    [NSColor makeHighlightColors];
    [NSValueTransformer registerCustomTransformers];
    [PDFPage setUsesSequentialPageNumbering:[[NSUserDefaults standardUserDefaults] boolForKey:SKSequentialPageNumberingKey]];
    [sud addObserver:self forKeyPath:SKSequentialPageNumberingKey options:0 context:&SKApplicationControllerDefaultsObservationContext];
    
    NSMenu *menu = [[[NSApp mainMenu] itemAtIndex:VIEW_MENU_INDEX] submenu];
    for (NSMenuItem *menuItem in [menu itemArray]) {
        if ([menuItem action] == @selector(changeLeftSidePaneState:) || [menuItem action] == @selector(changeRightSidePaneState:) || [menuItem action] == @selector(changeFindPaneState:))
            [menuItem setIndentationLevel:1];
    }
    
    // this creates the script menu if needed
    (void)[NSApp scriptMenu];
    
    if ([sud integerForKey:SKReopenLastOpenFilesKey] == SKReopenAlways || [sud boolForKey:SKIsRelaunchKey]) {
        // just remove this in case opening the last open files crashes the app after a relaunch
        if ([sud objectForKey:SKIsRelaunchKey]) {
            [sud removeObjectForKey:SKIsRelaunchKey];
            [sud synchronize];
        }
        [self reopenLastOpenFiles];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    
    if (didReopen == NO && [sud integerForKey:SKReopenLastOpenFilesKey] == SKReopenOnDefaultLaunch && [[[aNotification userInfo] objectForKey:NSApplicationLaunchIsDefaultLaunchKey] boolValue])
        [self reopenLastOpenFiles];
    
    [NSApp setServicesProvider:[NSDocumentController sharedDocumentController]];
    
    NSString *versionString = [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleVersionKey];
    NSString *lastVersionString = [sud stringForKey:SKLastVersionLaunchedKey];
    if (lastVersionString == nil || [SKVersionNumber compareVersionString:lastVersionString toVersionString:versionString] == NSOrderedAscending) {
        [self showReleaseNotes:nil];
        [sud setObject:versionString forKey:SKLastVersionLaunchedKey];
    }
	
    [self performSelector:@selector(startObservingCurrentDocuments) withObject:nil afterDelay:1.0];
    
    // kHIDRemoteModeExclusiveAuto lets the HIDRemote handle activation when the app gets or loses focus
    if ([sud boolForKey:SKEnableAppleRemoteKey]) {
        [[HIDRemote sharedHIDRemote] startRemoteControl:kHIDRemoteModeExclusiveAuto];
        [[HIDRemote sharedHIDRemote] setDelegate:self];
    }
    
    [[NSColorPanel sharedColorPanel] attachColorList:[SKColorList favoriteColorList]];
    
    [[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
    
    [NSApp setAutomaticCustomizeTouchBarMenuItemEnabled:YES];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)application {
    return NO;
}

- (void)application:(NSApplication *)application openURLs:(NSArray *)urls {
    NSAppleEventDescriptor *errr = [[[NSAppleEventManager sharedAppleEventManager] currentAppleEvent] descriptorForKeyword:'errr'];
    BOOL errorReporting = errr ? [errr booleanValue] : YES;
    
    for (NSURL *theURL in urls) {
        if ([theURL isFileURL]) {
            [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:theURL display:YES completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error) {
                if (document == nil && errorReporting && error && [error isUserCancelledError] == NO)
                    [NSApp presentError:error];
            }];
        } else if ([theURL isSkimURL]) {
            if ([theURL isSkimBookmarkURL]) {
                SKBookmark *bookmark = [[SKBookmarkController sharedBookmarkController] bookmarkForURL:theURL];
                if (bookmark) {
                    [[NSDocumentController sharedDocumentController] openDocumentWithBookmark:bookmark completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error) {
                        if (document == nil && errorReporting && error && [error isUserCancelledError] == NO)
                            [NSApp presentError:error];
                    }];
                }
            } else {
                [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[theURL associatedFileURL] display:YES completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error) {
                    if (document == nil && errorReporting && error && [error isUserCancelledError] == NO)
                        [NSApp presentError:error];
                }];
            }
        } else if (theURL) {
            SKDownload *download = [[SKDownload alloc] initWithURL:theURL];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:SKAutoOpenDownloadsWindowKey])
                [[self downloadController] showWindow:self];
            [[self downloadController] addObjectToDownloads:download];
        }
    }
}

- (NSApplicationPrintReply)application:(NSApplication *)application printFiles:(NSArray *)fileNames withSettings:(NSDictionary *)printSettings showPrintPanels:(BOOL)showPrintPanels {
    // keep track to see whether we finished before this method returns
    __block NSApplicationPrintReply reply = NSNotFound;
    NSMutableArray *fileURLs = [NSMutableArray array];
    for (NSString *fileName in fileNames)
        [fileURLs addObject:[NSURL fileURLWithPath:fileName]];
    
    [[NSDocumentController sharedDocumentController] printDocumentsWithContentsOfURLs:fileURLs withSettings:printSettings showPrintPanels:showPrintPanels completionHandler:^(BOOL didPrintSuccessfully){
        if (reply == NSPrintingReplyLater)
            [NSApp replyToOpenOrPrint:didPrintSuccessfully ? NSApplicationDelegateReplySuccess : NSApplicationDelegateReplyFailure];
        reply = didPrintSuccessfully ? NSPrintingSuccess : NSPrintingFailure;
    }];
    
    // setting this tells the async block that we returned
    if (reply == NSNotFound)
        reply = NSPrintingReplyLater;
    return reply;
}

static inline NSDocument *presentationDocument(void) {
    for (NSDocument *doc in [[NSDocumentController sharedDocumentController] documents]) {
        if ([doc interactionMode] == SKPresentationMode)
            return doc;
    }
    return nil;
}

- (void)applicationStartsTerminating:(NSApplication *)application {
    [self stopObservingCurrentDocuments];
    
    [presentationDocument() setInteractionMode:SKNormalMode];
    
    [self registerCurrentDocuments:nil];
}

- (void)applicationCanceledTerminating:(NSApplication *)application {
    if (currentDocumentsTimer == nil)
        [self startObservingCurrentDocuments];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)application {
    NSDocument *doc = presentationDocument();
    if ([doc canExitPresentation]) {
        [doc setInteractionMode:SKNormalMode];
    } else if (doc) {
        DISPATCH_MAIN_AFTER_SEC(0.51, ^{
            if ([doc interactionMode] != SKPresentationMode) {
                [NSApp replyToApplicationShouldTerminate:YES];
            } else if ([doc canExitPresentation]) {
                [doc setInteractionMode:SKNormalMode];
                [NSApp replyToApplicationShouldTerminate:YES];
            } else {
                [NSApp replyToApplicationShouldTerminate:NO];
            }
        });
        return NSTerminateLater;
    }
    return NSTerminateNow;
}

#pragma mark Updater

- (void)updaterWillRelaunchApplication:(SPUUpdater *)updater {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SKIsRelaunchKey];
}

#pragma mark Download Controller

- (SKDownloadController *)downloadController {
    if (downloadController == nil)
        downloadController = [[SKDownloadController alloc] init];
    return downloadController;
}

#pragma mark Actions

- (IBAction)orderFrontLineInspector:(id)sender {
    NSWindow *window = [[SKLineInspector sharedLineInspector] window];
    if ([window isVisible])
        [window orderOut:sender];
    else
        [window orderFront:sender];
}

- (IBAction)orderFrontNotesPanel:(id)sender {
    if (notesPanelController == nil)
        notesPanelController = [[SKNotesPanelController alloc] init];
    NSWindow *window = [notesPanelController window];
    if ([window isVisible])
        [window orderOut:sender];
    else
        [window orderFront:sender];
}

- (IBAction)visitWebSite:(id)sender{
    if([[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:WEBSITE_URL]] == NO)
        NSBeep();
}

- (IBAction)visitWiki:(id)sender{
    if([[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:WIKI_URL]] == NO)
        NSBeep();
}

- (IBAction)showPreferencePanel:(id)sender{
    if (preferenceController == nil)
        preferenceController = [[SKPreferenceController alloc] init];
    [preferenceController showWindow:self];
}

- (IBAction)showReleaseNotes:(id)sender{
    if (releaseNotesController == nil)
        releaseNotesController = [[SKReleaseNotesController alloc] init];
    [releaseNotesController showWindow:self];
}

- (IBAction)showDownloads:(id)sender{
    [[self downloadController] showWindow:self];
}

- (IBAction)getInfo:(id)sender {
    if (infoWindowController == nil)
        infoWindowController = [[SKInfoWindowController alloc] init];
    [infoWindowController showWindow:self];
}

- (IBAction)changeFindPaneState:(id)sender {}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = [menuItem action];
    if (action == @selector(orderFrontLineInspector:)) {
        if ([SKLineInspector sharedLineInspectorExists] && [[[SKLineInspector sharedLineInspector] window] isVisible])
            [menuItem setTitle:NSLocalizedString(@"Hide Lines", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Lines", @"Menu item title")];
        return YES;
    } else if (action == @selector(orderFrontNotesPanel:)) {
        if ( [[notesPanelController window] isVisible])
            [menuItem setTitle:NSLocalizedString(@"Hide Note Type", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Note Type", @"Menu item title")];
        return YES;
    } else if (action == @selector(getInfo:)) {
        return [[[NSApp mainWindow] windowController] document] != nil;
    } else if (action == @selector(changeFindPaneState:)) {
        [menuItem setHidden:YES];
        return NO;
    }
    return YES;
}

- (void)showRemoteSwitchIndication {
    NSTimeInterval timeInterval = [[NSUserDefaults standardUserDefaults] floatForKey:SKAppleRemoteSwitchIndicationTimeoutKey];
    if (timeInterval > 0.0) {
        static SKAnimatedBorderlessWindow *remoteStateWindow = nil;
        if (remoteStateWindow == nil) {
            NSRect contentRect = SKRectFromCenterAndSize(SKCenterPoint([[NSScreen mainScreen] frame]), SKMakeSquareSize(60.0));
            remoteStateWindow = [[SKAnimatedBorderlessWindow alloc] initWithContentRect:contentRect];
            [remoteStateWindow setDisplaysWhenScreenProfileChanges:NO];
            [remoteStateWindow setLevel:NSStatusWindowLevel];
            [remoteStateWindow setAutoHideTimeInterval:timeInterval];
            contentRect.origin = NSZeroPoint;
            NSVisualEffectView *contentView = [[NSVisualEffectView alloc] init];

            if (@available(macOS 10.14, *))
                [contentView setMaterial:NSVisualEffectMaterialUnderWindowBackground];
            else
                [contentView setMaterial:NSVisualEffectMaterialAppearanceBased];
            [contentView setState:NSVisualEffectStateActive];
            [remoteStateWindow setContentView:contentView];
            [contentView setMaskImage:[NSImage maskImageWithSize:contentRect.size cornerRadius:10.0]];
         }
        [remoteStateWindow center];
        [remoteStateWindow addImageViewWithImage:[NSImage imageNamed:remoteScrolling ? SKImageNameRemoteStateScroll : SKImageNameRemoteStateResize]];
        [remoteStateWindow orderFrontRegardless];
    }
}

- (void)hidRemote:(HIDRemote *)hidRemote eventWithButton:(HIDRemoteButtonCode)buttonCode isPressed:(BOOL)isPressed fromHardwareWithAttributes:(NSMutableDictionary *)attributes {
    if (isPressed) {
        if (buttonCode == kHIDRemoteButtonCodeMenu) {
            remoteScrolling = !remoteScrolling;
            [self showRemoteSwitchIndication];
        } else {
            NSEvent *theEvent = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                                                   location:NSZeroPoint
                                              modifierFlags:0
                                                  timestamp:[[NSProcessInfo processInfo] systemUptime]
                                               windowNumber:0
                                                    context:nil
                                                    subtype:SKRemoteButtonEvent
                                                      data1:buttonCode
                                                      data2:remoteScrolling];
            [NSApp postEvent:theEvent atStart:YES];
        }
    }
}

#pragma mark NSMenu Delegate

- (void)menuNeedsUpdate:(NSMenu *)menu {
    NSMenu *notesMenu = [[[NSDocumentController sharedDocumentController] currentDocument] notesMenu];
    [menu removeAllItems];
    if (notesMenu) {
        if (menu == noteColumnsMenu) {
            for (NSMenuItem *item in [notesMenu itemArray]) {
                if ([item isSeparatorItem])
                    break;
                [menu addItem:[item copy]];
            }
        } else if (menu == noteTypeMenu) {
            notesMenu = [[notesMenu itemAtIndex:[notesMenu numberOfItems] - 1] submenu];
            for (NSMenuItem *item in [notesMenu itemArray]) {
                [menu addItem:[item copy]];
            }
        }
    } else {
        [menu addItemWithTitle:NSLocalizedString(@"No Document", @"Menu item title") action:NULL keyEquivalent:@""];
    }
}

- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action { return NO; }

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &SKApplicationControllerDefaultsObservationContext) {
        if ([keyPath isEqualToString:SKSequentialPageNumberingKey]) {
            [PDFPage setUsesSequentialPageNumbering:[[NSUserDefaults standardUserDefaults] boolForKey:SKSequentialPageNumberingKey]];
            [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFPageLabelsChangedNotification object:nil];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Scripting support

- (BOOL)application:(NSApplication *)application delegateHandlesKey:(NSString *)key {
    static NSSet *applicationScriptingKeys = nil;
    if (applicationScriptingKeys == nil)
        applicationScriptingKeys = [[NSSet alloc] initWithObjects:@"bookmarks", @"downloads", @"notePreferences", @"displayPreferences", @"richTextFormat", @"favoriteColors", nil];
	return [applicationScriptingKeys containsObject:key];
}

- (id)newScriptingObjectOfClass:(Class)objectClass forValueForKey:(NSString *)key withContentsValue:(id)contentsValue properties:(NSDictionary *)properties {
    if ([key isEqualToString:@"bookmarks"]) {
        return [[[SKBookmarkController sharedBookmarkController] bookmarkRoot] newScriptingObjectOfClass:objectClass forValueForKey:key withContentsValue:contentsValue properties:properties];
    } else if ([key isEqualToString:@"downloads"]) {
        NSString *urlString = [properties objectForKey:@"scriptingURL"] ?: contentsValue;
        if (urlString == nil) {
            [[NSScriptCommand currentCommand] setScriptErrorNumber:NSRequiredArgumentsMissingScriptError];
            [[NSScriptCommand currentCommand] setScriptErrorString:@"New downloads requires a URL."];
            return nil;
        } else if ([urlString isKindOfClass:[NSString class]] == NO) {
            [[NSScriptCommand currentCommand] setScriptErrorNumber:NSArgumentsWrongScriptError];
            [[NSScriptCommand currentCommand] setScriptErrorString:@"URL must be text."];
            return nil;
        } else {
            return [[SKDownload alloc] initWithURL:[NSURL URLWithString:urlString]];
        }
    } else {
        return [super newScriptingObjectOfClass:objectClass forValueForKey:key withContentsValue:contentsValue properties:properties];
    }
}

- (NSArray *)bookmarks {
    return [[[SKBookmarkController sharedBookmarkController] bookmarkRoot] bookmarks];
}

- (void)insertObject:(SKBookmark *)bookmark inBookmarksAtIndex:(NSUInteger)anIndex {
    [[[SKBookmarkController sharedBookmarkController] bookmarkRoot] insertObject:bookmark inBookmarksAtIndex:anIndex];
}

- (void)removeObjectFromBookmarksAtIndex:(NSUInteger)anIndex {
    [[[SKBookmarkController sharedBookmarkController] bookmarkRoot] removeObjectFromBookmarksAtIndex:anIndex];
}

- (NSArray *)downloads {
    return [[self downloadController] downloads];
}

- (void)insertObject:(SKDownload *)download inDownloadsAtIndex:(NSUInteger)anIndex {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKAutoOpenDownloadsWindowKey])
        [[self downloadController] showWindow:nil];
    [[self downloadController] addObjectToDownloads:download];
}

- (void)removeObjectFromDownloadsAtIndex:(NSUInteger)anIndex {
    SKDownload *download = [[[self downloadController] downloads] objectAtIndex:anIndex];
    if ([download canRemove])
        [[self downloadController] removeObjectFromDownloads:download];
}

- (SKNotePrefs *)valueInNotePreferencesWithName:(NSString *)name {
    return [[SKNotePrefs alloc] initWithType:name];
}

- (SKDisplayPrefs *)valueInDisplayPreferencesWithName:(NSString *)name {
    return [[SKDisplayPrefs alloc] initWithName:name];
}

- (NSAttributedString *)valueInRichTextFormatWithName:(NSString *)name {
    NSData *data = [[NSData alloc] initWithHexString:name];
    return data ? [[NSAttributedString alloc] initWithData:data options:@{} documentAttributes:NULL error:NULL] : nil;
}

- (NSArray *)favoriteColors {
    return [NSColor favoriteColors];
}

- (void)setFavoriteColors:(NSArray *)array {
    NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:SKUnarchiveColorArrayTransformerName];
    [[NSUserDefaults standardUserDefaults] setObject:[transformer reverseTransformedValue:array] forKey:SKSwatchColorsKey];
}

@end
