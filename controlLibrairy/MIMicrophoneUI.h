//
//  MIMicrophoneUI.h
//  microphone
//
//  Created by Olivier Delecueillerie on 31/03/2014.
//  Copyright (c) 2014 Olivier Delecueillerie. All rights reserved.
//
//

#import <UIKit/UIKit.h>
#import "FDSoundActivatedRecorder.h"

@protocol microphoneRecorderDelegate <NSObject>
@required
@property (nonatomic, strong) NSData *dataSoundRecorded;
@optional
- (void) microphoneRecorderDidFinishRecording;

@end


@interface MIMicrophoneUI : UIViewController <FDSoundActivatedRecorderDelegate>
@property (strong, nonatomic) id <microphoneRecorderDelegate> delegate;

@end
