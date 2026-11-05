#import "DiscordBridge.h"

#if __has_include("discordpp.h")
  #define DISCORDPP_IMPLEMENTATION
  #include "discordpp.h"
  #define HAS_DISCORD_SDK 1
#elif __has_include(<discord_partner_sdk/discordpp.h>)
  #define DISCORDPP_IMPLEMENTATION
  #include <discord_partner_sdk/discordpp.h>
  #define HAS_DISCORD_SDK 1
#else
  #define HAS_DISCORD_SDK 0
#endif

#if HAS_DISCORD_SDK
// NOTE: written against the Discord Social SDK C++ API (discordpp). If a call below does not
// match the headers of the SDK version you downloaded, adjust it here; this is the only file
// that touches the SDK.
@implementation DiscordBridge {
    std::shared_ptr<discordpp::Client> _client;
    uint64_t _appId;
}

+ (BOOL)sdkAvailable { return YES; }

- (instancetype)initWithClientId:(NSString *)clientId {
    if ((self = [super init])) {
        _appId = strtoull(clientId.UTF8String, NULL, 10);
        _client = std::make_shared<discordpp::Client>();
        _client->SetApplicationId(_appId);
        __weak DiscordBridge *weakSelf = self;
        _client->SetStatusChangedCallback([weakSelf](discordpp::Client::Status s, discordpp::Client::Error, int32_t) {
            NSString *str = [NSString stringWithUTF8String:discordpp::Client::StatusToString(s).c_str()];
            dispatch_async(dispatch_get_main_queue(), ^{ if (weakSelf.onStatus) weakSelf.onStatus(str); });
        });
    }
    return self;
}

- (void)authorize:(DiscordAuthCompletion)completion {
    auto client = _client;
    uint64_t appId = _appId;
    auto verifier = client->CreateAuthorizationCodeVerifier();
    discordpp::AuthorizationArgs args{};
    args.SetClientId(appId);
    args.SetScopes(discordpp::Client::GetDefaultPresenceScopes());
    args.SetCodeChallenge(verifier.Challenge());
    DiscordAuthCompletion done = [completion copy];
    client->Authorize(args, [client, appId, verifier, done](discordpp::ClientResult result, std::string code, std::string redirectUri) {
        if (!result.Successful()) {
            NSString *e = [NSString stringWithUTF8String:result.Error().c_str()];
            dispatch_async(dispatch_get_main_queue(), ^{ done(nil, nil, e); });
            return;
        }
        client->GetToken(appId, code, verifier.Verifier(), redirectUri,
            [done](discordpp::ClientResult r, std::string access, std::string refresh, discordpp::AuthorizationTokenType, int32_t, std::string) {
                NSString *a = r.Successful() ? [NSString stringWithUTF8String:access.c_str()] : nil;
                NSString *rf = r.Successful() ? [NSString stringWithUTF8String:refresh.c_str()] : nil;
                NSString *e = r.Successful() ? nil : [NSString stringWithUTF8String:r.Error().c_str()];
                dispatch_async(dispatch_get_main_queue(), ^{ done(a, rf, e); });
            });
    });
}

- (void)refreshWithToken:(NSString *)refreshToken completion:(DiscordAuthCompletion)completion {
    DiscordAuthCompletion done = [completion copy];
    _client->RefreshToken(_appId, std::string(refreshToken.UTF8String),
        [done](discordpp::ClientResult r, std::string access, std::string refresh, discordpp::AuthorizationTokenType, int32_t, std::string) {
            NSString *a = r.Successful() ? [NSString stringWithUTF8String:access.c_str()] : nil;
            NSString *rf = r.Successful() ? [NSString stringWithUTF8String:refresh.c_str()] : nil;
            NSString *e = r.Successful() ? nil : [NSString stringWithUTF8String:r.Error().c_str()];
            dispatch_async(dispatch_get_main_queue(), ^{ done(a, rf, e); });
        });
}

- (void)connectWithAccessToken:(NSString *)accessToken {
    auto client = _client;
    client->UpdateToken(discordpp::AuthorizationTokenType::Bearer, std::string(accessToken.UTF8String),
        [client](discordpp::ClientResult r) { if (r.Successful()) client->Connect(); });
}

- (void)setActivity:(NSDictionary *)d {
    discordpp::Activity activity;
    activity.SetType((discordpp::ActivityTypes)[d[@"type"] intValue]);
    if (d[@"details"]) activity.SetDetails(std::string([d[@"details"] UTF8String]));
    if (d[@"state"]) activity.SetState(std::string([d[@"state"] UTF8String]));

    discordpp::ActivityAssets assets;
    if (d[@"largeImage"]) assets.SetLargeImage(std::string([d[@"largeImage"] UTF8String]));
    if (d[@"largeText"]) assets.SetLargeText(std::string([d[@"largeText"] UTF8String]));
    if (d[@"smallImage"]) assets.SetSmallImage(std::string([d[@"smallImage"] UTF8String]));
    if (d[@"smallText"]) assets.SetSmallText(std::string([d[@"smallText"] UTF8String]));
    activity.SetAssets(assets);

    if (d[@"start"]) {
        discordpp::ActivityTimestamps ts;
        ts.SetStart([d[@"start"] unsignedLongLongValue]);
        if (d[@"end"]) ts.SetEnd([d[@"end"] unsignedLongLongValue]);
        activity.SetTimestamps(ts);
    }
    if (d[@"buttonLabel"] && d[@"buttonUrl"]) {
        discordpp::ActivityButton b;
        b.SetLabel(std::string([d[@"buttonLabel"] UTF8String]));
        b.SetUrl(std::string([d[@"buttonUrl"] UTF8String]));
        activity.AddButton(b);
    }
    _client->UpdateRichPresence(activity, [](discordpp::ClientResult) {});
}

- (void)clearActivity { _client->ClearRichPresence(); }
- (void)runCallbacks { discordpp::RunCallbacks(); }
@end

#else  // ---- SDK not linked: harmless stubs so the project still builds ----
@implementation DiscordBridge
+ (BOOL)sdkAvailable { return NO; }
- (instancetype)initWithClientId:(NSString *)clientId { return [super init]; }
- (void)authorize:(DiscordAuthCompletion)c { c(nil, nil, @"Discord Social SDK was not linked into this build."); }
- (void)refreshWithToken:(NSString *)t completion:(DiscordAuthCompletion)c { c(nil, nil, @"Discord Social SDK was not linked into this build."); }
- (void)connectWithAccessToken:(NSString *)t {}
- (void)setActivity:(NSDictionary *)a {}
- (void)clearActivity {}
- (void)runCallbacks {}
@end
#endif
