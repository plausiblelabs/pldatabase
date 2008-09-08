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

#import "PlausibleDatabase.h"

@interface PLSqlBuilderTests : SenTestCase {
@private
    PLSqliteDatabase *_db;
    PLSqlBuilder *_sqlBuilder;
}
@end

@implementation PLSqlBuilderTests

- (void) setUp {
    PLSqliteEntityDialect *dialect;
    
    /* Set up the database */
    _db = [[PLSqliteDatabase alloc] initWithPath: @":memory:"];    
    STAssertTrue([_db open], @"Could not open memory database");
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test ("
                  "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                  "name VARCHAR(255),"
                  "age INTEGER)"], @"Could not create test table");

    /* Set up the SQL builder */
    dialect = [[[PLSqliteEntityDialect alloc] init] autorelease];
    _sqlBuilder = [[PLSqlBuilder alloc] initWithDatabase: _db dialect: dialect];
}

- (void) tearDown {
    [_db release];
    [_sqlBuilder release];
}

- (void) testInsertForTable {
    NSObject<PLPreparedStatement> *stmt;
    NSMutableDictionary *values;
    NSError *error;

    /* Set up the values we want to insert */
    values = [NSMutableDictionary dictionaryWithCapacity: 2];
    [values setObject: @"Jacob" forKey: @"name"];
    [values setObject: [NSNumber numberWithInt: 42] forKey: @"age"];

    /* Create the prepared statement for the columns */
    stmt = [_sqlBuilder insertForTable: @"test" withColumns: [values allKeys] error: &error];
    STAssertNotNil(stmt, @"Prepared statement creation failed: %@", error);

    STAssertEquals(2, [stmt parameterCount], @"Parameter count on prepared statement incorrect");

    /* Try binding our values and executing */
    [stmt bindParameterDictionary: values];
    STAssertTrue([stmt executeUpdateAndReturnError: &error], @"Statement execution failed: %@", error);

    /* Now finally, try fetching our data back out again */
    NSObject<PLResultSet> *rs;
    rs = [_db executeQueryAndReturnError: &error statement: @"SELECT * FROM test WHERE name = ?", @"Jacob"];
    STAssertNotNil(rs, @"Could not execute query: %@", error);
    STAssertTrue([rs next], @"No results returned");

    STAssertTrue([@"Jacob" isEqual: [rs stringForColumn: @"name"]], @"Unexpected name value");
    STAssertEquals(42, [rs intForColumn: @"age"], @"Unexpected age value");
}


- (void) testSelectLastInsertForTable {
    NSObject<PLPreparedStatement> *stmt;
    NSObject<PLResultSet> *rs;
    NSError *error;

    /* Execute an INSERT */
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (name, age) VALUES (?, ?)", @"Jacob", [NSNumber numberWithInt: 42]]), @"INSERT failed");

    /* Create the query and fetch the data back out */
    stmt = [_sqlBuilder selectLastInsertForTable: @"test" withColumns: [NSArray arrayWithObjects: @"id", @"name", @"age", nil] primaryKey: @"id" error: &error];
    STAssertNotNil(stmt, @"Prepared statement creation failed: %@", error);
    rs = [stmt executeQueryAndReturnError: &error];
    STAssertNotNil(rs, @"Could note execute query: %@", error);
    STAssertTrue([rs next], @"No results returned");

    STAssertFalse([rs isNullForColumn: @"id"], @"Id column was not populated");
    STAssertTrue([@"Jacob" isEqual: [rs stringForColumn: @"name"]], @"Unexpected name value");
    STAssertEquals(42, [rs intForColumn: @"age"], @"Unexpected age value");
}

- (void) testSelectForTable {
    NSObject<PLPreparedStatement> *stmt;
    NSObject<PLResultSet> *rs;
    NSError *error;
    
    /* Execute an INSERT */
    STAssertTrue(([_db executeUpdateAndReturnError: &error statement: @"INSERT INTO test (id, name, age) VALUES (?, ?, ?)", [NSNumber numberWithInt: 1], @"Jacob", [NSNumber numberWithInt: 42]]), @"INSERT failed: %@", error);
    
    /* Create the query and fetch the data back out */
    stmt = [_sqlBuilder selectForTable: @"test" withColumns: [NSArray arrayWithObjects: @"id", @"name", @"age", nil] primaryKeys: [NSArray arrayWithObjects: @"id", nil] error: &error];
    [stmt bindParameterDictionary: [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt: 1], @"id", nil]];
    
    STAssertNotNil(stmt, @"Prepared statement creation failed: %@", error);
    rs = [stmt executeQueryAndReturnError: &error];
    STAssertNotNil(rs, @"Could note execute query: %@", error);
    STAssertTrue([rs next], @"No results returned");
    
    STAssertEquals([rs intForColumn: @"id"], 1, @"Id column incorrect");
    STAssertTrue([@"Jacob" isEqual: [rs stringForColumn: @"name"]], @"Unexpected name value");
    STAssertEquals(42, [rs intForColumn: @"age"], @"Unexpected age value");
}


- (void) testDeleteForTable {
    NSObject<PLPreparedStatement> *stmt;
    NSMutableDictionary *values;
    NSArray *primaryKeys;
    NSError *error;
    NSNumber *rowId;
    
    /* Define the primary keys */
    primaryKeys = [NSArray arrayWithObjects: @"id", nil];
    
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (name, age) VALUES (?, ?)", @"Jacob", [NSNumber numberWithInt: 42]]), @"Could not insert row");
    rowId = [NSNumber numberWithInt:[_db lastInsertRowId]];
    
    /* Create the prepared statement */
    stmt = [_sqlBuilder deleteForTable: @"test" primaryKeys: primaryKeys error: &error];
    STAssertNotNil(stmt, @"Prepared statement creation failed: %@", error);
    
    /* Set up the values we want to delete */
    values = [NSMutableDictionary dictionaryWithCapacity: 1];
    [values setObject: rowId forKey: @"id"];
    
    /* Try binding our values and executing */
    [stmt bindParameterDictionary: values];
    STAssertTrue([stmt executeUpdateAndReturnError: &error], @"Statement execution failed: %@", error);
    
    /* Now finally, try fetching our data back out again and verifying the delete happened */
    NSObject<PLResultSet> *rs;
    rs = [_db executeQueryAndReturnError: &error statement: @"SELECT * FROM test WHERE id = ?", rowId];
    STAssertNotNil(rs, @"Could not execute query: %@", error);
    STAssertFalse([rs next], @"Unexpected result returned");
}

- (void) testDeleteForTableMultiplePrimaryKeys {
    NSObject<PLPreparedStatement> *stmt;
    NSMutableDictionary *primaryValues;
    NSArray *primaryKeys;
    NSError *error;
        
    /* Add a table with two primary keys */
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test_two_keys ("
                  "firstId INTEGER,"
                  "secondId INTEGER,"
                  "name VARCHAR(255),"
                  "age INTEGER, PRIMARY KEY (firstId, secondId))"], @"Could not create test table");
    
    /* Define the primary keys */
    primaryKeys = [NSArray arrayWithObjects: @"firstId", @"secondId", nil];
    
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test_two_keys (firstId, secondId, name, age) VALUES (?, ?, ?, ?)",
                   [NSNumber numberWithInt: 1], [NSNumber numberWithInt: 100], @"Jacob", [NSNumber numberWithInt: 42]]), @"Could not insert row");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test_two_keys (firstId, secondId, name, age) VALUES (?, ?, ?, ?)",
                   [NSNumber numberWithInt: 2], [NSNumber numberWithInt: 100], @"Marley", [NSNumber numberWithInt: 24]]), @"Could not insert row");
    
    /* Create the prepared statement */
    stmt = [_sqlBuilder deleteForTable: @"test_two_keys" primaryKeys: primaryKeys error: &error];
    STAssertNotNil(stmt, @"Prepared statement creation failed: %@", error);
    
    /* Set up the values we want to delete */
    primaryValues = [NSMutableDictionary dictionaryWithCapacity: 2];
    [primaryValues setObject: [NSNumber numberWithInt: 1] forKey: @"firstId"];
    [primaryValues setObject: [NSNumber numberWithInt: 100] forKey: @"secondId"];
    
    /* Try binding our values and executing */
    [stmt bindParameterDictionary: primaryValues];
    STAssertTrue([stmt executeUpdateAndReturnError: &error], @"Statement execution failed: %@", error);
    
    /* Now finally, try fetching our data back out again and verifying the delete happened */
    NSObject<PLResultSet> *rs;
    rs = [_db executeQueryAndReturnError: &error statement: @"SELECT * FROM test_two_keys WHERE firstId = ? AND secondId = ?",
          [NSNumber numberWithInt: 1], [NSNumber numberWithInt: 100]];
    STAssertNotNil(rs, @"Could not execute query: %@", error);
    STAssertFalse([rs next], @"Unexpected result returned");
    
    /* Verify the other row was untouched */
    rs = [_db executeQueryAndReturnError: &error statement: @"SELECT * FROM test_two_keys WHERE firstId = ? AND secondId = ?",
          [NSNumber numberWithInt: 2], [NSNumber numberWithInt: 100]];
    STAssertNotNil(rs, @"Could not execute query: %@", error);
    STAssertTrue([rs next], @"No results returned");
}

@end
