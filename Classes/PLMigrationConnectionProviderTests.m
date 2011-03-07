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

#import <SenTestingKit/SenTestingKit.h>

#import "PLMigrationConnectionProvider.h"
#import "PLSqliteConnectionProvider.h"
#import "PLSqliteMigrationManager.h"

#define TEST_VERSION 42

@interface PLMigrationConnectionProviderTests : SenTestCase <PLDatabaseMigrationDelegate> {
@private
}

@end


/**
 * PLDatabaseMigrationConnectionProvider Tests
 */
@implementation PLMigrationConnectionProviderTests

/**
 * Test simple migration
 */
- (void) testMigrate {
    PLMigrationConnectionProvider *mprov;
    PLSqliteMigrationManager *sqliteMgr;
    PLSqliteConnectionProvider *prov;
    PLDatabaseMigrationManager *mgr;

    /* Set up the migration manager */
    sqliteMgr = [[[PLSqliteMigrationManager alloc] init] autorelease];
    mgr = [[[PLDatabaseMigrationManager alloc] initWithTransactionManager: sqliteMgr
                                                           versionManager: sqliteMgr
                                                                 delegate: self] autorelease];

    /* Set up the connection providers */
    prov = [[[PLSqliteConnectionProvider alloc] initWithPath: @""] autorelease];
    mprov = [[[PLMigrationConnectionProvider alloc] initWithConnectionProvider: prov
                                                                      migrationManager: mgr] autorelease];

    /* Try fetching a connection, and verify that it has been migrated. */
    NSError *error;
    id<PLDatabase> db = [mprov getConnectionAndReturnError: &error];
    STAssertNotNil(db, @"Failed to fetch and migrate a connection: %@", error);

    int version = 0;
    STAssertTrue([sqliteMgr version: &version forDatabase: db error: &error], @"Failed to fetch the database version: %@", error);
    STAssertEquals(TEST_VERSION, version, @"Database migration was not executed");

    [mprov closeConnection: db];
}

// from PLDatabaseMigrationDelegate
- (BOOL) migrateDatabase: (id<PLDatabase>) database currentVersion: (int) currentVersion newVersion: (int *) newVersion error: (NSError **) outError {
    *newVersion = TEST_VERSION;
    return YES;
}

@end
