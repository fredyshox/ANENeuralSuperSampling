//
//  NSSMetalProcessing.m
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 22/11/2021.
//

#import "NSSMetalProcessing.h"
#import "NSSUtility.h"

NSString* const kZeroUpsamplingFunctionName = @"zero_upsampling";
NSString* const kWarpFunctionName = @"backward_image_warp";
NSString* const kCopyFunctionName = @"copy_texture_to_buffer";

@implementation NSSMetalProcessing {
    id<MTLLibrary> library;
    id<MTLDevice> device;
    id<MTLComputePipelineState> upsamplingPipeline;
    id<MTLComputePipelineState> warpPipeline;
    id<MTLComputePipelineState> copyPipeline;
    NSUInteger factor;
    NSUInteger resultStride;
}

- (id)initWithDevice:(id<MTLDevice>)device scaleFactor:(NSUInteger)scaleFactor outputBufferStride:(NSUInteger)outputBufferStride {
    self = [super init];
    if (self) {
        self->device = device;
        self->factor = scaleFactor;
        self->resultStride = outputBufferStride;
        
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

- (void)warpInputTexture:(id<MTLTexture>)inputTexture motionTexture:(id<MTLTexture>)motionTexture outputTexture:(id<MTLTexture>)outputTexture withCommandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    id<MTLComputeCommandEncoder> warpCommandEncoder = [commandBuffer computeCommandEncoderWithDispatchType:MTLDispatchTypeSerial];
    if (warpCommandEncoder == nil) {
        return;
    }
    
    MTLSize initialGridSize = MTLSizeMake(inputTexture.width, inputTexture.height, 1);
    MTLSize warpThreadgroup = [self calculateThreadsPerThreadgroupForPipelineState:warpPipeline];
    
    [warpCommandEncoder setComputePipelineState:warpPipeline];
    [warpCommandEncoder setTexture:inputTexture atIndex:0];
    [warpCommandEncoder setTexture:motionTexture atIndex:1];
    [warpCommandEncoder setTexture:outputTexture atIndex:2];
    [warpCommandEncoder dispatchThreads:initialGridSize threadsPerThreadgroup:warpThreadgroup];
    [warpCommandEncoder endEncoding];
}

- (void)copyTexture:(id<MTLTexture>)inputTexture outputTexture:(id<MTLTexture>)outputTexture withCommandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    assert(inputTexture.width == outputTexture.width && inputTexture.height == outputTexture.height);
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    [blitEncoder copyFromTexture:inputTexture toTexture:outputTexture];
    [blitEncoder endEncoding];
}

- (void)copyColorTexture:(id<MTLTexture>)colorTexture depthTexture:(id<MTLTexture>) depthTexture outputBuffer:(id<MTLBuffer>)buffer outputBufferOffset:(NSUInteger)offset withCommandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    assert(colorTexture.width == depthTexture.width && colorTexture.height == depthTexture.height);
    MTLSize initialGridSize = MTLSizeMake(colorTexture.width, colorTexture.height, 1);
    MTLSize copyThreadgroup = [self calculateThreadsPerThreadgroupForPipelineState:copyPipeline];
    
    id<MTLComputeCommandEncoder> copyColorCommandEncoder = [commandBuffer computeCommandEncoderWithDispatchType:MTLDispatchTypeSerial];
    assert(copyColorCommandEncoder != nil);
    [copyColorCommandEncoder setComputePipelineState:copyPipeline];
    [copyColorCommandEncoder setTexture:colorTexture atIndex:0];
    [copyColorCommandEncoder setBuffer:buffer offset:offset*sizeof(__fp16) atIndex:0];
    [copyColorCommandEncoder dispatchThreads:initialGridSize threadsPerThreadgroup:copyThreadgroup];
    [copyColorCommandEncoder endEncoding];

    id<MTLComputeCommandEncoder> copyDepthCommandEncoder = [commandBuffer computeCommandEncoderWithDispatchType:MTLDispatchTypeSerial];
    assert(copyDepthCommandEncoder != nil);
    NSUInteger depthOffset = (offset+3);
    [copyDepthCommandEncoder setComputePipelineState:copyPipeline];
    [copyDepthCommandEncoder setTexture:depthTexture atIndex:0];
    [copyDepthCommandEncoder setBuffer:buffer offset:depthOffset*sizeof(__fp16) atIndex:0];
    [copyDepthCommandEncoder dispatchThreads:initialGridSize threadsPerThreadgroup:copyThreadgroup];
    [copyDepthCommandEncoder endEncoding];
}

- (void)clearTexture:(id<MTLTexture>)texture withCommandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    MTLRenderPassDescriptor* clearRenderPassDesc = [MTLRenderPassDescriptor renderPassDescriptor];
    clearRenderPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
    clearRenderPassDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    clearRenderPassDesc.colorAttachments[0].texture = texture;

    id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:clearRenderPassDesc];
    [commandEncoder endEncoding];
}

-(MTLSize)calculateThreadsPerThreadgroupForPipelineState:(id<MTLComputePipelineState>)pipelineState {
    NSUInteger w = pipelineState.threadExecutionWidth;
    NSUInteger h = pipelineState.maxTotalThreadsPerThreadgroup / w;
    MTLSize threadsPerThreadgroup = MTLSizeMake(w, h, 1);
    
    return threadsPerThreadgroup;
}

@end
