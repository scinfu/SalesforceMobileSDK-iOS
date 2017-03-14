//
//  SFUserAccountManagerPersisterTests.m
//  SalesforceSDKCore
//
//  Created by Raj Rao on 3/13/17.
//  Copyright © 2017 salesforce.com. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFDefaultUserAccountPersister.h"
#import "SFUserAccountPersisterEphemeral.h"
#import "SFUserAccountManager.h"

static NSString * const kUserIdFormatString = @"005R0000000Dsl%lu";
static NSString * const kOrgIdFormatString = @"00D000000000062EA%lu";

@interface SFUserAccountManagerPersisterTests : XCTestCase
@property (nonatomic, strong) SFUserAccountManager *uam;
@end

@interface TestUserAccountManagerPersisterDelegate : NSObject <SFUserAccountManagerDelegate>

@property (nonatomic, strong) SFUserAccount *willSwitchOrigUserAccount;
@property (nonatomic, strong) SFUserAccount *willSwitchNewUserAccount;
@property (nonatomic, strong) SFUserAccount *didSwitchOrigUserAccount;
@property (nonatomic, strong) SFUserAccount *didSwitchNewUserAccount;

@end

@implementation TestUserAccountManagerPersisterDelegate

- (id)init {
    self = [super init];
    if (self) {
        [[SFUserAccountManager sharedInstance] addDelegate:self];
    }
    return self;
}

- (void)dealloc {
    [[SFUserAccountManager sharedInstance] removeDelegate:self];
}

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
        willSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser {
    self.willSwitchOrigUserAccount = fromUser;
    self.willSwitchNewUserAccount = toUser;
}

- (void)userAccountManager:(SFUserAccountManager *)userAccountManager
         didSwitchFromUser:(SFUserAccount *)fromUser
                    toUser:(SFUserAccount *)toUser {
    self.didSwitchOrigUserAccount = fromUser;
    self.didSwitchNewUserAccount = toUser;
}

@end

@implementation SFUserAccountManagerPersisterTests

- (void)setUp {
    [super setUp];
    [SFUserAccountManager setAccountPersisterClass:[SFUserAccountPersisterEphemeral class]];
    [[SFUserAccountManager sharedInstance] reload];
    self.uam = [SFUserAccountManager sharedInstance];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [SFUserAccountManager setAccountPersisterClass:nil];
    [[SFUserAccountManager sharedInstance] reload];
    [super tearDown];
    
}

- (void)testAccountIdentityEquality {
    NSDictionary *accountIdentityMatrix = @{
            @"MatchGroup1": @[
                    [[SFUserAccountIdentity alloc] initWithUserId:nil orgId:nil],
                    [[SFUserAccountIdentity alloc] initWithUserId:nil orgId:nil]
            ],
            @"MatchGroup2": @[
                    [[SFUserAccountIdentity alloc] initWithUserId:nil orgId:@"OrgID1"],
                    [[SFUserAccountIdentity alloc] initWithUserId:nil orgId:@"OrgID1"]
            ],
            @"MatchGroup3": @[
                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID1" orgId:nil],
                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID1" orgId:nil]
            ],
            @"MatchGroup4": @[
                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID1" orgId:@"OrgID1"],
                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID1" orgId:@"OrgID1"]
            ],
            @"MatchGroup5": @[
                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID2" orgId:@"OrgID2"],
                    [[SFUserAccountIdentity alloc] initWithUserId:@"UserID2" orgId:@"OrgID2"]
            ]
    };
    NSArray *keys = [accountIdentityMatrix allKeys];
    for (NSUInteger i = 0; i < [keys count]; i++) {

        // Equality
        NSArray *equalIdentitiesArray = accountIdentityMatrix[keys[i]];
        for (NSUInteger j = 0; j < [equalIdentitiesArray count]; j++) {
            SFUserAccountIdentity *obj1 = equalIdentitiesArray[j];
            for (NSUInteger k = 0; k < [equalIdentitiesArray count]; k++) {
                SFUserAccountIdentity *obj2 = equalIdentitiesArray[k];
                XCTAssertEqualObjects(obj1, obj2, @"Account identity '%@' and '%@' should be equal", obj1, obj2);
            }
        }

        // Inequality
        for (NSUInteger j = 0; j < [equalIdentitiesArray count]; j++) {
            SFUserAccountIdentity *obj1 = equalIdentitiesArray[j];
            for (NSUInteger k = 0; k < [keys count]; k++) {
                if (k == i) continue;
                NSArray *unequalIdentitiesArray = accountIdentityMatrix[keys[k]];
                for (NSUInteger l = 0; l < [unequalIdentitiesArray count]; l++) {
                    SFUserAccountIdentity *obj2 = unequalIdentitiesArray[l];
                    XCTAssertFalse([obj1 isEqual:obj2], @"Account identity '%@' and '%@' should NOT be equal", obj1, obj2);
                }
            }
        }
    }
}

- (void)testAccountIdentityUpdateFromCredentialsUpdate {
    NSArray *accounts = [self createAndVerifyUserAccounts:1];
    SFUserAccount *user = accounts[0];
    XCTAssertEqual(user.accountIdentity.userId, user.credentials.userId, @"Account identity UserID and credentials User ID should be equal.");
    XCTAssertEqual(user.accountIdentity.orgId, user.credentials.organizationId, @"Account identity UserID and credentials User ID should be equal.");

    // Changed credentials IDs.
    user.credentials.userId = @"NewUserId";
    user.credentials.organizationId = @"NewOrgId";
    XCTAssertEqual(user.accountIdentity.userId, @"NewUserId", @"Updated User ID in credentials not reflected in account identity.");
    XCTAssertEqual(user.accountIdentity.orgId, @"NewOrgId", @"Updated Org ID in credentials not reflected in account identity.");

    // Swap out credentials entirely.
    NSString *newCredentialsIdentifier = [NSString stringWithFormat:@"%@_1", user.credentials.identifier];
    SFOAuthCredentials *newCreds = [[SFOAuthCredentials alloc] initWithIdentifier:newCredentialsIdentifier clientId:user.credentials.clientId encrypted:YES];
    newCreds.userId = @"NewCredsUserId";
    newCreds.organizationId = @"NewCredsOrgId";
    user.credentials = newCreds;
    XCTAssertEqual(user.accountIdentity.userId, @"NewCredsUserId", @"User ID in new credentials not reflected in account identity.");
    XCTAssertEqual(user.accountIdentity.orgId, @"NewCredsOrgId", @"Org ID in new credentials not reflected in account identity.");
}

- (void)testSingleAccount {
   
    [self.uam clearAllAccountState];
    // Ensure we start with a clean state
    XCTAssertTrue(self.uam.allUserIdentities.count==0, @"There should be no accounts");

    // Create a single user
    NSArray *accounts = [self createAndVerifyUserAccounts:1];
    SFUserAccount *user = accounts[0];
    
    if ([self.uam allUserAccounts].count==1)
    
    XCTAssertEqual([self.uam allUserAccounts].count, (NSUInteger)1, @"There should be one account");

    // Now remove all the users and re-load
    [self.uam clearAllAccountState];
    XCTAssertEqual([self.uam.allUserAccounts count], (NSUInteger)0, @"There should be no accounts");

    [self.uam loadAccounts:nil];
    
    XCTAssertTrue([self.uam allUserAccounts].count>0, @"Unable to load user accounts: %@");
    NSString *userId = [NSString stringWithFormat:kUserIdFormatString, (unsigned long)0];
    XCTAssertEqualObjects(((SFUserAccountIdentity *)self.uam.allUserIdentities[0]).userId, userId, @"User ID doesn't match after reload");
    [self deleteUserAndVerify:user];
}

- (void)testMultipleAccounts {
    // Ensure we start with a clean state
    [self.uam clearAllAccountState];
    XCTAssertEqual([self.uam.allUserIdentities count], (NSUInteger)0, @"There should be no accounts");

    // Create 10 users
    [self createAndVerifyUserAccounts:10];
    XCTAssertEqual([self.uam allUserAccounts].count, (NSUInteger)10, @"There should be 10 accounts");
    
    // Reload all accounts
    {
        [self.uam clearAllAccountState];
        XCTAssertEqual([self.uam.allUserIdentities count], (NSUInteger)0, @"There should be no accounts");
        NSError *error =nil;
        [self.uam loadAccounts:&error];
        NSArray * accounts = [self.uam allUserAccounts];
        XCTAssertNil(error, @"Accounts should have been loaded");
        XCTAssertEqual(accounts.count,10,@"Must have 10 accounts");
    }

    // Remove and verify that allUserAccounts property implicitly loads the accounts from disk.
    [self.uam clearAllAccountState];
    NSError *error =nil;
    [self.uam loadAccounts:&error];
    XCTAssertNil(error, @"Accounts should have been loaded");
    // Now make sure each account has a different access token to ensure
    // they are not overlapping in the keychain.
    NSMutableSet *allTokens = [NSMutableSet new];
    NSArray *allIdentities = self.uam.allUserIdentities;
    for (NSUInteger index=0; index<10; index++) {
        SFUserAccount *user = [self.uam userAccountForUserIdentity:allIdentities[index]];
        if (![allTokens containsObject:user.credentials.accessToken]) {
            [allTokens addObject:user.credentials.accessToken];
        }
    }
    XCTAssertEqual(allTokens.count,10, @"Should not contain overlapping tokens");

    // Remove each account and verify that its user folder is gone.
    for (NSUInteger index = 0; index < 10; index++) {
        NSString *orgId = [NSString stringWithFormat:kOrgIdFormatString, (unsigned long)index];
        NSString *userId = [NSString stringWithFormat:kUserIdFormatString, (unsigned long)index];
       
        SFUserAccountIdentity *accountIdentity = [[SFUserAccountIdentity alloc] initWithUserId:userId orgId:orgId];

        SFUserAccount *userAccount = [self.uam userAccountForUserIdentity:accountIdentity];
        XCTAssertNotNil(userAccount, @"User acccount with User ID '%@' and Org ID '%@' should exist.", userId, orgId);
        [self deleteUserAndVerify:userAccount];
    }
}

- (void)testSwitchToUser {
    NSArray *accounts = [self createAndVerifyUserAccounts:2];
    SFUserAccount *origUser = accounts[0];
    SFUserAccount *newUser = accounts[1];
    self.uam.currentUser = origUser;
    TestUserAccountManagerPersisterDelegate *acctDelegate = [[TestUserAccountManagerPersisterDelegate alloc] init];
    [self.uam switchToUser:newUser];
    XCTAssertEqual(acctDelegate.willSwitchOrigUserAccount, origUser, @"origUser is not equal.");
    XCTAssertEqual(acctDelegate.willSwitchNewUserAccount, newUser, @"New user should be the same as the argument to switchToUser.");
    XCTAssertEqual(acctDelegate.didSwitchOrigUserAccount, origUser, @"origUser is not equal.");
    XCTAssertEqual(acctDelegate.didSwitchNewUserAccount, newUser, @"New user should be the same as the argument to switchToUser.");
    XCTAssertEqual(self.uam.currentUser, newUser, @"The current user should be set to newUser.");
    [self deleteUserAndVerify:origUser];
    [self deleteUserAndVerify:newUser];
}



- (void)testIdentityDataModification {
    NSArray *accounts = [self createAndVerifyUserAccounts:1];
    self.uam.currentUser = accounts[0];
    SFIdentityData *idData = [self sampleIdentityData];
    [self.uam applyIdData:idData];
    int origMobileAppPinLength = self.uam.currentUser.idData.mobileAppPinLength;
    int origMobileAppScreenLockTimeout = self.uam.currentUser.idData.mobileAppScreenLockTimeout;

    // Verify selective custom settings updates do not interfere with other previous identity data.
    NSDictionary *origCustomAttributes = self.uam.currentUser.idData.customAttributes;
    NSDictionary *origCustomPermissions = self.uam.currentUser.idData.customPermissions;
    NSMutableDictionary *mutableCustomAttributes = [origCustomAttributes mutableCopy];
    NSMutableDictionary *mutableCustomPermissions = [origCustomPermissions mutableCopy];
    mutableCustomAttributes[@"ANewCustomAttribute"] = @"ANewCustomAttributeValue";
    mutableCustomPermissions[@"ANewCustomPermission"] = @"ANewCustomPermissionValue";
    [self.uam applyIdDataCustomAttributes:mutableCustomAttributes];
    [self.uam applyIdDataCustomPermissions:mutableCustomPermissions];
    XCTAssertTrue([self.uam.currentUser.idData.customAttributes isEqualToDictionary:mutableCustomAttributes], @"Attributes dictionaries are not equal.");
    XCTAssertFalse([self.uam.currentUser.idData.customAttributes isEqualToDictionary:origCustomAttributes], @"Attributes dictionaries should not be equal.");
    XCTAssertTrue([self.uam.currentUser.idData.customPermissions isEqualToDictionary:mutableCustomPermissions], @"Permissions dictionaries are not equal.");
    XCTAssertFalse([self.uam.currentUser.idData.customPermissions isEqualToDictionary:origCustomPermissions], @"Permissions dictionaries should not be equal.");
    XCTAssertEqual(origMobileAppPinLength, self.uam.currentUser.idData.mobileAppPinLength, @"Mobile app pin length should not have changed.");
    XCTAssertEqual(origMobileAppScreenLockTimeout, self.uam.currentUser.idData.mobileAppScreenLockTimeout, @"Mobile app screen lock timeout should not have changed.");

    // Verify that re-applying the whole of the identity data, overwrites changes.
    idData = [self sampleIdentityData];
    [self.uam applyIdData:idData];
    XCTAssertTrue([self.uam.currentUser.idData.customAttributes isEqualToDictionary:origCustomAttributes], @"Custom atttribute changes should have been overwritten with whole identity write.");
    XCTAssertFalse([self.uam.currentUser.idData.customAttributes isEqualToDictionary:mutableCustomAttributes], @"Attributes dictionaries should not be equal.");
    XCTAssertTrue([self.uam.currentUser.idData.customPermissions isEqualToDictionary:origCustomPermissions], @"Custom permission changes should have been overwritten with whole identity write.");
    XCTAssertFalse([self.uam.currentUser.idData.customAttributes isEqualToDictionary:mutableCustomPermissions], @"Permissions dictionaries should not be equal.");
    [self deleteUserAndVerify:self.uam.currentUser];

}


#pragma mark - Helper methods

- (NSArray *)createAndVerifyUserAccounts:(NSUInteger)numAccounts {
    XCTAssertTrue(numAccounts > 0, @"You must create at least one account.");
    NSMutableArray *accounts = [NSMutableArray array];
    for (NSUInteger index = 0; index < numAccounts; index++) {
        SFUserAccount *user = [self createNewUserWithIndex:index];
        user.credentials.accessToken = [NSString stringWithFormat:@"accesstoken-%lu", (unsigned long)index];
        XCTAssertNotNil(user.credentials, @"User credentials shouldn't be nil");
        NSError *error = nil;
        [[SFUserAccountManager sharedInstance] saveAccountForUser:user error:&error];
        XCTAssertNil(error, @"Should be able to create user account");
        // Note: we always use index 0 because of the way the allUserIds are sorted out
        SFUserAccount *userAccount = [self.uam userAccountForUserIdentity:user.accountIdentity];
        XCTAssertEqualObjects(userAccount.accountIdentity.userId, ([NSString stringWithFormat:kUserIdFormatString, (unsigned long)index]), @"User ID doesn't match");
        XCTAssertEqualObjects(userAccount.accountIdentity.orgId, ([NSString stringWithFormat:kOrgIdFormatString, (unsigned long)index]), @"Org ID doesn't match");
        // Add to the output array.
        [accounts addObject:user];
    }

    return accounts;
}

- (SFUserAccount*)createNewUserWithIndex:(NSUInteger)index {
    XCTAssertTrue(index < 10, @"Supports only index up to 9");
    SFUserAccount *user = [[SFUserAccount alloc] initWithIdentifier:[NSString stringWithFormat:@"identifier-%lu", (unsigned long)index]];
    NSString *userId = [NSString stringWithFormat:kUserIdFormatString, (unsigned long)index];
    NSString *orgId = [NSString stringWithFormat:kOrgIdFormatString, (unsigned long)index];
    user.credentials.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://login.salesforce.com/id/%@/%@", orgId, userId]];
    return user;
}

- (void)deleteUserAndVerify:(SFUserAccount *)user {
    SFUserAccountIdentity *identity = user.accountIdentity;
    NSError *deleteAccountError = nil;
    [self.uam deleteAccountForUser:user error:&deleteAccountError];
    XCTAssertNil(deleteAccountError, @"Error deleting account with User ID '%@' and Org ID '%@': %@", identity.userId, identity.orgId, [deleteAccountError localizedDescription]);
    SFUserAccount *inMemoryAccount = [self.uam userAccountForUserIdentity:identity];
    XCTAssertNil(inMemoryAccount, @"deleteUser should have removed user account with User ID '%@' and OrgID '%@' from the list of users.", identity.userId, identity.orgId);
}

- (SFIdentityData *)sampleIdentityData {
    NSDictionary *sampleIdDataDict = @{
            @"mobile_phone" : @"+1 4155551234",
            @"first_name" : @"Test",
            @"mobile_phone_verified" : @YES,
            @"active" : @YES,
            @"utcOffset" : @(-28800000),
            @"username" : @"testuser@fake.salesforce.org",
            @"last_modified_date" : @"2013-04-19T22:12:04.000+0000",
            @"id" : @"https://test.salesforce.com/id/00DS0000000IDdtWAH/005S0000004y9JkCAF",
            @"locale" : @"en_US",
            @"urls" : @{
                    @"users" : @"https://cs1.salesforce.com/services/data/v{version}/chatter/users",
                    @"search" : @"https://cs1.salesforce.com/services/data/v{version}/search/",
                    @"metadata" : @"https://cs1.salesforce.com/services/Soap/m/{version}/00DS0000000IDdt",
                    @"query" : @"https://cs1.salesforce.com/services/data/v{version}/query/",
                    @"enterprise" : @"https://cs1.salesforce.com/services/Soap/c/{version}/00DS0000000IDdt",
                    @"profile" : @"https://cs1.salesforce.com/005S0000004y9JkCAF",
                    @"sobjects" : @"https://cs1.salesforce.com/services/data/v{version}/sobjects/",
                    @"groups" : @"https://cs1.salesforce.com/services/data/v{version}/chatter/groups",
                    @"rest" : @"https://cs1.salesforce.com/services/data/v{version}/",
                    @"feed_items" : @"https://cs1.salesforce.com/services/data/v{version}/chatter/feed-items",
                    @"recent" : @"https://cs1.salesforce.com/services/data/v{version}/recent/",
                    @"feeds" : @"https://cs1.salesforce.com/services/data/v{version}/chatter/feeds",
                    @"partner" : @"https://cs1.salesforce.com/services/Soap/u/{version}/00DS0000000IDdt"
            },
            @"addr_zip" : @"94105",
            @"addr_country" : @"US",
            @"asserted_user" : @YES,
            @"email_verified" : @YES,
            @"nick_name" : @"testuser1.3664094337872896E12",
            @"user_id" : @"005S0000004y9JkCAF",
            @"is_app_installed" : @YES,
            @"user_type" : @"STANDARD",
            @"addr_street" : @"123 Test User Ln",
            @"timezone" : @"America/Los_Angeles",
            @"mobile_policy" : @{
                    @"pin_length" : @"4",
                    @"screen_lock" : @"10"
            },
            @"organization_id" : @"00DS0000000IDdtWAH",
            @"addr_city" : @"Testville",
            @"addr_state" : @"CA",
            @"language" : @"en_US",
            @"last_name" : @"User",
            @"display_name" : @"Test User",
            @"photos" : @{
                    @"thumbnail" : @"https://c.cs1.content.force.com/profilephoto/729S00000009ZdF/T",
                    @"picture" : @"https://c.cs1.content.force.com/profilephoto/729S00000009ZdF/F"
            },
            @"email" : @"testuser@salesforce.nonexistentemail",
            @"custom_attributes" : @{
                    @"TestAttribute1" : @"TestVal1",
                    @"TestAttribute2" : @"TestVal2"
            },
            @"custom_permissions": @{
                    @"CustomPerm1" : @"CustomVal1",
                    @"CustomPerm2" : @"CustomVal2"
            },
            @"status" : @{
                    @"body" : [NSNull null],
                    @"created_date" : [NSNull null]
            }
    };
    SFIdentityData *idData = [[SFIdentityData alloc] initWithJsonDict:sampleIdDataDict];
    return idData;
}

@end
