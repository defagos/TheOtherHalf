//
//  PhotoViewController.m
//  theotherhalf
//
//  Created by Joris Heuberger on 11.02.14.
//  Copyright (c) 2014 The Other Half. All rights reserved.
//

#import "PhotoViewController.h"

CGRect rectCenteredInRect(CGRect rect, CGRect mainRect)
{
	return CGRectOffset(rect, CGRectGetMidX(mainRect)-CGRectGetMidX(rect), CGRectGetMidY(mainRect)-CGRectGetMidY(rect));
}

@interface PhotoViewController ()

@property (nonatomic, weak) IBOutlet UIView *buttonsPlaceholderView;
@property (nonatomic, weak) IBOutlet UIView *photoView;
@property (nonatomic, weak) IBOutlet UIView *photoButtonsView;
@property (nonatomic, weak) IBOutlet UIButton *takePhotoButton;
@property (nonatomic, weak) IBOutlet UIButton *choosePhotoButton;
@property (nonatomic, weak) IBOutlet UIView *sharingButtonsView;

@property (nonatomic, weak) CALayer *imageSublayer;

@end

@implementation PhotoViewController {
    CATransform3D _initialTransform;                    // Initial transform when a gesture begins
    CGPoint _currentTranslation;
    CGFloat _currentScale;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (! [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        self.takePhotoButton.hidden = YES;
    }
    if (! [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        self.choosePhotoButton.hidden = YES;
    }
    
    // Insert image as sublayer so that we can move and scale it while the main parent view stays the same
    CALayer *imageSublayer = [CALayer layer];
    imageSublayer.frame = self.photoView.bounds;
    imageSublayer.contents = (__bridge id)[UIImage imageWithColor:[UIColor colorWithNonNormalizedRed:38.f green:41.f blue:39.f alpha:1.f]].CGImage;
    [self.photoView.layer addSublayer:imageSublayer];
    self.imageSublayer = imageSublayer;
    
    // Apply mask to the parent view
	NSString *maskName = [NSString stringWithFormat:@"mask-%@.png", [NSBundle localization]];
	UIImage *maskImage = [UIImage imageNamed:maskName];
    CALayer *maskLayer = [CALayer layer];
    maskLayer.frame = self.photoView.bounds;
    maskLayer.contents = (id)maskImage.CGImage;
    self.photoView.layer.mask = maskLayer;
    
    // Gesture recognizers. Meant to move the image sublayer
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panImage:)];
    panGestureRecognizer.delegate = self;
    [self.photoView addGestureRecognizer:panGestureRecognizer];
    
    UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchImage:)];
    pinchGestureRecognizer.delegate = self;
    [self.photoView addGestureRecognizer:pinchGestureRecognizer];
	
	// Action buttons
	[self.buttonsPlaceholderView addSubview:self.photoButtonsView];
	[self.buttonsPlaceholderView addSubview:self.sharingButtonsView];
	self.sharingButtonsView.hidden = YES;
}

#pragma mark Helpers

- (void)displayImagePickerWithSourceType:(UIImagePickerControllerSourceType)sourceType
{
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.sourceType = sourceType;
    imagePickerController.delegate = self;
    [self presentViewController:imagePickerController animated:YES completion:nil];
}

- (void)updateImage
{
    CATransform3D currentTranslationTransform = CATransform3DMakeTranslation(_currentTranslation.x, _currentTranslation.y, 0.f);
    CATransform3D currentScaleTransform = CATransform3DMakeScale(_currentScale, _currentScale, 1.f);
    
    CATransform3D currentTransform = CATransform3DConcat(currentScaleTransform, currentTranslationTransform);
    self.imageSublayer.transform = CATransform3DConcat(_initialTransform, currentTransform);
}

#pragma mark UIGestureRecognizerDelegate protocol implementation

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    _initialTransform = self.imageSublayer.transform;
    
    _currentTranslation = CGPointZero;
    _currentScale = 1.f;
    
    return YES;
}

#pragma mark UIImagePickerControllerDelegate protocol implementation

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
	
	CGRect viewBounds = self.photoView.bounds;
	CGSize imageSize = image.size;
	CGFloat scale = (imageSize.height>imageSize.width) ? CGRectGetHeight(viewBounds)/imageSize.height : CGRectGetWidth(viewBounds)/imageSize.width;
	CGRect frame = CGRectMake(0.0, 0.0, imageSize.width * scale, imageSize.height * scale);
	frame = rectCenteredInRect(frame, viewBounds);
	
	self.imageSublayer.transform = CATransform3DIdentity;
	self.imageSublayer.frame = frame;
    self.imageSublayer.contents = (__bridge id)image.CGImage;
	
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark Actions

- (IBAction)goToWebSite:(id)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.theotherhalf.ch"]];
}

- (IBAction)changeLanguage:(id)sender
{
    [self.stackController popToRootViewControllerAnimated:YES];
}

- (IBAction)takePhoto:(id)sender
{
    [self displayImagePickerWithSourceType:UIImagePickerControllerSourceTypeCamera];
}

- (IBAction)choosePhoto:(id)sender
{
    [self displayImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
}

- (IBAction)validate:(id)sender
{
	self.sharingButtonsView.hidden = NO;
	self.photoButtonsView.hidden = YES;
}

- (IBAction)shareOnFacebook:(id)sender
{
}

- (IBAction)shareOnTwitter:(id)sender
{
}

- (IBAction)saveToCameraRoll:(id)sender
{
	// create a CG context
	UIGraphicsBeginImageContextWithOptions(self.photoView.bounds.size, NO, [UIScreen mainScreen].scale);
	
	// render into the new context
	[self.photoView.layer renderInContext:UIGraphicsGetCurrentContext()];
	
	// get the image out of the context
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
}

#pragma mark Gesture recognizers

- (void)panImage:(UIPanGestureRecognizer *)panGestureRecognizer
{
    _currentTranslation = [panGestureRecognizer translationInView:panGestureRecognizer.view];
    [self updateImage];
}

- (void)pinchImage:(UIPinchGestureRecognizer *)pinchGestureRecognizer
{
    _currentScale = pinchGestureRecognizer.scale;
    [self updateImage];
}

@end
