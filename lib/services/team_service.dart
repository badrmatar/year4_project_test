
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamService {
  
  final SupabaseClient? _testClient;

  
  TeamService({SupabaseClient? testClient}) : _testClient = testClient;

  
  SupabaseClient get _client => _testClient ?? Supabase.instance.client;

  
  
  Future<int?> fetchUserTeamId(int userId) async {
    try {
      
      final response = await _client
          .from('team_memberships')
          .select('team_id')
          .eq('user_id', userId)
          .filter('date_left', 'is', null) 
          .maybeSingle();

      
      if (response == null) {
        return null;
      }

      
      if (response is Map<String, dynamic>) {
        return response['team_id'] as int?;
      }

      return null;
    } catch (e) {
      
      print('Error fetching user team: $e');
      return null;
    }
  }

  
  Future<int?> fetchLeagueId(int teamId) async {
    try {
      final response = await _client
          .from('teams')
          .select('league_id')
          .eq('id', teamId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      if (response is Map<String, dynamic>) {
        return response['league_id'] as int?;
      }

      return null;
    } catch (e) {
      print('Error fetching league ID: $e');
      return null;
    }
  }
}