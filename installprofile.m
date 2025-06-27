// Simple tool to install a mobileconfig file.

#ifndef INTERFACES_H
#define INTERFACES_H

#import <Foundation/Foundation.h>

@interface CPProfile : NSObject <NSSecureCoding>
- (id)initWithData:(id)arg1 error:(id *)arg2;
- (void)setUserData:(id)arg1 forKey:(id)arg2;
@property(readonly) id dictionaryForArchiver;
@end

@interface CPProfileManager : NSObject
+ (id)sharedProfileManager;
- (id)installProfile:(id)arg1 forUser:(id)arg2;
@end


#endif // INTERFACES_H

#include <stdio.h>

int main() {
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    if ([arguments count] != 2) {
        NSLog(@"Usage: %@ <file>", [arguments objectAtIndex:0]);
        return 1;
    }

    NSString *path = [arguments objectAtIndex:1];
    CPProfileManager *mgr = [CPProfileManager sharedProfileManager];
    if (mgr == nil) {
        NSLog(@"Failed to get shared CPProfileManager.");
        return 1;
    }

    NSError *error = nil;
    NSData *profileData = [NSData dataWithContentsOfFile:path options:0 error:&error];
    if (error) {
        NSLog(@" error => %@ ", error);
        return 1;
    }

    CPProfile *profile = [[CPProfile alloc] initWithData:profileData error:&error];
    if (error) {
        NSLog(@" error => %@ ", error);
        return 1;
    }

    [profile setUserData:@"MDM" forKey:@"ManagedSource"];
    [profile setUserData:@{
        @"MDMUserApproved": @YES
    } forKey:@"SPIOverrides"];

    NSLog(@" profile => %@ ", [profile dictionaryForArchiver]);
    error = [mgr installProfile:profile forUser:nil];
    if (error) {
        NSLog(@" error => %@ ", error);
        return 1;
    }
}
