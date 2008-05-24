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

@interface PLSqliteEntityDialectTests : SenTestCase {
@private
    PLSqliteDatabase *_db;
    PLSqliteEntityDialect *_dialect;
}
@end

@implementation PLSqliteEntityDialectTests

- (void) setUp {
    _dialect = [[PLSqliteEntityDialect alloc] init];
    
    _db = [[PLSqliteDatabase alloc] initWithPath: @":memory:"];
    STAssertTrue([_db open], @"Couldn't open in-memory database");

    STAssertTrue([_db executeUpdate: @"CREATE TABLE Test ("
                  "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                  "name VARCHAR(255))"], @"Could not create Test table");

}

- (void) tearDown {
    [_db release];
    [_dialect release];
}

- (void) testLastInsertIdentity {
    NSObject<PLResultSet> *result;
    int32_t rowId;
    
    STAssertTrue([_dialect supportsLastInsertIdentity], nil);
    STAssertNotNil([_dialect lastInsertIdentity], nil);

    STAssertTrue(([_db executeUpdate: @"INSERT INTO Test (name) VALUES (?)", @"Johnny"]), @"INSERT failed");
    result = [_db executeQuery: [NSString stringWithFormat: @"SELECT %@", [_dialect lastInsertIdentity]]];

    STAssertNotNil(result, @"Identity query failed");
    STAssertTrue([result next], @"No identity results returned");

    /* Get the row ID */
    rowId = [result intForColumnIndex: 0];
    [result close];

    /* Try to fetch the value back out again */
    result = [_db executeQuery: @"SELECT name FROM Test WHERE id = ?", [NSNumber numberWithInt: rowId]];
    STAssertNotNil(result, @"Select query failed");
    STAssertTrue([result next], @"Query returned no rows");
    STAssertTrue([@"Johnny" isEqual: [result stringForColumn: @"name"]], @"Returned row incorrect");
}

@end
