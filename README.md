# CCIAPManager

[![CI Status](https://img.shields.io/travis/曹臣/CCIAPManager.svg?style=flat)](https://travis-ci.org/曹臣/CCIAPManager)
[![Version](https://img.shields.io/cocoapods/v/CCIAPManager.svg?style=flat)](https://cocoapods.org/pods/CCIAPManager)
[![License](https://img.shields.io/cocoapods/l/CCIAPManager.svg?style=flat)](https://cocoapods.org/pods/CCIAPManager)
[![Platform](https://img.shields.io/cocoapods/p/CCIAPManager.svg?style=flat)](https://cocoapods.org/pods/CCIAPManager)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

CCIAPManager is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'CCIAPManager'
```

## Use
```
/*
 CCIAPVerifyType 验证类型
 CCIAPVerifyNever = 0, 不验证
 CCIAPVerifyAppLocal, app本地验证 manager内部处理
 CCIAPVerifyService 服务端验证
 */
typedef NS_ENUM(NSInteger, CCIAPVerifyType) {
    CCIAPVerifyNever = 0,
    CCIAPVerifyAppLocal,
    CCIAPVerifyService
};

/*
 交易状态
 CCIAPVerifyNetError:防止掉单 需要保存凭证 后续重试
 */
typedef NS_ENUM(NSInteger, CCIAPStatus) {
    CCIAPNotAllow = 0,
    CCIAPSuccess,
    CCIAPFailed,
    CCIAPCancel,
    
    CCIAPVerifySuccess,
    CCIAPVerifyNetError,
    CCIAPVerifyFailed,
    
    CCIAPVerifyErrorID,
    
    CCIAPRestored,//重复购买
};

///appstore支持的产品
typedef void(^CCIAPAppStoreSupportProductIDsBlock)(NSArray <NSString *> * ids);
///内购交易完成handle
typedef void(^CCIAPCompletionHandle)(NSString *productID ,CCIAPStatus status, NSData *data);
///服务端认证handle
typedef void(^CCIAPServiceVerifyHandle)(NSString *productID, NSString *receipt, CCIAPCompletionHandle handle);

@interface CCInAppPurchaseManager : NSObject

+ (instancetype)shareInstance;

///请求appstore支持的产品
- (void)requestProductsWithProductArray:(NSArray <NSString *> * _Nullable)ids completion:(nullable CCIAPAppStoreSupportProductIDsBlock)block;

/*
 内购购买
 manager内部处理机制特性，同一productID同时只能请求一次，如需多次请求，请等待CCIAPCompletionHandle回调之后。
 productID与
 - (void)localVerifyPurchase: withPaymentProductID: receipt: completeHandle:的productID也不能一样
 
 productID:产品ID
 verifyType:认证类型
 serviceVerifyHandle:服务端认证,如果verifyType==CCIAPVerifyService 此参数有效
 completeHandle:购买结果
 */
- (void)startPurchaseWithID:(NSString *)productID verifyType:(CCIAPVerifyType)verifyType
    serviceVerifyHandle:(nullable CCIAPServiceVerifyHandle)serviceVerifyHandle
completeHandle:(CCIAPCompletionHandle)completeHandle;

/*
 本地验证便捷方法
 需保证productID唯一，同- (void)startPurchaseWithID:(NSString *)productID verifyType:(CCIAPVerifyType)verifyType
 serviceVerifyHandle:(nullable CCIAPServiceVerifyHandle)serviceVerifyHandle
completeHandle:(CCIAPCompletionHandle)completeHandle
 */
- (void)localVerifyPurchase:(NSString *)checkURL withPaymentProductID:(NSString *)productID receipt:(NSData *)receipt completeHandle:( CCIAPCompletionHandle)completeHandle;

@end

@interface CCInAppPurchaseManager ()


/*
 没有得到正确认证结果时,保存凭证,用于后续手动认证
 未获得认证失败、认证成功等明确认证结果的都需要保存，例如网络问题、未等到认证结果app被杀死。。。
 
 localId:保存在本地的键值，建议每个用户使用不同id
 */
- (BOOL)saveUnVerifyRecepitWith:(NSString *)localId productId:(NSString *)productId verifyType:(CCIAPVerifyType)verifyType receipt:(NSData *)receipt;
/*
 获取本地保存的凭证
 回调内容 @{productId:@{
                        @"verifyType":verifyType,
                        @"receipt":receipt
                        }
            }
 */
- (void)getUnVerifyRecepitWith:(NSString *)localId completion:(void(^)(NSDictionary *product))completion;

@end
```

## Author

曹臣, chenlove523@163.com

## License

CCIAPManager is available under the MIT license. See the LICENSE file for more info.
