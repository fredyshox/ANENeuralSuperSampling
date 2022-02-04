//
//  NSSUtility.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 28/11/2021.
//

#ifndef NSSUtility_h
#define NSSUtility_h

#import <Foundation/Foundation.h>
#import <IOSurface/IOSurface.h>

#define RAISE_EXCEPTION_ON_ERROR(err, name) \
    if (err) { \
        [NSException raise:name format:@"Error while initializing metal preprocessor: %@", err]; \
    }

#define RAISE_EXCEPTION(name) RAISE_EXCEPTION_ON_ERROR([NSError new], name)

#ifdef DEBUG
#define NSDebugLog(...) NSLog(__VA_ARGS__)
#else
#define NSDebugLog(...) (void)0;
#endif

void debug_dumpIOSurfaceToFile(NSString* path, IOSurfaceRef surface);

#endif /* NSSUtility_h */
