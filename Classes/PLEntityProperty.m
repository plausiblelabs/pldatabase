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

/**
  * If present, the property is considered a primary key value.
  * @ingroup globals
  */
NSString *PLEntityPAPrimaryKey = @"PLEntityPAPrimaryKey";

/**
  * If present, the value will be considered generated.
  * @ingroup globals
  */
NSString *PLEntityPAGeneratedValue = @"PLEntityPAGeneratedValue";


/**
 * Represents a single database column.
 *
 * @par Thread Safety
 * PLEntityProperty instances are immutable, and may be shared between threads
 * without synchronization.
 */
@implementation PLEntityProperty

/**
 * @internal
 *
 * Internal implementation -- parses the varargs attributes, and then creates and return a description with the provided
 * Key Value Coding key and database column name. See the public API documentation for a list of supported attributes.
 *
 * @param key KVC key used to access the column value.
 * @param columnName The corresponding database column.
 * @param firstAttribute The first property attribute (or nil, if there are none).
 * @param attributesv A nil-terminated list of property attributes.
 *
 * This method is the true designated initializer.
 */
- (id) initWithKey: (NSString *) key columnName: (NSString *) columnName attribute: (NSString *) firstAttribute attributesv: (va_list) attributesv {
    
    /*
     * Standard initialization
     */
    if ((self = [super init]) == nil)
        return nil;
    
    _key = [key retain];
    _columnName = [columnName retain];
    
    /*
     * Option Parsing.
     */
    for (NSString *attribute = firstAttribute; attribute != nil; attribute = va_arg(attributesv, id)) {
        /* Is a primary key */
        if ([PLEntityPAPrimaryKey isEqual: attribute]) {
            _primaryKey = YES;
        }
        /* Is a generated value */
        else if ([PLEntityPAGeneratedValue isEqual: attribute]) {
            _generatedValue = YES;
        } else {
            [NSException raise: PLDatabaseException format: @"Undefined PLEntityProperty attribute: %@", attribute];
        }
    }
    
    /*
     * Option validation.
     */
    
    return self;
}


/**
 * Create and return a description with the provided Key Value Coding key and
 * database column name.
 *
 * @param key KVC key used to access the column value.
 * @param columnName The corresponding database column.
 */
+ (PLEntityProperty *) propertyWithKey: (NSString *) key columnName: (NSString *) columnName {
    return [PLEntityProperty propertyWithKey: key columnName: columnName attributes: nil];
}


/**
 * Create and return a description with the provided Key Value Coding key and
 * database column name.
 *
 * @param key KVC key used to access the column value.
 * @param columnName The corresponding database column.
 * @param firstAttribute A nil-terminated list of property attributes.
 *
 * @see PLEntityProperty::initWithKey:columnName:attributes: for the list of supported property attributes.
 * values.
 */
+ (PLEntityProperty *) propertyWithKey: (NSString *) key columnName: (NSString *) columnName attributes: (NSString *) firstAttribute, ... {
    PLEntityProperty *ret;
    va_list args;

    va_start(args, firstAttribute);
    ret = [[[PLEntityProperty alloc] initWithKey: key columnName: columnName attribute: firstAttribute attributesv: args] autorelease];
    va_end(args);

    return ret;
}


/**
 * Initialize with the Key Value Coding key and database column name.
 *
 * @param key KVC key used to access the column value.
 * @param columnName The corresponding database column.
 * @param firstAttribute A nil-terminated list of property attributes.
 * 
 * @par Property Attributes
 *
 * The property attributes are a nil-terminated list of attribute constants and associated
 * attribute values.
 *
 * The presence of a boolean attribute implies a value of YES, while its absence implies a value of NO.
 *
 * @par Boolean Attributes
 * The existence of boolean attributes imply a YES value. The available boolean attributes are:
 * - #PLEntityPAPrimaryKey\n
 * If present, this attribute indicates that this property composes all or part of the PLEntityDescription's primary key.
 * - #PLEntityPAGeneratedValue\n
 * If present, this attribute indicates that this property is a database-generated value.
 *
 * @par Designated Initializer
 * This method is the designated initializer for the PLEntityProperty class.
 *
 * @internal
 * This method calls the true designated initializer with our vararg attributes.
 */
- (id) initWithKey: (NSString *) key columnName: (NSString *) columnName attributes: (NSString *) firstAttribute, ... {
    va_list args;
    
    va_start(args, firstAttribute);
    [self initWithKey: key columnName: columnName attribute: firstAttribute attributesv: args];
    va_end(args);
    
    return self;
}

- (void) dealloc {
    [_key release];
    [_columnName release];

    [super dealloc];
}


@end

/**
 * @internal
 * Private library methods.
 */
@implementation PLEntityProperty (PLEntityPropertyDescriptionLibraryPrivate)

/**
 * Return the the property's key.
 */
- (NSString *) key {
    return _key;
}


/**
 * Return the database column name.
 */
- (NSString *) columnName {
    return _columnName;
}

/**
 * Return YES if the property is part of the table's primary key.
 */
- (BOOL) isPrimaryKey {
    return _primaryKey;
}

/**
 * Returns YES if the property is a database-generated value.
 */
- (BOOL) isGeneratedValue {
    return _generatedValue;
}

@end
