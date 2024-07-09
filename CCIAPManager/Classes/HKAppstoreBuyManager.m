//
//  HKAppstoreBuyManager.m
//  zww
//
//  Created by mac on 2023/2/9.
//

#import "HKAppstoreBuyManager.h"
#import <StoreKit/StoreKit.h>

#define kSandBoxURL @"https://sandbox.itunes.apple.com/verifyReceipt"
#define kItunsURL @"https://buy.itunes.apple.com/verifyReceipt"

@interface HKAppstoreBuyManager ()<SKPaymentTransactionObserver,SKProductsRequestDelegate>

@property (nonatomic, assign) CCIAPVerifyType verifyType;

@property(nonatomic,strong) NSMutableDictionary *productDict;

@property (nonatomic, copy) CCIAPAppStoreSupportProductIDsBlock idsBlock;

@property (nonatomic, copy) CCIAPServiceVerifyHandle serviceVerifyHandle;

@property (nonatomic, strong) NSMutableDictionary *completionHandleDic;

@property (nonatomic, strong) SKProductsRequest *producesRequest;

@end

@implementation HKAppstoreBuyManager

+ (instancetype)shareInstance{
    
    static HKAppstoreBuyManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[HKAppstoreBuyManager alloc] init];
    });
    
    return manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setUp];
    }
    return self;
}

- (BOOL)hk_saveReceiptWithLocalId:(NSString *)localId productId:(NSString *)productId verifyType:(CCIAPVerifyType)verifyType userInfo:(NSDictionary *)info receipt:(NSData *)receipt{
    
    if (localId.length == 0 || productId.length == 0 || receipt.length == 0) return NO;
    
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    NSDictionary *saveProducts = [userDefault objectForKey:localId];
    
    if (saveProducts){
        if ([saveProducts.allKeys containsObject:productId]){
            return NO;
        }
    }
    
    NSDictionary *data = @{@"verifyType":@(verifyType),@"receipt":receipt};
    NSDictionary *productInfo = @{productId:data};
    
    NSMutableDictionary *products = [NSMutableDictionary dictionaryWithDictionary:productInfo];
    if (saveProducts){
        [products addEntriesFromDictionary:saveProducts];
    }
    
    [userDefault setObject:products forKey:localId];
    [userDefault synchronize];
    
    return YES;
}

- (void)hk_getReceiptWithLocalId:(NSString *)localId completion:(void(^)(NSDictionary *product))completion{
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    NSDictionary *products = [userDefault objectForKey:localId];
    !completion?:completion(products);
}

- (void)hk_deleteReceiptWithLocalId:(NSString *)localId completion:(void(^)(void))completion{
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    [userDefault removeObjectForKey:localId];
    [userDefault synchronize];
    !completion?:completion();
}

#pragma mark - private -
- (void)setUp{
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

- (void)hk_buyProductsDatasInfo:(NSArray <NSString *> *)ids completion:(CCIAPAppStoreSupportProductIDsBlock)block{
    
    self.idsBlock = block;
    
    NSSet *set = [[NSSet alloc] initWithArray:ids];
    if (_producesRequest == nil){
        self.producesRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:set];
    }
    
    self.producesRequest.delegate = self;
    
    [self.producesRequest start];
}

- (void)hk_buyWithProductId:(NSString *)productID verifyType:(CCIAPVerifyType)verifyType ID:(NSInteger)ID
    verifyCallback:(nullable CCIAPServiceVerifyHandle)serviceVerifyHandle
completeHandle:(CCIAPCompletionHandle)completeHandle failure:(HKBuyFailureCallBack)failure{
    
    if (!productID || !completeHandle) return;
    
    self.verifyType = verifyType;
    self.serviceVerifyHandle = serviceVerifyHandle;
    
    self.completionHandleDic[productID] = completeHandle;
    
    if (![SKPaymentQueue canMakePayments]){
        [self handleStatus:CCIAPNotAllow product:productID data:nil];
        return;
    }
    
    if (![self.productDict.allKeys containsObject:productID]){
        [self handleStatus:CCIAPVerifyErrorID product:productID data:nil];
        return;
    }
    
    SKProduct *product = self.productDict[productID];
    SKPayment *payment = [SKPayment paymentWithProduct:product];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    
}

- (void)verifyPurchaseWithPaymentTransaction:(SKPaymentTransaction *)transaction{
    
    NSString *productID = transaction.payment.productIdentifier;
    NSURL *recepitURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:recepitURL];
    if (!receipt){
        [self handleStatus:CCIAPVerifyFailed product:productID data:nil];
        return;
    }
    
    if (self.verifyType == CCIAPVerifyNever){
        [self handleStatus:CCIAPSuccess product:productID data:receipt];
        return;
    }
    
    if (self.verifyType == CCIAPVerifyAppLocal){
#ifdef DEBUG
    NSString *checkURL = kSandBoxURL;
#else
    NSString *checkURL = kItunsURL;
#endif
        
        [self hk_appVerifyBuyInfo:checkURL withItemId:productID receipt:receipt];
    }else if (self.verifyType == CCIAPVerifyService){
        [self serviceVerifyPurchasewithItemId:productID receipt:receipt];
    }
    
}

- (void)hk_appVerifyBuyInfo:(NSString *)checkURL withItemId:(NSString *)productID receipt:(NSData *)receipt completeHandle:( CCIAPCompletionHandle)completeHandle{
    
    if (!productID || !receipt || !completeHandle) return;
    
    self.completionHandleDic[productID] = completeHandle;
    
    [self hk_appVerifyBuyInfo:checkURL withItemId:productID receipt:receipt];
}

- (void)hk_appVerifyBuyInfo:(NSString *)checkURL withItemId:(NSString *)productID receipt:(NSData *)receipt{
    
    NSURL *url = [NSURL URLWithString:checkURL];
    
    NSError *error;
    NSDictionary *requestContents = @{
                                      @"receipt-data": [receipt base64EncodedStringWithOptions:0]
                                      };
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents
                                                              options:0
                                                                error:&error];
    
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0f];
    request.HTTPMethod = @"POST";
    request.HTTPBody = requestData;
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (error){
            [self handleStatus:CCIAPVerifyNetError product:productID data:receipt];
            return;
        }
        
        NSError *jsonError;
        NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (!jsonResponse) {
            [self handleStatus:CCIAPVerifyFailed product:productID data:receipt];
            return;
        }
         
        NSString *status = [NSString stringWithFormat:@"%@",jsonResponse[@"status"]];
        if ([status isEqualToString:@"21007"]){
            [self hk_appVerifyBuyInfo:kItunsURL withItemId:productID receipt:receipt];
        }else if ([status isEqualToString:@"0"]){
            [self handleStatus:CCIAPVerifySuccess product:productID data:nil];
        }else{
            [self handleStatus:CCIAPVerifyFailed product:productID data:nil];
        }
    }];
    
    [task resume];
}

- (void)serviceVerifyPurchasewithItemId:(NSString *)productID receipt:(NSData *)receipt{
    
    if (self.serviceVerifyHandle == nil) return;
    
    NSString *receiptString = [receipt base64EncodedStringWithOptions:0];
    __weak typeof(self) weakSelf = self;
    self.serviceVerifyHandle(productID, receiptString, ^(NSString * _Nonnull productID, CCIAPStatus status, NSData * _Nonnull data) {
        [weakSelf handleStatus:status product:productID data:data];
    });
}

- (void)handleStatus:(CCIAPStatus)status product:(NSString *)product data:(NSData *)data{
    
    CCIAPStatus resultStatus = status;
    if (status == CCIAPVerifySuccess){
        resultStatus = CCIAPSuccess;
    }
    
    if ([self.completionHandleDic.allKeys containsObject:product]){
        CCIAPCompletionHandle handle = self.completionHandleDic[product];
        handle(product,status,data);
    }
}

#pragma mark delegate
- (void)requestDidFinish:(SKRequest *)request{
    NSLog(@"[test] requestDidFinish:%@",request);
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    NSLog(@"[test] error:%@",error);
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
   
    [self.productDict removeAllObjects];
    
    NSMutableArray *productArray = [NSMutableArray array];
    for (SKProduct *product in response.products) {
        [self.productDict setObject:product forKey:product.productIdentifier];
        [productArray addObject:product.productIdentifier];
    }
    
    !self.idsBlock?:self.idsBlock(productArray);
    
}

- (BOOL)paymentQueue:(SKPaymentQueue *)queue shouldAddStorePayment:(SKPayment *)payment forProduct:(SKProduct *)product{
    return YES;
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions{
    for(SKPaymentTransaction *tran in transactions){
            
        switch (tran.transactionState) {
            case SKPaymentTransactionStatePurchased:{
                [self verifyPurchaseWithPaymentTransaction:tran];
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
            }
                break;
            case SKPaymentTransactionStatePurchasing:
                break;
            case SKPaymentTransactionStateRestored:{
                
                CCIAPStatus status = CCIAPRestored;
                [self handleStatus:status product:tran.payment.productIdentifier data:nil];

                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
            }
                break;
            case SKPaymentTransactionStateFailed:
            {
                CCIAPStatus status;
                if(tran.error.code != SKErrorPaymentCancelled){
                    status = CCIAPFailed;
                   
                }else{
                    status = CCIAPCancel;
                
                }
                [self handleStatus:status product:tran.payment.productIdentifier data:nil];

                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                
            }
                break;
            default:
                break;
        }
    }
}

#pragma mark getter
- (NSMutableDictionary *)productDict{
    if (_productDict == nil){
        _productDict = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return _productDict;
}

- (NSMutableDictionary *)completionHandleDic{
    if (_completionHandleDic == nil){
        _completionHandleDic = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return _completionHandleDic;
}

@end
