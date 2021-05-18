# MegicalEasyAccess-SDK-iOS

This is a step by step guide for basic Easy Access usage. More detailed code can be found in the EA Client Example project.

In this example we register to and authenticate against the Easy Access Playground service at 
https://playground.megical.com/easyaccess/.
A real application could have some slight differences.


## 1. Add megicaleasyaccess-sdk-ios framework

1.1 Add the framework either locally by dragging the sdk folder to xcode's project navigator or
by adding a swift package manager dependency to the sdk repository.


1.2 Import the framework in code with:
import MegicalEasyAccess_SDK_iOS


1.3 Logging
Basic logging is enabled with EALog.config() and can be modified with a custom implementation.



## 2. Handle app instance registration

2.1 App registration and app token
Register to your backend and get your backend's app token to be used in Easy Access client registration.

In the playground demo we get the app token by going on a browser to
https://playground.megical.com/easyaccess/
and logging in with Easy Access.
The needed token is named "Test app client registration token".


2.2 Client key and JSON web key data
Create a client key with MegAuthJwkKey(). The first time you call MegAuthJwkKey() (and use the key) will store the created key in iOS keychain with the given client key tags (public and private).

Create a JWK public key data with clientKey.jwkJsonDataFromPublicKey()


2.3 Register Easy Access client
Again get JWK public key data with the client key.
Call MegAuthRegistrationFlow.registerClient()
The returned clientId is automatically saved in the keychain using given keychainKeyClientId tag.



## 3. Register callbacks
For the authentication step you will need two callbacks. One for the Easy Access app and another for oauth.


3.1 Create a url scheme for your app (e.g. com.example.app) that is called by the Easy Access app.


This is added in your target's settings on info tab (URL Types section) and should result in something like the following in info.plist:

	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLName</key>
			<string> com.example.app </string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>com.example.app</string>
			</array>
		</dict>
	</array>


3.2 Handle calls to custom url scheme.
Older apps handle these in the AppDelegate, but from iOS 13 onward we do this in the SceneDelegate.

Add handlers to
scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions)
and
scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>)
The first one handles cases where the app is launched with the url scheme and the other where the app is in memory when calling the app with it's url scheme.

The idea in both is to check for correctness and send a notification i.e.
NotificationCenter.default.post(name: .init(rawValue: NOTIFICATION_NAME_EASY_ACCESS_SUCCESS),
                                                object: loginCode)


3.3 Custom url protocol for handling redirects back from oauth
The auth server's callbacks are redirects from your app and in that case a custom url scheme won't get called.
Because of that we need a custom url protocol.


3.4 Custom url protocol implementation
This is easiest to do by extending EARedirectURLProtocolBase
and overriding:
a) oauthCallback()
By returning your oauth callback based on your app's url scheme.

b) authCodeReceivedNotificationName()
By returning the notification name that is used by the url protocol to notify your code of the auth code that is received in the oauth callback.


3.5 Register the url protocol in AppDelegate

Usually in didFinishLaunchingWithOptions, place the following
let eaOauthRedirectRegistered = URLProtocol.registerClass(YourEARedirectURLProtocol.self)


3.6 Notification center notifications

We need to observe notifications for Easy Access success and oauth auth code received.

NotificationCenter.default.addObserver(self,
                                       selector: #selector(self.onEasyaccessSuccessWithLoginCode(notification:)),
                                       name: .init(rawValue: NOTIFICATION_NAME_EASY_ACCESS_SUCCESS),
                                       object: nil)
        
NotificationCenter.default.addObserver(self,
                                       selector: #selector(self.onEasyAccessAuthCodeReceived(notification:)),
                                       name: .init(rawValue: NOTIFICATION_NAME_AUTH_CODE_RECEIVED),
                                       object: nil)



## 4. Authentication

4.1 MegAuthFlow
Create and retain an instance of MegAuthFlow. This object holds important information about the ongoing authentication process.


4.2 Begin authenticating
Call authFlow.authorize()
This will get the login code from the server and launch the Easy Access app on the same device.


4.3 Returning from the Easy Access app

Easy Access calls the given url scheme which is caught in SceneDelegate and passed as a notification which is observed in the example in onEasyaccessSuccessWithLoginCode(notification:)

The task here is to call the auth server's verify with authFlow.verify().

Note: When switching back to the app, internet is not accessible for a small time frame. For that reason the example has a short timer here.


4.4 Receiving the auth code

If verify is successful, we get the auth code through the custom url protocol -> notification -> onEasyAccessAuthCodeReceived(notification:)

Here we can use the following helper method to handle the notification object.
MegAuthTokenFlow.handleAuthCodeNotificationObject()

In the helper's completion handler we can get the access token from the accessTokenResult:
accessTokenResult.accessToken


## 5. Access protected resources

In the example we can use the retrieved access token to access the playgroundHello api:
PlaygroundAPI.playgroundHello(accessToken: accessTokenResult.accessToken)

