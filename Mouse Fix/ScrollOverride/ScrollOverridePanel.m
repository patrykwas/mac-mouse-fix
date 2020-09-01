//
// --------------------------------------------------------------------------
// ScrollOverride.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

/*
 Reference:
    Table view programming guide:
        https://www.appcoda.com/macos-programming-tableview/
    Drag and drop for table views:
        https://www.natethompson.io/2019/03/23/nstableview-drag-and-drop.html
    General Drag and drop tutorial:
        https://www.raywenderlich.com/1016-drag-and-drop-tutorial-for-macos
    Uniform Type Identifiers (UTIs) Reference: https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html#//apple_ref/doc/uid/TP40009259-SW1
 */

#import "ScrollOverridePanel.h"
#import "ConfigFileInterface_PrefPane.h"
#import "Utility_PrefPane.h"
#import "NSMutableDictionary+Additions.h"
#import <Foundation/Foundation.h>
#import "MoreSheet.h"

@interface ScrollOverridePanel ()

#pragma mark Outlets

@property (strong) IBOutlet NSTableView *tableView;

@end

@implementation ScrollOverridePanel

#pragma mark - Class

+ (void)load {
    _instance = [[ScrollOverridePanel alloc] initWithWindowNibName:@"ScrollOverridePanel"];
        // Register for incoming drag and drop operation
}
static ScrollOverridePanel *_instance;
+ (ScrollOverridePanel *)instance {
    return _instance;
}

#pragma mark - Instance

#pragma mark - Public variables

#pragma mark - Private variables

/// Keys are table column identifiers (These are set through interface builder). Values are keypaths to the values modified by the controls in the column with that identifier.
/// Keypaths relative to config root give default values. Relative to config[@"AppOverrides"][@"[bundle identifier of someApp]"] they give override values for someApp.
NSDictionary *_columnIdentifierToKeyPath;

#pragma mark - Public functions

- (void)openWindow {
    _columnIdentifierToKeyPath = @{
        @"SmoothEnabledColumnID" : @"Scroll.smooth",
        @"MagnificationEnabledColumnID" : @"Scroll.modifierKeys.magnificationScrollModifierKeyEnabled",
        @"HorizontalEnabledColumnID" : @"Scroll.modifierKeys.horizontalScrollModifierKeyEnabled"
    };
    [ConfigFileInterface_PrefPane loadConfigFromFile];
    [self loadTableViewDataModelFromConfig];
    [_tableView reloadData];
    
    if (self.window.isVisible) {
        [self.window close];
    } else {
        [self.window center];
    }
    [self.window makeKeyAndOrderFront:nil];
    [self.window performSelector:@selector(makeKeyWindow) withObject:nil afterDelay:0.05]; // Need to do this to make the window key. Magic?
    
//    self.window.movableByWindowBackground = YES;
    
    // Make tableView drag and drop target
    
    NSString *fileURLUTI = @"public.file-url";
//    NSString *tableRowType = @"com.nuebling.mousefix.table-row";
    [_tableView registerForDraggedTypes:@[fileURLUTI]]; // makes it accept apps, and table rows
//    [_tableView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:YES];
}

//- (void)windowWillClose:(NSNotification *)notification {
//    dispatch_after(0.3, dispatch_get_main_queue(), ^{
//        [MoreSheet.instance end];
//    });
//}

- (void)setConfigFileToUI {
    [self writeTableViewDataModelToConfig];
    [ConfigFileInterface_PrefPane writeConfigToFileAndNotifyHelper];
    [self loadTableViewDataModelFromConfig];
    [_tableView reloadData];
}

#pragma mark TableView

- (IBAction)addRemoveControl:(id)sender {
    if ([sender selectedSegment] == 0) {
        [self addButtonAction];
    } else {
        [self removeButtonAction];
    }
}
- (void)addButtonAction {

    NSOpenPanel* openPanel = [NSOpenPanel openPanel];

    openPanel.canChooseFiles = YES;
    openPanel.canChooseDirectories = NO;
    openPanel.canCreateDirectories = NO; // Doesn't work
    openPanel.allowsMultipleSelection = YES; // Doesn't work :/
    openPanel.allowedFileTypes = @[@"com.apple.application"];
    openPanel.prompt = @"Choose";
    
    NSString *applicationsFolderPath = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES).firstObject;
    openPanel.directoryURL = [NSURL fileURLWithPath:applicationsFolderPath];
    
    // Display the dialog.
    [openPanel beginSheetModalForWindow:self.window
                    completionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK) {  // If the OK button was pressed, process the files. Otherwise return.
            return;
        }
        NSArray* urls = [openPanel URLs];
        NSMutableArray* bundleIDs = [NSMutableArray array];
        // Loop through all the files and process them.
        for (NSURL *fileURL in urls) {
            NSString* bundleID = [NSBundle bundleWithURL:fileURL].bundleIdentifier;
            [bundleIDs addObject:bundleID];
        }
        [self tableAddAppsWithBundleIDs:bundleIDs atRow:0];
    }];
}
- (void)removeButtonAction {
    [_tableViewDataModel removeObjectsAtIndexes:_tableView.selectedRowIndexes];
    [self writeTableViewDataModelToConfig];
    [self loadTableViewDataModelFromConfig]; // Not sure if necessary
    [_tableView removeRowsAtIndexes:_tableView.selectedRowIndexes withAnimation:NSTableViewAnimationSlideUp];
}
- (IBAction)checkBoxInCell:(NSButton *)sender {
    NSInteger state = sender.state;
    NSInteger row = [_tableView rowForView:sender];
    NSInteger column = [_tableView columnForView:sender];
    NSString *columnIdentifier = _tableView.tableColumns[column].identifier;
    
    [_tableViewDataModel[row] setObject: [NSNumber numberWithBool:state] forKey: columnIdentifier];
    [self setConfigFileToUI];
}

/// The tableView automatically calls this. The return determines how many rows the tableView will display.
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _tableViewDataModel.count;
}

/// The tableView automatically calls this for every cell. It uses the return of this function as the content of the cell.
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    
    if (row >= _tableViewDataModel.count) {
        return nil;
    }
    
    if ([tableColumn.identifier isEqualToString:@"AppColumnID"]) {
        NSTableCellView *appCell = [_tableView makeViewWithIdentifier:@"AppCellID" owner:nil];
        if (appCell) {
            NSString *bundleID = _tableViewDataModel[row][tableColumn.identifier];
            NSString *appPath = [NSWorkspace.sharedWorkspace absolutePathForAppBundleWithIdentifier:bundleID];
//            NSBundle *bundle = [NSBundle bundleWithIdentifier:bundleID]; // This doesn't work for some reason
            NSImage *appIcon;
            NSString *appName;
            if (![Utility_PrefPane appIsInstalled:bundleID]) {
                // User should never see this. We don't want to load uninstalled apps into _tableViewDataModel to begin with.
                appIcon = [NSImage imageNamed:NSImageNameStopProgressFreestandingTemplate];
                appName = [NSString stringWithFormat:@"Couldn't find app: %@", bundleID];
            } else {
                appIcon = [NSWorkspace.sharedWorkspace iconForFile:appPath];
                appName = [[NSBundle bundleWithPath:appPath] objectForInfoDictionaryKey:@"CFBundleName"];
            }
            
            appCell.textField.stringValue = appName;
            appCell.textField.toolTip = appName;
            appCell.imageView.image = appIcon;
        }
        return appCell;
    } else if ([tableColumn.identifier isEqualToString:@"SmoothEnabledColumnID"] ||
               [tableColumn.identifier isEqualToString:@"MagnificationEnabledColumnID"] ||
               [tableColumn.identifier isEqualToString:@"HorizontalEnabledColumnID"]) {
        NSTableCellView *cell = [_tableView makeViewWithIdentifier:@"CheckBoxCellID" owner:nil];
        if (cell) {
            BOOL isEnabled = [_tableViewDataModel[row][tableColumn.identifier] boolValue];
            NSButton *checkBox = cell.subviews[0];
            checkBox.state = isEnabled;
            checkBox.target = self;
            checkBox.action = @selector(checkBoxInCell:);
        }
        return cell;
    }
    return nil;
}

#pragma mark TableView - Drag and drop

// Validate drop
- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    
    NSPasteboard *pasteboard = info.draggingPasteboard;
    
    BOOL droppingAbove = (dropOperation == NSTableViewDropAbove);
    
    BOOL isURL = [pasteboard.types containsObject:@"public.file-url"];
    NSDictionary *options = @{NSPasteboardURLReadingContentsConformToTypesKey : @[@"com.apple.application-bundle"]};
    BOOL URLRefersToApp = [pasteboard canReadObjectForClasses:@[NSURL.self] options:options];
    
    NSArray<NSString *> *draggedBundleIDs = bundleIDsFromPasteboard(pasteboard);
    
    NSDictionary *draggedBundleIDsSorted = sortByAlreadyInTable(draggedBundleIDs);
    BOOL allAlreadyInTable = (((NSArray *)draggedBundleIDsSorted[@"notInTable"]).count == 0);
    NSMutableArray *tableIndicesOfAlreadyInTable = [((NSArray *)draggedBundleIDsSorted[@"inTable"]) valueForKey:@"tableIndex"];
    
    NSMutableIndexSet * indexSet = indexSetFromIndexArray(tableIndicesOfAlreadyInTable);
    [_tableView selectRowIndexes:indexSet byExtendingSelection:NO];
    
    if (droppingAbove && isURL && URLRefersToApp && !allAlreadyInTable) {
        return NSDragOperationCopy;
    }
    if (allAlreadyInTable) {
        [NSCursor.operationNotAllowedCursor push]; // I can't find a way to reset the cursor when it leaves the tableView
        [_tableView scrollRowToVisible:((NSNumber *)tableIndicesOfAlreadyInTable[0]).integerValue];
    }
    return NSDragOperationNone;
}

// Accept drop
- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    
    NSArray *items = info.draggingPasteboard.pasteboardItems;
    if (!items || items.count == 0) {
        return false;
    }
    row = 0; // Always adding items at the top cause it's noice
    
    NSArray<NSString *> * bundleIDs = bundleIDsFromPasteboard(info.draggingPasteboard);
    [self tableAddAppsWithBundleIDs:bundleIDs atRow:row];
    
    [self.window makeKeyWindow];
    
    return true;
}

- (void)tableAddAppsWithBundleIDs:(NSArray<NSString *> *)bundleIDs atRow:(NSInteger)row {
    
    NSMutableArray *newRows = [NSMutableArray array];
    bundleIDs = [bundleIDs valueForKeyPath:@"@distinctUnionOfObjects.self"]; // Remove duplicates. This is only necessary when the user drags and drops in more than one app with the same bundleID.
    NSDictionary *bundleIDsSorted = sortByAlreadyInTable(bundleIDs);
    
    for (NSString *bundleID in bundleIDsSorted[@"notInTable"]) {
        NSMutableDictionary *newRow = [NSMutableDictionary dictionary];
        // Fill out new row with bundle ID and default values
        newRow[@"AppColumnID"] = bundleID;
        for (NSString *columnID in _columnIdentifierToKeyPath) {
            NSString *keyPath = _columnIdentifierToKeyPath[columnID];
            NSObject *defaultValue = [ConfigFileInterface_PrefPane.config objectForCoolKeyPath:keyPath]; // Could use valueForKeyPath as well, because there are no periods in the keys of the keyPath
            newRow[columnID] = defaultValue;
        }
        [newRows addObject:newRow];
    }
    
    NSIndexSet *newRowsIndices = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row, ((NSArray *)bundleIDsSorted[@"notInTable"]).count)];
    NSIndexSet *alreadyInTableRowsIndices = indexSetFromIndexArray(
                                                                   [((NSArray *)bundleIDsSorted[@"inTable"]) valueForKey:@"tableIndex"]
                                                                   );
    
    [_tableView selectRowIndexes:alreadyInTableRowsIndices byExtendingSelection:NO];
    
    [_tableViewDataModel insertObjects:newRows atIndexes:newRowsIndices];
    [self writeTableViewDataModelToConfig];
    [self loadTableViewDataModelFromConfig]; // At the time of writing: not necessary. Not sure if useful. Might make things more robust, if we run all of the validity checks in `loadTableViewDataModelFromConfig` again.
    NSTableViewAnimationOptions animation = NSTableViewAnimationSlideDown;
    
    [_tableView insertRowsAtIndexes:newRowsIndices withAnimation:animation];
    [_tableView selectRowIndexes:newRowsIndices byExtendingSelection:YES];
    if (newRowsIndices.count > 0) {
        [_tableView scrollRowToVisible:newRowsIndices.firstIndex];
    } else {
        [_tableView scrollRowToVisible:alreadyInTableRowsIndices.firstIndex];
    }
}

#pragma mark - Private functions

NSMutableArray *_tableViewDataModel;

- (void)writeTableViewDataModelToConfig {
    
    NSMutableSet *bundleIDsInTable = [NSMutableSet set];
    // Write table data into config
    int orderKey = 0;
    for (NSMutableDictionary *rowDict in _tableViewDataModel) {
        NSString *bundleID = rowDict[@"AppColumnID"];
        [bundleIDsInTable addObject:bundleID];
        NSString *bundleIDEscaped = [bundleID stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
        [rowDict removeObjectsForKeys:@[@"AppColumnID", @"orderKey"]]; // So we don't iterate over this in the loop below
        // Write override values
        for (NSString *columnID in rowDict) {
            NSObject *cellValue = rowDict[columnID];
            NSString *defaultKeyPath = _columnIdentifierToKeyPath[columnID];
            NSString *overrideKeyPath = [NSString stringWithFormat:@"AppOverrides.%@.Root.%@", bundleIDEscaped, defaultKeyPath];
            [ConfigFileInterface_PrefPane.config setObject:cellValue forCoolKeyPath:overrideKeyPath];
        }
        // Write order key
        NSString *orderKeyKeyPath = [NSString stringWithFormat:@"AppOverrides.%@.meta.scrollOverridePanelTableViewOrderKey", bundleIDEscaped];
        [ConfigFileInterface_PrefPane.config setObject:[NSNumber numberWithInt:orderKey] forCoolKeyPath:orderKeyKeyPath];
        orderKey += 1;
    }
    
    // For all overrides for apps in the config, which aren't in the table, and which are installed - delete all values managed by the table from the config
    
    NSMutableSet *bundleIDsInConfigAndInstalledButNotInTable = [NSMutableSet setWithArray:((NSDictionary *)[ConfigFileInterface_PrefPane.config valueForKeyPath:@"AppOverrides"]).allKeys]; // Get all bundle IDs in the config
    
    bundleIDsInConfigAndInstalledButNotInTable = [bundleIDsInConfigAndInstalledButNotInTable filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [Utility_PrefPane appIsInstalled:evaluatedObject];
    }]].mutableCopy; // Filter out apps which aren't installed. We do this so we don't delete preinstalled overrides.
    [bundleIDsInConfigAndInstalledButNotInTable minusSet:bundleIDsInTable]; // Subtract apps in table
    
    for (NSString *bundleID in bundleIDsInConfigAndInstalledButNotInTable) {
        NSString *bundleIDEscaped = [bundleID stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
        // Delete override values
        for (NSString *rootKeyPath in _columnIdentifierToKeyPath.allValues) {
        NSString *overrideKeyPath = [NSString stringWithFormat:@"AppOverrides.%@.Root.%@", bundleIDEscaped, rootKeyPath];
        [ConfigFileInterface_PrefPane.config setObject:nil forCoolKeyPath:overrideKeyPath];
        }
        // Delete orderKey
        NSString *orderKeyKeyPath = [NSString stringWithFormat:@"AppOverrides.%@.meta.scrollOverridePanelTableViewOrderKey", bundleIDEscaped];
        [ConfigFileInterface_PrefPane.config setObject:nil forCoolKeyPath:orderKeyKeyPath];
    }
    
    [ConfigFileInterface_PrefPane cleanConfig];
    [ConfigFileInterface_PrefPane writeConfigToFileAndNotifyHelper];
}

- (void)loadTableViewDataModelFromConfig {
    _tableViewDataModel = [NSMutableArray array];
    NSDictionary *config = ConfigFileInterface_PrefPane.config;
    if (!config) { // TODO: does this exception make sense? What is the consequence of it being thrown? Where is it caught? Should we just reload the config file instead? Can this even happen if ConfigFileInterface successfully loaded?
        NSException *configNotLoadedException = [NSException exceptionWithName:@"ConfigNotLoadedException" reason:@"ConfigFileInterface config property is nil" userInfo:nil];
        @throw configNotLoadedException;
        return;
    }
    NSDictionary *overrides = config[@"AppOverrides"];
    if (!overrides) {
        NSLog(@"No overrides found in config while generating scroll override table data model.");
        return;
    }
    for (NSString *bundleID in overrides.allKeys) { // Every bundleID corresponds to one app/row
        // Check if app exists on system
        if (![Utility_PrefPane appIsInstalled:bundleID]) {
            continue; // If not, skip this bundleID
        }
        // Create rowDict for app with `bundleID` from data in config. Every key value pair in rowDict corresponds to a column. The key is the columnID and the value is the value for the column with `columnID` and the row of the app with `bundleID`
        NSMutableDictionary *rowDict = [NSMutableDictionary dictionary];
        NSArray *columnIDs = _columnIdentifierToKeyPath.allKeys;
        for (NSString *columnID in columnIDs) {
            NSString *keyPath = _columnIdentifierToKeyPath[columnID];
            NSObject *value = [overrides[bundleID][@"Root"] valueForKeyPath:keyPath];
            rowDict[columnID] = value; // If value is nil, no entry is added. (We use this fact in the allNil / someNil checks below)
        }
        // Check existence / validity of generated rowDict
        BOOL allNil = (rowDict.allValues.count == 0);
        BOOL someNil = (rowDict.allValues.count < columnIDs.count);
        if (allNil) { // None of the values controlled by the table exist for this app in config
            continue; // Don't add this app to the table
        }
        if (someNil) { // Only some of the values controlled by the table don't exist in this AppOverride
            // Fill out missing values with default ones
            [ConfigFileInterface_PrefPane repairConfigWithProblem:kMFConfigProblemIncompleteAppOverride info:@{
                    @"bundleID": bundleID,
                    @"relevantKeyPaths": _columnIdentifierToKeyPath.allValues,
            }];
            [self loadTableViewDataModelFromConfig]; // Restart the whole function. someNil will not occur next time because we filled out all the AppOverrides with some values missing.
            return;
        }
        // Add everything thats not an override last, so the allNil check works properly
        rowDict[@"AppColumnID"] = bundleID; // Not sure if the key `AppColumnID` makes sense here. Maybe it should be `bundleID` instead.
        rowDict[@"orderKey"] = overrides[bundleID][@"meta"][@"scrollOverridePanelTableViewOrderKey"];
        
        [_tableViewDataModel addObject:rowDict];
    }
    // Sort _tableViewDataModel by orderKey
    NSSortDescriptor *sortDesc = [NSSortDescriptor sortDescriptorWithKey:@"orderKey" ascending:YES];
    [_tableViewDataModel sortUsingDescriptors:@[sortDesc]];
}

#pragma mark Utility

static NSArray<NSString *> * bundleIDsFromPasteboard(NSPasteboard *pasteboard) {
    NSArray *items = pasteboard.pasteboardItems;
    NSMutableArray *bundleIDs = [NSMutableArray arrayWithCapacity:items.count];
    for (NSPasteboardItem *item in items) {
        NSString *urlString = [item stringForType:@"public.file-url"];
        NSURL *url = [NSURL URLWithString:urlString];
        NSString *bundleID = [[NSBundle bundleWithURL:url] bundleIdentifier];
        if (bundleID) { // Adding nil to NSArray with `addObject:` yields a crash
            [bundleIDs addObject:bundleID];
        }
    }
    return bundleIDs;
}

static NSDictionary *sortByAlreadyInTable(NSArray *bundleIDs) {
    NSArray *bundleIDsFromTable = [_tableViewDataModel valueForKey:@"AppColumnID"];
    NSMutableArray<NSString *> *inpNotInTable = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *inpInTable = [NSMutableArray array];
    for (NSString *bundleID in bundleIDs) {
        if ([bundleIDsFromTable containsObject:bundleID]) {
            [inpInTable addObject:@{
                @"id": bundleID,
                @"tableIndex": [NSNumber numberWithUnsignedInteger:[bundleIDsFromTable indexOfObject:bundleID]]
            }];
        } else {
            [inpNotInTable addObject:bundleID];
        }
    }
    return @{
        @"inTable": inpInTable,
        @"notInTable": inpNotInTable
    };
}
static NSMutableIndexSet *indexSetFromIndexArray(NSArray<NSNumber *> *arrayOfIndices) {
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    for (NSNumber *index in arrayOfIndices) {
        [indexSet addIndex:index.unsignedIntegerValue];
    }
    return indexSet;
}


@end