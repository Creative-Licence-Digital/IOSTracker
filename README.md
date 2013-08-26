How to add it to your project : 

- Copy the files into your project
- Add a compilation flag for those files -fno-objc-arc

In your AppDelegate.m, include "Tracker.h" 
And add this line : 

[[Tracker sharedInstance] startWithHost:@"http://YOUR-LOG-SERVER-INSTANCE-HERE"];


To log things, you need to call the log method 
For example : 

NSDictionary * data = [NSDictionary dictionaryWithObjectsAndKeys:@"test", @"toto", nil];
[[Tracker sharedInstance] log:@"document" withData:data];
