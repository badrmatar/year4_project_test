

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/run_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    
    
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<UserModel>(context, listen: false);
      if (user.id == 0) {
        
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        
        
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/waiting_room');
              },
              child: const Text('Go to Waiting Room'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/challenges');
              },
              child: const Text('View Challenges'),
            ),

            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: () async {
                
                
                final user = Provider.of<UserModel>(context, listen: false);
                final userId = user.id;

                
                final startContributionId = await startNewRunInDatabase(userId);

                if (startContributionId != null) {
                  
                  Navigator.pushNamed(
                    context,
                    '/active_run',
                    arguments: startContributionId,
                  );
                } else {
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to start run.'))
                  );
                }
              },
              child: const Text('Start Run'),
            ),
          ],
        ),
      ),
    );
  }


}