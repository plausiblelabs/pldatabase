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
 * @param tableName The database table corresponding to the described entity.
 */
+ (PLEntityDescription *) entityDescriptionWithTableName: (NSString *) tableName {
    return [[[PLEntityDescription alloc] initWithTableName: tableName] autorelease];
}

/**
 * Initialize the entity description.
 *
 * @param tableName The database table corresponding to the described entity.
 */
- (id) initWithTableName: (NSString *) tableName {
    if ((self = [super init]) == nil)
        return nil;

    _tableName = [tableName retain];

    return self;
}


- (void) dealloc {
    [_tableName release];

    [super dealloc];
}


/**
 * Add a new property description to the PLEntityDescription.
 *
 * @param description A property description.
 * @throw An exception will be thrown if two properties maintain conflicting column names.
 */
- (void) addPropertyDescription: (PLEntityPropertyDescription *) description {
}


/**
 * Return the table's name.
 */
- (NSString *) tableName {
    return _tableName;
}

@end
