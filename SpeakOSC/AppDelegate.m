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
	//	Set up the speech stuff and start the timer
	speechRecognizer = [[NSSpeechRecognizer alloc] init];
	[speechRecognizer setDelegate: self];
	[speechRecognizer setListensInForegroundOnly: NO];
	speechCommands = [[MutLockArray arrayWithCapacity:0] retain];
	[self _loadDefaultCommands];
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSLog(@"%s",__func__);
	documentAddress = nil;
	_startedDictation = NO;
	
	//	remove the orderFrontCharacterPalette thing from the edit menu!
    NSMenu		*edit = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle: @"Edit"] submenu];
	if ([[edit itemAtIndex: [edit numberOfItems] - 1] action] == NSSelectorFromString(@"orderFrontCharacterPalette:"))
		[edit removeItemAtIndex: [edit numberOfItems] - 1];

	// Insert code here to initialize your application
	//	tell the OS not to app nap us!
	NSActivityOptions options = NSActivityAutomaticTerminationDisabled | NSActivityBackground;
	appNapThing = [[[NSProcessInfo processInfo] beginActivityWithOptions: options reason:@"REALTIME VIDEO ANALYSIS"] retain];

	//	Set up the OSC stuff
	oscManager = [[OSCManager alloc] initWithInPortClass:[OSCInPort class] outPortClass:nil];
	//	by default, the osc manager's delegate will be told when osc messages are received
	[oscManager setDelegate:self];

	oscOutPort = [oscManager createNewOutputToAddress:@"127.0.0.1" atPort:1235 withLabel:@"Manual Output"];

	//	Register to receive notifications that the list of osc outputs has changed
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(oscOutputsChangedNotification:) name:OSCOutPortsChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(oscOutputsChangedNotification:) name:OSCInPortsChangedNotification object:nil];
	[self oscOutputsChangedNotification:nil];

	//	Load the preferences
	[self _loadPreferences];
	
	//	The first time that the timer fires while the app is in the front it'll start dictation
	dictationTimer = [[NSTimer scheduledTimerWithTimeInterval:1.25
                            target:self
                          selector:@selector(_updateDictationOutput)
                          userInfo:nil
                           repeats:YES] retain];

    
}
- (void)applicationWillBecomeActive:(NSNotification *)aNotification	{
	NSLog(@"%s",__func__);
	//	comment this out if you'd prefer to not auto-select the text field when the app becomes active
	[dictationField performSelectorOnMainThread:@selector(becomeFirstResponder) withObject:nil waitUntilDone:NO];
}
- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[self _stopListening];
	[self _storePreferences];
	VVRELEASE(speechRecognizer);
	VVRELEASE(documentAddress);
	[[NSProcessInfo processInfo] endActivity: appNapThing];
	
	/*
	NSMenu		*edit = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle: @"Edit"] submenu];
	if ([[edit itemAtIndex: [edit numberOfItems] - 1] action] == NSSelectorFromString(@"stopDictation:"))	{
		NSMenuItem		*dictationItem = [edit itemAtIndex: [edit numberOfItems] - 1];
		NSLog(@"\t\tgot %@", dictationItem);
		dictationTarget = [dictationItem target];
		dictationAction = [dictationItem action];
		[dictationTarget performSelectorOnMainThread: dictationAction withObject: dictationItem waitUntilDone: YES];
	
		NSLog(@"\t\tdictationAction %@ for target %@", NSStringFromSelector(dictationAction), dictationTarget);
		//[edit removeItemAtIndex: [edit numberOfItems] - 1];
	}
	*/
	[[NSApplication sharedApplication] stopDictation: nil];
	_startedDictation = NO;
	
	if (dictationTimer)	{
		[dictationTimer invalidate];
		[dictationTimer release];
		dictationTimer = nil;
	}
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
	NSArray				*typesArray = [NSArray arrayWithObject:@"sosc"];
	[panel setAllowedFileTypes:typesArray];

	// This method displays the panel and returns immediately.
	// The completion handler is called when the user selects an
	// item or cancels the panel.
	[panel beginWithCompletionHandler:^(NSInteger result){
		if (result == NSFileHandlingPanelOKButton) {
			NSURL		*theDoc = [[panel URLs] objectAtIndex:0];
			// Open  the document.
			[self openCommandsDocumentAtURL:theDoc];
		}

	}];
}
- (BOOL)application:(NSApplication *)theApplication	openFile:(NSString *)fileName	{
	NSLog(@"%s",__func__);
	NSURL		*theDoc = [NSURL fileURLWithPath:fileName];
	if (theDoc)	{
		[self openCommandsDocumentAtURL:theDoc];
		return YES;
	}
	return NO;
}
- (IBAction)saveCommandsDocumentAction:(id)sender	{
	if (documentAddress != nil)	{
		NSURL		*reloadURL = [[documentAddress copy] autorelease];
		[self saveCommandsDocumentAtURL:reloadURL];
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
	NSArray				*typesArray = [NSArray arrayWithObject:@"sosc"];
	[savePanel setAllowedFileTypes:typesArray];
	
	[savePanel beginWithCompletionHandler:^(NSInteger result){
		if (result == NSFileHandlingPanelOKButton) {
			// Save  the document.
			NSURL		*theURL = [savePanel URL];
			[self saveCommandsDocumentAtURL:theURL];
	  }
	}];
}
- (void)newDocument	{
	NSLog(@"%s",__func__);
	[self _stopListening];
	[speechCommands lockRemoveAllObjects];
	[speechRecognizer setCommands:[NSArray array]];
	[self _loadDefaultCommands];
	VVRELEASE(documentAddress);
	[commandsTableView reloadData];
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
	[speechCommands lockRemoveAllObjects];
	NSArray				*commandsArray = [commandsDocument objectForKey:@"commands"];
	if (commandsArray != nil)	{
		for (NSDictionary *cd in commandsArray)	{
			NSString			*tp = [cd objectForKey:@"targetPath"];
			NSString			*cp = [cd objectForKey:@"commandPhrase"];
			NSNumber			*val = [cd objectForKey:@"value"];
			SOSpeechCommand		*sc = [SOSpeechCommand createSpeechCommandWithTargetPath:tp
																		forCommandPhrase:cp
																		andValue:[val doubleValue]];
			if (sc)	{
				[speechCommands lockAddObject:sc];
			}
		}
	}
	
	[self _updateSpeechRecognizerCommands];
	[commandsTableView reloadData];
}
- (void)saveCommandsDocumentAtURL:(NSURL *)writeMe	{
	NSLog(@"%s",__func__);
	VVRELEASE(documentAddress);
	if (writeMe == nil)
		return;
	documentAddress = [writeMe copy];
	NSMutableDictionary		*writeDict = [NSMutableDictionary dictionaryWithCapacity:0];
	NSArray					*commandsArray = [NSMutableArray arrayWithCapacity:0];
	
	[speechCommands rdlock];
	
		for (SOSpeechCommand *sc in [speechCommands objectEnumerator])	{
			NSString				*targetPath = [sc targetPath];
			NSString				*commandPhrase = [sc commandPhrase];
			double					value = [sc value];
			NSMutableDictionary 	*tmpDict = [NSMutableDictionary dictionaryWithCapacity:0];
			
			if (targetPath)
				[tmpDict setObject:targetPath forKey:@"targetPath"];
			if (commandPhrase)
				[tmpDict setObject:commandPhrase forKey:@"commandPhrase"];
			[tmpDict setObject:[NSNumber numberWithDouble:value] forKey:@"value"];
			
			[commandsArray addObject:tmpDict];
		}
	
	[speechCommands unlock];	
	
	if (commandsArray != nil)	{
		[writeDict setObject: commandsArray forKey:@"commands"];
	}
	[writeDict writeToURL: writeMe atomically: YES];
}


/*===================================================================================*/
#pragma mark --------------------- Table View Methods
/*------------------------------------*/


- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView	{
	return [speechCommands lockCount];
}
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex	{
	SOSpeechCommand		*sc = [speechCommands lockObjectAtIndex:rowIndex];
	if (aTableColumn == commandWordColumn)	{
		return [sc commandPhrase];
	}
	else if (aTableColumn == targetPathColumn)	{
		return [sc targetPath];
	}
	else if (aTableColumn == valueColumn)	{
		return [NSNumber numberWithDouble:[sc value]];
	}
	return nil;
}
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex	{
	SOSpeechCommand		*sc = [speechCommands lockObjectAtIndex:rowIndex];
	if (aTableColumn == commandWordColumn)	{
		[sc setCommandPhrase:anObject];
		if ([[sc targetPath] isEqualToString:@"Something"])	{
			[sc setTargetPath:anObject];
		}
		[self _updateSpeechRecognizerCommands];
		[commandsTableView reloadData];
	}
	else if (aTableColumn == targetPathColumn)	{
		[sc setTargetPath:anObject];
	}
	else if (aTableColumn == valueColumn)	{
		[sc setValue:[anObject doubleValue]];
	}
	//[dictationField performSelectorOnMainThread:@selector(becomeFirstResponder) withObject:nil waitUntilDone:NO];
}

/*===================================================================================*/
#pragma mark --------------------- Speech Listening
/*------------------------------------*/


- (IBAction)addCommandButtonUsed:(id)sender	{
	NSString			*newCommand = @"Something";
	
	SOSpeechCommand		*newSpeechCommand = [SOSpeechCommand createSpeechCommandWithTargetPath:newCommand
																				forCommandPhrase:newCommand
																				andValue:1.0];
	if (newSpeechCommand)	{
		[speechCommands lockAddObject:newSpeechCommand];
	}
	
	[self _updateSpeechRecognizerCommands];
	[commandsTableView reloadData];
	[dictationField performSelectorOnMainThread:@selector(becomeFirstResponder) withObject:nil waitUntilDone:NO];
}
- (IBAction)removeCommandButtonUsed:(id)sender	{
	NSIndexSet			*selectedIndexes = [commandsTableView selectedRowIndexes];

	[speechCommands lockRemoveObjectsAtIndexes:selectedIndexes];
	[self _updateSpeechRecognizerCommands];
	[commandsTableView deselectAll: nil];
	[commandsTableView reloadData];
	[dictationField performSelectorOnMainThread:@selector(becomeFirstResponder) withObject:nil waitUntilDone:NO];
}
- (IBAction)dictationFieldUpdated:(id)sender	{
	//NSLog(@"%s",__func__);
	[self _updateDictationOutput];
}
- (void)_updateSpeechRecognizerCommands	{
	NSMutableArray		*newCommands = [NSMutableArray arrayWithCapacity:0];
	
	[self _stopListening];
	
	[speechCommands rdlock];
	
		for (SOSpeechCommand *ptr in [speechCommands objectEnumerator])	{
			NSString		*phrase = [ptr commandPhrase];
			if (phrase)	{
				[newCommands addObject:phrase];
			}
		}
	
	[speechCommands unlock];
	
	if ([newCommands count] > 0)	{
		[speechRecognizer setCommands:newCommands];
		[self _startListening];
	}
}
- (void)_loadDefaultCommands	{
	NSLog(@"%s",__func__);
	/*
	NSArray			*strings = [NSArray arrayWithObjects: 	@"Love",
															@"Hate",
															@"Up",
															@"Down",
															@"Left",
															@"Right",
															nil];
	*/
	NSArray			*strings = [NSArray arrayWithObject:@"Blathering blatherskite"];
	NSArray			*newCommands = [SOSpeechCommand speechCommandsFromStringsArray:strings];
	
	if (newCommands)	{
		[speechCommands lockReplaceWithObjectsFromArray:newCommands];
		[self _updateSpeechRecognizerCommands];
		[commandsTableView reloadData];
	}
}
- (void)_startListening	{
	NSLog(@"%s",__func__);
	[speechRecognizer startListening];
}
- (void)_stopListening	{
	NSLog(@"%s",__func__);
	[speechRecognizer stopListening];
}

- (void)_updateDictationOutput	{
	//NSLog(@"%s",__func__);
	//	do we need to start speech dictation?
	if (([[NSApplication sharedApplication] isActive] == YES)&&(_startedDictation==NO))	{
		NSMenu		*edit = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle: @"Edit"] submenu];
		if ([[edit itemAtIndex: [edit numberOfItems] - 1] action] == NSSelectorFromString(@"startDictation:"))	{
			_startedDictation = YES;
			NSMenuItem		*dictationItem = [edit itemAtIndex: [edit numberOfItems] - 1];
			//NSLog(@"\t\tgot %@", dictationItem);
			dictationTarget = [dictationItem target];
			dictationAction = [dictationItem action];
			[dictationField becomeFirstResponder];
			[dictationTarget performSelectorOnMainThread:dictationAction withObject: dictationItem waitUntilDone: YES];
			//[[NSApplication sharedApplication] startDictation: nil];
			NSLog(@"\t\tdictationAction %@ for target %@", NSStringFromSelector(dictationAction), dictationTarget);
			//[edit removeItemAtIndex: [edit numberOfItems] - 1];
		}
	}
	
	NSString			*newString = [dictationField stringValue];
		
	if ((newString != nil) && ([newString length]))	{
		OSCPacket			*packet = nil;	
		OSCMessage			*msg1 = nil;
		NSString			*tmpPath = [oscAddressField stringValue];
	
		msg1 = [OSCMessage createWithAddress:[NSString stringWithFormat:@"%@/dictation",tmpPath]];
		[msg1 addString:newString];
	
		packet = [OSCPacket createWithContent:msg1];
		[oscOutPort sendThisPacket:packet];	
	
		[dictationField setStringValue:@""];
		[resultField setStringValue:newString];
		NSLog(@"\t\tsent: %@",newString);
	}
	
	//[dictationField becomeFirstResponder];
}
- (void)speechRecognizer:(NSSpeechRecognizer *)sender didRecognizeCommand:(id)command	{
	NSLog(@"%s - %@",__func__, command);
	OSCPacket			*packet = nil;	
	OSCMessage			*msg1 = nil;
	OSCMessage			*msg2 = nil;
	NSString			*tmpPath = nil;
	NSString			*cmdPath = nil;
	SOSpeechCommand		*sc = [self _speechCommandForCommandWord:command];
	double				val = 1.0;
	
	if (sc != nil)	{
		cmdPath = [sc targetPath];
		val = [sc value];
	}
	
	if (tmpPath == nil)
		tmpPath = [oscAddressField stringValue];
	
	if (tmpPath == nil)
		tmpPath = @"/speak";
	
	if (cmdPath == nil)
		cmdPath = command;
	
	msg1 = [OSCMessage createWithAddress:[NSString stringWithFormat:@"%@/command",tmpPath]];
	[msg1 addString:command];
	
	msg2 = [OSCMessage createWithAddress:[NSString stringWithFormat:@"%@/command/%@",tmpPath,cmdPath]];
	[msg2 addFloat:val];
	
	packet = [OSCPacket createWithContent:msg2];
	[oscOutPort sendThisPacket:packet];
	packet = [OSCPacket createWithContent:msg1];
	[oscOutPort sendThisPacket:packet];
	
	[resultField setStringValue: command];
}
- (SOSpeechCommand *) _speechCommandForCommandWord:(NSString *)command	{
	if (command == nil)
		return nil;
	SOSpeechCommand		*returnMe = nil;
	[speechCommands rdlock];
	
		for (SOSpeechCommand *sc in [speechCommands objectEnumerator])	{
			if ([[sc commandPhrase] isEqualToString:command])	{
				returnMe = sc;
				break;
			}
		}
	
	[speechCommands unlock];
	
	return returnMe;
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
