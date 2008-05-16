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

#import "PlausibleDatabase.h"

/**
 * Defines the object entity mapping of a class and database table.
 */
@implementation PLEntityDescription


/**
 * Create a new entity description.
 *
 * @bug Composite primary keys may be defined, however, table composite
 * foreign keys are are not currently supported, and relationships
 * will not be handled correctly.
 *
 * @param entityClass The class corresponding to the described entity.
 * @param tableName The database table corresponding to the described entity.
 */
+ (PLEntityDescription *) descriptionForClass: (Class) entityClass tableName: (NSString *) tableName {
    return [[[PLEntityDescription alloc] initWithClass: entityClass tableName: tableName] autorelease];
}

/**
 * Initialize the entity description.
 *
 * @param entityClass The class corresponding to the described entity.
 * @param tableName The database table corresponding to the described entity.
 */
- (id) initWithClass: (Class) entityClass tableName: (NSString *) tableName {
    if ((self = [super init]) == nil)
        return nil;

    _entityClass = entityClass;
    _tableName = [tableName retain];
    _columnProperties = [[NSMutableDictionary alloc] initWithCapacity: 2];
    
    return self;
}

- (void) dealloc {
    [_tableName release];
    [_columnProperties release];

    [super dealloc];
}


/**
 * Add a new property description to the PLEntityDescription.
 *
 * @param description A property description.
 * @throw An exception will be thrown if two properties maintain conflicting column names.
 */
- (void) addPropertyDescription: (PLEntityPropertyDescription *) description {
    [self addPropertyDescription: description isPrimaryKey: NO];
}

/**
 * Add a new property description to the PLEntityDescription.
 *
 * @param description A property description.
 * @param isPrimaryKey YES if the property comprises the object's primary key.
 * @throw An exception will be thrown if two properties maintain conflicting column names.
 */
- (void) addPropertyDescription: (PLEntityPropertyDescription *) description isPrimaryKey: (BOOL) isPrimaryKey {
    NSString *columnName = [description columnName];

    /* Sanity check -- verify that multiple entries aren't registered for the same column */
    if ([_columnProperties objectForKey: columnName] != nil) {
        @throw [NSException exceptionWithName: PLDatabaseException 
                                       reason: [NSString stringWithFormat: @"Multiple properties registered for column %@", columnName] 
                                     userInfo: nil];
    }

    /* Save the description in our map */
    [_columnProperties setObject: description forKey: [description columnName]]; 
}


/**
 * Return the table's name.
 */
- (NSString *) tableName {
    return _tableName;
}

/**
 * XXX TODO
 */
- (id) instantiateEntityWithValues: (NSDictionary *) values {
    NSObject<PLEntity> *entity;

    /* Create the new class instance */
    entity = [[[_entityClass alloc] init] autorelease];

    /* Iterate over defined columns */
    for (NSString *columnName in _columnProperties) {
        id value;

        /* Retrieve the column's value. Skip missing values */
        value = [values objectForKey: columnName];
        if (value == nil)
            continue;

        /* Set the value */
        [entity setValue: value forKey: [[_columnProperties valueForKey: columnName] key]];
    }

    return entity;
}


@end
