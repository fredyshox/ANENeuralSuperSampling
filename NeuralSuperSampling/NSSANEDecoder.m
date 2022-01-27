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
    id<MTLLibrary> library;
    id<MTLComputePipelineState> pipeline;
    id<MTLBuffer> inputBuffer;
    uint32_t inputBufferStride;
    BOOL yuvConversion;
}

- (id)initWithDevice:(id<MTLDevice>)device yuvToRgbConversion:(BOOL)yuvConversion {
    self = [super init];
    if (self) {
        self->device = device;
        self->yuvConversion = yuvConversion;
        
        NSError* error = nil;
        NSBundle* bundle = [NSBundle bundleForClass: [self class]];
        id<MTLLibrary> library = [device newDefaultLibraryWithBundle:bundle
                                                               error:&error];
        RAISE_EXCEPTION_ON_ERROR(error, @"MetalLibraryNotFound");
        self->library = library;
    }
    
    return self;
}

- (void)attachBuffer:(NSSBuffer*)buffer {
    inputBuffer = [device newBufferWithBytesNoCopy:buffer.dataPointer
                                                  length:buffer.length
                                                 options:MTLResourceStorageModeShared
                                             deallocator:^(void*, NSUInteger) { /* nop */ }];
    assert(inputBuffer != nil);
    inputBufferStride = (uint32_t) buffer.pixelStride;
    MTLFunctionConstantValues* constantValues = [[MTLFunctionConstantValues alloc] init];
    [constantValues setConstantValue: &inputBufferStride type:MTLDataTypeUInt atIndex:0];
    
    id<MTLFunction> conversionFunction;
    NSError* error;
    if (yuvConversion) {
        conversionFunction = [library newFunctionWithName:kConversionWithYuvFunctionName
                                           constantValues:constantValues
                                                    error:&error];
    } else {
        conversionFunction = [library newFunctionWithName:kConversionFunctionName
                                           constantValues:constantValues
                                                    error:&error];
    }
    RAISE_EXCEPTION_ON_ERROR(error, @"MetalLibraryFunctionError");
    self->pipeline = [device newComputePipelineStateWithFunction:conversionFunction error:&error];
    RAISE_EXCEPTION_ON_ERROR(error, @"MetalLibraryPipelineStateError");
}

- (void)decodeIntoTexture:(id<MTLTexture>)texture usingCommandBuffer:(id<MTLCommandBuffer>)commandBuffer updateFence:(_Nullable id<MTLFence>)fence {
    if (inputBuffer == nil || pipeline == nil) {
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
    [commandEncoder setTexture:texture atIndex:0];
    [commandEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroup];
    if (fence != nil) {
        [commandEncoder updateFence:fence];
    }
    [commandEncoder endEncoding];
}

- (MTLSize)calculateThreadsPerThreadgroupForPipelineState:(id<MTLComputePipelineState>)pipelineState {
    NSUInteger w = pipelineState.threadExecutionWidth;
    NSUInteger h = pipelineState.maxTotalThreadsPerThreadgroup / w;
    MTLSize threadsPerThreadgroup = MTLSizeMake(w, h, 1);
    
    return threadsPerThreadgroup;
}
@end
