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

#import <Foundation/Foundation.h>

#import "PLDatabaseConstants.h"
#import "PLPreparedStatement.h"
#import "PLResultSet.h"

/**
 * Standard SQL transaction isolation levels. These levels define the minimum isolation required; a database
 * is free to apply stricter isolation than has been requested.
 *
 * @ingroup enums
 */
typedef enum {
    /** Statements can read rows that have been modified by other transactions and have not yet been committed. */
    PLDatabaseIsolationLevelReadUncommitted = 0,

    /** Statements cannot read changes that have not been committed by other transactions. Changes that
     * have been comitted will be readable. */
    PLDatabaseIsolationLevelReadCommitted = 1,

    /** Statements cannot read changes that have not been committed by other transactions, and no other transactions
     * may modify data that has been read by the current transaction until the current transaction is completed. */
    PLDatabaseIsolationLevelRepeatableRead = 2,

    /**
     * Statements cannot read changes that have not been committed by other transactions, no other transactions may
     * modify data that has been read by the current transaction until the current transaction is completed, and
     * other transactions cannot insert new rows with values that would fall into the range of rows read by any
     * statement in the current transaction until the current transaction complets.
     */
    PLDatabaseIsolationLevelSerializable = 3
} PLDatabaseIsolationLevel;

typedef enum {
    /** Request that the transaction be committed. */
    PLDatabaseTransactionCommit = 0,

    /** Request that the transaction be rolled back. The transaction will be automatically retried if the immediate
     * previous database failure was caused by a deadlock condition. Return PLDatabaseTransactionRollbackDisableRetry to
     * prevent retry behavior. */
    PLDatabaseTransactionRollback = 1,

    /** Request that the transaction be rolled back. It will not be retried. */
    PLDatabaseTransactionRollbackDisableRetry = 2
} PLDatabaseTransactionResult;

/**
 * Protocol for interacting with an SQL database.
 *
 * @par Object Types
 * All drivers support conversion to and from the following object types:
 * - NSString
 * - NSNumber
 * - NSData
 *
 * @par Scalar Types
 * All drivers implement conversion to and from the scalar types as defined in
 * the Key Value Coding documentation, Scalar and Structure Support:
 * http://developer.apple.com/documentation/Cocoa/Conceptual/KeyValueCoding/Concepts/DataTypes.html#//apple_ref/doc/uid/20002171-184842-BCIJIBHC
 *
 * @par
 * The mapping of these scalar types to specific database types is implementation
 * defined. Refer to the database driver's documentation for the specific mapping
 * used.
 *
 * @par Thread Safety
 * PLDatabase instances implement no locking and must not be shared between threads
 * without external synchronization.
 */
@protocol PLDatabase <NSObject>

/**
 * Test that the connection is active.
 */
- (BOOL) goodConnection;

/**
 * Close the database connection, releasing any held database resources.
 * After calling, no further PLDatabase methods may be called on the instance.
 *
 * As PLDatabase objects may be placed into autorelease pools, with indeterminate
 * release of database resources, this method should be used to ensure that the database
 * connection is closed in a timely manner. 
 *
 * Failure to call close will not result in any resource leaks, but may result in
 * database connections unexpectedly remaining open, especially in a garbage collection
 * environment.
 */
- (void) close;


/**
 * Prepare and return a new PLPreparedStatement.
 *
 * @param statement SQL statement to prepare.
 * @return The prepared statement, or nil if it could not be prepared.
 */
- (id<PLPreparedStatement>) prepareStatement: (NSString *) statement;

/**
 * Prepare and return a new PLPreparedStatement.
 *
 * @param statement SQL statement to prepare.
 * @param outError A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the statement could not be prepared.
 * If no error occurs, this parameter will be left unmodified. You may specify NULL for this
 * parameter, and no error information will be provided.
 * @return The prepared statement, or nil if it could not be prepared.
 */
- (id<PLPreparedStatement>) prepareStatement: (NSString *) statement error: (NSError **) outError;


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
 * Execute an update, returning YES on success, NO on failure.
 *
 * Any arguments should be provided following the statement, and
 * referred to using standard '?' JDBC substitutions
 *
 * @param error A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the statement could not be executed.
 * If no error occurs, this parameter will be left unmodified. You may specify NULL for this
 * parameter, and no error information will be provided.
 * @param statement SQL statement to execute.
 *
 */
- (BOOL) executeUpdateAndReturnError: (NSError **) error statement: (NSString *) statement, ...;

/**
 * Execute a query, returning a PLResultSet.
 *
 * Any arguments should be provided following the statement, and
 * referred to using standard '?' JDBC substitutions
 *
 * @param statement SQL statement to execute.
 * @return PLResultSet on success, or nil on failure.
 */
- (id<PLResultSet>) executeQuery: (NSString *) statement, ...;

/**
 * Execute a query, returning a PLResultSet.
 *
 * Any arguments should be provided following the statement, and
 * referred to using standard '?' JDBC substitutions
 *
 * @param error A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the statement could not be executed.
 * If no error occurs, this parameter will be left unmodified. You may specify NULL for this
 * parameter, and no error information will be provided.
 * @param statement SQL statement to execute.
 * @return PLResultSet on success, or nil on failure.
 */
- (id<PLResultSet>) executeQueryAndReturnError: (NSError **) error statement: (NSString *) statement, ...;

/**
 * Begin a transaction and execute @a block. If @a block returns PLDatabaseTransactionRollback, and
 * the immediate proceeding database operation within the transaction block failed due to the server reporting a dead-lock
 * condition, the transaction will be rolled back, immediately retried, and @a block will executed again. 
 *
 * @param block A block to be executed within the transaction. If the block returns PLDatabaseTransactionCommit, the
 * transaction will be committed, otherwise, the transaction will be rolled back and optionally retried.
 * @param outError If an error occurs executing the transaction, upon return contains an error object in the PLDatabaseErrorDomain
 * that describes the problem. Pass NULL if you do not want error information.
 *
 * @return YES if the transaction is successfully committed or rolled back, or NO on failure. Note that a return value of
 * YES <em>does not</em> signify that the transaction was committed, but rather, that no database error occured either committing
 * or rolling back the transaction.
 *
 * @par Automatic Retry
 *
 * If the immediate proceeding operation within the transaction failed due to a dead-lock condition, the transaction
 * will be automatically retried if PLDatabaseTransactionRollback is returned. This means that @a block may
 * be executed multiple times, and the block implementation must be idempotent and free of unintended side-effects if
 * run repeatedly.
 *
 * @par Isolation Level
 *
 * The transaction must provide at least 'Read committed' isolation. As per the SQL standard, the isolation level may be
 * stricter than what has been requested -- this method only gaurantees the MINIMUM of isolation.
 *
 * For more information on SQL standard transaction isolation levels, refer to
 * PostgreSQL's documentation:
 *    http://www.postgresql.org/docs/8.3/interactive/transaction-iso.html
 *
 * @warning The provided @a block may be executed multiple times and <em>must</em> be idempotent.
 */
- (BOOL) performTransactionWithRetryBlock: (PLDatabaseTransactionResult (^)()) block error: (NSError **) outError;

/**
 * Begin a transaction and execute @a block. If @a block returns PLDatabaseTransactionRollback, and
 * the immediate proceeding database operation within the transaction block failed due to the server reporting a dead-lock
 * condition, the transaction will be rolled back, immediately retried, and @a block will executed again. 
 *
 * @param isolationLevel The minimum isolation level to be used for this transaction.
 * @param block A block to be executed within the transaction. If the block returns YES, the transaction will be committed,
 * otherwise, the transaction will be rolled back.
 * @param outError If an error occurs executing the transaction, upon return contains an error object in the PLDatabaseErrorDomain
 * that describes the problem. Pass NULL if you do not want error information.
 
 * @return YES if the transaction is successfully committed or rolled back, or NO on failure. Note that a return value of
 * YES <em>does not</em> signify that the transaction was committed, but rather, that no database error occured either committing
 * or rolling back the transaction.
 *
 * @par Automatic Retry
 *
 * If the immediate proceeding operation within the transaction failed due to a dead-lock condition, the transaction
 * will be automatically retried if PLDatabaseTransactionRollback is returned. This means that @a block may
 * be executed multiple times, and the block implementation must be idempotent and free of unintended side-effects if
 * run repeatedly.
 *
 * @warning The provided @a block may be executed multiple times and <em>must</em> be idempotent.
 */
- (BOOL) performTransactionWithIsolationLevel: (PLDatabaseIsolationLevel) isolationLevel
                                   retryBlock: (PLDatabaseTransactionResult (^)()) block
                                        error: (NSError **) outError;


/**
 * Begin a transaction. This must provide at least 'Read committed' isolation. As
 * per the SQL standard, the isolation level may be stricter than what has been
 * requested -- this method only gaurantees the MINIMUM of isolation.
 *
 * For more information on SQL standard transaction isolation levels, refer to
 * PostgreSQL's documentation:
 *    http://www.postgresql.org/docs/8.3/interactive/transaction-iso.html
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) beginTransaction;

/**
 * Begin a transaction. This must provide at least 'Read committed' isolation. As
 * per the SQL standard, the isolation level may be stricter than what has been
 * requested -- this method only gaurantees the MINIMUM of isolation.
 *
 * For more information on SQL standard transaction isolation levels, refer to
 * PostgreSQL's documentation:
 *    http://www.postgresql.org/docs/8.3/interactive/transaction-iso.html
 *
 * @param outError A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the transaction could not
 * be started.
 *
 * If no error occurs, this parameter will be left unmodified. You may specify NULL for this
 * parameter, and no error information will be provided.
 * @return YES on success, NO on failure.
 */
- (BOOL) beginTransactionAndReturnError: (NSError **) outError;

/**
 * Begin a transaction.
 *
 * @param isolationLevel The minimum isolation level to be used for this transaction.
 * @param outError A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the transaction could not
 * be started.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) beginTransactionWithIsolationLevel: (PLDatabaseIsolationLevel) isolationLevel error: (NSError **) outError;

/**
 * Commit an open transaction.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) commitTransaction;

/**
 * Commit an open transaction.
 *
 * @param error A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the transaction could not
 * be committed.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) commitTransactionAndReturnError: (NSError **) error;

/**
 * Rollback an open transaction.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) rollbackTransaction;

/**
 * Rollback an open transaction.
 *
 * @param error A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the transaction could not
 * be rolled back.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) rollbackTransactionAndReturnError: (NSError **) error;


/**
 * Return the number of rows modified by the last UPDATE, INSERT, or DELETE statement issued
 * on this connection.
 */
- (NSInteger) lastModifiedRowCount;

/**
 * Return YES if the given table name exists.
 *
 * @return YES if it exists, NO otherwise.
 */
- (BOOL) tableExists: (NSString *) tableName;

@end