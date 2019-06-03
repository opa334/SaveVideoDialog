@interface CAMViewfinderViewController

@property (readonly, nonatomic, getter=isRecording) BOOL recording;

@end

@interface CAMVideoCaptureResult : NSObject
@property (readonly, nonatomic) NSError *error;
@property (readonly, nonatomic) NSInteger reason;
@end

@interface CAMCaptureRequest : NSObject
@property (readonly, copy, nonatomic) NSURL *localDestinationURL;
@end

@interface CAMVideoCaptureRequest : CAMCaptureRequest
@end

volatile BOOL preventWrongSave;
volatile BOOL recordingStoppedThroughButton;

@interface SVDAlertRootViewController : UIViewController
@end

@implementation SVDAlertRootViewController

- (BOOL)prefersStatusBarHidden
{
	return YES;
}

@end

#import <Photos/Photos.h>

%hook CAMPersistenceController

- (void)videoRequest:(CAMVideoCaptureRequest*)arg1 didCompleteCaptureWithResult:(CAMVideoCaptureResult*)arg2
{
	if(recordingStoppedThroughButton)
	{
		recordingStoppedThroughButton = NO;
		preventWrongSave = YES;

		dispatch_async(dispatch_get_main_queue(), ^
		{
			__block UIWindow* window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
			window.rootViewController = [[SVDAlertRootViewController alloc] init];

			UIAlertController* alertController = [UIAlertController alertControllerWithTitle:@"Keep Video?" message:@"" preferredStyle:UIAlertControllerStyleAlert];

			UIAlertAction* yesAction = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
			{
				%orig;

				preventWrongSave = NO;
				window = nil;
			}];

			UIAlertAction* noAction = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action)
			{
				window = nil;

				__block NSString* localIdentifier;

				[[PHPhotoLibrary sharedPhotoLibrary] performChanges:^
				{
					PHAssetChangeRequest* createRequest = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:arg1.localDestinationURL];
					localIdentifier = [createRequest.placeholderForCreatedAsset localIdentifier];
				} completionHandler:^(BOOL success, NSError *error)
				{
					PHFetchResult* fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[localIdentifier] options:nil];

					[[PHPhotoLibrary sharedPhotoLibrary] performChanges:^
					{
						[PHAssetChangeRequest deleteAssets:@[fetchResult.firstObject]];
					} completionHandler:^(BOOL success, NSError *error)
					{
						[[NSFileManager defaultManager] removeItemAtURL:arg1.localDestinationURL error:nil];
						preventWrongSave = NO;
					}];
				}];
			}];

			[alertController addAction:noAction];
			[alertController addAction:yesAction];

			[window makeKeyAndVisible];
			[window.rootViewController presentViewController:alertController animated:YES completion:nil];
		});
	}
	else
	{
		%orig;
	}
}

%end

%hook CAMViewfinderViewController

- (void)videoRequestDidCompleteCapture:(id)arg1 withResponse:(id)arg2 error:(id)arg3
{
	if(preventWrongSave)
	{
		return;
	}

	%orig;
}

- (void)_handleShutterButtonPressed:(id)arg1
{
	recordingStoppedThroughButton = self.recording;

	%orig;
}

%end

%hook CAMImageWell

- (void)setThumbnailImage:(UIImage*)image uuid:(id)uuid animated:(BOOL)animated
{
	if(preventWrongSave)
	{
		return;
	}

	%orig;
}

%end
