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

@interface PLSqliteResultSetTests : SenTestCase {
@private
    PLSqliteDatabase *_db;
}

@end

@implementation PLSqliteResultSetTests

- (void) setUp {
    _db = [[PLSqliteDatabase alloc] initWithPath: @":memory:"];
    STAssertTrue([_db open], @"Couldn't open the test database");
}

- (void) tearDown {
    [_db release];
}

/* Test close by trying to rollback a transaction after opening (and closing) a result set. */
- (void) testClose {
    /* Start the transaction and create the test data */
    STAssertTrue([_db beginTransaction], @"Could not start a transaction");
    
    /* Create a result, move to the first row, and then close it */
    id<PLResultSet> result = [_db executeQuery: @"PRAGMA user_version"];
    [result next];
    [result close];

    /* Roll back the transaction */
    STAssertTrue([_db rollbackTransaction], @"Could not roll back, was result actually closed?");
}

/* Test handling of schema changes when iterating over an already prepared statement.
 * This is handled automatically in SQLite 3.3.9 and later by using sqlite3_prepare_v2().
 *
 * Earlier versions of SQLite (eg, Mac OS X 10.4) require manually re-preparing the statement
 * after the first call to sqlite3_step() fails with SQLITE_SCHEMA. They also require
 * calling sqlite3_reset() to return the actual sqlite3_step() error.
 *
 * Our test uses a bound parameter to ensure that any bound parameters are correctly copied
 * across to a newly created statement.
 */
- (void) testSchemaChangeHandling {
    id<PLPreparedStatement> stmt;
    NSError *error = nil;
    
    /* Create a test table, prepare a statement, then modify the test table from underneath it */
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a int)"], @"Create table failed");
    stmt = [_db prepareStatement: @"INSERT INTO test (a) VALUES (?)"];
    STAssertNotNil(stmt, @"Could not parse statement");
    STAssertTrue([_db executeUpdateAndReturnError: &error statement: @"ALTER TABLE test ADD COLUMN b int DEFAULT 0"], @"Alter table failed: %@", error);

    /* Bind parameters */
    [stmt bindParameters: [NSArray arrayWithObject: [NSNumber numberWithInt: 1]]];

    /* Execute update */
    error = nil;
    STAssertTrue([stmt executeUpdateAndReturnError: &error], @"Statement execute failed: %@ (%@)", error, [[error userInfo] objectForKey: PLDatabaseErrorVendorStringKey]);

    /* The above should not fail, but if it does, we should verify that the returned error is non-generic */
    if (error != nil) {
        int errCode = [[[error userInfo] objectForKey: PLDatabaseErrorVendorErrorKey] intValue];
        STAssertEquals(SQLITE_SCHEMA, errCode, @"Expected SQLITE_SCHEMA error code");
    }
}

- (void) testBlockIteration {
    id<PLResultSet> result;
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a int)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", [NSNumber numberWithInt: 1]]), @"Could not insert row");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", [NSNumber numberWithInt: 2]]), @"Could not insert row");

    NSError *error;
    result = [_db executeQuery: @"SELECT a FROM test"];
    __block NSInteger iterations = 0;
    BOOL success = [result enumerateAndReturnError: &error block: ^(BOOL *stop) {
        STAssertEquals(1, [result intForColumn: @"a"], @"Did not return correct date value");
        iterations++;
        *stop = YES;
    }];

    STAssertTrue(success, @"Did not iterate successfully: %@", error);
    STAssertEquals((NSInteger)1, iterations, @"Did not stop when requested");
}

- (void) testNextErrorHandling {
    NSError *error;

    /* Trigger an error by over iterating the result set. (Is there a better way to trigger this error?) */
    id<PLResultSet> result = [_db executeQuery: @"PRAGMA user_version"];
    [result nextAndReturnError: NULL];
    [result nextAndReturnError: NULL];
    [result nextAndReturnError: NULL];
    STAssertEquals(PLResultSetStatusError, [result nextAndReturnError: &error], @"Result set did not return an error");
}


- (void) testColumnIndexForName {
    id<PLResultSet> result = [_db executeQuery: @"PRAGMA user_version"];
    STAssertEquals(0, [result columnIndexForName: @"user_version"], @"user_version column not found");
    STAssertEquals(0, [result columnIndexForName: @"USER_VERSION"], @"Column index lookup appears to be case sensitive.");

    STAssertThrows([result columnIndexForName: @"not_a_column"], @"Did not throw an exception for bad column");
}

- (void) testDateForColumn {
    id<PLResultSet> result;
    NSDate *now = [NSDate date];
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a date)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", now]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    STAssertEquals([now timeIntervalSince1970], [[result dateForColumn: @"a"] timeIntervalSince1970], @"Did not return correct date value");
}

- (void) testStringForColumn {
    id<PLResultSet> result;
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a varchar(30))"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", @"TestString"]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    STAssertTrue([@"TestString" isEqual: [result stringForColumn: @"a"]], @"Did not return correct string value");
}

- (void) testIntForColumn {
    id<PLResultSet> result = [_db executeQuery: @"PRAGMA user_version"];
    STAssertNotNil(result, @"No result returned from query");
    STAssertTrue([result next], @"No rows were returned");
    
    STAssertEquals(0, [result intForColumn: @"user_version"], @"Could not retrieve user_version column");
}

- (void) testBigIntForColumn {
    id<PLResultSet> result;
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a bigint)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", [NSNumber numberWithLongLong: INT64_MAX]]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    STAssertEquals(INT64_MAX, [result bigIntForColumn: @"a"], @"Did not return correct big integer value");
}

- (void) testBoolForColumn {
    id<PLResultSet> result;
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a bool)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", [NSNumber numberWithBool: YES]]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    STAssertTrue([result boolForColumn: @"a"], @"Did not return correct bool value");
}

- (void) testFloatForColumn {
    id<PLResultSet> result;
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a float)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", [NSNumber numberWithFloat: 3.14]]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    STAssertEquals(3.14f, [result floatForColumn: @"a"], @"Did not return correct float value");
}

- (void) testDoubleForColumn {
    id<PLResultSet> result;
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a double)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", [NSNumber numberWithDouble: 3.14159]]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    STAssertEquals(3.14159, [result doubleForColumn: @"a"], @"Did not return correct double value");
}

- (void) testDataForColumn {
    const char bytes[] = "This is some example test data";
    NSData *data = [NSData dataWithBytes: bytes length: sizeof(bytes)];
    id<PLResultSet> result;
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a blob)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", data]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    STAssertTrue([data isEqualToData: [result dataForColumn: @"a"]], @"Did not return correct data value");
}

- (void) testIsNullForColumn {
    id<PLResultSet> result;
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a integer)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", nil]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    STAssertEquals(0, [result intForColumn: @"a"], @"NULL column should return 0");
    STAssertTrue([result isNullForColumn: @"a"], @"Column value should be NULL");
}

/* Test that dereferencing a null value returns a proper default 0 value */
- (void) testNullValueHandling {
    id<PLResultSet> result;
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a integer)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", nil]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    
    STAssertEquals(0, [result intForColumn: @"a"], @"Expected 0 value");
    STAssertEquals((int64_t)0, [result bigIntForColumn: @"a"], @"Expected 0 value");
    STAssertEquals(0.0f, [result floatForColumn: @"a"], @"Expected 0 value");
    STAssertEquals(0.0, [result doubleForColumn: @"a"], @"Expected 0 value");
    STAssertEquals(NO, [result boolForColumn: @"a"], @"Expected 0 value");
    STAssertTrue([result stringForColumn: @"a"] == nil, @"Expected nil value");
    STAssertTrue([result dateForColumn: @"a"] == nil, @"Expected nil value");
    STAssertTrue([result dataForColumn: @"a"] == nil, @"Expected nil value");
    STAssertTrue([result objectForColumn: @"a"] == nil, @"Expected nil value");

}

- (void) testObjectForColumn {
    id<PLResultSet> result;
    NSNumber *testInteger;
    NSString *testString;
    NSNumber *testDouble;
    NSData *testBlob;
    NSError *error;
    
    /* Initialize test data */
    testInteger = [NSNumber numberWithInt: 42];
    testString = @"Test string";
    testDouble = [NSNumber numberWithDouble: 42.42];
    testBlob = [@"Test data" dataUsingEncoding: NSUTF8StringEncoding]; 

    STAssertTrue([_db executeUpdateAndReturnError: &error statement: @"CREATE TABLE test (a integer, b varchar(20), c double, d blob, e varchar(20))"], @"Create table failed: %@", error);
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a, b, c, d, e) VALUES (?, ?, ?, ?, ?)",
                   testInteger, testString, testDouble, testBlob, nil]), @"Could not insert row");
    
    /* Query the data */
    result = [_db executeQuery: @"SELECT * FROM test"];
    STAssertTrue([result next], @"No rows returned");
    
    STAssertTrue([testInteger isEqual: [result objectForColumn: @"a"]], @"Did not return correct integer value");
    STAssertTrue([testString isEqual: [result objectForColumn: @"b"]], @"Did not return correct string value");
    STAssertTrue([testDouble isEqual: [result objectForColumn: @"c"]], @"Did not return correct double value");
    STAssertTrue([testBlob isEqual: [result objectForColumn: @"d"]], @"Did not return correct data value");
    STAssertTrue(nil == [result objectForColumn: @"e"], @"Did not return correct NSNull value");
}

@end
