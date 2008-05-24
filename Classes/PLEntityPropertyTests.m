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

@interface PLEntityPropertyTests : SenTestCase
@end

@implementation PLEntityPropertyTests

- (void) testInitNotPrimaryKey {
    PLEntityProperty *propertyDescription;

    propertyDescription = [PLEntityProperty propertyWithKey: @"rowId" columnName: @"id"];
    STAssertNotNil(propertyDescription, @"Initializer returned nil");

    STAssertTrue([@"rowId" isEqual: [propertyDescription key]], @"KVC key incorrect");
    STAssertTrue([@"id" isEqual: [propertyDescription columnName]], @"Column name incorrect");
    STAssertFalse([propertyDescription isPrimaryKey], @"Property set as primary key");
    STAssertFalse([propertyDescription isGeneratedValue], @"Property set as generated value");
}

- (void) testInitPrimaryKey {    
    PLEntityProperty *propertyDescription;
    
    propertyDescription = [PLEntityProperty propertyWithKey: @"rowId" columnName: @"id" attributes: PLEntityPAPrimaryKey, PLEntityPAGeneratedValue, nil];
    STAssertNotNil(propertyDescription, @"Initializer returned nil");
    
    STAssertTrue([@"rowId" isEqual: [propertyDescription key]], @"KVC key incorrect");
    STAssertTrue([@"id" isEqual: [propertyDescription columnName]], @"Column name incorrect");
    STAssertTrue([propertyDescription isPrimaryKey], @"Property not set to primary key");
    STAssertTrue([propertyDescription isGeneratedValue], @"Property not set as generated value");
}

@end
