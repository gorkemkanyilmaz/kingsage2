// ios_native_auth_bridge.mm
// Native iOS Sign in with Apple (ASAuthorizationController + Face ID),
// In-App WKWebView OAuth bridge, and StoreKit IAP bridge for Taht ve Kilic (Godot 4.7 iOS export).

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <WebKit/WebKit.h>
#import <StoreKit/StoreKit.h>
#import <UserNotifications/UserNotifications.h>
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#if __has_include(<AuthenticationServices/AuthenticationServices.h>)
#import <AuthenticationServices/AuthenticationServices.h>
#define TVK_HAS_AUTH_SERVICES 1
#else
#define TVK_HAS_AUTH_SERVICES 0
#endif

static NSString *const kTVKReqFileName = @"native_auth_req.json";
static NSString *const kTVKResFileName = @"native_auth_res.json";
static NSString *const kTVKAckFileName = @"native_auth_ack.json";
static NSString *const kTVKIapReqFileName = @"native_iap_req.json";
static NSString *const kTVKIapProductsFileName = @"native_iap_products.json";
static NSString *const kTVKIapResFileName = @"native_iap_res.json";
static NSString *const kTVKNotifReqFileName = @"native_notif_req.json";
static NSString *const kTVKNotifStatusFileName = @"native_notif_status.json";
static NSString *const kTVKNotifOpenedFileName = @"native_notif_opened.json";
static NSString *const kTVKBgRefreshTaskId = @"com.tahtkilic.kingsage2.notif_refresh";
static NSString *const kTVKNotifServerUrlKey = @"tvk_notif_server_url";
static NSString *const kTVKNotifAuthTokenKey = @"tvk_notif_auth_token";
static NSString *const kTVKNotifEnabledKey = @"tvk_notif_enabled";
static NSString *const kTVKNotifDeviceTokenKey = @"tvk_notif_device_token";
static NSString *const kTVKAppleNamePrefix = @"tvk_apple_name_";
static NSString *const kTVKAppleEmailPrefix = @"tvk_apple_email_";
static NSString *const kTVKGoogleClientId = @"552757358961-j2p1bdt066tpropqmuj2dcp25rfu64o3.apps.googleusercontent.com";
static NSString *const kTVKGoogleCallbackScheme = @"com.googleusercontent.apps.552757358961-j2p1bdt066tpropqmuj2dcp25rfu64o3";
static NSString *const kTVKGoogleRedirectURI = @"com.googleusercontent.apps.552757358961-j2p1bdt066tpropqmuj2dcp25rfu64o3:/oauth2redirect/google";

static NSMutableArray<NSString *> *gTVKCachedExtraDirs = nil;
static NSArray<NSString *> *gTVKCachedBaseDirs = nil;
static BOOL gTVKDidDeepScanOnce = NO;

static NSArray<NSString *> *TVKCandidateUserDirs(BOOL deepScan, NSArray<NSString *> *reqFileNames) {
    if (!deepScan && gTVKCachedBaseDirs != nil) {
        return gTVKCachedBaseDirs;
    }
    NSMutableArray<NSString *> *dirs = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    void (^addDir)(NSString *) = ^(NSString *path) {
        if (path.length > 0 && ![seen containsObject:path]) {
            [seen addObject:path];
            [dirs addObject:path];
        }
    };

    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    addDir(docs);
    if (docs.length > 0) {
        addDir([docs stringByAppendingPathComponent:@"Taht ve K\u0131l\u0131\u00e7"]);
        addDir([docs stringByAppendingPathComponent:@"Taht ve Kilic"]);
        addDir([docs stringByAppendingPathComponent:@"TahtVeKilic"]);
    }

    NSString *appSup = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    addDir(appSup);
    if (appSup.length > 0) {
        addDir([appSup stringByAppendingPathComponent:@"Godot/app_userdata/Taht ve K\u0131l\u0131\u00e7"]);
        addDir([appSup stringByAppendingPathComponent:@"Godot/app_userdata/Taht ve Kilic"]);
        addDir([appSup stringByAppendingPathComponent:@"Godot/app_userdata/TahtVeKilic"]);
    }

    NSString *tmpDir = NSTemporaryDirectory();
    addDir(tmpDir);

    if (gTVKCachedExtraDirs != nil) {
        for (NSString *extra in gTVKCachedExtraDirs) {
            addDir(extra);
        }
    }

    if (deepScan && !gTVKDidDeepScanOnce && reqFileNames.count > 0) {
        gTVKDidDeepScanOnce = YES;
        gTVKCachedExtraDirs = [NSMutableArray array];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSSet<NSString *> *targets = [NSSet setWithArray:reqFileNames];
        for (NSString *baseRoot in @[docs ?: @"", appSup ?: @""]) {
            if (baseRoot.length == 0) {
                continue;
            }
            NSDirectoryEnumerator *en = [fm enumeratorAtPath:baseRoot];
            NSString *rel = nil;
            while ((rel = [en nextObject]) != nil) {
                if ([targets containsObject:[rel lastPathComponent]]) {
                    NSString *foundDir = [baseRoot stringByAppendingPathComponent:[rel stringByDeletingLastPathComponent]];
                    [gTVKCachedExtraDirs addObject:foundDir];
                    addDir(foundDir);
                }
            }
        }
    }

    gTVKCachedBaseDirs = [dirs copy];
    return gTVKCachedBaseDirs;
}

static void TVKWriteJsonDictToDirs(NSDictionary *payload, NSString *activeDir, NSString *fileName) {
    if (payload == nil || fileName.length == 0) {
        return;
    }
    NSError *err = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&err];
    if (json == nil || err != nil) {
        return;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableSet<NSString *> *targets = [NSMutableSet set];
    if (activeDir.length > 0) {
        [targets addObject:activeDir];
    }
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    if (docs.length > 0) {
        [targets addObject:docs];
    }
    for (NSString *candDir in TVKCandidateUserDirs(NO, nil)) {
        BOOL isDir = NO;
        if (candDir.length > 0 && [fm fileExistsAtPath:candDir isDirectory:&isDir] && isDir) {
            [targets addObject:candDir];
        }
    }
    for (NSString *dir in targets) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        [json writeToFile:[dir stringByAppendingPathComponent:fileName] atomically:YES];
    }
}

static NSString *TVKBase64AppStoreReceipt(void) {
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    if (receiptURL == nil) {
        return @"";
    }
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    if (receiptData.length == 0) {
        return @"";
    }
    return [receiptData base64EncodedStringWithOptions:0] ?: @"";
}

@interface TVKStoreKitBridge : NSObject <SKProductsRequestDelegate, SKPaymentTransactionObserver>
@property (nonatomic, strong) NSTimer *pollTimer;
@property (nonatomic, assign) NSUInteger scanTickCount;
@property (nonatomic, assign) BOOL observingTransactions;
@property (nonatomic, assign) BOOL isPurchaseBusy;
@property (nonatomic, assign) BOOL isRestoring;
@property (nonatomic, copy) NSString *activeIapDir;
@property (nonatomic, copy) NSString *activeFetchDir;
@property (nonatomic, copy) NSString *activeFetchReqId;
@property (nonatomic, copy) NSString *activePurchaseReqId;
@property (nonatomic, copy) NSString *activePurchaseProductId;
@property (nonatomic, strong) NSMutableDictionary<NSString *, SKProduct *> *cachedProducts;
@property (nonatomic, strong) SKProductsRequest *productFetchRequest;
@property (nonatomic, strong) SKProductsRequest *purchaseProductRequest;
@property (nonatomic, strong) NSMutableArray<NSString *> *restoredProductIds;
+ (instancetype)shared;
- (void)cleanupStaleFiles;
- (void)start;
- (void)stop;
@end

@interface TVKNativeAuthBridge : NSObject <
    WKNavigationDelegate,
    UIAdaptivePresentationControllerDelegate
#if TVK_HAS_AUTH_SERVICES
    , ASAuthorizationControllerDelegate
    , ASAuthorizationControllerPresentationContextProviding
    , ASWebAuthenticationPresentationContextProviding
#endif
>
@property (nonatomic, strong) NSTimer *pollTimer;
@property (nonatomic, copy) NSString *activeReqId;
@property (nonatomic, copy) NSString *activeProvider;
@property (nonatomic, copy) NSString *activeOAuthUrl;
@property (nonatomic, copy) NSString *activeDir;
@property (nonatomic, assign) BOOL isBusy;
@property (nonatomic, assign) NSTimeInterval busyStartedAt;
@property (nonatomic, assign) NSUInteger scanTickCount;
@property (nonatomic, strong) UIViewController *presentedNav;
@property (nonatomic, strong) UIActivityIndicatorView *loadingSpinner;
@property (nonatomic, strong) id googleAuthSession;
@property (nonatomic, copy) NSString *googleCodeVerifier;
@property (nonatomic, copy) NSString *googleOAuthState;
#if TVK_HAS_AUTH_SERVICES
@property (nonatomic, strong) id appleController;
#endif
+ (instancetype)shared;
- (void)cleanupStaleFiles;
- (void)startWatcher;
- (void)stopWatcher;
@end

static TVKNativeAuthBridge *gBridge = nil;
static TVKStoreKitBridge *gStoreKitBridge = nil;
static const NSInteger kTVKKeyboardToolbarTag = 90214;

static NSString *TVKBase64URLEncode(NSData *data) {
    if (data.length == 0) {
        return @"";
    }
    NSMutableString *b64 = [[data base64EncodedStringWithOptions:0] mutableCopy];
    [b64 replaceOccurrencesOfString:@"+" withString:@"-" options:0 range:NSMakeRange(0, b64.length)];
    [b64 replaceOccurrencesOfString:@"/" withString:@"_" options:0 range:NSMakeRange(0, b64.length)];
    [b64 replaceOccurrencesOfString:@"=" withString:@"" options:0 range:NSMakeRange(0, b64.length)];
    return [b64 copy];
}

static NSString *TVKRandomBase64URL(NSUInteger byteCount) {
    NSMutableData *data = [NSMutableData dataWithLength:byteCount];
    if (SecRandomCopyBytes(kSecRandomDefault, byteCount, data.mutableBytes) != errSecSuccess) {
        arc4random_buf(data.mutableBytes, byteCount);
    }
    return TVKBase64URLEncode(data);
}

static NSString *TVKSHA256Base64URL(NSString *input) {
    NSData *utf8 = [input dataUsingEncoding:NSUTF8StringEncoding];
    if (utf8.length == 0) {
        return @"";
    }
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(utf8.bytes, (CC_LONG)utf8.length, digest);
    return TVKBase64URLEncode([NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH]);
}

static NSString *TVKFormURLEncode(NSString *s) {
    if (s.length == 0) {
        return @"";
    }
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    return [s stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

static NSDictionary *TVKDecodeJWTPayload(NSString *jwt) {
    if (jwt.length == 0) {
        return nil;
    }
    NSArray<NSString *> *parts = [jwt componentsSeparatedByString:@"."];
    if (parts.count < 2) {
        return nil;
    }
    NSMutableString *b64 = [parts[1] mutableCopy];
    [b64 replaceOccurrencesOfString:@"-" withString:@"+" options:0 range:NSMakeRange(0, b64.length)];
    [b64 replaceOccurrencesOfString:@"_" withString:@"/" options:0 range:NSMakeRange(0, b64.length)];
    while (b64.length % 4 != 0) {
        [b64 appendString:@"="];
    }
    NSData *decoded = [[NSData alloc] initWithBase64EncodedString:b64 options:0];
    if (decoded.length == 0) {
        return nil;
    }
    id obj = [NSJSONSerialization JSONObjectWithData:decoded options:0 error:nil];
    return [obj isKindOfClass:[NSDictionary class]] ? (NSDictionary *)obj : nil;
}

static NSString *TVKExtractEmailFromJWT(NSString *jwt) {
    NSDictionary *claims = TVKDecodeJWTPayload(jwt);
    if (claims == nil) {
        return @"";
    }
    id em = claims[@"email"];
    return [em isKindOfClass:[NSString class]] ? [(NSString *)em stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
}

@interface TVKKeyboardToolbarHandler : NSObject
@property (nonatomic, weak) UIView *activeInputView;
+ (instancetype)shared;
- (void)install;
- (void)dismissKeyboard:(id)sender;
@end

@implementation TVKKeyboardToolbarHandler

+ (instancetype)shared {
    static TVKKeyboardToolbarHandler *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[TVKKeyboardToolbarHandler alloc] init];
    });
    return inst;
}

- (void)install {
    static dispatch_once_t regToken;
    dispatch_once(&regToken, ^{
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onTextBeginEditing:)
                                                     name:UITextFieldTextDidBeginEditingNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onTextBeginEditing:)
                                                     name:UITextViewTextDidBeginEditingNotification
                                                   object:nil];
    });
}

- (UIToolbar *)buildDoneToolbar {
    CGRect scr = [UIScreen mainScreen].bounds;
    UIToolbar *tb = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, MAX(320.0, scr.size.width), 44.0)];
    tb.tag = kTVKKeyboardToolbarTag;
    tb.barStyle = UIBarStyleBlack;
    tb.translucent = NO;
    tb.barTintColor = [UIColor colorWithRed:0.09 green:0.08 blue:0.13 alpha:1.0];
    tb.tintColor = [UIColor colorWithRed:0.96 green:0.82 blue:0.40 alpha:1.0];

    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                          target:nil
                                                                          action:nil];
    UIBarButtonItem *doneBtn = [[UIBarButtonItem alloc] initWithTitle:@"Tamam"
                                                                style:UIBarButtonItemStyleDone
                                                               target:self
                                                               action:@selector(dismissKeyboard:)];
    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:17.0],
        NSForegroundColorAttributeName: [UIColor colorWithRed:0.98 green:0.86 blue:0.44 alpha:1.0]
    };
    [doneBtn setTitleTextAttributes:attrs forState:UIControlStateNormal];
    [doneBtn setTitleTextAttributes:attrs forState:UIControlStateHighlighted];
    tb.items = @[flex, doneBtn];
    return tb;
}

- (void)onTextBeginEditing:(NSNotification *)note {
    id obj = note.object;
    if (![obj isKindOfClass:[UIView class]]) {
        return;
    }
    NSString *cls = NSStringFromClass([obj class]) ?: @"";
    if ([cls hasPrefix:@"WK"] || [cls hasPrefix:@"_WK"]) {
        return;
    }
    __weak UIView *weakView = (UIView *)obj;
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIView *v = weakView;
            if (v == nil || v.window == nil || ![v isFirstResponder]) {
                return;
            }
            self.activeInputView = v;
            if ([v isKindOfClass:[UITextField class]]) {
                UITextField *tf = (UITextField *)v;
                if (tf.inputAccessoryView == nil || tf.inputAccessoryView.tag != kTVKKeyboardToolbarTag) {
                    tf.inputAccessoryView = [self buildDoneToolbar];
                    [tf reloadInputViews];
                }
            } else if ([v isKindOfClass:[UITextView class]]) {
                UITextView *tv = (UITextView *)v;
                if (tv.inputAccessoryView == nil || tv.inputAccessoryView.tag != kTVKKeyboardToolbarTag) {
                    tv.inputAccessoryView = [self buildDoneToolbar];
                    [tv reloadInputViews];
                }
            }
        } @catch (NSException *ex) {
            NSLog(@"[TVKKeyboard] toolbar attach skipped: %@", ex);
        }
    });
}

- (void)dismissKeyboard:(id)sender {
    UIView *active = self.activeInputView;
    if ([active isKindOfClass:[UITextField class]]) {
        UITextField *tf = (UITextField *)active;
        @try {
            if (tf.delegate != nil && [tf.delegate respondsToSelector:@selector(textFieldShouldReturn:)]) {
                [tf.delegate textFieldShouldReturn:tf];
            }
        } @catch (NSException *ex) {
            NSLog(@"[TVKKeyboard] textFieldShouldReturn skipped: %@", ex);
        }
    }
    [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                    [w endEditing:YES];
                }
            }
        }
    }
}

@end

extern "C" void tvk_ios_auth_bridge_init(void);

@interface TVKNotificationBridge : NSObject <UNUserNotificationCenterDelegate>
@property (nonatomic, strong) NSTimer *pollTimer;
@property (nonatomic, assign) NSUInteger scanTickCount;
@property (nonatomic, copy) NSString *activeNotifDir;
@property (nonatomic, copy) NSString *lastDeviceToken;
@property (nonatomic, assign) BOOL isTerminating;
@property (nonatomic, assign) NSTimeInterval lastFlushUnix;
+ (instancetype)shared;
- (void)installDelegateAndHooks;
- (void)start;
- (void)stop;
- (void)flushAndScheduleBackground;
- (void)clearAppBadge;
@end

static TVKNotificationBridge *gNotifBridge = nil;

extern "C" void tvk_ios_auth_bridge_init(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[TVKKeyboardToolbarHandler shared] install];
        [[TVKNotificationBridge shared] installDelegateAndHooks];
        [[TVKNotificationBridge shared] start];
        [[TVKNativeAuthBridge shared] cleanupStaleFiles];
        [[TVKNativeAuthBridge shared] startWatcher];
        [[TVKStoreKitBridge shared] cleanupStaleFiles];
        [[TVKStoreKitBridge shared] start];
    });
}

@implementation TVKNativeAuthBridge

+ (void)load {
    @autoreleasepool {
        [[TVKNotificationBridge shared] installDelegateAndHooks];
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            [[TVKKeyboardToolbarHandler shared] install];
            [[TVKNotificationBridge shared] installDelegateAndHooks];
            [[TVKNotificationBridge shared] clearAppBadge];
            [[TVKNotificationBridge shared] start];
            [[TVKNativeAuthBridge shared] cleanupStaleFiles];
            [[TVKNativeAuthBridge shared] startWatcher];
            [[TVKStoreKitBridge shared] cleanupStaleFiles];
            [[TVKStoreKitBridge shared] start];
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            [[TVKKeyboardToolbarHandler shared] install];
            [[TVKNotificationBridge shared] installDelegateAndHooks];
            [[TVKNotificationBridge shared] clearAppBadge];
            [[TVKNotificationBridge shared] start];
            [[TVKNativeAuthBridge shared] startWatcher];
            [[TVKStoreKitBridge shared] start];
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            [[TVKNotificationBridge shared] flushAndScheduleBackground];
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            [[TVKNotificationBridge shared] flushAndScheduleBackground];
            [[TVKNotificationBridge shared] stop];
            [[TVKNativeAuthBridge shared] stopWatcher];
            [[TVKStoreKitBridge shared] stop];
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            [TVKNotificationBridge shared].isTerminating = YES;
            [[TVKNotificationBridge shared] stop];
            [[TVKNativeAuthBridge shared] stopWatcher];
            [[TVKStoreKitBridge shared] stop];
        }];
        if (@available(iOS 13.0, *)) {
            [[NSNotificationCenter defaultCenter] addObserverForName:UISceneDidActivateNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                [[TVKKeyboardToolbarHandler shared] install];
                [[TVKNotificationBridge shared] installDelegateAndHooks];
                [[TVKNotificationBridge shared] clearAppBadge];
                [[TVKNotificationBridge shared] start];
                [[TVKNativeAuthBridge shared] startWatcher];
                [[TVKStoreKitBridge shared] start];
            }];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[TVKKeyboardToolbarHandler shared] install];
            [[TVKNotificationBridge shared] installDelegateAndHooks];
            [[TVKNotificationBridge shared] start];
            [[TVKNativeAuthBridge shared] cleanupStaleFiles];
            [[TVKNativeAuthBridge shared] startWatcher];
            [[TVKStoreKitBridge shared] cleanupStaleFiles];
            [[TVKStoreKitBridge shared] start];
        });
    }
}

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gBridge = [[TVKNativeAuthBridge alloc] init];
    });
    return gBridge;
}

- (NSArray<NSString *> *)candidateUserDirsWithDeepScan:(BOOL)deepScan {
    return TVKCandidateUserDirs(deepScan, @[kTVKReqFileName, kTVKIapReqFileName, kTVKNotifReqFileName]);
}

- (void)cleanupStaleFiles {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *dir in [self candidateUserDirsWithDeepScan:YES]) {
        [fm removeItemAtPath:[dir stringByAppendingPathComponent:kTVKReqFileName] error:nil];
        [fm removeItemAtPath:[dir stringByAppendingPathComponent:kTVKResFileName] error:nil];
        [fm removeItemAtPath:[dir stringByAppendingPathComponent:kTVKAckFileName] error:nil];
    }
}

- (void)startWatcher {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.pollTimer != nil && [self.pollTimer isValid]) {
            return;
        }
        self.pollTimer = [NSTimer scheduledTimerWithTimeInterval:1.00
                                                          target:self
                                                        selector:@selector(pollForRequest)
                                                        userInfo:nil
                                                         repeats:YES];
        self.pollTimer.tolerance = 0.40;
        [[NSRunLoop mainRunLoop] addTimer:self.pollTimer forMode:NSRunLoopCommonModes];
    });
}

- (void)stopWatcher {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.pollTimer != nil) {
            [self.pollTimer invalidate];
            self.pollTimer = nil;
        }
    });
}

- (UIWindow *)activeKeyWindow {
    if (@available(iOS 13.0, *)) {
        UIWindow *fallbackActive = nil;
        UIWindow *fallbackAny = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] &&
                scene.activationState == UISceneActivationStateForegroundActive) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    if (w.rootViewController == nil || w.hidden) {
                        continue;
                    }
                    if (w.windowLevel == UIWindowLevelNormal && w.isKeyWindow) {
                        return w;
                    }
                    if (w.windowLevel == UIWindowLevelNormal && fallbackActive == nil) {
                        fallbackActive = w;
                    }
                    if (fallbackAny == nil) {
                        fallbackAny = w;
                    }
                }
            }
        }
        if (fallbackActive != nil) {
            return fallbackActive;
        }
        if (fallbackAny != nil) {
            return fallbackAny;
        }
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    if (!w.hidden && w.windowLevel == UIWindowLevelNormal && w.rootViewController != nil) {
                        return w;
                    }
                }
            }
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIWindow *kw = [UIApplication sharedApplication].keyWindow;
    if (kw != nil && !kw.hidden && kw.rootViewController != nil) {
        return kw;
    }
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (!w.hidden && w.rootViewController != nil) {
            return w;
        }
    }
    return kw ?: [UIApplication sharedApplication].windows.firstObject;
#pragma clang diagnostic pop
}

- (UIViewController *)topViewController {
    UIWindow *win = [self activeKeyWindow];
    UIViewController *vc = win.rootViewController;
    while (vc.presentedViewController != nil) {
        vc = vc.presentedViewController;
    }
    return vc;
}

- (void)writeJsonDict:(NSDictionary *)payload fileName:(NSString *)fileName {
    TVKWriteJsonDictToDirs(payload, self.activeDir, fileName);
}

- (void)writeResultDict:(NSDictionary *)payload {
    [self writeJsonDict:payload fileName:kTVKResFileName];
    self.isBusy = NO;
    self.busyStartedAt = 0.0;
    self.appleController = nil;
    self.googleAuthSession = nil;
    self.googleCodeVerifier = nil;
    self.googleOAuthState = nil;
}

- (void)finishSuccessWithProvider:(NSString *)provider
                      providerUid:(NSString *)uid
                             name:(NSString *)name
                            email:(NSString *)email
                    identityToken:(NSString *)idToken {
    NSMutableDictionary *res = [NSMutableDictionary dictionary];
    res[@"req_id"] = self.activeReqId ?: @"";
    res[@"ok"] = @YES;
    res[@"provider"] = provider ?: @"apple";
    res[@"provider_uid"] = uid ?: @"";
    res[@"name"] = name ?: @"";
    res[@"email"] = email ?: @"";
    res[@"identity_token"] = idToken ?: @"";
    [self writeResultDict:res];
}

- (void)finishError:(NSString *)message cancelled:(BOOL)cancelled {
    [self writeResultDict:@{
        @"req_id": self.activeReqId ?: @"",
        @"ok": @NO,
        @"cancelled": @(cancelled),
        @"error": message ?: @"Dogrulama tamamlanamadi."
    }];
}

- (void)pollForRequest {
    NSTimeInterval nowSec = [[NSDate date] timeIntervalSince1970];
    if (self.isBusy && self.presentedNav == nil && self.googleAuthSession == nil && self.busyStartedAt > 0.0 && (nowSec - self.busyStartedAt) > 25.0) {
        self.isBusy = NO;
        self.busyStartedAt = 0.0;
        self.appleController = nil;
    }
    if (self.isBusy) {
        if (self.presentedNav == nil && self.googleAuthSession == nil && self.busyStartedAt > 0.0 && (nowSec - self.busyStartedAt) > 6.0) {
            NSFileManager *fmPre = [NSFileManager defaultManager];
            BOOL hasFreshReq = NO;
            for (NSString *candDir in [self candidateUserDirsWithDeepScan:NO]) {
                NSString *rp = [candDir stringByAppendingPathComponent:kTVKReqFileName];
                if (![fmPre fileExistsAtPath:rp]) {
                    continue;
                }
                NSData *d = [NSData dataWithContentsOfFile:rp];
                id p = d.length > 0 ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
                NSString *newReqId = ([p isKindOfClass:[NSDictionary class]] && [p[@"req_id"] isKindOfClass:[NSString class]]) ? p[@"req_id"] : @"";
                if (newReqId.length > 0 && ![newReqId isEqualToString:(self.activeReqId ?: @"")]) {
                    hasFreshReq = YES;
                    break;
                }
            }
            if (!hasFreshReq) {
                return;
            }
            self.isBusy = NO;
            self.busyStartedAt = 0.0;
            self.appleController = nil;
        } else {
            return;
        }
    }
    self.scanTickCount += 1;
    BOOL deepScan = (self.scanTickCount == 1);
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *candDirs = [self candidateUserDirsWithDeepScan:deepScan];
    for (NSString *dir in candDirs) {
        NSString *reqPath = [dir stringByAppendingPathComponent:kTVKReqFileName];
        if ([fm fileExistsAtPath:reqPath]) {
            NSData *data = [NSData dataWithContentsOfFile:reqPath];
            [fm removeItemAtPath:reqPath error:nil];
            if (data.length == 0) {
                continue;
            }
            id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![parsed isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            NSDictionary *req = (NSDictionary *)parsed;
            self.isBusy = YES;
            self.busyStartedAt = [[NSDate date] timeIntervalSince1970];
            self.activeDir = dir;
            self.activeReqId = [req[@"req_id"] isKindOfClass:[NSString class]] ? req[@"req_id"] : @"";
            self.activeProvider = [req[@"provider"] isKindOfClass:[NSString class]] ? [req[@"provider"] lowercaseString] : @"apple";
            self.activeOAuthUrl = [req[@"oauth_url"] isKindOfClass:[NSString class]] ? req[@"oauth_url"] : @"https://92.5.113.251.nip.io/tahtkilic/api/auth/oauth_page";

            // Remove mirrored duplicate request files with the same req_id
            for (NSString *otherDir in candDirs) {
                if ([otherDir isEqualToString:dir]) {
                    continue;
                }
                NSString *otherPath = [otherDir stringByAppendingPathComponent:kTVKReqFileName];
                if ([fm fileExistsAtPath:otherPath]) {
                    NSData *odata = [NSData dataWithContentsOfFile:otherPath];
                    id oparsed = odata.length > 0 ? [NSJSONSerialization JSONObjectWithData:odata options:0 error:nil] : nil;
                    NSString *oreqId = ([oparsed isKindOfClass:[NSDictionary class]] && [oparsed[@"req_id"] isKindOfClass:[NSString class]]) ? oparsed[@"req_id"] : @"";
                    if (self.activeReqId.length == 0 || oreqId.length == 0 || [oreqId isEqualToString:self.activeReqId]) {
                        [fm removeItemAtPath:otherPath error:nil];
                    }
                }
            }

            // Acknowledge immediately so Godot knows the native bridge picked up the request
            [self writeJsonDict:@{
                @"req_id": self.activeReqId ?: @"",
                @"ack": @YES,
                @"provider": self.activeProvider ?: @"apple"
            } fileName:kTVKAckFileName];

            [self beginAuthFlow];
            return;
        }
    }
}

- (void)beginAuthFlow {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.activeProvider isEqualToString:@"apple"]) {
            [self startNativeAppleSignIn];
        } else {
            [self startNativeGoogleSignIn];
        }
    });
}

#pragma mark - Sign in with Apple

- (void)startNativeAppleSignIn {
#if TVK_HAS_AUTH_SERVICES
    if (@available(iOS 13.0, *)) {
        ASAuthorizationAppleIDProvider *provider = [[ASAuthorizationAppleIDProvider alloc] init];
        ASAuthorizationAppleIDRequest *request = [provider createRequest];
        request.requestedScopes = @[ASAuthorizationScopeFullName, ASAuthorizationScopeEmail];

        ASAuthorizationController *controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
        controller.delegate = self;
        controller.presentationContextProvider = self;
        self.appleController = controller;
        [controller performRequests];
        return;
    }
#endif
    NSURL *url = [NSURL URLWithString:self.activeOAuthUrl];
    if (url != nil) {
        [self presentEmbeddedWKWebView:url provider:@"apple"];
    } else {
        [self finishError:@"Apple giris sayfasi acilamadi." cancelled:NO];
    }
}

#if TVK_HAS_AUTH_SERVICES
- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(ASAuthorizationController *)controller API_AVAILABLE(ios(13.0)) {
    return [self activeKeyWindow];
}

- (void)authorizationController:(ASAuthorizationController *)controller
   didCompleteWithAuthorization:(ASAuthorization *)authorization API_AVAILABLE(ios(13.0)) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![authorization.credential isKindOfClass:[ASAuthorizationAppleIDCredential class]]) {
            [self finishError:@"Gecersiz Apple kimlik bilgisi." cancelled:NO];
            return;
        }
        ASAuthorizationAppleIDCredential *cred = (ASAuthorizationAppleIDCredential *)authorization.credential;
        NSString *uid = cred.user ?: @"";
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        NSString *idTok = @"";
        if (cred.identityToken != nil) {
            NSString *utf8Tok = [[NSString alloc] initWithData:cred.identityToken encoding:NSUTF8StringEncoding];
            idTok = utf8Tok ?: [cred.identityToken base64EncodedStringWithOptions:0];
        }

        NSString *email = cred.email;
        if (email.length == 0 && idTok.length > 0) {
            email = TVKExtractEmailFromJWT(idTok);
        }
        if (email.length > 0 && uid.length > 0) {
            [defaults setObject:email forKey:[kTVKAppleEmailPrefix stringByAppendingString:uid]];
        } else if (uid.length > 0) {
            email = [defaults stringForKey:[kTVKAppleEmailPrefix stringByAppendingString:uid]] ?: @"";
        }

        NSString *fullName = @"";
        if (cred.fullName != nil) {
            NSString *formatted = [NSPersonNameComponentsFormatter localizedStringFromPersonNameComponents:cred.fullName
                                                                                                    style:NSPersonNameComponentsFormatterStyleDefault
                                                                                                  options:0];
            fullName = [formatted stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
        if (fullName.length > 0 && uid.length > 0) {
            [defaults setObject:fullName forKey:[kTVKAppleNamePrefix stringByAppendingString:uid]];
        } else if (uid.length > 0) {
            fullName = [defaults stringForKey:[kTVKAppleNamePrefix stringByAppendingString:uid]] ?: @"";
        }

        if (fullName.length == 0 && email.length > 0) {
            NSString *prefix = [email componentsSeparatedByString:@"@"].firstObject;
            if (prefix.length > 0) {
                fullName = [[prefix stringByReplacingOccurrencesOfString:@"." withString:@" "] capitalizedString];
            }
        }
        if (fullName.length == 0) {
            NSString *shortId = uid.length >= 6 ? [uid substringToIndex:6] : @"Apple";
            fullName = [NSString stringWithFormat:@"Apple %@", shortId];
        }
        [defaults synchronize];

        [self finishSuccessWithProvider:@"apple"
                            providerUid:uid
                                   name:fullName
                                  email:(email ?: @"")
                          identityToken:(idTok ?: @"")];
    });
}

- (void)authorizationController:(ASAuthorizationController *)controller
           didCompleteWithError:(NSError *)error API_AVAILABLE(ios(13.0)) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error.code == ASAuthorizationErrorCanceled) {
            [self finishError:@"Apple ile giris iptal edildi." cancelled:YES];
            return;
        }
        // Fallback immediately to in-app WKWebView Apple sign-in sheet when native Sign In fails
        NSURL *url = [NSURL URLWithString:self.activeOAuthUrl];
        if (url != nil) {
            [self presentEmbeddedWKWebView:url provider:@"apple"];
        } else {
            [self finishError:(error.localizedDescription ?: @"Apple dogrulamasi basarisiz.") cancelled:NO];
        }
    });
}
#endif

#pragma mark - Sign in with Google (In-App ASWebAuthenticationSession + PKCE)

- (void)startNativeGoogleSignIn {
    [self launchGoogleASWebAuthenticationSessionWithAttempt:0];
}

#if TVK_HAS_AUTH_SERVICES
- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(ASWebAuthenticationSession *)session API_AVAILABLE(ios(13.0)) {
    return [self activeKeyWindow];
}
#endif

- (void)launchGoogleASWebAuthenticationSession {
    [self launchGoogleASWebAuthenticationSessionWithAttempt:0];
}

- (void)launchGoogleASWebAuthenticationSessionWithAttempt:(NSInteger)attempt {
#if TVK_HAS_AUTH_SERVICES
    if (@available(iOS 12.0, *)) {
        UIWindow *anchorWin = [self activeKeyWindow];
        UIApplicationState appState = [UIApplication sharedApplication].applicationState;
        if ((appState != UIApplicationStateActive || anchorWin == nil) && attempt < 10) {
            __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf launchGoogleASWebAuthenticationSessionWithAttempt:(attempt + 1)];
            });
            return;
        }
        if (anchorWin == nil) {
            [self finishError:@"Google oturum penceresi icin aktif pencere bulunamadi." cancelled:NO];
            return;
        }

        NSString *verifier = TVKRandomBase64URL(32);
        NSString *challenge = TVKSHA256Base64URL(verifier);
        NSString *state = TVKRandomBase64URL(16);
        self.googleCodeVerifier = verifier;
        self.googleOAuthState = state;

        NSURLComponents *comps = [NSURLComponents componentsWithString:@"https://accounts.google.com/o/oauth2/v2/auth"];
        comps.queryItems = @[
            [NSURLQueryItem queryItemWithName:@"client_id" value:kTVKGoogleClientId],
            [NSURLQueryItem queryItemWithName:@"redirect_uri" value:kTVKGoogleRedirectURI],
            [NSURLQueryItem queryItemWithName:@"response_type" value:@"code"],
            [NSURLQueryItem queryItemWithName:@"scope" value:@"openid email profile"],
            [NSURLQueryItem queryItemWithName:@"code_challenge" value:challenge],
            [NSURLQueryItem queryItemWithName:@"code_challenge_method" value:@"S256"],
            [NSURLQueryItem queryItemWithName:@"state" value:state],
            [NSURLQueryItem queryItemWithName:@"prompt" value:@"login"]
        ];
        NSURL *authURL = comps.URL;
        if (authURL == nil) {
            [self finishError:@"Google OAuth URL olusturulamadi." cancelled:NO];
            return;
        }

        __weak typeof(self) weakSelf = self;
        ASWebAuthenticationSession *session = [[ASWebAuthenticationSession alloc]
            initWithURL:authURL
            callbackURLScheme:kTVKGoogleCallbackScheme
            completionHandler:^(NSURL * _Nullable callbackURL, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    TVKNativeAuthBridge *strongSelf = weakSelf;
                    if (strongSelf == nil) {
                        return;
                    }
                    strongSelf.googleAuthSession = nil;

                    if (error != nil) {
                        if (@available(iOS 13.0, *)) {
                            if ([error.domain isEqualToString:ASWebAuthenticationSessionErrorDomain] &&
                                error.code == ASWebAuthenticationSessionErrorCodePresentationContextInvalid &&
                                attempt < 2) {
                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                    [strongSelf launchGoogleASWebAuthenticationSessionWithAttempt:(attempt + 1)];
                                });
                                return;
                            }
                        }
                        BOOL isCancel = (error.code == ASWebAuthenticationSessionErrorCodeCanceledLogin);
                        NSString *msg = isCancel ? @"Google ile giris iptal edildi." : (error.localizedDescription ?: @"Google dogrulamasi basarisiz.");
                        [strongSelf finishError:msg cancelled:isCancel];
                        return;
                    }
                    if (callbackURL == nil) {
                        [strongSelf finishError:@"Google donus adresi alinamadi." cancelled:NO];
                        return;
                    }

                    NSURLComponents *cbComps = [NSURLComponents componentsWithURL:callbackURL resolvingAgainstBaseURL:NO];
                    NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
                    for (NSURLQueryItem *item in cbComps.queryItems) {
                        if (item.name != nil && item.value != nil) {
                            params[item.name] = item.value;
                        }
                    }

                    if (params[@"error"].length > 0) {
                        BOOL isAccessDenied = [params[@"error"] isEqualToString:@"access_denied"];
                        [strongSelf finishError:(isAccessDenied ? @"Google ile giris iptal edildi." : params[@"error"]) cancelled:isAccessDenied];
                        return;
                    }

                    NSString *retState = params[@"state"] ?: @"";
                    if (strongSelf.googleOAuthState.length > 0 && ![retState isEqualToString:strongSelf.googleOAuthState]) {
                        [strongSelf finishError:@"Google guvenlik durumu (state) eslesmedi." cancelled:NO];
                        return;
                    }

                    NSString *code = params[@"code"] ?: @"";
                    if (code.length == 0) {
                        [strongSelf finishError:@"Google yetkilendirme kodu alinamadi." cancelled:NO];
                        return;
                    }

                    [strongSelf exchangeGoogleAuthCode:code];
                });
            }];

        if (@available(iOS 13.0, *)) {
            session.presentationContextProvider = self;
            session.prefersEphemeralWebBrowserSession = YES;
        }
        self.googleAuthSession = session;
        if (![session start]) {
            self.googleAuthSession = nil;
            if (attempt < 2) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [weakSelf launchGoogleASWebAuthenticationSessionWithAttempt:(attempt + 1)];
                });
                return;
            }
            [self finishError:@"Google oturum penceresi baslatilamadi." cancelled:NO];
        }
        return;
    }
#endif
    NSURL *url = [NSURL URLWithString:self.activeOAuthUrl];
    if (url != nil) {
        [self presentEmbeddedWKWebView:url provider:@"google"];
    } else {
        [self finishError:@"Google giris sayfasi acilamadi." cancelled:NO];
    }
}

- (void)exchangeGoogleAuthCode:(NSString *)code {
    NSURL *tokenURL = [NSURL URLWithString:@"https://oauth2.googleapis.com/token"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:tokenURL
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:15.0];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

    NSString *bodyStr = [NSString stringWithFormat:@"client_id=%@&code=%@&code_verifier=%@&redirect_uri=%@&grant_type=authorization_code",
        TVKFormURLEncode(kTVKGoogleClientId),
        TVKFormURLEncode(code),
        TVKFormURLEncode(self.googleCodeVerifier ?: @""),
        TVKFormURLEncode(kTVKGoogleRedirectURI)];
    req.HTTPBody = [bodyStr dataUsingEncoding:NSUTF8StringEncoding];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            TVKNativeAuthBridge *strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }
            if (error != nil || data.length == 0) {
                [strongSelf finishError:(error.localizedDescription ?: @"Google token degisimi basarisiz.") cancelled:NO];
                return;
            }
            id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![obj isKindOfClass:[NSDictionary class]]) {
                [strongSelf finishError:@"Google token cevabi okunamadi." cancelled:NO];
                return;
            }
            NSDictionary *tokDict = (NSDictionary *)obj;
            if ([tokDict[@"error"] isKindOfClass:[NSString class]] && ((NSString *)tokDict[@"error"]).length > 0) {
                NSString *errDesc = [tokDict[@"error_description"] isKindOfClass:[NSString class]] ? tokDict[@"error_description"] : tokDict[@"error"];
                [strongSelf finishError:errDesc cancelled:NO];
                return;
            }

            NSString *idToken = [tokDict[@"id_token"] isKindOfClass:[NSString class]] ? tokDict[@"id_token"] : @"";
            NSString *accessToken = [tokDict[@"access_token"] isKindOfClass:[NSString class]] ? tokDict[@"access_token"] : @"";

            NSDictionary *claims = TVKDecodeJWTPayload(idToken);
            NSString *sub = [claims[@"sub"] isKindOfClass:[NSString class]] ? claims[@"sub"] : @"";
            NSString *email = [claims[@"email"] isKindOfClass:[NSString class]] ? [claims[@"email"] lowercaseString] : @"";
            NSString *fullName = [claims[@"name"] isKindOfClass:[NSString class]] ? [claims[@"name"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";

            if ((sub.length == 0 || email.length == 0) && accessToken.length > 0) {
                [strongSelf fetchGoogleUserInfoWithAccessToken:accessToken
                                                       idToken:idToken
                                                    initialSub:sub
                                                  initialEmail:email
                                                   initialName:fullName];
                return;
            }

            [strongSelf completeGoogleIdentityWithSub:sub email:email name:fullName idToken:idToken];
        });
    }];
    [task resume];
}

- (void)fetchGoogleUserInfoWithAccessToken:(NSString *)accessToken
                                   idToken:(NSString *)idToken
                                initialSub:(NSString *)initialSub
                              initialEmail:(NSString *)initialEmail
                               initialName:(NSString *)initialName {
    NSURL *infoURL = [NSURL URLWithString:@"https://openidconnect.googleapis.com/v1/userinfo"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:infoURL
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:12.0];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            TVKNativeAuthBridge *strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }
            NSString *sub = initialSub ?: @"";
            NSString *email = initialEmail ?: @"";
            NSString *fullName = initialName ?: @"";
            if (error == nil && data.length > 0) {
                id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([obj isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *ui = (NSDictionary *)obj;
                    if (sub.length == 0 && [ui[@"sub"] isKindOfClass:[NSString class]]) {
                        sub = ui[@"sub"];
                    }
                    if (email.length == 0 && [ui[@"email"] isKindOfClass:[NSString class]]) {
                        email = [ui[@"email"] lowercaseString];
                    }
                    if (fullName.length == 0 && [ui[@"name"] isKindOfClass:[NSString class]]) {
                        fullName = [ui[@"name"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    }
                }
            }
            [strongSelf completeGoogleIdentityWithSub:sub email:email name:fullName idToken:idToken];
        });
    }];
    [task resume];
}

- (void)completeGoogleIdentityWithSub:(NSString *)sub
                                email:(NSString *)email
                                 name:(NSString *)name
                              idToken:(NSString *)idToken {
    NSString *cleanSub = [sub stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
    NSString *cleanEmail = [[email stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString] ?: @"";
    NSString *cleanName = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";

    if (cleanSub.length == 0 && cleanEmail.length == 0) {
        [self finishError:@"Google hesap kimligi alinamadi." cancelled:NO];
        return;
    }

    if (cleanName.length == 0 && cleanEmail.length > 0) {
        NSString *prefix = [cleanEmail componentsSeparatedByString:@"@"].firstObject;
        if (prefix.length > 0) {
            cleanName = [[prefix stringByReplacingOccurrencesOfString:@"." withString:@" "] capitalizedString];
        }
    }
    if (cleanName.length == 0) {
        NSString *shortId = cleanSub.length >= 6 ? [cleanSub substringToIndex:6] : @"Google";
        cleanName = [NSString stringWithFormat:@"Google %@", shortId];
    }

    [self finishSuccessWithProvider:@"google"
                        providerUid:cleanSub
                               name:cleanName
                              email:cleanEmail
                      identityToken:(idToken ?: @"")];
}

#pragma mark - In-App WKWebView OAuth Sheet

- (void)presentEmbeddedWKWebView:(NSURL *)url provider:(NSString *)provider {
    UIViewController *topVC = [self topViewController];
    if (topVC == nil) {
        [self finishError:@"Gorunum denetleyicisi bulunamadi." cancelled:NO];
        return;
    }

    WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
    cfg.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:cfg];
    webView.navigationDelegate = self;
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    UIViewController *webVC = [[UIViewController alloc] init];
    webVC.title = [provider isEqualToString:@"apple"] ? @"Apple ile Giris Yap" : @"Google ile Giris Yap";
    webVC.view.backgroundColor = [provider isEqualToString:@"apple"]
        ? [UIColor colorWithRed:0.06 green:0.07 blue:0.10 alpha:1.0]
        : [UIColor colorWithRed:0.96 green:0.97 blue:0.99 alpha:1.0];
    webView.frame = webVC.view.bounds;
    [webVC.view addSubview:webView];

    UIActivityIndicatorViewStyle spStyle = UIActivityIndicatorViewStyleMedium;
    if (@available(iOS 13.0, *)) {
        spStyle = UIActivityIndicatorViewStyleLarge;
    }
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:spStyle];
    spinner.center = webVC.view.center;
    spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                               UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    spinner.hidesWhenStopped = YES;
    [spinner startAnimating];
    [webVC.view addSubview:spinner];
    self.loadingSpinner = spinner;

    UIBarButtonItem *cancelBtn = [[UIBarButtonItem alloc] initWithTitle:@"Iptal"
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(onCancelModalTapped)];
    webVC.navigationItem.leftBarButtonItem = cancelBtn;

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:webVC];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    nav.presentationController.delegate = self;
    self.presentedNav = nav;

    [topVC presentViewController:nav animated:YES completion:^{
        [webView loadRequest:[NSURLRequest requestWithURL:url]];
    }];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self.loadingSpinner stopAnimating];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self.loadingSpinner stopAnimating];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self.loadingSpinner stopAnimating];
    if (error == nil) {
        return;
    }
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
        return;
    }
    if ([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 102) {
        return;
    }
    NSString *failingUrl = [error.userInfo[NSURLErrorFailingURLStringErrorKey] isKindOfClass:[NSString class]]
        ? [(NSString *)error.userInfo[NSURLErrorFailingURLStringErrorKey] lowercaseString]
        : @"";
    if ([failingUrl hasPrefix:@"tahtkilic://"]) {
        return;
    }
    NSString *errMsg = error.localizedDescription ?: @"Giris sayfasi yuklenemedi.";
    if (self.presentedNav != nil) {
        [self.presentedNav dismissViewControllerAnimated:YES completion:^{
            self.presentedNav = nil;
            self.loadingSpinner = nil;
            [self finishError:errMsg cancelled:NO];
        }];
    } else if (self.isBusy) {
        [self finishError:errMsg cancelled:NO];
    }
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    self.presentedNav = nil;
    self.loadingSpinner = nil;
    if (self.isBusy) {
        [self finishError:@"Giris iptal edildi." cancelled:YES];
    }
}

- (void)onCancelModalTapped {
    if (self.presentedNav != nil) {
        [self.presentedNav dismissViewControllerAnimated:YES completion:^{
            self.presentedNav = nil;
            self.loadingSpinner = nil;
            [self finishError:@"Giris iptal edildi." cancelled:YES];
        }];
    } else {
        [self finishError:@"Giris iptal edildi." cancelled:YES];
    }
}

- (void)webView:(WKWebView *)webView
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *targetUrl = navigationAction.request.URL;
    if (targetUrl != nil && [[targetUrl.scheme lowercaseString] isEqualToString:@"tahtkilic"]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        if (self.presentedNav != nil) {
            [self.presentedNav dismissViewControllerAnimated:YES completion:^{
                self.presentedNav = nil;
                self.loadingSpinner = nil;
                [self handleCallbackURL:targetUrl defaultProvider:self.activeProvider];
            }];
        } else {
            [self handleCallbackURL:targetUrl defaultProvider:self.activeProvider];
        }
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)handleCallbackURL:(NSURL *)url defaultProvider:(NSString *)defaultProvider {
    NSURLComponents *comps = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *item in comps.queryItems) {
        if (item.name != nil && item.value != nil) {
            params[item.name] = item.value;
        }
    }
    if ([params[@"cancelled"] isEqualToString:@"1"] || [params[@"ok"] isEqualToString:@"0"]) {
        [self finishError:(params[@"error"] ?: @"Giris iptal edildi.") cancelled:YES];
        return;
    }
    NSString *prov = params[@"provider"].length > 0 ? params[@"provider"] : (defaultProvider ?: @"google");
    NSString *uid = params[@"provider_uid"] ?: @"";
    NSString *name = params[@"name"] ?: @"";
    NSString *email = params[@"email"] ?: @"";
    NSString *idTok = params[@"identity_token"] ?: @"";
    [self finishSuccessWithProvider:prov providerUid:uid name:name email:email identityToken:idTok];
}

@end

#pragma mark - StoreKit IAP Bridge

@implementation TVKStoreKitBridge

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gStoreKitBridge = [[TVKStoreKitBridge alloc] init];
    });
    return gStoreKitBridge;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _cachedProducts = [NSMutableDictionary dictionary];
        _restoredProductIds = [NSMutableArray array];
    }
    return self;
}

- (void)cleanupStaleFiles {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *dir in TVKCandidateUserDirs(YES, @[kTVKReqFileName, kTVKIapReqFileName])) {
        [fm removeItemAtPath:[dir stringByAppendingPathComponent:kTVKIapReqFileName] error:nil];
        [fm removeItemAtPath:[dir stringByAppendingPathComponent:kTVKIapProductsFileName] error:nil];
        [fm removeItemAtPath:[dir stringByAppendingPathComponent:kTVKIapResFileName] error:nil];
    }
}

- (void)start {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.observingTransactions) {
            self.observingTransactions = YES;
            [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        }
        if (self.pollTimer != nil && [self.pollTimer isValid]) {
            return;
        }
        self.pollTimer = [NSTimer scheduledTimerWithTimeInterval:1.50
                                                          target:self
                                                        selector:@selector(pollForIapRequest)
                                                        userInfo:nil
                                                         repeats:YES];
        self.pollTimer.tolerance = 0.50;
        [[NSRunLoop mainRunLoop] addTimer:self.pollTimer forMode:NSRunLoopCommonModes];
    });
}

- (void)stop {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.pollTimer != nil) {
            [self.pollTimer invalidate];
            self.pollTimer = nil;
        }
    });
}

- (void)writeIapResult:(NSDictionary *)payload {
    TVKWriteJsonDictToDirs(payload, self.activeIapDir, kTVKIapResFileName);
    self.isPurchaseBusy = NO;
    self.isRestoring = NO;
}

- (void)pollForIapRequest {
    self.scanTickCount += 1;
    BOOL deepScan = (self.scanTickCount == 1);
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *candDirs = TVKCandidateUserDirs(deepScan, @[kTVKIapReqFileName]);
    for (NSString *dir in candDirs) {
        NSString *reqPath = [dir stringByAppendingPathComponent:kTVKIapReqFileName];
        if (![fm fileExistsAtPath:reqPath]) {
            continue;
        }
        NSData *data = [NSData dataWithContentsOfFile:reqPath];
        if (data.length == 0) {
            [fm removeItemAtPath:reqPath error:nil];
            continue;
        }
        id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![parsed isKindOfClass:[NSDictionary class]]) {
            [fm removeItemAtPath:reqPath error:nil];
            continue;
        }
        NSDictionary *req = (NSDictionary *)parsed;
        NSString *action = [req[@"action"] isKindOfClass:[NSString class]] ? [req[@"action"] lowercaseString] : @"";
        if (action.length == 0 && [req[@"type"] isKindOfClass:[NSString class]]) {
            action = [req[@"type"] lowercaseString];
        }

        if (([action isEqualToString:@"purchase"] || [action isEqualToString:@"restore"]) && self.isPurchaseBusy) {
            return;
        }

        [fm removeItemAtPath:reqPath error:nil];
        NSString *reqId = [req[@"req_id"] isKindOfClass:[NSString class]] ? req[@"req_id"] : @"";

        // Remove mirrored duplicate request files with the same req_id
        for (NSString *otherDir in candDirs) {
            if ([otherDir isEqualToString:dir]) {
                continue;
            }
            NSString *otherPath = [otherDir stringByAppendingPathComponent:kTVKIapReqFileName];
            if ([fm fileExistsAtPath:otherPath]) {
                NSData *odata = [NSData dataWithContentsOfFile:otherPath];
                id oparsed = odata.length > 0 ? [NSJSONSerialization JSONObjectWithData:odata options:0 error:nil] : nil;
                NSString *oreqId = ([oparsed isKindOfClass:[NSDictionary class]] && [oparsed[@"req_id"] isKindOfClass:[NSString class]]) ? oparsed[@"req_id"] : @"";
                if (reqId.length == 0 || oreqId.length == 0 || [oreqId isEqualToString:reqId]) {
                    [fm removeItemAtPath:otherPath error:nil];
                }
            }
        }

        if ([action isEqualToString:@"fetch_products"]) {
            NSArray *rawIds = [req[@"product_ids"] isKindOfClass:[NSArray class]] ? req[@"product_ids"] : @[];
            [self handleFetchProducts:rawIds reqId:reqId dir:dir];
            return;
        } else if ([action isEqualToString:@"purchase"]) {
            NSString *productId = [req[@"product_id"] isKindOfClass:[NSString class]] ? req[@"product_id"] : @"";
            [self handlePurchase:productId reqId:reqId dir:dir];
            return;
        } else if ([action isEqualToString:@"restore"]) {
            [self handleRestoreWithReqId:reqId dir:dir];
            return;
        }
    }
}

- (void)handleFetchProducts:(NSArray *)rawIds reqId:(NSString *)reqId dir:(NSString *)dir {
    NSMutableSet<NSString *> *idSet = [NSMutableSet set];
    for (id item in rawIds) {
        if ([item isKindOfClass:[NSString class]] && [(NSString *)item length] > 0) {
            [idSet addObject:(NSString *)item];
        }
    }
    self.activeFetchDir = dir;
    self.activeFetchReqId = reqId ?: @"";
    if (idSet.count == 0) {
        TVKWriteJsonDictToDirs(@{
            @"ok": @YES,
            @"req_id": self.activeFetchReqId ?: @"",
            @"products": @{}
        }, self.activeFetchDir, kTVKIapProductsFileName);
        return;
    }

    if (self.productFetchRequest != nil) {
        self.productFetchRequest.delegate = nil;
        [self.productFetchRequest cancel];
        self.productFetchRequest = nil;
    }

    SKProductsRequest *preq = [[SKProductsRequest alloc] initWithProductIdentifiers:idSet];
    preq.delegate = self;
    self.productFetchRequest = preq;
    [preq start];
}

- (void)handlePurchase:(NSString *)productId reqId:(NSString *)reqId dir:(NSString *)dir {
    self.isPurchaseBusy = YES;
    self.isRestoring = NO;
    self.activeIapDir = dir;
    self.activePurchaseReqId = reqId ?: @"";
    self.activePurchaseProductId = productId ?: @"";

    if (productId.length == 0) {
        [self writeIapResult:@{
            @"ok": @NO,
            @"action": @"purchase",
            @"req_id": self.activePurchaseReqId ?: @"",
            @"product_id": @"",
            @"cancelled": @NO,
            @"error": @"Gecersiz urun kimligi."
        }];
        return;
    }

    if (![SKPaymentQueue canMakePayments]) {
        [self writeIapResult:@{
            @"ok": @NO,
            @"action": @"purchase",
            @"req_id": self.activePurchaseReqId ?: @"",
            @"product_id": productId,
            @"cancelled": @NO,
            @"error": @"Bu cihazda uygulama ici satin alma kapali."
        }];
        return;
    }

    SKProduct *cached = self.cachedProducts[productId];
    if (cached != nil) {
        SKPayment *payment = [SKPayment paymentWithProduct:cached];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
        return;
    }

    if (self.purchaseProductRequest != nil) {
        self.purchaseProductRequest.delegate = nil;
        [self.purchaseProductRequest cancel];
        self.purchaseProductRequest = nil;
    }

    SKProductsRequest *preq = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithObject:productId]];
    preq.delegate = self;
    self.purchaseProductRequest = preq;
    [preq start];
}

- (void)handleRestoreWithReqId:(NSString *)reqId dir:(NSString *)dir {
    self.isPurchaseBusy = YES;
    self.isRestoring = YES;
    self.activeIapDir = dir;
    self.activePurchaseReqId = reqId ?: @"";
    self.activePurchaseProductId = @"";
    [self.restoredProductIds removeAllObjects];
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (SKProduct *p in response.products) {
            if (p.productIdentifier.length > 0) {
                self.cachedProducts[p.productIdentifier] = p;
            }
        }

        if (request == self.purchaseProductRequest) {
            self.purchaseProductRequest = nil;
            SKProduct *target = self.cachedProducts[self.activePurchaseProductId ?: @""] ?: response.products.firstObject;
            if (target != nil) {
                SKPayment *payment = [SKPayment paymentWithProduct:target];
                [[SKPaymentQueue defaultQueue] addPayment:payment];
            } else {
                [self writeIapResult:@{
                    @"ok": @NO,
                    @"action": @"purchase",
                    @"req_id": self.activePurchaseReqId ?: @"",
                    @"product_id": self.activePurchaseProductId ?: @"",
                    @"cancelled": @NO,
                    @"error": @"Urun App Store uzerinde bulunamadi."
                }];
            }
            return;
        }

        if (request == self.productFetchRequest) {
            self.productFetchRequest = nil;
        }

        NSMutableDictionary *productsDict = [NSMutableDictionary dictionary];
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterCurrencyStyle;
        for (SKProduct *p in response.products) {
            if (p.productIdentifier.length == 0) {
                continue;
            }
            formatter.locale = p.priceLocale;
            NSString *priceString = [formatter stringFromNumber:p.price] ?: @"";
            NSString *currencyCode = [p.priceLocale objectForKey:NSLocaleCurrencyCode] ?: @"";
            double rawPrice = [p.price doubleValue];
            NSNumber *priceVal = isfinite(rawPrice) ? @(rawPrice) : @(0.0);
            productsDict[p.productIdentifier] = @{
                @"title": p.localizedTitle ?: @"",
                @"price_string": priceString,
                @"currency_code": currencyCode,
                @"price": priceVal
            };
        }

        TVKWriteJsonDictToDirs(@{
            @"ok": @YES,
            @"req_id": self.activeFetchReqId ?: @"",
            @"products": productsDict
        }, self.activeFetchDir, kTVKIapProductsFileName);
    });
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *errMsg = error.localizedDescription ?: @"App Store baglantisi basarisiz.";
        if (request == self.purchaseProductRequest) {
            self.purchaseProductRequest = nil;
            [self writeIapResult:@{
                @"ok": @NO,
                @"action": @"purchase",
                @"req_id": self.activePurchaseReqId ?: @"",
                @"product_id": self.activePurchaseProductId ?: @"",
                @"cancelled": @NO,
                @"error": errMsg
            }];
            return;
        }
        if (request == self.productFetchRequest) {
            self.productFetchRequest = nil;
            TVKWriteJsonDictToDirs(@{
                @"ok": @NO,
                @"req_id": self.activeFetchReqId ?: @"",
                @"error": errMsg,
                @"products": @{}
            }, self.activeFetchDir, kTVKIapProductsFileName);
        }
    });
}

#pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (SKPaymentTransaction *tx in transactions) {
            NSString *pid = tx.payment.productIdentifier ?: (self.activePurchaseProductId ?: @"");
            switch (tx.transactionState) {
                case SKPaymentTransactionStatePurchased: {
                    NSString *txId = tx.transactionIdentifier ?: @"";
                    NSString *receiptB64 = TVKBase64AppStoreReceipt();
                    [[SKPaymentQueue defaultQueue] finishTransaction:tx];
                    [self writeIapResult:@{
                        @"ok": @YES,
                        @"action": @"purchase",
                        @"req_id": self.activePurchaseReqId ?: @"",
                        @"product_id": pid,
                        @"transaction_id": txId,
                        @"receipt_data": receiptB64
                    }];
                    break;
                }
                case SKPaymentTransactionStateFailed: {
                    BOOL isCancelled = (tx.error != nil &&
                                        [tx.error.domain isEqualToString:SKErrorDomain] &&
                                        tx.error.code == SKErrorPaymentCancelled);
                    NSString *errMsg = isCancelled
                        ? @"Satin alma iptal edildi."
                        : (tx.error.localizedDescription ?: @"Satin alma tamamlanamadi.");
                    [[SKPaymentQueue defaultQueue] finishTransaction:tx];
                    if (self.isPurchaseBusy && !self.isRestoring) {
                        [self writeIapResult:@{
                            @"ok": @NO,
                            @"action": @"purchase",
                            @"req_id": self.activePurchaseReqId ?: @"",
                            @"product_id": pid,
                            @"cancelled": @(isCancelled),
                            @"error": errMsg
                        }];
                    }
                    break;
                }
                case SKPaymentTransactionStateRestored: {
                    if (pid.length > 0 && ![self.restoredProductIds containsObject:pid]) {
                        [self.restoredProductIds addObject:pid];
                    }
                    [[SKPaymentQueue defaultQueue] finishTransaction:tx];
                    break;
                }
                case SKPaymentTransactionStatePurchasing:
                case SKPaymentTransactionStateDeferred:
                    break;
            }
        }
    });
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.isRestoring) {
            return;
        }
        NSString *receiptB64 = TVKBase64AppStoreReceipt();
        [self writeIapResult:@{
            @"ok": @YES,
            @"action": @"restore",
            @"req_id": self.activePurchaseReqId ?: @"",
            @"restored_products": [self.restoredProductIds copy],
            @"receipt_data": receiptB64
        }];
    });
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.isRestoring) {
            return;
        }
        BOOL isCancelled = (error != nil &&
                            [error.domain isEqualToString:SKErrorDomain] &&
                            error.code == SKErrorPaymentCancelled);
        [self writeIapResult:@{
            @"ok": @NO,
            @"action": @"restore",
            @"req_id": self.activePurchaseReqId ?: @"",
            @"cancelled": @(isCancelled),
            @"error": error.localizedDescription ?: @"Satin alimlar geri yuklenemedi."
        }];
    });
}

@end

#pragma mark - Native Notification, APNs Token & BGAppRefresh Bridge

typedef void (*TVKDidRegIMP)(id, SEL, UIApplication *, NSData *);
typedef void (*TVKDidFailIMP)(id, SEL, UIApplication *, NSError *);
static TVKDidRegIMP gTVKOrigDidRegIMP = NULL;
static TVKDidFailIMP gTVKOrigDidFailIMP = NULL;

@interface TVKNotificationBridge ()
- (void)handleRemoteDeviceToken:(NSData *)deviceToken;
- (void)handleRemoteTokenError:(NSError *)error;
@end

static void tvk_swizzledDidRegister(id selfObj, SEL _cmd, UIApplication *application, NSData *deviceToken) {
    if (gTVKOrigDidRegIMP != NULL) {
        gTVKOrigDidRegIMP(selfObj, _cmd, application, deviceToken);
    }
    [[TVKNotificationBridge shared] handleRemoteDeviceToken:deviceToken];
}

static void tvk_swizzledDidFailRegister(id selfObj, SEL _cmd, UIApplication *application, NSError *error) {
    if (gTVKOrigDidFailIMP != NULL) {
        gTVKOrigDidFailIMP(selfObj, _cmd, application, error);
    }
    [[TVKNotificationBridge shared] handleRemoteTokenError:error];
}

@implementation TVKNotificationBridge

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gNotifBridge = [[TVKNotificationBridge alloc] init];
    });
    return gNotifBridge;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        NSString *savedTok = [[NSUserDefaults standardUserDefaults] stringForKey:kTVKNotifDeviceTokenKey];
        if (savedTok.length > 0) {
            _lastDeviceToken = [savedTok copy];
        }
    }
    return self;
}

- (void)installDelegateAndHooks {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isTerminating) {
            return;
        }
        @try {
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            if (center.delegate != self) {
                center.delegate = self;
            }
            [self hookAppDelegatePushCallbacksIfPossible];
            [self publishCurrentStatus];
        } @catch (NSException *ex) {
            NSLog(@"[TVKNotif] installDelegateAndHooks exception: %@", ex);
        }
    });
}

- (void)hookAppDelegatePushCallbacksIfPossible {
    static BOOL sHooked = NO;
    if (sHooked || self.isTerminating) {
        return;
    }
    UIApplication *app = [UIApplication sharedApplication];
    id<UIApplicationDelegate> del = app.delegate;
    if (del == nil) {
        return;
    }
    sHooked = YES;
    Class cls = object_getClass(del);
    if (cls == Nil) {
        return;
    }

    SEL regSel = @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:);
    Method regM = class_getInstanceMethod(cls, regSel);
    if (regM != NULL) {
        gTVKOrigDidRegIMP = (TVKDidRegIMP)method_getImplementation(regM);
        method_setImplementation(regM, (IMP)tvk_swizzledDidRegister);
    } else {
        class_addMethod(cls, regSel, (IMP)tvk_swizzledDidRegister, "v@:@@");
    }

    SEL failSel = @selector(application:didFailToRegisterForRemoteNotificationsWithError:);
    Method failM = class_getInstanceMethod(cls, failSel);
    if (failM != NULL) {
        gTVKOrigDidFailIMP = (TVKDidFailIMP)method_getImplementation(failM);
        method_setImplementation(failM, (IMP)tvk_swizzledDidFailRegister);
    } else {
        class_addMethod(cls, failSel, (IMP)tvk_swizzledDidFailRegister, "v@:@@");
    }
}

- (void)start {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isTerminating) {
            return;
        }
        if (self.pollTimer != nil && [self.pollTimer isValid]) {
            return;
        }
        self.pollTimer = [NSTimer scheduledTimerWithTimeInterval:2.00
                                                          target:self
                                                        selector:@selector(pollForNotifRequest)
                                                        userInfo:nil
                                                         repeats:YES];
        self.pollTimer.tolerance = 0.60;
        [[NSRunLoop mainRunLoop] addTimer:self.pollTimer forMode:NSRunLoopCommonModes];
    });
}

- (void)stop {
    if ([NSThread isMainThread]) {
        if (self.pollTimer != nil) {
            [self.pollTimer invalidate];
            self.pollTimer = nil;
        }
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.pollTimer != nil) {
                [self.pollTimer invalidate];
                self.pollTimer = nil;
            }
        });
    }
}

- (void)flushAndScheduleBackground {
    if (self.isTerminating) {
        return;
    }
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - self.lastFlushUnix < 0.35) {
        return;
    }
    self.lastFlushUnix = now;
    @try {
        [self pollForNotifRequest];
    } @catch (NSException *ex) {
        NSLog(@"[TVKNotif] flushAndScheduleBackground exception: %@", ex);
    }
}

- (void)clearAppBadge {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isTerminating) {
            return;
        }
        @try {
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            [center removeAllDeliveredNotifications];
            if (@available(iOS 16.0, *)) {
                [center setBadgeCount:0 withCompletionHandler:nil];
            } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
#pragma clang diagnostic pop
            }
        } @catch (NSException *ex) {
            NSLog(@"[TVKNotif] clearAppBadge exception: %@", ex);
        }
    });
}

- (void)handleRemoteDeviceToken:(NSData *)deviceToken {
    if (deviceToken.length == 0) {
        return;
    }
    const unsigned char *bytes = (const unsigned char *)deviceToken.bytes;
    NSMutableString *hex = [NSMutableString stringWithCapacity:deviceToken.length * 2];
    for (NSUInteger i = 0; i < deviceToken.length; i++) {
        [hex appendFormat:@"%02x", bytes[i]];
    }
    self.lastDeviceToken = [hex copy];
    [[NSUserDefaults standardUserDefaults] setObject:self.lastDeviceToken forKey:kTVKNotifDeviceTokenKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self publishCurrentStatus];
}

- (void)handleRemoteTokenError:(NSError *)error {
    NSLog(@"[TVKNotif] APNs registration note: %@", error);
}

- (void)publishCurrentStatus {
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        NSString *statusStr = @"not_determined";
        if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
            statusStr = @"authorized";
        } else if (@available(iOS 12.0, *)) {
            if (settings.authorizationStatus == UNAuthorizationStatusProvisional) {
                statusStr = @"provisional";
            } else if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
                statusStr = @"denied";
            }
        } else if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
            statusStr = @"denied";
        }
#ifdef DEBUG
        BOOL isSandbox = YES;
#else
        BOOL isSandbox = NO;
#endif
        NSDictionary *statusDict = @{
            @"auth_status": statusStr,
            @"device_token": self.lastDeviceToken ?: @"",
            @"sandbox": @(isSandbox)
        };
        dispatch_async(dispatch_get_main_queue(), ^{
            TVKWriteJsonDictToDirs(statusDict, self.activeNotifDir, kTVKNotifStatusFileName);
            if ([statusStr isEqualToString:@"authorized"] || [statusStr isEqualToString:@"provisional"]) {
                [[UIApplication sharedApplication] registerForRemoteNotifications];
            }
        });
    }];
}

- (void)pollForNotifRequest {
    self.scanTickCount += 1;
    BOOL deepScan = (self.scanTickCount == 1);
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *candDirs = TVKCandidateUserDirs(deepScan, @[kTVKReqFileName, kTVKIapReqFileName, kTVKNotifReqFileName]);
    for (NSString *dir in candDirs) {
        NSString *reqPath = [dir stringByAppendingPathComponent:kTVKNotifReqFileName];
        if (![fm fileExistsAtPath:reqPath]) {
            continue;
        }
        NSData *data = [NSData dataWithContentsOfFile:reqPath];
        [fm removeItemAtPath:reqPath error:nil];
        if (data.length == 0) {
            continue;
        }
        id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![parsed isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *req = (NSDictionary *)parsed;
        NSString *reqId = [req[@"req_id"] isKindOfClass:[NSString class]] ? req[@"req_id"] : @"";
        self.activeNotifDir = dir;

        for (NSString *otherDir in candDirs) {
            if ([otherDir isEqualToString:dir]) {
                continue;
            }
            NSString *otherPath = [otherDir stringByAppendingPathComponent:kTVKNotifReqFileName];
            if ([fm fileExistsAtPath:otherPath]) {
                NSData *odata = [NSData dataWithContentsOfFile:otherPath];
                id oparsed = odata.length > 0 ? [NSJSONSerialization JSONObjectWithData:odata options:0 error:nil] : nil;
                NSString *oreqId = ([oparsed isKindOfClass:[NSDictionary class]] && [oparsed[@"req_id"] isKindOfClass:[NSString class]]) ? oparsed[@"req_id"] : @"";
                if (reqId.length == 0 || oreqId.length == 0 || [oreqId isEqualToString:reqId]) {
                    [fm removeItemAtPath:otherPath error:nil];
                }
            }
        }

        NSString *action = [req[@"action"] isKindOfClass:[NSString class]] ? [req[@"action"] lowercaseString] : @"";
        if ([action isEqualToString:@"request_permission"]) {
            [self handleRequestPermission];
        } else if ([action isEqualToString:@"sync_local"]) {
            NSArray *items = [req[@"items"] isKindOfClass:[NSArray class]] ? req[@"items"] : @[];
            [self handleSyncLocalNotifications:items];
        } else if ([action isEqualToString:@"clear_all_local"]) {
            [self handleClearAllLocalNotifications];
        } else if ([action isEqualToString:@"clear_badge"]) {
            [self clearAppBadge];
        } else if ([action isEqualToString:@"configure_bg_fetch"]) {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSString *srv = [req[@"server_url"] isKindOfClass:[NSString class]] ? req[@"server_url"] : @"";
            NSString *tok = [req[@"auth_token"] isKindOfClass:[NSString class]] ? req[@"auth_token"] : @"";
            BOOL en = [req[@"enabled"] respondsToSelector:@selector(boolValue)] ? [req[@"enabled"] boolValue] : NO;
            [defaults setObject:srv forKey:kTVKNotifServerUrlKey];
            [defaults setObject:tok forKey:kTVKNotifAuthTokenKey];
            [defaults setBool:en forKey:kTVKNotifEnabledKey];
            [defaults synchronize];
        }
        return;
    }
}

- (void)handleRequestPermission {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    UNAuthorizationOptions opts = (UNAuthorizationOptions)(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge);
    [center requestAuthorizationWithOptions:opts
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (granted) {
                [[UIApplication sharedApplication] registerForRemoteNotifications];
            }
            [self publishCurrentStatus];
        });
    }];
}

- (void)handleClearAllLocalNotifications {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
        NSMutableArray<NSString *> *ids = [NSMutableArray array];
        for (UNNotificationRequest *r in requests) {
            if ([r.identifier hasPrefix:@"tvk_"]) {
                [ids addObject:r.identifier];
            }
        }
        if (ids.count > 0) {
            [center removePendingNotificationRequestsWithIdentifiers:ids];
        }
    }];
}

- (void)handleSyncLocalNotifications:(NSArray *)items {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        BOOL allowed = (settings.authorizationStatus == UNAuthorizationStatusAuthorized);
        if (@available(iOS 12.0, *)) {
            allowed = allowed || (settings.authorizationStatus == UNAuthorizationStatusProvisional);
        }
        if (!allowed) {
            return;
        }
        [center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
            NSMutableArray<NSString *> *oldIds = [NSMutableArray array];
            for (UNNotificationRequest *r in requests) {
                if ([r.identifier hasPrefix:@"tvk_build_"] || [r.identifier hasPrefix:@"tvk_atk_"] || [r.identifier hasPrefix:@"tvk_full_"]) {
                    [oldIds addObject:r.identifier];
                }
            }
            if (oldIds.count > 0) {
                [center removePendingNotificationRequestsWithIdentifiers:oldIds];
            }
            for (id obj in items) {
                if (![obj isKindOfClass:[NSDictionary class]]) {
                    continue;
                }
                NSDictionary *it = (NSDictionary *)obj;
                NSString *nid = [it[@"id"] isKindOfClass:[NSString class]] ? it[@"id"] : @"";
                NSString *title = [it[@"title"] isKindOfClass:[NSString class]] ? it[@"title"] : @"Baş Vezir";
                NSString *body = [it[@"body"] isKindOfClass:[NSString class]] ? it[@"body"] : @"";
                double delaySec = [it[@"delay_seconds"] respondsToSelector:@selector(doubleValue)] ? [it[@"delay_seconds"] doubleValue] : 0.0;
                if (nid.length == 0 || body.length == 0 || delaySec < 1.0) {
                    continue;
                }
                NSString *route = [it[@"route"] isKindOfClass:[NSString class]] ? it[@"route"] : @"village";
                NSString *ntype = [it[@"type"] isKindOfClass:[NSString class]] ? it[@"type"] : @"local";
                NSNumber *vidNum = [it[@"village_id"] respondsToSelector:@selector(integerValue)] ? @([it[@"village_id"] integerValue]) : @(-1);

                UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
                content.title = title;
                content.body = body;
                content.sound = [UNNotificationSound defaultSound];
                content.badge = @1;
                content.userInfo = @{
                    @"route": route,
                    @"type": ntype,
                    @"village_id": vidNum
                };
                UNTimeIntervalNotificationTrigger *trig = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:delaySec repeats:NO];
                UNNotificationRequest *nreq = [UNNotificationRequest requestWithIdentifier:nid content:content trigger:trig];
                [center addNotificationRequest:nreq withCompletionHandler:nil];
            }
        }];
    }];
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
            completionHandler((UNNotificationPresentationOptions)0);
            return;
        }
        if (@available(iOS 14.0, *)) {
            completionHandler((UNNotificationPresentationOptions)(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionBadge));
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            completionHandler((UNNotificationPresentationOptions)(UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionBadge));
#pragma clang diagnostic pop
        }
    });
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler {
    NSDictionary *uinfo = response.notification.request.content.userInfo ?: @{};
    NSString *route = [uinfo[@"route"] isKindOfClass:[NSString class]] ? uinfo[@"route"] : @"village";
    NSString *ntype = [uinfo[@"type"] isKindOfClass:[NSString class]] ? uinfo[@"type"] : @"";
    NSNumber *vidNum = [uinfo[@"village_id"] respondsToSelector:@selector(integerValue)] ? @([uinfo[@"village_id"] integerValue]) : @(-1);
    NSDictionary *opened = @{
        @"route": route,
        @"type": ntype,
        @"village_id": vidNum,
        @"opened_unix": @((long)[[NSDate date] timeIntervalSince1970])
    };
    dispatch_async(dispatch_get_main_queue(), ^{
        [self clearAppBadge];
        TVKWriteJsonDictToDirs(opened, self.activeNotifDir, kTVKNotifOpenedFileName);
        completionHandler();
    });
}

@end
