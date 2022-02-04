//
//  NSSANEDecoder.m
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 28/11/2021.
//

#import "NSSANEDecoder.h"
#import "NSSUtility.h"

NSString* const kConversionFunctionName = @"decode_buffer";
NSString* const kConversionWithYuvFunctionName = @"decode_buffer_yuv";

@implementation NSSANEDecoder {
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
    id<MTLComputePipelineState> _pipeline;
    id<MTLBuffer> _inputBuffer;
    uint32_t _inputBufferStride;
    BOOL _yuvConversion;
}

- (id)initWithDevice:(id<MTLDevice>)device yuvToRgbConversion:(BOOL)yuvConversion {
    self = [super init];
    if (self) {
        self->_device = device;
        self->_yuvConversion = yuvConversion;
        
        NSError* error = nil;
        NSBundle* bundle = [NSBundle bundleForClass: [self class]];
        id<MTLLibrary> library = [device newDefaultLibraryWithBundle:bundle
                                                               error:&error];
        RAISE_EXCEPTION_ON_ERROR(error, @"MetalLibraryNotFound");
        self->_library = library;
    }
    
    return self;
}

- (void)attachInputBuffer:(NSSBuffer*)buffer {
    _inputBuffer = [_device newBufferWithBytesNoCopy:buffer.dataPointer
                                                  length:buffer.length
                                                 options:MTLResourceStorageModeShared
                                             deallocator:^(void*, NSUInteger) { /* nop */ }];
    assert(_inputBuffer != nil);
    _inputBufferStride = (uint32_t) buffer.pixelStride;
    MTLFunctionConstantValues* constantValues = [[MTLFunctionConstantValues alloc] init];
    [constantValues setConstantValue: &_inputBufferStride type:MTLDataTypeUInt atIndex:0];
    
    id<MTLFunction> conversionFunction;
    NSError* error;
    if (_yuvConversion) {
        conversionFunction = [_library newFunctionWithName:kConversionWithYuvFunctionName
                                           constantValues:constantValues
                                                    error:&error];
    } else {
        conversionFunction = [_library newFunctionWithName:kConversionFunctionName
                                           constantValues:constantValues
                                                    error:&error];
    }
    RAISE_EXCEPTION_ON_ERROR(error, @"MetalLibraryFunctionError");
    self->_pipeline = [_device newComputePipelineStateWithFunction:conversionFunction error:&error];
    RAISE_EXCEPTION_ON_ERROR(error, @"MetalLibraryPipelineStateError");
}

- (void)decodeIntoTexture:(id<MTLTexture>)texture usingCommandBuffer: (id<MTLCommandBuffer>)commandBuffer {
    if (_inputBuffer == nil || _pipeline == nil) {
        RAISE_EXCEPTION(@"AttachNotCalled");
    }
    
    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    if (commandEncoder == nil) {
        return;
    }
    
    MTLSize gridSize = MTLSizeMake(texture.width, texture.height, 1);
    MTLSize threadgroup = [self calculateThreadsPerThreadgroupForPipelineState:_pipeline];
    
    [commandEncoder setComputePipelineState:_pipeline];
    [commandEncoder setBuffer:_inputBuffer offset:0 atIndex:0];
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
