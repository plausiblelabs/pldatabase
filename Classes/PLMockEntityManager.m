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

#import "PlausibleDatabase.h"
#import "PLMockEntityManager.h"

/**
 * @internal
 *
 * Creates a testing-only entity manager, backed by a real, empty (embedded) database.
 */
@implementation PLMockEntityManager

/**
 * @internal
 *
 * @par Designated Initializer
 * This method is the designated initializer for the PLMockEntityManager class.
 */
- (id) init {
    PLSqliteEntityConnectionDelegate *connectionDelegate;
    PLSqliteEntityDialect *sqlDialect;
    NSString *path;
    
    /* Create a temporary file for the database. Secure -- user owns enclosing directory. */
    path = [NSTemporaryDirectory() stringByAppendingPathComponent: [[NSProcessInfo processInfo] globallyUniqueString]];

    /* Set up our supporting classes */
    connectionDelegate = [[[PLSqliteEntityConnectionDelegate alloc] initWithPath: path] autorelease];
    sqlDialect = [[[PLSqliteEntityDialect alloc] init] autorelease];

    /* Initialized our superclass */
    self = [super initWithConnectionDelegate: connectionDelegate sqlDialect: sqlDialect];
    if (self == nil)
        return nil;

    /* Need to delete this on cleanup */
    _dbPath = [path retain];

    return self;
}

- (void) dealloc {
    /* Remove the temporary database file */
    if (![[NSFileManager defaultManager] removeItemAtPath: _dbPath error: nil])
        NSLog(@"Could not delete PLMockEntityManager temporary database"); 

    [_dbPath release];

    [super dealloc];
}


/**
 * @internal
 * Return a new unopen connection to the backing database.
 */
- (PLSqliteDatabase *) database {
    return [PLSqliteDatabase databaseWithPath: _dbPath];
}

@end
