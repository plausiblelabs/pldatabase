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

/* Keep trying for up to 10 minutes. We do not modify the busy timeout handler. */
#define PL_SQLITE_BUSY_TIMEOUT 10 * 60 * 1000


/** A generic SQLite exception. */
NSString *PLSqliteException = @"PLSqliteException";


@interface PLSqliteDatabase (PLSqliteDatabasePrivate)

- (id<PLPreparedStatement>) prepareStatement: (NSString *) statement error: (NSError **) outError closeAtCheckin: (BOOL) closeAtCheckin;

@end


/**
 * An SQLite PLDatabase driver.
 *
 * @par Thread Safety
 * PLSqliteDatabase instances implement no locking and must not be shared between threads
 * without external synchronization.
 */
@implementation PLSqliteDatabase

/**
 * Creates and returns an SQLite database with the provided
 * file path.
 */
+ (id) databaseWithPath: (NSString *) dbPath {
    return [[[self alloc] initWithPath: dbPath] autorelease];
}

/**
 * Initialize the SQLite database with the provided
 * file path.
 *
 * @param dbPath Path to the sqlite database file.
 *
 * @par Designated Initializer
 * This method is the designated initializer for the PLSqliteDatabase class.
 */
- (id) initWithPath: (NSString*) dbPath {
    if ((self = [super init]) == nil)
        return nil;

    _path = [dbPath retain];
    
    return self;
}

/* GC */
- (void) finalize {
    [self close];

    [super finalize];
}

/* Manual */
- (void) dealloc {
    [self close];

    /* Release our backing path */
    [_path release];

    [super dealloc];
}


/**
 * Open the database connection. May be called once and only once.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) open {
    return [self openAndReturnError: NULL];
}


/**
 * Opens the database connection, and returns any errors. May
 * be called once and only once.
 *
 * @param error A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the database could
 * not be opened. If no error occurs, this parameter will be left unmodified.
 * You may specify NULL for this parameter, and no error information will be provided.
 *
 * @return YES if the database was successfully opened, NO on failure.
 */
- (BOOL) openAndReturnError: (NSError **) error {
    int err;

    /* Do not call open twice! */
    if (_sqlite != NULL)
        [NSException raise: PLSqliteException format: @"Attempted to open already-open SQLite database instance at '%@'. Called -[PLSqliteDatabase open] twice?", _path];
    
    /* Open the database */
    err = sqlite3_open([_path fileSystemRepresentation], &_sqlite);
    if (err != SQLITE_OK) {
        [self populateError: error 
              withErrorCode: PLDatabaseErrorFileNotFound 
                description: NSLocalizedString(@"The SQLite database file could not be found.", @"")
                queryString: nil];
        return NO;
    }
    
    /* Set a busy timeout */
    err = sqlite3_busy_timeout(_sqlite, PL_SQLITE_BUSY_TIMEOUT);
    if (err != SQLITE_OK) {
        /* This should never happen. */
        [self populateError: error
              withErrorCode: PLDatabaseErrorUnknown
                description: NSLocalizedString(@"The SQLite database busy timeout could not be set due to an internal error.", @"")
                queryString: nil];
        return NO;
    }
    
    /* Success */
    return YES;
}

/* from PLDatabase. */
- (BOOL) goodConnection {
    /* If the connection wasn't opened, we have our answer */
    if (_sqlite == NULL)
        return NO;
    
    return YES;
}

/**
 * Returns a borrowed reference to the underlying SQLite3 database handle.
 * If the database has not yet been opened, this method will return NULL.
*/
- (sqlite3 *) sqliteHandle {
    return _sqlite;
}

/* From PLDatabase */
- (void) close {
    int err;
    
    if (_sqlite == NULL)
        return;
    
    /* Close the connection and release any sqlite resources (if open was ever called) */
    err = sqlite3_close(_sqlite);
    
    /* Leaking prepared statements is programmer error, and is the only cause for SQLITE_BUSY */
    if (err == SQLITE_BUSY)
        [NSException raise: PLSqliteException format: @"The SQLite database at '%@' can not be closed, as the implementation has leaked prepared statements", _path];
    
    /* Unexpected! This should not happen */
    if (err != SQLITE_OK)
        NSLog(@"Unexpected error closing SQLite database at '%@': %s", sqlite3_errmsg(_sqlite));
    
    /* Reset the variable. If any of the above failed, it is programmer error. */
    _sqlite = NULL;
}


/* from PLDatabase */
- (id<PLPreparedStatement>) prepareStatement: (NSString *) statement {
    return [self prepareStatement: statement error: NULL];
}


/* from PLDatabase */
- (id<PLPreparedStatement>) prepareStatement: (NSString *) statement error: (NSError **) outError {
    return [self prepareStatement: statement error: outError closeAtCheckin: NO];
}

/**
 * @internal
 * Utility method to convert an va_list of objects to an NSArray
 */
- (NSArray *) arrayWithVaList: (va_list) ap count: (int) count {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity: count];
    
    /* Iterate over count and create our array */
    for (int i = 0; i < count; i++) {
        id obj;

        /* Fetch value -- handle nil */
        obj = va_arg(ap, id);
        if (obj == nil)
            obj = [NSNull null];
        
        [result addObject: obj];
    }
    
    return result;
}

#pragma mark Execute Update

/* varargs version */
- (BOOL) executeUpdateAndReturnError: (NSError **) error statement: (NSString *) statement args: (va_list) args {
    id<PLPreparedStatement> stmt;
    BOOL ret;
    
    /* Create the statement */
    stmt = [self prepareStatement: statement error: error];
    if (stmt == nil)
        return NO;
    
    /* Bind the arguments and execute the update */
    [stmt bindParameters: [self arrayWithVaList: args count: [stmt parameterCount]]];
    ret = [stmt executeUpdateAndReturnError: error];

    /* Close the statement */
    [stmt close];

    return ret;
}

/* from PLDatabase. */
- (BOOL) executeUpdateAndReturnError: (NSError **) error statement: (NSString *) statement, ... {
    BOOL ret;
    va_list ap;
    
    va_start(ap, statement);
    ret = [self executeUpdateAndReturnError: error statement: statement args: ap];
    va_end(ap);
    
    return ret;
}

/* from PLDatabase. */
- (BOOL) executeUpdate: (NSString *) statement, ... {
    BOOL ret;
    va_list ap;
    
    va_start(ap, statement);
    ret = [self executeUpdateAndReturnError: NULL statement: statement args: ap];
    va_end(ap);
    
    return ret;
}

#pragma mark Execute Query

/* varargs version */
- (id<PLResultSet>) executeQueryAndReturnError: (NSError **) error statement: (NSString *) statement args: (va_list) args {
    id<PLResultSet> result;
    id<PLPreparedStatement> stmt;
    
    /* Create the statement */
    stmt = [self prepareStatement: statement error: error closeAtCheckin: YES];
    if (stmt == nil)
        return NO;
    
    /* Bind the arguments */
    [stmt bindParameters: [self arrayWithVaList: args count: [stmt parameterCount]]];
    result = [stmt executeQueryAndReturnError: error];
    
    return result;
}


- (id<PLResultSet>) executeQueryAndReturnError: (NSError **) error statement: (NSString *) statement, ... {
    id<PLResultSet> result;
    va_list ap;
    
    va_start(ap, statement);
    result = [self executeQueryAndReturnError: error statement: statement args: ap];
    va_end(ap);
    
    return result;
}


/* from PLDatabase. */
- (id<PLResultSet>) executeQuery: (NSString *) statement, ... {
    id<PLResultSet> result;
    va_list ap;
    
    va_start(ap, statement);
    result = [self executeQueryAndReturnError: NULL statement: statement args: ap];
    va_end(ap);
    
    return result;
}


#pragma mark Transactions

/* from PLDatabase. */
- (BOOL) beginTransaction {
    return [self beginTransactionAndReturnError: NULL];
}

/* from PLDatabase */
- (BOOL) beginTransactionAndReturnError: (NSError **) error {
    return [self executeUpdateAndReturnError: error statement: @"BEGIN DEFERRED"];
}


/* from PLDatabase. */
- (BOOL) commitTransaction {
    return [self commitTransactionAndReturnError: NULL];
}

/* from PLDatabase */
- (BOOL) commitTransactionAndReturnError: (NSError **) error {
    return [self executeUpdateAndReturnError: error statement: @"COMMIT"];
}


/* from PLDatabase. */
- (BOOL) rollbackTransaction {
    return [self rollbackTransactionAndReturnError: NULL];
}

/* from PLDatabase */
- (BOOL) rollbackTransactionAndReturnError: (NSError **) error {
    return [self executeUpdateAndReturnError: error statement: @"ROLLBACK"];
}


#pragma mark Metadata


/* from PLDatabase */
- (BOOL) tableExists: (NSString *) tableName {
    id<PLResultSet> rs;
    BOOL exists;

    /* If there are any results, the table exists */
    rs = [self executeQuery: @"SELECT name FROM SQLITE_MASTER WHERE name = ? and type = ?", tableName, @"table"];
    exists = [rs next];
    [rs close];

    return exists;
}

/**
 * Returns the row ID of the most recent successful INSERT. If the table
 * has a column of type INTEGER PRIMARY KEY, then the value assigned will
 * be an alias for the row ID.
 *
 * @return Returns the row ID (integer primary key) of the most recent successful INSERT.
 */
- (int64_t) lastInsertRowId {
    return sqlite3_last_insert_rowid(_sqlite);
}

@end

#pragma mark Library Private

/**
 * @internal
 *
 * Library Private PLSqliteDatabase methods
 */
@implementation PLSqliteDatabase (PLSqliteDatabaseLibraryPrivate)

/**
 * @internal
 * Return the last error code encountered by the underlying sqlite database.
 */
- (int) lastErrorCode {
    return sqlite3_errcode(_sqlite);
}


/**
 * @internal
 * Return the last error message encountered by the underlying sqlite database.
 */
- (NSString *) lastErrorMessage {
    return [NSString stringWithUTF8String: sqlite3_errmsg(_sqlite)];
}


/**
 * @internal
 *
 * Populate an NSError (if not nil) and log it, filling in the last database error code and message.
 *
 * @param error Pointer to NSError instance to populate. If nil, the error message will be logged instead.
 * @param errorCode A PLDatabaseError error code.
 * @param description A localized description of the error message.
 * @param queryString The optional SQL query which caused the error.
 */
- (void) populateError: (NSError **) error withErrorCode: (PLDatabaseError) errorCode
           description: (NSString *) localizedDescription queryString: (NSString *) queryString
{
    NSString *vendorString = [self lastErrorMessage];
    NSNumber *vendorError = [NSNumber numberWithInt: [self lastErrorCode]];
    NSError *result;
    
    /* Create the error */
    result = [PlausibleDatabase errorWithCode: errorCode
                         localizedDescription: localizedDescription
                                  queryString: queryString
                                  vendorError: vendorError
                            vendorErrorString: vendorString];    

    if (queryString == nil)
        queryString = @"<none>";
    
    /* Log it and optionally return it */
    NSLog(@"A SQLite database error occurred on database '%@': %@ (SQLite #%@: %@) (query: '%@')", 
          _path, result, vendorError, vendorString, queryString);
    
    if (error != NULL)
        *error = result;
}

/**
 * @internal
 *
 * Create an SQLite statement, returning NULL on error.
 *
 * This method is intended to be used only by PLSqlitePreparedStatement, for the purpose of re-creating prepared statements.
 * This method is only exposed for the purpose of supporting implementations missing sqlite3_prepare_v2(), and should be
 * made class-private if support for SQLite 3.0.9 or earlier is dropped.
 *
 * @warning MEMORY OWNERSHIP WARNING: The returned statement is owned by the caller, and MUST be free'd using sqlite3_finalize().
 *
 * @param statement SQLite statement string
 * @param error A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the statement could
 * not be created. If no error occurs, this parameter will be left unmodified.
 * You may specify nil for this parameter, and no error information will be provided.
 */
- (sqlite3_stmt *) createStatement: (NSString *) statement error: (NSError **) error {
    sqlite3_stmt *sqlite_stmt;
    const char *unused;
    int ret;
    
    /* Prepare. The V2 interface is only available in SQLite 3.3.9 and later, which was released in January of 2004.
     * Mac OS X 10.4 ships with 3.1.3.
     *
     * The V2 interface differs in two ways (from the SQLite documentation):
     *
     * 1. If the database schema changes, instead of returning SQLITE_SCHEMA as it always
     * used to do, sqlite3_step() will automatically recompile the SQL statement and try
     * to run it again. If the schema has changed in a way that makes the statement no
     * longer valid, sqlite3_step() will still return SQLITE_SCHEMA. But unlike the legacy
     * behavior, SQLITE_SCHEMA is now a fatal error. Calling sqlite3_prepare_v2() again
     * will not make the error go away. Note: use sqlite3_errmsg() to find the text of the
     * parsing error that results in an SQLITE_SCHEMA return.
     *
     * 2. When an error occurs, sqlite3_step() will return one of the detailed error codes or
     * extended error codes. The legacy behavior was that sqlite3_step() would only return a generic
     * SQLITE_ERROR result code and you would have to make a second call to sqlite3_reset() in
     * order to find the underlying cause of the problem. With the "v2" prepare interfaces, the
     * underlying reason for the error is returned immediately.
     */
#ifdef PL_SQLITE_LEGACY_STMT_PREPARE
    ret = sqlite3_prepare(_sqlite, [statement UTF8String], -1, &sqlite_stmt, &unused);
#else
    ret = sqlite3_prepare_v2(_sqlite, [statement UTF8String], -1, &sqlite_stmt, &unused);
#endif
    
    /* Prepare failed */
    if (ret != SQLITE_OK) {
        [self populateError: error
              withErrorCode: PLDatabaseErrorInvalidStatement
                description: NSLocalizedString(@"An error occured parsing the provided SQL statement.", @"")
                queryString: statement];
        return NULL;
    }
    
    /* Multiple statements were provided */
    if (*unused != '\0') {
        [self populateError: error
              withErrorCode: PLDatabaseErrorInvalidStatement
                description: NSLocalizedString(@"Multiple SQL statements were provided for a single query.", @"")
                queryString: statement];
        return NULL;
    }
    
    return sqlite_stmt;
}

@end


#pragma mark Private

/**
 * @internal
 *
 * Private PLSqliteDatabase methods.
 */
@implementation PLSqliteDatabase (PLSqliteDatabasePrivate)


/**
 * @internal
 *
 * Prepare and return a new PLPreparedStatement. If closeAtCheckin is YES, the statement
 * will be closed upon the first checkin from its child PLSqliteResultSet. This should
 * only be used when returning a result set directly to an API client, in which case the statement
 * is not available and can not otherwise be explicitly closed.
 */
- (id<PLPreparedStatement>) prepareStatement: (NSString *) statement error: (NSError **) outError closeAtCheckin: (BOOL) closeAtCheckin {
    sqlite3_stmt *sqlite_stmt;
    
    /* Prepare our statement */
    sqlite_stmt = [self createStatement: statement error: outError];
    if (sqlite_stmt == NULL)
        return nil;
    
    /* Create a new prepared statement.
     *
     * MEMORY OWNERSHIP WARNING:
     * We pass our sqlite3_stmt reference to the PLSqlitePreparedStatement, which now must assume authority for releasing
     * that statement using sqlite3_finalize(). */
    return [[[PLSqlitePreparedStatement alloc] initWithDatabase: self sqliteStmt: sqlite_stmt queryString: statement closeAtCheckin: closeAtCheckin] autorelease];
}

@end