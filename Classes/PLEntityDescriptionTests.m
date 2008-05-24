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

@interface PLEntityDescriptionTests : SenTestCase
@end


@interface PLEntityDescExampleEntity : PLEntity {
@private
    /** Row id */
    NSNumber *_rowId;

    /** First name */
    NSString *_firstName;

    /** Last name */
    NSString *_lastName;
    
    /** Were we woken from the database? */
    BOOL _awoken;
}
@end


@implementation PLEntityDescExampleEntity

+ (PLEntityDescription *) entityDescription {
    return [PLEntityDescription descriptionForClass: [self class] tableName: @"People" properties:
        [NSArray arrayWithObjects:
            [PLEntityProperty propertyWithKey: @"rowId" columnName: @"id" attributes: PLEntityPAPrimaryKey, PLEntityPAGeneratedValue, nil],
            [PLEntityProperty propertyWithKey: @"firstName" columnName: @"first_name"],
            [PLEntityProperty propertyWithKey: @"lastName" columnName: @"last_name"],
            nil
        ]
    ];
}

- (id) init {
    if ((self = [super init]) == nil)
        return nil;

    _awoken = NO;
    
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

- (BOOL) awoken {
    return _awoken;
}

- (void) awakeFromDatabase {
    _awoken = YES;
}

- (BOOL) validateFirstName: (NSString **) ioValue error: (NSError **) error {
    /* Never allow Barnie */
    if ([*ioValue isEqual: @"Barnie"]) {
        if (error != nil)
            *error = [NSError errorWithDomain: PLDatabaseErrorDomain code: PLDatabaseErrorUnknown userInfo: nil];
        return NO;
    }

    /* Sarah is OK, but it should be spelled Sara */
    if ([*ioValue isEqual: @"Sarah"]) {
        *ioValue = @"Sara";
        return YES;
    }

    /* All other names are OK */
    return YES;
}

@end


@implementation PLEntityDescriptionTests

- (void) testInit {
    PLEntityDescription *description;

    /* Create one */
    description = [PLEntityDescription descriptionForClass: [self class] tableName: @"test" properties:
        [NSArray arrayWithObjects:
            [PLEntityProperty propertyWithKey: @"rowId" columnName: @"id" attributes: PLEntityPAPrimaryKey, PLEntityPAGeneratedValue, nil],
            [PLEntityProperty propertyWithKey: @"name" columnName: @"name"],
            nil
        ]
    ];

    STAssertNotNil(description, @"Could not initialize PLEntityDescription");
    STAssertTrue([@"test" isEqual: [description tableName]], @"Entity table name incorrect (%@)", [description tableName]);
}


/* Verify that we throw an exception if a user attempts to define multiple generated primary keys */
- (void) testMultipleGeneratedKeys {    
    /* Create one */
    STAssertThrows(([PLEntityDescription descriptionForClass: [self class] tableName: @"test" properties:
                        [NSArray arrayWithObjects:
                            [PLEntityProperty propertyWithKey: @"rowId" columnName: @"id" attributes: PLEntityPAPrimaryKey, PLEntityPAGeneratedValue, nil],
                            [PLEntityProperty propertyWithKey: @"anotherId" columnName: @"anotherId" attributes: PLEntityPAPrimaryKey, PLEntityPAGeneratedValue, nil],
                            nil
                        ]
                    ]), @"Defining two primary keys as generated values did not throw the expected exception");
}


- (void) testGeneratedPrimaryKeyProperty {
    PLEntityDescription *desc;
    
    /* Create one */
    desc = [PLEntityDescription descriptionForClass: [self class] tableName: @"test" properties:
        [NSArray arrayWithObjects:
            [PLEntityProperty propertyWithKey: @"rowId" columnName: @"id" attributes: PLEntityPAPrimaryKey, PLEntityPAGeneratedValue, nil],
            [PLEntityProperty propertyWithKey: @"name" columnName: @"name"],
            nil
        ]
    ];

    STAssertNotNil([desc generatedPrimaryKeyProperty], @"Generated primary key property was nil");
    STAssertTrue([[[desc generatedPrimaryKeyProperty] columnName] isEqual: @"id"], @"Generated primary key column name was incorrect");
}


- (void) testProperties {
    PLEntityDescription *desc;

    /* Create one */
    desc = [PLEntityDescription descriptionForClass: [self class] tableName: @"test" properties:
        [NSArray arrayWithObjects:
            [PLEntityProperty propertyWithKey: @"rowId" columnName: @"id" attributes: PLEntityPAPrimaryKey, PLEntityPAGeneratedValue, nil],
            [PLEntityProperty propertyWithKey: @"name" columnName: @"name"],
            nil
        ]
    ];

    STAssertEquals([[desc properties] count], (NSUInteger) 2, @"Expected 2 returned properties");
    STAssertEquals([[desc propertiesWithFilter: PLEntityPropertyFilterPrimaryKeys] count], (NSUInteger) 1, @"Expected only 1 returned property");
}


/* Test the PLEntityPropertyFilterAllowAllValues filter */
- (void) testEntityAllColumnValues {
    PLEntityDescExampleEntity *entity;
    NSDictionary *columnValues;

    /* Create a new entity */
    entity = [[[PLEntityDescExampleEntity alloc] initWithFirstName: @"Johnny" lastName: @"Appleseed"] autorelease];

    /* Try to fetch the column values */
    columnValues = [[PLEntityDescExampleEntity entityDescription] columnValuesForEntity: entity];
    STAssertNotNil(columnValues, @"Could not fetch column values");

    STAssertEquals([NSNull null], [columnValues objectForKey: @"id"], @"Row id was not NSNull instance");
    STAssertTrue([@"Johnny" isEqual: [columnValues objectForKey: @"first_name"]], @"Returned first name was incorrect");
    STAssertTrue([@"Appleseed" isEqual: [columnValues objectForKey: @"last_name"]], @"Returned last name was incorrect");
}


/* Test the PLEntityPropertyFilterPrimaryKeys filter */
- (void) testEntityPrimaryKeyColumnValues {
    PLEntityDescExampleEntity *entity;
    NSDictionary *columnValues;
    
    /* Create a new entity */
    entity = [[[PLEntityDescExampleEntity alloc] initWithFirstName: @"Johnny" lastName: @"Appleseed"] autorelease];
    
    /* Try to fetch the column values */
    columnValues = [[PLEntityDescExampleEntity entityDescription] columnValuesForEntity: entity withFilter: PLEntityPropertyFilterPrimaryKeys];
    STAssertNotNil(columnValues, @"Could not fetch column values");

    STAssertEquals([columnValues count], (NSUInteger) 1, @"Extra values returned");
    STAssertEquals([NSNull null], [columnValues objectForKey: @"id"], @"Row id was not NSNull instance");
}

/* Test the PLEntityPropertyFilterGeneratedPrimaryKeys filter */
- (void) testEntityGeneratedPrimaryKeyColumnValues {
    PLEntityDescExampleEntity *entity;
    NSDictionary *columnValues;
    
    /* Create a new entity */
    entity = [[[PLEntityDescExampleEntity alloc] initWithFirstName: @"Johnny" lastName: @"Appleseed"] autorelease];
    
    /* Try to fetch the column values */
    columnValues = [[PLEntityDescExampleEntity entityDescription] columnValuesForEntity: entity withFilter: PLEntityPropertyFilterGeneratedPrimaryKeys];
    STAssertNotNil(columnValues, @"Could not fetch column values");
    
    STAssertEquals([columnValues count], (NSUInteger) 1, @"Extra values returned");
    STAssertEquals([NSNull null], [columnValues objectForKey: @"id"], @"Row id was not NSNull instance");
}


- (void) testInstantiateEntityWithColumnValues {
    NSMutableDictionary *values = [NSMutableDictionary dictionaryWithCapacity: 3];
    PLEntityDescExampleEntity *entity;
    NSError *error;

    /* Set some example values */
    [values setObject: [NSNumber numberWithInt: 42] forKey: @"id"];
    [values setObject: @"Johnny" forKey: @"first_name"];
    [values setObject: [NSNull null] forKey: @"last_name"];

    
    /*
     * Try creating the entity
     */
    entity = [[PLEntityDescExampleEntity entityDescription] instantiateEntityWithColumnValues: values error: nil];
    STAssertNotNil(entity, @"Could not instantiate entity");

    STAssertTrue([entity awoken], @"awakeFromDatabase was not called");
    STAssertEquals(42, [[entity rowId] intValue], @"Incorrect row id");
    STAssertTrue([@"Johnny" isEqual: [entity firstName]], @"Incorrect firstName");
    STAssertNil([entity lastName], @"lastName is not nil");
    
    
    /*
     * Try creating the entity with a name that will be changed (Sarah -> Sara) 
     */
    [values setObject: @"Sarah" forKey: @"first_name"];
    entity = [[PLEntityDescExampleEntity entityDescription] instantiateEntityWithColumnValues: values error: nil];
    STAssertNotNil(entity, @"Could not instantiate entity");
    STAssertTrue([@"Sara" isEqual: [entity firstName]], @"Incorrect firstName '%@'", [entity firstName]);

    
    /*
     * Try triggering a validation error
     */
    [values setObject: @"Barnie" forKey: @"first_name"];
    
    error = nil;
    entity = [[PLEntityDescExampleEntity entityDescription] instantiateEntityWithColumnValues: values error: &error];

    STAssertNil(entity, @"Entity was incorrect instantiated");
    STAssertNotNil(error, @"No NSError value was provided");
}

- (void) testMergeEntity {
    NSMutableDictionary *values = [NSMutableDictionary dictionaryWithCapacity: 3];
    PLEntityDescExampleEntity *entity;
    NSError *error;
    
    /* Set up our entity */
    entity = [[[PLEntityDescExampleEntity alloc] initWithFirstName: @"Johnny" lastName: @"Appleseed"] autorelease];
    
    /* Set some example values */
    [values setObject: [NSNumber numberWithInt: 42] forKey: @"id"];

    /* Try merging them in */
    STAssertTrue([[[entity class] entityDescription] updateEntity: entity withColumnValues: values error: &error], @"Could not merge values: %@", error);

    STAssertEquals([[entity rowId] intValue], 42, @"rowId not correctly merged");
    STAssertTrue([@"Johnny" isEqual: [entity firstName]], @"Incorrect firstName");
    STAssertTrue([@"Appleseed" isEqual: [entity lastName]], @"Incorrect lastName");
}

@end
