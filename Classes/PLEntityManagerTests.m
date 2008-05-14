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

@interface PLEntityManagerTests : SenTestCase {
@private
    NSObject<PLDatabase> *_db;

    NSObject<PLEntityDialect> *_dialect;
}
@end

@implementation PLEntityManagerTests

- (void) setUp {
    PLSqliteDatabase *sqlite;
    BOOL ret;

    /* Create and open test database */
    _db = sqlite = [[PLSqliteDatabase alloc] initWithPath: @":memory:"];
    STAssertTrue([sqlite open], @"Could not open database");

    ret = [_db executeUpdate: @"CREATE TABLE Test ("
           "id INTEGER PRIMARY KEY AUTOINCREMENT,"
           "name VARCHAR(255))"];
    STAssertTrue(ret, @"Could not create test table");

    /* Create a dialect instance */
    _dialect = [[PLSqliteEntityDialect alloc] init];
}

- (void) tearDown {
    [_db release];
    [_dialect release];
}

- (void) testInitWithDatabase {
    PLEntityManager *entityManager;
    
    entityManager = [[[PLEntityManager alloc] initWithDatabase: _db entityDialect: _dialect] autorelease];
    STAssertNotNil(entityManager, @"Could not initialize entity manager");
}

@end
