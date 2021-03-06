/*
This file is part of Telegram Desktop,
the official desktop version of Telegram messaging app, see https://telegram.org

Telegram Desktop is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

It is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

In addition, as a special exception, the copyright holders give permission
to link the code of portions of this program with the OpenSSL library.

Full license: https://github.com/telegramdesktop/tdesktop/blob/master/LICENSE
Copyright (c) 2014-2016 John Preston, https://desktop.telegram.org
*/
#import <Cocoa/Cocoa.h>

NSString *appName = @"Telegram.app";
NSString *appDir = nil;
NSString *workDir = nil;
NSString *crashReportArg = nil;

#ifdef _DEBUG
BOOL _debug = YES;
#else
BOOL _debug = NO;
#endif

NSFileHandle *_logFile = nil;
void openLog() {
	if (!_debug || _logFile) return;
	NSString *logDir = [workDir stringByAppendingString:@"DebugLogs"];
	if (![[NSFileManager defaultManager] createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:nil]) {
		return;
	}

	NSDateFormatter *fmt = [[NSDateFormatter alloc] initWithDateFormat:@"DebugLogs/%Y%m%d_%H%M%S_upd.txt" allowNaturalLanguage:NO];
	NSString *logPath = [workDir stringByAppendingString:[fmt stringFromDate:[NSDate date]]];
	[[NSFileManager defaultManager] createFileAtPath:logPath contents:nil attributes:nil];
	_logFile = [NSFileHandle fileHandleForWritingAtPath:logPath];
}

void closeLog() {
	if (!_logFile) return;

	[_logFile closeFile];
}

void writeLog(NSString *msg) {
	if (!_logFile) return;

	[_logFile writeData:[[msg stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
	[_logFile synchronizeFile];
}

void delFolder() {
	writeLog([@"Fully clearing old path: " stringByAppendingString:[workDir stringByAppendingString:@"tupdates/ready"]]);
	if (![[NSFileManager defaultManager] removeItemAtPath:[workDir stringByAppendingString:@"tupdates/ready"] error:nil]) {
		writeLog(@"Failed to clear old path! :( New path was used?..");
	}
	writeLog([@"Fully clearing new path: " stringByAppendingString:[workDir stringByAppendingString:@"tupdates/temp"]]);
	if (![[NSFileManager defaultManager] removeItemAtPath:[workDir stringByAppendingString:@"tupdates/temp"] error:nil]) {
		writeLog(@"Error: failed to clear new path! :(");
	}
	rmdir([[workDir stringByAppendingString:@"tupdates"] fileSystemRepresentation]);
}

int main(int argc, const char * argv[]) {
	NSString *path = [[NSBundle mainBundle] bundlePath];
	if (!path) {
		return -1;
	}
	NSRange range = [path rangeOfString:@".app/" options:NSBackwardsSearch];
	if (range.location == NSNotFound) {
		return -1;
	}
	path = [path substringToIndex:range.location > 0 ? range.location : 0];

	range = [path rangeOfString:@"/" options:NSBackwardsSearch];
	NSString *appRealName = (range.location == NSNotFound) ? path : [path substringFromIndex:range.location + 1];
	appRealName = [[NSArray arrayWithObjects:appRealName, @".app", nil] componentsJoinedByString:@""];
	appDir = (range.location == NSNotFound) ? @"" : [path substringToIndex:range.location + 1];
	NSString *appDirFull = [appDir stringByAppendingString:appRealName];

	openLog();
	pid_t procId = 0;
	BOOL update = YES, toSettings = NO, autoStart = NO, startInTray = NO, testMode = NO;
	NSString *key = nil;
	for (int i = 0; i < argc; ++i) {
		if ([@"-workpath" isEqualToString:[NSString stringWithUTF8String:argv[i]]]) {
			if (++i < argc) {
				workDir = [NSString stringWithUTF8String:argv[i]];
			}
		} else if ([@"-procid" isEqualToString:[NSString stringWithUTF8String:argv[i]]]) {
			if (++i < argc) {
				NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
				[formatter setNumberStyle:NSNumberFormatterDecimalStyle];
				procId = [[formatter numberFromString:[NSString stringWithUTF8String:argv[i]]] intValue];
			}
		} else if ([@"-crashreport" isEqualToString:[NSString stringWithUTF8String:argv[i]]]) {
			if (++i < argc) {
				crashReportArg = [NSString stringWithUTF8String:argv[i]];
			}
		} else if ([@"-noupdate" isEqualToString:[NSString stringWithUTF8String:argv[i]]]) {
			update = NO;
		} else if ([@"-tosettings" isEqualToString:[NSString stringWithUTF8String:argv[i]]]) {
			toSettings = YES;
		} else if ([@"-autostart" isEqualToString:[NSString stringWithUTF8String:argv[i]]]) {
			autoStart = YES;
		} else if ([@"-debug" isEqualToString:[NSString stringWithUTF8String:argv[i]]]) {
			_debug = YES;
		} else if ([@"-startintray" isEqualToString:[NSString stringWithUTF8String:argv[i]]]) {
			startInTray = YES;
		} else if ([@"-testmode" isEqualToString:[NSString stringWithUTF8String:argv[i]]]) {
			testMode = YES;
		} else if ([@"-key" isEqualToString:[NSString stringWithUTF8String:argv[i]]]) {
			if (++i < argc) key = [NSString stringWithUTF8String:argv[i]];
		}
	}
	if (!workDir) workDir = appDir;
	openLog();
	NSMutableArray *argsArr = [[NSMutableArray alloc] initWithCapacity:argc];
	for (int i = 0; i < argc; ++i) {
		[argsArr addObject:[NSString stringWithUTF8String:argv[i]]];
	}
	writeLog([[NSArray arrayWithObjects:@"Arguments: '", [argsArr componentsJoinedByString:@"' '"], @"'..", nil] componentsJoinedByString:@""]);
	if (key) writeLog([@"Key: " stringByAppendingString:key]);
	if (toSettings) writeLog(@"To Settings!");

	if (procId) {
		NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:procId];
		for (int i = 0; i < 5 && app != nil && ![app isTerminated]; ++i) {
			usleep(200000);
			app = [NSRunningApplication runningApplicationWithProcessIdentifier:procId];
		}
		if (app) [app forceTerminate];
		app = [NSRunningApplication runningApplicationWithProcessIdentifier:procId];
		for (int i = 0; i < 5 && app != nil && ![app isTerminated]; ++i) {
			usleep(200000);
			app = [NSRunningApplication runningApplicationWithProcessIdentifier:procId];
		}
	}

	if (update) {
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSString *readyFilePath = [workDir stringByAppendingString:@"tupdates/temp/ready"];
		NSString *srcDir = [workDir stringByAppendingString:@"tupdates/temp/"], *srcEnum = [workDir stringByAppendingString:@"tupdates/temp"];
		if ([fileManager fileExistsAtPath:readyFilePath]) {
			writeLog([@"Ready file found! Using new path: " stringByAppendingString: srcEnum]);
		} else {
			srcDir = [workDir stringByAppendingString:@"tupdates/ready/"]; // old
			srcEnum = [workDir stringByAppendingString:@"tupdates/ready"];
			writeLog([@"Ready file not found! Using old path: " stringByAppendingString: srcEnum]);
		}

		writeLog([@"Starting update files iteration, path: " stringByAppendingString: srcEnum]);

		NSString *contentsPath = [appDirFull stringByAppendingString: @"/Contents"];
		writeLog([[NSArray arrayWithObjects: @"Clearing dir ", contentsPath, nil] componentsJoinedByString:@""]);
		if (![fileManager removeItemAtPath:contentsPath error:nil]) {
			writeLog([@"Failed to clear path for directory " stringByAppendingString:contentsPath]);
			delFolder();
			return -1;
		}

		NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];
		NSDirectoryEnumerator *enumerator = [fileManager
											 enumeratorAtURL:[NSURL fileURLWithPath:srcEnum]
											 includingPropertiesForKeys:keys
											 options:0
											 errorHandler:^(NSURL *url, NSError *error) {
												 writeLog([[[@"Error in enumerating " stringByAppendingString:[url absoluteString]] stringByAppendingString: @" error is: "] stringByAppendingString: [error description]]);
												 return NO;
											 }];
		for (NSURL *url in enumerator) {
			NSString *srcPath = [url path];
			writeLog([@"Handling file " stringByAppendingString:srcPath]);
			NSRange r = [srcPath rangeOfString:srcDir];
			if (r.location != 0) {
				writeLog([@"Bad file found, no base path " stringByAppendingString:srcPath]);
				delFolder();
				break;
			}
			NSString *pathPart = [srcPath substringFromIndex:r.length];
			r = [pathPart rangeOfString:appName];
			if (r.location != 0) {
				writeLog([@"Skipping not app file " stringByAppendingString:srcPath]);
				continue;
			}
			NSString *dstPath = [appDirFull stringByAppendingString:[pathPart substringFromIndex:r.length]];
			NSError *error;
			NSNumber *isDirectory = nil;
			if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
				writeLog([@"Failed to get IsDirectory for file " stringByAppendingString:[url path]]);
				delFolder();
				break;
			}
			if ([isDirectory boolValue]) {
				writeLog([[NSArray arrayWithObjects: @"Copying dir ", srcPath, @" to ", dstPath, nil] componentsJoinedByString:@""]);
				if (![fileManager createDirectoryAtPath:dstPath withIntermediateDirectories:YES attributes:nil error:nil]) {
					writeLog([@"Failed to force path for directory " stringByAppendingString:dstPath]);
					delFolder();
					break;
				}
			} else if ([srcPath isEqualToString:readyFilePath]) {
				writeLog([[NSArray arrayWithObjects: @"Skipping ready file ", srcPath, nil] componentsJoinedByString:@""]);
			} else if ([fileManager fileExistsAtPath:dstPath]) {
				if (![[NSData dataWithContentsOfFile:srcPath] writeToFile:dstPath atomically:YES]) {
					writeLog([@"Failed to edit file " stringByAppendingString:dstPath]);
					delFolder();
					break;
				}
			} else {
				if (![fileManager copyItemAtPath:srcPath toPath:dstPath error:nil]) {
					writeLog([@"Failed to copy file to " stringByAppendingString:dstPath]);
					delFolder();
					break;
				}
			}
		}
		delFolder();
	}

	NSString *appPath = [[NSArray arrayWithObjects:appDir, appRealName, nil] componentsJoinedByString:@""];
	NSMutableArray *args = [[NSMutableArray alloc] initWithObjects: crashReportArg ? crashReportArg : @"-noupdate", nil];
	if (!crashReportArg) {
		if (toSettings) [args addObject:@"-tosettings"];
		if (_debug) [args addObject:@"-debug"];
		if (startInTray) [args addObject:@"-startintray"];
		if (testMode) [args addObject:@"-testmode"];
		if (autoStart) [args addObject:@"-autostart"];
		if (key) {
			[args addObject:@"-key"];
			[args addObject:key];
		}
	}
	writeLog([[NSArray arrayWithObjects:@"Running application '", appPath, @"' with args '", [args componentsJoinedByString:@"' '"], @"'..", nil] componentsJoinedByString:@""]);
	NSError *error = nil;
	NSRunningApplication *result = [[NSWorkspace sharedWorkspace]
					launchApplicationAtURL:[NSURL fileURLWithPath:appPath]
					options:NSWorkspaceLaunchDefault
					configuration:[NSDictionary
								   dictionaryWithObject:args
								   forKey:NSWorkspaceLaunchConfigurationArguments]
					error:&error];
	if (!result) {
		writeLog([@"Could not run application, error: " stringByAppendingString:error ? [error localizedDescription] : @"(nil)"]);
	}
	closeLog();
	return result ? 0 : -1;
}

