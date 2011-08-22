/*
 * Copyright (c) 2008-2011 Plausible Labs Cooperative, Inc.
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
#import <libkern/OSAtomic.h>

#ifndef PL_DB_PRIVATE
@class PLSqliteStatementCache;
#else

#import <sqlite3.h>

@interface PLSqliteStatementCache : NSObject {
@private
    /** Maximum size. */
    NSUInteger _capacity;
    
    /** Current size. */
    NSUInteger _size;

    /** Maps the query string to a CFMutableArrayRef containing sqlite3_stmt instances. We claim ownership for these statements. */
    NSMutableDictionary *_availableStatements;
    
    /** All live statements (whether or not they're checked out). */
    __strong CFMutableSetRef _allStatements;

    /** Internal lock. Must be held when mutating state. */
    OSSpinLock _lock;
}

- (id) initWithCapacity: (NSUInteger) capacity;

- (void) close;

- (void) registerStatement: (sqlite3_stmt *) stmt;

- (void) checkinStatement: (sqlite3_stmt *) stmt forQuery: (NSString *) query;

- (sqlite3_stmt *) checkoutStatementForQueryString: (NSString *) query;

- (void) removeAllStatements;

@end

#endif /* PL_DB_PRIVATE */