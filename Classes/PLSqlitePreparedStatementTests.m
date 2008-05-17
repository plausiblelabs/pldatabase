/*
 * Copyright (c) 2008 Plausible Labs.
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

@interface PLSqlitePreparedStatementTests : SenTestCase {
@private
    PLSqliteDatabase *_db;
}

@end

@implementation PLSqlitePreparedStatementTests

- (void) setUp {
    _db = [[PLSqliteDatabase alloc] initWithPath: @":memory:"];
    STAssertTrue([_db open], @"Couldn't open the test database");

    STAssertTrue([_db executeUpdate: @"CREATE TABLE test ("
                  "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                  "name VARCHAR(255),"
                  "color VARCHAR(255))"],
                 @"Could not create test table");
}

- (void) tearDown {
    [_db release];
}


/* Test handling of all supported parameter data types */
- (void) testParameterBinding {
    NSObject<PLPreparedStatement> *stmt;

    /* Create the data table */
    STAssertTrue([_db executeUpdate: @"CREATE TABLE data ("
           "intval int,"
           "int64val int,"
           "stringval varchar(30),"
           "nilval int,"
           "floatval float,"
           "doubleval double precision,"
           "dateval double precision,"
           "dataval blob"
           ")"], @"Could not create table");

    /* Prepare the insert statement */
    stmt = [_db prepareStatement: @"INSERT INTO data (intval, int64val, stringval, nilval, floatval, doubleval, dateval, dataval)"
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?)"];
    STAssertNotNil(stmt, @"Could not create statement");
    
    /* Some example data */
    NSDate *now = [NSDate date];
    const char bytes[] = "This is some example test data";
    NSData *data = [NSData dataWithBytes: bytes length: sizeof(bytes)];

    /* Create our parameter list */
    NSArray *values = [NSArray arrayWithObjects:
        [NSNumber numberWithInt: 42],
        [NSNumber numberWithLongLong: INT64_MAX],
        @"test",
        [NSNull null],
        [NSNumber numberWithFloat: 3.14],
        [NSNumber numberWithDouble: 3.14159],
        now,
        data,
        nil
    ];
    
    /* Bind our values */
    STAssertTrue([stmt bindParameters: values error: nil], @"Could not bind parameters");

#if 0
	NSObject<PLResultSet> *rs;
	BOOL ret;
    
	/* Create the test table */
    ret = [_db executeUpdate: @"CREATE TABLE test ("
           "intval int,"
           "int64val int,"
           "stringval varchar(30),"
           "nilval int,"
           "floatval float,"
           "doubleval double precision,"
           "dateval double precision,"
           "dataval blob"
           ")"];
	STAssertTrue(ret, nil);
    
	/* Insert the test data */
    ret = [_db executeUpdate: @"INSERT INTO test "
           "(intval, int64val, stringval, nilval, floatval, doubleval, dateval, dataval)"
           "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
		   [NSNumber numberWithInt: 42],
           [NSNumber numberWithLongLong: INT64_MAX],
           @"test",
           nil,
           [NSNumber numberWithFloat: 3.14],
           [NSNumber numberWithDouble: 3.14159],
           now,
           data];
	STAssertTrue(ret, nil);
    
	/* Retrieve the data */
    rs = [_db executeQuery: @"SELECT * FROM test WHERE intval = 42"];
    STAssertTrue([rs next], @"No rows returned");
    
    /* NULL value */
    STAssertTrue([rs isNullForColumn: @"nilval"], @"NULL value not returned.");
    
    /* Date value */
    STAssertEquals([now timeIntervalSince1970], [[rs dateForColumn: @"dateval"] timeIntervalSince1970], @"Date value incorrect.");
    
    /* String */
    STAssertTrue([@"test" isEqual: [rs stringForColumn: @"stringval"]], @"String value incorrect.");
    
    /* Integer */
    STAssertEquals(42, [rs intForColumn: @"intval"], @"Integer value incorrect.");
    
    /* 64-bit integer value */
    STAssertEquals(INT64_MAX, [rs bigIntForColumn: @"int64val"], @"64-bit integer value incorrect");
    
    /* Float */
    STAssertEquals(3.14f, [rs floatForColumn: @"floatval"], @"Float value incorrect");
    
    /* Double */
    STAssertEquals(3.14159, [rs doubleForColumn: @"doubleval"], @"Double value incorrect");
    
    /* Data */
    STAssertTrue([data isEqualToData: [rs dataForColumn: @"dataval"]], @"Data value incorrect");
#endif
}

@end
