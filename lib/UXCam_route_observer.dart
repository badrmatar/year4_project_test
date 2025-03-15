import 'package:flutter/material.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';



class AnalyticsRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _sendScreenView(route);
  }

  
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _sendScreenView(newRoute);
    }
  }

  
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    
    if (previousRoute != null) {
      _sendScreenView(previousRoute);
    }
  }

  
  void _sendScreenView(Route<dynamic> route) {
    if (route is PageRoute) {
      
      final screenName = route.settings.name ?? route.runtimeType.toString();
      
      FlutterUxcam.tagScreenName(screenName);
    }
  }
}
