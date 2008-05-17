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

#import "PlausibleDatabase.h"


/**
 * @internal
 * SQLite prepared query implementation.
 */
@implementation PLSqlitePreparedStatement

/**
 * Initialize the prepared statement with an open database and an sqlite3 prepared statement.
 *
 * MEMORY OWNERSHIP WARNING:
 * We are passed an sqlite3_stmt reference which now we now assume authority for releasing
 * that statement using sqlite3_finalize().
 */
- (id) initWithDatabase: (PLSqliteDatabase *) db sqliteStmt: (sqlite3_stmt *) sqlite_stmt {
    if ((self = [super init]) == nil)
        return nil;

    /* Save our database and statement reference. */
    _database = [db retain];
    _sqlite_stmt = sqlite_stmt;

    return self;
}


/* GC */
- (void) finalize {
    /* The statement must be released before the databse is released, as the statement has a reference
     * to the database which would cause a SQLITE_BUSY error when the database is released. */
    [self close];
    
    [super finalize];
}

/* Manual */
- (void) dealloc {
    /* The statement must be released before the database is released, as the statement has a reference
     * to the database which would cause a SQLITE_BUSY error when the database is released. */
    [self close];

    /* Now release the database. */
    [_database release];
    
    [super dealloc];
}

- (void) close {
    if (_sqlite_stmt == nil)
        return;
    
    /* The finalization may return the last error returned by sqlite3_next(), but this has already
     * been handled by the -[PLSqliteResultSet next] implementation. Any remaining memory and
     * resources are released regardless of the error code, so we do not check it here. */
    sqlite3_finalize(_sqlite_stmt);
}


@end
