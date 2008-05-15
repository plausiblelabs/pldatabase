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
    NSString *_dbPath;
    PLSqliteDatabase *_db;

    NSObject<PLEntityDialect> *_dialect;
    
    PLEntityManager *_manager;
}
@end

@implementation PLEntityManagerTests

- (void) setUp {
    PLSqliteEntityConnectionDelegate *delegate;
    PLSqliteEntityDialect *dialect;
    
    /* Create a temporary file for the database. Secure -- user owns enclosing directory. */
    _dbPath = [[NSTemporaryDirectory() stringByAppendingPathComponent: [[NSProcessInfo processInfo] globallyUniqueString]] retain];
    
    /* Create the temporary database and populate it with some data */
    _db = [[PLSqliteDatabase alloc] initWithPath: _dbPath];
    STAssertTrue([_db open], @"Could not open temporary database");
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE Test ("
           "id INTEGER PRIMARY KEY AUTOINCREMENT,"
           "name VARCHAR(255))"], @"Could not create test table");

    /* Create an entity manager */
    delegate = [[[PLSqliteEntityConnectionDelegate alloc] initWithPath: _dbPath] autorelease];
    dialect = [[[PLSqliteEntityDialect alloc] init] autorelease];
    _manager = [[PLEntityManager alloc] initWithConnectionDelegate: delegate entityDialect: dialect];
}

- (void) tearDown {
    /* Remove the temporary database file */
    STAssertTrue([[NSFileManager defaultManager] removeItemAtPath: _dbPath error: nil], @"Could not clean up database %@", _dbPath);

    /* Release our objects */
    [_dbPath release];
    [_db release];
    [_manager release];
}

- (void) testInitWithDatabase {
    PLEntityManager *entityManager;
    PLSqliteEntityDialect *dialect;
    PLSqliteEntityConnectionDelegate *delegate;
    
    /* Set up a delegate and dialect */
    delegate = [[[PLSqliteEntityConnectionDelegate alloc] initWithPath: _dbPath] autorelease];
    dialect = [[[PLSqliteEntityDialect alloc] init] autorelease];

    /* Create the entity manager */
    entityManager = [[[PLEntityManager alloc] initWithConnectionDelegate: delegate entityDialect: dialect] autorelease];
    STAssertNotNil(entityManager, @"Could not initialize entity manager");
}


@end
