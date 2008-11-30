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


/**
 *
 * The PLDatabaseMigrationManager implements transactional, versioned migration/initialization of
 * database schema and data.
 *
 * Arbitrary migrations may be supplied via a PLDatabaseMigrationDelegate. The database versioning
 * meta-data is maintained by a supplied PLDatabaseMigrationVersionManager. This class makes no
 * assumptions about the migrations applied or the methods used to retrieve or update
 * database schema versions.
 *
 * @par Thread Safety
 * PLDatabaseMigrationManager instances are not required to implement any locking and must not be
 * shared between threads.
 */
@implementation PLDatabaseMigrationManager

/**
 * Manages database migration and initialization.
 *
 * @param connectionProvider Database conection provider.
 * @param lockManager An object implementing the PLDatabaseMigrationTransactionManager protocol.
 * @param versionManager An object implementing the PLDatabaseMigrationVersionManager protocol.
 * @param delegate An object implementing the formal PLDatabaseMigrationDelegate protocol.
 */
- (id) initWithConnectionProvider: (id<PLDatabaseConnectionProvider>) connectionProvider
                      transactionManager: (id<PLDatabaseMigrationTransactionManager>) lockManager
                   versionManager: (id<PLDatabaseMigrationVersionManager>) versionManager
                         delegate: (id<PLDatabaseMigrationDelegate>) delegate;
{
    assert(delegate != nil);
    assert(lockManager != nil);
    assert(versionManager != nil);
    assert(connectionProvider != nil);

    if ((self = [super init]) == nil)
        return nil;

    /* Save the delegates/providers */
    _delegate = delegate; // cyclic reference, can not retain
    _connectionProvider = [connectionProvider retain];
    _txManager = [lockManager retain];
    _versionManager = [versionManager retain];

    return self;
}


- (void) dealloc {
    [_connectionProvider release];
    [_txManager release];
    [_versionManager release];

    [super dealloc];
}


/**
 * Open a new database connection and allow the PLDatabaseMigrationDelegate to perform
 * any pending migrations.
 *
 * If the migration delegate returns success (YES), the PLDatabaseMigrationVersionManager will
 * be used to set the provided version number.
 *
 * If the delegate returns failure (NO), the database will not be modified in
 * any way (including the addition of a database version number).
 *
 * A transaction will be opened prior to the delegate being called. The transaction will
 * be committed upon the return of a success value (YES). If this method returns NO,
 * the entire transaction will be aborted.
 *
 * Failure to open the database, or returning NO from the delegate, will cause
 * database initialization to fail, and this method will return NO.
 *
 * @param outError A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the migration could not be completed.
 * If no error occurs, this parameter will be left unmodified. You may specify NULL for this
 * parameter, and no error information will be provided.
 * @return YES on successful migration, or NO if migration failed. If NO is returned, all modifications
 * will be rolled back.
 */
- (BOOL) migrateAndReturnError: (NSError **) outError {
    int currentVersion;
    int newVersion;
    id<PLDatabase> db;
    
    /* Open the database connection */
    db = [_connectionProvider getConnectionAndReturnError: outError];
    if (db == nil) {
        return NO;
    }

    /* Start a transaction, we'll do *all modifications* within this one transaction */
    if (![_txManager beginExclusiveTransactionForDatabase: db error: outError])
        goto cleanup;

    /* Fetch the current version. We default the new version to the current version -- failure to do so
     * will result in the database version being reset should the delegate forget to set the version
     * on a migration returning YES but implementing no changes. */
    if (![_versionManager version: &currentVersion forDatabase: db error: outError])
        goto rollback;
    
    newVersion = currentVersion;

    /* Run the migration */
    if (![_delegate migrateDatabase: db currentVersion: currentVersion newVersion: &newVersion error: outError])
        goto rollback;

    if (![_versionManager setVersion: newVersion forDatabase: db error: outError])
        goto rollback;

    if (![_txManager commitTransactionForDatabase: db error: outError])
        goto rollback;

    /* Return our connection to the provider */
    [_connectionProvider closeConnection: db];

    /* Create and return the new manager */
    return YES;

rollback:
    [_txManager rollbackTransactionForDatabase: db error: NULL];
cleanup:
    [_connectionProvider closeConnection: db];
    return NO;
}

@end
