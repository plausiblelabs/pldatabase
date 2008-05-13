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
    NSError *error = [PlausibleDatabase errorWithCode: PLDatabaseErrorFileNotFound 
                                 localizedDescription: @"test"
                                          queryString: @"query"
                                          vendorError: [NSNumber numberWithInt: 42]
                                    vendorErrorString: @"native"];

    STAssertTrue([PLDatabaseErrorDomain isEqual: [error domain]], @"Domain incorrect");
    STAssertEquals(PLDatabaseErrorFileNotFound, [error code], @"Code incorrect");
    STAssertTrue([@"test" isEqual: [error localizedDescription]], @"Description incorrect");

    STAssertTrue([@"query" isEqual: [[error userInfo] objectForKey: PLDatabaseErrorQueryStringKey]], @"Query string incorrect");
    
    STAssertEquals(42, [[[error userInfo] objectForKey: PLDatabaseErrorVendorErrorKey] intValue], @"Native error code incorrect");
    STAssertTrue([@"native" isEqual: [[error userInfo] objectForKey: PLDatabaseErrorVendorStringKey]], @"Native error string incorrect");
}

@end