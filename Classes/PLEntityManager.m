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
 * Manages the object relational mapping between a database, and Objective-C objects
 * conforming to the PLEntity protocol.
 */
@implementation PLEntityManager

/**
 * Initialize a new entity manager with the given connection provider delegate, and SQL dialect.
 *
 * @param connectionDelegate Delegate responsible for providing database connections.
 * @param sqlDialect The SQL entity dialect for the given database.
 */
- (id) initWithConnectionDelegate: (NSObject<PLEntityConnectionDelegate> *) connectionDelegate sqlDialect: (PLEntityDialect *) sqlDialect {
    if ((self = [super init]) == nil)
        return nil;

    _connectionDelegate = [connectionDelegate retain];
    _sqlDialect = [sqlDialect retain];

    return self;
}


- (void) dealloc {
    [_connectionDelegate release];
    [_sqlDialect release];

    [super dealloc];
}

@end

/**
 * @internal
 * Library Private API
 */
@implementation PLEntityManager (PLEntityManagerLibraryPrivate)

/**
 * @internal
 * Return the connection delegate.
 */
- (NSObject<PLEntityConnectionDelegate> *) connectionDelegate {
    return _connectionDelegate;
}

/**
 * @internal
 * Return the entity dialect.
 */
- (PLEntityDialect *) sqlDialect {
    return _sqlDialect;
}


/**
 * @internal
 *
 * Return the (potentially cached) entity description for the given
 * class.
 *
 * @todo Implement LRU cache here, if measurements dictate.
 */
- (PLEntityDescription *) descriptionForEntity: (Class<PLEntity>) entity {
    return [entity entityDescription];
}


@end