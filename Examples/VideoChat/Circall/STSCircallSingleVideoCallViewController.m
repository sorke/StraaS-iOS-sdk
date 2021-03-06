//
//  STSCircallMultipleVideoConferenceViewController.m
//  StraaSDemoApp
//
//  Created by Allen and Kim on 2018/5/3.
//  Copyright © 2018 StraaS.io. All rights reserved.
//

#import "STSCircallSingleVideoCallViewController.h"
#import <StraaSCircallSDK/STSCircallPlayerView.h>
#import <StraaSCircallSDK/STSCircallManager.h>
#import <MBProgressHUD/MBProgressHUD.h>

typedef NS_ENUM(NSUInteger, STSCircallSingleVideoCallViewControllerState){
    STSCircallSingleVideoCallViewControllerStateIdle,
    STSCircallSingleVideoCallViewControllerStateConnecting,
    STSCircallSingleVideoCallViewControllerStateConnected,
    STSCircallSingleVideoCallViewControllerStateTwoWayVideo
};

typedef NS_ENUM(NSUInteger, STSCircallSingleVideoCallViewControllerRecordingState){
    STSCircallSingleVideoCallViewControllerRecordingStateIdle,
    STSCircallSingleVideoCallViewControllerRecordingStateStarting,
    STSCircallSingleVideoCallViewControllerRecordingStateRecording
};

@interface STSCircallSingleVideoCallViewController () <STSCircallManagerDelegate>
// UI
@property (weak, nonatomic) IBOutlet STSCircallPlayerView *fullScreenVideoView;
@property (weak, nonatomic) IBOutlet STSCircallPlayerView *pictureInPictureVideoView;

@property (weak, nonatomic) IBOutlet UIButton *switchCameraCaputurePositionButton;
@property (weak, nonatomic) IBOutlet UIButton *switchCameraCaptureOnButton;
@property (weak, nonatomic) IBOutlet UIButton *switchMicrophoneOnButton;
@property (weak, nonatomic) IBOutlet UIButton *recordingButton;
@property (weak, nonatomic) IBOutlet UIButton *takeScreenshotButton;

@property (weak, nonatomic) IBOutlet UIImageView *recordingRedDot;
@property (weak, nonatomic) IBOutlet UIImageView *defaultFaceImageView;

@property (strong, nonatomic) MBProgressHUD *hud;

// properties
@property (strong, nonatomic) STSCircallManager *circallManager;

@property (assign, nonatomic) BOOL videoEnabled;
@property (assign, nonatomic) BOOL audioEnabled;
@property (assign, nonatomic) STSCircallSingleVideoCallViewControllerRecordingState recordingState;
@property (strong, nonatomic) NSString *recordingId;

@property (assign, nonatomic) STSCircallSingleVideoCallViewControllerState viewControllerState;
@property (strong, nonatomic) NSTimer *recordingRedDotTimer;

@end

@implementation STSCircallSingleVideoCallViewController

+ (instancetype)viewControllerFromStoryboard {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    STSCircallSingleVideoCallViewController * vc =
    [storyboard instantiateViewControllerWithIdentifier:@"STSCircallSingleVideoCallViewController"];
    return vc;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // UI settings
    self.recordingRedDot.layer.cornerRadius = 5.0;

    [self.switchCameraCaputurePositionButton setImage:[UIImage imageNamed:@"camera-switch"] forState:UIControlStateNormal];
    [self.switchCameraCaputurePositionButton setImage:[UIImage imageNamed:@"camera-switch-focus"] forState:UIControlStateHighlighted];

    [self.takeScreenshotButton setImage:[UIImage imageNamed:@"capture-img"] forState:UIControlStateNormal];
    [self.takeScreenshotButton setImage:[UIImage imageNamed:@"capture-img-focus"] forState:UIControlStateHighlighted];

    self.recordingRedDot.hidden = YES;

    // properties settings
    self.circallManager = [[STSCircallManager alloc] init];
    self.circallManager.delegate = self;

    STSCircallStreamConfig * streamConfig = [STSCircallStreamConfig new];
    streamConfig.minVideoSize = CGSizeMake(640, 360);
    self.pictureInPictureVideoView.scalingMode = STSCircallScalingModeAspectFill;
    self.pictureInPictureVideoView.isMirrored = YES;
    self.fullScreenVideoView.scalingMode = STSCircallScalingModeAspectFill;

    if (self.circallToken == nil) {
        [self showAlertWithTitle:@"Error" message:@"Circall token is nil"];
        return;
    }

    self.viewControllerState = STSCircallSingleVideoCallViewControllerStateIdle;
    self.recordingState = STSCircallSingleVideoCallViewControllerRecordingStateIdle;

    // actions
    self.hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    self.hud.mode = MBProgressHUDModeIndeterminate;

    __weak STSCircallSingleVideoCallViewController * weakSelf = self;
    void (^prepareWithPreviewViewSuccessHandler)(STSCircallStream * _Nonnull stream) = ^(STSCircallStream * _Nonnull stream) {
        weakSelf.pictureInPictureVideoView.stream = stream;
        weakSelf.viewControllerState = STSCircallSingleVideoCallViewControllerStateConnecting;
        [weakSelf.circallManager connectWithCircallToken:self.circallToken success:^{
            weakSelf.viewControllerState = STSCircallSingleVideoCallViewControllerStateConnected;

            STSCircallPublishConfig * config = [STSCircallPublishConfig new];
            config.maxVideoBitrate = @(600000);
            config.maxAudioBitrate = @(64000);
            [weakSelf.circallManager publishWithCameraCaptureWithConfig:config success:^(STSCircallStream * _Nonnull stream) {
                NSLog(@"publishWithConfig success with stream id: %@", stream.streamId);
            } failure:^(NSError * _Nonnull error) {
                NSLog(@"publishWithConfig failure");
            }];

            [self.hud hideAnimated:YES];
        } failure:^(NSError * _Nonnull error) {
            weakSelf.viewControllerState = STSCircallSingleVideoCallViewControllerStateIdle;
            NSString * errorMessage = [NSString stringWithFormat:@"ERROR: %@, %ld, %@", error.domain, error.code, error.localizedDescription];
            [weakSelf showAlertWithTitle:@"Error" message:errorMessage exitOnCompletion:YES];
            [self.hud hideAnimated:YES];
        }];
    };

    [self.circallManager prepareForCameraCaptureWithStreamConfig:streamConfig success:prepareWithPreviewViewSuccessHandler failure:^(NSError * _Nonnull error) {
        weakSelf.viewControllerState = STSCircallSingleVideoCallViewControllerStateIdle;
        [weakSelf showAlertWithTitle:@"Error" message:[NSString stringWithFormat:@"prepared failed with error: %@",error]];
        [self.hud hideAnimated:YES];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self addObserver:self forKeyPath:@"recordingState" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

-(void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self removeObserver:self forKeyPath:@"recordingState"];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

#pragma mark - Private Method

- (BOOL)videoEnabled {
    return self.pictureInPictureVideoView.stream.videoEnabled;
}

- (void)setVideoEnabled:(BOOL)videoEnabled {
    self.pictureInPictureVideoView.stream.videoEnabled = videoEnabled;
}

- (BOOL)audioEnabled {
    return self.pictureInPictureVideoView.stream.audioEnabled;
}

- (void)setAudioEnabled:(BOOL)audioEnabled {
    self.pictureInPictureVideoView.stream.audioEnabled = audioEnabled;
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    [self showAlertWithTitle:title message:message exitOnCompletion:NO];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message exitOnCompletion:(BOOL) exitOnCompletion {
    UIAlertController * alertController = [UIAlertController alertControllerWithTitle:title
                                                                              message:message
                                                                       preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:
     [UIAlertAction actionWithTitle:@"確定" style:UIAlertActionStyleDefault
                            handler: exitOnCompletion ? ^(UIAlertAction *action) {
                                [self leaveOngoingVideoCall];
                            } : nil]];
    [self presentViewController:alertController animated:YES completion:nil];

}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(recordingState))]) {
        STSCircallSingleVideoCallViewControllerRecordingState recordingState = [change[@"new"] integerValue];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateUIWithRecordingState:recordingState];
        });
    }
}

- (void)updateUIWithRecordingState:(STSCircallSingleVideoCallViewControllerRecordingState)recordingState {
    if (recordingState == STSCircallSingleVideoCallViewControllerRecordingStateRecording) {
        [self.recordingButton setImage:[UIImage imageNamed:@"capture-video-on"] forState:UIControlStateNormal];
        [self.recordingRedDot setHidden:NO];
        [self startAnimatingRecordingRedDot];
    } else {
        [self.recordingButton setImage:[UIImage imageNamed:@"capture-video-off"] forState:UIControlStateNormal];
        [self.recordingRedDot setHidden:YES];
        [self stopAnimatingRecordingRedDot];
    }
}

- (void)startAnimatingRecordingRedDot {
    __weak STSCircallSingleVideoCallViewController * weakSelf = self;
    self.recordingRedDotTimer = [NSTimer scheduledTimerWithTimeInterval:0.4 repeats:YES block:^(NSTimer * _Nonnull timer) {
        if (weakSelf.recordingRedDot.isHidden) {
            weakSelf.recordingRedDot.hidden = NO;
        } else {
            weakSelf.recordingRedDot.hidden = YES;
        }
    }];
}

- (void)stopAnimatingRecordingRedDot {
    [self.recordingRedDotTimer invalidate];
    self.recordingRedDotTimer = nil;
}

#pragma mark - IBAction

- (IBAction)closeButtonDidPressed:(id)sender {
    [self leaveOngoingVideoCall];
}

- (void)leaveOngoingVideoCall {
    // show alert
    if (self.viewControllerState == STSCircallSingleVideoCallViewControllerStateIdle) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }

    __block MBProgressHUD * hud = nil;

    __weak STSCircallSingleVideoCallViewController *weakSelf = self;
    void (^disconnectAndPopViewController)(void) = ^() {
        [weakSelf.circallManager disconnectWithSuccess:^{
            weakSelf.circallManager = nil;
            [hud hideAnimated:YES];
            [weakSelf.navigationController popViewControllerAnimated:YES];
        } failure:^(NSError * _Nonnull error) {
            NSString *errorMessage = [NSString stringWithFormat:@"error in disconnectWithSuccess: %@",error];
            NSAssert(false, errorMessage);
            weakSelf.circallManager = nil;
            [hud hideAnimated:YES];
            [weakSelf.navigationController popViewControllerAnimated:YES];
        }];
    };

    void (^stopRecordingIfNeededAndThenDisconnectAndPopViewController)(void) = ^() {
        if ((weakSelf.recordingState == STSCircallSingleVideoCallViewControllerRecordingStateRecording || weakSelf.recordingState == STSCircallSingleVideoCallViewControllerRecordingStateStarting) && self.fullScreenVideoView.stream != nil) {
            [weakSelf.circallManager stopRecordingStream:weakSelf.fullScreenVideoView.stream recordingId:weakSelf.recordingId success:^{
                weakSelf.recordingId = nil;
                weakSelf.recordingState = STSCircallSingleVideoCallViewControllerRecordingStateIdle;
                disconnectAndPopViewController();
            } failure:^(NSError * _Nonnull error) {
                NSString *errorMessage = [NSString stringWithFormat:@"error in stopRecordingStream: %@",error];
                NSAssert(false, errorMessage);
                disconnectAndPopViewController();
            }];
        } else {
            disconnectAndPopViewController();
        }
    };

    void (^unpublish)(void) = ^() {
        if (!weakSelf.circallManager.isLocalStreamPublished) {
            stopRecordingIfNeededAndThenDisconnectAndPopViewController();
            return;
        }
        [weakSelf.circallManager unpublishWithSuccess:^{
            stopRecordingIfNeededAndThenDisconnectAndPopViewController();
        } failure:^(NSError * _Nonnull error) {
            NSString *errorMessage = [NSString stringWithFormat:@"error in unpublishWithSuccess: %@",error];
            NSAssert(false, errorMessage);
            stopRecordingIfNeededAndThenDisconnectAndPopViewController();
        }];
    };

    UIAlertController * alertController = [UIAlertController alertControllerWithTitle:@"離開面談室"
                                                                              message:@"你確定要離開面談室嗎？"
                                                                       preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *exitAlertAction = [UIAlertAction actionWithTitle:@"確定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        hud = [MBProgressHUD showHUDAddedTo:weakSelf.view animated:YES];
        hud.mode = MBProgressHUDModeIndeterminate;
        // We would unpublish here before disconnect here. Without unpublish, there will be red bar on the screen top showing it's "publishing" when user press home button.
        // So far we don't do unpublish within disconnect, to leave more flexibility for the user
        if (!self.fullScreenVideoView.stream.streamId) {
            unpublish();
            return;
        }
        [weakSelf.circallManager unsubscribeStream:self.fullScreenVideoView.stream success:^{
            unpublish();
        } failure:^(NSError * _Nonnull error) {
            NSString *errorMessage = [NSString stringWithFormat:@"error in unsubscribeStream: %@",error];
            NSAssert(false, errorMessage);
            unpublish();
        }];
    }];
    [alertController addAction:exitAlertAction];
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (IBAction)switchCaptureCameraPositionButtonDidPressed:(id)sender {
    if (self.pictureInPictureVideoView.stream == nil) {
        return;
    }

    if (!self.videoEnabled) {
        return;
    }

    MBProgressHUD * hud = [MBProgressHUD showHUDAddedTo:self.defaultFaceImageView animated:YES];
    hud.mode = MBProgressHUDModeIndeterminate;
    hud.backgroundView.backgroundColor = [UIColor blackColor];
    hud.bezelView.style = MBProgressHUDBackgroundStyleSolidColor;
    hud.bezelView.backgroundColor = [UIColor clearColor];
    hud.contentColor = [UIColor whiteColor];
    UIImage *image = self.defaultFaceImageView.image;
    self.defaultFaceImageView.image = nil;
    self.pictureInPictureVideoView.hidden = YES;

    switch (self.pictureInPictureVideoView.stream.captureDevicePosition) {
        case AVCaptureDevicePositionFront:
            self.pictureInPictureVideoView.stream.captureDevicePosition = AVCaptureDevicePositionBack;
            self.pictureInPictureVideoView.isMirrored = NO;
            break;
        case AVCaptureDevicePositionBack:
        case AVCaptureDevicePositionUnspecified:
        default:
            self.pictureInPictureVideoView.stream.captureDevicePosition = AVCaptureDevicePositionFront;
            self.pictureInPictureVideoView.isMirrored = YES;
            break;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.defaultFaceImageView.image = image;
        self.pictureInPictureVideoView.hidden = NO;
        [hud hideAnimated:YES];
    });
}

- (IBAction)switchCameraCaptureOnButtonDidPressed:(id)sender {
    if (self.pictureInPictureVideoView.stream == nil) {
        return;
    }

    self.videoEnabled = !self.videoEnabled;

    if (self.videoEnabled) {
        [self.switchCameraCaptureOnButton setImage:[UIImage imageNamed:@"camera-on"] forState:UIControlStateNormal];
        self.pictureInPictureVideoView.hidden = NO;
    } else {
        [self.switchCameraCaptureOnButton setImage:[UIImage imageNamed:@"camera-off"] forState:UIControlStateNormal];
        self.pictureInPictureVideoView.hidden = YES;
    }
}

- (IBAction)switchMicrophoneOnButtonDidPressed:(id)sender {
    if (self.pictureInPictureVideoView.stream == nil) {
        return;
    }

    self.audioEnabled = !self.audioEnabled;

    if (self.audioEnabled) {
        [self.switchMicrophoneOnButton setImage:[UIImage imageNamed:@"voice-on"] forState:UIControlStateNormal];
    } else {
        [self.switchMicrophoneOnButton setImage:[UIImage imageNamed:@"voice-off"] forState:UIControlStateNormal];
    }
}

- (IBAction)recordingButtonDidPressed:(id)sender {
    if (self.viewControllerState != STSCircallSingleVideoCallViewControllerStateTwoWayVideo) {
        [self showAlertWithTitle:@"無法錄影" message:@"需等候 remote stream 加入, 才可開始進行錄影"];
        return;
    }

    __weak STSCircallSingleVideoCallViewController * weakSelf = self;
    switch (self.recordingState) {
        case STSCircallSingleVideoCallViewControllerRecordingStateIdle: {
            // start recording
            self.recordingState = STSCircallSingleVideoCallViewControllerRecordingStateStarting;

            [self.circallManager startRecordingStream:self.fullScreenVideoView.stream success:^(NSString *recordingId){
                weakSelf.recordingId = recordingId;
                weakSelf.recordingState = STSCircallSingleVideoCallViewControllerRecordingStateRecording;
            } failure:^(NSError * _Nonnull error) {
                weakSelf.recordingState = STSCircallSingleVideoCallViewControllerRecordingStateIdle;
                [weakSelf showAlertWithTitle:@"Error" message:[NSString stringWithFormat:@"start record failed with error:%@",error]];
            }];
            break;
        }
        case STSCircallSingleVideoCallViewControllerRecordingStateRecording: {
            // stop recording
            self.recordingState = STSCircallSingleVideoCallViewControllerRecordingStateIdle;

            [self.circallManager stopRecordingStream:self.fullScreenVideoView.stream recordingId:weakSelf.recordingId success:^{
                weakSelf.recordingId = nil;
                weakSelf.recordingState = STSCircallSingleVideoCallViewControllerRecordingStateIdle;
            } failure:^(NSError * _Nonnull error) {
                weakSelf.recordingState = STSCircallSingleVideoCallViewControllerRecordingStateRecording;
                [weakSelf showAlertWithTitle:@"Error" message:[NSString stringWithFormat:@"stop record failed with error:%@",error]];
            }];
            break;
        }
        case STSCircallSingleVideoCallViewControllerRecordingStateStarting:
        default:
            break;
    }
}

- (IBAction)takeScreenshotButtonDidPressed:(id)sender {
    if (self.fullScreenVideoView.stream == nil) {
        [self showAlertWithTitle:@"需等候 remote stream 加入, 才可開始截圖" message:nil];
    }

    UIImage *image = [self.fullScreenVideoView getVideoFrame];
    if (!image) {
        [self showAlertWithTitle:@"截圖失敗" message:nil];
        return;
    }

    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

- (void) image:(UIImage*)image didFinishSavingWithError:(NSError *)error contextInfo:(NSDictionary*)info {
    if (error) {
        NSString *errorMessage = @"截圖失敗";
        if (error.code == -3310) {
            errorMessage = @"無法儲存截圖，請先允許 StraaS 存取相片。";
        }
        [self showAlertWithTitle:errorMessage message:nil];
        return;
    }
    [self showAlertWithTitle:@"截圖成功，儲存至相簿" message:nil];
}

#pragma mark - STSCircallManagerDelegate Methods

- (void)circallManager:(STSCircallManager *)manager didAddStream:(STSCircallStream *)stream {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    __weak STSCircallSingleVideoCallViewController *weakSelf = self;
    [manager subscribeStream:stream success:^(STSCircallStream * _Nonnull stream) {
        weakSelf.viewControllerState = STSCircallSingleVideoCallViewControllerStateTwoWayVideo;
        weakSelf.fullScreenVideoView.stream = stream;

        [self getRecordingStatusWithStream:stream];
    } failure:^(STSCircallStream * _Nonnull stream, NSError * _Nonnull error) {
        weakSelf.viewControllerState = STSCircallSingleVideoCallViewControllerStateConnected;
        weakSelf.fullScreenVideoView.stream = stream;
    }];
}

- (void)getRecordingStatusWithStream:(STSCircallStream *)stream {
    __weak STSCircallSingleVideoCallViewController * weakSelf = self;
    [self.circallManager getRecordingStreamMetadataArrayWithSuccess:^(NSArray<STSCircallRecordingStreamMetadata *> * _Nonnull recordingStreamMetaDataArray) {
        for (STSCircallRecordingStreamMetadata *recordingStreamMetaData in recordingStreamMetaDataArray) {
            if ([recordingStreamMetaData.streamId isEqualToString:stream.streamId]) {
                weakSelf.recordingId = recordingStreamMetaData.recordingId;
                weakSelf.recordingState = recordingStreamMetaData.recordingId.length > 0 ? STSCircallSingleVideoCallViewControllerRecordingStateRecording : STSCircallSingleVideoCallViewControllerRecordingStateIdle;
            }
        }
    } failure:^(NSError * _Nonnull error) {
        NSString *errorMessage = [NSString stringWithFormat:@"getRecordingStatusWithStream failed with %@",error];
        NSAssert(false, errorMessage);
        weakSelf.recordingState = STSCircallSingleVideoCallViewControllerRecordingStateIdle;
    }];
}

- (void)circallManager:(STSCircallManager *)manager didRemoveStream:(STSCircallStream *)stream {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.viewControllerState = STSCircallSingleVideoCallViewControllerStateConnected;
    if ([self.fullScreenVideoView.stream.streamId isEqualToString:stream.streamId]) {
        self.recordingState = STSCircallSingleVideoCallViewControllerRecordingStateIdle;
        self.fullScreenVideoView.stream = nil;
    }
}

- (void)circallManager:(STSCircallManager *)manager onError:(NSError *)error {
    NSLog(@"%s - %@", __PRETTY_FUNCTION__, error);
    self.recordingState = STSCircallSingleVideoCallViewControllerRecordingStateIdle;
    self.viewControllerState = STSCircallSingleVideoCallViewControllerStateIdle;
    self.fullScreenVideoView.stream = nil;

    [self.hud hideAnimated:YES];
    NSString * errorMessage = [NSString stringWithFormat:@"ERROR: %@, %ld, %@", error.domain, error.code, error.localizedDescription];
    [self showAlertWithTitle:@"Error" message:errorMessage exitOnCompletion:YES];
}

@end
