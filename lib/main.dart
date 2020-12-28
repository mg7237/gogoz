import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/services.dart';
import 'package:connectivity/connectivity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'animations.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:gogoz/screens/login_screen.dart';
import 'mainScreen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import './alert_dialog.dart';

import 'dart:ui';

import 'package:flutter/cupertino.dart';

import 'package:rxdart/subjects.dart';

// adb shell service call isms 7 i32 0 s16 "com.android.mms.service" s16 "+919653488064" s16 "null" s16 "'8098'" s16 "null" s16 "null"

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Streams are created so that app can respond to notification-related events
/// since the plugin is initialised in the `main` function

final BehaviorSubject<ReceivedNotification> didReceiveLocalNotificationSubject =
    BehaviorSubject<ReceivedNotification>();

final BehaviorSubject<String> selectNotificationSubject =
    BehaviorSubject<String>();

const MethodChannel platform =
    MethodChannel('dexterx.dev/flutter_local_notifications_example');

class ReceivedNotification {
  ReceivedNotification({
    @required this.id,
    @required this.title,
    @required this.body,
    @required this.payload,
  });

  final int id;
  final String title;
  final String body;
  final String payload;
}

Future<dynamic> myBackgroundMessageHandler(Map<String, dynamic> message) async {
  if (message.containsKey('data')) {
    // Handle data message
    message = message['data'];
  }

  if (message.containsKey('notification')) {
    // Handle notification message
    message = message['notification'];
  }

  await displayNotification(message);

  return Future<void>.value();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final NotificationAppLaunchDetails notificationAppLaunchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  /// Note: permissions aren't requested here just to demonstrate that can be
  /// done later
  final IOSInitializationSettings initializationSettingsIOS =
      IOSInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          onDidReceiveLocalNotification:
              (int id, String title, String body, String payload) async {
            didReceiveLocalNotificationSubject.add(ReceivedNotification(
                id: id, title: title, body: body, payload: payload));
          });
  const MacOSInitializationSettings initializationSettingsMacOS =
      MacOSInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false);
  final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      macOS: initializationSettingsMacOS);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: (String payload) async {
    if (payload != null) {
      debugPrint('notification payload: $payload');
    }
    selectNotificationSubject.add(payload);
  });

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'App Intro',
    home: HomePage(
      notificationAppLaunchDetails,
    ),
    theme: ThemeData.dark(),
  ));
}

List<String> imagePath = [
  "assets/images/intro1.png",
  "assets/images/intro2.png",
  "assets/images/intro3.png",
  "assets/images/intro4.png",
  "assets/images/intro5.png"
];

List<String> title = [
  " ",
  "Eat Best",
  "Go Local",
  "Shop On-the-go",
  "Quick Delivery"
];

List<String> description = [
  "",
  "We make it simple to find fresh food for you, near you",
  "We are your supplier of the freshest everyday groceries",
  "Don't let anything stop you",
  "Enter your address, and let us do the rest",
];

const iOSPlatformChannelSpecifics = IOSNotificationDetails();

Future<void> displayNotification(Map<String, dynamic> message) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails('channel-id', 'fcm', 'gogoz',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker');

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
      0,
      message['notification']['title'],
      message['notification']['body'],
      platformChannelSpecifics,
      payload: 'fcm');
}

class HomePage extends StatefulWidget {
  const HomePage(
    this.notificationAppLaunchDetails, {
    Key key,
  }) : super(key: key);

  final NotificationAppLaunchDetails notificationAppLaunchDetails;
  bool get didNotificationLaunchApp =>
      notificationAppLaunchDetails?.didNotificationLaunchApp ?? false;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    checkPermission();
    _requestPermissions();
    _configureDidReceiveLocalNotificationSubject();
    _configureSelectNotificationSubject();
  }

  void _requestPermissions() {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  void _configureDidReceiveLocalNotificationSubject() {
    didReceiveLocalNotificationSubject.stream
        .listen((ReceivedNotification receivedNotification) async {
      await showDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: receivedNotification.title != null
              ? Text(receivedNotification.title)
              : null,
          content: receivedNotification.body != null
              ? Text(receivedNotification.body)
              : null,
          actions: <Widget>[
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                Navigator.of(context, rootNavigator: true).pop();
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        SecondScreen(receivedNotification.payload),
                  ),
                );
              },
              child: const Text('Ok'),
            )
          ],
        ),
      );
    });
  }

  bool gotPermissions = false;

  void checkPermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isUndetermined || status.isRestricted) {
      if (await Permission.locationWhenInUse.request().isGranted) {
        // Either the permission was already granted before or the user just granted it.
        gotPermissions = true;
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('location_permission', "granted");

        print("Permission Granted");
      } else {
        AlertDialogs(
            message: "Permission denied, cannot use this service",
            title: "Permission denied");
        print("Permission denied");
      }
    }
  }

  void _configureSelectNotificationSubject() {
    selectNotificationSubject.stream.listen((String payload) async {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (BuildContext context) => SecondScreen(payload)),
      );
    });
  }

  @override
  void dispose() {
    didReceiveLocalNotificationSubject.close();
    selectNotificationSubject.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return Scaffold(
      backgroundColor: Color(0xFF0E0038),
      body: ContentPage(),
    );
  }
}

class ContentPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Column(
          children: <Widget>[
            CarouselSlider(
              options: CarouselOptions(
                autoPlay: false,
                enableInfiniteScroll: false,
                initialPage: 0,
                reverse: false,
                viewportFraction: 1.0,
                aspectRatio: MediaQuery.of(context).size.aspectRatio,
                height: MediaQuery.of(context).size.height,
              ),
              items: [0].map((i) {
                return Builder(
                  builder: (BuildContext context) {
                    return Container(
                        width: MediaQuery.of(context).size.width,
                        child: AppIntro(i));
                  },
                );
              }).toList(),
            ),
          ],
        ));
  }
}

var deviceToken;

class AppIntro extends StatefulWidget {
  int index;
  AppIntro(this.index);
  @override
  _AppIntroState createState() => _AppIntroState();
}

var connected = false;

class _AppIntroState extends State<AppIntro> with TickerProviderStateMixin {
  String textValue = 'Hello World !';

  Connectivity connectivity;
  StreamSubscription<ConnectivityResult> subscription;
  FirebaseMessaging firebaseMessaging = new FirebaseMessaging();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      new FlutterLocalNotificationsPlugin();
  AnimationController _controller;
  Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    connectivity = new Connectivity();
    subscription =
        connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile) {
        setState(() {});
      }

      _controller = AnimationController(
        duration: const Duration(seconds: 2),
        vsync: this,
      )..forward();
      _animation = Tween<Offset>(
        begin: const Offset(-0.5, 0.0),
        end: const Offset(0.0, 0.0),
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.linearToEaseOut,
      ));
      getData();
    });

    firebaseMessaging.configure(
      onBackgroundMessage: myBackgroundMessageHandler,
      onLaunch: (Map<String, dynamic> message) {
        print(" onLaunch called ${(message)}");
      },
      onResume: (Map<String, dynamic> message) {
        print(" onResume called ${(message)}");
      },
      onMessage: (Map<String, dynamic> message) {
        displayNotification(message);
        print(" onMessage called ${(message)}");
      },
    );
    firebaseMessaging.requestNotificationPermissions(
        const IosNotificationSettings(sound: true, alert: true, badge: true));
    firebaseMessaging.onIosSettingsRegistered
        .listen((IosNotificationSettings setting) {
      print('IOS Setting Registered');
    });
    firebaseMessaging.getToken().then((token) {
      update(token);
      print("FirebaseMessaging token: $token");
    });
  }

  update(String token) {
    deviceToken = token;
    DatabaseReference databaseReference = new FirebaseDatabase().reference();
    databaseReference.child('fcm-token/${token}').set({"token": token});
    setState(() {});
  }

  var showDescription = false;

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  Future getData() async {
    Future.delayed(const Duration(milliseconds: 1500), () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_token', deviceToken);

      http.Response response = await http.get("https://02c8cb08d4e2.ngrok.io/");
      if (response.statusCode == HttpStatus.ok) {
        var result = ["connected"];
        connected = true;
        getPrefs();
        return result;
      }
    });
  }

  Future<void> getPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedin = prefs.getBool('loggedin');

    if (loggedin == null || loggedin == false) {
      Navigator.pushReplacement(context, SlideRightRoute(page: LoginScreen()));
    } else {
      Navigator.pushReplacement(context, SlideRightRoute(page: MainScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent));

    return Container(
        color: Color(0xFF0E0038),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: 50,
                  ),
                  SlideTransition(
                    position: _animation,
                    transformHitTests: true,
                    textDirection: TextDirection.ltr,
                    child: Image.asset(imagePath[0],
                        width: MediaQuery.of(context).size.width),
                  ),
                  Container(
                      child: Center(
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                        RichText(
                            textAlign: TextAlign.center,
                            text: new TextSpan(
                                style: new TextStyle(
                                  fontSize: 25,
                                  color: Colors.white,
                                ),
                                children: <TextSpan>[
                                  new TextSpan(
                                      text: description[0],
                                      style:
                                          new TextStyle(fontFamily: 'Avenir')),
                                ])),
                      ]))),
                  SizedBox(
                    height: 50,
                  ),
                  Center(
                      child: FutureBuilder(
                          future: getData(),
                          builder: (context, snapshot) {
                            return Center();
                          })),
                ],
              ),
            ),
          ],
        ));
  }
}

class SecondScreen extends StatefulWidget {
  const SecondScreen(
    this.payload, {
    Key key,
  }) : super(key: key);

  final String payload;

  @override
  State<StatefulWidget> createState() => SecondScreenState();
}

class SecondScreenState extends State<SecondScreen> {
  String _payload;
  @override
  void initState() {
    super.initState();
    _payload = widget.payload;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Second Screen with payload: ${_payload ?? ''}'),
        ),
        body: Center(
          child: RaisedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Go back!'),
          ),
        ),
      );
}
