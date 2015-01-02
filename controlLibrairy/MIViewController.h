//
//  MIViewController.h
//  microphone
//
//  Created by Olivier Delecueillerie on 28/01/2014.
//  Copyright (c) 2014 Olivier Delecueillerie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "MIMicrophoneUI.h"


@protocol microphonePlayerDelegate <NSObject>
@required

@property (nonatomic, strong) NSData *dataSoundRecorded;
- (void) deleteDataSoundRecorded;
- (void) playOtherSound;
@optional
- (void) microphonePlayerDidFinishRecording;
@end


@interface MIViewController : UIViewController <AVAudioRecorderDelegate, AVAudioPlayerDelegate ,microphoneRecorderDelegate>

+ (MIViewController *) instantiateInitialViewControllerWithMicrophoneDelegate:(id)delegate;
@property (strong, nonatomic) UIViewController <microphonePlayerDelegate> *delegate;
@property (strong, nonatomic) NSData *dataSoundRecorded;

@end