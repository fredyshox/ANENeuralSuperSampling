//
//  NSSUtility.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 28/11/2021.
//

#ifndef NSSUtility_h
#define NSSUtility_h

#define RAISE_EXCEPTION_ON_ERROR(err, name) \
    if (err) { \
        [NSException raise:name format:@"Error while initializing metal preprocessor: %@", err]; \
    }

#define RAISE_EXCEPTION(name) RAISE_EXCEPTION_ON_ERROR([NSError new], name)

#endif /* NSSUtility_h */
