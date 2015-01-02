//
//  FDSoundActivatedRecorder.h
//  FDSoundActivatedRecorder
//
//  Created by William Entriken on 12/22/13.
//  Copyright (c) 2013 William Entriken. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDSoundActivatedRecorder;

@protocol FDSoundActivatedRecorderDelegate <NSObject>
@optional
- (void)soundActivatedRecorderDidStartRecording:(FDSoundActivatedRecorder *)recorder;
- (void)soundActivatedRecorderDidStopRecording:(FDSoundActivatedRecorder *)recorder andSavedSound:(BOOL)didSave;
- (void)soundActivatedRecorderMicrophoneLevelGauge:(float)microphoneLevel;
@end


@interface FDSoundActivatedRecorder : NSObject

- (void)startListening; // ... and record when ready
- (void)startRecording;
- (void)stopListeningAndKeepRecordingIfInProgress:(BOOL)keep;
- (void)deleteRecording;
//@property (strong, nonatomic) NSNumber *recordedDuration;
//@property (strong, nonatomic) NSString *recordedFilePath;
@property (weak, nonatomic) id <FDSoundActivatedRecorderDelegate> delegate;
@property (strong, nonatomic) NSURL *trimmedRecordUrl;
// WHEN USING THIS CLASS:
// NSError *error;
// [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
@end