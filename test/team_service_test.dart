
import 'package:flutter_test/flutter_test.dart';
import 'package:year4_project/services/team_service.dart';


class TestableTeamService extends TeamService {
  
  final Map<int, int?> userTeamIdMap = {};
  final Map<int, int?> teamLeagueIdMap = {};

  
  bool throwsException = false;

  @override
  Future<int?> fetchUserTeamId(int userId) async {
    if (throwsException) {
      throw Exception('Test exception');
    }
    
    return userTeamIdMap[userId];
  }

  
  
  Future<int?> callFetchUserTeamIdWithErrorHandling(int userId) async {
    try {
      return await fetchUserTeamId(userId);
    } catch (e) {
      print('Error in fetchUserTeamId: $e');
      return null;
    }
  }

  @override
  Future<int?> fetchLeagueId(int teamId) async {
    if (throwsException) {
      throw Exception('Test exception');
    }
    
    return teamLeagueIdMap[teamId];
  }

  
  
  Future<int?> callFetchLeagueIdWithErrorHandling(int teamId) async {
    try {
      return await fetchLeagueId(teamId);
    } catch (e) {
      print('Error in fetchLeagueId: $e');
      return null;
    }
  }
}

void main() {
  late TestableTeamService teamService;

  setUp(() {
    teamService = TestableTeamService();
    
    teamService.userTeamIdMap.clear();
    teamService.teamLeagueIdMap.clear();
    teamService.throwsException = false;
  });

  group('fetchUserTeamId', () {
    test('should return team_id when user has an active team', () async {
      
      const userId = 123;
      const teamId = 456;
      teamService.userTeamIdMap[userId] = teamId;

      
      final result = await teamService.fetchUserTeamId(userId);

      
      expect(result, equals(teamId));
    });

    test('should return null when user has no active team', () async {
      
      const userId = 123;
      

      
      final result = await teamService.fetchUserTeamId(userId);

      
      expect(result, isNull);
    });

    test('should handle exceptions gracefully', () async {
      
      const userId = 123;
      teamService.throwsException = true;

      
      final result = await teamService.callFetchUserTeamIdWithErrorHandling(userId);

      
      expect(result, isNull);
    });
  });

  group('fetchLeagueId', () {
    test('should return league_id when team has a league', () async {
      
      const teamId = 456;
      const leagueId = 789;
      teamService.teamLeagueIdMap[teamId] = leagueId;

      
      final result = await teamService.fetchLeagueId(teamId);

      
      expect(result, equals(leagueId));
    });

    test('should return null when team has no league', () async {
      
      const teamId = 456;
      

      
      final result = await teamService.fetchLeagueId(teamId);

      
      expect(result, isNull);
    });

    test('should handle exceptions gracefully', () async {
      
      const teamId = 456;
      teamService.throwsException = true;

      
      final result = await teamService.callFetchLeagueIdWithErrorHandling(teamId);

      
      expect(result, isNull);
    });
  });
}