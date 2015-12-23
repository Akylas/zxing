// -*- mode:objc; c-basic-offset:2; indent-tabs-mode:nil -*-
/**
 * Copyright 2009 Jeff Verkoeyen
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "ZXingWidgetController.h"
#import "Decoder.h"
#import "NSString+HTML.h"
#import "ResultParser.h"
#import "ParsedResult.h"
#import "ResultAction.h"
#import "TwoDDecoderResult.h"
#include <sys/types.h>
#include <sys/sysctl.h>

#import <AVFoundation/AVFoundation.h>

#define CAMERA_SCALAR 1.12412 // scalar = (480 / (2048 / 480))
#define FIRST_TAKE_DELAY 1.0
#define ONE_D_BAND_HEIGHT 10.0

@interface ZXingWidgetController ()

@property BOOL showCancel;
@property BOOL showLicense;
@property BOOL oneDMode;
@property BOOL isStatusBarHidden;

- (void)initCapture;
- (void)stopCapture;

@end

@implementation ZXingWidgetController

//#if HAS_AVFF
@synthesize captureSession;
//#endif
@synthesize result, delegate, soundToPlay;
@synthesize overlayView;
@synthesize preview;
@synthesize oneDMode, showCancel, showLicense, isStatusBarHidden;
@synthesize readers;
@synthesize supportedOrientationsMask;
@synthesize cropRect = _cropRect;

- (id)initWithDelegate:(id<ZXingDelegate>)scanDelegate showCancel:(BOOL)shouldShowCancel OneDMode:(BOOL)shouldUseoOneDMode {
  
    return [self initWithDelegate:scanDelegate showCancel:shouldShowCancel OneDMode:shouldUseoOneDMode showLicense:YES];
}

- (id)initWithDelegate:(id<ZXingDelegate>)scanDelegate showCancel:(BOOL)shouldShowCancel OneDMode:(BOOL)shouldUseoOneDMode showLicense:(BOOL)shouldShowLicense {
  self = [super init];
  if (self) {
    [self setDelegate:scanDelegate];
    self.oneDMode = shouldUseoOneDMode;
    self.showCancel = shouldShowCancel;
//    self.wantsFullScreenLayout = YES;
    self.showLicense = shouldShowLicense;
    beepSound = -1;
    decoding = NO;
      
    supportedOrientationsMask =
      ZXingOrientationMask(UIInterfaceOrientationPortrait);
      rotating = NO;
    OverlayView *theOverLayView = [[OverlayView alloc] initWithFrame:CGRectZero 
                                                       cancelEnabled:showCancel 
                                                            oneDMode:oneDMode
                                                         showLicense:shouldShowLicense];
    ZxingPreview* theCaptureView = [[ZxingPreview alloc] initWithFrame:CGRectZero];
    self.preview = theCaptureView;

    [theCaptureView release];
      
    [theOverLayView setDelegate:self];
    self.overlayView = theOverLayView;
    [theOverLayView release];
      
      //    self.captureView.backgroundColor = [UIColor redColor];
      //    [self.view addSubview:captureView];
      //    captureView.frame = self.view.bounds;
      //    
      //    self.overlayView.backgroundColor = [UIColor clearColor];
      //    [self.view addSubview:overlayView];
      //    overlayView.frame = self.view.bounds;

  }
  
  return self;
}

- (void)dealloc {
  if (beepSound != (SystemSoundID)-1) {
    AudioServicesDisposeSystemSoundID(beepSound);
  }
  
  [self stopCapture];

  [result release];
  [soundToPlay release];
    [overlayView release];
    [preview release];
  [readers release];
  [super dealloc];
}

- (void)cancelled {
  [self stopCapture];
//  if (!self.isStatusBarHidden) {
//    [[UIApplication sharedApplication] setStatusBarHidden:NO];
//  }

  wasCancelled = YES;
  if (delegate != nil) {
    [delegate zxingControllerDidCancel:self];
  }
}

- (NSString *)getPlatform {
  size_t size;
  sysctlbyname("hw.machine", NULL, &size, NULL, 0);
  char *machine = malloc(size);
  sysctlbyname("hw.machine", machine, &size, NULL, 0);
  NSString *platform = [NSString stringWithCString:machine encoding:NSASCIIStringEncoding];
  free(machine);
  return platform;
}

- (BOOL)fixedFocus {
  NSString *platform = [self getPlatform];
  if ([platform isEqualToString:@"iPhone1,1"] ||
      [platform isEqualToString:@"iPhone1,2"]) return YES;
  return NO;
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    self.view.autoresizingMask = self.preview.autoresizingMask = self.overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    preview.frame = self.view.bounds;
    [self.view addSubview:preview];
    overlayView.frame = self.view.bounds;
    [self.view addSubview:overlayView];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
//  self.wantsFullScreenLayout = YES;
  if ([self soundToPlay] != nil) {
    OSStatus error = AudioServicesCreateSystemSoundID((CFURLRef)[self soundToPlay], &beepSound);
    if (error != kAudioServicesNoError) {
      DLog(@"Problem loading nearSound.caf");
    }
  }
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
//  self.isStatusBarHidden = [[UIApplication sharedApplication] isStatusBarHidden];
//  if (!isStatusBarHidden)
//    [[UIApplication sharedApplication] setStatusBarHidden:YES];

    decoding = YES;

//    self.captureView.backgroundColor = [UIColor redColor];
//    self.captureView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
//    [self.view addSubview:captureView];
//    captureView.frame = self.view.bounds;
//    
//    self.overlayView.backgroundColor = [UIColor clearColor];
//    self.overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
//    [self.view addSubview:overlayView];
//    overlayView.frame = self.view.bounds;
 
    [self initCapture];
    
    [overlayView setPoints:nil];
    wasCancelled = NO;
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
//  if (!isStatusBarHidden)
//    [[UIApplication sharedApplication] setStatusBarHidden:NO];
//    [self.preview removeFromSuperview];
//    [self.overlayView removeFromSuperview];
  [self stopCapture];
}

//- (BOOL) shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation) orient
//{
//    return YES;
//}

- (void) willRotateToInterfaceOrientation: (UIInterfaceOrientation) orient
                                 duration: (NSTimeInterval) duration
{
#ifdef DEBUG
    DLog(@"willRotate: orient=%d #%g", orient, duration);
#endif
    rotating = YES;
    if(preview)
        [preview willRotateToInterfaceOrientation: orient
                                            duration: duration];
}

- (void) willAnimateRotationToInterfaceOrientation: (UIInterfaceOrientation) orient
                                          duration: (NSTimeInterval) duration
{
#ifdef DEBUG
    DLog(@"willAnimateRotation: orient=%d #%g", orient, duration);
#endif
    if(preview)
        [preview setNeedsLayout];
    if(overlayView)
        [overlayView setNeedsLayout];
}


// utility routing used during image capture to set up capture orientation
- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation
{
    AVCaptureVideoOrientation videoRot = deviceOrientation;
    if ( deviceOrientation == UIDeviceOrientationLandscapeLeft )
        videoRot = AVCaptureVideoOrientationLandscapeRight;
    else if ( deviceOrientation == UIDeviceOrientationLandscapeRight )
        videoRot = AVCaptureVideoOrientationLandscapeLeft;
    return videoRot;
}

- (void) didRotateFromInterfaceOrientation: (UIInterfaceOrientation) orient
{
#ifdef DEBUG
    DLog(@"didRotate(%d): orient=%d", rotating, orient);
#endif
    if(!rotating && preview) {
        // work around UITabBarController bug: willRotate is not called
        // for non-portrait initial interface orientation
        [preview willRotateToInterfaceOrientation: self.interfaceOrientation
                                            duration: 0];
        [preview setNeedsLayout];
    }
    if(overlayView)
        [overlayView setNeedsLayout];
    rotating = NO;
    [self.preview.prevLayer setOrientation:[self avOrientationForDeviceOrientation:orient] ];
}

- (CGImageRef)CGImageRotated90:(CGImageRef)imgRef
{
  CGFloat angleInRadians = -90 * (M_PI / 180);
  CGFloat width = CGImageGetWidth(imgRef);
  CGFloat height = CGImageGetHeight(imgRef);
  
  CGRect imgRect = CGRectMake(0, 0, width, height);
  CGAffineTransform transform = CGAffineTransformMakeRotation(angleInRadians);
  CGRect rotatedRect = CGRectApplyAffineTransform(imgRect, transform);
  
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef bmContext = CGBitmapContextCreate(NULL,
                                                 rotatedRect.size.width,
                                                 rotatedRect.size.height,
                                                 8,
                                                 0,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedFirst);
  CGContextSetAllowsAntialiasing(bmContext, FALSE);
  CGContextSetInterpolationQuality(bmContext, kCGInterpolationNone);
  CGColorSpaceRelease(colorSpace);
  //      CGContextTranslateCTM(bmContext,
  //                                                +(rotatedRect.size.width/2),
  //                                                +(rotatedRect.size.height/2));
  CGContextScaleCTM(bmContext, rotatedRect.size.width/rotatedRect.size.height, 1.0);
  CGContextTranslateCTM(bmContext, 0.0, rotatedRect.size.height);
  CGContextRotateCTM(bmContext, angleInRadians);
  //      CGContextTranslateCTM(bmContext,
  //                                                -(rotatedRect.size.width/2),
  //                                                -(rotatedRect.size.height/2));
  CGContextDrawImage(bmContext, CGRectMake(0, 0,
                                           rotatedRect.size.width,
                                           rotatedRect.size.height),
                     imgRef);
  
  CGImageRef rotatedImage = CGBitmapContextCreateImage(bmContext);
  CFRelease(bmContext);
  [(id)rotatedImage autorelease];
  
  return rotatedImage;
}

- (CGImageRef)CGImageRotated180:(CGImageRef)imgRef
{
  CGFloat angleInRadians = M_PI;
  CGFloat width = CGImageGetWidth(imgRef);
  CGFloat height = CGImageGetHeight(imgRef);
  
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef bmContext = CGBitmapContextCreate(NULL,
                                                 width,
                                                 height,
                                                 8,
                                                 0,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedFirst);
  CGContextSetAllowsAntialiasing(bmContext, FALSE);
  CGContextSetInterpolationQuality(bmContext, kCGInterpolationNone);
  CGColorSpaceRelease(colorSpace);
  CGContextTranslateCTM(bmContext,
                        +(width/2),
                        +(height/2));
  CGContextRotateCTM(bmContext, angleInRadians);
  CGContextTranslateCTM(bmContext,
                        -(width/2),
                        -(height/2));
  CGContextDrawImage(bmContext, CGRectMake(0, 0, width, height), imgRef);
  
  CGImageRef rotatedImage = CGBitmapContextCreateImage(bmContext);
  CFRelease(bmContext);
  [(id)rotatedImage autorelease];
  
  return rotatedImage;
}

// DecoderDelegate methods

- (void)decoder:(Decoder *)decoder willDecodeImage:(UIImage *)image usingSubset:(UIImage *)subset{
#ifdef ZXING_DEBUG
  DLog(@"DecoderViewController MessageWhileDecodingWithDimensions: Decoding image (%.0fx%.0f) ...", image.size.width, image.size.height);
#endif
}

- (void)decoder:(Decoder *)decoder
  decodingImage:(UIImage *)image
     usingSubset:(UIImage *)subset {
}

- (void)presentResultForString:(NSString *)resultString {
  self.result = [ResultParser parsedResultForString:resultString];
  if (beepSound != (SystemSoundID)-1) {
    AudioServicesPlaySystemSound(beepSound);
  }
#ifdef ZXING_DEBUG
  DLog(@"result string = %@", resultString);
#endif
}

- (void)presentResultPoints:(NSArray *)resultPoints
                   forImage:(UIImage *)image
                usingSubset:(UIImage *)subset {
  // simply add the points to the image view
  NSMutableArray *mutableArray = [[NSMutableArray alloc] initWithArray:resultPoints];
  [overlayView setPoints:mutableArray];
  [mutableArray release];
}

- (void)decoder:(Decoder *)decoder didDecodeImage:(UIImage *)image usingSubset:(UIImage *)subset withResult:(TwoDDecoderResult *)twoDResult {
  [self presentResultForString:[twoDResult text]];
  [self presentResultPoints:[twoDResult points] forImage:image usingSubset:subset];
  // now, in a selector, call the delegate to give this overlay time to show the points
  [self performSelector:@selector(notifyDelegate:) withObject:[twoDResult text] afterDelay:0.0];
  decoder.delegate = nil;
}

- (void)notifyDelegate:(id)text {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
//  if (!isStatusBarHidden) [[UIApplication sharedApplication] setStatusBarHidden:NO];
  [delegate zxingController:self didScanResult:text];
    [pool release];
}

- (void)decoder:(Decoder *)decoder failedToDecodeImage:(UIImage *)image usingSubset:(UIImage *)subset reason:(NSString *)reason {
  decoder.delegate = nil;
  [overlayView setPoints:nil];
}

- (void)decoder:(Decoder *)decoder foundPossibleResultPoint:(CGPoint)point {
  [overlayView setPoint:point];
}

/*
- (void)stopPreview:(NSNotification*)notification {
  // DLog(@"stop preview");
}

- (void)notification:(NSNotification*)notification {
  // DLog(@"notification %@", notification.name);
}
*/

-(void)setCropRect:(CGRect)cropRect {
    _cropRect = cropRect;
    overlayView.cropRect = _cropRect;
}

#pragma mark - 
#pragma mark AVFoundation

#include <sys/types.h>
#include <sys/sysctl.h>

// Gross, I know. But you can't use the device idiom because it's not iPad when running
// in zoomed iphone mode but the camera still acts like an ipad.
#if HAS_AVFF
static bool isIPad() {
  static int is_ipad = -1;
  if (is_ipad < 0) {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0); // Get size of data to be returned.
    char *name = malloc(size);
    sysctlbyname("hw.machine", name, &size, NULL, 0);
    NSString *machine = [NSString stringWithCString:name encoding:NSASCIIStringEncoding];
    free(name);
    is_ipad = [machine hasPrefix:@"iPad"];
  }
  return !!is_ipad;
}
#endif
    
- (void)initCapture {
#if HAS_AVFF
  AVCaptureDevice* inputDevice =
    [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
  AVCaptureDeviceInput *captureInput =
    [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:nil];
  AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init]; 
  captureOutput.alwaysDiscardsLateVideoFrames = YES; 
  [captureOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
  NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey; 
  NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
  NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key]; 
  [captureOutput setVideoSettings:videoSettings]; 
  self.captureSession = [[[AVCaptureSession alloc] init] autorelease];

  NSString* preset = 0;
  if (NSClassFromString(@"NSOrderedSet") && // Proxy for "is this iOS 5" ...
      [UIScreen mainScreen].scale > 1 &&
      isIPad() && 
      [inputDevice
        supportsAVCaptureSessionPreset:AVCaptureSessionPresetiFrame960x540]) {
    // DLog(@"960");
    preset = AVCaptureSessionPresetiFrame960x540;
  }
  if (!preset) {
    // DLog(@"MED");
    preset = AVCaptureSessionPresetMedium;
  }
  self.captureSession.sessionPreset = preset;

  [self.captureSession addInput:captureInput];
  [self.captureSession addOutput:captureOutput];

  [captureOutput release];

/*
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(stopPreview:)
             name:AVCaptureSessionDidStopRunningNotification
           object:self.captureSession];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(notification:)
             name:AVCaptureSessionDidStopRunningNotification
           object:self.captureSession];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(notification:)
             name:AVCaptureSessionRuntimeErrorNotification
           object:self.captureSession];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(notification:)
             name:AVCaptureSessionDidStartRunningNotification
           object:self.captureSession];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(notification:)
             name:AVCaptureSessionWasInterruptedNotification
           object:self.captureSession];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(notification:)
             name:AVCaptureSessionInterruptionEndedNotification
           object:self.captureSession];
*/

  if (!self.preview.prevLayer) {
    self.preview.prevLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
  }

  [self.captureSession startRunning];
#endif
}

#if HAS_AVFF
- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
       fromConnection:(AVCaptureConnection *)connection 
{ 
  if (!decoding) {
    return;
  }
  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer); 
  /*Lock the image buffer*/
  CVPixelBufferLockBaseAddress(imageBuffer,0); 
  /*Get information about the image*/
  size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer); 
  size_t width = CVPixelBufferGetWidth(imageBuffer); 
  size_t height = CVPixelBufferGetHeight(imageBuffer); 
    
  uint8_t* baseAddress = CVPixelBufferGetBaseAddress(imageBuffer); 
  void* free_me = 0;
  if (true) { // iOS bug?
    uint8_t* tmp = baseAddress;
    int bytes = bytesPerRow*height;
    free_me = baseAddress = (uint8_t*)malloc(bytes);
    baseAddress[0] = 0xdb;
    memcpy(baseAddress,tmp,bytes);
  }

  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
  CGContextRef newContext =
    CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace,
                          kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst); 

  CGImageRef capture = CGBitmapContextCreateImage(newContext); 
//    [(id)capture autorelease];
  CVPixelBufferUnlockBaseAddress(imageBuffer,0);
  free(free_me);

  CGContextRelease(newContext); 
  CGColorSpaceRelease(colorSpace);

    
  CGRect cropRect = [overlayView cropRect];
  if (oneDMode) {
    // let's just give the decoder a vertical band right above the red line
    cropRect.origin.x = cropRect.origin.x + (cropRect.size.width / 2) - (ONE_D_BAND_HEIGHT + 1);
    cropRect.size.width = ONE_D_BAND_HEIGHT;
    // do a rotate
    CGImageRef croppedImg = CGImageCreateWithImageInRect(capture, cropRect);
    CGImageRelease(capture);
    capture = [self CGImageRotated90:croppedImg];
    capture = [self CGImageRotated180:capture];
    //              UIImageWriteToSavedPhotosAlbum([UIImage imageWithCGImage:capture], nil, nil, nil);
    CGImageRelease(croppedImg);
    CGImageRetain(capture);
    cropRect.origin.x = 0.0;
    cropRect.origin.y = 0.0;
    cropRect.size.width = CGImageGetWidth(capture);
    cropRect.size.height = CGImageGetHeight(capture);
  }

  // N.B.
  // - Won't work if the overlay becomes uncentered ...
  // - iOS always takes videos in landscape
  // - images are always 4x3; device is not
  // - iOS uses virtual pixels for non-image stuff

  {
    float height = CGImageGetHeight(capture);
    float width = CGImageGetWidth(capture);

    CGRect screen = UIScreen.mainScreen.bounds;
    float tmp = screen.size.width;
    screen.size.width = screen.size.height;;
    screen.size.height = tmp;

    cropRect.origin.x = (width-cropRect.size.width)/2;
    cropRect.origin.y = (height-cropRect.size.height)/2;
  }
  CGImageRef newImage = CGImageCreateWithImageInRect(capture, cropRect);
  CGImageRelease(capture);
  UIImage *scrn = [[UIImage alloc] initWithCGImage:newImage];
  CGImageRelease(newImage);
  Decoder *d = [[Decoder alloc] init];
  d.readers = readers;
  d.delegate = self;
  cropRect.origin.x = 0.0;  
  cropRect.origin.y = 0.0;
  decoding = [d decodeImage:scrn cropRect:cropRect] == YES ? NO : YES;
  [d release];
  [scrn release];
} 
#endif

- (void)stopCapture {
  decoding = NO;
#if HAS_AVFF
  [captureSession stopRunning];
  AVCaptureInput* input = [captureSession.inputs objectAtIndex:0];
  [captureSession removeInput:input];
  AVCaptureVideoDataOutput* output = (AVCaptureVideoDataOutput*)[captureSession.outputs objectAtIndex:0];
  [captureSession removeOutput:output];
[self.preview.prevLayer removeFromSuperlayer];

/*
  // heebee jeebees here ... is iOS still writing into the layer?
  if (self.prevLayer) {
    layer.session = nil;
    AVCaptureVideoPreviewLayer* layer = prevLayer;
    [self.prevLayer retain];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 12000000000), dispatch_get_main_queue(), ^{
        [layer release];
    });
  }
*/

  self.preview.prevLayer = nil;
  self.captureSession = nil;
#endif
}

#pragma mark - Torch

- (void)setTorch:(BOOL)status {
#if HAS_AVFF
  Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
  if (captureDeviceClass != nil) {
    
    AVCaptureDevice *device = [captureDeviceClass defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    [device lockForConfiguration:nil];
    if ( [device hasTorch] ) {
      if ( status ) {
        [device setTorchMode:AVCaptureTorchModeOn];
      } else {
        [device setTorchMode:AVCaptureTorchModeOff];
      }
    }
    [device unlockForConfiguration];
    
  }
#endif
}

- (BOOL)torchIsOn {
#if HAS_AVFF
  Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
  if (captureDeviceClass != nil) {
    
    AVCaptureDevice *device = [captureDeviceClass defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    if ( [device hasTorch] ) {
      return [device torchMode] == AVCaptureTorchModeOn;
    }
    [device unlockForConfiguration];
  }
#endif
  return NO;
}

@end
