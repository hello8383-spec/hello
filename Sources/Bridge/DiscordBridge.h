#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

typedef void (^DiscordAuthCompletion)(NSString *_Nullable access, NSString *_Nullable refresh, NSString *_Nullable error);

/// Thin Objective-C++ wrapper around the Discord Social SDK (C++).
/// Without the SDK linked, every method is a safe no-op and +sdkAvailable is NO.
@interface DiscordBridge : NSObject
@property(class, readonly) BOOL sdkAvailable;
@property(nonatomic, copy, nullable) void (^onStatus)(NSString *status);

- (instancetype)initWithClientId:(NSString *)clientId;
- (void)authorize:(DiscordAuthCompletion)completion;
- (void)refreshWithToken:(NSString *)refreshToken completion:(DiscordAuthCompletion)completion;
- (void)connectWithAccessToken:(NSString *)accessToken;
/// Keys: type(NSNumber), details, state, largeImage, largeText, smallImage, smallText,
/// start(NSNumber, unix s), end(NSNumber), buttonLabel, buttonUrl
- (void)setActivity:(NSDictionary *)activity;
- (void)clearActivity;
- (void)runCallbacks;
@end
NS_ASSUME_NONNULL_END
