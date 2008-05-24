/*
 * Copyright (c) 2008 Plausible Labs Cooperative, Inc.
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
 *
 * @par Thread Safety
 * PLEntityDialect instances must be immutable, and support concurrent
 * access from multiple threads.
 */
@implementation PLEntityDialect

- (NSException *) validationExceptionWithReason: (NSString *) reason {
    return [NSException exceptionWithName: PLDatabaseException reason: reason userInfo: nil];
}


/**
 * Initialize the entity dialect.
 *
 * @par Designated Initializer
 * This method is the designated initializer for the PLEntityDialect class.
 */
- (id) init {
    if ((self = [super init]) == nil)
        return nil;

    /*
     * Perform validation of the subclass' implementation.
     */

    /* Determining Insert Identity */
    if ([self supportsLastInsertIdentity])
        assert([self lastInsertIdentity] != nil);

    return self;
}

/**
 * @name Quoting
 * @{
 */

/**
 * Quote a table or column name (an identifier) for the
 * database.
 *
 * @param identifier The identifier to be quoted
 * @return Returns a quoted identifier.
 *
 * @par Default Value:
 * The idenfitier is wrapped in double quotes, ie, "identifier".
 *
 * @warning This method does not provide escaping, and MUST NOT be
 * used with non-identifiers (such as values).
 */
- (NSString *) quoteIdentifier: (NSString *) identifier {
    return [NSString stringWithFormat: @"\"%@\"", identifier];
}


/*
 * @} Quoting
 */

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
 * Returns the expression used to get the last generated IDENTITY value.
 *
 * If PLEntityDialect::supportsLastInsertIdentity returns NO, this method may
 * return a nil value.
 *
 * @return Returns a SQL expression that provides the last generated IDENTITY value for the previous INSERT.
 *
 * @par Default Value:
 * Method returns nil by default.
 *
 * @par Example
 * - For SQLite, this would be "last_insert_rowid()"
 * - For MySQL, this would be "LAST_INSERT_ID()"
 */
- (NSString *) lastInsertIdentity {
    return nil;
}

/** @} Insert Identity */

@end
