//
//  POIDetailsViewController.m
//  OSMiOS
//
//  Created by Bryce Cogswell on 12/10/12.
//  Copyright (c) 2012 Bryce Cogswell. All rights reserved.
//

#import "AppDelegate.h"
#import "AutocompleteTextField.h"
#import "CommonTagList.h"
#import "DLog.h"
#import "EditorMapLayer.h"
#import "MapView.h"
#import "OsmMapData.h"
#import "OsmObjects.h"
#import "POICommonTagsViewController.h"
#import "POIPresetViewController.h"
#import "POITabBarController.h"
#import "POITabBarController.h"
#import "POITypeViewController.h"
#import "TagInfo.h"
#import "UITableViewCell+FixConstraints.h"


@interface CommonTagCell : UITableViewCell
@property (assign,nonatomic)	IBOutlet	UILabel						*	nameLabel;
@property (assign,nonatomic)	IBOutlet	UILabel						*	nameLabel2;
@property (assign,nonatomic)	IBOutlet	AutocompleteTextField		*	valueField;
@property (assign,nonatomic)	IBOutlet	AutocompleteTextField		*	valueField2;
@property (strong,nonatomic)				CommonTagKey				*	commonTag;
@property (strong,nonatomic)				CommonTagKey				*	commonTag2;
@end

@implementation CommonTagCell
@end



@implementation POICommonTagsViewController


- (void)viewDidLoad
{
	// have to update presets before call super because super asks for the number of sections
	[self updatePresets];

	[super viewDidLoad];

	_tags = [CommonTagList sharedList];

	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(keyboardDidShow) name:UIKeyboardDidShowNotification object:nil];
	[center addObserver:self selector:@selector(keyboardDidHide) name:UIKeyboardWillHideNotification object:nil];
}

-(void)dealloc
{
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center removeObserver:self name:UIKeyboardDidShowNotification object:nil];
	[center removeObserver:self name:UIKeyboardDidHideNotification object:nil];
}

-(void)keyboardDidShow
{
	_keyboardShowing = YES;
}
-(void)keyboardDidHide
{
	_keyboardShowing = NO;
	dispatch_async(dispatch_get_main_queue(), ^{
		[self updatePresets];
	});
}

-(void)updatePresets
{
	POITabBarController * tabController = (id)self.tabBarController;

	_saveButton.enabled = [tabController isTagDictChanged];

	NSDictionary * dict = tabController.keyValueDict;


	OsmBaseObject * object = tabController.selection;
	NSString * geometry = object ? [object geometryName] : GEOMETRY_NODE;

	// update most recent feature
	NSString * featureName = [CommonTagList featureNameForObjectDict:dict geometry:geometry];
	if ( featureName ) {
		CommonTagFeature * feature = [CommonTagFeature commonTagFeatureWithName:featureName];
		[POITypeViewController loadMostRecentForGeometry:geometry];
		[POITypeViewController updateMostRecentArrayWithSelection:feature geometry:geometry];
	}
	
	__weak POICommonTagsViewController * weakSelf = self;
	__weak CommonTagList * weakTags = _tags;
	[_tags setPresetsForDict:dict geometry:geometry update:^{
		// this may complete much later, even after we've been dismissed
		POICommonTagsViewController * mySelf = weakSelf;
		if ( mySelf && !mySelf->_keyboardShowing ) {
			[weakTags setPresetsForDict:dict geometry:geometry update:nil];
			[mySelf.tableView reloadData];
		}
	}];
	[self.tableView reloadData];
}

#pragma mark display

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	if ( [self isMovingToParentViewController] ) {
	} else {
		[self updatePresets];
	}
}

-(void)viewWillDisappear:(BOOL)animated
{
	[self resignAll];
	[super viewWillDisappear:animated];
}

-(void)typeViewController:(POITypeViewController *)typeViewController didChangeFeatureTo:(CommonTagFeature *)feature
{
	POITabBarController * tabController = (id) self.tabBarController;
	NSString * geometry = tabController.selection ? [tabController.selection geometryName] : GEOMETRY_NODE;
	NSString * oldFeatureName = [CommonTagList featureNameForObjectDict:tabController.keyValueDict geometry:geometry];
	CommonTagFeature * oldFeature = [CommonTagFeature commonTagFeatureWithName:oldFeatureName];

	// remove previous feature tags
	[oldFeature.removeTags enumerateKeysAndObjectsUsingBlock:^(NSString * key, NSString * value, BOOL *stop) {
		[tabController setFeatureKey:key value:nil];
	}];

	// add new feature tags
	NSDictionary * defaults = [feature defaultValuesForGeometry:geometry];
	[defaults enumerateKeysAndObjectsUsingBlock:^(NSString * key, NSString * value, BOOL *stop) {
		if ( tabController.keyValueDict[key] == nil ) {
			[tabController setFeatureKey:key value:value];
		}
	}];
	NSDictionary * addTags = feature.addTags;
	[addTags enumerateKeysAndObjectsUsingBlock:^(NSString * key, NSString * value, BOOL *stop) {
		if ( [value isEqualToString:@"*"] )
			value = @"yes";
		[tabController setFeatureKey:key value:value];
	}];
}

- (NSString *)typeKeyForDict:(NSDictionary *)dict
{
	for ( NSString * tag in [OsmBaseObject typeKeys] ) {
		NSString * value = dict[ tag ];
		if ( value.length ) {
			return tag;
		}
	}
	return nil;
}
- (NSString *)typeStringForDict:(NSDictionary *)dict
{
	NSString * tag = [self typeKeyForDict:dict];
	NSString * value = dict[ tag ];
	if ( value.length ) {
		NSString * text = [NSString stringWithFormat:@"%@ (%@)", value, tag];
		text = [text stringByReplacingOccurrencesOfString:@"_" withString:@" "];
		text = text.capitalizedString;
		return text;
	}
	return nil;
}

#pragma mark - Table view data source

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	[cell fixConstraints];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	// Fix bug on iPad where cell heights come back as -1:
	// CGFloat h = [super tableView:tableView heightForRowAtIndexPath:indexPath];
	return 44.0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return _tags.sectionCount + 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if ( section == _tags.sectionCount )
		return nil;
	if ( section > _tags.sectionCount )
		return nil;
	CommonTagGroup * group = [_tags groupAtIndex:section];
	return group.name;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if ( section == _tags.sectionCount )
		return 1;
	if ( section > _tags.sectionCount )
		return 0;
	return [_tags tagsInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ( YES ) {

		if ( indexPath.section == _tags.sectionCount ) {
			UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"CustomizePresets" forIndexPath:indexPath];
			return cell;
		}
		if ( indexPath.section > _tags.sectionCount )
			return nil;

		NSString * key = [_tags tagAtIndexPath:indexPath].tagKey;
		NSString * cellName = key == nil || [key isEqualToString:@"name"] ? @"CommonTagType" : @"CommonTagSingle";

		CommonTagCell * cell = [tableView dequeueReusableCellWithIdentifier:cellName forIndexPath:indexPath];
		CommonTagKey * commonTag = [_tags tagAtIndexPath:indexPath];
		cell.nameLabel.text = commonTag.name;
		cell.valueField.placeholder = commonTag.placeholder;
		cell.valueField.delegate = self;
		cell.valueField.textColor = [UIColor colorWithRed:0.22 green:0.33 blue:0.53 alpha:1.0];
		cell.commonTag = commonTag;

		cell.valueField.keyboardType = commonTag.keyboardType;
		cell.valueField.autocapitalizationType = commonTag.autocapitalizationType;
		[cell.valueField removeTarget:self action:NULL forControlEvents:UIControlEventAllEvents];
		[cell.valueField addTarget:self action:@selector(textFieldReturn:)			forControlEvents:UIControlEventEditingDidEndOnExit];
		[cell.valueField addTarget:self action:@selector(textFieldChanged:)			forControlEvents:UIControlEventEditingChanged];
		[cell.valueField addTarget:self action:@selector(textFieldEditingDidBegin:)	forControlEvents:UIControlEventEditingDidBegin];
		[cell.valueField addTarget:self action:@selector(textFieldDidEndEditing:)	forControlEvents:UIControlEventEditingDidEnd];

		cell.accessoryType = commonTag.presetList.count ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;

		POITabBarController	* tabController = (id)self.tabBarController;
		NSDictionary * objectDict = tabController.keyValueDict;

		if ( indexPath.section == 0 && indexPath.row == 0 ) {
			// Type cell
			NSString * text = [_tags featureName];
			if ( text == nil )
				text = [self typeStringForDict:objectDict];
			cell.valueField.text = text;
			cell.valueField.enabled = NO;
		} else {
			// Regular cell
			NSString * value = objectDict[ commonTag.tagKey ];
			value = [CommonTagList friendlyValueNameForKey:commonTag.tagKey value:value geometry:nil];
			cell.valueField.text = value;
			cell.valueField.enabled = YES;
		}

		return cell;

	} else {

//		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CommonTagDouble" forIndexPath:indexPath];
//		return cell;
	}
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	CommonTagCell * cell = (id) [tableView cellForRowAtIndexPath:indexPath];
	if ( cell.accessoryType == UITableViewCellAccessoryNone )
		return;
	if ( indexPath.section == 0 && indexPath.row == 0 ) {
		[self performSegueWithIdentifier:@"POITypeSegue" sender:cell];
	} else {
		[self performSegueWithIdentifier:@"POIPresetSegue" sender:cell];
	}
}
-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	CommonTagCell * cell = sender;
	if ( [segue.destinationViewController isKindOfClass:[POIPresetViewController class]] ) {
		POIPresetViewController * preset = segue.destinationViewController;
		preset.tag = cell.commonTag.tagKey;
		preset.valueDefinitions = cell.commonTag.presetList;
		preset.navigationItem.title = cell.commonTag.name;
	} else if ( [segue.destinationViewController isKindOfClass:[POITypeViewController class]] ) {
		POITypeViewController * dest = (id)segue.destinationViewController;
		dest.delegate = self;
	}
}

-(IBAction)cancel:(id)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

-(IBAction)done:(id)sender
{
	[self resignAll];
	[self dismissViewControllerAnimated:YES completion:nil];

	POITabBarController * tabController = (id)self.tabBarController;
	[tabController commitChanges];
}

#pragma mark - Table view delegate


- (void)resignAll
{
	for (CommonTagCell * cell in self.tableView.visibleCells) {
		[cell.valueField resignFirstResponder];
		[cell.valueField2 resignFirstResponder];
	}
}


- (IBAction)textFieldReturn:(id)sender
{
	[sender resignFirstResponder];
}

-(CommonTagCell *)cellForTextField:(UITextField *)textField
{
	CommonTagCell * cell = (id) [textField superview];
	while ( cell && ![cell isKindOfClass:[CommonTagCell class]] ) {
		cell = (id)cell.superview;
	}
	return cell;
}

- (IBAction)textFieldEditingDidBegin:(UITextField *)textField
{
	if ( [textField isKindOfClass:[AutocompleteTextField class]] ) {

		// get list of values for current key
		CommonTagCell * cell = [self cellForTextField:textField];
		NSString * key = cell.commonTag.tagKey;
		if ( key == nil )
			return;	// should never happen
		NSSet * set = [CommonTagList allTagValuesForKey:key];
		AppDelegate * appDelegate = [AppDelegate getAppDelegate];
		NSMutableSet * values = [appDelegate.mapView.editorLayer.mapData tagValuesForKey:key];
		[values addObjectsFromArray:[set allObjects]];
		NSArray * list = [values allObjects];
		[(AutocompleteTextField *)textField setCompletions:list];
	}
}

- (IBAction)textFieldChanged:(UITextField *)textField
{
	_saveButton.enabled = YES;
}

- (IBAction)textFieldDidEndEditing:(UITextField *)textField
{
	CommonTagCell * cell = [self cellForTextField:textField];
	NSString * key = cell.commonTag.tagKey;
	if ( key == nil )
		return;	// should never happen
	NSString * value = textField.text;
	value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	textField.text = value;

	POITabBarController * tabController = (id)self.tabBarController;

	if ( value.length ) {
		[tabController.keyValueDict setObject:value forKey:key];
	} else {
		[tabController.keyValueDict removeObjectForKey:key];
	}

	_saveButton.enabled = [tabController isTagDictChanged];
}

@end
