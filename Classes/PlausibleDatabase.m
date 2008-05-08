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

/** PlausibleDatabase Error Domain */
NSString *PLDatabaseErrorDomain = @"com.plausiblelabs.pldatabase";

/**
 * @internal
 * Implementation-private utility methods.
 */
@implementation PlausibleDatabase

/**
 * @internal
 *
 * Create a new NSError in the PLDatabaseErrorDomain.
 *
 * @param code The error code.
 * @param localizedDescription A localized error description.
 * @return A NSError that may be returned to the API caller.
 */
+ (NSError *) databaseError: (PLDatabaseError) code localizedDescription: (NSString *) localizedDescription {
    NSDictionary *userInfo;

    /* Create the userInfo dictionary */
    userInfo = [NSDictionary dictionaryWithObjectsAndKeys: localizedDescription, NSLocalizedDescriptionKey, nil];

    /* Return the NSError */
    return [NSError errorWithDomain: PLDatabaseErrorDomain code: code userInfo: userInfo];
}

@end