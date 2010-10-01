/*
 * Copyright (c) 2008-2010 Plausible Labs Cooperative, Inc.
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
#import <CoreFoundation/CoreFoundation.h>

/**
 * Manages a cache of sqlite3_stmt instances, providing a mapping from query string to a sqlite3_stmt.
 *
 * The implementation naively evicts all statements should the cache become full. Future enhancement
 * may include implementing an LRU strategy, but it's not expected that many users will be executing
 * more unique queries than will fit in a reasonably sized cache.
 */
@implementation PLSqliteStatementCache

/**
 * Initialize the cache with the provided query @a capacity. The cache will discard sqlite3_stmt instances to stay
 * within the given capacity.
 *
 * @param capacity Maximum cache capacity.
 */
- (id) initWithCapacity: (NSUInteger) capacity {
    if ((self = [super init]) == nil)
        return nil;
    
    _capacity = capacity;
    _statements = [[NSMutableDictionary alloc] init];

    return self;
}

- (void) finalize {
    /* The sqlite statements have to be finalized explicitly */
    [self removeAllStatements];

    [super finalize];
}

- (void) dealloc {
    /* The sqlite statements have to be finalized explicitly */
    [self removeAllStatements];

    [_statements release];

    [super dealloc];
}

static const CFArrayCallBacks StatementCacheArrayCallbacks = {
    .version = 0,
    .retain = NULL,
    .release = NULL,
    .copyDescription = NULL,
    .equal = NULL
};

/**
 * Check in an sqlite3 prepared statement for the given @a query, making it available for re-use from the cache.
 * The statement will be reset (via sqlite3_reset()).
 *
 * @param stmt The statement to check in.
 * @param query The query string corresponding to this statement.
 *
 * @warning MEMORY OWNERSHIP WARNING: The receiver will claim ownership of the statement object.
 */
- (void) checkinStatement: (sqlite3_stmt *) stmt forQuery: (NSString *) query {
    /* Bump the count */
    _size++;
    if (_size > _capacity)
        [self removeAllStatements];

    /* Fetch the statement set for this query */
    CFMutableArrayRef stmtArray = (CFMutableArrayRef) [_statements objectForKey: query];
    if (stmtArray == nil) {
        stmtArray = CFArrayCreateMutable(NULL, 0, &StatementCacheArrayCallbacks);
        CFMakeCollectable(stmtArray);

        [_statements setObject: (id) stmtArray forKey: query];
    }

    /* Claim ownership of the statement */
    sqlite3_reset(stmt);
    CFArrayAppendValue(stmtArray, stmt);
}

/**
 * Check out a sqlite3 prepared statement for the given @a query, or NULL if none is cached.
 *
 * @param query The query string corresponding to this statement.
 *
 * @warning MEMORY OWNERSHIP WARNING: The caller is given ownership of the statement object, and MUST either deallocate
 * that object or provide it to PLSqliteStatementCache::checkinStatement:forQuery: for reclaimation.
 */
- (sqlite3_stmt *) checkoutStatementForQuery: (NSString *) query {
    /* Fetch the statement set for this query */
    CFMutableArrayRef stmtArray = (CFMutableArrayRef) [_statements objectForKey: query];
    if (stmtArray == nil)
        return NULL;

    if (CFArrayGetCount(stmtArray) == 0)
        return NULL;

    /* Pop the statement from the array */
    sqlite3_stmt *stmt = (sqlite3_stmt *) CFArrayGetValueAtIndex(stmtArray, 0);
    CFArrayRemoveValueAtIndex(stmtArray, 0);

    return stmt;
}

/**
 * Remove all statements from the cache.
 */
- (void) removeAllStatements {
    /* Iterate over and finalize all statements */
    for (NSString *query in _statements) {
        CFMutableArrayRef stmtArray = (CFMutableArrayRef) [_statements objectForKey: query];
        CFIndex stmtCount = CFArrayGetCount(stmtArray);

        /* Finalize all statements */
        for (CFIndex i = 0; i < stmtCount; i++) {
            sqlite3_stmt *stmt = (sqlite3_stmt *) CFArrayGetValueAtIndex(stmtArray, i);
            sqlite3_finalize(stmt);
        }
        
        /* Now remove them all */
        CFArrayRemoveAllValues(stmtArray);
    }
}

@end
