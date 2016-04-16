
package ${YYAndroidPackageName};

import ${YYAndroidPackageName}.RunnerActivity;
import com.yoyogames.runner.RunnerJNILib;
import android.content.Intent;
import android.util.Log;
import android.app.Application;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.Bundle;
import android.util.Log;

import java.lang.NullPointerException;
import java.lang.reflect.Field;
import java.net.URLConnection;
import java.net.URL;
import java.net.MalformedURLException;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.Iterator;
import java.util.List;
import java.util.Collection;
import java.util.ArrayList;
import java.util.Arrays;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import com.facebook.UiLifecycleHelper;
import com.facebook.Session;
import com.facebook.SessionState;
import com.facebook.Request;
import com.facebook.Response;
import com.facebook.HttpMethod;
import com.facebook.RequestAsyncTask;
import com.facebook.FacebookRequestError;
import com.facebook.model.*;//GraphObject;
import com.facebook.widget.WebDialog;
import com.facebook.FacebookException;
import com.facebook.FacebookOperationCanceledException;
import android.view.Window;
import android.view.ViewGroup.LayoutParams;
import android.view.WindowManager;

public class FacebookExtension
{

// Facebook communication settings
    public static final String STATUS_IDLE = "IDLE";
    public static final String STATUS_PROCESSING = "PROCESSING";
    public static final String STATUS_FAILED = "FAILED";
    public static final String STATUS_AUTHORISED = "AUTHORISED";
    private static final int EVENT_OTHER_SOCIAL = 70;
    
    public static String msLoginStatus = STATUS_IDLE; 
    public static String msUserId = ""; 
    private static int msRequestId = 1;
    private static boolean mbPermissionsRequestInProgress = false;
    private static List<String> mPermsRequested = null;
    private static boolean HaveRequestedUserId = false;

	private static boolean isSubsetOf(Collection<String> subset,
            Collection<String> superset) {
        for (String string : subset) {
            if (!superset.contains(string)) {
                return false;
            }
        }
        return true;
    }

	
	
	public void onActivityResult(Integer requestCode, Integer resultCode, Intent data)
	{
		Session fbSession = Session.getActiveSession();
		if(fbSession!=null)
		{
			fbSession.onActivityResult(RunnerActivity.CurrentActivity,requestCode,resultCode,data);
		}
	}
	
	
	private String getFacebookSDKVersion()
    {
        String sdkVersion = null;
        ClassLoader classLoader = getClass().getClassLoader();
        Class<?> cls;
        try
        {
            cls = classLoader.loadClass("com.facebook.FacebookSdkVersion");
            Field field = cls.getField("BUILD");
            sdkVersion = String.valueOf(field.get(null));
        }
        catch (ClassNotFoundException e)
        {
            // error
        }
        catch (NoSuchFieldException e)
        {
            // error
        }
        catch (IllegalArgumentException e)
        {
            // error
        }
        catch (IllegalAccessException e)
        {
            // error
        }
        return sdkVersion;
    }
    
	public void initFacebook(String appID) {
		Log.i("yoyo", "RunnerFacebook.initFacebook: Facebook initialisation for " + appID);
		Log.i("yoyo", "Facebook SDK version: " + getFacebookSDKVersion());
	}
	
	public String getUserId(){
		return msUserId;
	}
	
	public String facebookLoginStatus() {
		return msLoginStatus;
	}
	
	private void ClearStoredAccessTokenData() {
	
		final RunnerActivity activity = RunnerActivity.CurrentActivity;
		SharedPreferences.Editor editor = activity.getPreferences(Context.MODE_PRIVATE).edit();
	    editor.remove("access_token");
    	editor.remove("access_expires");
        editor.commit();
	}

	// Handle FB authorisation
	static List<String> ms_FacebookPermissions;
    public void setupFacebook(String[] permissions) {    
    
		
		//Log.i("yoyo","setting up facebook for permissions:"+permissions);
	    	    
	    // If we have our custom Facebook permission then setup the necessary parts
	    final RunnerActivity activity = RunnerActivity.CurrentActivity;
	    
		// Store permissions for potential later use
		ms_FacebookPermissions = new ArrayList<String>(Arrays.asList(permissions));
		
		if( Session.getActiveSession() != null && Session.getActiveSession().isOpened())
		{
			Log.i("yoyo", "Facebook session already opened");
		}
		else
		{
			FacebookLogin(permissions);
		}
    }	
	
    private static void SetLoginStatus( String newState)
    {
    	Log.i("yoyo", "Facebook login status: " + msLoginStatus);
    	msLoginStatus = newState;
    }
    
    //new permissions support WIP...
    public Boolean CheckPermission( String _permission )
    {
    	Session session = Session.getActiveSession();
    	if( session != null )
    	{
    		//+need to check session is open?
    		List<String> permsList = session.getPermissions();
    		Log.i("yoyo", "Current permissions:" + permsList);
    		
    		boolean bHavePermission = session.isPermissionGranted( _permission );
    		return bHavePermission;
    	}
    	return false;
    }
    
    public Integer RequestPermissions( String[] _permissions, Boolean _bPublishPermission )
    {
    	//check session is opened
    	Session session = Session.getActiveSession();
    	if( session == null || !session.isOpened())
    	{
    		Log.i("yoyo", "Facebook session must be opened to request permissions");
    		return -1;
    	}
    	if( mbPermissionsRequestInProgress )
    	{
    		Log.i("yoyo", "Facebook permissions request already in progress");
    		return -1;
    	}
    	
    	++msRequestId;
    	mPermsRequested = Arrays.asList(_permissions);
    	mbPermissionsRequestInProgress = true;
    	Session.NewPermissionsRequest request = new Session.NewPermissionsRequest(RunnerActivity.CurrentActivity, mPermsRequested );
    	//should get callback in onSessionStateChanged() callback...hopefully
    	if( _bPublishPermission)
    	{
    		session.requestNewPublishPermissions( request );
    	}
    	else
    	{
    		session.requestNewReadPermissions( request );
    	}

    	return msRequestId;
    }
    
    private static void PermissionsRequestResult(Session session, Exception exception)
    {
    	Log.i("yoyo", "Permssions request result");
    	List<String> currentPerms = session.getPermissions();
    	Log.i("yoyo", "current perms:" + currentPerms);
    	Log.i("yoyo", "requested perms:" + mPermsRequested );
    	int dsMapIndex = RunnerJNILib.jCreateDsMap(null, null, null);
    	RunnerJNILib.dsMapAddInt(dsMapIndex, "requestId", msRequestId);
    	RunnerJNILib.dsMapAddString(dsMapIndex, "type", "facebook_permission_request");
    	if( exception != null )
    	{
    		RunnerJNILib.dsMapAddString(dsMapIndex, "result", "error");
    		String errorMsg = exception.getMessage();
    		if( errorMsg != null ) {
    			RunnerJNILib.dsMapAddString(dsMapIndex, "error", errorMsg);
    		}
    	}
    	else
    	{
    		boolean bGranted = isSubsetOf(mPermsRequested, currentPerms);
    		if( bGranted)
    		{
    			RunnerJNILib.dsMapAddString(dsMapIndex, "result", "granted");
    		}
    		else
    		{
    			RunnerJNILib.dsMapAddString(dsMapIndex, "result", "denied");
    		}
    		RunnerJNILib.CreateAsynEventWithDSMap( dsMapIndex, EVENT_OTHER_SOCIAL);
    	}
    	
    }
    
    private Session.StatusCallback fbSessionCallback = new Session.StatusCallback()
	{
		@Override
		public void call(Session session,SessionState state, Exception exception)
		{
			onSessionStateChanged(session,state,exception);
		}
	};

	
	public void onResume()
	{
		Session session = Session.getActiveSession();
		if(session != null && (session.isOpened() || session.isClosed()))
		{
			onSessionStateChanged(session,session.getState(),null);
		}
	}
	
	
    public static void onSessionStateChanged(Session session, SessionState state, Exception exception)
	{
		Log.i("yoyo","Facebook onSessionStateChanged: " + state + ", " + exception );
			
		if(state.isOpened())
		{
			SetLoginStatus( STATUS_AUTHORISED );  
			
			//check if permissions request succeeded ( SessionState.OPENED_TOKEN_UPDATED? )
			if( mbPermissionsRequestInProgress)
			{
				mbPermissionsRequestInProgress = false;
				PermissionsRequestResult( session, exception  );
			}
			
			//ping to get our info
			// make request to the /me API - only need to do once!
			if( !HaveRequestedUserId )
			{
				HaveRequestedUserId = true;
				//refresh permissions in case opened from cached session
				session.refreshPermissions();
				
				Request.newMeRequest( session, new Request.GraphUserCallback() 
				{
					// callback after Graph API response with user object
					@Override
					public void onCompleted(GraphUser user, Response response) 
					{
						Log.i("yoyo","Facebook info request completed");
						if( user != null )
						{
							Log.i("yoyo","for " + user.getName() + " id " + user.getId());
							msUserId = user.getId();
						}
					};
				}).executeAsync();
			}
		}
		else if( state.isClosed() )
		{
			if( state == SessionState.CLOSED_LOGIN_FAILED )
			{
				SetLoginStatus( STATUS_FAILED );
			}
			else if( state == SessionState.CLOSED )
			{
				Log.i("yoyo","Facebook Logged out");
				SetLoginStatus( STATUS_IDLE);
			}
			mbPermissionsRequestInProgress = false;
		}
		else
		{
			//open or close in process...?
			SetLoginStatus( STATUS_PROCESSING );
		}
	}
	
	
	private boolean isNetworkAvailable() {	
        
        ConnectivityManager conMan = (ConnectivityManager) RunnerActivity.CurrentActivity.getApplicationContext().getSystemService(Context.CONNECTIVITY_SERVICE);
		NetworkInfo activeNetwork = conMan.getActiveNetworkInfo();
		return activeNetwork != null && activeNetwork.isConnected();
    }
	
	
	private void FacebookLogin(String[] permissions ) {
	
		//for(int i=0;i<ms_FacebookPermissions.length;i++)
		//	Log.i("yoyo", "Setting up Facebook for permissions " + ms_FacebookPermissions[i]);	
		SetLoginStatus( STATUS_PROCESSING );
		final List<String> permsList = Arrays.asList( permissions);
		RunnerActivity.ViewHandler.post(new Runnable() 
		{
			public void run() 
			{				
				Log.i("yoyo","Creating new facebook session");
				Session.openActiveSession(RunnerActivity.CurrentActivity,true, permsList, fbSessionCallback);
			}
		});
	}
    
    public String getAccessToken()
    {
		if(Session.getActiveSession()!=null)
		{
			return Session.getActiveSession().getAccessToken();
		}
    
		return "";
    }
    
    // Log the user out from Facebook
    public void logout() {
    
		if(Session.getActiveSession()!=null)
		{
			Session.getActiveSession().closeAndClearTokenInformation();
		}
    }
    
    // Handles the situation where an array is found within the json data
	private void extractJSONDataArray(JSONArray objArray, Integer dsListIndex)
	{       
    	for (int arrayIndex = 0; arrayIndex < objArray.length(); ++arrayIndex) 
	    {
		    Object arrayObj;
	    	try {	    	
	    	    arrayObj = objArray.get(arrayIndex);
	    	}
	    	catch (org.json.JSONException e) {
	    		e.printStackTrace();
	    		continue;
	    	}
	    	
        	if (arrayObj instanceof JSONArray)
    	    {
	            // Create a new ds_list for the array
        	    int dsNewListIndex = RunnerJNILib.dsListCreate();
            
            	// Add this map index to the list
    	        RunnerJNILib.dsListAddInt(dsListIndex, dsNewListIndex);
        
 	           	Log.i("yoyo", "Added ds_list " + dsNewListIndex + " to ds_list " + dsListIndex);
            
    	        // Add the ds_list index to the ds_map for the current key                      
            	extractJSONDataArray((JSONArray)objArray, dsNewListIndex); 
	        }
    	    else if (arrayObj instanceof JSONObject) 
        	{                    
            	// Create a new ds_map and get the index for it...
    	        int subDsMap = RunnerJNILib.dsMapCreate();
	            
            	// Add this map index to the list
        	    RunnerJNILib.dsListAddInt(dsListIndex, subDsMap);
            
	            // Recurse to parse the new dictionary
        	    translateJSONResponse((JSONObject)arrayObj, subDsMap);
            
	            Log.i("yoyo", "Added ds_map " + subDsMap + " to ds_list " + dsListIndex);
    	    }
        	else if (arrayObj instanceof String) 
	        {                    
    	        // Add the string to the list        	                     
    	        RunnerJNILib.dsListAddString(dsListIndex, (String)arrayObj);
        	    
            	Log.i("yoyo", "Added " + (String)arrayObj + " to ds_list " + dsListIndex);
	        } 
	        else if(arrayObj instanceof Integer)
    	    {
    			RunnerJNILib.dsListAddInt(dsListIndex, (Integer)arrayObj);
    			
    			Log.i("yoyo", "Added " + (Integer)arrayObj + " to ds_list " + dsListIndex );
    		} 
	        else 
	        {
        		String str = arrayObj.toString();
        		RunnerJNILib.dsListAddString(dsListIndex, str);
            	Log.i("yoyo", "Added " + str + " to ds_list " + dsListIndex); 
	        }
    	}
    }
    
    // Translates a JSON response from Facebook into ds_map/ds_list data
    private void translateJSONResponse(JSONObject response, Integer dsMapResponse) {
    
    	JSONArray keys = response.names();    
	    for (int n = 0; n < response.length(); ++n) 
    	{
	    	String currentKey;
	    	Object currentObj;
        	try {
	        	currentKey = (String)keys.get(n);
		        currentObj = response.get(currentKey);
		    }
		    catch (org.json.JSONException e) {
	    		e.printStackTrace();
	    		continue;
	    	}
        	//Log.i("yoyo","translateJSONResponse:key=" + currentKey.toString() + "=" + currentObj.toString());
    	    if (currentObj instanceof JSONArray) 
        	{
	            // Create a new ds_list for the array
    	        int dsListIndex = RunnerJNILib.dsListCreate();
            
        	    // Add this map index to the list
            	RunnerJNILib.dsMapAddInt(dsMapResponse, currentKey, dsListIndex);
            
	            Log.i("yoyo", "Added " + dsListIndex + " to ds_map " + dsMapResponse + " for key " + currentKey);
            
    	        // Add the ds_list index to the ds_map for the current key                  
            	extractJSONDataArray((JSONArray)currentObj, dsListIndex);
	        }
    	    else if (currentObj instanceof JSONObject) 
        	{
            	// Create a new ds_map and get the index for it...
	            int subDsMap = RunnerJNILib.dsMapCreate();
            
    	        // Add this to the current ds_map
        	    RunnerJNILib.dsMapAddInt(dsMapResponse, currentKey, subDsMap);
            
            	// And recurse to parse the new dictionary
    	        translateJSONResponse((JSONObject)currentObj, subDsMap);
            
        	    Log.i("yoyo", "Added new ds_map " + subDsMap + " to ds_map " + dsMapResponse + " for key " + currentKey);
	        }
    	    else if (currentObj instanceof String) 
        	{
            	// Add the string to the map with the current key                  
            	RunnerJNILib.dsMapAddString(dsMapResponse, currentKey, (String)currentObj);
            
	            Log.i("yoyo", "Added " + (String)currentObj + " to ds_map " + dsMapResponse + " for key " + currentKey);
    	    }
    	    else if(currentObj instanceof Integer)
    	    {
    			RunnerJNILib.dsMapAddInt(dsMapResponse, currentKey, (Integer)currentObj);
    			Log.i("yoyo", "Added " + (Integer)currentObj + " to ds_map " + dsMapResponse + " for key " + currentKey);
    		}
    	    else 
	        {
        		String str = currentObj.toString();
        		RunnerJNILib.dsMapAddString(dsMapResponse, currentKey, str);
	            Log.i("yoyo", "Added " + str + " to ds_map " + dsMapResponse + " for key " + currentKey); 
	        }
    	}    
    }
    
    // Posts a message to the users feed based on the set of key-value pairs found in the given array: ["key0", "value0", "key1", "value1"..."keyN", "valueN"]
	// See http://developers.facebook.com/docs/reference/api/user/#posts for the set of key-value pairs expected
    public void graphRequest(String _graphPath, String _httpMethod, String[] _keyValuePairs, Integer _dsMapResponse) 
    {
		//only allow if session is open-
    	Session session = Session.getActiveSession();
    	if( session == null || !session.isOpened() )
    	{
    		Log.i("yoyo", "facebook graph request error: facebook session must be open");
    		return;
    	}
    	
    	final String graphPath = _graphPath;
		final String httpMethod = _httpMethod;
		final String[] keyValuePairs= _keyValuePairs;
    	final int dsMapResponse = _dsMapResponse;
    	
		//RunnerActivity.ViewHandler.post( new Runnable() {
		//public void run() {
    	Runnable exec = new Runnable() {
    		public void run() 
    		{
    
			    if ((keyValuePairs.length & 0x1) != 0) {
					throw new IllegalArgumentException("There must be an even number of strings forming key-value pairs");
				}
				if (!httpMethod.equals("GET") && !httpMethod.equals("POST")  && !httpMethod.equals("DELETE")) {
					throw new IllegalArgumentException("The httpMethod for a Facebook graph request must be one of 'GET', 'POST' or 'DELETE', value supplied was: " + httpMethod);
				}
					
				Log.i("yoyo", "Making graph API request for path: " + graphPath + " with httpMethod: " + httpMethod);
				try {
		    		Bundle parameters = new Bundle();    	        
		    	        
		    	    // Populate the Bundle parameters with the key-value pairs			
		    	    for (int n = 0; n < keyValuePairs.length; n += 2) {
									
			           	parameters.putString(keyValuePairs[n], keyValuePairs[n+1]);
		    	    }
		    	    
		    	    HttpMethod httpmethod = HttpMethod.POST;
		    		if(httpMethod.equals("GET"))
		    			httpmethod = HttpMethod.GET;
		    		else if(httpMethod.equals("DELETE"))
		    			httpmethod = HttpMethod.DELETE;
		    		
		    	  
		    		Request request = new Request(Session.getActiveSession(), graphPath, parameters, httpmethod,new Request.Callback()
                    {
		    			public void onCompleted(Response response)
						{
							if( response != null )
							{
								Log.i("yoyo", "Facebook graph request COMPLETE: " + response.toString());	
								//add response to map
								if (dsMapResponse != -1) 
								{
									RunnerJNILib.dsMapAddString(dsMapResponse, "response_text", response.toString());
								}
							}
							
							GraphObject graphobj = response.getGraphObject();
							if(graphobj!=null)
							{
							
								JSONObject graphResponse = graphobj.getInnerJSONObject();
										   
								if (dsMapResponse != -1) {
									translateJSONResponse(graphResponse, dsMapResponse);
								}
							}
									   
							
							FacebookRequestError error = response.getError();
							if (error != null) {
							
								Log.i("yoyo","Error from facebook graphRequest response:" + error.getErrorMessage());
								//is response null in case of error? add error message to "response_text" ?
							}
						}
                    });
		
					RequestAsyncTask task = new RequestAsyncTask(request);
					task.execute();
				} 
			    catch(Exception e) {
		    	    e.printStackTrace();
		        }	
    		}
    	};
    	RunnerActivity.ViewHandler.post( exec );
    }
    

	private Bundle buildParamsBundle( String[] keyValuePairs )
	{
		Bundle parameters = new Bundle();
		if ((keyValuePairs.length & 0x1) != 0) {
			throw new IllegalArgumentException("There must be an even number of strings forming key-value pairs");
		}
		try {
    		// Populate the Bundle parameters with the key-value pairs
    	    for (int n = 0; n < keyValuePairs.length; n += 2) {
	        	parameters.putString(keyValuePairs[n], keyValuePairs[n+1]);
    	    }    	
    	}        
		catch(Exception e) {
    		e.printStackTrace();
        }
		return parameters;
	}
    
    
    public void dialog(String dialogType, String[] keyValuePairs, Integer dsMapResponse) 
	{
    	Bundle parameters = buildParamsBundle( keyValuePairs);
    	showDialogWithoutNotificationBar(dialogType, parameters,dsMapResponse);
    }
	
	public void inviteDialog(String dialogType, String[] keyValuePairs, Integer dsMapResponse) 
    {
		Bundle parameters = buildParamsBundle( keyValuePairs);
    	Log.i("yoyo", "invite dialog: params=" + parameters.toString());
    	showDialogWithoutNotificationBar("apprequests", parameters,dsMapResponse);
    }
	
    WebDialog dialog;
    
    
    private void parseInviteDialogResult( Bundle values, int mapIndex )
    {
    	if( values != null )
		{
			Log.i("yoyo", "values=" + values.toString());
			int numMappings = values.size();
			
			if( mapIndex >=0 && numMappings > 0)
			{
				String key = "request";
				String request = values.getString(key);
				if( request != null )
				{
					RunnerJNILib.dsMapAddString( mapIndex, key, request );
					int dsListIndex = RunnerJNILib.dsListCreate();
		           	RunnerJNILib.dsMapAddInt( mapIndex, "to", dsListIndex);
					
					int i=0;
					key = "to[0]";
					while( values.containsKey( key ) )
					{
						String val = values.getString( key );
						Log.i("yoyo", "adding key:" + key + " = " + val );
						//list add val ...
						RunnerJNILib.dsListAddString(dsListIndex, val );
						
						++i;
						key = "to[" + i + "]";
					}
				}
			}
		}	
    }
    
    private void showDialogWithoutNotificationBar(String _action, Bundle _params, int _dsMapResponse)
    {
    	final String action = _action;
		final Bundle params = _params;
		final int mapIndex = _dsMapResponse;
		final boolean bInviteDialog = _action.equals("apprequests");
		
		RunnerActivity.ViewHandler.post( new Runnable() 
		{
    	public void run() 
    	{
			Session fbSession = Session.getActiveSession();
	    	WebDialog.Builder dialogBuilder;
	    	if( fbSession == null || !fbSession.isOpened())
	    	{
	    		//we can still present a dialog without an active session-
	    		//passing null for applicationId should retrieve appID from manifest...
	    		Log.i("yoyo","facebook dialog - no open session");
	    		String appId = null;
	    		dialogBuilder = new WebDialog.Builder(RunnerActivity.CurrentActivity, appId, action, params );
	    	}
	    	else
	    	{
	    		Log.i("yoyo","facebook dialog - with open session");
	    		dialogBuilder = new WebDialog.Builder(RunnerActivity.CurrentActivity, fbSession, action, params );
	    	}
	    	
	    	dialogBuilder.setOnCompleteListener( new WebDialog.OnCompleteListener()
	    	{
	    		@Override
				public void onComplete(Bundle values, FacebookException error) {
					if (error != null && !(error instanceof FacebookOperationCanceledException)) {
						Log.i("yoyo","Error showing facebook dialog :" + error);
					}
					
					if(values!=null)
					{
						Log.i("yoyo", "dialog completed: " + values.toString());
						if( bInviteDialog )
						{
							//special case apprequests results for consistency with html5 response
							parseInviteDialogResult( values, mapIndex);
						}
						else
						{
							if( mapIndex >=0 )
							{
								String key;
				                String val;
								Iterator<String> it = values.keySet().iterator();
								while(it.hasNext()) {
				                    key = it.next();
									try{
										val = values.get(key).toString();
										Log.i("yoyo", "Added " + val + " to ds_map " + mapIndex + " for key " + key);
										RunnerJNILib.dsMapAddString(mapIndex, key, val );
									}
									catch( Exception ex )
									{
										Log.i("yoyo", ex.getMessage());
									}
								}
							}
						}
					}
				}
	    	});
	    	
	    	dialog = dialogBuilder.build();
	    	Window dialog_window = dialog.getWindow();
			dialog_window.setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
				WindowManager.LayoutParams.FLAG_FULLSCREEN);
	
			
	    	dialog.show();
    	}
    	});
    }
}