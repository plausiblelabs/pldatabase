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

#import <SenTestingKit/SenTestingKit.h>

#import "PlausibleDatabase.h"
#import "PLMockEntityManager.h"

@interface PLEntitySessionTests : SenTestCase {
@private
    PLMockEntityManager *_manager;
    PLEntitySession *_tx;
    PLSqliteDatabase *_db;
}
@end

@interface PLEntitySessionExampleEntity : PLEntity {
@private
    NSNumber *_rowId;
    NSString *_firstName;
    NSString *_lastName;
}

- (id) initWithFirstName: (NSString *) firstName lastName: (NSString *) lastName;
- (NSNumber *) rowId;
- (NSString *) firstName;
- (NSString *) lastName;

@end


@implementation PLEntitySessionTests


- (void) setUp {
    _manager = [[PLMockEntityManager alloc] init];
    _tx = [[PLEntitySession alloc] initWithEntityManager: _manager error: nil];

    /* Create our schema */
    _db = [[_manager database] retain];
    STAssertTrue([_db open], nil);
    STAssertTrue([_db executeUpdate: @"CREATE TABLE People ("
                  "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                  "first_name VARCHAR(150),"
                  "last_name VARCHAR(150))"], @"Could not create People table");
}

- (void) tearDown {
    [_manager release];
    [_tx release];
    [_db release];
}

- (void) testInit {
    PLEntitySession *tx = [[[PLEntitySession alloc] initWithEntityManager: _manager error: nil] autorelease];

    STAssertNotNil(tx, @"Could not initialize transaction");
}

/* Test insert with a generated primary key */
- (void) testInsertEntity {
    PLEntitySessionExampleEntity *entity;
    NSError *error;

    /* Insert the entity */
    entity = [[[PLEntitySessionExampleEntity alloc] initWithFirstName: @"Johnny" lastName: @"Appleseed"] autorelease];
    STAssertTrue([_tx insertEntity: entity error: &error], @"Could not INSERT entity: %@", error);
    STAssertNotNil([entity rowId], @"Entity primary key was not populated");

    /* Verify that he arrived */
    NSObject<PLResultSet> *rs;
    rs = [_db executeQueryAndReturnError: &error statement: @"SELECT * FROM People WHERE first_name = ?", @"Johnny"];
    STAssertNotNil(rs, @"Could not execute query: %@", error);
    STAssertTrue([rs next], @"No results returned");
    
    STAssertTrue([@"Johnny" isEqual: [rs stringForColumn: @"first_name"]], @"Unexpected name value");
    STAssertTrue([@"Appleseed" isEqual: [rs stringForColumn: @"last_name"]], @"Unexpected name value");
    [rs close];
}

/* Test insert with a previously generated primary key */
- (void) testInsertEntityWithPrimaryKey {
    PLEntitySessionExampleEntity *entity;
    NSError *error;
    
    /* Insert the entity */
    entity = [[[PLEntitySessionExampleEntity alloc] initWithFirstName: @"Johnny" lastName: @"Appleseed"] autorelease];
    [entity setValue: [NSNumber numberWithInt: 42] forKey: @"rowId"];
    STAssertTrue([_tx insertEntity: entity error: &error], @"Could not INSERT entity: %@", error);
    STAssertNotNil([entity rowId], @"Entity primary key was not populated");
    
    /* Verify that he arrived */
    NSObject<PLResultSet> *rs;
    rs = [_db executeQueryAndReturnError: &error statement: @"SELECT * FROM People WHERE id = ?", [NSNumber numberWithInt: 42]];
    STAssertNotNil(rs, @"Could not execute query: %@", error);
    STAssertTrue([rs next], @"No results returned");

    STAssertEquals([rs intForColumn: @"id"], 42, @"Unexpected id value");
    STAssertTrue([@"Johnny" isEqual: [rs stringForColumn: @"first_name"]], @"Unexpected name value");
    STAssertTrue([@"Appleseed" isEqual: [rs stringForColumn: @"last_name"]], @"Unexpected name value");
    [rs close];    
}

- (void) testDeleteEntity {
    PLEntitySessionExampleEntity *entity;
    NSError *error;
    
    /* Insert the entity */
    entity = [[[PLEntitySessionExampleEntity alloc] initWithFirstName: @"Johnny" lastName: @"Appleseed"] autorelease];
    STAssertTrue([_tx insertEntity: entity error: &error], @"Could not INSERT entity: %@", error);
    
    /* Verify that he arrived */
    NSObject<PLResultSet> *rs;
    rs = [_db executeQueryAndReturnError: &error statement: @"SELECT * FROM People WHERE first_name = ?", @"Johnny"];
    STAssertNotNil(rs, @"Could not execute query: %@", error);
    STAssertTrue([rs next], @"No results returned");
    [rs close];

    /* Delete the entity */
    STAssertTrue([_tx deleteEntity: entity error: &error], @"Could not DELETE entity: %@", error);

    /* Verify the entry was deleted */
    rs = [_db executeQueryAndReturnError: &error statement: @"SELECT * FROM People WHERE first_name = ?", @"Johnny"];
    STAssertNotNil(rs, @"Could not execute query: %@", error);
    STAssertFalse([rs next], @"Result returned when not expected");
    [rs close];
}

- (void) testInTransaction {
    STAssertFalse([_tx inTransaction], @"Transaction started active");

    /* Try begin + commit */
    STAssertTrue([_tx begin], @"Could not start transaction");
    STAssertTrue([_tx inTransaction], @"Transaction active, but inTransaction returned false");
    STAssertTrue([_tx commit], @"Could not commit transaction");
    STAssertFalse([_tx inTransaction], @"Transaction not active, but inTransaction returned true");

    /* Try begin + rollback */
    STAssertTrue([_tx begin], @"Could not start transaction");
    STAssertTrue([_tx inTransaction], @"Transaction active, but inTransaction returned false");
    STAssertTrue([_tx rollback], @"Could not commit transaction");
    STAssertFalse([_tx inTransaction], @"Transaction not active, but inTransaction returned true");
}


- (void) testBegin {
    STAssertFalse([_tx commit], @"Commit return true, but transaction not started");
    STAssertTrue([_tx begin], @"Could not start transaction");
    STAssertTrue([_tx commit], @"Could not commit transaction");

}


- (void) testCommit {
    STAssertTrue([_tx begin], @"Could not start transaction");
    STAssertTrue([_tx commit], @"Could not commit transaction");
    STAssertFalse([_tx commit], @"Commit return true, but transaction not started");
}


- (void) testRollback {
    STAssertTrue([_tx begin], @"Could not start transaction");
    STAssertTrue([_tx rollback], @"Could not rollback transaction");
    STAssertTrue([_tx begin], @"Begin return false, but transaction not started");
}

@end

@implementation PLEntitySessionExampleEntity

+ (PLEntityDescription *) entityDescription {
    PLEntityDescription *desc;
    
    desc = [PLEntityDescription descriptionForClass: [self class] tableName: @"People" properties:
        [NSArray arrayWithObjects:
            [PLEntityProperty propertyWithKey: @"rowId" columnName: @"id" attributes: PLEntityPAPrimaryKey, PLEntityPAGeneratedValue, nil],
            [PLEntityProperty propertyWithKey: @"firstName" columnName: @"first_name"],
            [PLEntityProperty propertyWithKey: @"lastName" columnName: @"last_name"],
            nil
        ]
    ];

    return desc;
}

- (id) init {
    if ((self = [super init]) == nil)
        return nil;
    
    return self;
}

- (id) initWithFirstName: (NSString *) firstName lastName: (NSString *) lastName {
    if (![self init])
        return nil;
    
    _firstName = [firstName retain];
    _lastName = [lastName retain];
    
    return self;
}

- (void) dealloc {
    [_rowId release];
    [_firstName release];
    [_lastName release];
    
    [super dealloc];
}

- (NSNumber *) rowId {
    return _rowId;
}

- (NSString *) firstName {
    return _firstName;
}

- (NSString *) lastName {
    return _lastName;
}

@end


