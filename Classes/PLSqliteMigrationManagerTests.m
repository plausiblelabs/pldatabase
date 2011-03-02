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

#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>

#import "PLSqliteMigrationManager.h"

@interface PLSqliteMigrationManagerTests : SenTestCase {
@private
    NSString *_dbPath;
    PLSqliteDatabase *_db;
    PLSqliteMigrationManager *_versionManager;
}
@end


@implementation PLSqliteMigrationManagerTests

- (void) setUp {
    /* Create a temporary file for the database. Secure -- user owns enclosing directory. */
    _dbPath = [[NSTemporaryDirectory() stringByAppendingPathComponent: [[NSProcessInfo processInfo] globallyUniqueString]] retain];
    
    /* Create the temporary database */
    _db = [[PLSqliteDatabase alloc] initWithPath: _dbPath];
    STAssertTrue([_db open], @"Could not open temporary database");

    /* Create the version manager */
    _versionManager = [[PLSqliteMigrationManager alloc] init];
}

- (void) tearDown {
    /* Close the open database file */
    [_db close];

    /* Remove the temporary database file */
    STAssertTrue([[NSFileManager defaultManager] removeItemAtPath: _dbPath error: NULL], @"Could not clean up database %@", _dbPath);
    
    /* Release our objects */
    [_dbPath release];
    [_db release];
    [_versionManager release];
}

- (void) testDefaultVersion {
    NSError *error;
    int version;

    STAssertTrue([_versionManager version: &version forDatabase: _db error: &error], @"Could not retrieve version: %@", error);
    STAssertEquals(0, version, @"Default version should be 0, is %d", version);
}

- (void) testSetGetVersion {
    NSError *error;
    int version;
    
    STAssertTrue([_versionManager setVersion: 5 forDatabase: _db error: &error], @"Could not set version: %@", error);
    STAssertTrue([_versionManager version: &version forDatabase: _db error: &error], @"Could not retrieve version: %@", error);
    STAssertEquals(5, version, @"Version should be 5, is %d", version);
}

- (void) testBeginAndRollbackTransaction {
    NSError *error;

    STAssertTrue([_versionManager beginExclusiveTransactionForDatabase: _db error: &error], @"Could not start a transaction: %@", error);

    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a int)"], @"Could not create test table");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", [NSNumber numberWithInt: 42]]), @"Inserting test data failed");

    STAssertTrue([_db tableExists: @"test"], @"Table was not created");
    STAssertTrue([_versionManager rollbackTransactionForDatabase: _db error: &error], @"Could not roll back");
    STAssertFalse([_db tableExists: @"test"], @"Table was not rolled back");
}


- (void) testBeginAndCommitTransaction {
    NSError *error;

    STAssertTrue([_versionManager beginExclusiveTransactionForDatabase: _db error: &error], @"Could not start a transaction: %@", error);

    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a int)"], @"Could not create test table");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", [NSNumber numberWithInt: 42]]), @"Inserting test data failed");
    STAssertTrue([_db tableExists: @"test"], @"Table was not created");

    STAssertTrue([_versionManager commitTransactionForDatabase: _db error: &error], @"Could not commit transaction");
    
    STAssertTrue([_db tableExists: @"test"], @"Table was not comitted");
}

@end
