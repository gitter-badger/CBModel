//
//  CBModel.h
//  CBModel
//
//  Created by 陈超邦 on 16/6/1.
//  Copyright © 2016年 陈超邦. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDB.h"

/**
 *  多线程运行结果block
 */
typedef void(^CBAsyResultBlock)(void);

@interface CBModel : NSObject

/**
 *  主键值
 */
@property (nonatomic, assign, readwrite) int             primaryKey;

/**
 *  属性名称数组
 */
@property (nonatomic, strong, readonly ) NSMutableArray  *columeNames;

/**
 *  类型类型数组
 */
@property (nonatomic, strong, readonly ) NSMutableArray  *columeTypes;


/**
 *  更换存储目录为当前用户目录
 */
+ (void)updateUserPath;

/**
 *  清除该表
 *
 *  @return 成败判断
 */
+ (BOOL)clearTable;

/**
 *  保存单个对象
 *
 *  @return 成败判断
 */
- (BOOL)saveSingleObject;

/**
 *  保存多个对象
 *
 *  @param array 保存多个对象的数组
 *
 *  @return 成败判断
 */
+ (BOOL)saveObjectsWithArray:(NSArray *)array;

/**
 *  更新单个对象
 *
 *  @return 成败判断
 */

- (BOOL)updateSingleObject;

/**
 *  更新多个对象
 *
 *  @param array 保存多个对象的数组
 *
 *  @return 成败判断
 */
+ (BOOL)updateObjectsWithArray:(NSArray *)array;

/**
 *  删除单个对象
 *
 *  @return 成败判断
 */

- (BOOL)deleteSingleObject;

/**
 *  删除多个对象
 *
 *  @param array 保存多个对象的数组
 *
 *  @return 成败判断
 */
+ (BOOL)deleteObjectsWithArray:(NSArray *)array;

/**
 *  根据条件删除对象
 *
 *  @param criteria 条件
 *
 *  @return 成败判断
 */
+ (BOOL)deleteObjectsWithCriteria:(NSString *)criteria;

/**
 *  根据多个参数删除对象
 *
 *  @param format 条件，形式类似于 [userModel deleteObjectsWithFormat:@" WHERE %@ < %d",@"age",20]]
 *
 *  @return 成败判断
 */
+ (BOOL)deleteObjectsWithFormat:(NSString *)format, ...;

/**
 *  查找所有对象
 *
 *  @return 包含所有对象的数组
 */
+ (NSArray *)findAllObjects;

/**
 *  单个条件查找多个对象
 *
 *  @return 包含符合条件的对象的数组
 */
+ (NSArray *)findByCriteria:(NSString *)criteria;

/**
 *  通过多个条件查找多个对象
 *
 *  @param format 条件，形式类似于 [userModel findWithFormat:@" WHERE %@ < %d",@"age",20]]
 *
 *  @return 包含符合条件的对象的数组
 */
+ (NSArray *)findWithFormat:(NSString *)format, ...;

////////////////////////////////////////////////////////////////////////////////////

/**
 *  子线程保存单个对象
 *
 *  @param resultBock 结果block
 */
- (void)AsySaveSingleObjectsWithResultBlock:(CBAsyResultBlock)resultBock;

/**
 *  子线程更新单个对象
 *
 *  @param resultBock 结果block
 */
- (void)AsyUpdateSingleObjectsWithResultBlock:(CBAsyResultBlock)resultBock;

/**
 *  子线程删除单个对象
 *
 *  @param resultBock 结果block
 */
- (void)AsyDeleteSingleObjectsWithResultBlock:(CBAsyResultBlock)resultBock;


/**
 *  在子线程执行保存操作并执行回调
 *
 *  @param array 保存多个对象的数组
 *  @param resultBock 结果block
 *
 *  @return 成败判断
 */

+ (void)AsySaveObjectsWithArray:(NSArray *)array
                    resultBlock:(CBAsyResultBlock)resultBock;

/**
 *  在子线程执行更新操作并执行回调
 *
 *  @param array 保存多个对象的数组
 *  @param resultBock 结果block
 *
 *  @return 成败判断
 */
+ (void)AsyUpdateObjectsWithArray:(NSArray *)array
                      resultBlock:(CBAsyResultBlock)resultBock;

/**
 *  在子线程执行删除操作并执行回调
 *
 *  @param array 保存多个对象的数组
 *  @param resultBock 结果block
 *
 *  @return 成败判断
 */
+ (void)AsyDeleteObjectsWithArray:(NSArray *)array
                      resultBlock:(CBAsyResultBlock)resultBock;

////////////////////////////////////////////////////////////////////////////////////

/**
 *  字典转为模型
 *
 *  @param dictionary 字典
 */
- (void)configurePropertyWithDictionary:(NSDictionary *)dictionary;

/**
 *  模型转为字典
 *
 *  @return 字典
 */
- (NSDictionary *)makeDictionary;

/**
 *  数组中有多个字典
 *
 *  @param array 数组
 *
 *  @return 存储转化后的model对象的数组
 */
- (NSArray *)configurePropertyWithArray:(NSArray *)array;

@end
