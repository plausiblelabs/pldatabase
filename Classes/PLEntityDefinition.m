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


@implementation PLEntityDefinition

/**
 * Create a new entity definition for the given table.
 *
 * @param tableName Name of table to which the new entity definition will correspond.
 * @param firstObj A nil-terminated list of PLEntityColumn instances.
 * @result An entity definition for the given table.
 */
+ (PLEntityDefinition *) defineEntityForTable: (NSString *) tableName withColumns: (PLEntityColumn *) firstObj, ... {
    PLEntityColumn *column;
    NSMutableSet *columns;
    va_list ap;

    /* If there are no columns, exit early */
    if (firstObj == nil)
        return [[[PLEntityDefinition alloc] initWithTableName: tableName columns: [NSMutableSet setWithCapacity: 0]] autorelease];

    /* Populate the set */
    columns = [NSMutableSet setWithObject: firstObj]; // arbitrary capacity

    va_start(ap, firstObj);
    while ((column = va_arg(ap, PLEntityColumn *)) != nil) {
        [columns addObject: column];
    }
    va_end(ap);

    /* Now return a nice new definition */
    return [[[PLEntityDefinition alloc] initWithTableName: tableName columns: columns] autorelease];
}

/**
 * Initialize a new entity definition for the given table.
 *
 * @param tableName Name of table to which this entity definition corresponds.
 * @param columns A set of #PLEntityColumn instances.
 */
- (id) initWithTableName: (NSString *) tableName columns: (NSSet *) columns {
    /* A mutable pointer to _columnCache */
    NSMutableDictionary *mutableColumnCache;
    
    if ((self = [super init]) == nil)
        return nil;

    /* Save the table name */
    _tableName = [tableName retain];

    /* Populate the column cache */
    mutableColumnCache = [[NSMutableDictionary alloc] initWithCapacity: [columns count]];
    _columnCache = mutableColumnCache;

    for (PLEntityColumn *column in columns) {
        [mutableColumnCache setObject: column forKey: [column columnName]]; 
    }

    return self;
}


- (void) dealloc {
    [_tableName release];
    [_columnCache release];

    [super dealloc];
}


/**
 * @internal
 * Return the table's name.
 */
- (NSString *) tableName {
    return _tableName;
}

@end
