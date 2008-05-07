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

/* Library Includes */
#import "PLResultSet.h"
#import "PLDatabase.h"

#import "PLSqliteDatabase.h"
#import "PLSqliteResultSet.h"

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
 * conforming to #PLResultSet will be returned.
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
