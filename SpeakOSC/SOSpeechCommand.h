//
//  SOSpeechCommand.h
//  SpeakOSC
//
//  Created by David Lublin on 8/4/15.
//  Copyright (c) 2015 VIDVOX. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>


/*

	Right now this is just a dumb wrapper for some variables related to commands being sent

*/



@interface SOSpeechCommand : NSObject	{

	NSString		*commandPhrase;		//	the command being listened for
	
	NSString		*targetPath;		//	what OSC path should this send to
	double			value;				//	what OSC value should this send when triggered

}

//	returns a set of prepared speech commands for the given strings, assuming the target path is the same as the command
+ (NSArray *) speechCommandsFromStringsArray:(NSArray *)strings;

+ (id) createSpeechCommandWithTargetPath:(NSString *)p forCommandPhrase:(NSString *)c andValue:(double)v;
- (id) initSpeechCommandWithTargetPath:(NSString *)p forCommandPhrase:(NSString *)c andValue:(double)v;

@property(readwrite, copy) NSString *commandPhrase;
@property(readwrite, copy) NSString *targetPath;
@property(readwrite, assign) double value;

@end
