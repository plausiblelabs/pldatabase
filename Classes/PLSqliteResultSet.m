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
 *
 * SQLite #PLResultSet implementation.
 */
 @implementation PLSqliteResultSet

/**
 * Initialize the ResultSet with an open database and an sqlite3 prepare statement.
 *
 * MEMORY OWNERSHIP WARNING:
 * We are passed an sqlite3_stmt reference which now we now assume authority for releasing
 * that statement using sqlite3_finalize().
 */
- (id) initWithDatabase: (PLSqliteDatabase *) db sqliteStmt: (sqlite3_stmt *) sqlite_stmt {
    if ((self = [super init]) == nil) {
        return nil;
    }
    
    /* Save our database and statement reference. */
    _db = [db retain];
    _sqlite_stmt = sqlite_stmt;

    /* Save result information */
    _columnCount = sqlite3_column_count(_sqlite_stmt);
    
    /* Create a column name cache. Optimization possibility: Using CFDictionary may
     * provide an optimization here, since dictionary values do not need to be boxed as objects */
    _columnNames = [[NSMutableDictionary alloc] initWithCapacity: _columnCount];
    for (int columnIndex = 0; columnIndex < _columnCount; columnIndex++) {
        NSString *name = [[NSString stringWithUTF8String: sqlite3_column_name(_sqlite_stmt, columnIndex)] lowercaseString];
        [_columnNames setValue: [NSNumber numberWithInt: columnIndex] forKey: name];
    }

    return self;
}

- (void) dealloc {
    /* The statement must be released before the databse is released, as the statement has a reference
     * to the database which would cause a SQLITE_BUSY error when the database is released. */
    [self close];

    /* Release the column cache. */
    [_columnNames release];

    /* Now release the database. */
    [_db release];
    
    [super dealloc];
}

// From PLResultSet
- (void) close {
    if (_sqlite_stmt == nil)
        return;

    /* The finalization may return the last error returned by sqlite3_next(), but this has already
     * been handled by the -[PLSqliteResultSet next] implementation. Any remaining memory and
     * resources are released regardless of the error code, so we do not check it here. */
    sqlite3_finalize(_sqlite_stmt);
}

/**
 * @internal
 * Assert that the result set has not been closed
 */
- (void) assertNotClosed {
    if (_sqlite_stmt == nil)
        [NSException raise: PLSqliteException format: @"Attempt to access already-closed result set."];
}

// From PLResultSet
- (BOOL) next {
    [self assertNotClosed];

    int ret;
    ret = sqlite3_step(_sqlite_stmt);
    
    /* No more rows available, return NO. */
    if (ret == SQLITE_DONE)
        return NO;
    
    /* A row is available, return YES. */
    if (ret == SQLITE_ROW)
        return YES;
    
    /* An error occurred. Log it and throw an exceptions. */
    NSString *error = [NSString stringWithFormat: @"Error occurred calling next on a PLSqliteResultSet. Error: %@", [_db lastErrorMessage]];
    NSLog(@"%@", error);

    [NSException raise: PLSqliteException format: @"%@", error];

    /* Unreachable */
    abort();
}


/* From PLResultSet */
- (int) columnIndexForName: (NSString *) name {
    [self assertNotClosed];

    NSNumber *number = [_columnNames objectForKey: [name lowercaseString]];
    if (number != nil)
        return [number intValue];
    
    /* Not found */
    [NSException raise: PLSqliteException format: @"Attempted to access unknown result column %@", name];

    /* Unreachable */
    abort();
}


/**
 * @internal
 * Validate the column index and return the column type
 */
- (int) validateColumnIndex: (int) columnIndex isNullable: (BOOL) nullable {
    [self assertNotClosed];

    int columnType;
    
    /* Verify that the index is in range */
    if (columnIndex > _columnCount - 1 || columnIndex < 0)
        [NSException raise: PLSqliteException format: @"Attempted to access out-of-range column index %d", columnIndex];

    /* Fetch the type */
    columnType = sqlite3_column_type(_sqlite_stmt, columnIndex);
    
    /* Verify nullability */
    if (!nullable && columnType == SQLITE_NULL) {
        [NSException raise: PLSqliteException format: @"Attempted to access null column value for column index %d. Use -[PLResultSet isNullColumn].", columnIndex];
    }

    return columnType;
}

/* This beauty generates the PLResultSet value accessors for a given data type */
#define VALUE_ACCESSORS(ReturnType, MethodName, SqliteType, Expression) \
    - (ReturnType) MethodName ## ForColumnIndex: (int) columnIndex { \
        [self assertNotClosed]; \
        int columnType = [self validateColumnIndex: columnIndex isNullable: NO]; \
        \
        if (columnType == SqliteType) \
            return (Expression); \
        \
        /* unknown value */ \
        [NSException raise: PLSqliteException format: @"Attempted to access non-%s column as %s.", #ReturnType, #ReturnType]; \
        \
        /* Unreachable */ \
        abort(); \
    } \
    \
    - (ReturnType) MethodName ## ForColumn: (NSString *) column { \
        return [self MethodName ## ForColumnIndex: [self columnIndexForName: column]]; \
    }

/* bool */
VALUE_ACCESSORS(BOOL, bool, SQLITE_INTEGER, sqlite3_column_int(_sqlite_stmt, columnIndex))

/* int32_t */
VALUE_ACCESSORS(int32_t, int, SQLITE_INTEGER, sqlite3_column_int(_sqlite_stmt, columnIndex))

/* int64_t */
VALUE_ACCESSORS(int64_t, bigInt, SQLITE_INTEGER, sqlite3_column_int64(_sqlite_stmt, columnIndex))

/* date */
VALUE_ACCESSORS(NSDate *, date, SQLITE_FLOAT,
                    [NSDate dateWithTimeIntervalSince1970: sqlite3_column_double(_sqlite_stmt, columnIndex)])

/* string */
VALUE_ACCESSORS(NSString *, string, SQLITE_TEXT,
                    [NSString stringWithCharacters: sqlite3_column_text16(_sqlite_stmt, columnIndex)
                                            length: sqlite3_column_bytes16(_sqlite_stmt, columnIndex) / 2])

/* float */
VALUE_ACCESSORS(float, float, SQLITE_FLOAT, sqlite3_column_double(_sqlite_stmt, columnIndex))

/* double */
VALUE_ACCESSORS(double, double, SQLITE_FLOAT, sqlite3_column_double(_sqlite_stmt, columnIndex))

/* data */
VALUE_ACCESSORS(NSData *, data, SQLITE_BLOB, [NSData dataWithBytes: sqlite3_column_blob(_sqlite_stmt, columnIndex)
                                                            length: sqlite3_column_bytes(_sqlite_stmt, columnIndex)])

/* from PLResultSet */
- (BOOL) isNullForColumnIndex: (int) columnIndex {
    [self assertNotClosed];

    int columnType = [self validateColumnIndex: columnIndex isNullable: YES];
    
    /* If the column has a null value, return YES. */
    if (columnType == SQLITE_NULL)
        return YES;

    /* Return NO for all other column types. */
    return NO;
}

/* from PLResultSet */
- (BOOL) isNullForColumn: (NSString *) columnName {
    return [self isNullForColumnIndex: [self columnIndexForName: columnName]];
}

@end


