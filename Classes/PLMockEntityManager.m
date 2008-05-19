//
//  PLMockEntityManager.m
//  PlausibleDatabase
//
//  Created by Landon Fuller on 5/14/08.
//  Copyright 2008 Plausible Labs. All rights reserved.
//

#import "PlausibleDatabase.h"
#import "PLMockEntityManager.h"

/**
 * @internal
 *
 * Creates a testing-only entity manager, backed by a real, empty (embedded) database.
 */
@implementation PLMockEntityManager

- (id) init {
    PLSqliteEntityConnectionDelegate *connectionDelegate;
    PLSqliteEntityDialect *sqlDialect;
    NSString *path;
    
    /* Create a temporary file for the database. Secure -- user owns enclosing directory. */
    path = [NSTemporaryDirectory() stringByAppendingPathComponent: [[NSProcessInfo processInfo] globallyUniqueString]];

    /* Set up our supporting classes */
    connectionDelegate = [[[PLSqliteEntityConnectionDelegate alloc] initWithPath: path] autorelease];
    sqlDialect = [[[PLSqliteEntityDialect alloc] init] autorelease];

    /* Initialized our superclass */
    self = [super initWithConnectionDelegate: connectionDelegate sqlDialect: sqlDialect];
    if (self == nil)
        return nil;

    /* Need to delete this on cleanup */
    _dbPath = [path retain];

    return self;
}

- (void) dealloc {
    /* Remove the temporary database file */
    if (![[NSFileManager defaultManager] removeItemAtPath: _dbPath error: nil])
        NSLog(@"Could not delete PLMockEntityManager temporary database"); 

    [_dbPath release];

    [super dealloc];
}


/**
 * @internal
 * Return a new unopen connection to the backing database.
 */
- (PLSqliteDatabase *) database {
    return [PLSqliteDatabase databaseWithPath: _dbPath];
}

@end
