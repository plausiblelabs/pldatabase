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


/* Dependencies */
#import <Foundation/Foundation.h>

/* Exceptions */
extern NSString *PLDatabaseException;

/* Error Domain and Codes */
extern NSString *PLDatabaseErrorDomain;
extern NSString *PLDatabaseErrorQueryStringKey;
extern NSString *PLDatabaseErrorVendorErrorKey;
extern NSString *PLDatabaseErrorVendorStringKey;

/**
 * NSError codes in the Plausible Database error domain.
 */
typedef enum {
    /** An unknown error has occured. If this
     * code is received, it is a bug, and should be reported. */
    PLDatabaseErrorUnknown = 0,
    
    /** File not found. */
    PLDatabaseErrorFileNotFound = 1,
    
    /** An SQL query failed. */
    PLDatabaseErrorQueryFailed = 2,
    
    /** The provided SQL statement was invalid. */
    PLDatabaseErrorInvalidStatement = 3,
} PLDatabaseError;


/* Library Includes */
#import "PLResultSet.h"
#import "PLPreparedStatement.h"
#import "PLDatabase.h"

#import "PLSqliteDatabase.h"
#import "PLSqlitePreparedStatement.h"
#import "PLSqliteResultSet.h"

#import "PLEntity.h"
#import "PLEntityProperty.h"
#import "PLEntityDescription.h"

#import "PLEntityConnectionDelegate.h"
#import "PLEntityDialect.h"
#import "PLEntitySession.h"
#import "PLEntityManager.h"
#import "PLSqlBuilder.h"

#import "PLSqliteEntityDialect.h"
#import "PLSqliteEntityConnectionDelegate.h"

#ifdef PL_DB_PRIVATE

@interface PlausibleDatabase : NSObject {
}

+ (NSError *) errorWithCode: (PLDatabaseError) errorCode localizedDescription: (NSString *) localizedDescription 
                queryString: (NSString *) queryString
                 vendorError: (NSNumber *) vendorError vendorErrorString: (NSString *) vendorErrorString;

@end

#endif /* PL_DB_PRIVATE */

/**
 * @mainpage Plausible Database
 *
 * @section intro_sec Introduction
 *
 * Plausible Database provides a generic Objective-C interface for interacting with
 * SQL databases. SQLite is the initial and primary target, but the API has been
 * designed to support more traditional databases.
 *
 * While the code is stable and unit tested, the API has not yet been finalized,
 * and may see incompatible changes prior to the 1.0 release.
 *
 * Plausible Database provides an Objective-C veneer over the underlying SQL database. Classes
 * are automatically bound to statement parameters, and converted to and from the underlying SQL datatypes.
 *
 * Library classes supporting subclassing are explicitly documented. Due to Objective-C's fragile base classes,
 * binary compatibility with subclasses is NOT guaranteed. You should avoid subclassing library
 * classes -- use class composition instead.
 *
 * @section create_conn Creating a Connection
 *
 * Open a connection to a database file:
 *
 * <pre>
 * PLSqliteDatabase *db = [[PLSqliteDatabase alloc] initWithPath:  @"/path/to/database"];
 * if (![db open])
 *     NSLog(@"Could not open database");
 * </pre>
 *
 * @section exec_update Update Statements
 *
 * Update statements can be executed using -[PLDatabase executeUpdate:]
 *
 * <pre>
 * if (![db executeUpdate: @"CREATE TABLE example (id INTEGER)"])
 *     NSLog(@"Table creation failed");
 *
 * if (![db executeUpdate: @"INSERT INTO example (id) VALUES (?)", [NSNumber numberWithInteger: 42]])
 *     NSLog(@"Data insert failed");
 * </pre>
 * @section exec_query Query Statements
 *
 * Queries can be executed using -[PLDatabase executeQuery:]. To iterate over the returned results, an NSObject instance
 * conforming to PLResultSet will be returned.
 *
 * <pre>
 * NSObject<PLResultSet> *results = [db executeQuery: @"SELECT id FROM example WHERE id = ?", [NSNumber numberWithInteger: 42]];
 * while ([results next]) {
 *     NSLog(@"Value of column id is %d", [results intForColumn: @"id"]);
 * }
 *
 * // Failure to close the result set will not leak memory, but may
 * // retain database resources until the instance is deallocated.
 * [results close];
 * </pre>
 */
