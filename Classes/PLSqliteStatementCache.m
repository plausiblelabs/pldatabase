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

#import "PLSqliteStatementCache.h"

static const CFArrayCallBacks StatementCacheArrayCallbacks = {
    .version = 0,
    .retain = NULL,
    .release = NULL,
    .copyDescription = NULL,
    .equal = NULL
};

static const CFSetCallBacks StatementCacheSetCallbacks = {
    .version = 0,
    .retain = NULL,
    .release = NULL,
    .copyDescription = NULL,
    .equal = NULL,
    .hash = NULL
};

@interface PLSqliteStatementCache (PrivateMethods)
static void cache_statement_finalize (const void *value, void *context);
- (void) removeAllStatementsHasLock: (BOOL) locked;
@end

/**
 * @internal
 *
 * Manages a cache of sqlite3_stmt instances, providing a mapping from query string to a sqlite3_stmt.
 *
 * The implementation naively evicts all statements should the cache become full. Future enhancement
 * may include implementing an LRU strategy, but it's not expected that many users will be executing
 * more unique queries than will fit in a reasonably sized cache.
 *
 * @par Thread Safety
 *
 * Unlike most classes in this library, PLSqliteStatementCache is thread-safe; this is intended to allow the safe
 * finalization/deallocation of SQLite ojects from multiple threads.
 *
 * Note, however, that the implementation is optimized for minimal contention.
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
    _availableStatements = [[NSMutableDictionary alloc] init];
    _allStatements = CFSetCreateMutable(NULL, 0, &StatementCacheSetCallbacks);

    /* Disable collection of _availableStatements; we need this to live until our finalizer has run. */
#ifdef __OBJC_GC__
    [[NSGarbageCollector defaultCollector] disableCollectorForPointer: _availableStatements];
#endif /* __OBJC_GC__ */
    
    _lock = OS_SPINLOCK_INIT;

    return self;
}

- (void) finalize {
    /* The sqlite statements have to be finalized explicitly */
    [self close];

    OSSpinLockLock(&_lock); {
        if (_allStatements != NULL) {
                CFRelease(_allStatements);
                _allStatements = NULL;
        }
    } OSSpinLockUnlock(&_lock);

    /* Re-enable collection of _availableStatements */
#ifdef __OBJC_GC__
    [[NSGarbageCollector defaultCollector] enableCollectorForPointer: _availableStatements];
#endif /* __OBJC_GC__ */

    [super finalize];
}

- (void) dealloc {
    /* The sqlite statements have to be finalized explicitly */
    [self close];

    /* Re-enable collection of _availableStatements */
#ifdef __OBJC_GC__
    [[NSGarbageCollector defaultCollector] enableCollectorForPointer: _availableStatements];
#endif /* __OBJC_GC__ */

    [_availableStatements release];

    if (_allStatements != NULL) {
        CFRelease(_allStatements);
        _allStatements = NULL;
    }

    [super dealloc];
}

/**
 * Register a sqlite3 prepared statement for the given @a query. This is used to support properly ordered finalization
 * of both sqlite3_stmt references and the backing sqlite3 database; all statements that will be checked out
 * via checkoutStatementForQueryString: must be registered apriori.
 *
 * @param stmt The statement to register.
 * @param query The query string corresponding to this statement.
 *
 */
- (void) registerStatement: (sqlite3_stmt *) stmt {
    OSSpinLockLock(&_lock); {
        CFSetAddValue(_allStatements, stmt);
    }; OSSpinLockUnlock(&_lock);
}

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
    OSSpinLockLock(&_lock); {
        /* If the statement pointer is not currently registered, there's nothing to do here. This may occur if
         * a finalized PLSqlitePreparedStatement attempts to check in its statement, but the statement has already
         * been destroyed. */
        if (!CFSetContainsValue(_allStatements, stmt)) {
            OSSpinLockUnlock(&_lock);
            return;
        }

        /* Bump the count */
        _size++;
        if (_size > _capacity) {
            [self removeAllStatementsHasLock: YES];
        }

        /* Fetch the statement set for this query */
        CFMutableArrayRef stmtArray = (CFMutableArrayRef) [_availableStatements objectForKey: query];
        if (stmtArray == nil) {
            stmtArray = CFArrayCreateMutable(NULL, 0, &StatementCacheArrayCallbacks);
            [_availableStatements setObject: (id) stmtArray forKey: query];
            [(id)stmtArray release];
        }

        /* Claim ownership of the statement */
        sqlite3_reset(stmt);
        CFArrayAppendValue(stmtArray, stmt);
    }; OSSpinLockUnlock(&_lock);
}

/**
 * Check out a sqlite3 prepared statement for the given @a query, or NULL if none is cached.
 *
 * @param query The query string corresponding to this statement.
 *
 * @warning MEMORY OWNERSHIP WARNING: The caller is given ownership of the statement object, and MUST either deallocate
 * that object or provide it to PLSqliteStatementCache::checkinStatement:forQuery: for reclaimation.
 */
- (sqlite3_stmt *) checkoutStatementForQueryString: (NSString *) query {
    sqlite3_stmt *stmt;

    OSSpinLockLock(&_lock); {
        /* Fetch the statement set for this query */
        CFMutableArrayRef stmtArray = (CFMutableArrayRef) [_availableStatements objectForKey: query];
        if (stmtArray == nil || CFArrayGetCount(stmtArray) == 0) {
            OSSpinLockUnlock(&_lock);
            return NULL;
        }

        /* Pop the statement from the array */
        stmt = (sqlite3_stmt *) CFArrayGetValueAtIndex(stmtArray, 0);
        CFArrayRemoveValueAtIndex(stmtArray, 0);

        /* Decrement the count */
        _size--;
    }; OSSpinLockUnlock(&_lock);

    return stmt;
}

/**
 * Remove all unused statements from the cache. This will not invalidate active, in-use statements.
 */
- (void) removeAllStatements {
    [self removeAllStatementsHasLock: NO];
}

/**
 * Close the cache, invalidating <em>all</em> registered statements from the cache.
 *
 * @warning This will remove statements that may be in active use by PLSqlitePreparedStatement instances, and must
 * only be called by the PLSqliteDatabase prior to finalization.
 */
- (void) close {
    OSSpinLockLock(&_lock); {

        /* Finalize all registered statements */
        CFSetApplyFunction(_allStatements, cache_statement_finalize, NULL);
        CFSetRemoveAllValues(_allStatements);
        
        /* Empty the statement cache of the now invalid references. */
        [_availableStatements removeAllObjects];
    } OSSpinLockUnlock(&_lock);
}

@end

@implementation PLSqliteStatementCache (PrivateMethods)

static void cache_statement_finalize (const void *value, void *context) {
    sqlite3_stmt *stmt = (sqlite3_stmt *) value;
    sqlite3_finalize(stmt);
}

/**
 * Remove all unused statements from the cache. This will not invalidate active, in-use statements.
 *
 * @param locked If NO, the implementation will acquire a lock on _lock; otherwise,
 * it is assumed that _lock is already held.
 */
- (void) removeAllStatementsHasLock: (BOOL) locked {
    if (!locked)
        OSSpinLockLock(&_lock);
    
    /* Iterate over all cached queries and finalize their sqlite statements */
    [_availableStatements enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
        CFMutableArrayRef array = (CFMutableArrayRef) obj;
        CFIndex count = CFArrayGetCount(array);
        
        /* Finalize all statements */
        CFArrayApplyFunction(array, CFRangeMake(0, count), cache_statement_finalize, NULL);
    }];
    
    /* Empty the statement cache of the now invalid references. */
    [_availableStatements removeAllObjects];

    if (!locked)
        OSSpinLockUnlock(&_lock);
}

@end