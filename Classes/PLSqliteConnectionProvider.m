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

#import "PLSqliteConnectionProvider.h"
#import "PLSqliteDatabase.h"

/**
 * Provides new PLSqliteDatabase connections as per the PLDatabaseConnectionProvider
 * protocol. This class does no connection pooling, and should be combined
 * with a generic connection pool implementation if pooling is required.
 *
 * @par Thread Safety
 * Immutable and thread-safe. May be used from any thread.
 */
@implementation PLSqliteConnectionProvider

/*
 * Private initializer.
 *
 * @param dbPath Path to the sqlite database file.
 * @param flags The SQLite-defined flags that will be passed directly to sqlite3_open_v2() or an equivalent API.
 * @return YES if the database was successfully opened, NO on failure.
 * @param useFlags If NO, the @a flags argument will be ignored.
 */
- (id) initWithPath: (NSString *) dbPath flags: (int) flags useFlags: (BOOL) useFlags {
    if ((self = [super init]) == nil)
        return nil;
    
    /* Path to our backing database */
    _dbPath = dbPath;
    _flags = flags;
    _useFlags = useFlags;
    
    return self;
}

/**
 * Initialize the database connection delegate with the provided
 * file path.
 *
 * @param dbPath Path to the sqlite database file.
 */
- (id) initWithPath: (NSString *) dbPath {
    return [self initWithPath: dbPath flags: 0 useFlags: NO];
}

/**
 * Initialize the database connection delegate with the provided
 * file path.
 *
 * @param dbPath Path to the sqlite database file.
 * @param flags The SQLite-defined flags that will be passed directly to sqlite3_open_v2() or an equivalent API.
 * @return YES if the database was successfully opened, NO on failure.
 *
 * @par Supported Flags
 * The flags supported by SQLite are defined in the SQLite C API Documentation:
 * http://www.sqlite.org/c3ref/open.html
 */
- (id) initWithPath: (NSString *) dbPath flags: (int) flags {
    return [self initWithPath: dbPath flags: flags useFlags: YES];
}




// from PLDatabaseConnectionProvider protocol
- (id<PLDatabase>) getConnectionAndReturnError: (NSError **) error {
    PLSqliteDatabase *database;

    /* Create and attempt to open */
    database = [[PLSqliteDatabase alloc] initWithPath: _dbPath];

    /* Open with the correct flags (or the default flags) */
    BOOL ret;
    if (_useFlags) {
        ret = [database openWithFlags: _flags error: error];
    } else {
        ret = [database openAndReturnError: error];
    }

    if (!ret) {
        /* Error was filled in, simply return nil */
        return nil;
    }

    /* All is well, and database connection is open */
    return database;
}


// from PLDatabaseConnectionProvider protocol
- (void) closeConnection: (id<PLDatabase>) connection {
    // Nothing to do besides close the connection, no connection pooling
    [connection close];
}


@end
