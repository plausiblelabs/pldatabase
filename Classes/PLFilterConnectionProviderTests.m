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
#import "PLFilterConnectionProvider.h"

@interface PLFilterConnectionProviderTests : SenTestCase {
@private
}

@end

/**
 * PLFilterConnectionProvider Tests
 */
@implementation PLFilterConnectionProviderTests

/**
 * Test basic filtering.
 */
- (void) testFiltering {
    NSError *error;
    
    /* Create a testing database provider */
    PLSqliteConnectionProvider *provider = [[[PLSqliteConnectionProvider alloc] initWithPath: @":memory:"] autorelease];
    PLFilterConnectionProvider *filter = [[[PLFilterConnectionProvider alloc] initWithConnectionProvider: provider filterBlock: ^(id<PLDatabase> db) {
        NSError *error;

        STAssertNotNil(db, @"Filtering a nil database");
        STAssertTrue([db executeUpdateAndReturnError: &error statement: @"PRAGMA user_version = 42;"], @"Failed to set user version: %@", error);
    }] autorelease];
    
    /* Fetch a connection */
    id<PLDatabase> con = [filter getConnectionAndReturnError: &error];
    STAssertNotNil(con, @"Failed to fetch connection: %@", error);
    
    /* Verify that our filter block was applied. */
    id<PLResultSet> rs = [con executeQueryAndReturnError: &error statement: @"PRAGMA user_version"];
    STAssertNotNil(rs, @"Failed to execute pragma: %@", error);
    [rs next];

    STAssertEquals(42, [rs intForColumn: @"user_version"], @"Incorrect version, filter not applied.");
    [rs close];
    
    /* Check connection back in. */
    [filter closeConnection: con];
}

@end
