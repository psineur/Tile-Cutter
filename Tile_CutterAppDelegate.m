//
//  Tile_CutterAppDelegate.m
//  Tile Cutter
//
//  Created by jeff on 10/7/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#include <dispatch/dispatch.h>
#import "Tile_CutterAppDelegate.h"
#import "TileCutterView.h"
#import "NSImage-Tile.h"
#import "NSUserDefaults-MCColor.h"
#import "TileOperation.h"



@interface Tile_CutterAppDelegate()

- (void)delayAlert:(NSString *)message;

@end


@implementation Tile_CutterAppDelegate

@synthesize window, tileCutterView, widthTextField, heightTextField, rowBar, columnBar, progressWindow, progressLabel, baseFilename,tileCore;

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{

    tileCutterView.filename = filename;
    NSImage *theImage = [[NSImage alloc] initWithContentsOfFile:filename];
    if (theImage == nil)
        return NO;
    
    tileCutterView.image = theImage;
    [theImage release];
    [tileCutterView setNeedsDisplay:YES];
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification 
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSColor *guideColor = [defaults colorForKey:@"guideColor"];
    if (guideColor == nil)
    {
        [defaults setColor:[NSColor redColor] forKey:@"guideColor"];
        [defaults setInteger:200 forKey:@"widthField"];
        [defaults setBool:YES forKey:@"showGuides"];
        [defaults setInteger:200 forKey:@"heightField"];
    }
    
	self.tileCore = [TileCutterCore new];
	self.tileCore.operationsDelegate = self;
}

- (void)saveThread
{
    NSLog(@"Save thread started");
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; 
    
	
	// Setup Tile Core
	self.tileCore.inputFilename = tileCutterView.filename;
	self.tileCore.outputFormat = (TileCutterOutputPrefs)[[NSUserDefaults standardUserDefaults] integerForKey:@"OutputFormat"];
	self.tileCore.outputBaseFilename = baseFilename;
	if (![tileCutterView.skipCheckbox intValue]) 
		self.tileCore.keepAllTiles = YES;
	else 
		self.tileCore.keepAllTiles = NO;
	
	// Start Tiling
	[self.tileCore startSavingTiles];    
    
    [pool drain];
}

- (IBAction)saveButtonPressed:(id)sender
{
    NSSavePanel *sp = [NSSavePanel savePanel];
    //[sp setRequiredFileType:@"jpg"];
    [sp setAllowedFileTypes:[NSArray arrayWithObject:@"jpg"]];
    

    [sp beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if(result == NSFileHandlingPanelOKButton){
            self.baseFilename = [[sp filename] stringByDeletingPathExtension];
            self.tileCore.tileHeight = [heightTextField intValue];
            self.tileCore.tileWidth = [widthTextField intValue];
            
            [self performSelector:@selector(delayPresentSheet) withObject:nil afterDelay:0.1];
        }
    }];
}

- (void)delayPresentSheet
{
    [progressLabel setStringValue:@"Analyzing image for tile cutting…"];
    [rowBar setIndeterminate:YES];
    [columnBar setIndeterminate:YES];
    [rowBar startAnimation:self];
    [columnBar startAnimation:self];
    
    [NSApp beginSheet: progressWindow
       modalForWindow: window
        modalDelegate: self
       didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
          contextInfo: nil];
    
    //[queue setSuspended:YES];
    [self performSelectorInBackground:@selector(saveThread) withObject:nil];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
    
}
- (IBAction)openSelected:(id)sender
{
    NSOpenPanel *op = [NSOpenPanel openPanel];
    [op setAllowedFileTypes:[NSImage imageFileTypes]];
    
    [op beginSheetModalForWindow:window completionHandler:^(NSInteger returnCode){
        if (returnCode == NSOKButton)
        {
            NSString *filename = [op filename];
            [self application:NSApp openFile:filename];
        }
    }];
    
}
- (void)dealloc
{
	self.tileCore = nil;
    [columnBar release], columnBar = nil;
    [rowBar release], rowBar = nil;
    [progressWindow release], progressWindow = nil;
    [progressLabel release], progressLabel = nil;
    [baseFilename release], baseFilename = nil;
    [super dealloc];
}
#pragma mark -
- (void)updateProgress
{
    if (self.tileCore.progressRow >= self.tileCore.tileRowCount)
	{
        [NSApp endSheet:progressWindow];
	}
    
//    [rowBar setDoubleValue:(double)progressRow];
//    [columnBar setDoubleValue:(double)progressCol];
    [progressLabel setStringValue:[NSString stringWithFormat:@"Processing row %d, column %d", self.tileCore.progressRow, self.tileCore.progressCol]]; 
}
- (void)operationDidFinishTile:(TileOperation *)op
{
    if (self.tileCore.progressRow >= self.tileCore.tileRowCount)
        [NSApp endSheet:progressWindow];
    
//    [rowBar setDoubleValue:(double)progressRow];
//    [columnBar setDoubleValue:(double)progressCol];
//    [progressLabel setStringValue:[NSString stringWithFormat:@"Processing row %d, column %d", progressRow, progressCol]];
    
    [self performSelectorOnMainThread:@selector(updateProgress) withObject:nil waitUntilDone:NO];
}

- (void)operationDidFinishSuccessfully:(TileOperation *)op
{
	
}

- (void)delayAlert:(NSString *)message
{
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"Crud"];
    [alert setMessageText:@"There was an error tiling this image."];
    [alert setInformativeText:message];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

- (void)operation:(TileOperation *)op didFailWithMessage:(NSString *)message
{
    [NSApp endSheet:progressWindow];
    [self performSelector:@selector(delayAlert:) withObject:nil afterDelay:0.5];
}
@end
