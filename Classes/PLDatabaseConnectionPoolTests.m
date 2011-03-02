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

#import <SenTestingKit/SenTestingKit.h>

#import "PLSqliteConnectionProvider.h"
#import "PLDatabaseConnectionPool.h"

@interface PLDatabaseConnectionPoolTests : SenTestCase {
@private
}

@end

@implementation PLDatabaseConnectionPoolTests

/**
 * Test basic pooling.
 */
- (void) testPooling {
    NSError *error;
    
    /* Create a testing database pool */
    PLSqliteConnectionProvider *provider = [[[PLSqliteConnectionProvider alloc] initWithPath: @":memory:"] autorelease];
    PLDatabaseConnectionPool *pool = [[[PLDatabaseConnectionPool alloc] initWithConnectionProvider: provider capacity: 0] autorelease];

    /* Fetch a connection */
    id<PLDatabase> con = [pool getConnectionAndReturnError: &error];
    STAssertNotNil(con, @"Failed to fetch connection: %@", error);
    
    /* Verify that another connection is returned if we request it before returning our existing connection to the pool. */
    id<PLDatabase> cachedConnection = [pool getConnectionAndReturnError: &error];
    STAssertNotNil(con, @"Failed to fetch connection: %@", error);
    STAssertTrue(con != cachedConnection, @"Returned an already checked out connection");
    
    /* Check out connection back in, verify that it will be returned if we ask for a new connection. */
    [pool closeConnection: con];
    cachedConnection = [pool getConnectionAndReturnError: &error];
    STAssertEquals(con, cachedConnection, @"Did not return expected connection");
}

/**
 * Test capacity handling
 */
- (void) testCapacity {
    NSError *error;
    
    /* Create a testing database pool */
    PLSqliteConnectionProvider *provider = [[[PLSqliteConnectionProvider alloc] initWithPath: @":memory:"] autorelease];
    PLDatabaseConnectionPool *pool = [[[PLDatabaseConnectionPool alloc] initWithConnectionProvider: provider capacity: 1] autorelease];
    
    /* Fetch two connections and check one back in; the cache should now be at capacity. */
    id<PLDatabase> con1 = [pool getConnectionAndReturnError: &error];
    id<PLDatabase> con2 = [pool getConnectionAndReturnError: &error];

    STAssertNotNil(con1, @"Failed to fetch connection: %@", error);
    STAssertNotNil(con2, @"Failed to fetch connection: %@", error);

    [pool closeConnection: con2];

    /* Verify that con2 was not closed; it should be cached. */
    STAssertTrue([con2 goodConnection], @"Connection was closed, but cache isn't yet at capacity");

    /* Check the other connection back in, and verify that it is closed by the cache. */
    [pool closeConnection: con1];
    STAssertFalse([con1 goodConnection], @"Cache is at capacity, but connection was not closed");
}

@end
