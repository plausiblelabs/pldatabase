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
 * An object that represents a pre-compiled statement, and any parameters
 * bound to that statement.
 *
 * @paragraph SQL Parameters
 * Query parameters may be specified as either named parameters (:name) or unamed parameters '?'.
 * XXX TODO described named vs unnamed parameter binding.
 *
 * @paragraph Thread Safety
 * PLPreparedStatement implementations are stateful, and access is not synchronized. It is not
 * safe to share instances between threads without external synchronization.
 *
 * @warning A prepared statement may not be re-used by simultaneous PLResultSet. Attempting to 
 * either re-execute a statement or rebind its parameters without first closing any PLResultSet previously
 * returned by the statement will throw an exception.
 */
@protocol PLPreparedStatement

/**
 * Returns the number of parameters in the prepared statement.
 */
- (int) parameterCount;

/**
 * Bind a list of parameters to the prepared statement. All parameters
 * must be provided -- if less than PLPreparedStatement::parameterCount
 * values are provided, an exception will be thrown.
 *
 * @param parameters List of parameters to bind.
 * @note NSArray may not contain nil values. Any nil parameter values must be
 * supplied using NSNull.
 */
- (void) bindParameters: (NSArray *) parameters;


/**
 * Execute an update, returning YES on success, NO on failure.
 */
- (BOOL) executeUpdate;


/**
 * Execute an update, returning YES on success, NO on failure.
 *
 * @param outError A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the statement could not be executed.
 * If no error occurs, this parameter will be left unmodified. You may specify nil for this
 * parameter, and no error information will be provided.
 * @param statement SQL statement to execute.
 *
 */
- (BOOL) executeUpdateAndReturnError: (NSError **) outError;


/**
 * Execute a query, returning a PLResultSet.
 *
 * @return PLResultSet on success, or nil on failure.
 */
- (NSObject<PLResultSet> *) executeQuery;


/**
 * Execute a query, returning a PLResultSet.
 *
 * @param outError A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the statement could not be executed.
 * If no error occurs, this parameter will be left unmodified. You may specify nil for this
 * parameter, and no error information will be provided.
 * @param statement SQL statement to execute.
 * @return PLResultSet on success, or nil on failure.
 */
- (NSObject<PLResultSet> *) executeQueryAndReturnError: (NSError **) outError;

/**
 * Close the prepared statement, and return any held database resources. After calling,
 * no further PLPreparedStatement methods may be called on the instance.
 *
 * As PLPreparedStatement objects may be placed into autorelease pools with indeterminate
 * release of database resources, this method may be used to ensure that resources
 * are free'd in a timely fashion.
 *
 * Failure to call close will not result in any memory leaks.
 */
- (void) close;

@end