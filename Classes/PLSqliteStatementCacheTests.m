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

#import <SenTestingKit/SenTestingKit.h>

#import "PLSqliteDatabase.h"
#import "PLSqliteStatementCache.h"

@interface PLSqliteStatementCacheTests : SenTestCase {
@private
}

@end

/**
 * PLSqliteStatementCache Tests
 */
@implementation PLSqliteStatementCacheTests

/**
 * Test basic caching.
 */
- (void) testCaching {
    NSError *error;

    /* Create a testing database */
    PLSqliteDatabase *db = [PLSqliteDatabase databaseWithPath: @":memory:"];
    STAssertTrue([db openAndReturnError: &error], @"Database could not be opened: %@", error);
    sqlite3 *sqlite = [db sqliteHandle];

    /* Prepare a statement to test with */
    NSString *queryString = @"SELECT 1";
    sqlite3_stmt *stmt;
    const char *unused;
    int ret;

    ret = sqlite3_prepare_v2(sqlite, [queryString UTF8String], -1, &stmt, &unused);
    STAssertEquals(ret, SQLITE_OK, @"Failed to prepare the statement");

    /* Try caching it */
    PLSqliteStatementCache *cache = [[[PLSqliteStatementCache alloc] initWithCapacity: 500] autorelease];
    [cache registerStatement: stmt];
    [cache checkinStatement: stmt forQuery: queryString inFinalizer: NO];

    /* Make sure we can get it back out again */
    sqlite3_stmt *cached_stmt = [cache checkoutStatementForQueryString: queryString];
    STAssertEquals(stmt, cached_stmt, @"Statement was not cached");

    /* Re-add it to the cache so that we can test the cache's finalization of statements. */
    [cache checkinStatement: stmt forQuery: queryString inFinalizer: NO];

    /* Finalize all statements */
    [cache close];

    /* Now verify that the databases closes cleanly. If it doesn't, that means that the statements were leaked, and an 
     * exception will be raised. */
    [db close];
}

/**
 * Test cleanup of statements from their finalizers.
 */
- (void) testFinalizationHandling {
    NSError *error;
    
    /* Create a testing database */
    PLSqliteDatabase *db = [PLSqliteDatabase databaseWithPath: @":memory:"];
    STAssertTrue([db openAndReturnError: &error], @"Database could not be opened: %@", error);
    sqlite3 *sqlite = [db sqliteHandle];
    
    /* Prepare a statement to test with */
    NSString *queryString = @"SELECT 1";
    sqlite3_stmt *stmt;
    const char *unused;
    int ret;
    
    ret = sqlite3_prepare_v2(sqlite, [queryString UTF8String], -1, &stmt, &unused);
    STAssertEquals(ret, SQLITE_OK, @"Failed to prepare the statement");
    
    /* Register the statement */
    PLSqliteStatementCache *cache = [[[PLSqliteStatementCache alloc] initWithCapacity: 500] autorelease];
    [cache registerStatement: stmt];

    /* Check it in with finalization = YES */
    [cache checkinStatement: stmt forQuery: queryString inFinalizer: YES];
    
    /* Make sure we don't get it back out again. The statement should be sitting in the finalization queue. */
    sqlite3_stmt *cached_stmt = [cache checkoutStatementForQueryString: queryString];
    STAssertTrue(cached_stmt == NULL, @"Statement was cached");
    
    /* Verify that the databases closes cleanly. The above checkout request should trigger flushing of the cleanup queue;
     * If it doesn't, that means that the statements were leaked, and an exception will be raised in
     * -[PLSqliteDatabase close] */
    [db close];
}

@end
