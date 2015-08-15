//
//  SOSpeechCommand.m
//  SpeakOSC
//
//  Created by David Lublin on 8/4/15.
//  Copyright (c) 2015 VIDVOX. All rights reserved.
//

#import "SOSpeechCommand.h"

@implementation SOSpeechCommand

@synthesize commandPhrase, targetPath, value;

+ (NSArray *) speechCommandsFromStringsArray:(NSArray *)strings	{
	NSMutableArray		*returnMe = [NSMutableArray arrayWithCapacity: 0];
	
	if (strings != nil)	{
		for (NSString *c in strings)	{
			SOSpeechCommand		*newSpeechCommand = [SOSpeechCommand createSpeechCommandWithTargetPath:c
																						forCommandPhrase:c
																						andValue:1.0];
			if (newSpeechCommand)	{
				[returnMe addObject:newSpeechCommand];
			}
		}
	}
	
	return returnMe;
}
+ (id) createSpeechCommandWithTargetPath:(NSString *)p forCommandPhrase:(NSString *)c andValue:(double)v	{
	SOSpeechCommand	*returnMe = [[SOSpeechCommand alloc] initSpeechCommandWithTargetPath:p forCommandPhrase:c andValue:v];
	
	if (returnMe)
		[returnMe autorelease];
	
	return returnMe;
}
- (id) initSpeechCommandWithTargetPath:(NSString *)p forCommandPhrase:(NSString *)c andValue:(double)v	{
	if (c==nil)
		goto BAIL;
	
	if (self = [super init])	{
		[self setCommandPhrase:c];
		[self setTargetPath:p];
		[self setValue:v];
		return self;
	}
BAIL:
	if (self != nil)
		[self release];
	return nil;
}
- (void) dealloc	{
	VVRELEASE(commandPhrase);
	VVRELEASE(targetPath);
	[super dealloc];
}

@end
