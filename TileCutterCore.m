//
//  TileCutterCore.m
//  Tile Cutter
//
//  Created by Stepan Generalov on 28.04.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "TileCutterCore.h"
#import "NSImage-Tile.h"

@implementation TileCutterCore

@synthesize keepAllTiles, tileWidth, tileHeight, inputFilename, 
			outputBaseFilename, outputSuffix, operationsDelegate, 
			queue, allTilesInfo, imageInfo, outputFormat;
@synthesize rigidTiles;
@synthesize contentScaleFactor;
@synthesize POTTiles;

#pragma mark Public Methods

- (id) init
{
	if ( (self == [super init]) )
	{
		self.queue = [[[NSOperationQueue alloc] init] autorelease];
		[self.queue setMaxConcurrentOperationCount:1];
		
		self.outputFormat = NSPNGFileType;
		self.outputSuffix = @"";
		self.keepAllTiles = NO;
		self.rigidTiles = NO;
	}
	
	return self;
}

- (void) dealloc
{
	self.queue = nil;
	self.allTilesInfo = nil;
	self.imageInfo = nil;	
	self.inputFilename = nil;
	self.outputBaseFilename = nil;
	self.outputSuffix = nil;
	
	[super dealloc];
}

- (void) startSavingTiles
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; 
    
    NSImage *image = [[[NSImage alloc] initWithContentsOfFile: self.inputFilename] autorelease];
        
    _progressCol = 0;
    _progressRow = 0;
    
    _tileRowCount = [image rowsWithTileHeight: self.tileHeight];
    _tileColCount = [image columnsWithTileWidth: self.tileWidth];
	
	NSSize outputImageSizeForPlist = [image size];
	outputImageSizeForPlist.width /= self.contentScaleFactor;
	outputImageSizeForPlist.height /= self.contentScaleFactor;
	self.imageInfo = [NSDictionary dictionaryWithObjectsAndKeys: 
					  [self.inputFilename lastPathComponent], @"Filename",
					  NSStringFromSize(outputImageSizeForPlist), @"Size", nil];
	
	self.allTilesInfo = [NSMutableArray arrayWithCapacity: _tileRowCount * _tileColCount];
    
	// One ImageRep for all TileOperation
	NSBitmapImageRep *imageRep = 
		[[[NSBitmapImageRep alloc] initWithCGImage:[image CGImageForProposedRect:NULL context:NULL hints:nil]] autorelease];
	
    for (int row = 0; row < _tileRowCount; row++)
    {
        TileOperation *op = [[TileOperation alloc] init];
        op.row = row;
        op.tileWidth = self.tileWidth;
        op.tileHeight = self.tileHeight;
        op.imageRep = imageRep;
        op.baseFilename = outputBaseFilename;
        op.delegate = self;
        op.outputFormat = self.outputFormat;
		op.outputSuffix = self.outputSuffix;
		op.skipTransparentTiles = (! self.keepAllTiles );
		op.rigidTiles = self.rigidTiles;
		op.POTTiles = self.POTTiles;
        [queue addOperation:op];
        [op release];
    }
    
    [pool drain];
}

- (void)operationDidFinishTile:(TileOperation *)op
{
	_progressCol++;
    if (_progressCol >= _tileColCount)
    {
        _progressCol = 0;
        _progressRow++;
    }
	
	if ([self.operationsDelegate respondsToSelector: _cmd])
		[self.operationsDelegate performSelectorOnMainThread: _cmd 
												  withObject: op 
											   waitUntilDone: NO];
}

- (void) saveImageInfoDictionary
{
	// Change coordinates & size of all tiles for contentScaleFactor
	if (self.contentScaleFactor != 1.0f)
	{
		// Create new array, that will replace old self.allTilesInfo
		NSMutableArray *newTilesInfoArray = [NSMutableArray arrayWithCapacity: [self.allTilesInfo count]];
		
		for (NSDictionary *tileDict in self.allTilesInfo)
		{
			// Get Tile Rect
			NSRect rect = NSRectFromString([tileDict objectForKey: @"Rect"]);
			
			// Divide it by contentScaleFactor
			rect.origin.x /= self.contentScaleFactor;
			rect.origin.y /= self.contentScaleFactor;
			rect.size.width /= self.contentScaleFactor;
			rect.size.height /= self.contentScaleFactor;
			
			// Create new tile info Dict with changed rect
			NSDictionary *newTileDict = [NSDictionary dictionaryWithObjectsAndKeys:
										  [tileDict objectForKey:@"Name"], @"Name",
										  NSStringFromRect(rect), @"Rect",
										  nil];
			
			// Add new tile info for new array
			[newTilesInfoArray addObject:newTileDict ];
			
		}
		
		// Replace Old Tiles with New
		self.allTilesInfo = newTilesInfoArray;
		
	}
	
	// Create Root Dictionary for a PLIST file
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  self.imageInfo, @"Source",
						  self.allTilesInfo, @"Tiles",
						  [NSNumber numberWithFloat:self.contentScaleFactor], @"ContentScaleFactor", nil];
	
	// Be safe with outputSuffix
	if (!self.outputSuffix)
		self.outputSuffix = @"";
	
	// Save Dict to File
	[dict writeToFile:[NSString stringWithFormat:@"%@%@.plist", self.outputBaseFilename, self.outputSuffix]  atomically:YES];
}

- (void)operationDidFinishSuccessfully:(TileOperation *)op
{
	[(NSMutableArray *)self.allTilesInfo addObjectsFromArray: op.tilesInfo];
	op.tilesInfo = nil;
	
	// All Tiles Finished?
	if (_progressRow >= _tileRowCount)
	{
		[self saveImageInfoDictionary];
	}
	
	if ([self.operationsDelegate respondsToSelector: _cmd])
		[self.operationsDelegate performSelectorOnMainThread: _cmd 
												  withObject: op 
											   waitUntilDone: NO];
}


- (void)operation:(TileOperation *)op didFailWithMessage:(NSString *)message
{
	if ([self.operationsDelegate respondsToSelector: _cmd])
		[self.operationsDelegate performSelectorOnMainThread: _cmd 
												  withObject: op 
											   waitUntilDone: NO];
}


@end
