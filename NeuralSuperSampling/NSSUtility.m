//
//  NSSUtility.m
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 26/01/2022.
//

#import "NSSUtility.h"

void debug_dumpIOSurfaceToFile(NSString* path, IOSurfaceRef surface) {
    void* bytes = IOSurfaceGetBaseAddress(surface);
    size_t size = IOSurfaceGetAllocSize(surface);
    NSData* data = [NSData dataWithBytes:bytes length: size];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    [data writeToFile:path atomically:NO];
}
