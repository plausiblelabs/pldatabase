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

#import "PlausibleDatabase.h"

/** Plausible Database Entity NSError Domain
 * @ingroup globals */
NSString *PLEntityErrorDomain = @"com.plausiblelabs.pldatabase.entity";

/**
 * Manages the object relational mapping between a database, and Objective-C objects
 * conforming to the PLEntity protocol.
 *
 * @par Thread Safety
 * PLEntityManager instances implement no locking and must not be shared between threads
 * without external synchronization. This may change in a future revision of the API.
 */
@implementation PLEntityManager

/**
 * Initialize a new entity manager with the given connection provider delegate, and SQL dialect.
 *
 * @param connectionDelegate Delegate responsible for providing database connections.
 * @param sqlDialect The SQL entity dialect for the given database.
 *
 * @par Designated Initializer
 * This method is the designated initializer for the PLEntityManager class.
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

/**
 * Opens a new entity session.
 *
 * @return Returns a new session, or nil if the session could not be opened.
 * @sa PLEntityManager::openSessionAndReturnError:
 */
- (PLEntitySession *) openSession {
    return [[[PLEntitySession alloc] initWithEntityManager: self error: nil] autorelease];
}

/**
 * Opens a new entity session.
 *
 * @param error A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the session could
 * not be opened. If no error occurs, this parameter will be left unmodified.
 * You may specify nil for this parameter, and no error information will be provided.
 *
 * @return Returns a new session, or nil if the session could not be opened.
 */
- (PLEntitySession *) openSessionAndReturnError: (NSError **) error {
    return [[[PLEntitySession alloc] initWithEntityManager: self error: error] autorelease];
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
- (PLEntityDialect *) dialect {
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
- (PLEntityDescription *) descriptionForEntity: (Class) entity {
    return [entity entityDescription];
}


@end