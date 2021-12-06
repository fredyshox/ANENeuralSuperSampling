//
//  NSSMetalPreprocessor.m
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 22/11/2021.
//

#import "NSSMetalPreprocessor.h"
#import "NSSUtility.h"

const NSString* kZeroUpsamplingFunctionName = @"zero_upsampling";
const NSString* kWarpFunctionName = @"backward_image_warp_buffer";
const NSString* kCopyFunctionName = @"copy_texture_to_buffer";

@implementation NSSMetalPreprocessor {
    id<MTLLibrary> library;
    id<MTLDevice> device;
    id<MTLComputePipelineState> upsamplingPipeline;
    id<MTLComputePipelineState> warpPipeline;
    id<MTLComputePipelineState> copyPipeline;
    uint32_t factor;
    uint32_t resultStride;
}

-(id)initWithDevice:(id<MTLDevice>)device descriptor:(NSSPreprocessorDescriptor*)descriptor; {
    self = [super init];
    if (self) {
        self->device = device;
        self->factor = descriptor.scaleFactor;
        self->resultStride = descriptor.outputBufferStride;
        
        NSError* error = nil;
        NSBundle* bundle = [NSBundle bundleForClass: [self class]];
        id<MTLLibrary> library = [device newDefaultLibraryWithBundle:bundle
                                                               error:&error];
        RAISE_EXCEPTION_ON_ERROR(error, @"MetalLibraryNotFound")
        self->library = library;
        
        MTLFunctionConstantValues* constantValues = [[MTLFunctionConstantValues alloc] init];
        [constantValues setConstantValue: &self->factor type:MTLDataTypeUInt atIndex:0];
        [constantValues setConstantValue: &self->resultStride type:MTLDataTypeUInt atIndex:1];
        
        id<MTLFunction> upsamplingFunction = [library newFunctionWithName:kZeroUpsamplingFunctionName
                                                           constantValues:constantValues
                                                                    error:&error];
        RAISE_EXCEPTION_ON_ERROR(error, @"MetalLibraryFunctionNotFound");
        self->upsamplingPipeline = [device newComputePipelineStateWithFunction:upsamplingFunction error:&error];
        RAISE_EXCEPTION_ON_ERROR(error, @"MetalLibraryPipelineStateError");
        
        id<MTLFunction> warpFunction = [library newFunctionWithName:kWarpFunctionName
                                                     constantValues:constantValues
                                                              error:&error];
        RAISE_EXCEPTION_ON_ERROR(error, @"MetalLibraryFunctionNotFound");
        self->warpPipeline = [device newComputePipelineStateWithFunction:warpFunction error:&error];
        RAISE_EXCEPTION_ON_ERROR(error, @"MetalLibraryPipelineStateError");
        
        id<MTLFunction> copyFunction = [library newFunctionWithName:kCopyFunctionName
                                                     constantValues:constantValues
                                                              error:&error];
        RAISE_EXCEPTION_ON_ERROR(error, @"MetalLibraryFunctionNotFound")
        self->copyPipeline = [device newComputePipelineStateWithFunction:copyFunction error:&error];
        RAISE_EXCEPTION_ON_ERROR(error, @"MetalLibraryPipelineStateError");
    }
    
    return self;
}

- (void)upsampleInputTexture:(id<MTLTexture>)inputTexture outputTexture:(id<MTLTexture>)outputTexture withCommandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    id<MTLComputeCommandEncoder> upsamplingCommandEncoder = [commandBuffer computeCommandEncoderWithDispatchType:MTLDispatchTypeSerial];
    if (upsamplingCommandEncoder == nil) {
        return;
    }
    
    MTLSize initialGridSize = MTLSizeMake(inputTexture.width, inputTexture.height, 1);
    MTLSize upsamplingThreadgroup = [self calculateThreadsPerThreadgroupForPipelineState:upsamplingPipeline];
    
    [upsamplingCommandEncoder setComputePipelineState:upsamplingPipeline];
    [upsamplingCommandEncoder setTexture:inputTexture atIndex:0];
    [upsamplingCommandEncoder setTexture:outputTexture atIndex:1];
    [upsamplingCommandEncoder dispatchThreads:initialGridSize threadsPerThreadgroup:upsamplingThreadgroup];
    [upsamplingCommandEncoder endEncoding];
}

- (void)warpColorTexture:(id<MTLTexture>)colorTexture depthTexture:(id<MTLTexture>)depthTexture motionTexture:(id<MTLTexture>)motionTexture outputBuffer:(id<MTLBuffer>)buffer withCommandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    id<MTLComputeCommandEncoder> warpCommandEncoder = [commandBuffer computeCommandEncoderWithDispatchType:MTLDispatchTypeSerial];
    if (warpCommandEncoder == nil) {
        return;
    }
    
    MTLSize initialGridSize = MTLSizeMake(colorTexture.width, colorTexture.height, 1);
    MTLSize warpThreadgroup = [self calculateThreadsPerThreadgroupForPipelineState:warpPipeline];
    
    [warpCommandEncoder setComputePipelineState:warpPipeline];
    [warpCommandEncoder setTexture:colorTexture atIndex:0];
    [warpCommandEncoder setTexture:depthTexture atIndex:1];
    [warpCommandEncoder setTexture:motionTexture atIndex:2];
    [warpCommandEncoder setBuffer:buffer offset:0 atIndex:0];
    [warpCommandEncoder dispatchThreads:initialGridSize threadsPerThreadgroup:warpThreadgroup];
    [warpCommandEncoder endEncoding];
}

-(MTLSize)calculateThreadsPerThreadgroupForPipelineState:(id<MTLComputePipelineState>)pipelineState {
    NSUInteger w = pipelineState.threadExecutionWidth;
    NSUInteger h = pipelineState.maxTotalThreadsPerThreadgroup / w;
    MTLSize threadsPerThreadgroup = MTLSizeMake(w, h, 1);
    
    return threadsPerThreadgroup;
}

- (void)copyColorTexture:(id<MTLTexture>)colorTexture depthTexture:(id<MTLTexture>) depthTexture outputBuffer:(id<MTLBuffer>)buffer withCommandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    id<MTLComputeCommandEncoder> copyColorCommandEncoder = [commandBuffer computeCommandEncoderWithDispatchType:MTLDispatchTypeSerial];
    id<MTLComputeCommandEncoder> copyDepthCommandEncoder = [commandBuffer computeCommandEncoderWithDispatchType:MTLDispatchTypeSerial];
    if (copyColorCommandEncoder == nil || copyDepthCommandEncoder == nil) {
        return;
    }
    
    assert(colorTexture.width == depthTexture.width && colorTexture.height == depthTexture.height);
    MTLSize initialGridSize = MTLSizeMake(colorTexture.width, colorTexture.height, 1);
    MTLSize copyThreadgroup = [self calculateThreadsPerThreadgroupForPipelineState:copyPipeline];
    
    [copyColorCommandEncoder setComputePipelineState:copyPipeline];
    [copyColorCommandEncoder setTexture:colorTexture atIndex:0];
    [copyColorCommandEncoder setBuffer:buffer offset:0 atIndex:0];
    [copyColorCommandEncoder dispatchThreads:initialGridSize threadsPerThreadgroup:copyThreadgroup];
    [copyColorCommandEncoder endEncoding];
    
    NSUInteger depthOffset = 3*sizeof(__fp16);
    [copyDepthCommandEncoder setComputePipelineState:copyPipeline];
    [copyDepthCommandEncoder setTexture:depthTexture atIndex:0];
    [copyDepthCommandEncoder setBuffer:buffer offset:depthOffset atIndex:0];
    [copyDepthCommandEncoder dispatchThreads:initialGridSize threadsPerThreadgroup:copyThreadgroup];
    [copyDepthCommandEncoder endEncoding];
}

@end
