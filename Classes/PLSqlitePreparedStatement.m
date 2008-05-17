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

@interface PLSqlitePreparedStatement (PLSqlitePreparedStatementPrivate)

- (int) bindValueForParameter: (sqlite3_stmt *) sqlite_stmt withParameter: (int) parameterIndex withValue: (id) value;

@end


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
    _parameterCount = sqlite3_bind_parameter_count(_sqlite_stmt);
    assert(_parameterCount >= 0); // sanity check

    return self;
}


/* GC */
- (void) finalize {
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


/* from PLPreparedStatement */
- (int) parameterCount {
    return _parameterCount;
}


/* from PLPreparedStatement */
- (void) bindParameters: (NSArray *) parameters {
    /* Verify that a complete parameter list was provided */
    if ([parameters count] != _parameterCount)
        [NSException raise: PLSqliteException 
                    format: @"%@ prepared statement provided invalid parameter count (expected %d, but %d were provided)", [self class], _parameterCount, [parameters count]];

    /* Sqlite counts parameters starting at 1. */
    for (int valueIndex = 1; valueIndex <= _parameterCount; valueIndex++) {
        /* (Note that NSArray indexes from 0, so we subtract one to get the current value) */
        id value = [parameters objectAtIndex: valueIndex - 1];

        /* Bind the parameter */
        int ret = [self bindValueForParameter: _sqlite_stmt
                                withParameter: valueIndex
                                    withValue: value];

        /* If the bind fails, throw an exception (programmer error). */
        if (ret != SQLITE_OK) {
            [NSException raise: PLSqliteException
                        format: @"SQlite error binding parameter %d for database: %d", valueIndex, ret];
        }
    }
    
    /* If you got this far, all is well */
}

@end


/**
 * @internal
 *
 * Private PLSqliteDatabase methods.
 */
@implementation PLSqlitePreparedStatement (PLSqlitePreparedStatementPrivate)

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
    if (value == nil || value == [NSNull null]) {
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
    [NSException raise: PLSqliteException format: @"SQLite error binding unknown parameter type '%@'. Value: '%@'", [value class], value];
    
    /* Unreachable */
    abort();
}

@end