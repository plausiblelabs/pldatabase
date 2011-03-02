/*
 * Copyright (c) 2008-2011 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holder nor the names of any contributors
 *    may be used to endorse or promote products derived from this
 *    software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>

/* Exceptions */
extern NSString *PLDatabaseException;

/* Error Domain and Codes */
extern NSString *PLDatabaseErrorDomain;
extern NSString *PLDatabaseErrorQueryStringKey;
extern NSString *PLDatabaseErrorVendorErrorKey;
extern NSString *PLDatabaseErrorVendorStringKey;

/**
 * NSError codes in the Plausible Database error domain.
 * @ingroup enums
 */
typedef enum {
    /** An unknown error has occured. If this
     * code is received, it is a bug, and should be reported. */
    PLDatabaseErrorUnknown = 0,
    
    /** File not found. */
    PLDatabaseErrorFileNotFound = 1,
    
    /** An SQL query failed. */
    PLDatabaseErrorQueryFailed = 2,
    
    /** The provided SQL statement was invalid. */
    PLDatabaseErrorInvalidStatement = 3,
} PLDatabaseError;

#ifdef PL_DB_PRIVATE

@interface PlausibleDatabase : NSObject {
}

+ (NSError *) errorWithCode: (PLDatabaseError) errorCode localizedDescription: (NSString *) localizedDescription 
                queryString: (NSString *) queryString
                vendorError: (NSNumber *) vendorError vendorErrorString: (NSString *) vendorErrorString;

@end

#endif /* PL_DB_PRIVATE */
