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

@interface PLEntityDescriptionTests : SenTestCase
@end


@interface ExampleEntity : NSObject <PLEntity> {
@private
    /** Row id */
    NSNumber *rowId;

    /** First name */
    NSString *firstName;

    /** Last name */
    NSString *lastName;
}
@end


@implementation ExampleEntity

+ (PLEntityDescription *) entityDescription {
    PLEntityDescription *desc = [PLEntityDescription descriptionForClass: [self class] tableName: @"People"];

    /* Define our columns */
    [desc addPropertyDescription: [PLEntityPropertyDescription descriptionWithKey: @"rowId" columnName: @"id"] isPrimaryKey: YES];
    [desc addPropertyDescription: [PLEntityPropertyDescription descriptionWithKey: @"firstName" columnName: @"first_name"]];
    [desc addPropertyDescription: [PLEntityPropertyDescription descriptionWithKey: @"lastName" columnName: @"last_name"]];

    return desc;
}

- (NSNumber *) rowId {
    return rowId;
}

- (NSString *) firstName {
    return firstName;
}

- (NSString *) lastName {
    return lastName;
}

@end


@implementation PLEntityDescriptionTests

- (void) testInit {
    PLEntityDescription *description;

    /* Create one */
    description = [PLEntityDescription descriptionForClass: [self class] tableName: @"test"];
    STAssertNotNil(description, @"Could not initialize PLEntityDescription");
    STAssertTrue([@"test" isEqual: [description tableName]], @"Entity table name incorrect (%@)", [description tableName]);

    /* Add some properties */
    [description addPropertyDescription: [PLEntityPropertyDescription descriptionWithKey: @"rowId" columnName: @"id"] isPrimaryKey: YES];
    [description addPropertyDescription: [PLEntityPropertyDescription descriptionWithKey: @"name" columnName: @"name"]];
}


- (void) testInstantiateEntityWithValues {
    NSMutableDictionary *values = [NSMutableDictionary dictionaryWithCapacity: 3];
    ExampleEntity *entity;

    /* Set some example values */
    [values setObject: [NSNumber numberWithInt: 42] forKey: @"id"];
    [values setObject: @"Johnny" forKey: @"first_name"];
    [values setObject: @"Appleseed" forKey: @"last_name"];

    /* Try creating the entity */
    entity = [[ExampleEntity entityDescription] instantiateEntityWithValues: values];
    STAssertNotNil(entity, @"Could not instantiate entity");

    STAssertEquals(42, [[entity rowId] intValue], @"Incorrect row id");
    STAssertTrue([@"Johnny" isEqual: [entity firstName]], @"Incorrect firstName");
    STAssertTrue([@"Appleseed" isEqual: [entity lastName]], @"Incorrect lastName");
}

@end