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

/**
 * The PLEntityTransaction is used to control transactions on its enclosing
 * PLEntityManager.
 */
@implementation PLEntityTransaction


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
- (BOOL) begin {
    return [self beginAndReturnError: nil];
}


/**
 * Begin a transaction. This must provide at least 'Read committed' isolation. As
 * per the SQL standard, the isolation level may be stricter than what has been
 * requested -- this method only gaurantees the MINIMUM of isolation.
 *
 * For more information on SQL standard transaction isolation levels, refer to
 * PostgreSQL's documentation:
 *    http://www.postgresql.org/docs/8.3/interactive/transaction-iso.html
 *
 * @param error A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the transaction could not
 * be started.
 *
 * If no error occurs, this parameter will be left unmodified. You may specify nil for this
 * parameter, and no error information will be provided.
 * @return YES on success, NO on failure.
 */
- (BOOL) beginAndReturnError: (NSError **) error {
    return NO; // XXX TODO
}


/**
 * Commit an open transaction.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) commit {
    return [self commitAndReturnError: nil];
}


/**
 * Commit an open transaction.
 *
 * @param error A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the transaction could not
 * be committed.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) commitAndReturnError: (NSError **) error {
    return NO; // XXX TODO
}


/**
 * Rollback an open transaction.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) rollback {
    return [self rollbackAndReturnError: nil];
}


/**
 * Rollback an open transaction.
 *
 * @param error A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the transaction could not
 * be rolled back.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) rollbackAndReturnError: (NSError **) error {
    return NO; // XXX TODO
}

@end
