#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "BHPreferences.h"

static NSSet<NSString *> *hiddenNames;
static NSMutableSet<NSString *> *knownNames;
static NSHashTable<UITableViewCell *> *trackedCells;
static BOOL enabled;
static BOOL discoveryQueued;
static char savedHiddenKey;

static BOOL IsBatteryScreen(UIView *view) {
    for (UIResponder *r = view; r; r = r.nextResponder) {
        if (![r isKindOfClass:UIViewController.class]) continue;
        NSString *bundle = [NSBundle bundleForClass:r.class].bundlePath.lastPathComponent;
        // Our own preference bundle also has "Battery" in its name.
        if ([bundle containsString:@"BatteryHide"]) return NO;
        if ([bundle containsString:@"Battery"] || [bundle containsString:@"PowerUsage"]) return YES;
    }
    return NO;
}

static BOOL ContainsHiddenLabel(UIView *root) {
    if ([root isKindOfClass:UILabel.class]) {
        NSString *text = [((UILabel *)root).text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (text && [hiddenNames containsObject:text]) return YES;
    }
    for (UIView *child in root.subviews) if (ContainsHiddenLabel(child)) return YES;
    return NO;
}

static void RestoreCell(UITableViewCell *cell) {
    NSNumber *original = objc_getAssociatedObject(cell, &savedHiddenKey);
    if (!original) return;
    objc_setAssociatedObject(cell, &savedHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    cell.hidden = original.boolValue;
}

static void QueueKnownName(NSString *name) {
    name = [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!name.length || name.length > 150 || knownNames.count >= 2000 || [knownNames containsObject:name]) return;
    [knownNames addObject:name];
    if (discoveryQueued) return;
    discoveryQueued = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        discoveryQueued = NO;
        [knownNames addObjectsFromArray:BHNames(@"KnownNames")];
        BHWrite(@"KnownNames", [[knownNames allObjects] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]);
    });
}

static void ReadLabels(UIView *root, NSMutableArray<NSString *> *labels, BOOL *hasImage) {
    if (root.hidden || root.alpha < 0.01) return;
    if ([root isKindOfClass:UIImageView.class] && ((UIImageView *)root).image) *hasImage = YES;
    if ([root isKindOfClass:UILabel.class]) {
        NSString *text = ((UILabel *)root).text;
        if (text.length) [labels addObject:text];
    }
    for (UIView *child in root.subviews) ReadLabels(child, labels, hasImage);
}

static void LearnRow(UITableViewCell *cell) {
    BOOL hasImage = cell.imageView.image != nil;
    NSMutableArray<NSString *> *labels = [NSMutableArray array];
    ReadLabels(cell.contentView, labels, &hasImage);
    if (!hasImage) return; // Only learn icon-bearing rows, not chart/section labels.
    NSString *candidate = cell.textLabel.text;
    if (!candidate.length) {
        for (NSString *label in labels) {
            if ([label rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet].location != NSNotFound &&
                ![label containsString:@"%"] && ![label containsString:@"\n"]) { candidate = label; break; }
        }
    }
    if (candidate.length) QueueKnownName(candidate);
}

static void RefreshVisibleRows(void) {
    CFPreferencesAppSynchronize(CFSTR("com.example.batteryhide"));
    enabled = [BHRead(@"Enabled", @YES) boolValue];
    hiddenNames = [NSSet setWithArray:BHNames(@"HiddenNames")];
    [knownNames addObjectsFromArray:BHNames(@"KnownNames")];
    for (UITableViewCell *cell in trackedCells.allObjects) {
        RestoreCell(cell);
        if (enabled && IsBatteryScreen(cell) && ContainsHiddenLabel(cell.contentView)) {
            objc_setAssociatedObject(cell, &savedHiddenKey, @(cell.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            cell.hidden = YES;
        }
        [cell setNeedsLayout];
    }
}

static void Changed(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    dispatch_async(dispatch_get_main_queue(), ^{ RefreshVisibleRows(); });
}

%hook UITableViewCell
- (void)layoutSubviews {
    RestoreCell(self);
    %orig;
    if (!IsBatteryScreen(self)) return;
    [trackedCells addObject:self];
    LearnRow(self);
    if (enabled && ContainsHiddenLabel(self.contentView)) {
        objc_setAssociatedObject(self, &savedHiddenKey, @(self.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        self.hidden = YES;
    }
}
- (void)prepareForReuse {
    RestoreCell(self);
    [trackedCells removeObject:self];
    %orig;
}
%end

%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.Preferences"]) return;
        knownNames = [NSMutableSet setWithArray:BHNames(@"KnownNames")];
        trackedCells = [NSHashTable weakObjectsHashTable];
        enabled = [BHRead(@"Enabled", @YES) boolValue];
        hiddenNames = [NSSet setWithArray:BHNames(@"HiddenNames")];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, Changed,
            CFSTR("com.example.batteryhide/changed"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        %init;
    }
}
