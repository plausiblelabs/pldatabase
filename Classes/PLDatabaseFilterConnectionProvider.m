/*
 * Copyright (c) 2011 Plausible Labs Cooperative, Inc.
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

#import "PLDatabaseFilterConnectionProvider.h"

/**
 * Provides a filtering database connection provider that supports modification of PLDatabase connections as they are
 * returned from a backing PLDatabaseConnectionProvider.
 *
 * @par Thread Safety
 * Thread-safe. May be used from any thread.
 */
@implementation PLDatabaseFilterConnectionProvider


/**
 * Initialize a new instance with the provided connection provider and filter block.
 *
 * @param provider A connection provider that will be used to acquire new database connections.
 * @param filterBlock The filter block to be called for each returned database connection.
 */
- (id) initWithConnectionProvider: (id<PLDatabaseConnectionProvider>) provider filterBlock: (void (^)(id<PLDatabase> db)) block {
    if ((self = [super init]) == nil)
        return nil;

    _provider = [provider retain];
    _filterBlock = [block copy];

    return self;
}

- (void) dealloc {
    [_provider release];
    [_filterBlock release];

    [super dealloc];
}

// from PLDatabaseConnectionProvider protocol
- (id<PLDatabase>) getConnectionAndReturnError: (NSError **) outError {
    /* Attempt to fetch the connection */
    id<PLDatabase> db = [_provider getConnectionAndReturnError: outError];
    if (db == nil)
        return nil;
    
    /* Apply a filter block */
    _filterBlock(db);

    /* Return the filtered connection */
    return db;
}


// from PLDatabaseConnectionProvider protocol
- (void) closeConnection: (id<PLDatabase>) connection {
    [_provider closeConnection: connection];
}

@end
