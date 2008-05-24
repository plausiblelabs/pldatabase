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

@interface PLEntityDescription : NSObject {
@private
    /** Database table name */
    NSString *_tableName;

    /** Map of column name to PLEntityProperty */
    NSDictionary *_columnProperties;
    
    /** The described entity's class object */
    Class _entityClass;

    /** The described entity's generated primary key property, if any. May be nil */
    PLEntityProperty *_generatedPrimaryKeyProperty;
}

+ (PLEntityDescription *) descriptionForClass: (Class) entityClass tableName: (NSString *) tableName properties: (NSArray *) properties;

- (id) initWithClass: (Class) entityClass tableName: (NSString *) tableName properties: (NSArray *) properties;

@end

#ifdef PL_DB_PRIVATE

/**
 * @internal
 * Implement to filter returned column values from PLEntityDescription::columnValuesForEntity:withFilter:filterContext:
 *
 * Must return YES if the value should be included in the result, otherwise NO.
 *
 * @ingroup functions
 */
typedef BOOL (*PLEntityDescriptionPropertyFilter) (PLEntityProperty *property, void *context);

/*
 * Pre-packaged filters.
 */
extern BOOL PLEntityPropertyFilterAllowAllValues (PLEntityProperty *property, void *context);
extern BOOL PLEntityPropertyFilterPrimaryKeys (PLEntityProperty *property, void *context);
extern BOOL PLEntityPropertyFilterGeneratedPrimaryKeys (PLEntityProperty *property, void *context);

@interface PLEntityDescription (PLEntityDescriptionLibraryPrivate)

- (NSString *) tableName;

- (PLEntityProperty *) generatedPrimaryKeyProperty;

- (NSArray *) properties;
- (NSArray *) propertiesWithFilter: (PLEntityDescriptionPropertyFilter) filter;
- (NSArray *) propertiesWithFilter: (PLEntityDescriptionPropertyFilter) filter filterContext: (void *) filterContext;

- (NSDictionary *) columnValuesForEntity: (PLEntity *) entity;
- (NSDictionary *) columnValuesForEntity: (PLEntity *) entity withFilter: (PLEntityDescriptionPropertyFilter) filter;
- (NSDictionary *) columnValuesForEntity: (PLEntity *) entity withFilter: (PLEntityDescriptionPropertyFilter) filter filterContext: (void *) filterContext;

- (id) instantiateEntityWithColumnValues: (NSDictionary *) values error: (NSError **) outError;

- (BOOL) updateEntity: (PLEntity *) entity withColumnValues: (NSDictionary *) values error: (NSError **) outError;

@end
#endif