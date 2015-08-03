//
//  AppDelegate.h
//  SpeakOSC
//
//  Created by David Lublin on 8/3/15.
//  Copyright (c) 2015 VIDVOX. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>
#import <VVOSC/VVOSC.h>


@interface AppDelegate : NSObject <NSApplicationDelegate, NSSpeechRecognizerDelegate>	{

	//	Speech backend
	NSSpeechRecognizer				*speechRecognizer;

	//	Speech GUI
	IBOutlet NSTableView			*commandsTableView;
	IBOutlet NSTableColumn			*commandWordColumn;
	IBOutlet NSTextField			*resultField;


	//	OSC backend
	OSCManager						*oscManager;
	OSCOutPort						*oscOutPort;
	
	//	OSC preferences GUIs
	IBOutlet NSTextField			*ipField;
	IBOutlet NSTextField			*portField;
	IBOutlet NSTextField			*oscAddressField;
	IBOutlet NSPopUpButton			*outputDestinationButton;
	NSString						*desiredOSCDestination;
	
	
	//	File loading / saving
	NSURL							*documentAddress;
	
	//	Prevent app nap with this
	id								appNapThing;

}

//	File Management Stuff
- (IBAction)newCommandsDocumentAction:(id)sender;
- (IBAction)openCommandsDocumentAction:(id)sender;
- (IBAction)saveCommandsDocumentAction:(id)sender;
- (IBAction)saveAsCommandsDocumentAction:(id)sender;

- (void)newDocument;
- (void)openCommandsDocumentAtURL:(NSURL *)openMe;
- (void)saveCommandsDocumentAtURL:(NSURL *)writeMe;


//	Preferences Stuff
- (void)_loadPreferences;


//	Speech UI methods
- (IBAction)addCommandButtonUsed:(id)sender;
- (IBAction)removeCommandButtonUsed:(id)sender;

//	Speech methods
- (void)_loadDefaultCommands;
- (void)_startListening;
- (void)_stopListening;

//	OSC UI Methods
- (void)oscOutputsChangedNotification:(NSNotification *)note;
- (IBAction)outputDestinationButtonUsed:(id)sender;
- (IBAction)setupFieldUsed:(id)sender;

@property (readwrite, assign) IBOutlet NSWindow *window;

@end

