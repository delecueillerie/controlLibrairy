//
//  MIViewController.m
//  microphone
//
//  Created by Olivier Delecueillerie on 28/01/2014.
//  Copyright (c) 2014 Olivier Delecueillerie. All rights reserved.
//
//
//

#import "MIViewController.h"
//#import "MIMicrophoneUI.h"

@interface MIViewController ()

enum mode
{
    play = 0,
    stop = 1,
    record = 2,
    delete = 3,
};

@property (weak, nonatomic) IBOutlet UIButton *button;
@property (weak, nonatomic) IBOutlet UISwitch *switchControl;

@property (nonatomic) enum mode mode;
@property (strong, nonatomic) AVAudioPlayer *player;
@end

@implementation MIViewController


+ (MIViewController *) instantiateInitialViewControllerWithMicrophoneDelegate:(id)delegate {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"controlBundle.bundle/Main" bundle:nil];
    MIViewController *viewController = [storyboard instantiateInitialViewController];
    viewController.delegate = delegate;
    return viewController;
}


- (IBAction)switchEditing:(UISwitch *)sender {
    self.editing = sender.on;
}

//setter of the editing property
- (void) setEditing:(BOOL)editing {
    if (editing) {
        [self buttonState:record];
    }
    else {
        [self buttonState:play];
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// VC LIFECYCLE
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)viewDidLoad
{
    [super viewDidLoad];

    //switch controle is used for dev and test purpose only
    //self.switchControl.hidden = YES;
    
    //init the default state of the button
    if (self.delegate.editing) {
        [self buttonState:record];
    } else {
        [self buttonState:play];
    }

    // Setup audio session
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CONTROL
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


- (void) buttonState:(NSUInteger) state {
    [self.button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    switch (state) {
        case 0:
        {
            //play
            self.mode = play;
            [self.button setImage:[UIImage imageNamed:@"controlBundle.bundle/buttonPlay"] forState:UIControlStateNormal];
            [self.button addTarget:self action:@selector(controlPlay:) forControlEvents:UIControlEventTouchUpInside];
            break;
        }
        case 1:
        {
            //stop playing
            self.mode = stop;
            [self.button setImage:[UIImage imageNamed:@"controlBundle.bundle/buttonStop64"] forState:UIControlStateNormal];
            [self.button addTarget:self action:@selector(controlStop:) forControlEvents:UIControlEventTouchUpInside];
            break;
        }
        case 2:
        {
            //activated recorder
            self.mode = record;
            [self.button setImage:[UIImage imageNamed:@"controlBundle.bundle/microphone64"] forState:UIControlStateNormal];
            [self.button addTarget:self action:@selector(controlRecord:) forControlEvents:UIControlEventTouchUpInside];
            break;
        }
        case 3:
        {
            //delete
            self.mode = delete;
            [self.button setImage:[UIImage imageNamed:@"controlBundle.bundle/buttonBin"] forState:UIControlStateNormal];
            [self.button addTarget:self action:@selector(deleteRecord:) forControlEvents:UIControlEventTouchUpInside];
            break;
        }
            
        default:
        {
            break;
        }
    }
}

- (void) nextButtonState:(BOOL) next {
    NSArray * modeAvailaible;
    
    if (self.delegate.editing) {
        modeAvailaible = @[[NSNumber numberWithInt:0], [NSNumber numberWithInt:2], [NSNumber numberWithInt:3]];
    } else {
        modeAvailaible = @[[NSNumber numberWithInt:0]];
    }
    
    NSUInteger index = [modeAvailaible indexOfObject:[NSNumber numberWithInt:self.mode]];
    NSInteger indexNext;
    if (next) {
        indexNext = (index +1 ) %[modeAvailaible count];
        
    } else {
        indexNext = index - 1 ;
        if (indexNext < 0) {
            indexNext = ([modeAvailaible count]-1);
        }
    }
    NSUInteger newState = [[modeAvailaible objectAtIndex:indexNext] integerValue];
    
    [self buttonState:newState];
}

- (void) deleteRecord:(id) sender {
    self.dataSoundRecorded = nil;
    self.delegate.dataSoundRecorded = nil;
}

- (IBAction)controlRecord:(id)sender {
//open MIMicrophone
    MIMicrophoneUI *microphoneVC = (MIMicrophoneUI *) [self.storyboard instantiateViewControllerWithIdentifier:@"microphone"];
    microphoneVC.delegate = self;
    [self presentViewController:microphoneVC animated:YES completion:^{
        //code
    }];
}

- (IBAction)controlStop:(id)sender {
    [self.player stop];
    [self buttonState:play];
}

- (IBAction)controlPlay:(id)sender {
    //self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:self.activatedRecorder.trimmedRecordUrl error:nil];
    if (self.delegate.dataSoundRecorded) {
        NSError *error;
        self.player = [[AVAudioPlayer alloc] initWithData:self.delegate.dataSoundRecorded error:&error];
        [self.player setDelegate:self];
        [self.player play];
        [self buttonState:stop];
    } else if ([self.delegate respondsToSelector:@selector(playOtherSound)]) {
        [self.delegate playOtherSound];
    } else {
        UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Play sound" message:@"No audio file available" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [myAlertView show];
    }

}

- (IBAction)swipeGestureRight:(UISwipeGestureRecognizer *)sender {
    [self nextButtonState:NO];
}


- (IBAction)swipeGestureLeft:(id)sender {
    [self nextButtonState:YES];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// AVAudio Player & Recorder delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void) microphoneRecorderDidFinishRecording {
    self.delegate.dataSoundRecorded = self.dataSoundRecorded;
    if ([self.delegate respondsToSelector:@selector(microphonePlayerDidFinishRecording)]) {
        [self.delegate microphonePlayerDidFinishRecording];
    }

}

- (void) audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag{
    [self buttonState:play];
}
@end
