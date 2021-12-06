//
//  NSSANEReconstructor.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 27/11/2021.
//

#import <Foundation/Foundation.h>
#import "NSSBuffer.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSSANEReconstructor : NSObject

@property (nonatomic, strong, readonly, nullable) NSSBuffer* inputBuffer;
@property (nonatomic, strong, readonly, nullable) NSSBuffer* outputBuffer;

- (id)initWithMilUrl:(NSURL*)milUrl modelKey:(NSString*)key;
- (BOOL)loadModelWithError:(NSError**)error;
- (void)attachInputBuffer:(NSSBuffer*)inputBuffer outputBuffer:(NSSBuffer*)outputBuffer;
- (BOOL)processWithError:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
