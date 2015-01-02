//
//  FDSoundActivatedRecorder.m
//  FDSoundActivatedRecorder
//
//  Created by William Entriken on 12/22/13.
//  Copyright (c) 2013 William Entriken. All rights reserved.
//

#import "FDSoundActivatedRecorder.h"
#import <AVFoundation/AVFoundation.h>
/*
 * HOW RECORDING WORKS
 *
 * V            Recording
 * O          /-----------\
 * L         /             \Fall
 * U        /Rise           \
 * M       /                 \
 * E  -----                   --------
 *    Listening                Done
 *
 * We start off by listening and saving the audio level every INTERVAL
 * When the level exceeds the moving average of recent levels by a threshold, we record
 * While recording, we average levels and look for a drop of a certain threshold
 * If the level drops, the average will not include them
 * If a certain number of consecutive levels are a drop then we stop recording
 *
 * SEE: Averaging logs http://physics.stackexchange.com/questions/46228/averaging-decibels
 * Our "averages" are time averages of log squared power, an odd definition
 */
#define INTERVAL_SECONDS 0.05
#define SAVING_SAMPLES_PER_SECOND 22050
#define TOTAL_TIMEOUT_SECONDS 10.0

#define LISTENING_MINIMUM_INTERVALS 2
#define LISTENING_AVERAGING_INTERVALS 7
#define RISE_TRIGGER_DB 15
#define RISE_TRIGGER_INTERVALS 2
#define RECORDING_MINIMUM_INTERVALS 4
#define RECORDING_AVERAGING_INTERVALS 15
#define FALL_TRIGGER_DB 10
#define FALL_TRIGGER_INTERVALS 4


@interface FDSoundActivatedRecorder() <AVAudioPlayerDelegate, AVAudioRecorderDelegate>

@property (nonatomic) AVAudioRecorder *audioRecorder;
@property (nonatomic) NSMutableArray *listeningIntervals;
@property (nonatomic) NSMutableArray *recordingIntervals;
@property (nonatomic) NSInteger triggerCount;

@property (nonatomic) BOOL isRecordingInProgress;
@property (strong, nonatomic) NSTimer *intervalTimer;
@property (nonatomic) double recordingBeginTime;
@property (strong, nonatomic) NSURL *URLNewRecord;

@end

@implementation FDSoundActivatedRecorder

- (NSURL *) URLNewRecord {
    if (!_URLNewRecord) {
        // Set the audio file
        NSFileManager *fileManager = [NSFileManager defaultManager];
        //look for a temporary directory
        NSArray *arrayOfDir = [fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask];
        NSURL * urlBase = [arrayOfDir firstObject];
        NSURL *url = [NSURL URLWithString:@"newRecord.m4a" relativeToURL:urlBase];
        return url;
    }
    else return _URLNewRecord;
}

- (id)init {
    self = [super init];
    self.listeningIntervals = [NSMutableArray arrayWithCapacity:LISTENING_AVERAGING_INTERVALS];
    self.recordingIntervals = [NSMutableArray arrayWithCapacity:RECORDING_AVERAGING_INTERVALS];

    // USE kAudioFormatLinearPCM
    // SEE IMA4 vs M4A http://stackoverflow.com/questions/3509921/recorder-works-on-iphone-3gs-but-not-on-iphone-3g

    NSDictionary *recordSettings =
    [[NSDictionary alloc] initWithObjectsAndKeys:
     [NSNumber numberWithFloat: SAVING_SAMPLES_PER_SECOND],     AVSampleRateKey,
     [NSNumber numberWithInt: kAudioFormatMPEG4AAC],            AVFormatIDKey,
     [NSNumber numberWithInt: 1],                               AVNumberOfChannelsKey,
     [NSNumber numberWithInt: AVAudioQualityHigh],               AVEncoderAudioQualityKey,
     nil];

    NSError *error = nil;
    self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:self.URLNewRecord settings:recordSettings error:&error];
    self.audioRecorder.delegate = self;
    self.audioRecorder.meteringEnabled = YES;
    if (![self.audioRecorder prepareToRecord]){
        NSLog(@"self.audioRecorder cannot prepareToRecord");
    }
    return self;
}

- (void)startListening
{
    [self.audioRecorder stop];
    self.isRecordingInProgress = NO;
    self.recordingBeginTime = 0;
    // Start recording for XX seconds
    [self.audioRecorder recordForDuration:TOTAL_TIMEOUT_SECONDS];
    self.intervalTimer = [NSTimer scheduledTimerWithTimeInterval:INTERVAL_SECONDS
                                                          target:self
                                                        selector:@selector(interval)
                                                        userInfo:nil
                                                         repeats:YES];
    [self.listeningIntervals removeAllObjects];
    [self.recordingIntervals removeAllObjects];
    self.triggerCount = 0;
}

- (void)startRecording
{
    if ([self.delegate respondsToSelector:@selector(soundActivatedRecorderDidStartRecording:)])
        [self.delegate soundActivatedRecorderDidStartRecording:self];
    self.isRecordingInProgress = YES;
    self.triggerCount = 0;
    self.recordingBeginTime = self.audioRecorder.currentTime - RISE_TRIGGER_INTERVALS * INTERVAL_SECONDS;
    if (self.recordingBeginTime < 0)
        self.recordingBeginTime = 0;
}

- (void)stopListeningAndKeepRecordingIfInProgress:(BOOL)keep
{
    [self.intervalTimer invalidate];
    [self.audioRecorder stop];
    if ([self.delegate respondsToSelector:@selector(soundActivatedRecorderDidStopRecording:andSavedSound:)])
        [self.delegate soundActivatedRecorderDidStopRecording:self andSavedSound:keep];

    self.trimmedRecordUrl = [self trimmedRecordUrl];
    NSLog(@"trimmed record url %@", self.trimmedRecordUrl.absoluteString);
    // if KEEP, then CHECK that ISRECORDING is true (to avoid double shot due to slow [self interval]
}

- (void)deleteRecording
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:[self.audioRecorder.url path] isDirectory:NO])
        [fileManager removeItemAtPath:[self.audioRecorder.url path] error:nil];
}

- (void)dealloc
{
    [self deleteRecording];
}

////////////////////////////

- (void)interval
{
    if (!self.audioRecorder.recording) { // Timed out
        [self stopListeningAndKeepRecordingIfInProgress:NO];
        return;
    }

    [self.audioRecorder updateMeters];
    float currentLevel = [self.audioRecorder averagePowerForChannel:0];

    float microphoneLevel = fabsf((currentLevel/80)+1);
    if ([self.delegate respondsToSelector:@selector(soundActivatedRecorderMicrophoneLevelGauge:)]) {
        [self.delegate soundActivatedRecorderMicrophoneLevelGauge:microphoneLevel];
    }

    //NSLog(@"%2.2f %lu %lu %d %ld %@ %@", currentLevel, (unsigned long)self.listeningIntervals.count, (unsigned long)self.recordingIntervals.count, self.isRecordingInProgress, (long)self.triggerCount, [self.listeningIntervals valueForKeyPath:@"@avg.self"], [self.recordingIntervals valueForKeyPath:@"@avg.self"] );

    if (self.isRecordingInProgress) {
        // info about the use of @avg
        //http://stackoverflow.com/questions/14398756/find-the-average-of-an-nsmutablearray-with-valueforkeypath
        NSNumber *recordingAverage = [self.recordingIntervals valueForKeyPath:@"@avg.self"];

        //first we wait to have enough interval
        if (self.recordingIntervals.count < RECORDING_MINIMUM_INTERVALS) {
            [self.recordingIntervals addObject:[NSNumber numberWithFloat:currentLevel]];
        }

        //case the sound is not hearable once
        else if (currentLevel <= recordingAverage.doubleValue - FALL_TRIGGER_DB) {
            self.triggerCount++;
            NSLog(@"triger for currentLevel %2.2f",currentLevel);
        }

        //case the sound is hearable we add the new value to the array
        else {
            [self.recordingIntervals addObject:[NSNumber numberWithFloat:currentLevel]];
            if (self.recordingIntervals.count > RECORDING_AVERAGING_INTERVALS)
                [self.recordingIntervals removeObjectAtIndex:0];
        }

        //case the sound is not hearable for a few interval
        if (self.triggerCount >= FALL_TRIGGER_INTERVALS) {
            [self stopListeningAndKeepRecordingIfInProgress:YES];
        }
    }

    else {

        NSNumber *listeningAverage = [self.listeningIntervals valueForKeyPath:@"@avg.self"];


        //first we wait to have enough interval
        if (self.listeningIntervals.count < LISTENING_MINIMUM_INTERVALS) {
            [self.listeningIntervals addObject:[NSNumber numberWithFloat:currentLevel]];
        }
        // case we have a peak in sound
        else if (currentLevel >= listeningAverage.doubleValue + RISE_TRIGGER_DB) {
            self.triggerCount++;
        }
        // case we still have no sound
        else {
            [self.listeningIntervals addObject:[NSNumber numberWithFloat:currentLevel]];
            if (self.listeningIntervals.count > LISTENING_AVERAGING_INTERVALS)
                [self.listeningIntervals removeObjectAtIndex:0];
        }
        // the sound is hearable
        if (self.triggerCount >= RISE_TRIGGER_INTERVALS) {
            [self startRecording];
        }
    }
}


- (NSURL *)trimmedRecordUrl
{
    // Prepare output
    //
    NSURL *urlBase = [self.audioRecorder.url baseURL];
    // url of the trimmed audio file
    NSURL *url = [NSURL URLWithString:@"recordingConverted.caf" relativeToURL:urlBase];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;

    if ([fileManager removeItemAtURL:url error:&error]) {
        NSLog(@"removeItemAtPath %@", [url absoluteString]);
    } else {
        NSLog(@"error to remove item at path %@", error);
    }

    AVAsset *avAsset = [AVAsset assetWithURL:self.audioRecorder.url];
    NSArray *tracks = [avAsset tracksWithMediaType:AVMediaTypeAudio];
    AVAssetTrack *track = [tracks objectAtIndex:0];
    NSLog(@"number of tracks %lu",(unsigned long)[tracks count]);

    AVAssetExportSession *exportSession = [AVAssetExportSession
                                           exportSessionWithAsset:avAsset
                                           presetName:AVAssetExportPresetAppleM4A];
    
    // create trim time range
    CMTime startTime = CMTimeMake(self.recordingBeginTime*SAVING_SAMPLES_PER_SECOND, SAVING_SAMPLES_PER_SECOND);
    CMTimeRange exportTimeRange = CMTimeRangeFromTimeToTime(startTime, kCMTimePositiveInfinity);
    
    // create fade in time range
    CMTime startFadeInTime = startTime;
    CMTime endFadeInTime = CMTimeMake(self.recordingBeginTime*SAVING_SAMPLES_PER_SECOND + RISE_TRIGGER_INTERVALS*INTERVAL_SECONDS*SAVING_SAMPLES_PER_SECOND, SAVING_SAMPLES_PER_SECOND);
    CMTimeRange fadeInTimeRange = CMTimeRangeFromTimeToTime(startFadeInTime, endFadeInTime);
    
    // setup audio mix
    AVMutableAudioMix *exportAudioMix = [AVMutableAudioMix audioMix];
    AVMutableAudioMixInputParameters *exportAudioMixInputParameters = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:track];
    
    [exportAudioMixInputParameters setVolumeRampFromStartVolume:0.0 toEndVolume:1.0
                                                      timeRange:fadeInTimeRange];
    exportAudioMix.inputParameters = [NSArray
                                      arrayWithObject:exportAudioMixInputParameters];
    
    // configure export session  output with all our parameters
    exportSession.outputURL = url;
    exportSession.outputFileType = AVFileTypeAppleM4A;
    exportSession.timeRange = exportTimeRange;
    exportSession.audioMix = exportAudioMix;
    
    // MAKE THE EXPORT SYNCHRONOUS
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    if (AVAssetExportSessionStatusCompleted == exportSession.status) {
        NSLog(@"AVAssetExportSessionStatusCompleted");
        return url;
    } else if (AVAssetExportSessionStatusFailed == exportSession.status) {
        // a failure may happen because of an event out of your control
        // for example, an interruption like a phone call comming in
        // make sure and handle this case appropriately
        NSLog(@"AVAssetExportSessionStatusFailed %@", exportSession.error.localizedDescription);
    } else {
        NSLog(@"Export Session Status: %ld", (long)exportSession.status);
    }
    return nil;
}


@end