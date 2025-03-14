import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:year4_project/services/auth_service.dart';
import 'package:year4_project/services/analytics_service.dart';
import 'package:year4_project/models/user.dart';
import 'package:year4_project/pages/home_page.dart';
import 'package:year4_project/pages/login_page.dart';
import 'package:year4_project/pages/signup_page.dart';
import 'package:year4_project/pages/waiting_room.dart';
import 'package:year4_project/pages/challenges_page.dart';
import 'package:year4_project/pages/run_loading_page.dart';
import 'package:year4_project/pages/duo_active_run_page.dart';
import 'package:year4_project/pages/league_room_page.dart';
import 'package:year4_project/pages/journey_type_page.dart';
import 'package:year4_project/pages/duo_waiting_room_page.dart';
import 'package:year4_project/services/team_service.dart';
import 'package:year4_project/pages/history_page.dart';
import 'package:year4_project/analytics_route_observer.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_smartlook/flutter_smartlook.dart';

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
}

Future<void> requestLocationPermission() async {
  try {
    
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services disabled. Cannot request permission.');
      return;
    }

    if (Platform.isIOS) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions denied on iOS');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        print('Location permissions permanently denied on iOS, guide user to settings');
        return;
      }
    } else {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions denied');
          return;
        }
      }
    }

    
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      print(
          'Current location: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m');
    } catch (e) {
      print('Error getting current position: $e');
    }
  } catch (e) {
    print('Error requesting location permission: $e');
  }
}

Future<void> initPosthog() async {
  try {
    
    final config = PostHogConfig('phc_uiuWH9NvkviwjtUsHRwkc9qgXvsWwlobSFgpbe9lRnF')
      ..debug = true 
      ..captureApplicationLifecycleEvents = true
      ..host = 'https:

    
    await Posthog().setup(config);

    
    await Posthog().capture(
      eventName: 'app_initialized',
      properties: {
        'timestamp': DateTime.now().toIso8601String(),
        'platform': Platform.isAndroid ? 'Android' : 'iOS',
      },
    );

    print('PostHog initialized with test event');
  } catch (e) {
    print('Error initializing PostHog: $e');
  }
}

Future<void> requestScreenPermissions() async {
  try {
    if (Platform.isAndroid) {
      
      PermissionStatus storageStatus = await Permission.storage.request();
      print('Storage permission status: $storageStatus');

      
      if (await Permission.photos.isGranted == false) {
        await Permission.photos.request();
      }

      if (await Permission.mediaLibrary.isGranted == false) {
        await Permission.mediaLibrary.request();
      }
    }
  } catch (e) {
    print('Error requesting screen permissions: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🔄 Starting app initialization...');

  
  print('🔄 Requesting screen permissions...');
  await requestScreenPermissions();

  
  print('🔄 Loading environment variables...');
  await dotenv.load();

  print('🔄 Initializing Supabase...');
  await initSupabase();

  print('🔄 Initializing PostHog...');
  await initPosthog();

  
  print('🔄 Requesting location permissions...');
  await requestLocationPermission();

  print('🔄 Checking authentication status...');
  final authService = AuthService();
  final isAuthenticated = await authService.checkAuthStatus();

  
  UserModel initialUserModel = UserModel(id: 0, email: '', name: '');

  
  if (isAuthenticated) {
    print('🔄 Restoring user session...');
    final userData = await authService.restoreUserSession();
    if (userData != null) {
      initialUserModel = UserModel(
        id: userData['id'],
        email: userData['email'],
        name: userData['name'],
      );

      
      await AnalyticsService().client.identifyUser(
        userId: userData['id'].toString(),
        email: userData['email'],
        role: 'user',
      );
    }
  }

  final initialRoute = isAuthenticated ? '/home' : '/login';
  print('🔄 Initial route set to: $initialRoute');

  print('✅ App initialization complete. Starting UI...');
  runApp(
    ChangeNotifierProvider(
      create: (_) => initialUserModel,
      child: MyApp(initialRoute: initialRoute),
    ),
  );
}

class MyApp extends StatefulWidget {
  final String initialRoute;
  const MyApp({Key? key, required this.initialRoute}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _routeObserver = AnalyticsRouteObserver();
  final Smartlook smartlook = Smartlook.instance;

  @override
  void initState() {
    super.initState();
    print('MyApp initState called');
    WidgetsBinding.instance.addObserver(this);

    
    print('Initializing UXCam from initState...');
    FlutterUxcam.optIntoSchematicRecordings();
    FlutterUxConfig config = FlutterUxConfig(
      userAppKey: "pse1vvwkr8reerf",
      enableAutomaticScreenNameTagging: false,
    );
    FlutterUxcam.startWithConfiguration(config);

    
    Future.delayed(Duration(seconds: 1), () async {
      try {
        bool isRecording = await FlutterUxcam.isRecording();
        print('UXCam recording status after initialization: $isRecording');

        if (!isRecording) {
          print('UXCam not recording, starting new session...');
          await FlutterUxcam.startNewSession();
        }
      } catch (e) {
        print('Error checking UXCam status: $e');
      }
    });

    
    smartlook.start();
    smartlook.preferences.setProjectKey('5e6af6d7c885ec62a1814ea8ed55fcafc2fa91d6');
    print('Smartlook initialized');

    
    Future.delayed(Duration(seconds: 2), () {
      try {
        final user = Provider.of<UserModel>(context, listen: false);
        if (user.id != 0) {
          FlutterUxcam.setUserIdentity(user.id.toString());
          if (user.email.isNotEmpty) {
            FlutterUxcam.setUserProperty("email", user.email);
          }
          if (user.name.isNotEmpty) {
            FlutterUxcam.setUserProperty("name", user.name);
          }
          print('User identified in UXCam');
        }
      } catch (e) {
        print('Error identifying user in UXCam: $e');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('App lifecycle state changed to: $state');

    if (state == AppLifecycleState.resumed) {
      print("App resumed - checking UXCam and Smartlook");
      _checkUXCamStatus();
    }
  }

  Future<void> _checkUXCamStatus() async {
    try {
      bool isRecording = await FlutterUxcam.isRecording();
      print('UXCam recording status check: $isRecording');

      if (!isRecording) {
        print('Restarting UXCam recording...');
        await FlutterUxcam.startNewSession();
      }
    } catch (e) {
      print('Error checking UXCam status: $e');
    }
  }

  @override
  void dispose() {
    print('MyApp dispose called');
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('MyApp build called');

    final user = Provider.of<UserModel>(context);
    _checkUserTeam(user);

    return MaterialApp(
      title: 'Running App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      navigatorObservers: [
        _routeObserver,
      ],
      initialRoute: widget.initialRoute,
      routes: {
        '/': (context) => const HomePage(),
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/waiting_room': (context) => WaitingRoomScreen(userId: user.id),
        '/challenges': (context) => const ChallengesPage(),
        '/journey_type': (context) => const JourneyTypePage(),
        '/duo_waiting_room': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return DuoWaitingRoom(teamChallengeId: args['team_challenge_id'] as int);
        },
        '/run_loading': (context) => const RunLoadingPage(journeyType: 'solo', challengeId: 0),
        '/league_room': (context) => LeagueRoomPage(userId: user.id),
        '/history': (context) => const HistoryPage(),
        '/duo_active_run': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return DuoActiveRunPage(challengeId: args['team_challenge_id'] as int);
        },
      },
      onGenerateRoute: (settings) {
        
        print('Navigating to: ${settings.name}');

        
        if (settings.name != null) {
          FlutterUxcam.tagScreenName(settings.name!);
        }
        return null; 
      },
    );
  }

  Future<void> _checkUserTeam(UserModel user) async {
    if (user.id == 0) return;
    final teamService = TeamService();
    final teamId = await teamService.fetchUserTeamId(user.id);
    if (teamId != null) {
      print('User ${user.id} belongs to team ID: $teamId');
    } else {
      print('User ${user.id} does not belong to any active team.');
    }
  }
}