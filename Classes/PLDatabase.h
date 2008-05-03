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

/**
 * Protocol for interacting with an SQL database.
 */
@protocol PLDatabase

/**
 * Close the database connection. Once closed, the connection may not be re-used.
 */
- (void) close;

/**
 * Test that the connection is active.
 */
- (BOOL) goodConnection;

/**
 * Execute an update, returning YES on success, NO on failure.
 *
 * Any arguments should be provided following the statement, and
 * referred to using standard '?' JDBC substitutions
 *
 * @param statement SQL statement to execute.
 */
- (BOOL) executeUpdate: (NSString *) statement, ...;

/**
 * Execute a query, returning a #PLResultSet.
 *
 * Any arguments should be provided following the statement, and
 * referred to using standard '?' JDBC substitutions
 *
 * @param statement SQL statement to execute.
 */
- (NSObject<PLResultSet> *) executeQuery: (NSString *) statement, ...;

/**
 * Begin a transaction.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) beginTransaction;

/**
 * Commit an open transaction.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) commitTransaction;

/**
 * Rollback an open transaction.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) rollbackTransaction;

@end