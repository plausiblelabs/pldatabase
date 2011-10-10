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
#import "PLSqliteConnectionProvider.h"

@interface PLSqliteConnectionProviderTests : SenTestCase {
@private
    NSString *_dbPath;
}
@end

@implementation PLSqliteConnectionProviderTests

- (void) setUp {
    /* Create a temporary file for the database. Secure -- user owns enclosing directory. */
    _dbPath = [[NSTemporaryDirectory() stringByAppendingPathComponent: [[NSProcessInfo processInfo] globallyUniqueString]] retain];
}

- (void) tearDown {
    /* Remove the temporary database file */
    if ([[NSFileManager defaultManager] fileExistsAtPath: _dbPath])
        STAssertTrue([[NSFileManager defaultManager] removeItemAtPath: _dbPath error: NULL], @"Could not clean up database %@", _dbPath);

    /* Release our objects */
    [_dbPath release];
}

- (void) testInitWithFlags {
    PLSqliteConnectionProvider *provider;
    id<PLDatabase> db;
    NSError *error;

    /* Create our delegate and request a connection, verifying that it is created */
    provider = [[[PLSqliteConnectionProvider alloc] initWithPath: _dbPath flags: SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE] autorelease];
    db = [provider getConnectionAndReturnError: &error];
    
    /* Test the connection */
    STAssertNotNil(db, @"Delegate returned nil: %@", error);
    STAssertTrue([db goodConnection], @"Database connection claims to be bad.");
    
    /* Try to be polite */
    [provider closeConnection: db];
    STAssertFalse([db goodConnection], @"Connection should be closed");
    STAssertTrue([[NSFileManager defaultManager] removeItemAtPath: _dbPath error: NULL], @"Could not clean up database %@", _dbPath);
    
    /* Create our second provider -- the lack of SQLITE_OPEN_CREATE should ensure that opening the connection fails,
     * as the database does not exist. */
    provider = [[[PLSqliteConnectionProvider alloc] initWithPath: _dbPath flags: SQLITE_OPEN_READWRITE] autorelease];
    db = [provider getConnectionAndReturnError: NULL];
    STAssertNil(db, @"Database open flag was not specified -- provider created a database even though SQLITE_OPEN_CREATE|SQLITE_OPEN_EXCLUSIVE was set");
}

- (void) testInitWithPath {
    PLSqliteConnectionProvider *provider;
    id<PLDatabase> db;

    /* Create our delegate and request a connection */
    provider = [[[PLSqliteConnectionProvider alloc] initWithPath: _dbPath] autorelease];
    db = [provider getConnectionAndReturnError: NULL];

    /* Test the connection */
    STAssertNotNil(db, @"Delegate returned nil.");
    STAssertTrue([db goodConnection], @"Database connection claims to be bad.");

    /* Try to be polite */
    [provider closeConnection: db];
    STAssertFalse([db goodConnection], @"Connection should be closed");
}

@end
