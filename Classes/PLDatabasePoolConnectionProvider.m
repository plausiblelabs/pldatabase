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

#import "PLDatabasePoolConnectionProvider.h"

/**
 * Provides a size-constrained thread-safe database connection pool.
 *
 * @par Thread Safety
 * Thread-safe. May be used from any thread, subject to SQLite's documented thread-safety constraints.
 */
@implementation PLDatabasePoolConnectionProvider

/**
 * Initialize a new instance with the provided connection provider and capacity.
 *
 * @param provider A connection provider that will be used to acquire new database connections.
 * @param capacity The maximum number of database connections that the pool will cache. The pool will return
 * as many connections as are requested, but will not cache connections beyond this capacity. If a capacity of 0 is
 * specified, no capacity limit will be applied.
 */
- (id) initWithConnectionProvider: (id<PLDatabaseConnectionProvider>) provider capacity: (NSUInteger) capacity {
    if ((self = [super init]) == nil)
        return nil;
    
    _provider = provider;
    _capacity = capacity;

    if (capacity > 0) {
        _connections = [[NSMutableSet alloc] initWithCapacity: capacity];
    } else {
        _connections = [[NSMutableSet alloc] init];
    }

    pthread_mutex_init(&_lock, NULL);

    return self;
}

- (void) dealloc {
    pthread_mutex_destroy(&_lock);
}

// from PLDatabaseConnectionProvider protocol
- (id<PLDatabase>) getConnectionAndReturnError: (NSError **) outError {
    id<PLDatabase> db;
    
    pthread_mutex_lock(&_lock); {
        /* Try to fetch an existing connection */
        db = [_connections anyObject];
        if (db != nil)
            [_connections removeObject: db];
    } pthread_mutex_unlock(&_lock);
    
    
    /* No existing connection could be acquired; try to create a new connection. This may fail, and we just report the
     * error directly. We do this outside of the synchronized block to avoid any possibility of deadlock when calling
     * out to our backing provider. */
    if (db == nil) {
        db = [_provider getConnectionAndReturnError: outError];
    }

    return db;
}


// from PLDatabaseConnectionProvider protocol
- (void) closeConnection: (id<PLDatabase>) connection {
    BOOL shouldClose = NO;

    pthread_mutex_lock(&_lock); {
        /* Check if we've hit capacity */ 
        if (_capacity > 0 && [_connections count] >= _capacity) {
            shouldClose = YES;

        } else if (![connection goodConnection]) {
            /* Connection is invalid */
            shouldClose = YES;

        } else {
            /* Connection is valid; re-add to the set of available connections. */
            [_connections addObject: connection];
        }
    } pthread_mutex_unlock(&_lock);

    /* We do this outside of the synchronized block to avoid any possibility of deadlock when calling
     * out to our backing provider. */
    if (shouldClose)
        [_provider closeConnection: connection];
}

@end
