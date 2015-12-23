//
//  ZxingPreview.m
//  IziPass
//
//  Created by Martin Guillon on 1/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ZxingPreview.h"

@implementation ZxingPreview
@synthesize prevLayer = _prevLayer;
@synthesize previewTransform;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    }
    return self;
}

static inline CGFloat rotationForInterfaceOrientation (int orient)
{
    // resolve camera/device image orientation to view/interface orientation
    switch(orient)
    {
        case UIInterfaceOrientationLandscapeLeft:
            return(M_PI_2);
        case UIInterfaceOrientationPortraitUpsideDown:
            return(M_PI);
        case UIInterfaceOrientationLandscapeRight:
            return(3 * M_PI_2);
        case UIInterfaceOrientationPortrait:
            return(2 * M_PI);
    }
    return(0);
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    if(!bounds.size.width || !bounds.size.height)
        return;
    
    // orient view bounds to match camera image
    CGSize psize;
    if(UIInterfaceOrientationIsPortrait(interfaceOrientation))
        psize = CGSizeMake(bounds.size.height, bounds.size.width);
    else
        psize = bounds.size;
    
    //    BOOL sameOrient = ((UIInterfaceOrientationIsPortrait(toInterfaceOrientation) && UIInterfaceOrientationIsPortrait(_oldOrientation))
    //                        || (UIInterfaceOrientationIsLandscape(toInterfaceOrientation) && UIInterfaceOrientationIsLandscape(_oldOrientation)));
    //    CGAffineTransform transform;
    //    switch (toInterfaceOrientation) {
    //        case UIInterfaceOrientationPortrait:
    //            transform = CGAffineTransformIdentity;
    //            break;
    //        case UIInterfaceOrientationLandscapeLeft:
    //            transform = CGAffineTransformMakeRotation(M_PI_2);
    //            break;
    //        case UIInterfaceOrientationPortraitUpsideDown:
    //            transform = CGAffineTransformMakeRotation(M_PI);
    //            break;
    //        case UIInterfaceOrientationLandscapeRight:
    //            transform = CGAffineTransformMakeRotation(3*M_PI_2);
    //            break;
    //    }
    [CATransaction begin];
    if (animationDuration)
    {
        [CATransaction setAnimationDuration: animationDuration];
        [CATransaction setAnimationTimingFunction:
         [CAMediaTimingFunction functionWithName:
          kCAMediaTimingFunctionEaseInEaseOut]];
    }
    else
        [CATransaction setDisableActions: YES];
    
    self.prevLayer.bounds = CGRectMake(0, 0, psize.height, psize.width);
    // center preview in view
    self.prevLayer.position = CGPointMake(bounds.size.width / 2,
                                          bounds.size.height / 2);
    
    CGFloat angle = rotationForInterfaceOrientation(interfaceOrientation);
    CATransform3D xform =
    CATransform3DMakeAffineTransform(previewTransform);
    self.prevLayer.transform = CATransform3DRotate(xform, angle, 0, 0, 1);
    //    self.captureView.transform = transform;
    //    if (!sameOrient)
    //        self.captureView.center = CGPointMake (self.view.bounds.size.height / 2, self.view.bounds.size.width/ 2);
    //    if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
    //        self.overlayView.transform = transform;
    
    [CATransaction commit];
    animationDuration = 0;
}
/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

-(void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    if (_prevLayer) {
        CGRect bounds = self.bounds;
        bounds.origin = CGPointZero;
        self.prevLayer.bounds = bounds;
        self.prevLayer.position = CGPointMake(bounds.size.width / 2,
                                              bounds.size.height / 2);
    }
    [self setNeedsLayout];
}

- (void) setPreviewTransform: (CGAffineTransform) xfrm
{
    previewTransform = xfrm;
    [self setNeedsLayout];
}

-(void)setPrevLayer:(AVCaptureVideoPreviewLayer *)prevLayer
{
    if (_prevLayer) {
        [_prevLayer removeFromSuperlayer];
        [_prevLayer release];
    }
    previewTransform = CGAffineTransformIdentity;
    _prevLayer = [prevLayer retain];
    CGRect bounds = self.bounds;
    bounds.origin = CGPointZero;
   self.prevLayer.bounds = bounds;
    self.prevLayer.position = CGPointMake(bounds.size.width / 2,
                                          bounds.size.height / 2);
    self.prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.layer addSublayer: self.prevLayer];
    [self setNeedsLayout];
}

- (void) willRotateToInterfaceOrientation: (UIInterfaceOrientation) orient
                                 duration: (NSTimeInterval) duration
{
    if(interfaceOrientation != orient) {
#ifdef DEBUG
        DLog(@"orient=%d #%g", orient, duration);
#endif
        interfaceOrientation = orient;
        animationDuration = duration;
    }
}

@end
