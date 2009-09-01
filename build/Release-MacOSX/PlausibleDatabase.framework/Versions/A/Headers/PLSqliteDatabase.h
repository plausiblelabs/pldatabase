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

/* On windows, use the included sqlite3 library */
#ifdef WINDOWS
#import "sqlite3.h"
#else
#import <sqlite3.h>
#endif

/* On older versions of sqlite3, sqlite3_prepare_v2() is not available */
#if SQLITE_VERSION_NUMBER <= 3003009
#define PL_SQLITE_LEGACY_STMT_PREPARE 1
#endif

extern NSString *PLSqliteException;

@interface PLSqliteDatabase : NSObject <PLDatabase> {
@private
    /** Path to the database file. */
    NSString *_path;
    
    /** Underlying sqlite database reference. */
    sqlite3 *_sqlite;
}

+ (id) databaseWithPath: (NSString *) dbPath;

- (id) initWithPath: (NSString*) dbPath;

- (BOOL) open;
- (BOOL) openAndReturnError: (NSError **) error;

- (sqlite3 *) sqliteHandle;
- (int64_t) lastInsertRowId;

@end

#ifdef PL_DB_PRIVATE

@interface PLSqliteDatabase (PLSqliteDatabaseLibraryPrivate)

- (int) lastErrorCode;
- (NSString *) lastErrorMessage;

#ifdef PL_SQLITE_LEGACY_STMT_PREPARE
// This method is only exposed for the purpose of supporting implementations missing sqlite3_prepare_v2()
- (sqlite3_stmt *) createStatement: (NSString *) statement error: (NSError **) error;
#endif

- (void) populateError: (NSError **) result withErrorCode: (PLDatabaseError) errorCode
           description: (NSString *) localizedDescription queryString: (NSString *) queryString;

@end

#endif