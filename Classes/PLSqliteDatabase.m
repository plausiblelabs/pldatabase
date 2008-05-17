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

/* Keep trying for up to 5 seconds */
#define SQLITE_BUSY_TIMEOUT 5000


/** A generic SQLite exception. */
NSString *PLSqliteException = @"PLSqliteException";


@interface PLSqliteDatabase (PLSqliteDatabasePrivate)

- (void) populateError: (NSError **) result withErrorCode: (PLDatabaseError) errorCode
           description: (NSString *) localizedDescription queryString: (NSString *) queryString;

- (sqlite3_stmt *) createStatement: (NSString *) statement error: (NSError **) error;

- (int) bindValueForParameter: (sqlite3_stmt *) sqlite_stmt withParameter: (int) parameterIndex withValue: (id) value;

- (void) bindValuesForStatement: (sqlite3_stmt *) sqlite_stmt withArgs: (va_list) args;

@end


/**
 * An SQLite PLDatabase driver.
 *
 * @par Scalary Types
 * All 
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
 */
- (id) initWithPath: (NSString*) dbPath {
    if ((self = [super init]) == nil)
        return nil;

    _path = [dbPath retain];
    
    return self;
}

/* Private shared finalization */
- (void) sharedFinalization {
    int err;

    /* Close the connection and release any sqlite resources (if open was ever called) */
    if (_sqlite != nil) {
        err = sqlite3_close(_sqlite);
        
        /* Leaking prepared statements is programmer error, and is the only cause for SQLITE_BUSY */
        if (err == SQLITE_BUSY)
            [NSException raise: PLSqliteException format: @"The SQLite database at '%@' can not be closed, as the implementation has leaked prepared statements", _path];
        
        /* Unexpected! This should not happen */
        if (err != SQLITE_OK)
            NSLog(@"Unexpected error closing SQLite database at '%@': %s", sqlite3_errmsg(_sqlite));
    }
}

/* GC */
- (void) finalize {
    [self sharedFinalization];

    [super finalize];
}

/* Manual */
- (void) dealloc {
    [self sharedFinalization];

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
    return [self openAndReturnError: nil];
}


/**
 * Opens the database connection, and returns any errors. May
 * be called once and only once.
 *
 * @param error A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the database could
 * not be opened. If no error occurs, this parameter will be left unmodified.
 * You may specify nil for this parameter, and no error information will be provided.
 *
 * @return YES if the database was successfully opened, NO on failure.
 */
- (BOOL) openAndReturnError: (NSError **) error {
    int err;

    /* Do not call open twice! */
    if (_sqlite != nil)
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
    err = sqlite3_busy_timeout(_sqlite, SQLITE_BUSY_TIMEOUT);
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
    if (_sqlite == nil)
        return NO;
    
    return YES;
}


/* from PLDatabase */
- (NSObject<PLPreparedStatement> *) prepareStatement: (NSString *) statement {
    return [self prepareStatement: statement error: nil];
}


/* from PLDatabase */
- (NSObject<PLPreparedStatement> *) prepareStatement: (NSString *) statement error: (NSError **) outError {
    sqlite3_stmt *sqlite_stmt;
    
    /* Prepare our statement */
    sqlite_stmt = [self createStatement: statement error: outError];
    if (sqlite_stmt == nil)
        return nil;

    /* Create a new PLSqliteResultSet statement.
     *
     * MEMORY OWNERSHIP WARNING:
     * We pass our sqlite3_stmt reference to the PLSqlitePreparedStatement, which now must assume authority for releasing
     * that statement using sqlite3_finalize(). */
    return [[[PLSqlitePreparedStatement alloc] initWithDatabase: self sqliteStmt: sqlite_stmt] autorelease];
}


/* varargs version */
- (BOOL) executeUpdateAndReturnError: (NSError **) error statement: (NSString *) statement args: (va_list) args {
    sqlite3_stmt *sqlite_stmt;
    int ret;
    
    /* Prepare our statement */
    sqlite_stmt = [self createStatement: statement error: error];
    if (sqlite_stmt == nil)
        return NO;
    
    /* Parameter binding */
    [self bindValuesForStatement: sqlite_stmt withArgs: args];
    
    /* Call sqlite3_step() to run the virtual machine, and finalize the statement */
    ret = sqlite3_step(sqlite_stmt);
    sqlite3_finalize(sqlite_stmt);
    
    /* On success, return */
    if (ret == SQLITE_DONE)
        return YES;
    
    /* Programmer error */
    if (ret == SQLITE_ROW) {
        /* Since the SQL being executed is not a SELECT statement, we assume no data will be returned. */
        [NSException raise: PLSqliteException format: @"SQLite -[PLSqliteDatabase executeUpdate:] query '%@' on database '%@' "
         "returned result set. Perhaps the developer provided SELECT query to -[db executeUpdate:]?)", statement, _path];
    }
    
    /* Query failed */
    [self populateError: error
          withErrorCode: PLDatabaseErrorQueryFailed
            description: NSLocalizedString(@"An error occurred executing an SQL update.", @"")
            queryString: statement];
    return NO;
}

/* from PLDatabase. */
- (BOOL) executeUpdate: (NSString *) statement, ... {
    BOOL ret;
    va_list ap;
    
    va_start(ap, statement);
    ret = [self executeUpdateAndReturnError: nil statement: statement args: ap];
    va_end(ap);
    
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


/* varargs version */
- (NSObject<PLResultSet> *) executeQueryAndReturnError: (NSError **) error statement: (NSString *) statement args: (va_list) args {
    sqlite3_stmt *sqlite_stmt;
    
    /* Prepare our statement */
    sqlite_stmt = [self createStatement: statement error: error];
    if (sqlite_stmt == nil)
        return nil;
    
    /* Varargs parsing */
    [self bindValuesForStatement: sqlite_stmt withArgs: args];
    
    /* Create a new PLSqliteResultSet statement.
     *
     * MEMORY OWNERSHIP WARNING:
     * We pass our sqlite3_stmt reference to the PLSqliteResultSet, which now must assume authority for releasing
     * that statement using sqlite3_finalize(). */
    return [[[PLSqliteResultSet alloc] initWithDatabase:self sqliteStmt:sqlite_stmt] autorelease];
}


- (NSObject<PLResultSet> *) executeQueryAndReturnError: (NSError **) error statement: (NSString *) statement, ... {
    NSObject<PLResultSet> *result;
    va_list ap;

    va_start(ap, statement);
    result = [self executeQueryAndReturnError: error statement: statement args: ap];
    va_end(ap);

    return result;
}


/* from PLDatabase. */
- (NSObject<PLResultSet> *) executeQuery: (NSString *) statement, ... {
    NSObject<PLResultSet> *result;
    va_list ap;
    
    va_start(ap, statement);
    result = [self executeQueryAndReturnError: nil statement: statement args: ap];
    va_end(ap);
    
    return result;
}


/* from PLDatabase. */
- (BOOL) beginTransaction {
    return [self beginTransactionAndReturnError: nil];
}

/* from PLDatabase */
- (BOOL) beginTransactionAndReturnError: (NSError **) error {
    return [self executeUpdateAndReturnError: error statement: @"BEGIN DEFERRED"];
}


/* from PLDatabase. */
- (BOOL) commitTransaction {
    return [self commitTransactionAndReturnError: nil];
}

/* from PLDatabase */
- (BOOL) commitTransactionAndReturnError: (NSError **) error {
    return [self executeUpdateAndReturnError: error statement: @"COMMIT"];
}


/* from PLDatabase. */
- (BOOL) rollbackTransaction {
    return [self rollbackTransactionAndReturnError: nil];
}

/* from PLDatabase */
- (BOOL) rollbackTransactionAndReturnError: (NSError **) error {
    return [self executeUpdateAndReturnError: error statement: @"ROLLBACK"];
}


/* from PLDatabase */
- (BOOL) tableExists: (NSString *) tableName {
    NSObject<PLResultSet> *rs;
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

@end

/**
 * @internal
 *
 * Private PLSqliteDatabase methods.
 */
@implementation PLSqliteDatabase (PLSqliteDatabasePrivate)

/**
 * @internal
 *
 * Populate an NSError (if not nil) and log it.
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

    /* Log it and optionally return it */
    NSLog(@"A SQLite database error occurred on database '%@': %@ (SQLite #%@: %@) (query: '%@')", 
          _path, result, vendorError, vendorString, queryString != nil ? queryString : @"<none>");

    if (error != nil)
        *error = result;
}

/**
 * @internal
 *
 * Create an SQLite statement, returning nil on error.
 * MEMORY OWNERSHIP WARNING:
 * The returned statement is owned by the caller, and MUST be free'd using sqlite3_finalize().
 */
- (sqlite3_stmt *) createStatement: (NSString *) statement error: (NSError **) error {
    sqlite3_stmt *sqlite_stmt;
    const char *unused;
    int ret;
    
    /* Prepare */
    ret = sqlite3_prepare_v2(_sqlite, [statement UTF8String], -1, &sqlite_stmt, &unused);
    
    /* Prepare failed */
    if (ret != SQLITE_OK) {
        [self populateError: error
              withErrorCode: PLDatabaseErrorInvalidStatement
                description: NSLocalizedString(@"An error occured parsing the provided SQL statement.", @"")
                queryString: statement];
        return nil;
    }
    
    /* Multiple statements were provided */
    if (*unused != '\0') {
        [self populateError: error
              withErrorCode: PLDatabaseErrorInvalidStatement
                description: NSLocalizedString(@"Multiple SQL statements were provided for a single query.", @"")
                queryString: statement];
        return nil;
    }

    return sqlite_stmt;
}


/**
 * @internal
 * Bind a value to a statement parameter, returning the SQLite bind result value.
 *
 * @param sqlite_stmt Statement containing to-be-bound parameter.
 * @param parameterIndex Index of parameter to be bound.
 * @param value Objective-C object to use as the value.
 */
- (int) bindValueForParameter: (sqlite3_stmt *) sqlite_stmt withParameter: (int) parameterIndex withValue: (id) value {
    /* NULL */
    if (value == nil) {
        return sqlite3_bind_null(sqlite_stmt, parameterIndex);
    }
    
    /* Data */
    else if ([value isKindOfClass: [NSData class]]) {
        return sqlite3_bind_blob(sqlite_stmt, parameterIndex, [value bytes], [value length], SQLITE_TRANSIENT);
    }
    
    /* Date */
    else if ([value isKindOfClass: [NSDate class]]) {
        return sqlite3_bind_double(sqlite_stmt, parameterIndex, [value timeIntervalSince1970]);
    }
    
    /* String */
    else if ([value isKindOfClass: [NSString class]]) {
        return sqlite3_bind_text(sqlite_stmt, parameterIndex, [value UTF8String], -1, SQLITE_TRANSIENT);
    }

    /* Number */
    else if ([value isKindOfClass: [NSNumber class]]) {
        const char *objcType = [value objCType];
        int64_t number = [value longLongValue];
        
        /* Handle floats and doubles */
        if (strcmp(objcType, @encode(float)) == 0 || strcmp(objcType, @encode(double)) == 0) {
            return sqlite3_bind_double(sqlite_stmt, parameterIndex, [value doubleValue]);
        }

        /* If the value can fit into a 32-bit value, use that bind type. */
        else if (number <= INT32_MAX) {
            return sqlite3_bind_int(sqlite_stmt, parameterIndex, number);

        /* Otherwise use the 64-bit bind. */
        } else {
            return sqlite3_bind_int64(sqlite_stmt, parameterIndex, number);
        }
    }

    /* Not a known type */
    [NSException raise: PLSqliteException format: @"SQLite error binding unknown parameter type '%@' for database '%@'. Value: '%@'", [value class], _path, value];
    
    /* Unreachable */
    abort();
}


/**
 * @internal
 * Bind all parameter values for an SQLite statement. Throws an exception on error.
 *
 * @param sqlite_stmt Statement containing to-be-bound parameters.
 * @param args Arguments to be bound. This MUST be a list of Objective-C object instances.
 */
- (void) bindValuesForStatement: (sqlite3_stmt *) sqlite_stmt withArgs: (va_list) args {
    int valueCount = sqlite3_bind_parameter_count(sqlite_stmt);
    assert(valueCount >= 0);
    
    /* Sqlite counts parameters starting at 1. */
    for (int valueIndex = 1; valueIndex <= valueCount; valueIndex++) {
        /* Bind the parameter */
        int ret = [self bindValueForParameter: sqlite_stmt
                                 withParameter: valueIndex
                                     withValue: va_arg(args, id)];
        
        /* If the bind fails, throw an exception (programmer error). */
        if (ret != SQLITE_OK) {
            [NSException raise: PLSqliteException
                        format: @"SQlite error binding parameter %d for database '%@': %d", valueIndex, _path, ret];
        }
    }

    /* If you get this far, all is well */
    return;
}

@end