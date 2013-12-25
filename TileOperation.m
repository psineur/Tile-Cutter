//
//  TileOperation.m
//  Tile Cutter
//
//  Created by jeff on 10/30/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "TileOperation.h"
#import "NSImage-Tile.h"
#import "NSInvocation-MCUtilities.h"
#import "NSBitmapImageRep-Tile.h"

@interface NSBitmapImageRep (Extension)

- (BOOL) isAbsoluteTransparent;

@end

@implementation NSBitmapImageRep (Extension)

- (BOOL) isAbsoluteTransparent
{	
	NSSize s = [self size];
	
	for (int i = 0; i < s.width; ++i)
	{
		for (int j = 0; j < s.height; ++j)
		{
			NSColor *col = [self colorAtX:i y:j];
			
			if ([col alphaComponent] != 0.0f)
				return NO;
		}
	}
	
	return YES;
}

@end


@implementation TileOperation
@synthesize delegate, imageRep, row, baseFilename, tileHeight, tileWidth, outputFormat;
@synthesize tilesInfo;
@synthesize skipTransparentTiles;
@synthesize outputSuffix;
@synthesize rigidTiles, POTTiles;
#pragma mark -
- (void)informDelegateOfError:(NSString *)message
{
    
    if ([delegate respondsToSelector:@selector(operation:didFailWithMessage:)])
    {
        NSInvocation *invocation = [NSInvocation invocationWithTarget:delegate 
                                                             selector:@selector(operation:didFailWithMessage:) 
                                                      retainArguments:YES, self, message];
        [invocation invokeOnMainThreadWaitUntilDone:YES];
    }
}
- (void)main 
{
    @try 
    {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        NSString *extension = nil;
        NSBitmapImageFileType fileType;

        switch (outputFormat)
        {
            case TileCutterOutputPrefsJPEG:
                extension = @"jpg";
                fileType = NSJPEGFileType;
                break;
            case TileCutterOutputPrefsGIF:
                extension = @"gif";
                fileType = NSGIFFileType;
                break;
            case TileCutterOutputPrefsTIFF:
                extension = @"tiff";
                fileType = NSTIFFFileType;
                break;
            case TileCutterOutputPrefsBMP:
                extension = @"bmp";
                fileType = NSBMPFileType;
                break;
            case TileCutterOutputPrefsPNG:
                extension = @"png";
                fileType = NSPNGFileType;
                break;
            case TileCutterOutputPrefsJPEG2000:
                extension = @"jpx";
                fileType = NSJPEG2000FileType;
                break;
            default:
                NSLog(@"Bad preference detected, assuming JPEG");
                extension = @"jpg";
                fileType = NSJPEGFileType;
                break;
        }		
        
		// Get Tile Count for this Operation
		int tileColCount = [imageRep columnsWithTileWidth:tileWidth];
		
		// Create tilesInfo Array for holding this Operation Tiles Info
		self.tilesInfo = [NSMutableArray arrayWithCapacity: tileColCount];
		
		// Safe Empty Suffix
		if (!self.outputSuffix)
			self.outputSuffix = @"";
		
        for (int column = 0; column < tileColCount; column++)
        {
            NSImage *subImage = [imageRep subImageWithTileWidth:(float)tileWidth
													 tileHeight:(float)tileHeight 
														 column:column 
															row:row 
													  rigidSize:self.rigidTiles];
            
            if (subImage == nil)
            {
                [self informDelegateOfError:NSLocalizedString(@"Error creating tile", @"")];
                goto finish;
            }
            
            NSArray * representations = [subImage representations];			
            NSBitmapImageRep *subBitmapRep = nil;
			if ( [representations count] )
				subBitmapRep = [representations objectAtIndex: 0];
			
            if ([self isCancelled])
                goto finish;
            
			
			
			// Analyze do we need this tile saved
			BOOL curTileNeeded = ! (self.skipTransparentTiles && [subBitmapRep isAbsoluteTransparent]);
			
			// save if yes
			if ( curTileNeeded )
			{			
				NSData *bitmapData = [NSBitmapImageRep representationOfImageRepsInArray:representations 
																			  usingType:fileType properties:nil];
				
				
				if (bitmapData == nil)
				{
					[self informDelegateOfError:NSLocalizedString(@"Error retrieving bitmap data from result", @"")];
					goto finish;
				}
				
				
				if ([self isCancelled])
					goto finish;
				//modify by jk 原配置
//				NSString *outPath = [NSString stringWithFormat:@"%@_%d_%d%@.%@", baseFilename, row, column, self.outputSuffix, extension];
                //新配置 tile%d
                NSString *outPath = [NSString stringWithFormat:@"%@%d.%@", baseFilename, (int)row  *32+ column, extension];
				[bitmapData writeToFile:outPath atomically:YES];
				
				// Add created Tile Info to tilesInfo array
				NSRect tileRect = NSRectFromCGRect( CGRectMake(column * tileWidth, 
															   row * tileHeight, 
															   [subImage size].width, 
															   [subImage size].height));
				NSDictionary *tileInfoDict = [NSDictionary dictionaryWithObjectsAndKeys:
											  [outPath lastPathComponent], @"Name",
											  NSStringFromRect(tileRect), @"Rect",
											  nil];
				[(NSMutableArray *)self.tilesInfo addObject: tileInfoDict ];
			}
            
            if ([delegate respondsToSelector:@selector(operationDidFinishTile:)])
                [delegate operationDidFinishTile: self];
            
        }
        
        if ([delegate respondsToSelector:@selector(operationDidFinishSuccessfully:)])
            [delegate operationDidFinishSuccessfully: self ];
		
    finish:
        [pool drain];
    }
    @catch (NSException * e) 
    {
        NSLog(@"Exception: %@", e);
    }
}

- (void)dealloc
{
	self.outputSuffix = nil;
    delegate = nil;
    [imageRep release], imageRep = nil;
    [baseFilename release], baseFilename = nil;
	self.tilesInfo = nil;
    
    [super dealloc];
}
@end
