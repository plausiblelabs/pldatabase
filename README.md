# PLDatabase

PLDatabase provides an SQL database access library for Objective-C, focused on SQLite as an application database. The library supports both macOS and iOS development.

## Basic Usage

### Creating a Connection

Open a connection to a database file:

```objectivec
PLSqliteDatabase *db = [[PLSqliteDatabase alloc] initWithPath: @"/path/to/database"];
if (![db openAndReturnError: &error]) {
    NSLog(@"Could not open database");
}
```

### Update Statements

Update statements can be executed directly via `-[PLDatabase executeUpdateAndReturnError:statement:...]`:

```objectivec
if (![db executeUpdateAndReturnError: &error statement: @"CREATE TABLE example (id INTEGER)"]) {
    NSLog(@"Table creation failed");
}

if (![db executeQueryAndReturnError: &error statement: @"INSERT INTO example (id) VALUES (?)", [NSNumber numberWithInteger: 42]]) {
    NSLog(@"Data insert failed");
}
```

### Query Statements

Queries can be executed using `-[PLDatabase executeQueryAndReturnError:statement:...]`.  To iterate over the returned results, a instance conforming to the `PLResultSet` protocol will be returned:

```objectivec
id<PLResultSet> results = [db executeQueryAndReturnError: &error statement: @"SELECT id FROM example WHERE id = ?", [NSNumber numberWithInteger: 42]];
PLResultSetStatus rss;
while ((rss = [results nextAndReturnError: &error]) == PLResultSetStatusRow) {
    NSLog(@"Value of column id is %d", [results intForColumn: @"id"]);
}

if (rss != PLResultSetStatusDone) {
    NSLog(@"Iterating results failed");
}

// Failure to close the result set will not leak memory, but may
// retain database resources until the instance is deallocated.
[results close];
```

### Prepared Statements

Pre-compilation of SQL statements and advanced parameter binding are supported by `PLPreparedStatement`. A prepared statement can be constructed using `-[PLDatabase prepareStatement:error:]`.

```objectivec
id<PLPreparedStatement> stmt = [db prepareStatement: @"INSERT INTO example (name, color) VALUES (?, ?)" error: &error];

// Bind the parameters
[stmt bindParameters: @["Widget", @"Blue"]];

// Execute the INSERT
if ([stmt executeUpdateAndReturnError: &error] == NO) {
    NSLog(@"INSERT failed");
}
```

### Name-based Parameter Binding

Name-based parameter binding is also supported:

```objectivec
// Prepare the statement
id<PLPreparedStatement> stmt = [db prepareStatement: @"INSERT INTO test (name, color) VALUES (:name, :color)" error: &error];

// Bind the parameters using a dictionary
[stmt bindParameterDictionary: @{ @"name" : @"Widget", @"color" : @"Blue" }];

// Execute the INSERT
if ([stmt executeUpdateAndReturnError: &error] == NO) {
    NSLog(@"INSERT failed");
}
```

## Building

To build your own release binary, build the 'Disk Image' target:
```
$ xcodebuild -configuration Release -target 'Disk Image'
```

This will output a new release disk image containing an embeddable macOS framework and a static iOS framework in `build/Release/Plausible Database-{version}.dmg`.

## License

PLDatabase is provided free of charge under the BSD license, and may be freely integrated with any application. See the LICENSE file for the full license.
