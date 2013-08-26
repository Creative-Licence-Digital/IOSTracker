#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface TrackerDB : NSObject

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

+(TrackerDB*) sharedInstance;

-(void)createLog:(NSString*)type withData:(NSDictionary*)data;


-(void)addToQueue:(NSString*)postData;
-(void)removeFromQueue:(NSManagedObject*)postDataObj;
-(NSArray*) getLogs;
-(NSArray*) getQueue;
-(NSUInteger)getLogCount;
-(NSUInteger)getQueueCount;
- (void)saveContext;

@end
