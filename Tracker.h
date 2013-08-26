#import <Foundation/Foundation.h>

@class EventQueue;
@class LogQueue;

@interface Tracker : NSObject {
	double unsentSessionLength;
	NSTimer *timer;
	double lastTime;
	BOOL isSuspended;
    EventQueue *eventQueue;
    LogQueue *logQueue;
}

+ (Tracker *)sharedInstance;

- (void)startWithHost:(NSString *)appHost;

- (void)recordEvent:(NSString *)key count:(int)count;

- (void)recordEvent:(NSString *)key count:(int)count sum:(double)sum;

- (void)recordEvent:(NSString *)key segmentation:(NSDictionary *)segmentation count:(int)count;

- (void)recordEvent:(NSString *)key segmentation:(NSDictionary *)segmentation count:(int)count sum:(double)sum;

- (void)log:(NSString *)type withData:(NSDictionary *)data;

@end


