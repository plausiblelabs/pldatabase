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

- (sqlite3_stmt *) createStatement: (NSString *) statement;

- (int) bindValueForParameter: (sqlite3_stmt *) sqlite_stmt withParameter: (int) parameterIndex withValue: (id) value;

- (void) bindValuesForStatement: (sqlite3_stmt *) sqlite_stmt withArgs: (va_list) args;

@end

/**
 * SQLite #PLDatabase implementation.
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


- (void) dealloc {
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
    int err;

    /* Do not call open twice! */
    if (_sqlite != nil)
        [NSException raise: PLSqliteException format: @"Attempted to open already-open SQLite database instance at '%@'. Called -[PLSqliteDatabase open] twice?", _path];

    /* Open the database */
    err = sqlite3_open([_path fileSystemRepresentation], &_sqlite);
    if (err != SQLITE_OK) {
        /* Failed. Log a helpful error. */
        NSLog(@"Could not open SQLite database at '%@': %s", _path, sqlite3_errmsg(_sqlite));
        return NO;
    }

    /* Set a busy timeout */
    err = sqlite3_busy_timeout(_sqlite, SQLITE_BUSY_TIMEOUT);
    if (err != SQLITE_OK) {
        /* Failed. Log a helpful error. */
        NSLog(@"Could not set SQLite busy timeout for database '%@': %s", _path, sqlite3_errmsg(_sqlite));
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


/* from PLDatabase. */
- (BOOL) executeUpdate: (NSString *) statement, ... {
    sqlite3_stmt *sqlite_stmt;
    va_list ap;
    int ret;

    /* Prepare our statement */
    sqlite_stmt = [self createStatement: statement];
    if (sqlite_stmt == nil)
        return NO;

    /* Varargs parsing */
    va_start(ap, statement);
    [self bindValuesForStatement: sqlite_stmt withArgs: ap];
    va_end(ap);

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
    NSLog(@"SQLite query '%@' on database '%@' failed: %@", statement, _path, [self lastErrorMessage]);
    return NO;
}


/* from PLDatabase. */
- (NSObject<PLResultSet> *) executeQuery: (NSString *) statement, ... {
    sqlite3_stmt *sqlite_stmt;
    va_list ap;

    /* Prepare our statement */
    sqlite_stmt = [self createStatement: statement];
    if (sqlite_stmt == nil)
        return nil;

    /* Varargs parsing */
    va_start(ap, statement);
    [self bindValuesForStatement: sqlite_stmt withArgs: ap];
    va_end(ap);
    
    /* Create a new PLSqliteResultSet statement.
     *
     * MEMORY OWNERSHIP WARNING:
     * We pass our sqlite3_stmt reference to the PLSqliteResultSet, which now must assume authority for releasing
     * that statement using sqlite3_finalize(). */
    return [[[PLSqliteResultSet alloc] initWithDatabase:self sqliteStmt:sqlite_stmt] autorelease];
}


/* from PLDatabase. */
- (BOOL) beginTransaction {
    return [self executeUpdate: @"BEGIN DEFERRED"];
}


/* from PLDatabase. */
- (BOOL) commitTransaction {
    return [self executeUpdate: @"COMMIT"];
}


/* from PLDatabase. */
- (BOOL) rollbackTransaction {
    return [self executeUpdate: @"ROLLBACK"];
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
 * @param Return the row ID (integer primary key) of the most recent successful INSERT.
 */
- (int64_t) lastInsertRowId {
    return sqlite3_last_insert_rowid(_sqlite);
}

/**
 * @internal
 * Return the last error message encountered by the underlying sqlite database.
 */
- (NSString *) lastErrorMessage {
    return [NSString stringWithUTF8String: sqlite3_errmsg(_sqlite)];
}

@end

@implementation PLSqliteDatabase (PLSqliteDatabasePrivate)

/**
 * @internal
 *
 * Create an SQLite statement, returning nil on error.
 * MEMORY OWNERSHIP WARNING:
 * The returned statement is owned by the caller, and MUST be free'd using sqlite3_finalize().
 */
- (sqlite3_stmt *) createStatement: (NSString *) statement {
    sqlite3_stmt *sqlite_stmt;
    const char *unused;
    int ret;
    
    /* Prepare */
    ret = sqlite3_prepare_v2(_sqlite, [statement UTF8String], -1, &sqlite_stmt, &unused);
    
    /* Prepare failed */
    if (ret != SQLITE_OK) {
        NSLog(@"Could not prepare statement '%@' for SQLite database at '%@': %s", statement, _path, sqlite3_errmsg(_sqlite));
        return nil;
    }
    
    /* Multiple statements were provided */
    if (*unused != '\0') {
        NSLog(@"Multiple statements '%@' were provided for single-statement preparation SQLite database at '%@'", statement, _path);
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