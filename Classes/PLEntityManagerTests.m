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

@interface PLEntityManagerTests : SenTestCase {
@private
    PLEntityManager *_manager;
}
@end

@interface PLEntityManagerExampleEntity : PLEntity {
@private
    /** Row id */
    NSNumber *_rowId;
    
    /** First name */
    NSString *_name;
}
@end

@implementation PLEntityManagerTests

- (void) setUp {
    /* Create an entity manager */
    _manager = [[PLMockEntityManager alloc] init];
}

- (void) tearDown {
    [_manager release];
}

- (void) testInit {
    PLEntityManager *entityManager;
    PLSqliteEntityDialect *dialect;
    PLSqliteEntityConnectionDelegate *delegate;
    
    /* Set up a delegate and dialect */
    delegate = [[[PLSqliteEntityConnectionDelegate alloc] initWithPath: @":memory:"] autorelease];
    dialect = [[[PLSqliteEntityDialect alloc] init] autorelease];

    /* Create the entity manager */
    entityManager = [[[PLEntityManager alloc] initWithConnectionDelegate: delegate sqlDialect: dialect] autorelease];
    STAssertNotNil(entityManager, @"Could not initialize entity manager");
}

- (void) testOpenSession {
    NSError *error;

    PLEntitySession *session;

    session = [_manager openSessionAndReturnError: &error];
    STAssertNotNil(session, @"Could not open session: %@", error);
    [session close];
    
    session = [_manager openSession];
    STAssertNotNil(session, @"Could not open session");
    [session close];
}

- (void) testConnectionDelegate {
    STAssertNotNil([_manager connectionDelegate], @"Could not retrieve connection delegate");
}

- (void) testDialect {
    STAssertNotNil([_manager dialect], @"Could not retrieve sql dialect");
}

- (void) testDescriptionForEntity {
    STAssertNotNil([_manager descriptionForEntity: [PLEntityManagerExampleEntity class]], @"Could not fetch entity description");
}

@end

/**
 * @internal
 * The example entity
 */
@implementation PLEntityManagerExampleEntity

+ (PLEntityDescription *) entityDescription {
    return [PLEntityDescription descriptionForClass: [self class] tableName: @"People" properties:
        [NSArray arrayWithObjects:
            [PLEntityProperty propertyWithKey: @"rowId" columnName: @"id" attributes: PLEntityPAPrimaryKey, PLEntityPAGeneratedValue, nil],
            [PLEntityProperty propertyWithKey: @"name" columnName: @"name"],
            nil
        ]
    ];
}

@end