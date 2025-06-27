// Simple tool to install a mobileconfig file.

#ifndef INTERFACES_H
#define INTERFACES_H

#import <Foundation/Foundation.h>
#include "libproc.h"

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

int usage(NSArray *args) {
    NSLog(@"Usage: %@ <file>", [args objectAtIndex:0]);
    return 1;
}

int runAsService(NSString *path) {
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
    NSLog(@"Successfully installed profile");
    return 0;
}

bool installProfileServiceIsUp() {
    int numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    pid_t pids[numberOfProcesses];
    bzero(pids, numberOfProcesses);
    proc_listpids(PROC_ALL_PIDS, 0, pids, sizeof(pids));
    for (int i = 0; i < numberOfProcesses; ++i) {
        if (pids[i] == 0) { continue; }
        if (pids[i] == getpid()) { continue; }
        char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
        bzero(pathBuffer, PROC_PIDPATHINFO_MAXSIZE);
        proc_pidpath(pids[i], pathBuffer, sizeof(pathBuffer));

        NSString *path = [NSString stringWithUTF8String:pathBuffer];
        NSString *currentExecutable = [[NSBundle mainBundle] executablePath];
        if ([[path lastPathComponent] isEqualTo:[currentExecutable lastPathComponent]]) {
            return true;
        }
    }
    return false;
}

int createAndWaitService(NSString *path) {
    NSString *currentExecutable = [[NSBundle mainBundle] executablePath];
    NSDictionary *service = @{
        @"Label": @"installprofile",
        @"ProgramArguments": @[currentExecutable, @"-s", path],
        @"RunAtLoad": @NO,
        @"WorkingDirectory": [[NSFileManager defaultManager] currentDirectoryPath],
    };

    NSError *error;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:service format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
    if (data == nil) {
        NSLog(@"Failed to serialize service: %@", error);
        return 1;
    }

    NSString *servicePath = @"/Library/LaunchDaemons/installprofile.plist";
    NSLog(@"Creating service at %@ with %@", servicePath, service);
    if ([data writeToFile:servicePath options:NSDataWritingAtomic error:&error] == false) {
        NSLog(@"Failed to write service: %@", error);
        return 2;
    }

    // Unload previous service
    NSTask *task = [NSTask new];
    [task setLaunchPath:@"/bin/launchctl"];
    [task setArguments:@[@"unload", servicePath]];
    [task launch];
    [task waitUntilExit];

    // Load service
    task = [NSTask new];
    [task setLaunchPath:@"/bin/launchctl"];
    [task setArguments:@[@"load", servicePath]];
    [task launch];
    [task waitUntilExit];
    // return code 0 is for loaded daemon, and much info is in stdout, and 113 or other nonzero value when daemon is not loaded
    if ([task terminationStatus] != 0) {
        NSLog(@"Failed to load service");
        return 3;
    }

    // Start a debug service so we get stdio here.
    NSString *serviceName = @"system/installprofile";
    NSTask *debugTask = [NSTask new];
    [debugTask setLaunchPath:@"/bin/launchctl"];
    [debugTask setArguments:@[@"debug", serviceName, @"--stdout", @"--stderr"]];
    [debugTask launch];

    NSTask *startTask = [NSTask new];
    [startTask setLaunchPath:@"/bin/launchctl"];
    [startTask setArguments:@[@"kickstart", serviceName, @"-k"]];
    [startTask launch];
    [startTask waitUntilExit];

    while (installProfileServiceIsUp()) {
        sleep(1);
    }
    [debugTask terminate];
    [debugTask waitUntilExit];

    if ([[NSFileManager defaultManager] removeItemAtPath:servicePath error:&error] == false) {
        NSLog(@"Failed to delete service: %@", error);
        return 4;
    }
    return 0;
}

int main(int argc, char**argv) {
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];

    bool isService = getppid() == 1;
    NSString *path = nil;
    for (NSUInteger i = 1; i < [arguments count]; i++) {
        NSString *arg = arguments[i];
        if ([arg hasPrefix:@"-"]) {
            NSMutableArray  *chars = [NSMutableArray array];

            [arg enumerateSubstringsInRange:NSMakeRange(1, [arg length] - 1) options: NSStringEnumerationByComposedCharacterSequences
                usingBlock: ^(NSString *inSubstring, NSRange inSubstringRange, NSRange inEnclosingRange, BOOL *outStop) {
                [chars addObject:inSubstring];
            }];
            for (id c in chars) {
                if ([c isEqual:@"s"]) {
                    isService = true;
                } else {
                    return usage(arguments);
                }
            }
        } else if (path == nil) {
            path = arg;
        } else {
            return usage(arguments);
        }
    }
    if (path == nil) {
        return usage(arguments);
    }

    if (!isService) {
        // Create service
        return createAndWaitService(path);
    }

    return runAsService(path);
}
