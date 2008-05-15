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

#import "PlausibleDatabase.h"
#import "PLMockEntityManager.h"

@interface PLEntityTransactionTests : SenTestCase {
@private
    PLEntityManager *_manager;
    PLEntityTransaction *_tx;
}
@end

@implementation PLEntityTransactionTests


- (void) setUp {
    _manager = [[PLMockEntityManager alloc] init];
    _tx = [[PLEntityTransaction alloc] initWithEntityManager: _manager error: nil];
}

- (void) tearDown {
    [_manager release];
    [_tx release];
}

- (void) testInit {
    PLEntityTransaction *tx = [[[PLEntityTransaction alloc] initWithEntityManager: _manager error: nil] autorelease];

    STAssertNotNil(tx, @"Could not initialize transaction");
}

- (void) testInsertEntity {
    
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
