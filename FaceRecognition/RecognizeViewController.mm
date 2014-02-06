//
//  RecognizeViewController.mm
//  FaceRecognition
//
//  Created by Michael Peterson on 2012-11-16.
//
//

#import <MediaPlayer/MediaPlayer.h>

#import "RecognizeViewController.h"
#import "OpenCVData.h"


#define CAPTURE_FPS 30


@interface RecognizeViewController ()
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, assign) BOOL  hasFace;
- (IBAction)switchCameraClicked:(id)sender;
@end

@implementation RecognizeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    self.faceDetector = [[FaceDetector alloc] init];
    self.faceRecognizer = [[CustomFaceRecognizer alloc] initWithEigenFaceRecognizer];
    
    [self setupCamera];
    
    self.view.backgroundColor = [UIColor blueColor];
    
    BOOL isLandscape = UIInterfaceOrientationIsLandscape(self.interfaceOrientation);
    CGFloat width = isLandscape?CGRectGetHeight(self.view.bounds):CGRectGetWidth(self.view.bounds);
    CGFloat height = isLandscape?CGRectGetWidth(self.view.bounds):CGRectGetHeight(self.view.bounds);
    _webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    _webView.backgroundColor = [UIColor groupTableViewBackgroundColor];
    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.google.com"]]];
    [_webView.scrollView setContentInset:UIEdgeInsetsMake(20, 0, 0, 0)];
    [self.view addSubview:_webView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Re-train the model in case more pictures were added
    self.modelAvailable = [self.faceRecognizer trainModel];
    
    if (!self.modelAvailable) {
        self.instructionLabel.text = @"Add people in the database first";
    }
    
    [self.videoCamera start];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.videoCamera stop];
}

- (void)setupCamera
{
    self.videoCamera = [[CvVideoCamera alloc] initWithParentView:nil];//self.imageView
    self.videoCamera.delegate = self;
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionFront;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset352x288;
    AVCaptureVideoOrientation orientation = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad?
    AVCaptureVideoOrientationLandscapeRight:AVCaptureVideoOrientationPortrait;
    self.videoCamera.defaultAVCaptureVideoOrientation = orientation;
    self.videoCamera.defaultFPS = CAPTURE_FPS;
    self.videoCamera.grayscaleMode = NO;
}

- (void)processImage:(cv::Mat&)image
{
    // Only process every CAPTURE_FPS'th frame (every 1s)
    if (self.frameNum == CAPTURE_FPS) {
        [self parseFaces:[self.faceDetector facesFromImage:image] forImage:image];
        self.frameNum = 0;
    }
    
    self.frameNum++;
}

- (void)parseFaces:(const std::vector<cv::Rect> &)faces forImage:(cv::Mat&)image
{
    // No faces found
    dispatch_sync(dispatch_get_main_queue(), ^{
        if (!faces.size()) {
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && _hasFace) {
                _hasFace = NO;
                [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.google.com"]]];
            }
            return;
        }
        
        if (!_hasFace) {
            [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.yahoo.com"]]];
            _hasFace = YES;
        }
    });
    
    return;
    
    // We only care about the first face
    cv::Rect face = faces[0];
    
    // By default highlight the face in red, no match found
    CGColor *highlightColor = [[UIColor redColor] CGColor];
    NSString *message = @"No match found";
    NSString *confidence = @"";
    
    // Unless the database is empty, try a match
    if (self.modelAvailable) {
        NSDictionary *match = [self.faceRecognizer recognizeFace:face inImage:image];
        
        // Match found
        if ([match objectForKey:@"personID"] != [NSNumber numberWithInt:-1]) {
            message = [match objectForKey:@"personName"];
            highlightColor = [[UIColor greenColor] CGColor];
            
            NSNumberFormatter *confidenceFormatter = [[NSNumberFormatter alloc] init];
            [confidenceFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
            confidenceFormatter.maximumFractionDigits = 2;
            
            confidence = [NSString stringWithFormat:@"Confidence: %@",
                          [confidenceFormatter stringFromNumber:[match objectForKey:@"confidence"]]];
        }
    }
    
    // All changes to the UI have to happen on the main thread
    dispatch_sync(dispatch_get_main_queue(), ^{
        self.instructionLabel.text = message;
        self.confidenceLabel.text = confidence;
        [self highlightFace:[OpenCVData faceToCGRect:face] withColor:highlightColor];
    });
}

- (void)noFaceToDisplay
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        self.instructionLabel.text = @"No face in image";
        self.confidenceLabel.text = @"";
        self.featureLayer.hidden = YES;
    });
}

- (void)highlightFace:(CGRect)faceRect withColor:(CGColor *)color
{
    if (self.featureLayer == nil) {
        self.featureLayer = [[CALayer alloc] init];
        self.featureLayer.borderWidth = 4.0;
    }
    
    [self.imageView.layer addSublayer:self.featureLayer];
    
    self.featureLayer.hidden = NO;
    self.featureLayer.borderColor = color;
    self.featureLayer.frame = faceRect;
}

- (IBAction)switchCameraClicked:(id)sender {
    [self.videoCamera stop];
    
    if (self.videoCamera.defaultAVCaptureDevicePosition == AVCaptureDevicePositionFront) {
        self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    } else {
        self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionFront;
    }
    
    [self.videoCamera start];
}

@end
