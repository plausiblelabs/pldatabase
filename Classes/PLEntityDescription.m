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
 *
 * @par Thread Safety
 * PLEntityDescription instances are immutable, and may be shared between threads
 * without synchronization.
 */
@implementation PLEntityDescription


/**
 * Create a new entity description.
 *
 * @note Composite primary keys are not currently supported.
 *
 * @param entityClass The class corresponding to the described entity.
 * @param tableName The database table corresponding to the described entity.
 * @param properties A list of PLEntityProperty instances.
 */
+ (PLEntityDescription *) descriptionForClass: (Class) entityClass tableName: (NSString *) tableName properties: (NSArray *) properties {
    return [[[PLEntityDescription alloc] initWithClass: entityClass tableName: tableName properties: properties] autorelease];
}

/**
 * Initialize the entity description.
 *
 * @param entityClass The class corresponding to the described entity.
 * @param tableName The database table corresponding to the described entity.
 * @param properties A list of PLEntityProperty instances.
 *
 * @par Designated Initializer
 * This method is the designated initializer for the PLEntityDescription class.
 */
- (id) initWithClass: (Class) entityClass tableName: (NSString *) tableName properties: (NSArray *) properties {
    NSMutableDictionary *columnProperties;
    NSMutableArray *primaryKeys;

    if ((self = [super init]) == nil)
        return nil;

    _entityClass = entityClass;
    _tableName = [tableName retain];

    /*
     * Populate our column -> property map, and a list of primary keys
     */
    _columnProperties = columnProperties = [[NSMutableDictionary alloc] initWithCapacity: [properties count]];
    _primaryKeys =  primaryKeys = [NSMutableArray arrayWithCapacity: 1];

    for (PLEntityProperty *desc in properties) {
        NSString *columnName = [desc columnName];

        /* Sanity check -- verify that multiple entries aren't registered for the same column */
        if ([columnProperties objectForKey: columnName] != nil) {
            @throw [NSException exceptionWithName: PLDatabaseException 
                                           reason: [NSString stringWithFormat: @"Multiple properties registered for column %@", columnName] 
                                         userInfo: nil];
        }

        /* Save the description in our map */
        [columnProperties setObject: desc forKey: [desc columnName]];
    
        /* Primary key? */
        if ([desc isPrimaryKey])
            [primaryKeys addObject: desc];
    }

    return self;
}

- (void) dealloc {
    [_tableName release];
    [_columnProperties release];

    [super dealloc];
}

@end


/**
 * @internal
 * Library-private methods.
 */
@implementation PLEntityDescription (PLEntityDescriptionLibraryPrivate)

/**
 * @internal
 *
 * Return the table's name.
 */
- (NSString *) tableName {
    return _tableName;
}


/**
 * @internal
 *
 * Retrieve all available column values from the given entity instance,
 * using the object's declared PLEntityPropertyDescription instances.
 *
 * Nil values are represented as NSNull, as per the Key-Value Coding
 * Programming Guidelines: http://developer.apple.com/documentation/Cocoa/Conceptual/KeyValueCoding/Concepts/BasicPrinciples.html
 */
- (NSDictionary *) columnValuesForEntity: (PLEntity *) entity {
    NSMutableDictionary *columnValues;

    /* Create our return dictionary */
    columnValues = [NSMutableDictionary dictionaryWithCapacity: [_columnProperties count]];

    for (NSString *columnName in _columnProperties) {
        PLEntityProperty *property;
        id value;
        
        /* Fetch the property description and the entity's value */
        property = [_columnProperties objectForKey: columnName];
        value = [entity valueForKey: [property key]];

        /* Handle nil (NSDictionary values can't be nil) */
        if (value == nil)
            value = [NSNull null];

        /* Add column, value */
        [columnValues setObject: value forKey: [property columnName]];
    }

    return columnValues;
}


/**
 * @internal
 *
 * Instantiate an instance of the described class, using database column values.
 *
 * @param values A dictionary mapping database column names to associated values.
 * @param outError A pointer to an NSError instance that will be set if an error occurs. May be nil.
 * @return Returns a new instance, or sets outError and returns nil on failure.
 */
- (id) instantiateEntityWithColumnValues: (NSDictionary *) values error: (NSError **) outError {
    PLEntity *entity;

    /* Create the new class instance */
    entity = [[[_entityClass alloc] init] autorelease];

    /* Should not fail. */
    if (entity == nil) {
        [NSException raise: PLDatabaseException format: @"Could not instantiate %@", _entityClass];
    }

    /* Iterate over defined columns */
    for (NSString *columnName in _columnProperties) {
        NSString *key;
        id value;

        /* Get the property key */
        key = [[_columnProperties valueForKey: columnName] key];

        /* Retrieve the column's value (may be nil, it's up to the validator to accept/reject a nil value) */
        value = [values objectForKey: columnName];
        
        /* Validate the value (might replace value!) */
        if (![entity validateValue: &value forKey: key error: outError]) {
            NSLog(@"Validation for key '%@', column '%@', value '%@' failed", key, columnName, value);
            if (outError) {
                *outError = [NSError errorWithDomain: PLEntityErrorDomain  code: PLEntityValidationError userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                                NSLocalizedString(@"Could not validate property value provided by the database.", @""), NSLocalizedDescriptionKey,
                                nil]];
            }
            return nil;
        }

        /* Set the value */
        [entity setValue: value forKey: key];
    }

    /* Wake the object up */
    if ([entity respondsToSelector: @selector(awakeFromDatabase)])
        [entity awakeFromDatabase];

    return entity;
}

- (BOOL) mergeColumnValuesForEntity: (PLEntity *) entity error: (NSError **) outError {
    return NO; // XXX TODO
}

/**
 * @internal
 *
 * Returns the primary keys defined in this entity description.
 *
 * @return An NSArray containing PLEntityProperty objects.
 */
- (NSArray *) primaryKeys {
    return _primaryKeys;
}

@end
