#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>

#define LOG(fmt, ...) fprintf(stderr, "dockhop: %s:%d: " fmt "\n", __func__, __LINE__, ##__VA_ARGS__)
#define FAIL(...)                                                                                                      \
    do {                                                                                                               \
        LOG(__VA_ARGS__);                                                                                              \
        exit(1);                                                                                                       \
    } while (0)

static BOOL includeFinder = NO;

static void openDockApp(NSUInteger slot) {
    NSUInteger number = slot + 1;
    NSWorkspace *workspace = NSWorkspace.sharedWorkspace;
    NSURL *url = nil;
    if (includeFinder && slot == 0) {
        url = [workspace URLForApplicationWithBundleIdentifier:@"com.apple.finder"];
    } else {
        if (includeFinder)
            slot--;

        // Refresh preference cache to reflect any changes to the Dock
        CFPreferencesAppSynchronize(CFSTR("com.apple.dock"));
        id tiles = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("persistent-apps"), CFSTR("com.apple.dock")));
        if (![tiles isKindOfClass:NSArray.class]) {
            LOG("No persistent-apps found!");
            return;
        }

        for (id tile in tiles) {
            if (![tile isKindOfClass:NSDictionary.class])
                continue;
            id data = tile[@"tile-data"];
            if (![data isKindOfClass:NSDictionary.class])
                continue;
            id file = data[@"file-data"];
            if (![file isKindOfClass:NSDictionary.class])
                continue;
            id path = file[@"_CFURLString"];
            if (![path isKindOfClass:NSString.class])
                continue;
            NSURL *toRun = [NSURL URLWithString:path];
            if (toRun.isFileURL && [toRun.pathExtension.lowercaseString isEqual:@"app"] && slot-- == 0) {
                url = toRun;
                break;
            }
        }
    }

    if (!url) {
        LOG("Nothing found in slot %lu", (unsigned long)number);
        return;
    }

    LOG("Opening slot %lu: %s", (unsigned long)number, url.path.UTF8String);
    NSWorkspaceOpenConfiguration *config = [NSWorkspaceOpenConfiguration configuration];
    config.activates = YES;
    [workspace openApplicationAtURL:url
                      configuration:config
                  completionHandler:^(NSRunningApplication *app, NSError *error) {
                      (void)app;
                      if (error)
                          LOG("Open failed: %s", error.localizedDescription.UTF8String);
                  }];
}

static OSStatus pressed(EventHandlerCallRef next, EventRef event, void *context) {
    (void)next;
    (void)context;
    @autoreleasepool {
        EventHotKeyID key;
        OSStatus status =
            GetEventParameter(event, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(key), NULL, &key);
        if (status != noErr)
            return status;
        if (key.signature != 'dhop' || key.id >= 9)
            return eventNotHandledErr;
        openDockApp(key.id);
    }
    return noErr;
}

// Returns nil if the file doesn't exist
static NSDictionary *readConfig(NSString *path) {
    NSError *error = nil;
    NSData *contents = [NSData dataWithContentsOfFile:path options:0 error:&error];
    if (!contents) {
        if ([error.domain isEqual:NSCocoaErrorDomain] && error.code == NSFileReadNoSuchFileError)
            return nil;
        FAIL("Failed to load config: %s", error.localizedDescription.UTF8String);
    }
    id parsed = [NSJSONSerialization JSONObjectWithData:contents options:0 error:&error];
    if (![parsed isKindOfClass:NSDictionary.class])
        FAIL("Config is not a valid JSON object");
    return parsed;
}

int main(void) {
    @autoreleasepool {
        LOG("Starting...");

        NSFileManager *fm = NSFileManager.defaultManager;
        NSString *path;
        const char *override = getenv("DOCKHOP_CONFIG");
        if (override && *override) {
            path = [fm stringWithFileSystemRepresentation:override length:strlen(override)];
        } else {
            path = [NSHomeDirectory() stringByAppendingPathComponent:@".config/dockhop/config.json"];
        }

        LOG("Config path: %s", path.UTF8String);
        NSDictionary *config = readConfig(path);
        if (!config) {
            LOG("Could not read config file; using defaults");
            config = @{};
        }

        id finder = config[@"includeFinder"];
        if (finder && CFGetTypeID((__bridge CFTypeRef)finder) != CFBooleanGetTypeID()) {
            FAIL("includeFinder must be true/false");
        }
        includeFinder = [config[@"includeFinder"] boolValue];
        LOG(" -> include Finder: %s", includeFinder ? "YES" : "NO");

        id modifiers = config[@"modifiers"] ?: @[ @"command" ];
        if (![modifiers isKindOfClass:NSArray.class] || ![modifiers count]) {
            FAIL("Modifiers cannot be empty");
        }
        NSDictionary *flags = @{
            @"command" : @(cmdKey),
            @"option" : @(optionKey),
            @"control" : @(controlKey),
            @"shift" : @(shiftKey),
        };
        UInt32 mask = 0;
        for (id modifier in modifiers) {
            if (![modifier isKindOfClass:NSString.class] || !flags[modifier]) {
                FAIL("Invalid modifier %s", [modifier description].UTF8String);
            }
            mask |= [flags[modifier] unsignedIntValue];
        }
        if (!(mask & (cmdKey | optionKey | controlKey))) {
            FAIL("Shift must be combined with another modifier");
        }
        LOG(" -> modifiers: %s", [modifiers componentsJoinedByString:@"+"].UTF8String);

        EventTypeSpec type = {kEventClassKeyboard, kEventHotKeyPressed};
        if (InstallApplicationEventHandler(pressed, 1, &type, NULL, NULL) != noErr) {
            FAIL("Could not install hotkey handler!");
        }

        UInt32 codes[] = {kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                          kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9};
        for (UInt32 i = 0; i < 9; i++) {
            EventHotKeyID key = {'dhop', i};
            EventHotKeyRef hotkey;
            OSStatus status = RegisterEventHotKey(codes[i], mask, key, GetApplicationEventTarget(), 0, &hotkey);
            if (status != noErr) {
                FAIL("Failed to register shortcut %u (status %d)", i + 1, (int)status);
            }
        }
        LOG("Hotkey registration complete! Waiting for key presses.");

        // Carbon event loop
        EventTargetRef target = GetEventDispatcherTarget();
        for (;;) {
            EventRef event;
            if (ReceiveNextEvent(0, NULL, kEventDurationForever, true, &event) == noErr) {
                SendEventToEventTarget(event, target);
                ReleaseEvent(event);
            }
        }
    }
    return 0;
}
