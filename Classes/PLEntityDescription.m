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

#import "PlausibleDatabase.h"

/* Private methods */
@interface PLEntityDescription (PLEntityDescriptionPrivate)

- (NSDictionary *) columnValuesForEntity: (PLEntity *) entity withFilter: (PLEntityDescriptionPropertyFilter) filter filterContext: (void *) filterContext;

@end


/**
 * Defines the object entity mapping of a class and database table.
 *
 * @par Composite Primary Keys
 * Composite primary keys are supported, however, only ONE primary key
 * property may have the PLEntityPAGeneratedValue attribute.
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

    if ((self = [super init]) == nil)
        return nil;

    _entityClass = entityClass;
    _tableName = [tableName retain];

    /*
     * Populate our column -> property map, and a list of primary keys
     */
    _columnProperties = columnProperties = [[NSMutableDictionary alloc] initWithCapacity: [properties count]];

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
    
        /* Validate any primary keys, and save the generated primary key property, if any. */
        if ([desc isPrimaryKey]) {
            
            if ([desc isGeneratedValue] && _generatedPrimaryKeyProperty != nil) {
                [self release];
                [NSException raise: PLDatabaseException format: @"More than one generated primary key was defined. This is not supported."];
                
            } else if ([desc isGeneratedValue]) {
                _generatedPrimaryKeyProperty = [desc retain];
            }
        }
    }

    return self;
}

- (void) dealloc {
    [_tableName release];
    [_columnProperties release];
    [_generatedPrimaryKeyProperty release]; // may be nil

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
 * Return the entity's generated primary key, if any.
 * If no generated primary key has been defined, returns nil.
 */
- (PLEntityProperty *) generatedPrimaryKeyProperty {
    return _generatedPrimaryKeyProperty;
}

/**
 * @internal
 * A #PLEntityDescriptionPropertyFilter that accepts any and all properties.
 * No filter context is required.
 *
 * @see PLEntityDescription::columnValuesForEntity:withFilter:filterContext:
 *
 * @ingroup functions
 */
BOOL PLEntityPropertyFilterAllowAllValues (PLEntityProperty *property, void *context) {
    return YES;
}


/**
 * @internal
 * A #PLEntityDescriptionPropertyFilter that accepts only primary keys.
 * No filter context is required.
 *
 * @see PLEntityDescription::columnValuesForEntity:withFilter:filterContext:
 *
 * @ingroup functions
 */
BOOL PLEntityPropertyFilterPrimaryKeys (PLEntityProperty *property, void *context) {
    if ([property isPrimaryKey])
        return YES;
    else
        return NO;
}

/**
 * @internal
 * A #PLEntityDescriptionPropertyFilter that accepts only generated primary keys.
 * No filter context is required.
 *
 * @see PLEntityDescription::columnValuesForEntity:withFilter:filterContext:
 *
 * @ingroup functions
 */
BOOL PLEntityPropertyFilterGeneratedPrimaryKeys (PLEntityProperty *property, void *context) {
    if ([property isPrimaryKey] && [property isGeneratedValue])
        return YES;
    
    return NO;
}


/**
 * @internal
 *
 * Retrieve all defined column properties for this entity description
 */
- (NSArray *) properties {
    return [self propertiesWithFilter: PLEntityPropertyFilterAllowAllValues];
}


/**
 * @internal
 *
 * Retrieve all defined column properties that match the provided PLEntityDescriptionPropertyFilter.
 *
 * @param entity Entity from which to retrieve the values
 * @param filter Filter to run on entity properties.
 * @param filterContext Context variable to pass to filter.
 *
 * The filter context will be set to NULL.
 * @see PLEntityDescription::propertiesWithFilter:filterContext:
 */
- (NSArray *) propertiesWithFilter: (PLEntityDescriptionPropertyFilter) filter {
    return [self propertiesWithFilter: filter filterContext: NULL];
}


/**
 * @internal
 *
 * Retrieve all defined column properties that match the provided PLEntityDescriptionPropertyFilter.
 *
 * @param entity Entity from which to retrieve the values
 * @param filter Filter to run on entity properties.
 *
 * The filter context will be set to NULL.
 * @see PLEntityDescription::propertiesWithFilter:filterContext:
 */
- (NSArray *) propertiesWithFilter: (PLEntityDescriptionPropertyFilter) filter filterContext: (void *) filterContext {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity: [_columnProperties count]];
    
    for (PLEntityProperty *property in [_columnProperties allValues]) {
        /* Skip any that do not match the filter */
        if (!filter(property, filterContext))
            continue;

        [result addObject: property];
    }

    return result;
}


/**
 * @internal
 *
 * Retrieve all available column values from the given entity instance,
 * using the object's declared PLEntityProperty instances.
 *
 * Nil values are represented as NSNull, as per the Key-Value Coding
 * Programming Guidelines: http://developer.apple.com/documentation/Cocoa/Conceptual/KeyValueCoding/Concepts/BasicPrinciples.html
 *
 * @param entity Entity from which to retrieve the values
 */
- (NSDictionary *) columnValuesForEntity: (PLEntity *) entity {
    return [self columnValuesForEntity: entity withFilter: PLEntityPropertyFilterAllowAllValues];
}

/**
 * @internal
 *
 * Retrieve all filtered column values from the given entity instance,
 * using the object's declared PLEntityPropertyDescription instances.
 *
 * Nil values are represented as NSNull, as per the Key-Value Coding
 * Programming Guidelines: http://developer.apple.com/documentation/Cocoa/Conceptual/KeyValueCoding/Concepts/BasicPrinciples.html
 *
 * @param entity Entity from which to retrieve the values
 * @param filter Filter to run on entity properties.
 *
 * The filter context will be set to NULL.
 * @see PLEntityDescription::columnValuesForEntity:withFilter:filterContext:
 */
- (NSDictionary *) columnValuesForEntity: (PLEntity *) entity withFilter: (PLEntityDescriptionPropertyFilter) filter {
    return [self columnValuesForEntity: entity withFilter: filter filterContext: NULL];
}

/**
 * @internal
 *
 * Retrieve all filtered column values from the given entity instance,
 * using the object's declared PLEntityPropertyDescription instances.
 *
 * Nil values are represented as NSNull, as per the Key-Value Coding
 * Programming Guidelines: http://developer.apple.com/documentation/Cocoa/Conceptual/KeyValueCoding/Concepts/BasicPrinciples.html
 *
 * @param entity Entity from which to retrieve the values
 * @param filter Filter to run on entity properties.
 * @param filterContext Context variable to pass to filter.
 *
 * @par Supplied Filter Functions
 * A number of filter functions are included with this class implementation:
 * - #PLEntityPropertyFilterAllowAllValues - Returns all properties (does not filter).
 */
- (NSDictionary *) columnValuesForEntity: (PLEntity *) entity withFilter: (PLEntityDescriptionPropertyFilter) filter filterContext: (void *) filterContext {
    NSMutableDictionary *columnValues;
    
    /* Create our return dictionary */
    columnValues = [NSMutableDictionary dictionaryWithCapacity: [_columnProperties count]];
    
    for (NSString *columnName in _columnProperties) {
        PLEntityProperty *property;
        id value;
        
        /* Fetch the property description, skipping any that do not match the filter */
        property = [_columnProperties objectForKey: columnName];
        if (!filter(property, filterContext))
            continue;
        
        /* Fetch the value */
        value = [entity valueForKey: [property key]];
        
        /* Handle nil (NSDictionary values can't be nil) */
        if (value == nil)
            value = [NSNull null];
        
        /* Add column, value */
        [columnValues setObject: value forKey: [property columnName]];
    }
    
    return columnValues;
}

- (BOOL) setValue: (id) value forKey: (NSString *) key withEntity: (PLEntity *) entity error: (NSError **) outError {
    id validatedValue;

    /* Handle NSNull */
    if (value == [NSNull null])
        validatedValue = nil;
    else
        validatedValue = value;
    
    /*
     * Validate the value (might replace value!)
     */
    if (![entity validateValue: &validatedValue forKey: key error: outError])
        return NO;

    /*
     * Set the value
     */
    [entity setValue: validatedValue forKey: key];
    return YES;
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
        
        if (![self setValue: value forKey: key withEntity: entity error: outError])
            return nil;
    }

    /* Wake the object up */
    if ([entity respondsToSelector: @selector(awakeFromDatabase)])
        [entity awakeFromDatabase];

    return entity;
}

/**
 * @internal
 *
 * Update the entity with the provided column values.
 * @param entity The entity to modify.
 * @param values Dictionary mapping column names (not property keys) to values.
 * @param outError A pointer to an NSError instance that will be set if an error occurs. May be nil.
 */
- (BOOL) updateEntity: (PLEntity *) entity withColumnValues: (NSDictionary *) values error: (NSError **) outError {
    for (NSString *column in [values allKeys]) {
        NSString *key;

        /* Get the property key */
        key = [[_columnProperties objectForKey: column] key];
        if (key == nil) {
            [NSException raise: PLDatabaseException format: @"Attempted to merge value for column '%@' on entity '%@'", column, entity];
        }

        /* Set the value */
        if (![self setValue: [values objectForKey: column] forKey: key withEntity: entity error: outError])
            return NO;
    }

    return YES;
}

@end