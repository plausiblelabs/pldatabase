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

#import "PLDatabaseMigrationConnectionProvider.h"


/**
 *
 * The PLDatabaseMigrationConnectionProvider implements the PLDatabaseConnectionProvider protocol, providing
 * transactional migration of all returned connections via the PLDatabaseMigrationManager API.
 *
 * Connections are acquired (and returned) to a backing PLDatabaseConnectionProvider, and providers may be arbitrarily
 * stacked; for instance, a PLDatabaseMigrationConnectionProvider may be wrapped by a PLDatabaseConnectionPool, thus pooling
 * migrated connections.
 *
 * @par Thread Safety
 * Thread-safe. May be used from any thread.
 */
@implementation PLDatabaseMigrationConnectionProvider

/**
 * Initialize a new migration connection provider.
 *
 * @param conProv The connection provider to be used to acquire and perform migrations upon new connections.
 * @param migrationManager The migration manager to be used to perform migrations on connections acquired from @a conProv.
 */
- (id) initWithConnectionProvider: (id<PLDatabaseConnectionProvider>) conProv
                 migrationManager: (PLDatabaseMigrationManager *) migrationManager
{
    if ((self = [super init]) == nil)
        return nil;
    
    _conProv = [conProv retain];
    _migrationMgr = [migrationManager retain];

    return self;
}

- (void) dealloc {
    [_conProv release];
    [_migrationMgr release];

    [super dealloc];
}

// from PLDatabaseConnectionProvider protocol
- (id<PLDatabase>) getConnectionAndReturnError: (NSError **) outError {
    /* Get the database connection */
    id<PLDatabase> db = [_conProv getConnectionAndReturnError: outError];
    if (db == nil)
        return nil;

    /* Run migrations */
    if (![_migrationMgr migrateDatabase: db error: outError])
        return nil;

    /* Success! */
    return db;
}

// from PLDatabaseConnectionProvider protocol
- (void) closeConnection: (id<PLDatabase>) connection {
    /* Simply hand the connection back to the backing provider. */
    [_conProv closeConnection: connection];
}

@end
