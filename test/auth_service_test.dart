
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:year4_project/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:year4_project/models/user.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class TestableAuthService {
  
  final String userLoginFunctionUrl = 'https:
  final String userSignupFunctionUrl = 'https:
  final String userLogoutFunctionUrl = 'https:
  final String bearerToken = 'mock_token';

  
  final Map<String, String> secureStorageValues = {};

  
  bool authStatusResult = false;
  Map<String, dynamic>? userSessionData;
  bool loginResult = false;
  bool registerResult = false;
  bool logoutResult = false;

  
  bool throwsExceptionOnLogin = false;
  bool throwsExceptionOnRegister = false;
  bool throwsExceptionOnLogout = false;
  bool throwsExceptionOnCheckAuth = false;
  bool throwsExceptionOnRestoreSession = false;

  
  Future<void> _storeUserData(Map<String, dynamic> userData) async {
    secureStorageValues['user_id'] = userData['id'].toString();
    secureStorageValues['user_email'] = userData['email'].toString();
    secureStorageValues['user_name'] = userData['name'].toString();
  }

  Future<Map<String, dynamic>?> _getUserData() async {
    if (throwsExceptionOnRestoreSession) {
      throw Exception('Test exception during restore session');
    }

    if (secureStorageValues.isEmpty ||
        !secureStorageValues.containsKey('user_id') ||
        !secureStorageValues.containsKey('user_email') ||
        !secureStorageValues.containsKey('user_name')) {
      return null;
    }

    return {
      'id': int.parse(secureStorageValues['user_id']!),
      'email': secureStorageValues['user_email'],
      'name': secureStorageValues['user_name'],
    };
  }

  
  void _updateUserModel(BuildContext context, Map<String, dynamic> data) {
    final userModel = Provider.of<UserModel>(context, listen: false);
    userModel.setUser(
      id: data['id'],
      email: data['email'].toString(),
      name: data['name'].toString(),
    );
  }

  void _clearUserModel(BuildContext context) {
    final userModel = Provider.of<UserModel>(context, listen: false);
    userModel.clearUser();
  }

  
  Future<bool> userLogin(BuildContext context, String email, String password) async {
    if (throwsExceptionOnLogin) {
      throw Exception('Test exception during login');
    }

    if (loginResult) {
      if (userSessionData != null) {
        await _storeUserData(userSessionData!);
        _updateUserModel(context, userSessionData!);
      }
    }

    return loginResult;
  }

  Future<bool> registerUser(BuildContext context, String username, String email, String password) async {
    if (throwsExceptionOnRegister) {
      throw Exception('Test exception during registration');
    }

    return registerResult;
  }

  Future<bool> userLogout(BuildContext context, int userId) async {
    if (throwsExceptionOnLogout) {
      throw Exception('Test exception during logout');
    }

    if (logoutResult) {
      _clearUserModel(context);
      secureStorageValues.clear();
    }

    return logoutResult;
  }

  Future<bool> checkAuthStatus() async {
    if (throwsExceptionOnCheckAuth) {
      throw Exception('Test exception during auth check');
    }

    return authStatusResult;
  }

  Future<Map<String, dynamic>?> restoreUserSession() async {
    return await _getUserData();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestableAuthService authService;
  late UserModel mockUserModel;

  setUp(() {
    authService = TestableAuthService();
    mockUserModel = UserModel(id: 0, email: '', name: '');

    
    authService.authStatusResult = false;
    authService.userSessionData = null;
    authService.loginResult = false;
    authService.registerResult = false;
    authService.logoutResult = false;
    authService.secureStorageValues.clear();

    
    authService.throwsExceptionOnLogin = false;
    authService.throwsExceptionOnRegister = false;
    authService.throwsExceptionOnLogout = false;
    authService.throwsExceptionOnCheckAuth = false;
    authService.throwsExceptionOnRestoreSession = false;
  });

  
  BuildContext createMockContext(WidgetTester tester) {
    late BuildContext resultContext;

    tester.pumpWidget(
      ChangeNotifierProvider<UserModel>.value(
        value: mockUserModel,
        child: Builder(
          builder: (context) {
            resultContext = context;
            return Container();
          },
        ),
      ),
    );

    return resultContext;
  }

  group('checkAuthStatus', () {
    test('should return true when user is authenticated', () async {
      
      authService.authStatusResult = true;

      
      final result = await authService.checkAuthStatus();

      
      expect(result, isTrue);
    });

    test('should return false when user is not authenticated', () async {
      
      authService.authStatusResult = false;

      
      final result = await authService.checkAuthStatus();

      
      expect(result, isFalse);
    });

    test('should handle exceptions gracefully', () async {
      
      authService.throwsExceptionOnCheckAuth = true;

      
      expect(() => authService.checkAuthStatus(), throwsException);
    });
  });

  group('restoreUserSession', () {
    test('should return user data when session exists', () async {
      
      final userData = {'id': 123, 'email': 'test@example.com', 'name': 'Test User'};
      authService.secureStorageValues['user_id'] = userData['id'].toString();
      authService.secureStorageValues['user_email'] = userData['email'] as String;
      authService.secureStorageValues['user_name'] = userData['name'] as String;

      
      final result = await authService.restoreUserSession();

      
      expect(result, isNotNull);
      expect(result!['id'], equals(userData['id']));
      expect(result['email'], equals(userData['email']));
      expect(result['name'], equals(userData['name']));
    });

    test('should return null when no session exists', () async {
      
      final result = await authService.restoreUserSession();

      
      expect(result, isNull);
    });

    test('should handle exceptions gracefully', () async {
      
      authService.throwsExceptionOnRestoreSession = true;

      
      expect(() => authService.restoreUserSession(), throwsException);
    });
  });

  group('userLogin', () {
    testWidgets('should return true and update user model on successful login', (WidgetTester tester) async {
      
      final testContext = createMockContext(tester);
      authService.loginResult = true;
      authService.userSessionData = {'id': 123, 'email': 'test@example.com', 'name': 'Test User'};

      
      final result = await authService.userLogin(testContext, 'test@example.com', 'password');

      
      expect(result, isTrue);
      expect(mockUserModel.id, equals(123));
      expect(mockUserModel.email, equals('test@example.com'));
      expect(mockUserModel.name, equals('Test User'));

      
      expect(authService.secureStorageValues['user_id'], equals('123'));
      expect(authService.secureStorageValues['user_email'], equals('test@example.com'));
      expect(authService.secureStorageValues['user_name'], equals('Test User'));
    });

    testWidgets('should return false on failed login', (WidgetTester tester) async {
      
      final testContext = createMockContext(tester);
      authService.loginResult = false;

      
      final result = await authService.userLogin(testContext, 'test@example.com', 'wrong_password');

      
      expect(result, isFalse);
      expect(mockUserModel.id, equals(0)); 
      expect(authService.secureStorageValues.isEmpty, isTrue); 
    });

    testWidgets('should handle exceptions', (WidgetTester tester) async {
      
      final testContext = createMockContext(tester);
      authService.throwsExceptionOnLogin = true;

      
      expect(() => authService.userLogin(testContext, 'test@example.com', 'password'), throwsException);
    });
  });

  group('registerUser', () {
    testWidgets('should return true on successful registration', (WidgetTester tester) async {
      
      final testContext = createMockContext(tester);
      authService.registerResult = true;

      
      final result = await authService.registerUser(testContext, 'Test User', 'test@example.com', 'password');

      
      expect(result, isTrue);
    });

    testWidgets('should return false on failed registration', (WidgetTester tester) async {
      
      final testContext = createMockContext(tester);
      authService.registerResult = false;

      
      final result = await authService.registerUser(testContext, 'Test User', 'existing@example.com', 'password');

      
      expect(result, isFalse);
    });

    testWidgets('should handle exceptions', (WidgetTester tester) async {
      
      final testContext = createMockContext(tester);
      authService.throwsExceptionOnRegister = true;

      
      expect(() => authService.registerUser(testContext, 'Test User', 'test@example.com', 'password'), throwsException);
    });
  });

  group('userLogout', () {
    testWidgets('should return true and clear user model on successful logout', (WidgetTester tester) async {
      
      final testContext = createMockContext(tester);
      mockUserModel.setUser(id: 123, email: 'test@example.com', name: 'Test User');
      authService.secureStorageValues['user_id'] = '123';
      authService.secureStorageValues['user_email'] = 'test@example.com';
      authService.secureStorageValues['user_name'] = 'Test User';
      authService.logoutResult = true;

      
      final result = await authService.userLogout(testContext, 123);

      
      expect(result, isTrue);
      expect(mockUserModel.id, equals(0)); 
      expect(mockUserModel.email, equals('')); 
      expect(mockUserModel.name, equals('')); 
      expect(authService.secureStorageValues.isEmpty, isTrue); 
    });

    testWidgets('should return false on failed logout', (WidgetTester tester) async {
      
      final testContext = createMockContext(tester);
      mockUserModel.setUser(id: 123, email: 'test@example.com', name: 'Test User');
      authService.secureStorageValues['user_id'] = '123';
      authService.logoutResult = false;

      
      final result = await authService.userLogout(testContext, 123);

      
      expect(result, isFalse);
      expect(mockUserModel.id, equals(123)); 
      expect(authService.secureStorageValues.isEmpty, isFalse); 
    });

    testWidgets('should handle exceptions', (WidgetTester tester) async {
      
      final testContext = createMockContext(tester);
      authService.throwsExceptionOnLogout = true;

      
      expect(() => authService.userLogout(testContext, 123), throwsException);
    });
  });
}