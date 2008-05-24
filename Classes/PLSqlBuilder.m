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
@interface PLSqlBuilder (PLSqlBuilderPrivate)

- (NSString *) identifiersWithQuoting: (NSArray *) identifiers;
- (NSString *) columnsWithEquality: (NSArray *) columnNames;

@end

/**
 * @internal
 *
 * SQL statement builder.
 */
@implementation PLSqlBuilder

/**
 * Initialize with the given database and dialect.
 *
 * @param database Database to use for generating prepared statements.
 * @param dialect Database dialect definition.
 *
 * @par Designated Initializer
 * This method is the designated initializer for the PLSqlBuilder class.
 *
 * @par Thread Safety
 * PLSqlBuilder instances must be immutable, and support concurrent access
 * from multiple threads.
 */
- (id) initWithDatabase: (NSObject<PLDatabase> *) database dialect: (PLEntityDialect *) dialect {
    if ((self = [super init]) == nil)
        return nil;

    _db = [database retain];
    _dialect = [dialect retain];
    
    return self;
}

- (void) dealloc {
    [_db release];
    [_dialect release];

    [super dealloc];
}


/**
 * @internal
 * Create an INSERT prepared statement, with named bindings for the given column names.
 *
 * @param tableName The name of the table for the INSERT.
 * @param columns A list of all the column names, which will be included in the INSERT as named parameters.
 * @param outError If an error occurs, nil will be returned and outError will be populated with the error reason.
 * @return A prepared statement that may be used for dictionary-based parameter binding. Nil if an error occurs.
 */
- (NSObject<PLPreparedStatement> *) insertForTable: (NSString *) tableName withColumns: (NSArray *) columnNames error: (NSError **) outError {
    NSString *query;
    NSObject<PLPreparedStatement> *stmt;

    /* Create the query string */
    query = [NSString stringWithFormat: @"INSERT INTO %@ (%@) VALUES (:%@)", 
             [_dialect quoteIdentifier: tableName],
             [columnNames componentsJoinedByString: @", "],
             [columnNames componentsJoinedByString: @", :"]];

    /* Prepare the statement */
    stmt = [_db prepareStatement: query error: outError];
    if (stmt == nil)
        return nil;

    /* All is well in prepared statement land */
    return stmt;
}

/**
 * @internal
 *
 * Create a SELECT statement for the given table, with named bindings for the given column names.
 * The statement will be written such that all columns will be checked for equality when executing the SELECT. This
 * is primarily useful for implementing a select on a specific entity.
 *
 * @param tableName The name of the table for the INSERT.
 * @param columnNames A list of column values which will be returned.
 * @param primaryKeys A list of all the column names which will be included in the SELECT as named WHERE parameters, tested for equality.
 * @param outError If an error occurs, nil will be returned and outError will be populated with the error reason.
 * @return A prepared statement that may be used for dictionary-based parameter binding. Nil if an error occurs.
 */
- (NSObject<PLPreparedStatement> *) selectForTable: (NSString *) tableName 
                                       withColumns: (NSArray *) columnNames
                                       primaryKeys: (NSArray *) primaryKeys
                                             error: (NSError **) outError
{    
    NSString *query;
    NSObject<PLPreparedStatement> *stmt;
    
    /* Create the query string */
    query = [NSString stringWithFormat: @"SELECT %@ FROM %@ WHERE %@",
             [self identifiersWithQuoting: columnNames],
             [_dialect quoteIdentifier: tableName],
             [self columnsWithEquality: primaryKeys]];

    /* Prepare the statement */
    stmt = [_db prepareStatement: query error: outError];
    if (stmt == nil)
        return nil;
    
    /* All is well in prepared statement land */
    return stmt;
}

/**
 * @internal
 *
 * Create a SELECT statement for the last INSERT on the given table. Relies on the result of PLEntityDialect::selectLastInsertIdentity.
 *
 * The backing dialect MUST return YES from PLEntityDialect::supportsLastInsertIdentity
 *
 * @param tableName The name of the table for the SELECT.
 * @param columnNames A list of column values which will be returned.
 * @param primaryKey The name of the primary key column that will be compared against the last insert ID as provided by the database.
 * @param outError If an error occurs, nil will be returned and outError will be populated with the error reason.
 */
- (NSObject<PLPreparedStatement> *) selectLastInsertForTable: (NSString *) tableName 
                                                 withColumns: (NSArray *) columnNames 
                                                  primaryKey: (NSString *) primaryKey
                                                       error: (NSError **) outError
{
    NSString *query;
    NSObject<PLPreparedStatement> *stmt;
    
    /* Create the query string */
    assert([_dialect supportsLastInsertIdentity]);
    query = [NSString stringWithFormat: @"SELECT %@ FROM %@ WHERE %@ = %@",
             [self identifiersWithQuoting: columnNames],
             [_dialect quoteIdentifier: tableName],
             [_dialect quoteIdentifier: primaryKey],
             [_dialect lastInsertIdentity]];

    /* Prepare the statement */
    stmt = [_db prepareStatement: query error: outError];
    if (stmt == nil)
        return nil;
    
    /* All is well in prepared statement land */
    return stmt;
}

/**
 * @internal
 * Create a DELETE prepared statement, with named bindings for the given column names.
 * The statement will be written such that all columns will be checked for equality when executing the DELETE.
 *
 * @param tableName The name of the table for the DELETE.
 * @param primaryKeys A list of all the primary key column names, which will be included in the DELETE as named parameters.
 * @param outError If an error occurs, nil will be returned and outError will be populated with the error reason.
 * @return A prepared statement that may be used for dictionary-based parameter binding. Nil if an error occurs.
 */
- (NSObject<PLPreparedStatement> *) deleteForTable: (NSString *) tableName primaryKeys: (NSArray *) columnNames error: (NSError **) outError {
    NSString *query;
    NSObject<PLPreparedStatement> *stmt;
    
    /* Create the query string */
    query = [NSString stringWithFormat: @"DELETE FROM %@ WHERE %@", 
             [_dialect quoteIdentifier: tableName],
             [self columnsWithEquality: columnNames]];
    
    /* Prepare the statement */
    stmt = [_db prepareStatement: query error: outError];
    if (stmt == nil)
        return nil;
    
    /* All is well in prepared statement land */
    return stmt;
}

@end

/**
 * @internal
 * Class-private methods.
 */
@implementation PLSqlBuilder (PLSqlBuilderPrivate)

/**
 * @internal
 * Private helper method to turn a list of identifiers into a comma-seperated list of quoted identifiers.
 */
- (NSString *) identifiersWithQuoting: (NSArray *) identifiers {
    NSMutableString *identifierString;
    
    /* Create the column list */
    identifierString = [NSMutableString stringWithCapacity: [identifiers count] * 10];
    for (NSString *identifier in identifiers) {
        if ([identifierString length] != 0)
            [identifierString appendString: @", "];
        
        [identifierString appendString: [_dialect quoteIdentifier: identifier]];
    }

    return identifierString;
}

/**
 * @internal
 * Private helper method to turn a list of column names into a named parameter list with SQL equality operators
 * e.g columnName = (:columnName)
 */
- (NSString *) columnsWithEquality: (NSArray *) columnNames {
    NSMutableString *builder = [NSMutableString stringWithCapacity: 15];
    
    for (NSString *columnName in columnNames) {
        if ([builder length] > 0)
            [builder appendString: @" AND "];
        
        [builder appendFormat: @"%@ = (:%@)", [_dialect quoteIdentifier: columnName], columnName];
    }
    
    return builder;
}

@end