//
//  NSSANEDecoder.m
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 28/11/2021.
//

#import "NSSANEDecoder.h"
#import "NSSUtility.h"

const NSString* kConversionFunctionName = @"decode_buffer";
const NSString* kConversionWithYuvFunctionName = @"decode_buffer_yuv";

@implementation NSSANEDecoder {
    id<MTLDevice> device;
    id<MTLComputePipelineState> pipeline;
    id<MTLBuffer> inputBuffer;
    id<MTLBuffer> strideBuffer;
}

- (id)initWithDevice:(id<MTLDevice>)device yuvToRgbConversion:(BOOL)yuvConversion {
    self = [super init];
    if (self) {
        self->device = device;
        
        NSError* error = nil;
        NSBundle* bundle = [NSBundle bundleForClass: [self class]];
        id<MTLLibrary> library = [device newDefaultLibraryWithBundle:bundle
                                                               error:&error];
        RAISE_EXCEPTION_ON_ERROR(error, @"MetalLibraryNotFound");
        
        id<MTLFunction> conversionFunction;
        if (yuvConversion) {
            conversionFunction = [library newFunctionWithName:kConversionWithYuvFunctionName];
        } else {
            conversionFunction = [library newFunctionWithName:kConversionFunctionName];
        }
        self->pipeline = [device newComputePipelineStateWithFunction:conversionFunction error:&error];
        RAISE_EXCEPTION_ON_ERROR(error, @"MetalLibraryPipelineStateError");
    }
    
    return self;
}

- (void)attachBuffer:(NSSBuffer*)buffer {
    inputBuffer = [device newBufferWithBytesNoCopy:buffer.dataPointer
                                                  length:buffer.length
                                                 options:MTLResourceStorageModeShared
                                             deallocator:nil];
    size_t pixelStride = buffer.pixelStride;
    strideBuffer = [device newBufferWithBytes:&pixelStride
                                       length:sizeof(size_t)
                                      options:MTLResourceStorageModePrivate];
}

- (void)decodeIntoTexture:(id<MTLTexture>)texture usingCommandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    if (inputBuffer == nil || strideBuffer == nil) {
        RAISE_EXCEPTION(@"AttachNotCalled");
    }
    
    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    if (commandEncoder == nil) {
        return;
    }
    
    MTLSize gridSize = MTLSizeMake(texture.width, texture.height, 1);
    MTLSize threadgroup = [self calculateThreadsPerThreadgroupForPipelineState:pipeline];
    
    [commandEncoder setComputePipelineState:pipeline];
    [commandEncoder setBuffer:inputBuffer offset:0 atIndex:0];
    [commandEncoder setBuffer:strideBuffer offset:0 atIndex:1];
    [commandEncoder setTexture:texture atIndex:0];
    [commandEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroup];
    [commandEncoder endEncoding];
}

- (MTLSize)calculateThreadsPerThreadgroupForPipelineState:(id<MTLComputePipelineState>)pipelineState {
    NSUInteger w = pipelineState.threadExecutionWidth;
    NSUInteger h = pipelineState.maxTotalThreadsPerThreadgroup / w;
    MTLSize threadsPerThreadgroup = MTLSizeMake(w, h, 1);
    
    return threadsPerThreadgroup;
}
@end
