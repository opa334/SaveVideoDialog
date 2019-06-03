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
			UIViewController* rootViewController = [[[[UIApplication sharedApplication] delegate] window] rootViewController];

			UIAlertController* alertController = [UIAlertController alertControllerWithTitle:@"Keep Video?" message:@"" preferredStyle:UIAlertControllerStyleAlert];

			UIAlertAction* yesAction = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action)
			{
				%orig;

				preventWrongSave = NO;
			}];

			UIAlertAction* noAction = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action)
			{
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

			[rootViewController presentViewController:alertController animated:YES completion:nil];
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
