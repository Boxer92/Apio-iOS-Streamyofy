//
//  VisualizerView.m
//  apio_streamify
//
//  Created by Matteo Pio Napolitano on 10/02/15.
//  Copyright (c) 2015 OnCreate. All rights reserved.
//  based on iPodVisualizer Created by Xinrong Guo
//

#import "VisualizerView.h"

@implementation VisualizerView {
    CAEmitterLayer *emitterLayer;
}

+ (Class)layerClass {
    return [CAEmitterLayer class];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setBackgroundColor:[UIColor clearColor]];
        emitterLayer = (CAEmitterLayer *)self.layer;
        
        CGFloat width = frame.size.width;
        CGFloat height = frame.size.height;
        emitterLayer.emitterPosition = CGPointMake(width / 2, height / 2);
        emitterLayer.emitterSize = CGSizeMake(width - 80, 60);
        emitterLayer.emitterShape = kCAEmitterLayerRectangle;
        emitterLayer.renderMode = kCAEmitterLayerAdditive;
        emitterLayer.beginTime = CACurrentMediaTime();
        
        [self setCell:0.1f];
        
        CADisplayLink *dpLink = [CADisplayLink displayLinkWithTarget:self
                                                            selector:@selector(update)];
        [dpLink addToRunLoop:[NSRunLoop currentRunLoop]
                     forMode:NSRunLoopCommonModes];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(orientationChanged:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)orientationChanged:(NSNotification *)notification {
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    self.frame = CGRectMake(0, 0, screenWidth, screenHeight);
    emitterLayer.emitterPosition = CGPointMake(screenWidth / 2, screenHeight / 2);
}

- (void)setCell:(float)rate {
    emitterLayer.hidden = YES;
    CAEmitterCell *cell = [CAEmitterCell emitterCell];
    cell.name = @"cell";
    cell.color = [[UIColor colorWithRed:1.0f green:0.83f blue:0.4f alpha:0.8f] CGColor];
    cell.redRange = 0.46f;
    cell.greenRange = 0.49f;
    cell.blueRange = 0.67f;
    cell.alphaRange = 0.55f;
    
    cell.redSpeed = 0.11f;
    cell.greenSpeed = 0.07f;
    cell.blueSpeed = -0.25f;
    cell.alphaSpeed = 0.15f;
    
    cell.scale = 0.5f;
    cell.scaleRange = 0.5f;
    
    cell.lifetime = 3.0f;
    cell.lifetimeRange = .15f;
    cell.birthRate = 3;
    
    cell.velocity = 70.0f * rate;
    cell.velocityRange = 250.0f * rate;
    cell.emissionRange = M_PI * 2 * rate;
    
    CAEmitterCell *childCell = [CAEmitterCell emitterCell];
    childCell.name = @"childCell";
    childCell.lifetime = 1.0f / 60.0f;
    childCell.birthRate = 60.0f;
    childCell.velocity = 1.4f;
    childCell.spin = 1.0f;
    childCell.spinRange = 7.0f;
    childCell.contents = (id)[[UIImage imageNamed:@"apio.png"] CGImage];
    
    cell.emitterCells = @[childCell];
    emitterLayer.emitterCells = @[cell];
    emitterLayer.hidden = NO;
}

- (void)update {
    Float32 volume;
    UInt32 dataSize_vol = sizeof(Float32);
    AudioSessionGetProperty (kAudioSessionProperty_CurrentHardwareOutputVolume, &dataSize_vol, &volume);
    
    float scale = 0.45;
    scale = scale * volume;
    if (scale > 0.45) {
        scale = 0.1;
    }
    
    [emitterLayer setValue:@(scale) forKeyPath:@"emitterCells.cell.emitterCells.childCell.scale"];
}

@end