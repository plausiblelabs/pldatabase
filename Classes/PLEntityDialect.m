/*
 * Copyright (c) 2008 Plausible Labs.
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

#import "PlausibleDatabase.h"


/**
 * Represents a SQL dialect as implemented by a specific database system.
 * Implementors should subclass this abstract base class to implement
 * Plausible Entity support for a specific database system.
 *
 * As this class is intended to be extended, binary compatibility of
 * subclasses is gauranteed.
 *
 * Subclass implementations must be immutable, as they will be shared
 * between multiple threads and potentially unrelated database connections.
 *
 * @warning The PLEntityDialect API is experimental and subject to change.
 */
@implementation PLEntityDialect

- (NSException *) validationExceptionWithReason: (NSString *) reason {
    return [NSException exceptionWithName: PLDatabaseException reason: reason userInfo: nil];
}

- (id) init {
    if ((self = [super init]) == nil)
        return nil;

    /*
     * Perform validation of the subclass' implementation.
     */

    /* Determining Insert Identity */
    if ([self supportsLastInsertIdentity])
        assert([self selectLastInsertIdentity] != nil);

    return self;
}

/**
 * @name Determining Insert Identity
 * @{
 */

/**
 * Return YES if the dialect supports SELECT for the
 * previous insert's identity value.
 *
 * @return Return YES if PLEntityDialect::selectLastInsertIdentity is supported.
 *
 * @par Default Value:
 * Method returns NO by default.
 */
- (BOOL) supportsLastInsertIdentity {
    return NO;
}

/**
 * Returns the statement used to get the last generated IDENTITY value.
 *
 * If PLEntityDialect::supportsLastInsertIdentity returns NO, this method may
 * return a nil value.
 *
 * @return Returns a SQL statement that provides the last generated IDENTITY value for the previous INSERT.
 *
 * @par Default Value:
 * Method returns nil by default.
 *
 */
- (NSString *) selectLastInsertIdentity {
    return nil;
}

/** @} Insert Identity */

@end
