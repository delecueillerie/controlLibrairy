//
//  MIMicrophoneUI.m
//  microphone
//
//  Created by Olivier Delecueillerie on 31/03/2014.
//  Copyright (c) 2014 Olivier Delecueillerie. All rights reserved.
//

#import "MIMicrophoneUI.h"

@interface MIMicrophoneUI ()
@property (strong, nonatomic) FDSoundActivatedRecorder *activatedRecorder;
@property (weak, nonatomic) IBOutlet UIView *viewBackgroundColor;
@property (weak, nonatomic) IBOutlet UIImageView *viewMicrophoneImage;
@end

@implementation MIMicrophoneUI



- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.activatedRecorder = [[FDSoundActivatedRecorder alloc] init];

    self.activatedRecorder.delegate = self;
    [self.activatedRecorder startListening];
}


- (IBAction)controlCancel:(id)sender {
[[self presentingViewController] dismissViewControllerAnimated:YES completion:^{
    //<#code#>
}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// FDSoundActivatedRecorderDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void) soundActivatedRecorderDidStopRecording:(FDSoundActivatedRecorder *)recorder andSavedSound:(BOOL)didSave {
    //put the file in NSData object
    self.delegate.dataSoundRecorded = [NSData dataWithContentsOfURL:self.activatedRecorder.trimmedRecordUrl];
    [self.delegate microphoneRecorderDidFinishRecording];
    [[self presentingViewController] dismissViewControllerAnimated:YES completion:^{
        //<#code#>
    }];
}

- (void) soundActivatedRecorderMicrophoneLevelGauge:(float)microphoneLevel {    
    self.viewBackgroundColor.frame = CGRectMake(self.viewMicrophoneImage.frame.origin.x,
                                                (self.viewMicrophoneImage.frame.origin.y)+((1-microphoneLevel)*self.viewMicrophoneImage.frame.size.height),
                                                self.viewMicrophoneImage.frame.size.width,
                                                (self.viewMicrophoneImage.bounds.size.height * microphoneLevel));

}
@end
