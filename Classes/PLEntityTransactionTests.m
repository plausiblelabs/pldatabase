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

#import <SenTestingKit/SenTestingKit.h>
#import <OCMock/OCMock.h>

#import "PlausibleDatabase.h"

@interface PLEntityTransactionTests : SenTestCase {
@private
    OCMockObject *_mockDB;
    PLEntityTransaction *_tx;
}
@end


@implementation PLEntityTransactionTests

- (void) setUp {
    PLEntityManager *entityManager;
    OCMockObject *_mockDBDelegate;

    /* Create the mock database */
    _mockDB = [[OCMockObject mockForProtocol:@protocol(PLDatabase)] retain];

    /* Create the mock database delegate */
    _mockDBDelegate = [OCMockObject mockForProtocol:@protocol(PLEntityConnectionDelegate)];
    [[[_mockDBDelegate stub] andReturn: _mockDB] getConnectionAndReturnError: (NSError **) OCMOCK_ANY];

    /* Create the entity manager */
    PLSqliteEntityDialect *dialect = [[[PLSqliteEntityDialect alloc] init] autorelease];
    entityManager = [[[PLEntityManager alloc] initWithConnectionDelegate: (NSObject<PLEntityConnectionDelegate> *) _mockDBDelegate
                                                           entityDialect: dialect] autorelease];

    /* Create a transaction */
    _tx = [[PLEntityTransaction alloc] initWithEntityManager: (PLEntityManager *) entityManager];
}

- (void) tearDown {
    [_tx release];
    [_mockDB release];
}

- (void) testInit {
    PLEntityTransaction *tx;
    OCMockObject *manager;
    
    /* Create the mock manager */
    manager = [OCMockObject mockForClass: [PLEntityManager class]];    

    /* Set up an entity transaction */
    tx = [[[PLEntityTransaction alloc] initWithEntityManager: (PLEntityManager *) manager] autorelease];
    STAssertNotNil(tx, @"Could not initialize the transaction instance");
}


/*
 * For begin, commit, and rollback, we abuse the shared database connection to validate
 * transaction state.
 */
- (void) testBegin {
    BOOL yes = YES;
    NSValue *yesValue = [NSValue value: &yes withObjCType: @encode(BOOL)];

    [[[_mockDB expect] andReturnValue: yesValue] beginTransactionAndReturnError: (NSError **) OCMOCK_ANY];
    STAssertTrue([_tx begin], @"Transaction was not started?");

    [_mockDB verify];
}


- (void) testCommit {
    /* Configure the mock */
    
    
    [_tx begin];
//    STAssertTrue([_tx commit], @"Could not commit transaction -- was a transaction open?");
}


- (void) testRollback {
}


@end
