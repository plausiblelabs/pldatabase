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
 * Abstract base class for entities that may be loaded and persisted to and
 * from a database.
 *
 * @par Implementation Requirements
 * Implementing classes must:
 * - Provide an entity description via PLEntity::entityDescription
 * - Support initialization via the no-argument init method.
 * - Be KVC and KVO compatible.
 *
 * @par Determing Changes
 * In performing updates to the corresponding database rows, only
 * modified values are written to the database
 */
@implementation PLEntity

/**
 * Returns the entity database description.
 *
 * This abstract method must be overridden.
 */
+ (PLEntityDescription *) entityDescription {
    [NSException raise:NSGenericException format: @"Method %s is abstract", _cmd];

    // Unreachable
    abort();
}

/**
 * Designated initializer for the PLEntity superclass.
 */ 
- (id) init {
    if ((self = [super init]) == nil)
        return nil;

    return self;
}

/**
 * Prepares the receiver for service after it has been loaded from the database.
 *
 * You may implement this method to perform additional initialization after
 * an object has been loaded from the database, and declared entity
 * properties have been populated.
 */
- (void) awakeFromDatabase {
    // Do nothing
}

@end
