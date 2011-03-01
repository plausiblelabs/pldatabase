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

#import <PlausibleDatabase/PlausibleDatabase.h>
#import "PLSqliteStatementReference.h"

@interface PLSqliteStatementReferenceTests : SenTestCase {
@private
    PLSqliteStatementReference *_ref;
    PLSqliteDatabase *_db;
}

@end

/**
 * PLSqliteStatementReference Tests
 */
@implementation PLSqliteStatementReferenceTests

- (void) setUp {
    NSError *error;

    /* Create a testing database */
    _db = [[PLSqliteDatabase databaseWithPath: @":memory:"] retain];
    STAssertTrue([_db openAndReturnError: &error], @"Database could not be opened: %@", error);
    sqlite3 *sqlite = [_db sqliteHandle];
    
    /* Prepare a statement to test with */
    NSString *queryString = @"SELECT 1";
    sqlite3_stmt *stmt;
    const char *unused;
    int ret;

    ret = sqlite3_prepare_v2(sqlite, [queryString UTF8String], -1, &stmt, &unused);
    STAssertEquals(ret, SQLITE_OK, @"Failed to prepare the statement");
    
    /* Create our reference to it */
    _ref = [[PLSqliteStatementReference alloc] initWithStatement: stmt queryString: queryString];
}

- (void) tearDown {
    [_ref invalidate];
    [_ref release];

    [_db close];
}

/**
 * Test performing a transaction block using the reference.
 */
- (void) testPerformWithStatement {
    NSError *error;

    /* Try with a valid reference */
    __block BOOL didRun = NO;
    BOOL result = [_ref performWithStatement: ^(sqlite3_stmt *stmt) {
        STAssertTrue(stmt != NULL, @"Statement is nil");
        didRun = YES;
    } error: &error];

    STAssertTrue(didRun, @"Block did not run");
    STAssertTrue(result, @"Perform returned false");

    /* Make sure the transaction block is not executed once the reference is invalidated. */
    [_ref invalidate];
    didRun = NO;

    result = [_ref performWithStatement: ^(sqlite3_stmt *stmt) {
        STAssertTrue(stmt != NULL, @"Statement is nil");
        didRun = YES;
    } error: &error];
    
    STAssertFalse(didRun, @"Block ran with invalidated statement.");
    STAssertFalse(result, @"Perform returned true with an invalidated statement.");
    STAssertEquals([error code], PLDatabaseErrorStatementInvalidated, @"Unexpected error returned.");

    /* Verify that the databases closes cleanly. If it doesn't, that means that the statements were leaked, and an
     * exception will be raised. */
    [_db close];
}

/**
 * Test invalidation of a parent reference while using a cloned reference.
 */
- (void) testCloneParentInvalidated {
    PLSqliteStatementReference *clone = [_ref cloneReference];
    NSError *error;
    
    /* Make sure the transaction block is not executed once the parent reference is invalidated. */
    __block BOOL didRun = NO;
    [_ref invalidate];
    
    BOOL result = [clone performWithStatement: ^(sqlite3_stmt *stmt) {
        STAssertTrue(stmt != NULL, @"Statement is nil");
        didRun = YES;
    } error: &error];
    
    STAssertFalse(didRun, @"Block ran with invalidated statement.");
    STAssertFalse(result, @"Perform returned true with an invalidated statement.");
    STAssertEquals([error code], PLDatabaseErrorStatementInvalidated, @"Unexpected error returned.");

    /* Verify that the databases closes cleanly. If it doesn't, that means that the statements were leaked, and an
     * exception will be raised. */
    [_db close];
}

/**
 * Test performWithStatement on a cloned reference.
 */
- (void) testClonePerformWithStatement {
    PLSqliteStatementReference *clone = [_ref cloneReference];
    NSError *error;

    /* Try with a valid child reference */
    __block BOOL didRun = NO;
    BOOL result = [clone performWithStatement: ^(sqlite3_stmt *stmt) {
        STAssertTrue(stmt != NULL, @"Statement is nil");
        didRun = YES;
    } error: &error];
    
    STAssertTrue(didRun, @"Block did not run");
    STAssertTrue(result, @"Perform returned false");


    /* Make sure the transaction block is not executed once the reference is invalidated. */
    [clone invalidate];
    didRun = NO;
    
    result = [clone performWithStatement: ^(sqlite3_stmt *stmt) {
        STAssertTrue(stmt != NULL, @"Statement is nil");
        didRun = YES;
    } error: &error];
    
    STAssertFalse(didRun, @"Block ran with invalidated statement.");
    STAssertFalse(result, @"Perform returned true with an invalidated statement.");
    STAssertEquals([error code], PLDatabaseErrorStatementInvalidated, @"Unexpected error returned.");


    /* Verify that the child reference does not invalidate the parent. */
    didRun = NO;
    result = [_ref performWithStatement: ^(sqlite3_stmt *stmt) {
        STAssertTrue(stmt != NULL, @"Statement is nil");
        didRun = YES;
    } error: &error];
    
    STAssertTrue(didRun, @"Block did not run");
    STAssertTrue(result, @"Perform returned false");
}

@end
