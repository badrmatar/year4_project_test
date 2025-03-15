import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:year4_project/services/auth_service.dart';
import 'package:year4_project/services/analytics_service.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';
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


Future<void> initUXCam() async {
  try {
    
    
    FlutterUxConfig config = FlutterUxConfig(userAppKey: "pse1vvwkr8reerf");

    
    await FlutterUxcam.startWithConfiguration(config);

    
    await FlutterUxcam.optIntoSchematicRecordings();

    print('UXCam initialized successfully');
  } catch (e) {
    print('Error initializing UXCam: $e');
  }
}

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await initSupabase();
  await initPosthog();
  await initUXCam(); 

  
  await requestLocationPermission();

  final authService = AuthService();
  final isAuthenticated = await authService.checkAuthStatus();

  
  UserModel initialUserModel = UserModel(id: 0, email: '', name: '');

  
  if (isAuthenticated) {
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

      
      await FlutterUxcam.setUserIdentity(userData['id'].toString());

      
      try {
        await FlutterUxcam.setUserProperty("email", userData['email']);
        await FlutterUxcam.setUserProperty("name", userData['name']);
      } catch (e) {
        print('Could not set UXCam user properties: $e');
      }
    }
  }

  final initialRoute = isAuthenticated ? '/home' : '/login';

  runApp(
    ChangeNotifierProvider(
      create: (_) => initialUserModel,
      child: MyApp(initialRoute: initialRoute),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  final _routeObserver = AnalyticsRouteObserver();
  final _uxcamRouteObserver = UxcamRouteObserver();

  MyApp({Key? key, required this.initialRoute}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
        _uxcamRouteObserver, 
      ],
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const HomePage(),
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/waiting_room': (context) => WaitingRoomScreen(userId: user.id),
        '/challenges': (context) => const ChallengesPage(),
        '/journey_type': (context) => const JourneyTypePage(),
        '/duo_waiting_room': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
          as Map<String, dynamic>;
          return DuoWaitingRoom(teamChallengeId: args['team_challenge_id'] as int);
        },
        
        '/run_loading': (context) =>
        const RunLoadingPage(journeyType: 'solo', challengeId: 0),
        '/league_room': (context) => LeagueRoomPage(userId: user.id),
        '/history': (context) => const HistoryPage(),
        
        '/duo_active_run': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
          as Map<String, dynamic>;
          return DuoActiveRunPage(challengeId: args['team_challenge_id'] as int);
        },
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


class UxcamRouteObserver extends NavigatorObserver {
  
  final Map<String, String> _screenNames = {
    '/': 'Home',
    '/home': 'Home',
    '/login': 'Login',
    '/signup': 'Signup',
    '/waiting_room': 'Waiting Room',
    '/challenges': 'Challenges',
    '/journey_type': 'Journey Type',
    '/duo_waiting_room': 'Duo Waiting Room',
    '/run_loading': 'Run Loading',
    '/league_room': 'League Room',
    '/history': 'History',
    '/duo_active_run': 'Duo Active Run',
  };

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _tagScreen(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _tagScreen(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) _tagScreen(previousRoute);
  }

  void _tagScreen(Route<dynamic> route) {
    if (route.settings.name != null) {
      final routeName = route.settings.name!;

      
      final screenName = _screenNames[routeName] ?? routeName;

      
      String tagName = screenName;
      if (route.settings.arguments != null) {
        if (routeName == '/duo_waiting_room' || routeName == '/duo_active_run') {
          try {
            final args = route.settings.arguments as Map<String, dynamic>;
            if (args.containsKey('team_challenge_id')) {
              final challengeId = args['team_challenge_id'] as int;
              tagName = '$screenName (ID: $challengeId)';
            }
          } catch (e) {
            print('Error extracting arguments for UXCam: $e');
          }
        }
      }

      
      
      Future.delayed(const Duration(milliseconds: 1000), () {
        
        FlutterUxcam.tagScreenName(tagName);

        
        FlutterUxcam.logEvent('Screen View: $tagName');

        print('UXCam: Tagged screen "$tagName" after loading delay');
      });
    }
  }
}