/*
 * Copyright (c) 2011 Plausible Labs Cooperative, Inc.
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

#import "PLDatabaseThreadLocalConnectionProvider.h"
#import "PLDatabaseThreadLocalConnectionProviderEntry.h"

#import <pthread.h>

/* Used to maintain a CFDictionary mapping PLDatabaseThreadLocalConnectionProvider instances to corresponding
 * PLDatabaseThreadLocalConnectionProviderEntry instances. */
static pthread_key_t prov_dictionary_key;

/* Key callbacks. We specifically avoid retaining the PLDatabaseThreadLocalConnectionProvider */
static const CFDictionaryKeyCallBacks keyCallbacks = {
    .version = 0,
    .retain = NULL,
    .release = NULL,
    .copyDescription = NULL,
    .equal = NULL,
    .hash = NULL
};

/**
 * A thread-local SQL connection provider. Will return an arbitrary number of connections, but
 * maintains a maximum cache of one SQL connection per thread.
 *
 * @par Thread Safety
 * Thread-safe. May be used from any thread, subject to SQLite's documented thread-safety constraints.
 */
@implementation PLDatabaseThreadLocalConnectionProvider

/* Handles cleanup of the prov_dictionary_key */
static void tld_cleanup_providers (void *value) {
    CFMutableDictionaryRef dict = value;

    /* Fetch all connections */
    CFIndex count = CFDictionaryGetCount(dict);
    const void **keys = malloc(count * sizeof(void *));
    PLDatabaseThreadLocalConnectionProviderEntry **values = malloc(count * sizeof(void *));
    CFDictionaryGetKeysAndValues(dict, keys, (const void **) values);

    /* Close all connections. We do so directly on the backing provider. */
    for (CFIndex i = 0; i < count; i++) {
        [values[i].provider closeConnection: values[i].db];
        CFDictionaryRemoveValue(dict, keys[i]);
    }

    /* Clean up */
    CFRelease(dict);
    free(keys);
    free(values);
}

/* Set up our thread-local key */
+ (void) initialize {
    if (![[self class] isEqual: [PLDatabaseThreadLocalConnectionProvider class]])
        return;
    
    pthread_key_create(&prov_dictionary_key, tld_cleanup_providers);
}

/**
 * Initialize a new instance with the provided connection provider
 *
 * @param provider A connection provider that will be used to acquire new database connections.
 */
- (id) initWithConnectionProvider: (id<PLDatabaseConnectionProvider>) provider {
    if ((self = [super init]) == nil)
        return nil;
    
    _provider = [provider retain];

    return self;
}

- (void) dealloc {
    /* Clean up any thread-local connection entries */
    CFMutableDictionaryRef thrDict = pthread_getspecific(prov_dictionary_key);
    if (thrDict != NULL) {
        /* If an entry exists, close it */
        PLDatabaseThreadLocalConnectionProviderEntry *entry = (id) CFDictionaryGetValue(thrDict, self);
        if (entry != nil)
            [entry.provider closeConnection: entry.db];

        /* Remove our entry from the dictionary */
        CFDictionaryRemoveValue(thrDict, self);
    }

    [_provider release];
    
    [super dealloc];
}

// from PLDatabaseConnectionProvider protocol
- (id<PLDatabase>) getConnectionAndReturnError: (NSError **) outError {
    CFMutableDictionaryRef thrDict = pthread_getspecific(prov_dictionary_key);
    
    /* Register the thread-local dictionary if it does not yet exist */
    if (thrDict == NULL) {
        thrDict = CFDictionaryCreateMutable(NULL, 0, &keyCallbacks, &kCFTypeDictionaryValueCallBacks);
        pthread_setspecific(prov_dictionary_key, thrDict);
    }

    /* Try fetching a cached connection */
    PLDatabaseThreadLocalConnectionProviderEntry *entry = (id) CFDictionaryGetValue(thrDict, self);
    if (entry != nil) {
        id<PLDatabase> db = entry.db;

        /* Ensure that the connection survives */
        [[db retain] autorelease];

        /* Remove the entry from the dictionary -- we don't want to re-use its connection until it is checked
         * in. */
        CFDictionaryRemoveValue(thrDict, self);

        return db;
    }

    /* Otherwise no connection is available. Let the provider generate a new connection. */
    return [_provider getConnectionAndReturnError: outError];
}

// from PLDatabaseConnectionProvider protocol
- (void) closeConnection: (id<PLDatabase>) connection {
    /* If a connection is already cached, simply let the provider close the connection */
    CFMutableDictionaryRef thrDict = pthread_getspecific(prov_dictionary_key);
    if (CFDictionaryGetValue(thrDict, self) != NULL) {
        [_provider closeConnection: connection];
        return;
    }

    /* Otherwise, we should cache the connection now */
    PLDatabaseThreadLocalConnectionProviderEntry *entry;
    entry = [[[PLDatabaseThreadLocalConnectionProviderEntry alloc] initWithDatabase: connection 
                                                                           provider: _provider] autorelease];
    CFDictionarySetValue(thrDict, self, entry);
}

@end
