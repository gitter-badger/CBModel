//
//  CBModel.m
//  CBModel
//
//  Created by 陈超邦 on 16/6/1.
//  Copyright © 2016年 陈超邦. All rights reserved.
//

#import "CBModel.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation CBModel

static FMDatabaseQueue *dbQueue;

+ (void)initialize
{
    if (![NSStringFromClass(self.class) isEqualToString:@"CBModel"] && ![NSStringFromClass(self.class) isEqualToString:@"CBBaseModel"]) {
        [self createTable];
    }
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        [self resetPropertiesToEmptyString];
        
        NSDictionary *dic = [self.class getColumeAndType];
        _columeNames = [[NSMutableArray alloc] initWithArray:[dic objectForKey:@"name"]];
        _columeTypes = [[NSMutableArray alloc] initWithArray:[dic objectForKey:@"type"]];
    }
    return self;
}

- (void)resetPropertiesToEmptyString {
    unsigned int outCount;
    
    objc_property_t *properties = class_copyPropertyList(self.class, &outCount);
    
    for (int i = 0; i < outCount; i++)
    {
        objc_property_t property = properties[i];
        
        NSString *propertyName = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        
        [self setValue:@"" forKeyPath:propertyName];
    }
}

+ (FMDatabaseQueue *)shareDBQueue {
    static dispatch_once_t onceToken ;
    dispatch_once(&onceToken, ^{
        dbQueue = [[FMDatabaseQueue alloc] initWithPath:[CBModel dbPath]];
    });
    return dbQueue;
}

+ (void)updateUserPath {
    dbQueue = [[FMDatabaseQueue alloc] initWithPath:[CBModel dbPath]];
    [self createTable];
}

+ (NSString *)dbPath {
    NSString *directoryPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/"];
    
    directoryPath = [directoryPath stringByAppendingString:@"/CBModel/"];
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:directoryPath isDirectory:nil]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
    }
    
    NSString *dbpath = [directoryPath stringByAppendingPathComponent:@"CBModel.sqlite"];
    
    return dbpath;
}

+ (NSString *)getColumeAndTypeStringWithDictionary:(NSDictionary *)dictionary {
    
    NSMutableArray *columeNames = [dictionary objectForKey:@"name"];;
    NSMutableArray *columeTypes = [dictionary objectForKey:@"type"];;
    NSMutableString* parStr = [NSMutableString string];
    
    for (int i=0; i< columeTypes.count; i++) {
        [parStr appendFormat:@"%@ %@",[columeNames objectAtIndex:i],[columeTypes objectAtIndex:i]];
        if(i+1 != columeTypes.count)
        {
            [parStr appendString:@","];
        }
    }
    return parStr;
}

+ (NSDictionary *)getColumeAndType {
    NSMutableArray *columeNames = [NSMutableArray array];
    NSMutableArray *columeTypes = [NSMutableArray array];
    
    [columeNames addObject:@"primaryKey"];
    [columeTypes addObject:[NSString stringWithFormat:@"%@ %@",@"INTEGER",@"primary key"]];
    
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        
        NSString *propertyName = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        
        [columeNames addObject:propertyName];
        
        NSString *propertyType = [NSString stringWithCString:property_getAttributes(property) encoding:NSUTF8StringEncoding];
        
        NSString *type = nil;
        if ([propertyType hasPrefix:@"T@"]) {
            type = [propertyType substringWithRange:NSMakeRange(3, [propertyType rangeOfString:@","].location-4)];
            if ([type isEqualToString:@"NSData"] || [type isEqualToString:@"UIImage"]) {
                [columeTypes addObject:@"BLOB"];
            }else {
                [columeTypes addObject:@"TEXT"];
            }
        }
        else if ([propertyType hasPrefix:@"Ti"] || [propertyType hasPrefix:@"Tq"]) {
            [columeTypes addObject:@"BIGINT"];
        }
        else if ([propertyType hasPrefix:@"Tf"] || [propertyType hasPrefix:@"Td"]) {
            [columeTypes addObject:@"DECIMAL"];
        }
        else if([propertyType hasPrefix:@"Tl"] || [propertyType hasPrefix:@"Tc"] || [propertyType hasPrefix:@"Ts"]) {
            [columeTypes addObject:@"INTEGER"];
        }else {
            [columeTypes addObject:@"TEXT"];
        }
    }
    free(properties);
    
    return [NSDictionary dictionaryWithObjectsAndKeys:columeNames,@"name",columeTypes,@"type",nil];
}

#pragma 表格管理
+ (BOOL)isExistInTable {
    __block BOOL success = NO;
    [[self shareDBQueue] inDatabase:^(FMDatabase *db) {
        NSString *tableName = NSStringFromClass(self.class);
        success = [db tableExists:tableName];
    }];
    return success;
}

+ (BOOL)clearTable {
    __block BOOL success = NO;
    [[CBModel shareDBQueue] inDatabase:^(FMDatabase *db) {
        NSString *tableName = NSStringFromClass(self.class);
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@",tableName];
        success = [db executeUpdate:sql];
    }];
    return success;
}

+ (BOOL)createTable {
    __block BOOL success = YES;
    
    [[self shareDBQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        NSString *tableName = NSStringFromClass(self.class);
        NSString *columeAndType = [self getColumeAndTypeStringWithDictionary:[self getColumeAndType]];
        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@);",tableName,columeAndType];
        if (![db executeUpdate:sql]) {
            success = NO;
            *rollback = YES;
            return;
        }
        
        NSMutableArray *columns = [NSMutableArray array];
        FMResultSet *resultSet = [db getTableSchema:tableName];
        while ([resultSet next]) {
            NSString *column = [resultSet stringForColumn:@"name"];
            [columns addObject:column];
        }
        
        NSDictionary *dict = [self.class getColumeAndType];
        NSArray *properties = [dict objectForKey:@"name"];
        NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)",columns];
        NSArray *resultArray = [properties filteredArrayUsingPredicate:filterPredicate];
        for (NSString *column in resultArray) {
            NSUInteger index = [properties indexOfObject:column];
            NSString *proType = [[dict objectForKey:@"type"] objectAtIndex:index];
            NSString *fieldSql = [NSString stringWithFormat:@"%@ %@",column,proType];
            NSString *sql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ ",NSStringFromClass(self.class),fieldSql];
            if (![db executeUpdate:sql]) {
                success = NO;
                *rollback = YES;
                return ;
            }
        }
    }];
    return success;
}

#pragma 保存
- (BOOL)saveSingleObject {
    if (![[self class] isExistInTable]) {
        [[self class] createTable];
    }
    
    NSString *tableName = NSStringFromClass(self.class);
    NSMutableString *keyString = [NSMutableString string];
    NSMutableString *valueString = [NSMutableString string];
    NSMutableArray *insertValues = [NSMutableArray  array];
    
    for (int i = 0; i < _columeNames.count; i++) {
        NSString *proname = [_columeNames objectAtIndex:i];
        if ([proname isEqualToString:@"primaryKey"]) continue;
        
        [keyString appendFormat:@"%@,", proname];
        [valueString appendString:@"?,"];
        
        [insertValues addObject:![self valueForKey:proname]?@"":[self valueForKey:proname]];
    }
    
    [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
    [valueString deleteCharactersInRange:NSMakeRange(valueString.length - 1, 1)];
    
    __block BOOL success = NO;
    [[CBModel shareDBQueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", tableName, keyString, valueString];
        success = [db executeUpdate:sql withArgumentsInArray:insertValues];
        _primaryKey = success?[NSNumber numberWithLongLong:db.lastInsertRowId].intValue:0;
    }];
    return success;
}

+ (BOOL)saveObjectsWithArray:(NSArray *)array {
    if (![self isExistInTable]) {
        [self createTable];
    }
    
    __block BOOL success = YES;
    for (CBModel *CBModel in array) {
        if (![CBModel isKindOfClass:[CBModel class]]) {
            success = NO;
        }
    }
    [[self shareDBQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (CBModel *model in array) {
            NSString *tableName = NSStringFromClass(model.class);
            NSMutableString *keyString = [NSMutableString string];
            NSMutableString *valueString = [NSMutableString string];
            NSMutableArray *insertValues = [NSMutableArray  array];
            for (int i = 0; i < model.columeNames.count; i++) {
                NSString *proname = [model.columeNames objectAtIndex:i];
                if ([proname isEqualToString:@"primaryKey"]) continue;
                
                [keyString appendFormat:@"%@,", proname];
                [valueString appendString:@"?,"];
                
                [insertValues addObject:![model valueForKey:proname]?@"":[model valueForKey:proname]];
            }
            [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
            [valueString deleteCharactersInRange:NSMakeRange(valueString.length - 1, 1)];
            
            NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", tableName, keyString, valueString];
            BOOL flag = [db executeUpdate:sql withArgumentsInArray:insertValues];
            model.primaryKey = flag?[NSNumber numberWithLongLong:db.lastInsertRowId].intValue:0;
            if (!flag) {
                success = NO;
                *rollback = YES;
            }
        }
    }];
    return success;
}

#pragma 更新
- (BOOL)updateSingleObject {
    if (![[self class] isExistInTable]) {
        [[self class] createTable];
    }
    
    __block BOOL success = YES;
    [[CBModel shareDBQueue] inDatabase:^(FMDatabase *db) {
        NSString *tableName = NSStringFromClass(self.class);
        
        id primaryValue = [self valueForKey:@"primaryKey"];
        if (!primaryValue || primaryValue <= 0) return;
        
        NSMutableString *keyString = [NSMutableString string];
        NSMutableArray *updateValues = [NSMutableArray  array];
        
        for (int i = 0; i < self.columeNames.count; i++) {
            NSString *proname = [self.columeNames objectAtIndex:i];
            if ([proname isEqualToString:@"primaryKey"]) continue;
            
            [keyString appendFormat:@" %@=?,", proname];
            
            [updateValues addObject:![self valueForKey:proname]?@"":[self valueForKey:proname]];
        }
        [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
        
        NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@ = ?;", tableName, keyString, @"primaryKey"];
        
        [updateValues addObject:primaryValue];
        
        success = [db executeUpdate:sql withArgumentsInArray:updateValues];
    }];
    return success;
}

+ (BOOL)updateObjectsWithArray:(NSArray *)array {
    if (![[self class] isExistInTable]) {
        [[self class] createTable];
    }
    __block BOOL success = YES;
    for (CBModel *CBModel in array) {
        if (![CBModel isKindOfClass:[CBModel class]]) {
            success = NO;
        }
    }
    
    [[self shareDBQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (CBModel *model in array) {
            NSString *tableName = NSStringFromClass(model.class);
            
            id primaryValue = [model valueForKey:@"primaryKey"];
            if (!primaryValue || primaryValue <= 0) {
                success = NO;
                *rollback = YES;
                return;
            }
            
            NSMutableString *keyString = [NSMutableString string];
            NSMutableArray *updateValues = [NSMutableArray  array];
            
            for (int i = 0; i < model.columeNames.count; i++) {
                NSString *proname = [model.columeNames objectAtIndex:i];
                if ([proname isEqualToString:@"primaryKey"]) continue;
                
                [keyString appendFormat:@" %@=?,", proname];
                
                [updateValues addObject:![self valueForKey:proname]?@"":[self valueForKey:proname]];
            }
            
            [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
            
            NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@=?;", tableName, keyString, @"primaryKey"];
            
            [updateValues addObject:primaryValue];
            
            BOOL flag = [db executeUpdate:sql withArgumentsInArray:updateValues];
            if (!flag) {
                success = NO;
                *rollback = YES;
            }
        }
    }];
    return success;
}

#pragma 删除
- (BOOL)deleteSingleObject {
    __block BOOL success = NO;
    [[CBModel shareDBQueue] inDatabase:^(FMDatabase *db) {
        NSString *tableName = NSStringFromClass(self.class);
        
        id primaryValue = [self valueForKey:@"primaryKey"];
        
        if (!primaryValue || primaryValue <= 0) return;
        
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = ?",tableName,@"primaryKey"];
        
        success = [db executeUpdate:sql withArgumentsInArray:@[primaryValue]];
    }];
    return success;
}

+ (BOOL)deleteObjectsWithArray:(NSArray *)array {
    __block BOOL success = YES;
    for (CBModel *cbModel in array) {
        if (![cbModel isKindOfClass:[CBModel class]]) {
            success = NO;
        }
        [[self shareDBQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
            for (CBModel *cbModel in array) {
                NSString *tableName = NSStringFromClass(cbModel.class);
                
                id primaryValue = [cbModel valueForKey:@"primaryKey"];
                
                if (!primaryValue || primaryValue <= 0) return;
                
                NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = ?",tableName,@"primaryKey"];
                
                BOOL flag = [db executeUpdate:sql withArgumentsInArray:@[primaryValue]];
                
                if (!flag) {
                    success = NO;
                    *rollback = YES;
                }
            }
        }];
    }
    return success;
}

+ (BOOL)deleteObjectsWithCriteria:(NSString *)criteria {
    __block BOOL success = NO;
    
    [[self shareDBQueue] inDatabase:^(FMDatabase *db) {
        NSString *tableName = NSStringFromClass(self.class);
        
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ %@ ",tableName,criteria];
        
        success = [db executeUpdate:sql];
    }];
    return success;
}

+ (BOOL)deleteObjectsWithFormat:(NSString *)format, ...
{
    va_list ap;
    va_start(ap, format);
    NSString *criteria = [[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:ap];
    va_end(ap);
    
    return [self deleteObjectsWithCriteria:criteria];
}

#pragma 查找
+ (NSArray *)findAllObjects {
    NSMutableArray *allObjects = [NSMutableArray array];
    
    [[self shareDBQueue] inDatabase:^(FMDatabase *db) {
        NSString *tableName = NSStringFromClass(self.class);
        
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@",tableName];
        
        FMResultSet *resultSet = [db executeQuery:sql];
        
        while ([resultSet next]) {
            CBModel *model = [[self.class alloc] init];
            
            for (int i=0; i< model.columeNames.count; i++) {
                
                NSString *columeName = [model.columeNames objectAtIndex:i];
                NSString *columeType = [model.columeTypes objectAtIndex:i];
                
                if ([columeType isEqualToString:@"TEXT"]) {
                    [model setValue:[resultSet stringForColumn:columeName] forKey:columeName];
                } else {
                    [model setValue:[NSNumber numberWithLongLong:[resultSet longLongIntForColumn:columeName]] forKey:columeName];
                }
            }
            [allObjects addObject:model];
            FMDBRelease(model);
        }
    }];
    
    return allObjects;
}

+ (NSArray *)findByCriteria:(NSString *)criteria {
    NSMutableArray *fliterObjects = [NSMutableArray array];
    
    [[self shareDBQueue] inDatabase:^(FMDatabase *db) {
        NSString *tableName = NSStringFromClass(self.class);
        
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ %@",tableName,criteria];
        
        FMResultSet *resultSet = [db executeQuery:sql];
        
        while ([resultSet next]) {
            CBModel *model = [[self.class alloc] init];
            
            for (int i=0; i< model.columeNames.count; i++) {
                
                NSString *columeName = [model.columeNames objectAtIndex:i];
                NSString *columeType = [model.columeTypes objectAtIndex:i];
                
                if ([columeType isEqualToString:@"TEXT"]) {
                    [model setValue:[resultSet stringForColumn:columeName] forKey:columeName];
                } else {
                    [model setValue:[NSNumber numberWithLongLong:[resultSet longLongIntForColumn:columeName]] forKey:columeName];
                }
            }
            [fliterObjects addObject:model];
            FMDBRelease(model);
        }
    }];
    return fliterObjects;
}

+ (NSArray *)findWithFormat:(NSString *)format, ... {
    va_list ap;
    va_start(ap, format);
    NSString *criteria = [[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:ap];
    va_end(ap);
    
    return [self findByCriteria:criteria];
}

#pragma Block

- (void)AsySaveSingleObjectsWithResultBlock:(CBAsyResultBlock)resultBock {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self saveSingleObject];
        dispatch_async(dispatch_get_main_queue(), ^{
            resultBock();
        });
    });
}

- (void)AsyUpdateSingleObjectsWithResultBlock:(CBAsyResultBlock)resultBock {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self updateSingleObject];
        dispatch_async(dispatch_get_main_queue(), ^{
            resultBock();
        });
    });
}

- (void)AsyDeleteSingleObjectsWithResultBlock:(CBAsyResultBlock)resultBock {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self deleteSingleObject];
        dispatch_async(dispatch_get_main_queue(), ^{
            resultBock();
        });
    });
}

+ (void)AsySaveObjectsWithArray:(NSArray *)array resultBlock:(CBAsyResultBlock)resultBock {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [[self class] saveObjectsWithArray:array];
        dispatch_async(dispatch_get_main_queue(), ^{
            resultBock();
        });
    });
}

+ (void)AsyUpdateObjectsWithArray:(NSArray *)array  resultBlock:(CBAsyResultBlock)resultBock {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [[self class] updateObjectsWithArray:array];
        dispatch_async(dispatch_get_main_queue(), ^{
            resultBock();
        });
    });
}

+ (void)AsyDeleteObjectsWithArray:(NSArray *)array resultBlock:(CBAsyResultBlock)resultBock {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [[self class] deleteObjectsWithArray:array];
        dispatch_async(dispatch_get_main_queue(), ^{
            resultBock();
        });
    });
}

#pragma Jason <-> Model

- (NSArray *)properties {
    NSMutableArray *props = [NSMutableArray array];
    
    unsigned int outCount, i;
    
    objc_property_t *properties = class_copyPropertyList(self.class, &outCount);
    
    for (i = 0; i < outCount; i++) {
        const char *char_f = property_getName(properties[i]);
        
        NSString *propertyName = [NSString stringWithUTF8String:char_f];
        
        [props addObject:propertyName];
    }
    free(properties);
    
    return [props copy];
}

- (void)configurePropertyWithDictionary:(NSDictionary *)dictionary {
    for (NSString *key in dictionary) {
        id value = dictionary[key];
        
        if ([value isEqual:[NSNull null]]) value = @"";
        
        NSString *propertSetterName = [NSString stringWithFormat:@"set%@%@",key,@":"];
        
        SEL setterSEL = NSSelectorFromString(propertSetterName);
        
        if ([self respondsToSelector:setterSEL]) {
            ((void(*)(id, SEL,id))objc_msgSend)(self, setterSEL, value);
        }
    }
}

- (NSArray *)configurePropertyWithArray:(NSArray *)array {
    NSMutableArray *resultArray = [[NSMutableArray alloc] init];
    
    for (NSDictionary *singleDic in array) {
        NSObject *cbModel = [[[self class] alloc] init];
        
        for (NSString *key in singleDic) {
            id value = singleDic[key];
            
            if ([value isEqual:[NSNull null]]) value = @"";
            
            NSString *propertSetterName = [NSString stringWithFormat:@"set%@%@",key,@":"];
            
            SEL setterSEL = NSSelectorFromString(propertSetterName);
            
            if ([self respondsToSelector:setterSEL]) {
                ((void(*)(id, SEL,id))objc_msgSend)(cbModel, setterSEL, value);
            }
        }
        [resultArray addObject:cbModel];
    }
    return [resultArray copy];
}

- (NSDictionary *)makeDictionary {
    NSArray *propertiesArray = [self properties];
    
    NSDictionary *resultDictionary = [[NSDictionary alloc] init];
    
    for (NSString *propertiesName in propertiesArray) {
        SEL getterSEL = NSSelectorFromString(propertiesName);
        
        if ([self respondsToSelector:getterSEL]) {

            [resultDictionary setValue:((id(*)(id, SEL))objc_msgSend)(self, getterSEL) forKey:propertiesName];
        }
    }
    return resultDictionary;
}

@end
