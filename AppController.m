#import "AppController.h"
#import "DonationReminder/DonationReminder.h"
#import "ProgressWindowController.h"
#import "NSRunningApplication+SmartActivate.h"
#import "PDFMerger.h"

#import <Quartz/Quartz.h>

#define useLog 0

#define DEFAULT_DPI 72

static id sharedObj;

@implementation AppController

+ (id)sharedAppController
{
	if (sharedObj == nil) {
		sharedObj = [[self alloc] init];
	}
	return sharedObj;
}

- (id)init
{
	if (self = [super init]) {
		if (sharedObj == nil) {
			sharedObj = self;
		}
	}
	
	return self;
}

- (BOOL)activateWindowForFolder:(NSString *)path
{
	for (NSWindow *window in [NSApp windows]) {
		if ([window.windowController isKindOfClass:[ProgressWindowController class]]) {
			NSString *location = [window.windowController sourceLocation];
			if ([location isEqualToString:path]) {
				[window.windowController showWindow:self];
				return YES;
			}
		}
	}
	return NO;
}

- (void)processFolder:(NSString *)path
{
#if useLog
	NSLog(@"%@", @"start processFolder");
#endif
	if ([self activateWindowForFolder:path]) return;
	ProgressWindowController *wcontroller = [[ProgressWindowController alloc] initWithWindowNibName:@"ProgressWindow"];
	[wcontroller setSourceLocation:path];
	[wcontroller showWindow:self];
	[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:path]];
}

#pragma mark actions

- (IBAction)chooseFolder:(id)sender
{
	NSOpenPanel *open_panel = [NSOpenPanel openPanel];
	[open_panel setCanChooseDirectories:YES];
	[open_panel setCanChooseFiles:NO];
	[open_panel setTitle:@"Choose a folder containing PDF/image files"];
	NSInteger result = [open_panel runModal];
	if (NSFileHandlingPanelCancelButton == result) return;
	
	NSArray *array = [open_panel URLs];
	[self processFolder:[[array lastObject] path]];
}

- (IBAction)makeDonation:(id)sender
{
	[DonationReminder goToDonation];
}

#pragma mark Services
void saveImageAsPDF(NSString *path)
{
	PDFDocument *pdfdoc = NULL;
	switch (image_type(path)) {
		case JpegImage:
			pdfdoc = [PDFDocument pdfDocumentWithImageURL:[NSURL fileURLWithPath:path]];
			break;
		case GenericImage:
			pdfdoc = [PDFDocument pdfDocumentWithImageURL:[NSURL fileURLWithPath:path]];
			break;
        default:
            break;
	}
	
	if (!pdfdoc) {
		[NSApp activateIgnoringOtherApps:YES];
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:NSLocalizedString(@"Not image files", @"message of alert")];
        [alert setInformativeText:NSLocalizedString(@"Passed files to MergePDF are not images files.",
                                                    @"invomative text of alert")];
        [alert runModal];
		return;
	}
	
    NSURL *pdfurl = [NSURL fileURLWithPath:[[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"]];
	NSFileManager *fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath:[pdfurl path]]) {
		NSSavePanel *sp = [NSSavePanel savePanel];
		[sp setMessage:NSLocalizedString(@"Choose location to save a PDF file.",
						@"message of save panel")];
		[sp setTitle:NSLocalizedString(@"Convert an image to a PDF.",
						@"title of save panel")];
        [sp setDirectoryURL:[pdfurl URLByDeletingLastPathComponent]];
        [sp setNameFieldStringValue:[pdfurl lastPathComponent]];
		[NSApp activateIgnoringOtherApps:YES];
        if (NSFileHandlingPanelCancelButton == [NSApp runModalForWindow:sp]) {
            return;
        }
		pdfurl = [sp URL];
	}
	
    [pdfdoc writeToURL:pdfurl];
}

- (void)imageToPDF:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error
{
	NSArray *types = [pboard types];
	NSArray *file_names;
	if (![types containsObject:NSFilenamesPboardType] 
		|| !(file_names = [pboard propertyListForType:NSFilenamesPboardType])) {
        *error = NSLocalizedString(@"Error: Pasteboard doesn't contain file paths.",
								   @"Pasteboard couldn't give string.");
        return;
    }
	
    for (NSString *a_path in file_names) {
		saveImageAsPDF(a_path);
	}
}

#pragma mark Delegate methods


- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
#if useLog
	NSLog(@"start application:openFiles: for :%@",[filenames description]);
#endif	
	NSEnumerator *enumerator = [filenames objectEnumerator];
	NSString *filename = nil;
	while (filename = [enumerator nextObject]) {
		BOOL is_dir;
		if (! [[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&is_dir]) 
			continue;
		if (!is_dir) continue;
		
		if (! [[NSWorkspace sharedWorkspace] openFile:filename]) continue;
		[self processFolder:filename];
	}
	[NSRunningApplication activateSelf];
	
#if useLog
	NSLog(@"end application:openFiles:");
#endif	
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	[DonationReminder remindDonation];
}

OSType getLauchedMethod()
{
#if useLog
	NSLog(@"%@", @"start getLauchedMethod");
#endif	
	NSAppleEventDescriptor *ev = [[NSAppleEventManager sharedAppleEventManager] currentAppleEvent];
#if useLog
	NSLog(@"%@", [ev description]);
#endif
	if (!ev) {
		return typeNull;
	}
	AEEventID evid = [ev eventID];
	NSAppleEventDescriptor *propData;
	OSType result = kAEOpenApplication;
	switch (evid) {
		case kAEOpenDocuments:
			result = evid;
			break;
		case kAEOpenApplication:
			propData = [ev paramDescriptorForKeyword: keyAEPropData];
			DescType type = propData ? [propData descriptorType] : typeNull;
			if(type == typeType) {
				result = [propData typeCodeValue];
				// keyAELaunchedAsLogInItem or keyAELaunchedAsServiceItem
			} else {
				result = evid;
			}
			break;
	}
	return result;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
#if useLog
	NSLog(@"start applicationDidFinishLaunching");
	NSAppleEventDescriptor *ev = [[NSAppleEventManager sharedAppleEventManager] currentAppleEvent];
	NSLog(@"event :%@\n", [ev description]);
#endif	
	OSType evid = getLauchedMethod();
	if (kAEOpenApplication == evid) {
		[self processFolder:@"Insertion Location"];
		//[self processFolder:@"/Users/tkurita/Dev/Projects/MergePDF/testpdfs/"];
	}
}

- (void)awakeFromNib
{
	NSString *defaultsPlistPath = [[NSBundle mainBundle] pathForResource:@"FactorySetting" ofType:@"plist"];
	NSDictionary *defautlsDict = [NSDictionary dictionaryWithContentsOfFile:defaultsPlistPath];
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults registerDefaults:defautlsDict];
	[NSApp setServicesProvider:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}

@end
