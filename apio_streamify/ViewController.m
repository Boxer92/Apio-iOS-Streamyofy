//
//  ViewController.m
//  apio_streamify
//
//  Created by Matteo Pio Napolitano on 10/02/15.
//  Copyright (c) 2015 OnCreate. All rights reserved.
//

#import "ViewController.h"
#import <MyoKit/MyoKit.h>

@interface ViewController () <ApioIOSocketDelegate>

@property (strong, nonatomic) VisualizerView *animatedView;
@property (strong, nonatomic) MPMusicPlayerController *appMusicPlayer;
@property (strong, nonatomic) AVAudioPlayer *avPlayer;
@property (strong, nonatomic) NSMutableArray *songsList;

@property (weak, nonatomic) IBOutlet UIView *ui_trackInfoContainer;
@property (weak, nonatomic) IBOutlet UILabel *ui_trackInfoAlbum;
@property (weak, nonatomic) IBOutlet UILabel *ui_trackInfoArtist;
@property (weak, nonatomic) IBOutlet UILabel *ui_trackInfoTitle;

@property (nonatomic, strong) ApioIOSocket *aios;
@property BOOL paused;
@property BOOL playing;
@property BOOL started;
@property BOOL triggered;
@property int nowPlayingIndex;

@property int fistCounter;

//@property float startingPoint;



@property (weak, nonatomic) IBOutlet UILabel *helloLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *accelerationProgressBar;
@property (weak, nonatomic) IBOutlet UILabel *accelerationLabel;
@property (weak, nonatomic) IBOutlet UILabel *armLabel;
@property (weak, nonatomic) IBOutlet UILabel *lockLabel;
@property (strong, nonatomic) TLMPose *currentPose;
@property (nonatomic, readwrite) BOOL shouldNotifyInBackground;

- (IBAction)didTapSettings:(id)sender;

@end

@implementation ViewController

- (id)init {
    // Initialize our view controller with a nib (see TLHMViewController.xib).
    self = [super initWithNibName:@"ViewController" bundle:nil];
    return self;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    self.fistCounter = 0;
    //ipAddress=@"192.168.1.18";
    self.shouldNotifyInBackground = YES;
    // Data notifications are received through NSNotificationCenter.
    // Posted whenever a TLMMyo connects
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didConnectDevice:)
                                                 name:TLMHubDidConnectDeviceNotification
                                               object:nil];
    // Posted whenever a TLMMyo disconnects.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didDisconnectDevice:)
                                                 name:TLMHubDidDisconnectDeviceNotification
                                               object:nil];
    // Posted whenever the user does a successful Sync Gesture.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didSyncArm:)
                                                 name:TLMMyoDidReceiveArmSyncEventNotification
                                               object:nil];
    // Posted whenever Myo loses sync with an arm (when Myo is taken off, or moved enough on the user's arm).
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didUnsyncArm:)
                                                 name:TLMMyoDidReceiveArmUnsyncEventNotification
                                               object:nil];
    // Posted whenever Myo is unlocked and the application uses TLMLockingPolicyStandard.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didUnlockDevice:)
                                                 name:TLMMyoDidReceiveUnlockEventNotification
                                               object:nil];
    // Posted whenever Myo is locked and the application uses TLMLockingPolicyStandard.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didLockDevice:)
                                                 name:TLMMyoDidReceiveLockEventNotification
                                               object:nil];
    // Posted when a new orientation event is available from a TLMMyo. Notifications are posted at a rate of 50 Hz.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveOrientationEvent:)
                                                 name:TLMMyoDidReceiveOrientationEventNotification
                                               object:nil];
    // Posted when a new accelerometer event is available from a TLMMyo. Notifications are posted at a rate of 50 Hz.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveAccelerometerEvent:)
                                                 name:TLMMyoDidReceiveAccelerometerEventNotification
                                               object:nil];
    // Posted when a new pose is available from a TLMMyo.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceivePoseChange:)
                                                 name:TLMMyoDidReceivePoseChangedNotification
                                               object:nil];
    
    self.shouldNotifyInBackground= YES;
    /*self.animatedView = [[VisualizerView alloc] initWithFrame:self.view.frame];
     [self.animatedView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
     self.view.backgroundColor = [UIColor colorWithHexString:@"#B9362C"];
     [self.view addSubview:self.animatedView];*/
    
    self.ui_trackInfoAlbum.text = @"-";
    self.ui_trackInfoArtist.text = @"-";
    self.ui_trackInfoTitle.text = @"-";
    
    self.aios = [[ApioIOSocket alloc] initWithHost:@"http://192.168.1.18" andPort:@"8083"];
    self.aios.delegate = self;
    
    NSError *audioError = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    if(![session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&audioError]) {
        NSLog(@"[ViewController] Failed to setup audio session: %@", audioError);
    }
    [session setActive:YES error:&audioError];
    
    self.appMusicPlayer = [MPMusicPlayerController applicationMusicPlayer];
    [self.appMusicPlayer setShuffleMode: MPMusicShuffleModeOff];
    [self.appMusicPlayer setRepeatMode: MPMusicRepeatModeNone];
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(handle_NowPlayingItemChanged:)
                               name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification
                             object:self.appMusicPlayer];
    
    [notificationCenter addObserver:self
                           selector:@selector(handle_PlaybackStateChanged:)
                               name:MPMusicPlayerControllerPlaybackStateDidChangeNotification
                             object:self.appMusicPlayer];
    
    [notificationCenter addObserver:self
                           selector:@selector(handle_VolumeChanged:)
                               name:@"AVSystemController_SystemVolumeDidChangeNotification"
                             object:nil];
    
    [self.appMusicPlayer beginGeneratingPlaybackNotifications];
    
    MPMediaQuery *songsQuery = [MPMediaQuery songsQuery];
    self.songsList = [[NSMutableArray alloc] initWithArray:[songsQuery collections]];
    
    self.paused = NO;
    self.playing = NO;
    self.started = NO;
    self.triggered = NO;
    self.nowPlayingIndex = -1;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - NSNotificationCenter Methods

- (void)didConnectDevice:(NSNotification *)notification {
    // Align our label to be in the center of the view.
    [self.helloLabel setCenter:self.view.center];
    
    // Set the text of the armLabel to "Perform the Sync Gesture".
    self.armLabel.text = @"Perform the Sync Gesture";
    
    // Set the text of our helloLabel to be "Hello Myo".
    self.helloLabel.text = @"Hello Myo";
    
    // Show the acceleration progress bar
    [self.accelerationProgressBar setHidden:NO];
    [self.accelerationLabel setHidden:NO];
}

- (void)didDisconnectDevice:(NSNotification *)notification {
    // Remove the text from our labels when the Myo has disconnected.
    self.helloLabel.text = @"";
    self.armLabel.text = @"";
    self.lockLabel.text = @"";
    
    // Hide the acceleration progress bar.
    [self.accelerationProgressBar setHidden:YES];
    [self.accelerationLabel setHidden:YES];
}

- (void)didUnlockDevice:(NSNotification *)notification {
    // Update the label to reflect Myo's lock state.
    self.lockLabel.text = @"Unlocked";
}

- (void)didLockDevice:(NSNotification *)notification {
    // Update the label to reflect Myo's lock state.
    self.lockLabel.text = @"Locked";
}

- (void)didSyncArm:(NSNotification *)notification {
    // Retrieve the arm event from the notification's userInfo with the kTLMKeyArmSyncEvent key.
    TLMArmSyncEvent *armEvent = notification.userInfo[kTLMKeyArmSyncEvent];
    
    // Update the armLabel with arm information.
    NSString *armString = armEvent.arm == TLMArmRight ? @"Right" : @"Left";
    NSString *directionString = armEvent.xDirection == TLMArmXDirectionTowardWrist ? @"Toward Wrist" : @"Toward Elbow";
    self.armLabel.text = [NSString stringWithFormat:@"Arm: %@ X-Direction: %@", armString, directionString];
    self.lockLabel.text = @"Locked";
}

- (void)didUnsyncArm:(NSNotification *)notification {
    // Reset the labels.
    self.armLabel.text = @"Perform the Sync Gesture";
    self.helloLabel.text = @"Hello Myo";
    self.lockLabel.text = @"";
    self.helloLabel.font = [UIFont fontWithName:@"Helvetica Neue" size:50];
    self.helloLabel.textColor = [UIColor blackColor];
}

- (void)didReceiveOrientationEvent:(NSNotification *)notification {
    //TLMPose *pose = notification.userInfo[kTLMKeyPose];
    //self.currentPose = pose;
    //NSLog(@"%d", self.currentPose.type);
    // Retrieve the orientation from the NSNotification's userInfo with the kTLMKeyOrientationEvent key.
    TLMOrientationEvent *orientationEvent = notification.userInfo[kTLMKeyOrientationEvent];
    
    // Create Euler angles from the quaternion of the orientation.
    TLMEulerAngles *angles = [TLMEulerAngles anglesWithQuaternion:orientationEvent.quaternion];
    
    // Next, we want to apply a rotation and perspective transformation based on the pitch, yaw, and roll.
    CATransform3D rotationAndPerspectiveTransform = CATransform3DConcat(CATransform3DConcat(CATransform3DRotate (CATransform3DIdentity, angles.pitch.radians, -1.0, 0.0, 0.0), CATransform3DRotate(CATransform3DIdentity, angles.yaw.radians, 0.0, 1.0, 0.0)), CATransform3DRotate(CATransform3DIdentity, angles.roll.radians, 0.0, 0.0, -1.0));
    //NSString *rollio= orientationEvent.quaternion.toString();
    //NSLog(@"Rollio:");
    //NSLog(@"%f", angles.roll.radians);
    
    // Apply the rotation and perspective transform to helloLabel.
    self.helloLabel.layer.transform = rotationAndPerspectiveTransform;
    if(self.fistCounter % 10 == 0){
        //NSLog(@"counter: %d", self.fistCounter);
        if(self.currentPose.type == TLMPoseTypeFist){
            //NSLog(@"angles.roll.radians vale %f", angles.roll.radians);
            // Retrieve the orientation from the NSNotification's userInfo with the kTLMKeyOrientationEvent key.
            //TLMOrientationEvent *orientationEvent = notification.userInfo[kTLMKeyOrientationEvent];
            
            // Create Euler angles from the quaternion of the orientation.
            //float actualPoint= (angles.roll.radians+M_PI)/(2*M_PI);
            float actualPoint = (angles.roll.radians+1.85)/(3.25);
            if(actualPoint > 1){
                actualPoint = 1;
            } else if(actualPoint < 0){
                actualPoint = 0;
            }
            
            //NSLog(@"actualPoint vale %f", actualPoint);
            //NSLog(@"rollio vale: %f", roll);
            
            [self setVolume:actualPoint];
        }
    }
    self.fistCounter++;
}

- (void)didReceiveAccelerometerEvent:(NSNotification *)notification {
    // Retrieve the accelerometer event from the NSNotification's userInfo with the kTLMKeyAccelerometerEvent.
    TLMAccelerometerEvent *accelerometerEvent = notification.userInfo[kTLMKeyAccelerometerEvent];
    
    // Get the acceleration vector from the accelerometer event.
    TLMVector3 accelerationVector = accelerometerEvent.vector;
    
    // Calculate the magnitude of the acceleration vector.
    float magnitude = TLMVector3Length(accelerationVector);
    
    // Update the progress bar based on the magnitude of the acceleration vector.
    self.accelerationProgressBar.progress = magnitude / 8;
    
    /* Note you can also access the x, y, z values of the acceleration (in G's) like below
     float x = accelerationVector.x;
     float y = accelerationVector.y;
     float z = accelerationVector.z;
     NSLog(@"X:");
    NSLog(@"%f", x);
    */
}

- (void)didReceivePoseChange:(NSNotification *)notification {
    // Retrieve the pose from the NSNotification's userInfo with the kTLMKeyPose key.
    TLMPose *pose = notification.userInfo[kTLMKeyPose];
    self.currentPose = pose;
    
    // Handle the cases of the TLMPoseType enumeration, and change the color of helloLabel based on the pose we receive.
    switch (pose.type) {
        case TLMPoseTypeUnknown:
        case TLMPoseTypeRest:
        case TLMPoseTypeDoubleTap:
        {
            // Changes helloLabel's font to Helvetica Neue when the user is in a rest or unknown pose.
            self.helloLabel.text = @"Hello Myo";
            self.helloLabel.font = [UIFont fontWithName:@"Helvetica Neue" size:50];
            self.helloLabel.textColor = [UIColor blackColor];
            break;
        }
        case TLMPoseTypeFist:
        {
            // Changes helloLabel's font to Noteworthy when the user is in a fist pose.
            self.helloLabel.text = @"Fist";
            self.helloLabel.font = [UIFont fontWithName:@"Noteworthy" size:50];
            self.helloLabel.textColor = [UIColor greenColor];
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
            [properties setObject:@"1" forKey:@"fist"];
            [properties setObject:@"0" forKey:@"fingerspread"];
            [properties setObject:@"0" forKey:@"wavein"];
            [properties setObject:@"0" forKey:@"waveout"];
            
            [dict setObject:@"11111" forKey:@"address"];
            [dict setObject:properties forKey:@"properties"];
            [dict setObject:@"true" forKey:@"writeToDatabase"];
            //[dict setObject:@"true" forKey:@"writeToSerial"];
            [dict setObject:@"false" forKey:@"writeToSerial"];
            NSDictionary *data = [[NSDictionary alloc] initWithDictionary:dict];
            
            /*TLMOrientationEvent *orientationEvent = notification.userInfo[kTLMKeyOrientationEvent];
            TLMEulerAngles *angles = [TLMEulerAngles anglesWithQuaternion:orientationEvent.quaternion];
            self.startingPoint = angles.roll.radians;
            NSLog(@"%f", self.startingPoint);*/
            
            [self.aios emit:@"apio_notification" data:data];
            //NSLog(@"Fist");
            break;
        }
        case TLMPoseTypeWaveIn:
        {
            // Changes helloLabel's font to Courier New when the user is in a wave in pose.
            self.helloLabel.text = @"Wave In";
            self.helloLabel.font = [UIFont fontWithName:@"Courier New" size:50];
            self.helloLabel.textColor = [UIColor greenColor];
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
            
            [properties setObject:@"0" forKey:@"fist"];
            [properties setObject:@"0" forKey:@"fingerspread"];
            [properties setObject:@"0" forKey:@"waveout"];
            [properties setObject:@"1" forKey:@"wavein"];
            
            //[properties setObject:[NSNumber numberWithInt:denormalizedVolume] forKey:@"volume"];
            [dict setObject:@"11111" forKey:@"address"];
            [dict setObject:properties forKey:@"properties"];
            [dict setObject:@"true" forKey:@"writeToDatabase"];
            //[dict setObject:@"true" forKey:@"writeToSerial"];
            [dict setObject:@"false" forKey:@"writeToSerial"];
            NSDictionary *data = [[NSDictionary alloc] initWithDictionary:dict];
            
            [self.aios emit:@"apio_notification" data:data];
            break;
        }
        case TLMPoseTypeWaveOut:
        {
            // Changes helloLabel's font to Snell Roundhand when the user is in a wave out pose.
            self.helloLabel.text = @"Wave Out";
            self.helloLabel.font = [UIFont fontWithName:@"Snell Roundhand" size:50];
            self.helloLabel.textColor = [UIColor greenColor];
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
            
            [properties setObject:@"0" forKey:@"fist"];
            [properties setObject:@"0" forKey:@"fingerspread"];
            [properties setObject:@"0" forKey:@"wavein"];
            [properties setObject:@"1" forKey:@"waveout"];
            
            //[properties setObject:[NSNumber numberWithInt:denormalizedVolume] forKey:@"volume"];
            [dict setObject:@"11111" forKey:@"address"];
            [dict setObject:properties forKey:@"properties"];
            [dict setObject:@"true" forKey:@"writeToDatabase"];
            //[dict setObject:@"true" forKey:@"writeToSerial"];
            [dict setObject:@"false" forKey:@"writeToSerial"];
            NSDictionary *data = [[NSDictionary alloc] initWithDictionary:dict];
            
            [self.aios emit:@"apio_notification" data:data];
            
            break;
        }
        case TLMPoseTypeFingersSpread:
        {
            // Changes helloLabel's font to Chalkduster when the user is in a fingers spread pose.
            self.helloLabel.text = @"Fingers Spread";
            self.helloLabel.font = [UIFont fontWithName:@"Chalkduster" size:50];
            self.helloLabel.textColor = [UIColor greenColor];
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
            
            [properties setObject:@"0" forKey:@"fist"];
            [properties setObject:@"1" forKey:@"fingerspread"];
            [properties setObject:@"0" forKey:@"wavein"];
            [properties setObject:@"0" forKey:@"waveout"];
            
            //[properties setObject:[NSNumber numberWithInt:denormalizedVolume] forKey:@"volume"];
            [dict setObject:@"11111" forKey:@"address"];
            [dict setObject:properties forKey:@"properties"];
            [dict setObject:@"true" forKey:@"writeToDatabase"];
            //[dict setObject:@"true" forKey:@"writeToSerial"];
            [dict setObject:@"false" forKey:@"writeToSerial"];
            NSDictionary *data = [[NSDictionary alloc] initWithDictionary:dict];
            
            [self.aios emit:@"apio_notification" data:data];
            break;
        }
    }
    
    // Unlock the Myo whenever we receive a pose
    if (pose.type == TLMPoseTypeUnknown || pose.type == TLMPoseTypeRest) {
        // Causes the Myo to lock after a short period.
        [pose.myo unlockWithType:TLMUnlockTypeTimed];
    } else {
        // Keeps the Myo unlocked until specified.
        // This is required to keep Myo unlocked while holding a pose, but if a pose is not being held, use
        // TLMUnlockTypeTimed to restart the timer.
        [pose.myo unlockWithType:TLMUnlockTypeHold];
        // Indicates that a user action has been performed.
        [pose.myo indicateUserAction];
    }
}

- (IBAction)didTapSettings:(id)sender {
    // Note that when the settings view controller is presented to the user, it must be in a UINavigationController.
    UINavigationController *controller = [TLMSettingsViewController settingsInNavigationController];
    // Present the settings view controller modally.
    [self presentViewController:controller animated:YES completion:nil];
}


- (void)onSocketReady:(NSDictionary *)initialConfiguration {
    NSLog(@"onSocketReady %@", initialConfiguration);
    [self sendPlaylistToHost];
}

- (void)onSocketConnectionFailed {
    NSLog(@"onSocketConnectionFailed");
}

- (void)onEventReceived:(NSArray*)data {
    //NSLog(@"onEventReceived %@", data);
    if (data != nil) {
        NSDictionary *contents = [data objectAtIndex:0];
        NSInteger address = [[contents objectForKey:@"address"] integerValue];
        if (address == 1000) { // Stereo Philips
            NSDictionary *properties = [contents objectForKey:@"properties"];
            if ([[properties allKeys] containsObject:@"onoff"]) {
                NSInteger onoff = [[properties objectForKey:@"onoff"] integerValue];
                if (onoff == 0) {
                    if (self.playing) {
                        self.triggered = YES;
                        [self pause];
                    }
                }
                else {
                    if (self.paused) {
                        self.triggered = YES;
                        [self play];
                    }
                    else if (!self.playing) {
                        self.triggered = YES;
                        [self playRandom];
                    }
                    else{
                        self.playing = YES;
                        self.paused = NO;
                        self.started = NO;
                        self.triggered = NO;
                    }
                }
            }
            else if ([[properties allKeys] containsObject:@"volume"]) {
                float volume = [[properties objectForKey:@"volume"] floatValue];
                float normalizedVolume = volume / 255;
                [self setVolume:normalizedVolume];
            }
            else if ([[properties allKeys] containsObject:@"avanti"]) {
                self.triggered = YES;
                [self playRandom];
            }
            else if ([[properties allKeys] containsObject:@"indietro"]) {
                self.triggered = YES;
                [self stop];
                [self play];
            }
            else if ([[properties allKeys] containsObject:@"canzoni"]) {
                NSInteger index = [[properties objectForKey:@"canzoni"] integerValue];
                if (index != -1) {
                    self.triggered = YES;
                    [self playSelectedTrack:(int)index];
                }
            }
        }
    }
}

- (void)onSocketError:(NSDictionary*)error {
    NSLog(@"onSocketError %@", error);
}

- (void)onSocketDisconnected {
    NSLog(@"onSocketDisconnected");
}

- (void)onSocketReconnect {
    NSLog(@"onSocketReconnect");
}

- (void)onSocketReconnectionError {
    NSLog(@"onSocketReconnectionError");
}

- (void)handle_NowPlayingItemChanged:(NSNotification *)notification {
    NSLog(@"handle_NowPlayingItemChanged");
    
    if (self.started && self.playing && !self.triggered) {
        self.started = NO;
        self.nowPlayingIndex = self.nowPlayingIndex + 1;
        
        int trackCount = [self.songsList count];
        if (self.nowPlayingIndex > (trackCount - 1)) {
            self.nowPlayingIndex = 0;
        }
        
        [self playSelectedTrack:self.nowPlayingIndex];
    }
    else{
        self.started = YES;
        self.triggered = NO;
        MPMusicPlayerController *player = (MPMusicPlayerController *)notification.object;
        MPMediaItem *song = [player nowPlayingItem];
        
        if (song) {
            NSString *album = [song valueForProperty:MPMediaItemPropertyAlbumTitle];
            NSString *artist = [song valueForProperty:MPMediaItemPropertyArtist];
            NSString *title = [song valueForProperty:MPMediaItemPropertyTitle];
            
            self.ui_trackInfoContainer.hidden = NO;
            self.ui_trackInfoAlbum.text = album;
            self.ui_trackInfoArtist.text = artist;
            self.ui_trackInfoTitle.text = title;
            
            if (self.nowPlayingIndex != -1) {
                [self sendNowPlayingTrackToHost];
            }
        }
        else {
            self.ui_trackInfoContainer.hidden = YES;
        }
    }
}

- (void)handle_PlaybackStateChanged:(id)sender {
    NSLog(@"handle_PlaybackStateChanged");
}

- (void)handle_VolumeChanged:(id)sender {
    //NSLog(@"handle_VolumeChanged");
    Float32 volume;
    UInt32 dataSize_vol = sizeof(Float32);
    AudioSessionGetProperty (kAudioSessionProperty_CurrentHardwareOutputVolume, &dataSize_vol, &volume);
    [self.animatedView setCell:volume];
    
    int denormalizedVolume = (int)(volume * 255);
    //if((denormalizedVolume > self.denormalizedVolumeCheck && denormalizedVolume > self.denormalizedVolumeCheckPrev && denormalizedVolume > self.denormalizedVolumeCheckPrevPrev) || (denormalizedVolume < self.denormalizedVolumeCheck && denormalizedVolume < self.denormalizedVolumeCheckPrev && denormalizedVolume < self.denormalizedVolumeCheckPrevPrev)){
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
        [properties setObject:[NSNumber numberWithInt:denormalizedVolume] forKey:@"volume"];
        [dict setObject:@"1000" forKey:@"address"];
        [dict setObject:properties forKey:@"properties"];
        [dict setObject:@"true" forKey:@"writeToDatabase"];
        //[dict setObject:@"true" forKey:@"writeToSerial"];
        [dict setObject:@"false" forKey:@"writeToSerial"];
        NSDictionary *data = [[NSDictionary alloc] initWithDictionary:dict];
        
        [self.aios emit:@"apio_client_update" data:data];
        //self.denormalizedVolumeCheckPrevPrev = self.denormalizedVolumeCheckPrev;
        //self.denormalizedVolumeCheckPrev = self.denormalizedVolumeCheck;
        //self.denormalizedVolumeCheck = denormalizedVolume;
    //}
}

- (void)play {
    if (!([self.appMusicPlayer playbackState] == MPMusicPlaybackStatePlaying) && !self.paused) {
        [self.appMusicPlayer stop];
    }
    self.paused = NO;
    self.playing = YES;
    
    [self.appMusicPlayer prepareToPlay];
    [self.appMusicPlayer play];
}

- (void)playSelectedTrack:(int)index {
    if (self.songsList != nil) {
        self.nowPlayingIndex = index;
        MPMediaItem *selectedTrack = [[self.songsList objectAtIndex:self.nowPlayingIndex] representativeItem];
        NSMutableArray *tracks = [[NSMutableArray alloc] init];
        [tracks addObject:selectedTrack];
        MPMediaItemCollection *collection = [MPMediaItemCollection collectionWithItems:tracks];
        [self.appMusicPlayer setQueueWithItemCollection:collection];
        [self play];
    }
}

- (void)pause {
    self.paused = YES;
    self.playing = NO;
    [self.appMusicPlayer pause];
}

- (void)stop {
    self.paused = NO;
    self.playing = NO;
    self.started = NO;
    self.nowPlayingIndex = -1;
    [self.appMusicPlayer stop];
}

- (void)setVolume:(CGFloat)volume {
    [self.appMusicPlayer setVolume:volume];
}

- (void)playRandom {
    MPMediaQuery* query = [MPMediaQuery songsQuery];
    NSArray *songs = [query items];
    self.nowPlayingIndex = arc4random_uniform([songs count]);
    MPMediaItem *randomTrack = [songs objectAtIndex:self.nowPlayingIndex];
    NSMutableArray *randoms = [[NSMutableArray alloc] init];
    [randoms addObject:randomTrack];
    MPMediaItemCollection *collection = [MPMediaItemCollection collectionWithItems:randoms];
    
    [self.appMusicPlayer setQueueWithItemCollection:collection];
    [self play];
}

- (void)sendPlaylistToHost {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    if (self.songsList != nil) {
        NSMutableDictionary *tracks = [[NSMutableDictionary alloc] init];
        for (int i = 0; i < [self.songsList count]; i++) {
            MPMediaItem *song = [[self.songsList objectAtIndex:i] representativeItem];
            if (song) {
                NSString *artist = [song valueForProperty:MPMediaItemPropertyArtist];
                artist = artist != nil ? artist : @"Nessun artista";
                NSString *title = [song valueForProperty:MPMediaItemPropertyTitle];
                title = title != nil ? title : @"Traccia senza nome";
                NSString *track = [NSString stringWithFormat:@"%@ - %@", artist, title];
                [tracks setObject:[NSString stringWithFormat:@"%@", track] forKey:[NSString stringWithFormat:@"%d", i]];
            }
        }
        [dict setObject:@"1000" forKey:@"address"];
        [dict setObject:tracks forKey:@"canzoni"];
    }
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    
    HTTPClient *client = [[HTTPClient alloc] init];
    NSString *payload = @"http://192.168.1.18:8083/apio/updateListElements";
    NSURL *url = [NSURL URLWithString: payload];
    client.postData = jsonData;
    [client connect:url
             method:@"POST"
               type:@"JSON"
        beforeStart:^{}
   duringConnection:^{}
      afterComplete:^{
          NSDictionary *responsedata = [client responsedata];
          NSLog(@"%@",responsedata);
      }];
}

- (void)sendNowPlayingTrackToHost {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:[NSString stringWithFormat:@"%d", self.nowPlayingIndex] forKey:@"canzoni"];
    [dict setObject:@"1000" forKey:@"address"];
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    
    HTTPClient *client = [[HTTPClient alloc] init];
    NSString *payload = @"http://192.168.1.18:8083/apio/notify";
    NSURL *url = [NSURL URLWithString: payload];
    client.postData = jsonData;
    [client connect:url
             method:@"POST"
               type:@"JSON"
        beforeStart:^{}
   duringConnection:^{}
      afterComplete:^{
          NSDictionary *responsedata = [client responsedata];
          NSLog(@"%@",responsedata);
      }];
}

@end