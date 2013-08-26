

#ifndef TRACKER_DEBUG
#define TRACKER_DEBUG 0
#endif


#if TRACKER_DEBUG
#   define TRACKER_LOG(fmt, ...) NSLog(fmt, ##__VA_ARGS__)
#else
#   define TRACKER_LOG(...)
#endif



#import "Tracker.h"
#import "Tracker_OpenUDID.h"
#import <UIKit/UIKit.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import "TrackerDB.h"

#include <sys/types.h>
#include <sys/sysctl.h>


/// Utilities for encoding and decoding URL arguments.
/// This code is from the project google-toolbox-for-mac
@interface NSString (GTMNSStringURLArgumentsAdditions)

/// Returns a string that is escaped properly to be a URL argument.
//
/// This differs from stringByAddingPercentEscapesUsingEncoding: in that it
/// will escape all the reserved characters (per RFC 3986
/// <http://www.ietf.org/rfc/rfc3986.txt>) which
/// stringByAddingPercentEscapesUsingEncoding would leave.
///
/// This will also escape '%', so this should not be used on a string that has
/// already been escaped unless double-escaping is the desired result.
- (NSString*)gtm_stringByEscapingForURLArgument;

/// Returns the unescaped version of a URL argument
//
/// This has the same behavior as stringByReplacingPercentEscapesUsingEncoding:,
/// except that it will also convert '+' to space.
- (NSString*)gtm_stringByUnescapingFromURLArgument;

@end

#define GTMNSMakeCollectable(cf) ((id)(cf))
#define GTMCFAutorelease(cf) ([GTMNSMakeCollectable(cf) autorelease])

@implementation NSString (GTMNSStringURLArgumentsAdditions)

- (NSString*)gtm_stringByEscapingForURLArgument {
	// Encode all the reserved characters, per RFC 3986
	// (<http://www.ietf.org/rfc/rfc3986.txt>)
	CFStringRef escaped =
    CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                            (CFStringRef)self,
                                            NULL,
                                            (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                            kCFStringEncodingUTF8);
	return GTMCFAutorelease(escaped);
}

- (NSString*)gtm_stringByUnescapingFromURLArgument {
	NSMutableString *resultString = [NSMutableString stringWithString:self];
	[resultString replaceOccurrencesOfString:@"+"
								  withString:@" "
									 options:NSLiteralSearch
									   range:NSMakeRange(0, [resultString length])];
	return [resultString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

@end


@interface DeviceInfo : NSObject
{
}
@end

@implementation DeviceInfo

+ (NSString *)udid
{
	return [Tracker_OpenUDID value];
}

+ (NSString *)device
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    return platform;
}

+ (NSString *)osVersion
{
	return [[UIDevice currentDevice] systemVersion];
}

+ (NSString *)carrier
{
	if (NSClassFromString(@"CTTelephonyNetworkInfo"))
	{
		CTTelephonyNetworkInfo *netinfo = [[[CTTelephonyNetworkInfo alloc] init] autorelease];
		CTCarrier *carrier = [netinfo subscriberCellularProvider];
		return [carrier carrierName];
	}
    
	return nil;
}

+ (NSString *)resolution
{
	CGRect bounds = [[UIScreen mainScreen] bounds];
	CGFloat scale = [[UIScreen mainScreen] respondsToSelector:@selector(scale)] ? [[UIScreen mainScreen] scale] : 1.f;
	CGSize res = CGSizeMake(bounds.size.width * scale, bounds.size.height * scale);
	NSString *result = [NSString stringWithFormat:@"%gx%g", res.width, res.height];
    
	return result;
}

+ (NSString *)locale
{
	return [[NSLocale currentLocale] localeIdentifier];
}

+ (NSString *)appVersion
{
    NSString *result = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if ([result length] == 0)
        result = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey];
    
    return result;
}

+ (NSString *)metrics
{
	NSString *result = @"{";
    
	result = [result stringByAppendingFormat:@"\"%@\":\"%@\"", @"_device", [DeviceInfo device]];
    
	result = [result stringByAppendingFormat:@",\"%@\":\"%@\"", @"_os", @"iOS"];
    
	result = [result stringByAppendingFormat:@",\"%@\":\"%@\"", @"_os_version", [DeviceInfo osVersion]];
    
	NSString *carrier = [DeviceInfo carrier];
	if (carrier != nil)
		result = [result stringByAppendingFormat:@",\"%@\":\"%@\"", @"_carrier", carrier];
    
	result = [result stringByAppendingFormat:@",\"%@\":\"%@\"", @"_resolution", [DeviceInfo resolution]];
    
	result = [result stringByAppendingFormat:@",\"%@\":\"%@\"", @"_locale", [DeviceInfo locale]];
    
	result = [result stringByAppendingFormat:@",\"%@\":\"%@\"", @"_app_version", [DeviceInfo appVersion]];
    
	result = [result stringByAppendingString:@"}"];
    
	result = [result gtm_stringByEscapingForURLArgument];
    
	return result;
}

@end


@interface Log : NSObject
{
}

@property (nonatomic, copy) NSString *type;
@property (nonatomic, retain) NSDictionary *data;
@property (nonatomic, assign) double timestamp;
@end


@implementation Log

@synthesize type = type_;
@synthesize data = data_;
@synthesize timestamp = timestamp_;

- (id)init
{
    if (self = [super init])
    {
        type_ = nil;
        data_ = nil;
        timestamp_ = 0;
    }
    return self;
}

- (void)dealloc
{
    [type_ release];
    [data_ release];
    [super dealloc];
}

@end

@interface LogQueue : NSObject
@end

@implementation LogQueue

- (void)dealloc
{
    [super dealloc];
}

- (NSUInteger)count
{
    @synchronized (self)
    {
        return [[TrackerDB sharedInstance] getLogCount];
    }
}

-(Log*) convertNSManagedObjectToLog:(NSManagedObject*)managedObject{
    Log* log = [[Log alloc] init];
    
    log.type = [managedObject valueForKey:@"type"];
    if ([managedObject valueForKey:@"data"])
        log.data = [managedObject valueForKey:@"data"];
    
    if ([managedObject valueForKey:@"timestamp"])
        log.timestamp = ((NSNumber *)[managedObject valueForKey:@"timestamp"]).doubleValue;
    
    return log;
}

- (NSString *)logs
{
    NSString *result = @"[";
    
    @synchronized (self)
    {
        NSArray* logs = [[[TrackerDB sharedInstance] getLogs] copy];
        for (NSUInteger i = 0; i < logs.count; ++i)
        {
            
            Log *log = [self convertNSManagedObjectToLog:[logs objectAtIndex:i]];
            
            result = [result stringByAppendingString:@"{"];
            
            result = [result stringByAppendingFormat:@"\"%@\":\"%@\"", @"@type", log.type];
            
            if (log.data)
            {
                NSString *data = @"{";
                
                NSArray *keys = [log.data allKeys];
                for (NSUInteger i = 0; i < keys.count; ++i)
                {
                    NSString *key = [keys objectAtIndex:i];
                    NSString *value = [log.data objectForKey:key];
                    
                    data = [data stringByAppendingFormat:@"\"%@\":\"%@\"", key, value];
                    
                    if (i + 1 < keys.count)
                        data = [data stringByAppendingString:@","];
                }
                data = [data stringByAppendingString:@"}"];
                
                result = [result stringByAppendingFormat:@",\"%@\":%@", @"@fields",data];
            }
            
             result = [result stringByAppendingFormat:@",\"%@\":%ld", @"@timestamp", (time_t)log.timestamp];
         
            
            result = [result stringByAppendingString:@"}"];
            
            if (i + 1 < logs.count)
                result = [result stringByAppendingString:@","];
            
            [[TrackerDB sharedInstance] removeFromQueue:[logs objectAtIndex:i]];
            
        }
        
        [logs release];
        
    }
    
    result = [result stringByAppendingString:@"]"];
    
    result = [result gtm_stringByEscapingForURLArgument];
    
	return result;
}



- (void)record:(NSString *)type withData:(NSDictionary *)data;
{
    @synchronized (self)
    {
        
        Log *log = [[Log alloc] init];
        log.type = type;
        log.data = data;
        
        [[TrackerDB sharedInstance] createLog:type withData:data];
        [log release];
    }
}


@end

@interface ConnectionQueue : NSObject
{
	NSURLConnection *connection_;
	UIBackgroundTaskIdentifier bgTask_;
	NSString *appKey;
	NSString *appHost;
}

@property (nonatomic, copy) NSString *appKey;
@property (nonatomic, copy) NSString *appHost;

@end

static ConnectionQueue *s_sharedConnectionQueue = nil;

@implementation ConnectionQueue : NSObject

@synthesize appKey;
@synthesize appHost;

+ (ConnectionQueue *)sharedInstance
{
	if (s_sharedConnectionQueue == nil)
		s_sharedConnectionQueue = [[ConnectionQueue alloc] init];
    
	return s_sharedConnectionQueue;
}

- (id)init
{
	if (self = [super init])
	{
		connection_ = nil;
        bgTask_ = UIBackgroundTaskInvalid;
        appKey = nil;
        appHost = nil;
	}
	return self;
}

- (void) tick
{
    NSArray* dataQueue = [[[TrackerDB sharedInstance] getQueue] copy];
    
    if (connection_ != nil || bgTask_ != UIBackgroundTaskInvalid || [dataQueue count] == 0)
        return;
    
    UIApplication *app = [UIApplication sharedApplication];
    bgTask_ = [app beginBackgroundTaskWithExpirationHandler:^{
		[app endBackgroundTask:bgTask_];
		bgTask_ = UIBackgroundTaskInvalid;
    }];
    
    NSString *data = [[dataQueue objectAtIndex:0] valueForKey:@"post"];
    NSString *urlString = [NSString stringWithFormat:@"%@/i?%@", self.appHost, data];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    connection_ = [NSURLConnection connectionWithRequest:request delegate:self];
    
    [dataQueue release];
}

- (void)beginSession
{
	NSString *data = [NSString stringWithFormat:@"app_key=%@&device_id=%@&timestamp=%ld&sdk_version=1&begin_session=1&metrics=%@",
					  appKey,
					  [DeviceInfo udid],
					  time(NULL),
					  [DeviceInfo metrics]];
    
    [[TrackerDB sharedInstance] addToQueue:data];
    
	[self tick];
}

- (void)updateSessionWithDuration:(int)duration
{
	NSString *data = [NSString stringWithFormat:@"app_key=%@&device_id=%@&timestamp=%ld&session_duration=%d",
					  appKey,
					  [DeviceInfo udid],
					  time(NULL),
					  duration];
    
    [[TrackerDB sharedInstance] addToQueue:data];
    
	[self tick];
}

- (void)endSessionWithDuration:(int)duration
{
	NSString *data = [NSString stringWithFormat:@"app_key=%@&device_id=%@&timestamp=%ld&end_session=1&session_duration=%d",
					  appKey,
					  [DeviceInfo udid],
					  time(NULL),
					  duration];
    
    [[TrackerDB sharedInstance] addToQueue:data];
    
	[self tick];
}

- (void)recordLogs: (NSString *)logs
{
    NSString *data = [NSString stringWithFormat:@"logs=%@", logs];
    [[TrackerDB sharedInstance] addToQueue:data];
    
    [self tick];
}



- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    
    NSArray* dataQueue = [[[TrackerDB sharedInstance] getQueue] copy];
    
	TRACKER_LOG(@"ok -> %@", [dataQueue objectAtIndex:0]);
    
    UIApplication *app = [UIApplication sharedApplication];
    if (bgTask_ != UIBackgroundTaskInvalid)
    {
        [app endBackgroundTask:bgTask_];
        bgTask_ = UIBackgroundTaskInvalid;
    }
    
    connection_ = nil;
    
    [[TrackerDB sharedInstance] removeFromQueue:[dataQueue objectAtIndex:0]];
    
    [dataQueue release];
    
    [self tick];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)err
{
    #if TRACKER_DEBUG
        NSArray* dataQueue = [[[TrackerDB sharedInstance] getQueue] copy];
        TRACKER_LOG(@"error -> %@: %@", [dataQueue objectAtIndex:0], err);
    #endif
    
    UIApplication *app = [UIApplication sharedApplication];
    if (bgTask_ != UIBackgroundTaskInvalid)
    {
        [app endBackgroundTask:bgTask_];
        bgTask_ = UIBackgroundTaskInvalid;
    }
    
    connection_ = nil;
}



- (void)dealloc
{
	[super dealloc];
	
	if (connection_)
		[connection_ cancel];
	
	self.appKey = nil;
	self.appHost = nil;
}

@end

static Tracker *s_sharedTracker = nil;

@implementation Tracker

+ (Tracker *)sharedInstance
{
	if (s_sharedTracker == nil)
		s_sharedTracker = [[Tracker alloc] init];
    
	return s_sharedTracker;
}

- (id)init
{
	if (self = [super init])
	{
		timer = nil;
		isSuspended = NO;
		unsentSessionLength = 0;
        logQueue = [[LogQueue alloc] init];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(didEnterBackgroundCallBack:)
													 name:UIApplicationDidEnterBackgroundNotification
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(willEnterForegroundCallBack:)
													 name:UIApplicationWillEnterForegroundNotification
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(willTerminateCallBack:)
													 name:UIApplicationWillTerminateNotification
												   object:nil];
	}
	return self;
}

- (void)startWithHost:(NSString *)appHost
{
	timer = [NSTimer scheduledTimerWithTimeInterval:60.0
											 target:self
										   selector:@selector(onTimer:)
										   userInfo:nil
											repeats:YES];
	lastTime = CFAbsoluteTimeGetCurrent();
	[[ConnectionQueue sharedInstance] setAppKey:@""];
	[[ConnectionQueue sharedInstance] setAppHost:appHost];
	[[ConnectionQueue sharedInstance] beginSession];
}

- (void)log:(NSString *)type withData:(NSDictionary *)data {
    [logQueue record:type withData:data];
    
    if (logQueue.count >= 10)
        [[ConnectionQueue sharedInstance] recordLogs:[logQueue logs]];
}


- (void)onTimer:(NSTimer *)timer
{
	if (isSuspended == YES)
		return;
    
	double currTime = CFAbsoluteTimeGetCurrent();
	unsentSessionLength += currTime - lastTime;
	lastTime = currTime;
    
	int duration = unsentSessionLength;
	[[ConnectionQueue sharedInstance] updateSessionWithDuration:duration];
	unsentSessionLength -= duration;
    
    
    if (logQueue.count > 0)
        [[ConnectionQueue sharedInstance] recordLogs:[logQueue logs]];
}

- (void)suspend
{
	isSuspended = YES;
        
    if (logQueue.count > 0)
        [[ConnectionQueue sharedInstance] recordLogs:[logQueue logs]];
    
	double currTime = CFAbsoluteTimeGetCurrent();
	unsentSessionLength += currTime - lastTime;
    
	int duration = unsentSessionLength;
	[[ConnectionQueue sharedInstance] endSessionWithDuration:duration];
	unsentSessionLength -= duration;
}

- (void)resume
{
	lastTime = CFAbsoluteTimeGetCurrent();
    
	[[ConnectionQueue sharedInstance] beginSession];
    
	isSuspended = NO;
}

- (void)exit
{
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
	
	if (timer)
    {
        [timer invalidate];
        timer = nil;
    }
    
    [eventQueue release];
    [logQueue release];
	
	[super dealloc];
}

- (void)didEnterBackgroundCallBack:(NSNotification *)notification
{
	TRACKER_LOG(@"Tracker didEnterBackgroundCallBack");
	[self suspend];
    
}

- (void)willEnterForegroundCallBack:(NSNotification *)notification
{
	TRACKER_LOG(@"Tracker willEnterForegroundCallBack");
	[self resume];
}

- (void)willTerminateCallBack:(NSNotification *)notification
{
	TRACKER_LOG(@"Tracker willTerminateCallBack");
    [[TrackerDB sharedInstance] saveContext];
	[self exit];
}

@end
