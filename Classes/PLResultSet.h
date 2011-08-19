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

/**
 * Result values returned when iterating PLResetSet rows.
 *
 * @ingroup constants
 */
typedef enum {
    /** No further rows available */
    PLResultSetStatusDone = 0,

    /** An additional row is available. */
    PLResultSetStatusRow = 1,

    /** An error occured retrieving the row. */
    PLResultSetStatusError = 2
} PLResultSetStatus;

/**
 * Represents a set of results returned by an SQL query.
 *
 * @par Thread Safety
 * PLResultSet instances implement no locking and must not be shared between threads
 * without external synchronization.
 */
@protocol PLResultSet <NSObject>

/**
 * Iterate over all rows in the result set, calling the provided block for each row.
 *
 * @param block Block to execute for each row in the result set. Set the provided stop argument's value
 * to YES to stop iteration of the result set.
 *
 * @return Returns YES if the result set was successfully iterated, or NO if a database error occurs.
 *
 * @invariant If all rows are enumerated and iteration is not explicitly stopped by setting the provided stop argument, the result set will be implicitly closed.
 * @invariant If an error occurs during enumeration and NO is returned by this method, the result set will be implicitly closed.
 */
- (BOOL) enumerateWithBlock: (void (^)(id<PLResultSet> rs, BOOL *stop)) block;

/**
 * Iterate over all rows in the result set, calling the provided block for each row.
 *
 * @param outError A pointer to an NSError object variable. If an error occurs, iteration will stop and
 * this pointer will contain an error object indicating why the statement could not be executed.
 * If no error occurs, this parameter's value will not be modified. You may specify NULL for this
 * parameter, and no error information will be provided.
 * @param block Block to execute for each row in the result set. Set the provided stop argument's value
 * to YES to stop iteration of the result set.
 *
 * @return Returns YES if the result set was successfully iterated, or NO if a database error occurs.
 *
 * @invariant If all rows are enumerated and iteration is not explicitly stopped by setting the provided stop argument, the result set will be implicitly closed.
 * @invariant If an error occurs during enumeration and NO is returned by this method, the result set will be implicitly closed.
 */
- (BOOL) enumerateAndReturnError: (NSError **) outError block: (void (^)(id<PLResultSet> rs, BOOL *stop)) block;

/**
 * Move the result cursor to the next available row. If no further rows
 * are available or an error occurs, returns NO.
 *
 * @return YES if the cursor was moved to the next row, NO if no further rows were available or an error
 * has occured.
 *
 * @deprecated This method fails to differentiate between end of rows and an error condition. Replaced by 
 * PLResultSet::nextAndReturnError:.
 */
- (BOOL) next;

/**
 * Move the result cursor to the next available row. If no further rows
 * are available or an error occurs, returns NO.
 *
 * @param outError A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the statement could not be executed.
 * If no error occurs, this parameter's value will not be modified. You may specify NULL for this
 * parameter, and no error information will be provided.
 *
 * @return Returns #PLResultSetStatusRow if the next row is available, or #PLResultSetStatusDone if no
 * further rows are available. If an error occurs, #PLResultSetStatusError will be returned.
 */
- (PLResultSetStatus) nextAndReturnError: (NSError **) outError;

/**
 * Close the result set, and return any held database resources. After calling,
 * no further PLResultSet methods may be called on the instance.
 *
 * As PLResultSet objects may be placed into autorelease pools, with indeterminate
 * release of database resources, this method should be used to ensure that the
 * database connection remains usable once finished with a result set.
 *
 * Failure to call close will not result in any memory leaks, but may prevent
 * further use of the database connection (until the result set is released).
 */
- (void) close;

/**
 * Map the given column name to a column index. Will throw NSException if the column name is unknown.
 *
 * @param name Name of the column.
 * @return Returns the index of the column name, or throws an NSException if the column can not be found.
 */
- (int) columnIndexForName: (NSString *) name;

/**
 * Return the integer value of the given column index from the current result row.
 *
 * If the column value is NULL, 0 will be returned.
 *
 * Will throw NSException if the column index is out of range.
 */
- (int32_t) intForColumnIndex: (int) columnIdx;

/**
 * Return the integer value of the named column from the current result row.
 *
 * If the column value is NULL, 0 will be returned.
 *
 * Will throw NSException if the column name is unknown.
 */
- (int32_t) intForColumn: (NSString *) columnName;

/**
 * Return the string value of the given column index from the current result row.
 *
 * If the column value is NULL, nil will be returned.
 *
 * Will throw NSException if the column index is out of range.
 */
- (NSString *) stringForColumnIndex: (int) columnIndex;

/**
 * Return the string value of the named column from the current result row.
 *
 * If the column value is NULL, nil will be returned.
 *
 * Will throw NSException if the column name is unknown.
 */
- (NSString *) stringForColumn: (NSString *) columnName;

/**
 * Returns the 64 bit big integer (long) value of the given column index the current result row.
 *
 * If the column value is NULL, 0 will be returned.
 *
 * Will throw NSException if the column index is out of range.
 */
- (int64_t) bigIntForColumnIndex: (int) columnIndex;

/**
 * Returns the 64 bit big integer (long) value of the named column from the current result row.
 *
 * If the column value is NULL, 0 will be returned.
 *
 * Will throw NSException if the column name is unknown.
 */
- (int64_t) bigIntForColumn: (NSString *) columnName;

/**
 * Returns YES if the value of the given column index is NULL,
 * NO otherwise.
 *
 * Will throw NSException if the column index is out of range.
 */
- (BOOL) isNullForColumnIndex: (int) columnIndex;

/**
 * Returns YES if the value of the named column is NULL,
 * NO otherwise.
 *
 * Will throw NSException if the column index is out of range.
 */
- (BOOL) isNullForColumn: (NSString *) columnName;

/**
 * Returns the BOOL value of the named column from the current result row.
 *
 * If the column value is NULL, NO will be returned.
 *
 * Will throw NSException if the column name is unknown.
 */
- (BOOL) boolForColumn: (NSString *) columnName;

/**
 * Returns the BOOL value of the given column index from the  current result row.
 *
 * If the column value is NULL, NO will be returned.
 *
 * Will throw NSException if the column index is out of range.
 */
- (BOOL) boolForColumnIndex: (int) columnIndex;

/**
 * Returns the float value of the named column from the current result row.
 *
 * If the column value is NULL, 0.0 will be returned.
 *
 * Will throw NSException if the column name is unknown.
 */
- (float) floatForColumn: (NSString *) columnName;

/**
 * Returns the float value of the given column index from the  current result row.
 *
 * If the column value is NULL, 0.0 will be returned.
 *
 * Will throw NSException if the column index is out of range,
 * or if the column value is NULL.
 */
- (float) floatForColumnIndex: (int) columnIndex;

/**
 * Returns the double value of the named column from the current result row.
 *
 * If the column value is NULL, 0.0 will be returned.
 *
 * Will throw NSException if the column name is unknown.
 */
- (double) doubleForColumn: (NSString *) columnName;

/**
 * Returns the double value of the given column index from the current result row.
 *
 * If the column value is NULL, 0.0 will be returned.
 *
 * Will throw NSException if the column index is out of range.
 */
- (double) doubleForColumnIndex: (int) columnIndex;

/**
 * Returns the NSDate value of the named column from the current result row.
 *
 * If the column value is NULL, nil will be returned.
 *
 * Will throw NSException if the column name is unknown.
 */
- (NSDate *) dateForColumn: (NSString *) columnName;

/**
 * Returns the NSDate value of the given column index from the current result row.
 *
 * If the column value is NULL, nil will be returned.
 *
 * Will throw NSException if the column index is out of range.
 */
- (NSDate *) dateForColumnIndex: (int) columnIndex;

/**
 * Returns the NSData value of the named column from the current result row.
 *
 * If the column value is NULL, nil will be returned.
 *
 * Will throw NSException if the column name is unknown.
 */
- (NSData *) dataForColumn: (NSString *) columnName;

/**
 * Returns the NSData value of the given column index from the  current result row.
 *
 * If the column value is NULL, nil will be returned.
 *
 * Will throw NSException if the column index is out of range.
 */
- (NSData *) dataForColumnIndex: (int) columnIndex;

/**
 * Return the value of the named column as a Foundation Objective-C  object, using the database driver's built-in
 * SQL and Foundation data-type mappings.
 *
 * If the column value is NULL, nil will be returned.
 *
 * Will throw NSException if the column name is unknown.
 *
 * @param columnName Name of column value to return.
 *
 * @warning In previous releases, NSNull was returned for NULL column values. This behavior was not documented,
 * and the implementation has been modified to return nil.
 */
- (id) objectForColumn: (NSString *) columnName;

/**
 * Return the value of the named column as a Foundation Objective-C  object, using the database driver's built-in
 * SQL and Foundation data-type mappings.
 *
 * If the column value is NULL, nil will be returned.
 *
 * Will throw NSException if the column index is out of range.
 *
 * @param columnIndex Index of column value to return.
 *
 * @warning In previous releases, NSNull was returned for NULL column values. This behavior was not documented,
 * and the implementation has been modified to return nil.
 */
- (id) objectForColumnIndex: (int) columnIndex;
@end

