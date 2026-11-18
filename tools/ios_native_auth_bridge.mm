// ios_native_auth_bridge.mm
// Native iOS Sign in with Apple (ASAuthorizationController + Face ID),
// and In-App WKWebView OAuth bridge for Taht ve Kilic (Godot 4.7 iOS export).

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <WebKit/WebKit.h>
#if __has_include(<AuthenticationServices/AuthenticationServices.h>)
#import <AuthenticationServices/AuthenticationServices.h>
#define TVK_HAS_AUTH_SERVICES 1
#else
#define TVK_HAS_AUTH_SERVICES 0
#endif

static NSString *const kTVKReqFileName = @"native_auth_req.json";
static NSString *const kTVKResFileName = @"native_auth_res.json";
static NSString *const kTVKAckFileName = @"native_auth_ack.json";
static NSString *const kTVKAppleNamePrefix = @"tvk_apple_name_";
static NSString *const kTVKAppleEmailPrefix = @"tvk_apple_email_";

@interface TVKNativeAuthBridge : NSObject <
    WKNavigationDelegate,
    UIAdaptivePresentationControllerDelegate
#if TVK_HAS_AUTH_SERVICES
    , ASAuthorizationControllerDelegate
    , ASAuthorizationControllerPresentationContextProviding
#endif
>
@property (nonatomic, strong) NSTimer *pollTimer;
@property (nonatomic, copy) NSString *activeReqId;
@property (nonatomic, copy) NSString *activeProvider;
@property (nonatomic, copy) NSString *activeOAuthUrl;
@property (nonatomic, copy) NSString *activeDir;
@property (nonatomic, assign) BOOL isBusy;
@property (nonatomic, assign) NSUInteger scanTickCount;
@property (nonatomic, strong) UIViewController *presentedNav;
@property (nonatomic, strong) UIActivityIndicatorView *loadingSpinner;
#if TVK_HAS_AUTH_SERVICES
@property (nonatomic, strong) id appleController;
#endif
+ (instancetype)shared;
- (void)cleanupStaleFiles;
- (void)startWatcher;
@end

static TVKNativeAuthBridge *gBridge = nil;

extern "C" void tvk_ios_auth_bridge_init(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[TVKNativeAuthBridge shared] cleanupStaleFiles];
        [[TVKNativeAuthBridge shared] startWatcher];
    });
}

@implementation TVKNativeAuthBridge

+ (void)load {
    @autoreleasepool {
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            [[TVKNativeAuthBridge shared] cleanupStaleFiles];
            [[TVKNativeAuthBridge shared] startWatcher];
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            [[TVKNativeAuthBridge shared] startWatcher];
        }];
        if (@available(iOS 13.0, *)) {
            [[NSNotificationCenter defaultCenter] addObserverForName:UISceneDidActivateNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                [[TVKNativeAuthBridge shared] startWatcher];
            }];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[TVKNativeAuthBridge shared] cleanupStaleFiles];
            [[TVKNativeAuthBridge shared] startWatcher];
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

    if (deepScan) {
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *baseRoot in @[docs ?: @"", appSup ?: @""]) {
            if (baseRoot.length == 0) {
                continue;
            }
            NSDirectoryEnumerator *en = [fm enumeratorAtPath:baseRoot];
            NSString *rel = nil;
            while ((rel = [en nextObject]) != nil) {
                if ([[rel lastPathComponent] isEqualToString:kTVKReqFileName]) {
                    addDir([baseRoot stringByAppendingPathComponent:[rel stringByDeletingLastPathComponent]]);
                }
            }
        }
    }

    return dirs;
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
        self.pollTimer = [NSTimer scheduledTimerWithTimeInterval:0.15
                                                          target:self
                                                        selector:@selector(pollForRequest)
                                                        userInfo:nil
                                                         repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.pollTimer forMode:NSRunLoopCommonModes];
    });
}

- (UIWindow *)activeKeyWindow {
    if (@available(iOS 13.0, *)) {
        UIWindow *fallbackWindow = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] &&
                scene.activationState == UISceneActivationStateForegroundActive) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    if (w.rootViewController != nil && w.isKeyWindow) {
                        return w;
                    }
                    if (w.rootViewController != nil && fallbackWindow == nil) {
                        fallbackWindow = w;
                    }
                }
            }
        }
        if (fallbackWindow != nil) {
            return fallbackWindow;
        }
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    if (w.rootViewController != nil) {
                        return w;
                    }
                }
            }
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIWindow *kw = [UIApplication sharedApplication].keyWindow;
    if (kw != nil && kw.rootViewController != nil) {
        return kw;
    }
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.rootViewController != nil) {
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
    NSError *err = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&err];
    if (json == nil || err != nil) {
        return;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableSet<NSString *> *targets = [NSMutableSet set];
    if (self.activeDir.length > 0) {
        [targets addObject:self.activeDir];
    }
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    if (docs.length > 0) {
        [targets addObject:docs];
    }
    for (NSString *dir in targets) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        [json writeToFile:[dir stringByAppendingPathComponent:fileName] atomically:YES];
    }
}

- (void)writeResultDict:(NSDictionary *)payload {
    [self writeJsonDict:payload fileName:kTVKResFileName];
    self.isBusy = NO;
    self.appleController = nil;
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
    if (self.isBusy) {
        return;
    }
    self.scanTickCount += 1;
    BOOL deepScan = (self.scanTickCount == 1 || (self.scanTickCount % 3) == 0);
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *dir in [self candidateUserDirsWithDeepScan:deepScan]) {
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
            self.activeDir = dir;
            self.activeReqId = [req[@"req_id"] isKindOfClass:[NSString class]] ? req[@"req_id"] : @"";
            self.activeProvider = [req[@"provider"] isKindOfClass:[NSString class]] ? [req[@"provider"] lowercaseString] : @"apple";
            self.activeOAuthUrl = [req[@"oauth_url"] isKindOfClass:[NSString class]] ? req[@"oauth_url"] : @"https://tahtkilic.vercel.app/api/auth/oauth_page";

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
            NSURL *url = [NSURL URLWithString:self.activeOAuthUrl];
            if (url != nil) {
                [self presentEmbeddedWKWebView:url provider:self.activeProvider];
            } else {
                [self finishError:@"Gecersiz OAuth URL." cancelled:NO];
            }
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

        NSString *email = cred.email;
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

        NSString *idTok = @"";
        if (cred.identityToken != nil) {
            NSString *utf8Tok = [[NSString alloc] initWithData:cred.identityToken encoding:NSUTF8StringEncoding];
            idTok = utf8Tok ?: [cred.identityToken base64EncodedStringWithOptions:0];
        }

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
