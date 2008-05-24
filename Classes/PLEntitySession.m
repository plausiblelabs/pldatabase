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
 * The PLEntitySession represents a single database connection.
 *
 * @par Thread Safety
 * PLEntitySession instances implement no locking and must not be shared between threads
 * without external synchronization.
 */
@implementation PLEntitySession

/**
 * @internal
 *
 * Disallow direct initialization.
 */
- (id) init {
    [self doesNotRecognizeSelector: _cmd];
    return nil;
}

/**
 * @internal
 * Initialize with the given entity manager.
 *
 * @par Designated Initializer
 * This method is the designated initializer for the PLEntityProperty class.
 */
- (id) initWithEntityManager: (PLEntityManager *) entityManager error: (NSError **) error {
    if ((self = [super init]) == nil) {
        /* This should not fail, but we have to return an error. */
        if (error != nil)
            *error = [NSError errorWithDomain: PLDatabaseErrorDomain code: PLDatabaseErrorUnknown userInfo: nil];
        return nil;
    }

    /* Retain a reference to our entity manager */
    _entityManager = [entityManager retain];
    
    /* Retain our dialect */
    _sqlDialect = [[entityManager dialect] retain];
    
    /* Initialize transaction state */
    _inTransaction = NO;

    /* Fetch a database connection. This must be returned in dealloc. */
    _database = [[[_entityManager connectionDelegate] getConnectionAndReturnError: error] retain];
    if (_database == nil) {
        [self release];
        return nil;
    }

    /* Set up our statement builder */
    _sqlBuilder = [[PLSqlBuilder alloc] initWithDatabase: _database dialect: _sqlDialect];

    return self;
}


/* GC */
- (void) finalize {
    /* Return our database connection */
    [self close];
    [super finalize];
}


/* Manual */
- (void) dealloc {
    /* Return our database connection */
    [self close];

    /* Free any memory */
    [_entityManager release];
    [_sqlDialect release];
    [_sqlBuilder release];

    [super dealloc];
}


/**
 * Close the session, and return any held database resources. After calling,
 * no further methods may be called on the instance.
 *
 * As PLEntitySession objects may be placed into autorelease pools, with indeterminate
 * release of database resources, this method should be used to ensure timely
 * release of the database connection.
 *
 * Failure to call close will not result in any memory leaks, but will prevent
 * further use of the backing database connection until the session
 * is released. This issue will be exacerbated in a garbage collection
 * environment, where object finalization may not occur as regularly
 * as with autorelease pools.
 */
- (void) close {
    if (_database == nil)
        return;

    /* Return the connection */
    [[_entityManager connectionDelegate] closeConnection: _database];

    /* Release the database reference */
    [_database release];

    /* Mark ourselves finished */
    _database = nil;
}


/**
 * Begin a transaction. This must provide at least 'Read committed' isolation. As
 * per the SQL standard, the isolation level may be stricter than what has been
 * requested -- this method only gaurantees the MINIMUM of isolation.
 *
 * For more information on SQL standard transaction isolation levels, refer to
 * PostgreSQL's documentation:
 *    http://www.postgresql.org/docs/8.3/interactive/transaction-iso.html
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) begin {
    return [self beginAndReturnError: nil];
}


/**
 * Begin a transaction. This must provide at least 'Read committed' isolation. As
 * per the SQL standard, the isolation level may be stricter than what has been
 * requested -- this method only gaurantees the MINIMUM of isolation.
 *
 * For more information on SQL standard transaction isolation levels, refer to
 * PostgreSQL's documentation:
 *    http://www.postgresql.org/docs/8.3/interactive/transaction-iso.html
 *
 * @param error A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the transaction could not
 * be started.
 *
 * If no error occurs, this parameter will be left unmodified. You may specify nil for this
 * parameter, and no error information will be provided.
 * @return YES on success, NO on failure.
 */
- (BOOL) beginAndReturnError: (NSError **) error {
    BOOL ret;

    ret = [_database beginTransactionAndReturnError: error];
    if (ret)
        _inTransaction = YES;

    return ret;
}


/**
 * Commit an open transaction.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) commit {
    return [self commitAndReturnError: nil];
}


/**
 * Commit an open transaction.
 *
 * @param error A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the transaction could not
 * be committed.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) commitAndReturnError: (NSError **) error {
    BOOL ret;

    ret = [_database commitTransactionAndReturnError: error];
    if (ret)
        _inTransaction = NO;

    return ret;
}


/**
 * Rollback an open transaction.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) rollback {
    return [self rollbackAndReturnError: nil];
}


/**
 * Rollback an open transaction.
 *
 * @param error A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the transaction could not
 * be rolled back.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) rollbackAndReturnError: (NSError **) error {
    BOOL ret;

    ret = [_database rollbackTransactionAndReturnError: error];
    if (ret)
        _inTransaction = NO;

    return ret;
}


/**
 * Returns YES if the transaction is active. This method only reflects local
 * state -- if a transaction was rolled back through other means (such as by the database),
 * it will not be reflected here.
 */
- (BOOL) inTransaction {
    return _inTransaction;
}


/* Filter for all generated values */
static BOOL propertyfilter_filter_generated (PLEntityProperty *property, void *context) {
    if ([property isGeneratedValue])
        return YES;

    return NO;
}

/**
 * @internal
 *
 * Implements entity insert via a post-insert SELECT for identity.
 */
- (BOOL) insertEntitySelectLastIdentity: (PLEntity *) entity error: (NSError **) error {
    PLEntityProperty *generatedPrimaryKey;
    PLEntityDescription *desc;
    NSDictionary *values;
    NSMutableDictionary *updateValues;
    
    NSObject<PLPreparedStatement> *stmt = nil;
    NSObject<PLResultSet> *rs = nil;
    
    /* Fetch the entity description */
    desc = [_entityManager descriptionForEntity: [entity class]];
    generatedPrimaryKey = [desc generatedPrimaryKeyProperty];

    /*
     * Perform the insert
     */
    /* Fetch the insert data */
    values = [desc columnValuesForEntity: entity];

    /* Create our insert statement */
    stmt = [_sqlBuilder insertForTable: [desc tableName] withColumns: [values allKeys] error: error];
    if (stmt == nil)
        goto error;
    
    /* Bind parameters */
    [stmt bindParameterDictionary: values];
    
    /* Execute our statement */
    if (![stmt executeUpdateAndReturnError: error])
        goto error;

    /*
     * Fetch all generated values
     */
    
    /* Determine the generated column names */
    NSArray *generatedProperties;
    NSMutableArray *columnNames;

    generatedProperties = [desc propertiesWithFilter: propertyfilter_filter_generated];
    columnNames = [NSMutableArray arrayWithCapacity: [generatedProperties count]];
    for (PLEntityProperty *property in generatedProperties)
        [columnNames addObject: [property columnName]];

    /* Generate a SELECT statement for the generated primary key */
    if (generatedPrimaryKey != nil && [values objectForKey: [generatedPrimaryKey columnName]] == [NSNull null]) {
        /* Create the select statement */
        stmt = [_sqlBuilder selectLastInsertForTable: [desc tableName] 
                                         withColumns: columnNames
                                          primaryKey: [generatedPrimaryKey columnName]
                                               error: error];

        if (stmt == nil)
            goto error;
    }
    /* Otherwise, generate SELECT for the known primary key values */
    else {
        NSDictionary *primaryKeyValues = [desc columnValuesForEntity: entity withFilter: PLEntityPropertyFilterPrimaryKeys];

        /* Create the select statement */
        stmt = [_sqlBuilder selectForTable: [desc tableName]
                               withColumns: columnNames
                               primaryKeys: [primaryKeyValues allKeys]
                                     error: error];
        if (stmt == nil)
            goto error;
        [stmt bindParameterDictionary: primaryKeyValues];
    }
        
    /* Execute our statement */
    rs = [stmt executeQueryAndReturnError: error];
    if (rs == nil)
        goto error;

    /* Has our just inserted entity gone missing? */
    if (![rs next]) {
        if (error) {
            NSString *description = NSLocalizedString(@"The entity could not be located in the database after an INSERT.", @"");
            *error = [NSError errorWithDomain: PLEntityErrorDomain 
                                         code: PLEntityNotFoundError 
                                     userInfo: [NSDictionary dictionaryWithObjectsAndKeys: description, NSLocalizedDescriptionKey, nil]];
        }
        goto error;
    }

    /* Fetch our value dictionary */
    updateValues = [NSMutableDictionary dictionaryWithCapacity: [columnNames count]];
    for (NSString *columnName in columnNames) {
        [updateValues setObject: [rs objectForColumn: columnName] forKey: columnName];
    }
    
    /* Clean up */
    [rs close];

    /* Update our entity */
    if (![desc updateEntity: entity withColumnValues: updateValues error: error])
        goto error;

    /* All is well */
    return YES;


error:
    /* An error occured, clean up and return NO */

    if (rs != nil)
        [rs close];

    if (stmt != nil)
        [stmt close];

    return NO;
}


/**
 * Insert an entity into the database.
 *
 * Any generated values (including the primary key) will be loaded from the database
 * and the entity will be updated accordingly
 *
 * @param entity The entity to insert.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) insertEntity: (PLEntity *) entity {
    return [self insertEntity: entity error: nil];
}


/**
 * Insert an entity into the database.
 *
 * Any generated values (including the primary key) will be loaded from the database
 * and the entity will be updated accordingly
 *
 * @param entity The entity to insert.
 * @param error A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the entity could not
 * be inserted.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) insertEntity: (PLEntity *) entity error: (NSError **) error {
    if ([_sqlDialect supportsLastInsertIdentity])
        return [self insertEntitySelectLastIdentity: entity error: error];
    else
        [NSException raise: PLDatabaseException format: @"Do not know how to determine INSERT row identity for this database"];

    /* Add support for INSERT ... RETURNING here */

    /* Unreachable */
    abort();
}


/**
 * Delete an entity.
 *
 * If the entity was not loaded from the database, this operation will fail
 * and return NO.
 *
 * @param entity The entity to delete.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) deleteEntity: (PLEntity *) entity {
    return [self deleteEntity: entity error: nil];
}

/**
 * Delete an entity.
 *
 * If the entity was not loaded from the database, this operation will fail
 * and return NO.
 *
 * @param entity The entity to delete.
 * @param error A pointer to an NSError object variable. If an error occurs, this
 * pointer will contain an error object indicating why the entity could not
 * be deleted.
 *
 * @return YES on success, NO on failure.
 */
- (BOOL) deleteEntity: (PLEntity *) entity error: (NSError **) error {
    PLEntityDescription *desc;
    NSDictionary *columnValues;                            
    NSObject<PLPreparedStatement> *stmt;
    BOOL ret;
    
    /* Fetch the data */
    desc = [_entityManager descriptionForEntity: [entity class]];
    columnValues = [desc columnValuesForEntity: entity withFilter: PLEntityPropertyFilterPrimaryKeys];
    
    /* Create our delete statement */
    stmt = [_sqlBuilder deleteForTable: [desc tableName] primaryKeys: [columnValues allKeys] error: error];
    if (stmt == nil)
        return NO;
    
    /* Bind parameters */
    [stmt bindParameterDictionary: columnValues];
    
    /* Execute our statement */
    ret = [stmt executeUpdateAndReturnError: error];
    
    /* Clean up */
    [stmt close];
    
    return ret;
}

@end
