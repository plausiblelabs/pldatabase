/*
 * Copyright (c) 2011 Plausible Labs Cooperative, Inc.
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

#import "PLSqliteStatementReference.h"
#import "PlausibleDatabase.h"

@interface PLSqliteStatementReference (PrivateMethods)

- (id) initWithStatement: (sqlite3_stmt *) statement
                  parent: (PLSqliteStatementReference *) parent
             queryString: (NSString *) queryString;

@end


/**
 * @internal
 *
 * Manages a reference to a sqlite3_stmt instance, providing support for safe invalidation of existing references.
 *
 * @par Thread Safety
 *
 * Unlike most classes in this library, PLSqliteStatementRef is thread-safe; this is intended to allow the safe
 * finalization/deallocation of SQLite data structures from multiple threads.
 *
 * Note, however, that the implementation is optimized for minimal contention.
 */
@implementation PLSqliteStatementReference

@synthesize queryString = _queryString;

/**
 * Initialize a new statement reference with the provided statement. The receiver will assume ownership of the
 * provided statement.
 *
 * @param statement A valid sqlite3_stmt reference.
 * @param queryString The original SQL query string.
 */
- (id) initWithStatement: (sqlite3_stmt *) statement queryString: (NSString *) queryString {
    return [self initWithStatement: statement parent: nil queryString: queryString];
}

- (void) finalize {
    [self invalidate];

    [super finalize];
}

- (void) dealloc {
    [self invalidate];
    [_parent release];

    [super dealloc];
}

/**
 * Invalidate and release the held statement reference.
 */
- (void) invalidate {
    OSSpinLockLock(&_lock); {
        /* If the statement hasn't already been finalized, do it now. Note that we must support being called from
         * within our own finalizer. */
        if (_stmt != NULL) {
            sqlite3_finalize(_stmt);
            _stmt = NULL;
        }

        if (_parent != NULL) {
            [_parent release];
            _parent = nil;
        }
    } OSSpinLockUnlock(&_lock);
}

/**
 * Clone the receiver, returning a child reference. Multiple child references may exist; the parent reference will
 * remain as long as any validated child references exist, unless the parent reference is explicitly invalidated.
 */
- (PLSqliteStatementReference *) cloneReference {
    /* Keep the child reference tree flat by returning our parent, if one is specified */
    PLSqliteStatementReference *parent;

    OSSpinLockLock(&_lock); {
        if (_parent == nil)
            parent = self;
        else
            parent = [[_parent retain] autorelease];
    } OSSpinLockUnlock(&_lock);

    return [[[PLSqliteStatementReference alloc] initWithStatement: NULL parent: parent queryString: _queryString] autorelease];    
}

/**
 * Execute the provided block immediately while holding a valid statement reference. If the statement has been
 * invalidated, the block will not be executed and NO will be returned.
 *
 * @param block The block to execute with a valid reference to the managed sqlite3_stmt.
 * @param outError A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the statement was unavailable. You may specify NULL
 * for this parameter, and no error information will be provided.
 */
- (BOOL) performWithStatement: (void (^)(sqlite3_stmt *stmt)) block error: (NSError **) outError {
    BOOL ret;

    /* Execute the block. We either do so directly, or if this is a child reference, we let the parent do so. */
    OSSpinLockLock(&_lock); {
        if (_stmt != NULL) {
            /* This is the primary reference and the statement is valid */
            block(_stmt);
            ret = YES;
            
        } else if (_parent != nil) {
            /* This is a child reference */
            ret = [_parent performWithStatement: block error: outError];

        } else {
            /* Reference is invalid */
            if (outError != NULL)
                *outError = [PlausibleDatabase errorWithCode: PLDatabaseErrorStatementInvalidated localizedDescription: NSLocalizedString(@"The statement has been re-used.", nil)];

            ret = NO;
        }

    } OSSpinLockUnlock(&_lock);

    return ret;
}

@end


@implementation PLSqliteStatementReference (PrivateMethods)

/**
 * Initialize a new statement reference with either a valid statement, or a non-nil parent reference.
 *
 * @param statement A valid sqlite3_stmt reference, or NULL if this is a child statement.
 * @param parent A valid parent reference, or nil if statement is non-NULL.
 * @param queryString The original SQL query string.
 */
- (id) initWithStatement: (sqlite3_stmt *) statement parent: (PLSqliteStatementReference *) parent queryString: (NSString *) queryString {
    if ((self = [super init]) == nil)
        return nil;
    
    _lock = OS_SPINLOCK_INIT;
    _parent = [parent retain];
    _stmt = statement;
    _queryString = [queryString copy];
    
    return self;
}

@end

