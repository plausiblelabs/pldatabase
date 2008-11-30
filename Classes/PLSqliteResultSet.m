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

/**
 * @internal
 *
 * SQLite #PLResultSet implementation.
 *
 * @par Thread Safety
 * PLSqliteResultSet instances implement no locking and must not be shared between threads
 * without external synchronization.
 */
 @implementation PLSqliteResultSet

/**
 * Initialize the ResultSet with an open database and an sqlite3 prepare statement.
 *
 * MEMORY OWNERSHIP WARNING:
 * We are passed an sqlite3_stmt reference owned by the PLSqlitePreparedStatement.
 * It will remain valid insofar as the PLSqlitePreparedStatement reference is retained.
 *
 * @par Designated Initializer
 * This method is the designated initializer for the PLSqliteResultSet class.
 */
- (id) initWithPreparedStatement: (PLSqlitePreparedStatement *) stmt 
                  sqliteStatemet: (sqlite3_stmt *) sqlite_stmt
{
    if ((self = [super init]) == nil) {
        return nil;
    }
    
    /* Save our database and statement references. */
    _stmt = [stmt retain];
    _sqlite_stmt = sqlite_stmt;

    /* Save result information */
    _columnCount = sqlite3_column_count(_sqlite_stmt);
    
    return self;
}

/* GC */
- (void) finalize {
    /* 'Check in' our prepared statement reference */
    [self close];
    if (_columnNames != nil)
        [_columnNames release];

    [super finalize];
}

/* Manual */
- (void) dealloc {
    /* 'Check in' our prepared statement reference */
    [self close];

    /* Release the column cache. */
    if (_columnNames != NULL)
        [_columnNames release];
    
    /* Release the statement. */
    [_stmt release];
    
    [super dealloc];
}

// From PLResultSet
- (void) close {
    if (_sqlite_stmt == NULL)
        return;

    /* Check ourselves back in and give up our statement reference */
    [_stmt checkinResultSet: self];
    _sqlite_stmt = NULL;
}

/**
 * @internal
 * Assert that the result set has not been closed
 */
- (void) assertNotClosed {
    if (_sqlite_stmt == NULL)
        [NSException raise: PLSqliteException format: @"Attempt to access already-closed result set."];
}

/* From PLResultSet */
- (BOOL) next {
    [self assertNotClosed];

    if ([self nextAndReturnError: NULL] == PLResultSetStatusRow)
        return YES;

    /* This depreciated API can not differentiate between an error or
     * the end of the result set. */
    return NO;
}

- (PLResultSetStatus) nextAndReturnError: (NSError **) error {
    [self assertNotClosed];
    
    int ret;
    ret = sqlite3_step(_sqlite_stmt);
    
#ifdef PL_SQLITE_LEGACY_STMT_PREPARE
    /* Earlier versions of SQLite require a call to sqlite3_reset to return
     * a non-generic error */
    if (ret == SQLITE_ERROR)
        ret = sqlite3_reset(_sqlite_stmt);

    if (ret == SQLITE_SCHEMA) {
        sqlite3_stmt *newStmt = [_stmt reloadStatementAndReturnError: error];
        if (newStmt == NULL)
            return PLResultSetStatusError;
        
        _sqlite_stmt = newStmt;
        return [self nextAndReturnError: error];
    }
#endif

    /* No more rows available. */
    if (ret == SQLITE_DONE)
        return PLResultSetStatusDone;
    
    /* A row is available */
    if (ret == SQLITE_ROW)
        return PLResultSetStatusRow;

    /* An error has occured */
    [_stmt populateError: error withErrorCode: PLDatabaseErrorQueryFailed description: NSLocalizedString(@"Could not retrieve the next result row", @"Generic result row error")];
    return PLResultSetStatusError;
}


/* From PLResultSet */
- (int) columnIndexForName: (NSString *) name {
    [self assertNotClosed];
    
    /* Lazy initialization of the column name mapping. Profiling demonstrates that iPhone code doing a high
     * volume of queries avoids a significant performance penalty if the column name mapping is not used. */
    if (_columnNames == nil) {
        /* Create a column name cache */
        NSMutableDictionary *columnNames = [[NSMutableDictionary alloc] initWithCapacity: _columnCount];
        _columnNames = columnNames;

        for (int columnIndex = 0; columnIndex < _columnCount; columnIndex++) {
            /* Fetch the name */
            NSString *name = [NSString stringWithUTF8String: sqlite3_column_name(_sqlite_stmt, columnIndex)];
            
            /* Set the dictionary value */
            [columnNames setObject: [NSNumber numberWithInt: columnIndex] forKey: [name lowercaseString]];
        }
    }

    NSString *key = [name lowercaseString];
    NSNumber *idx = [_columnNames objectForKey: key];
    if (idx != nil) {
        return [idx intValue];
    }
    
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


/* From PLResultSet */
- (id) objectForColumnIndex: (int) columnIndex {
    [self assertNotClosed];

    int columnType = [self validateColumnIndex: columnIndex isNullable: YES];
    switch (columnType) {
        case SQLITE_TEXT:
            return [self stringForColumnIndex: columnIndex];

        case SQLITE_INTEGER:
            return [NSNumber numberWithLong: [self bigIntForColumnIndex: columnIndex]];

        case SQLITE_FLOAT:
            return [NSNumber numberWithDouble: [self doubleForColumnIndex: columnIndex]];

        case SQLITE_BLOB:
            return [self dataForColumnIndex: columnIndex];

        case SQLITE_NULL:
            return [NSNull null];

        default:
            [NSException raise: PLDatabaseException format: @"Unhandled SQLite column type %d", columnType];
    }

    /* Unreachable */
    abort();
}


/* From PLResultSet */
- (id) objectForColumn: (NSString *) columnName {
    return [self objectForColumnIndex: [self columnIndexForName: columnName]];
}


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
