//
//  PlausibleDatabaseTests.m
//  PlausibleDatabase
//
//  Created by Landon Fuller on 5/8/08.
//  Copyright 2008 Plausible Labs. All rights reserved.
//


#import <SenTestingKit/SenTestingKit.h>

#import "PlausibleDatabase.h"

@interface PlausibleDatabaseTests : SenTestCase {
@private
}

@end

@implementation PlausibleDatabaseTests

/* Test NSError creation */
- (void) testDatabaseError {
    NSError *error = [PlausibleDatabase databaseError: PLDatabaseErrorFileNotFound localizedDescription: @"test"];

    STAssertTrue([PLDatabaseErrorDomain isEqual: [error domain]], @"Domain incorrect");
    STAssertEquals(PLDatabaseErrorFileNotFound, [error code], @"Code incorrect");
    STAssertTrue([@"test" isEqual: [error localizedDescription]], @"Description incorrect");
}

@end