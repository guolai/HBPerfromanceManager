//
//  HBOpenGLView.m
//  HBPerformanceManager
//
//  Created by bobo on 17/2/8.
//  Copyright © 2017年 bob. All rights reserved.
//

#import "HBOpenGLView.h"
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>
#import "HBPerformanceManager.h"

@interface HBOpenGLView ()
{
    
    CAEAGLLayer* _eaglLayer;
    EAGLContext* _context;
    GLuint _colorRenderBuffer;
}

@end

@implementation HBOpenGLView

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (void)setupLayer {
    _eaglLayer = (CAEAGLLayer*) self.layer;
    _eaglLayer.opaque = YES;
}

- (void)setupRenderBuffer {
    glGenRenderbuffers(1, &_colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
}

- (void)setupFrameBuffer {
    GLuint framebuffer;
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, _colorRenderBuffer);
}

- (void)render
{
    if ([EAGLContext currentContext] == _context)
    {
        glClearColor(1.0, 1.0, 1.0, 0.0);
        glClear(GL_COLOR_BUFFER_BIT);
        [_context presentRenderbuffer:GL_RENDERBUFFER];
    }
    else
    {
        //在其他业务使用opengl的时候，为了防止opengl的冲突，停止卡顿的检测
        [[HBPerformanceManager shareInstance] stopPerformance];
    }
}

- (void)setupContext {
    if (!_context)
    {
        EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES2;
        _context = [[EAGLContext alloc] initWithAPI:api];
        if (!_context) {
            NSLog(@"**************Failed to initialize OpenGLES 2.0 context**************");
            exit(1);
        }
    }
    if (![EAGLContext setCurrentContext:_context]) {
        NSLog(@"**************Failed to set current OpenGL context**************");
        exit(1);
    }
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupLayer];
        [self setupContext];
        [self setupRenderBuffer];
        [self setupFrameBuffer];
        [self render];
    }
    return self;
}


- (void)dealloc
{
    _context = nil;
}


@end
