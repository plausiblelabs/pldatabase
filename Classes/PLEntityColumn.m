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
 * Represents a single database column.
 */
@implementation PLEntityColumn

/**
 * Initialize with the given column name, and column data accessor.
 *
 * @param columnName Name of the database column.
 * @param accessor Accessor to retrieve column value.
 */
- (id) initWithColumnName: (NSString *) columnName accessor: (SEL) accessor {
    return [self initWithColumnName: columnName accessor: accessor isPrimaryKey: NO];
}


/**
 * Initialize with the given column name, and column data accessor.
 *
 * If this column is part (or wholly comprises) the table's primary key,
 * primaryKey must be YES.
 *
 * @param columnName Name of the database column.
 * @param accessor Accessor to retrieve column value.
 * @param primaryKey YES if this column comprises the table's primary key.
 */
- (id) initWithColumnName: (NSString *) columnName accessor: (SEL) accessor isPrimaryKey: (BOOL) primaryKey {
    if ((self = [super init]) == nil)
        return nil;
    
    _columnName = [columnName retain];
    _accessor = accessor;
    _primaryKey = primaryKey;
    
    return self;
}


- (void) dealloc {
    [_columnName release];

    [super dealloc];
}

/**
 * Return the column's name.
 */
- (NSString *) columnName {
    return _columnName;
}

/**
 * @internal
 * Returns YES if the column is a primary key.
 */
- (BOOL) isPrimaryKey {
    return _primaryKey;
}

/**
 * @internal
 * Returns the column accessor.
 */
- (SEL) accessor {
    return _accessor; 
}

@end
