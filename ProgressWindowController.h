#import <Cocoa/Cocoa.h>
#import "PDFMerger.h"

@interface ProgressWindowController : NSWindowController {
	IBOutlet NSTextField *statusField;
	IBOutlet NSTextView *errorTextView;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSTextField *sourceLocationField;
	IBOutlet NSTextField *newFileField;
	IBOutlet NSWindow *directionChooserWindow;
	
	NSArray *progressStatuses;
	NSUInteger statusLevel;
	NSString *sourceLocation;
	NSString *frameName;
	PDFMerger *mergeProcessor;
	BOOL processStarted;
	BOOL canceled;
}

@property (retain) NSArray *progressStatuses;
@property (retain) NSString *sourceLocation;
@property (retain) NSString *frameName;
@property (retain) PDFMerger *mergeProcessor;
@property (readwrite) BOOL processStarted;
@property (readwrite) BOOL canceled;

- (IBAction)cancelAction:(id)sender;
@end