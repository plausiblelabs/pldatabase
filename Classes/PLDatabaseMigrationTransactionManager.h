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
 * Manages the database migration transactions and locking to ensure atomic testing
 * of the database version and application of any migrations.
 *
 * @par Thread Safety
 * PLDatabaseMigrationTransactionManager instances are not required to implement any locking and must not be
 * shared between threads.
 */
@protocol PLDatabaseMigrationTransactionManager <NSObject>

/**
 * Start a database transaction, using a sufficient isolation level and/or locking to ensure that
 * no other migrations will run until this has completed. 
 *
 * @param database An active database connection on which to execute any queries.
 * @param outError A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the transaction could not be started.
 * If no error occurs, this parameter will be left unmodified. You may specify NULL for this
 * parameter, and no error information will be provided.
 */
- (BOOL) beginExclusiveTransactionForDatabase: (id<PLDatabase>) database error: (NSError **) outError;


/**
 * Roll back the database transaction, returning YES on success, or NO on failure.
 *
 * @param database An active database connection on which to issue any queries.
 * @param outError A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the transaction could not be
 * rolled back.
 */
- (BOOL) rollbackTransactionForDatabase: (id<PLDatabase>) database error: (NSError **) outError;


/**
 * Commit the database transaction, returning YES on success, or NO on failure.
 *
 * @param database An active database connection on which to issue any queries.
 * @param outError A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the transaction could not be
 * committed.
 */
- (BOOL) commitTransactionForDatabase: (id<PLDatabase>) database error: (NSError **) outError;

@end
