//
//  
//  Copyright YoYo Games Ltd., 2015.
//  For support please submit a ticket at help.yoyogames.com
//
//


#import "FacebookExtension.h"


extern "C" void dsMapClear(int _dsMap );
extern "C" int dsMapCreate();
extern "C" void dsMapAddInt(int _dsMap, char* _key, int _value);
extern "C" void dsMapAddString(int _dsMap, char* _key, char* _value);
extern "C" int dsListCreate();
extern "C" void dsListAddInt(int _dsList, int _value);
extern "C" void dsListAddString(int _dsList, char* _value);

const int EVENT_OTHER_SOCIAL = 70;
//extern int CreateDsMap( int _num, ... );
//extern "C" void CreateAsynEventWithDSMap(int dsmapindex, int event_index);
extern "C" void createSocialAsyncEventWithDSMap(int dsmapindex);

static int s_requestID = 0;
static bool s_bPermissionsRequestInProgress = false;



@implementation FacebookExtension


- (id)init
{
    self = [super init];
    if (self)
    {
        // superclass successfully initialized, further
        // initialization happens here ...
        [self setLoginStatus: @"IDLE"];
    }
    
    return self;
}

- (void)FBinit;
{
    //facebook_init...appid must be in plist
    //..try to open cached session?
    //NB - login status may be already set to authorised in case of app cold start ( set via sessionStateChanged handler )
    
}

//TODO::appdelegate things...handleOpenUrl or something...

-(void)onResume
{
	[FBAppCall handleDidBecomeActive];
}

-(BOOL)onOpenURL:(NSURL*)url sourceApplication:(NSString*)sourceApplication
{

	//facebook handle "app cold starts" - need to re-set state change handler
    [FBSession.activeSession setStateChangeHandler:
     ^(FBSession *session, FBSessionState state, NSError *error) {
         
         [self sessionStateChanged:session state:state error:error];
     }];
    
    return [FBAppCall handleOpenURL:url sourceApplication:sourceApplication];

}

- (void)login:(NSArray*)_permissions loginType:(int)_loginType
{
    //set login type
    bool bDefaultLogin=false;
    FBSessionLoginBehavior eType;
    switch(_loginType)
    {
        //"fb_login_default", 0);
        case 1: //"fb_login_fallback_to_webview",1);
            eType = FBSessionLoginBehaviorWithFallbackToWebView; break;
        case 2: //"fb_login_no_fallback_to_webview",2);
            eType = FBSessionLoginBehaviorWithNoFallbackToWebView; break;
        case 3: //"fb_login_forcing_webview",3);
            eType = FBSessionLoginBehaviorForcingWebView; break;
        case 4: //"fb_login_use_system_account",4);
            eType = FBSessionLoginBehaviorUseSystemAccountIfPresent; break;
        case 5: //"fb_login_forcing_safari",5);
            eType = FBSessionLoginBehaviorForcingSafari; break;
        default:
            bDefaultLogin = true; break;
    }
    
    
    if (FBSession.activeSession.isOpen )
    {
        NSLog(@"facebook_login: session already open");
        [self setLoginStatus:@"AUTHORISED"];
        return;
    }
    
    [self setLoginStatus:@"PROCESSING"];
    if( bDefaultLogin)
    {
        //default behaviour will open safari if both native integration & facebook app are unavailable
        //which is a bad thing apparently...? how can this be the default then...???
        // You must ALWAYS ask for public_profile permissions when opening a session
        [FBSession openActiveSessionWithReadPermissions:_permissions allowLoginUI:YES
                                      completionHandler:
         ^(FBSession *session, FBSessionState state, NSError *error) {
             
             [self sessionStateChanged:session state:state error:error];
         }];
    }
    else
    {
        //use the login behaviour specified in the facebook_login fn
        NSLog(@"Login with behaviour:%d",eType);
        FBSession *session = [[FBSession alloc] initWithPermissions:_permissions];  //// Initialize a session object
        [FBSession setActiveSession:session];   // Set the active session
        // Open the session
        
        [session openWithBehavior:eType
                completionHandler:^(FBSession *session,
                                    FBSessionState state,
                                    NSError *error)
        {
                    [self sessionStateChanged:session state:state error:error];
        }];
    }

}

- (void)logout
{
    // Close the session and remove the access token from the cache
    // The session state handler will be called automatically
    //CHECK - do we need to check session is open first?
    [FBSession.activeSession closeAndClearTokenInformation];
}

- (NSString*)loginStatus
{
    return mLoginStatus;
}

- (void)setLoginStatus:(NSString*)_status
{
    NSLog(@"Setting login status to %@\n", _status);
    mLoginStatus = _status;
}

- (NSString *)accessToken
{
    FBAccessTokenData* accessTokenData = [FBSession.activeSession accessTokenData];
    if( accessTokenData != nil )
    {
        NSString* str = [accessTokenData accessToken];
        return str;
    }
    
    return @"";
}

- (NSString *)userId
{
    if (mUserId == nil) {
        return @"";
    }
    return mUserId;
}

- (void) makeRequestForUserData
{
    [FBRequestConnection startForMeWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        if (!error) {
            // Success!
            NSLog(@"user info: %@", result);
            NSString* userId = [result objectForKey:@"id"];
            mUserId = [[NSString alloc] initWithString:userId];
        } else {
            // An error occurred, we need to handle the error
            // Check out our error handling guide: https://developers.facebook.com/docs/ios/errors/
            NSLog(@"error %@", error.description);
        }
    }];
}

// This method will handle ALL the session state changes in the app
- (void)sessionStateChanged:(FBSession *)session state:(FBSessionState) state error:(NSError *)error
{
    if( error )
    {
        [self handleAuthError:error ];
        return;
    }
    
    // If the session was opened successfully
    if (state == FBSessionStateOpen || state == FBSessionStateOpenTokenExtended){
        //NSLog(@"Session opened");
        [self setLoginStatus:@"AUTHORISED"];
        //request user id...
        if( mUserId == nil )
        {
            [self makeRequestForUserData];
        }
        return;
    }
    if (state == FBSessionStateClosed || state == FBSessionStateClosedLoginFailed){
        // If the session is closed
        NSLog(@"Session closed");
        [self setLoginStatus:@"IDLE"];
    }
}

- (void)handleAuthError:(NSError *)error
{
    NSLog(@"Facebook Auth Error");
    NSLog(@"%@",error.description);
    NSString *alertText;
    NSString *alertTitle;
    // If the error requires people using an app to make an action outside of the app in order to recover
    if ([FBErrorUtility shouldNotifyUserForError:error] == YES){
        alertTitle = @"Something went wrong";
        alertText = [FBErrorUtility userMessageForError:error];
        //[self showMessage:alertText withTitle:alertTitle];
    } else {
        
        // If the user cancelled login, do nothing
        if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryUserCancelled) {
            NSLog(@"User cancelled login");
            
            // Handle session closures that happen outside of the app
        } else if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryAuthenticationReopenSession){
            alertTitle = @"Session Error";
            alertText = @"Your current session is no longer valid. Please log in again.";
            //[self showMessage:alertText withTitle:alertTitle];
            
            // For simplicity, here we just show a generic message for all other errors
            // You can learn how to handle other errors using our guide: https://developers.facebook.com/docs/ios/errors
        } else {
            //Get more error information from the error
            NSDictionary *errorInformation = [[[error.userInfo objectForKey:@"com.facebook.sdk:ParsedJSONResponseKey"] objectForKey:@"body"] objectForKey:@"error"];
            
            // Show the user an error message
            alertTitle = @"Something went wrong";
            alertText = [NSString stringWithFormat:@"Please retry. \n\n If the problem persists contact us and mention this error code: %@", [errorInformation objectForKey:@"message"]];
            //[self showMessage:alertText withTitle:alertTitle];
        }
    }
    // Clear this token
    [FBSession.activeSession closeAndClearTokenInformation];
    // Show the user the logged-out UI
    [self setLoginStatus:@"FAILED"];
}

-(void)parseInviteDialogResult:(NSURL*) resultURL dsMap:(int)map
{
    NSString* query=[resultURL absoluteString];
    NSArray *components = [query componentsSeparatedByString:@"&"];
    int len = [components count];
    if( len > 1)
    {
        int dsListIndex = dsListCreate();
        
        int i=0;
        for (NSString *component in components)
        {
            NSArray *subcomponents = [component componentsSeparatedByString:@"="];
            len = [subcomponents count];
            if( len >1)
            {
                const char* key=[[subcomponents objectAtIndex:0] UTF8String];
                const char* val=[[subcomponents objectAtIndex:1] UTF8String];
                //[myArray addObject:val];
                if( i==0 ) {
                    dsMapAddString( map, (char*)key,(char*)val );
                    NSString* to = @"to";
                    dsMapAddInt(map, (char*)[to UTF8String], dsListIndex);
                }
                else
                {
                    dsListAddString(dsListIndex, (char*)val );
                }
            }
            ++i;
        }
    }

}

- (void)showDialog:(NSString*)dialogType params:(NSMutableDictionary*)params userData:(int)userData
{
    int mapIndex = userData; //for ds map response...
    //clear the map!
    if( mapIndex>=0)
    {
        dsMapClear(mapIndex);
    }
    bool bInviteDialog = [dialogType isEqualToString:@"apprequests"];
    
    [FBWebDialogs presentDialogModallyWithSession:nil dialog:dialogType parameters:params
        handler:^(FBWebDialogResult result, NSURL *resultURL, NSError *error)
        {
            if (error) {
                // An error occurred, we need to handle the error
                // See: https://developers.facebook.com/docs/ios/errors
                NSLog(@"Error publishing story: %@", error.description);
            } else {
                NSLog(@"dialog result: %d", result );
                if (result == FBWebDialogResultDialogNotCompleted) {
                    // User canceled.
                    NSLog(@"- User cancelled.");
                } else {
                    // Handle the publish feed callback
                    NSLog(@"- completed with result:%@", [resultURL absoluteString]);
                    
                    //do we get params in case of error...?TEST
                    if(mapIndex >=0 && resultURL != nil)
                    {
                        if( bInviteDialog)
                        {
                            //special case for invite dialog return data to be consistent with html5 response
                            [self parseInviteDialogResult:resultURL dsMap:mapIndex];
                        }
                        else
                        {
                            //fill return map
                            NSMutableDictionary *urlParams = [self parseURLParams:[resultURL query]];
                            if( urlParams !=nil)
                            {
                                [self extractJSONData:urlParams dsMapIndex:mapIndex];
                                [urlParams release];
                            }
                        }
                    }
                }
            }
            
        }];
}

//graphRequest:nsGraphPath httpMethod:nsHttpMethod params:params dsMap:_dsMapIndex ];
-(void)graphRequest:(NSString*)_graphPath httpMethod:(NSString*)_httpMethod params:(NSMutableDictionary*)_params dsMap:(int)_dsMap
{
    if( !FBSession.activeSession.isOpen)
    {
        NSLog(@"facebook graph request error: facebook session must be open");
        return;
    }
    
    //clear the map!
    if( _dsMap >=0)
    {
        dsMapClear(_dsMap);
    }
    
    int dsMapIndex = _dsMap;
    
    //OR-if we want to set graph API version...
    //FBRequest *request = [FBRequest requestWithGraphPath:_graphPath parameters:_params HTTPMethod:_httpMethod];
    //NSString* graphVersion =@"v1.0"; //TESTING - select graph version...?
    //[request overrideVersionPartWith:graphVersion];
    //[request startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error)
    
    
    [FBRequestConnection startWithGraphPath:_graphPath parameters:_params HTTPMethod:_httpMethod
                          completionHandler:^(FBRequestConnection *connection, id result, NSError *error)
     {
         if (!error) {
             // Success! Include your code to handle the results here
             NSLog(@"graphRequest Result: %@", result);
         } else {
             // An error occurred, we need to handle the error
             // Check out our error handling guide: https://developers.facebook.com/docs/ios/errors/
             NSLog(@"error %@", error.description);
         }
         
         //do we still get result in case of error? no - should pass error to response_text instead
         if(dsMapIndex >=0)
         {
             //[result
             //how the heck to we get a dictionary from this...or is it already a dictionary...???
             /*NSString* requestResponse = [[NSString alloc] initWithData:[connection urlResponse] encoding:NSASCIIStringEncoding];
             NSLog(@"FBRequest %@ didLoad\n", requestResponse);
             
             // Convert response into JSON and populate the ds_map if one is theoretically available
             NSMutableDictionary* storageDictionary = [requestResponse JSONValue];
             if (storageDictionary != nil)
             {
                 NSLog(@"FBRequest returned valid JSON data\n");
                 [self extractJSONData:storageDictionary dsMapIndex:dsMapIndex];
             }
             [requestResponse release];*/
             
             //...OR...what if result is not dictionary?...i think it probably is...
             //TODO::add raw text response to map?
             NSString* desc = [result description];
             if( result != nil)
             {
                 dsMapAddString(dsMapIndex, "response_text",(char*)[desc UTF8String]);
             
                 if( [result isKindOfClass:[NSDictionary class]] )
                 {
                     [self extractJSONData:result dsMapIndex:dsMapIndex];
                 }
             }
             else if( error )
             {
                 dsMapAddString(dsMapIndex, "response_text", (char*)[error.description UTF8String]);
             }
         }
     }];
}


// A function for parsing URL parameters returned by the Feed Dialog.
- (NSMutableDictionary*)parseURLParams:(NSString *)query
{
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    for (NSString *pair in pairs) {
        NSArray *kv = [pair componentsSeparatedByString:@"="];
        NSString *val =[kv[1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString*key = [kv[0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        params[key] = val;
    }
    return params;
}

// Handles the situation where an array is found within the json data
- (void)extractJSONDataArray:(NSArray*)objArray dsListIndex:(int)dsListIndex
{
    for (int arrayIndex = 0; arrayIndex < [objArray count]; ++arrayIndex)
    {
        NSObject* arrayObj = [objArray objectAtIndex:arrayIndex];
        if ([arrayObj isKindOfClass:[NSArray class]])
        {
            // Create a new ds_list for the array
            int dsNewListIndex = dsListCreate();
            
            // Add this map index to the list
            dsListAddInt(dsListIndex, dsNewListIndex);
            
            NSLog(@"Added ds_list %d to ds_list %d", dsNewListIndex, dsListIndex);
            
            // Add the ds_list index to the ds_map for the current key
            NSArray* objArray = (NSArray*)arrayObj;
            [self extractJSONDataArray:objArray dsListIndex:dsNewListIndex];
        }
        else if ([arrayObj isKindOfClass:[NSDictionary class]])
        {
            // Create a new ds_map and get the index for it...
            int subDsMap = dsMapCreate();
            
            // Add this map index to the list
            dsListAddInt(dsListIndex, subDsMap);
            
            // Recurse to parse the new dictionary
            NSDictionary* dictObj = (NSDictionary*)arrayObj;
            [self extractJSONData:dictObj dsMapIndex:subDsMap];
            
            NSLog(@"Added ds_map %d to ds_list %d", subDsMap, dsListIndex);
        }
        else if ([arrayObj isKindOfClass:[NSString class]])
        {
            // Add the string to the list
            NSString* str = (NSString*)arrayObj;
            char currentVal[256];
            [str getCString:currentVal maxLength:256 encoding:NSASCIIStringEncoding];
            dsListAddString(dsListIndex, currentVal);
            
            NSLog(@"Added %@ to ds_list %d", str, dsListIndex);
        }
    }
}

// Builds a ds_map from the jsonData contained in the given dictionary
- (void)extractJSONData:(NSDictionary*)jsonData dsMapIndex:(int)dsMapIndex
{
    NSArray* keys = [jsonData allKeys];
    for (int n = 0; n < [keys count]; ++n)
    {
        // Extract the current key in a form the C++ can use
        NSString* nsKey = [keys objectAtIndex:n];
        char currentKey[256];
        [nsKey getCString:currentKey maxLength:256 encoding:NSASCIIStringEncoding];
        
        NSObject* obj = [jsonData objectForKey:[keys objectAtIndex:n]];
        if ([obj isKindOfClass:[NSArray class]])
        {
            // Create a new ds_list for the array
            int dsListIndex = dsListCreate();
            
            // Add this map index to the list
            dsMapAddInt(dsMapIndex, currentKey, dsListIndex);
            
            NSLog(@"Added ds_list %d to ds_map %d for key %@", dsListIndex, dsMapIndex, nsKey);
            
            // Add the ds_list index to the ds_map for the current key
            NSArray* objArray = (NSArray*)obj;
            [self extractJSONDataArray:objArray dsListIndex:dsListIndex];
        }
        else if ([obj isKindOfClass:[NSDictionary class]])
        {
            // Create a new ds_map and get the index for it...
            int subDsMap = dsMapCreate();
            
            // Add this to the current ds_map
            dsMapAddInt(dsMapIndex, currentKey, subDsMap);
            
            // And recurse to parse the new dictionary
            NSDictionary* dictObj = (NSDictionary*)obj;
            [self extractJSONData:dictObj dsMapIndex:subDsMap];
            
            NSLog(@"Added new ds_map %d to ds_map %d for key %@", subDsMap, dsMapIndex, nsKey);
        }
        else if ([obj isKindOfClass:[NSString class]])
        {
            // Add the string to the map with the current key
            NSString* str = (NSString*)obj;
            char currentVal[256];
            [str getCString:currentVal maxLength:256 encoding:NSASCIIStringEncoding];
            dsMapAddString(dsMapIndex, currentKey, currentVal);
            
            NSLog(@"Added %@ to ds_map %d for key %@", str, dsMapIndex, nsKey);
        }
        else if([obj isKindOfClass:[NSNumber class] ])
        {
            NSNumber *num = (NSNumber *)obj;
            NSInteger val = [num integerValue];
            dsMapAddInt(dsMapIndex, currentKey, val);
            NSLog(@"Added %d to ds_map %d for key %@", val, dsMapIndex, nsKey);
        }
    }
}


-(bool)checkPermission:(NSString*)permission
{
    if( FBSession.activeSession.isOpen)
    {
        //CHECK-does this update when we add new permissions after login? or do we need to maintain our own list or do a graph query (annoying since async...)
        NSArray* perms = FBSession.activeSession.permissions;
        NSLog(@"fb permissions: %@", perms);
        if( [perms containsObject:permission])
        {
            return true;
        }
    }
    else
    {
        NSLog(@"Facebook session must be open to query permissions");
    }
    return false;
}

-(void)requestPublishPermissions:(NSArray*)_permissions requestId:(int)_requestId
{
    FBSessionDefaultAudience audience = FBSessionDefaultAudienceFriends;    //pass as param?
    // Ask for the missing publish permissions
    [FBSession.activeSession requestNewPublishPermissions:_permissions defaultAudience:audience
        completionHandler:^(FBSession *session, NSError *error)
        {
            [self permissionsRequestResponse:session error:error requestId:_requestId];
        }];
}

-(void)requestReadPermissions:(NSArray*)_permissions requestId:(int)_requestId
{
    NSLog(@"requestReadPermissions: %@ %d", _permissions, _requestId);
    [FBSession.activeSession requestNewReadPermissions:_permissions
        completionHandler:^(FBSession *session, NSError *error)
        {
            [self permissionsRequestResponse:session error:error requestId:_requestId];
        }];
}



-(void)permissionsRequestResponse:(FBSession*)session error:(NSError*)error requestId:(int)_requestId
{
    //LOGGING ....
    NSString* alertText;
    if (!error) {
        // Permission granted
        NSLog(@"new permissions %@", [FBSession.activeSession permissions]);
    } else {
        NSLog(@"error %@", error.description);

        if ([FBErrorUtility shouldNotifyUserForError:error] == YES){
            // Error requires people using an app to make an out-of-band action to recover
            //alertTitle = @"Something went wrong";
            alertText = [FBErrorUtility userMessageForError:error];
        } else {
            // We need to handle the error
            if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryUserCancelled) {
                // Ignore it or...
                //alertTitle = @"Permission not granted";
                alertText = @"Your post could not be completed because you didn't grant the necessary permissions.";
                //[self showMessage:alertText withTitle:alertTitle];
                
            } else{
                // All other errors that can happen need retries
                // Show the user a generic error message
                //alertTitle = @"Something went wrong";
                alertText = @"Please retry";
                
            }   
        }
        NSLog(@"permissions request error: %@",alertText );
    }

    //TODO::return result as async event, or something... need request id!
    if( error )
    {
        if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryUserCancelled)
        {
            //user denied
            [self returnPermissionRequestResult:_requestId success:false denied:true error:nil];
        }
        else
        {
            //some other error
            [self returnPermissionRequestResult:_requestId success:false denied:false error:error];
        }
    }
    else
    {
        // Permission granted
        [self returnPermissionRequestResult:_requestId success:true denied:false error:nil];
    }
    s_bPermissionsRequestInProgress = false;
}

//return async event with result map
-(void)returnPermissionRequestResult:(int)_requestId success:(bool)_bSuccess denied:(bool)_bDenied error:(NSError*)_error
{
    int dsMapIndex = dsMapCreate();
    dsMapAddInt(dsMapIndex, "requestId", _requestId );
    dsMapAddString(dsMapIndex, "type", "facebook_permission_request");
    if( _bSuccess)
    {
        //permission granted or already available
        dsMapAddString(dsMapIndex, "result", "granted");
    }
    else if( _bDenied)
    {
        //user denied the permission
        dsMapAddString(dsMapIndex, "result", "denied");
    }
    else
    {
        //error occured querying or requesting permissions
        dsMapAddString(dsMapIndex, "result", "error");
        dsMapAddString(dsMapIndex, "error", (char*)[_error.description UTF8String]);
        dsMapAddInt(dsMapIndex, "error_code", _error.code);
    }
    
    //CreateAsynEventWithDSMap(dsMapIndex, EVENT_OTHER_SOCIAL);
    createSocialAsyncEventWithDSMap(dsMapIndex);
}


-(int)requestPermissions:(NSArray*)_permissions publish:(bool)_bPublish
{
    //session must be open
    if(!FBSession.activeSession.isOpen )
    {
        NSLog(@"Session must be open to request permissions");
        return -1;
    }
    //ALSO - MUST complete previous permissions request before allowing another or it will CRASH HORRIBLY...good old facebook
    if( s_bPermissionsRequestInProgress)
    {
        NSLog(@"Permissions request already in progress...");
        return -1;
    }
    
    NSArray *permissionsNeeded = _permissions;
    int requestId = ++s_requestID;
    
    // Request the permissions the user currently has
    //ugh can't we just use FBSession.activeSession permissions ?
    //this just seems to return installed permission anyway...
    
    //[FBRequestConnection startWithGraphPath:@"/me/permissions"
    //    completionHandler:^(FBRequestConnection *connection, id result, NSError *error)
    //    {
    //        if (!error)
    //        {
    //            NSDictionary *currentPermissions= [(NSArray *)[result data] objectAtIndex:0];
                NSArray* currentPerms = FBSession.activeSession.permissions;
                NSLog(@"current permissions %@", currentPerms);
                NSMutableArray *requestPermissions = [[NSMutableArray alloc] initWithArray:@[]];
                                  
                // Check if all the permissions we need are present in the user's current permissions
                // If they are not present add them to the permissions to be requested
                for (NSString *permission in permissionsNeeded)
                {
                    //if (![currentPermissions objectForKey:permission])
                    if( ![currentPerms containsObject:permission])
                    {
                        [requestPermissions addObject:permission];
                    }
                }
    
                // If we have permissions to request
                if ([requestPermissions count] > 0)
                {
                    s_bPermissionsRequestInProgress = true;
                    if(_bPublish)
                    {
                        [self requestPublishPermissions:requestPermissions requestId:requestId ];
                    }
                    else
                    {
                        [self requestReadPermissions:requestPermissions requestId:requestId];
                    }
                }

    return requestId;
}


@end



