import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/challenge.dart';
import '../models/user.dart';
import '../widgets/challenge_card.dart';
import '../services/analytics_service.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({Key? key}) : super(key: key);

  @override
  _ChallengesPageState createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  late Future<Map<String, dynamic>> _challengesData;

  @override
  void initState() {
    super.initState();
    _challengesData = _fetchChallengesAndTeamStatus();
  }

  String _getTimeRemaining(DateTime startTime, int? duration) {
    if (duration == null) return 'N/A';
    final endTime = startTime.add(Duration(minutes: duration));
    final now = DateTime.now().toUtc();
    if (now.isAfter(endTime)) return 'Expired';
    final remaining = endTime.difference(now);
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

  Future<Map<String, dynamic>> _fetchChallengesAndTeamStatus() async {
    final supabase = Supabase.instance.client;
    final user = Provider.of<UserModel>(context, listen: false);
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      
      final challengesResponse = await supabase
          .from('challenges')
          .select()
          .gte('start_time', startOfDay.toIso8601String())
          .lt('start_time', endOfDay.toIso8601String());
      final List challengesList = challengesResponse as List;

      
      final teamMembershipResponse = await supabase
          .from('team_memberships')
          .select('team_id')
          .eq('user_id', user.id)
          .filter('date_left', 'is', null)
          .limit(1)
          .maybeSingle();

      if (teamMembershipResponse == null) {
        throw Exception('No active team membership found');
      }
      final Map teamMembershipData = teamMembershipResponse;
      final teamId = teamMembershipData['team_id'];

      
      final teamChallengesResponse = await supabase
          .from('team_challenges')
          .select('*, challenges(start_time), user_contributions(distance_covered, journey_type)')
          .eq('team_id', teamId)
          .order('team_challenge_id', ascending: false);

      final List allTeamChallengesList = teamChallengesResponse as List;

      
      final currentDate = DateTime.now().toUtc();
      final todayStart = DateTime.utc(currentDate.year, currentDate.month, currentDate.day);

      final todaysTeamChallenges = allTeamChallengesList.where((tc) {
        final challengeStartTime = tc['challenges'] != null ?
        DateTime.parse(tc['challenges']['start_time']) : null;
        if (challengeStartTime == null) return false;

        return challengeStartTime.isAfter(todayStart) ||
            (challengeStartTime.year == todayStart.year &&
                challengeStartTime.month == todayStart.month &&
                challengeStartTime.day == todayStart.day);
      }).toList();

      
      final activeTeamChallenges = todaysTeamChallenges
          .where((tc) => tc['iscompleted'] == false)
          .toList();

      
      final completedTeamChallenges = todaysTeamChallenges
          .where((tc) => tc['iscompleted'] == true)
          .toList();

      
      dynamic activeTeamChallenge;
      if (activeTeamChallenges.isNotEmpty) {
        activeTeamChallenge = _calculateDistances(activeTeamChallenges.first);
      }

      
      dynamic completedTeamChallenge;
      if (completedTeamChallenges.isNotEmpty) {
        completedTeamChallenge = _calculateDistances(completedTeamChallenges.first);
      }

      return {
        'challenges': challengesList,
        'activeTeamChallenge': activeTeamChallenge,
        'completedTeamChallenge': completedTeamChallenge,
        'hasChallengeToday': todaysTeamChallenges.isNotEmpty,
      };
    } catch (e) {
      debugPrint('Error fetching challenges and team status: $e');
      rethrow;
    }
  }

  
  dynamic _calculateDistances(dynamic teamChallenge) {
    final contributions = teamChallenge['user_contributions'] as List? ?? [];
    final totalDistance = contributions.fold<double>(
      0,
          (sum, contrib) => sum + (contrib['distance_covered'] ?? 0),
    );
    final duoDistance = contributions
        .where((contrib) => contrib['journey_type'] == 'duo')
        .fold<double>(
      0,
          (sum, contrib) => sum + (contrib['distance_covered'] ?? 0),
    );
    return {
      ...teamChallenge,
      'total_distance': totalDistance,
      'duo_distance': duoDistance,
    };
  }

  Future<void> _handleChallengeAction(
      Challenge challenge,
      dynamic activeTeamChallenge,
      dynamic completedTeamChallenge,
      bool hasChallengeToday,
      BuildContext context,
      ) async {
    
    if (activeTeamChallenge != null) {
      
      AnalyticsService().client.trackEvent('challenge_continue', {
        'challenge_id': challenge.challengeId,
      });

      Navigator.pushNamed(
        context,
        '/journey_type',
        arguments: {
          'challenge_id': challenge.challengeId,
          'team_challenge_id': activeTeamChallenge['team_challenge_id']
        },
      );
      return;
    }

    
    if (completedTeamChallenge != null || hasChallengeToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your team has already completed a challenge today. Only one challenge per day is allowed.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    
    AnalyticsService().client.trackEvent('challenge_assign_attempt', {
      'challenge_id': challenge.challengeId,
    });

    final success = await _assignChallengeToTeam(challenge.challengeId, context);
    if (success) {
      
      AnalyticsService().client.trackEvent('challenge_assign_success', {
        'challenge_id': challenge.challengeId,
      });

      Navigator.pushNamed(
        context,
        '/journey_type',
        arguments: {'challenge_id': challenge.challengeId},
      );
    } else {
      
      AnalyticsService().client.trackEvent('challenge_assign_fail', {
        'challenge_id': challenge.challengeId,
      });
    }
  }

  Future<bool> _assignChallengeToTeam(int challengeId, BuildContext context) async {
    final user = Provider.of<UserModel>(context, listen: false);
    final url = '${dotenv.env['SUPABASE_URL']}/functions/v1/assign_challenge_to_team';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${dotenv.env['BEARER_TOKEN']}',
        },
        body: jsonEncode({'user_id': user.id, 'challenge_id': challengeId}),
      );
      if (response.statusCode == 200) {
        setState(() {
          _challengesData = _fetchChallengesAndTeamStatus();
        });
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorData['error'] ?? 'Failed to start challenge')),
        );
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1F1F1F),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
        ),
        title: const Text(
          "Today's Challenges",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _challengesData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          } else if (!snapshot.hasData ||
              (snapshot.data!['challenges'] as List).isEmpty) {
            return const Center(
              child: Text(
                'No challenges found for today.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final data = snapshot.data!;
          final challenges = (data['challenges'] as List)
              .map((item) => Challenge.fromJson(item))
              .toList();
          final activeTeamChallenge = data['activeTeamChallenge'];
          final completedTeamChallenge = data['completedTeamChallenge'];
          final hasChallengeToday = data['hasChallengeToday'] ?? false;

          return ListView.builder(
            itemCount: challenges.length,
            itemBuilder: (context, index) {
              final challenge = challenges[index];
              return ChallengeCard(
                challenge: challenge,
                activeTeamChallenge: activeTeamChallenge,
                completedTeamChallenge: completedTeamChallenge,
                hasChallengeToday: hasChallengeToday,
                onPressed: (chal, active, completed, hasChallenge, ctx) =>
                    _handleChallengeAction(chal, active, completed, hasChallenge, ctx),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class GetMovingBanner extends StatelessWidget {
  const GetMovingBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Text(
          "Let's",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          "get",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          "moving",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}