//
//  NeuralSuperSampling.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 22/11/2021.
//

#ifndef NSS_h
#define NSS_h

#import <Foundation/Foundation.h>

//! Project version number for NeuralSuperSampling.
FOUNDATION_EXPORT double NeuralSuperSamplingVersionNumber;

//! Project version string for NeuralSuperSampling.
FOUNDATION_EXPORT const unsigned char NeuralSuperSamplingVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <NeuralSuperSampling/PublicHeader.h>

#import <NeuralSuperSampling/NSSUpscaler.h>
#import <NeuralSuperSampling/NSSMetalPreprocessor.h>
#import <NeuralSuperSampling/NSSPreprocessorDescriptor.h>
#import <NeuralSuperSampling/NSSANEDecoder.h>
#import <NeuralSuperSampling/NSSBuffer.h>

#endif /* NSS_h */
