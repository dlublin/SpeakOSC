//
//  AppDelegate.m
//  SpeakOSC
//
//  Created by David Lublin on 8/3/15.
//  Copyright (c) 2015 VIDVOX. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()


@end

@implementation AppDelegate

- (void)awakeFromNib	{
	NSLog(@"%s",__func__);
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSLog(@"%s",__func__);
	documentAddress = nil;
	
	// Insert code here to initialize your application
    //	tell the OS not to app nap us!
	NSActivityOptions options = NSActivityAutomaticTerminationDisabled | NSActivityBackground;
	appNapThing = [[[NSProcessInfo processInfo] beginActivityWithOptions: options reason:@"REALTIME VIDEO ANALYSIS"] retain];
	
	oscManager = [[OSCManager alloc] initWithInPortClass:[OSCInPort class] outPortClass:nil];
	//	by default, the osc manager's delegate will be told when osc messages are received
	[oscManager setDelegate:self];
	
    oscOutPort = [oscManager createNewOutputToAddress:@"127.0.0.1" atPort:1235 withLabel:@"Manual Output"];
	
	//	register to receive notifications that the list of osc outputs has changed
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(oscOutputsChangedNotification:) name:OSCOutPortsChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(oscOutputsChangedNotification:) name:OSCInPortsChangedNotification object:nil];
    [self oscOutputsChangedNotification:nil];
    
    [self _loadPreferences];
    
    speechRecognizer = [[NSSpeechRecognizer alloc] init];
    [speechRecognizer setDelegate: self];
    [speechRecognizer setListensInForegroundOnly: NO];
    [self _loadDefaultCommands];
    [self _startListening];
}
- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[self _stopListening];
	[self _storePreferences];
	VVRELEASE(speechRecognizer);
	VVRELEASE(documentAddress);
	[[NSProcessInfo processInfo] endActivity: appNapThing];
}
- (void)_loadPreferences	{
	NSUserDefaults	*def = [NSUserDefaults standardUserDefaults];
	NSString		*tmpString = nil;
	NSInteger		tmpInt = 0;

	//	OSC destination or manual mode?
	tmpString = [def stringForKey:@"SpeakOSCOutputDestination"];
	if (tmpString != nil)	{
		[outputDestinationButton selectItemWithTitle:tmpString];
		VVRELEASE(desiredOSCDestination);
		desiredOSCDestination = [tmpString copy];
		[self outputDestinationButtonUsed: outputDestinationButton];
	}
	else	{
		tmpString = [def stringForKey:@"SpeakOSCOutputIPAddress"];
		if (tmpString != nil)	{
			[ipField setStringValue: tmpString];
		}
		tmpInt = [def integerForKey: @"SpeakOSCOutputPort"];
		[portField setStringValue:[NSString stringWithFormat:@"%ld",tmpInt]];
		[self setupFieldUsed:nil];
	}
	
	tmpString = [def stringForKey:@"SpeakOSCBaseString"];
	if (tmpString != nil)	{
		[oscAddressField setStringValue: tmpString];
	}

}

- (void)_storePreferences	{
	NSLog(@"%s",__func__);
	NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
	
	//	if it is manual output, store the IP address and port
	NSString *outputDestination = [outputDestinationButton titleOfSelectedItem];
	if ((outputDestination == nil) || ([outputDestination isEqualToString:@"Manual Output"]))	{
		[def setObject:[ipField stringValue] forKey:@"SpeakOSCOutputIPAddress"];
		[def setInteger:[portField intValue] forKey:@"SpeakOSCOutputPort"];
		[def removeObjectForKey:@"SpeakOSCOutputDestination"];
	}
	//	if the outputDestinationButton is not manual output, store it as a string
	else	{
		[def setObject:outputDestination forKey:@"SpeakOSCOutputDestination"];
		[def removeObjectForKey:@"SpeakOSCOutputIPAddress"];
		[def removeObjectForKey:@"SpeakOSCOutputPort"];
	}
	
	//	store the oscAddressField string
	[def setObject: [oscAddressField stringValue] forKey:@"SpeakOSCBaseString"];
	
	if ([def synchronize])	{
		NSLog(@"\t\tprefs stored");
	}
}

/*===================================================================================*/
#pragma mark --------------------- Document Saving Methods
/*------------------------------------*/


- (IBAction)newCommandsDocumentAction:(id)sender	{
	[self newDocument];
}
- (IBAction)openCommandsDocumentAction:(id)sender	{
	NSOpenPanel			*panel = [NSOpenPanel openPanel];

	// This method displays the panel and returns immediately.
	// The completion handler is called when the user selects an
	// item or cancels the panel.
	[panel beginWithCompletionHandler:^(NSInteger result){
		if (result == NSFileHandlingPanelOKButton) {
			NSURL		*theDoc = [[panel URLs] objectAtIndex:0];
			// Open  the document.
			[self openCommandsDocumentAtURL: theDoc];
		}

	}];
}
- (IBAction)saveCommandsDocumentAction:(id)sender	{
	if (documentAddress != nil)	{
		NSURL		*reloadURL = [[documentAddress copy] autorelease];
		[self saveCommandsDocumentAtURL: reloadURL];
		return;
	}
	NSSavePanel			*savePanel = [NSSavePanel savePanel];
	
	[savePanel beginWithCompletionHandler:^(NSInteger result){
		if (result == NSFileHandlingPanelOKButton) {
			// Save  the document.
			NSURL		*theURL = [savePanel URL];
			[self saveCommandsDocumentAtURL: theURL];
	  }
	}];
}
- (IBAction)saveAsCommandsDocumentAction:(id)sender	{
	NSSavePanel			*savePanel = [NSSavePanel savePanel];
	
	[savePanel beginWithCompletionHandler:^(NSInteger result){
		if (result == NSFileHandlingPanelOKButton) {
			// Save  the document.
			NSURL		*theURL = [savePanel URL];
			[self saveCommandsDocumentAtURL: theURL];
	  }
	}];
}
- (void)newDocument	{
	NSLog(@"%s",__func__);
	[self _stopListening];
	[speechRecognizer setCommands: [NSArray array]];
	[self _startListening];
	[commandsTableView reloadData];
	[self addCommandButtonUsed: nil];
	VVRELEASE(documentAddress);
}
- (void)openCommandsDocumentAtURL:(NSURL *)openMe	{
	NSLog(@"%s",__func__);
	VVRELEASE(documentAddress);
	if (openMe == nil)
		return;
	documentAddress = [openMe copy];
	NSDictionary		*commandsDocument = [NSDictionary dictionaryWithContentsOfURL: openMe];
	if (commandsDocument == nil)
		return;
	[self _stopListening];
	NSArray				*commandsArray = [commandsDocument objectForKey:@"commands"];
	if (commandsArray != nil)	{
		[speechRecognizer setCommands: commandsArray];
	}
	[commandsTableView reloadData];
	[self _startListening];
}
- (void)saveCommandsDocumentAtURL:(NSURL *)writeMe	{
	NSLog(@"%s",__func__);
	VVRELEASE(documentAddress);
	if (writeMe == nil)
		return;
	documentAddress = [writeMe copy];
	NSMutableDictionary		*writeDict = [NSMutableDictionary dictionaryWithCapacity:0];
	NSArray					*commandsArray = [speechRecognizer commands];
	if (commandsArray != nil)	{
		[writeDict setObject: commandsArray forKey:@"commands"];
	}
	[writeDict writeToURL: writeMe atomically: YES];
}


/*===================================================================================*/
#pragma mark --------------------- Table View Methods
/*------------------------------------*/


- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView	{
	return [[speechRecognizer commands] count];
}
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex	{
	NSArray					*commandsArray = [speechRecognizer commands];
	return [commandsArray objectAtIndex:rowIndex];
}
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex	{
	if (aTableColumn == commandWordColumn)	{
		NSArray				*commandsArray = [speechRecognizer commands];
		NSMutableArray		*newCommandsArray = [NSMutableArray arrayWithArray: commandsArray];

		[newCommandsArray replaceObjectAtIndex:rowIndex withObject:anObject];
		[speechRecognizer setCommands: newCommandsArray];
		[commandsTableView reloadData];
	}
}

/*===================================================================================*/
#pragma mark --------------------- Speech Listening
/*------------------------------------*/


- (IBAction)addCommandButtonUsed:(id)sender	{
	NSMutableArray			*newCommandsArray = [NSMutableArray arrayWithArray: [speechRecognizer commands]];
	//NSString				*newCommand = [self newUniqueCommandForWord: @"Something"];
	NSString				*newCommand = @"Something";
	
	[newCommandsArray addObject: newCommand];
	
	[speechRecognizer setCommands: newCommandsArray];
	
	[commandsTableView reloadData];
}
- (IBAction)removeCommandButtonUsed:(id)sender	{
	NSArray				*commandsArray = [speechRecognizer commands];
	NSIndexSet			*selectedIndexes = [commandsTableView selectedRowIndexes];
	NSMutableArray		*newCommandsArray = [NSMutableArray arrayWithArray: commandsArray];

	[newCommandsArray removeObjectsAtIndexes:selectedIndexes];
	[speechRecognizer setCommands: newCommandsArray];
	[commandsTableView deselectAll: nil];
	[commandsTableView reloadData];
}
- (void)_loadDefaultCommands	{
	NSLog(@"%s",__func__);
	NSArray			*defaultCommands = [NSArray arrayWithObjects: 	@"Love",
																	@"Hate",
																	@"Up",
																	@"Down",
																	@"Left",
																	@"Right",
																	nil];
	[speechRecognizer setCommands: defaultCommands];
	
	[commandsTableView reloadData];
}
- (void)_startListening	{
	NSLog(@"%s",__func__);
	[speechRecognizer startListening];
}
- (void)_stopListening	{
	NSLog(@"%s",__func__);
	[speechRecognizer stopListening];
}
- (void)speechRecognizer:(NSSpeechRecognizer *)sender didRecognizeCommand:(id)command	{
	NSLog(@"%s - %@",__func__, command);
	OSCPacket			*packet = nil;	
	OSCMessage			*msg1 = nil;
	OSCMessage			*msg2 = nil;
	NSString			*tmpPath = [oscAddressField stringValue];
	
	if (tmpPath == nil)
		tmpPath = @"/command/";
	
	msg1 = [OSCMessage createWithAddress:tmpPath];
	[msg1 addString:command];
	
	msg2 = [OSCMessage createWithAddress:[NSString stringWithFormat:@"%@/%@",tmpPath,command]];
	[msg2 addFloat:1.0];
	
	packet = [OSCPacket createWithContent:msg2];
	[oscOutPort sendThisPacket:packet];
	packet = [OSCPacket createWithContent:msg1];
	[oscOutPort sendThisPacket:packet];
	
	[resultField setStringValue: command];
}


/*===================================================================================*/
#pragma mark --------------------- OSC Setup
/*------------------------------------*/


- (void) oscOutputsChangedNotification:(NSNotification *)note	{
	//NSLog(@"%s",__func__);
	NSArray			*portLabelArray = nil;
	
	//	remove the items in the pop-up button
	[outputDestinationButton removeAllItems];
	//	get an array of the out port labels
	portLabelArray = [oscManager outPortLabelArray];
	//	push the labels to the pop-up button of destinations
	[outputDestinationButton addItemsWithTitles:portLabelArray];
	
	if (desiredOSCDestination != nil)	{
		[outputDestinationButton selectItemWithTitle: desiredOSCDestination];
		VVRELEASE(desiredOSCDestination);
		[self outputDestinationButtonUsed: outputDestinationButton];
	}
}
- (IBAction) outputDestinationButtonUsed:(id)sender	{
	NSInteger		selectedIndex = [outputDestinationButton indexOfSelectedItem];
	OSCOutPort		*selectedPort = nil;
	//	figure out the index of the selected item
	if (selectedIndex == -1)
		return;
	//	find the output port corresponding to the index of the selected item
	selectedPort = [oscManager findOutputForIndex:(int)selectedIndex];
	if (selectedPort == nil)
		return;
	//	push the data of the selected output to the fields
	[ipField setStringValue:[selectedPort addressString]];
	[portField setStringValue:[NSString stringWithFormat:@"%d",[selectedPort port]]];
	//	bump the fields (which updates the oscOutPort, which is the only out port sending data)
	[self setupFieldUsed:nil];
}
- (IBAction) setupFieldUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	
	//	first take care of the port (there's only one) which is receiving data
	//	push the settings in the port field to the in port
	//[inPort setPort:[receivingPortField intValue]];
	//	push the actual port i'm receiving on to the text field (if anything went wrong when changing the port, it should revert to the last port #)
	//[receivingPortField setIntValue:[inPort port]];
	
	//	now take care of the ports which relate to sending data
	//	push the settings on the ui items to the oscOutPort, which is the only out port actually sending data
	[oscOutPort setAddressString:[ipField stringValue]];
	[oscOutPort setPort:[portField intValue]];
	//[portField setIntValue:[oscOutPort port]];
	//	since the port this app receives on may have changed, i have to adjust the out port for the "This app" output so it continues to point to the correct address
	id			anObj = [oscManager findOutputWithLabel:@"This app"];
	if (anObj != nil)	{
		//[(OSCOutPort *)anObj setPort:[receivingPortField intValue]];
	}
	
	//	select the "manual output" item in the pop-up button
	//[outputDestinationButton selectItemWithTitle:@"Manual Output"];
	
}

@end
