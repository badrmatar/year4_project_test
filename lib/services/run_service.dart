import 'package:supabase_flutter/supabase_flutter.dart';

Future<int?> startNewRunInDatabase(int userId) async {
  final supabase = Supabase.instance.client;

  try {
    final data = await supabase
        .from('user_contributions')
        .insert({
      'team_challenge_id': 1,
      'user_id': userId,
      'start_time': DateTime.now().toUtc().toIso8601String(),
      'end_time': DateTime.now().toUtc().toIso8601String(),
      'start_latitude': 0.0,
      'start_longitude': 0.0,
      'end_latitude': 0.0,
      'end_longitude': 0.0,
      'contribution_details': null,
      'active': true,
    })
        .select()
        .single() as Map<String, dynamic>; 

    
    final userContributionId = data['user_contribution_id'] as int;
    return userContributionId;
  } catch (e) {
    print('Exception in startNewRunInDatabase: $e');
    return null;
  }
}
