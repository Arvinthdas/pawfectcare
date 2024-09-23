import 'package:flutter/material.dart';

class ExerciseMonitoringPage extends StatefulWidget {
  @override
  _ExerciseMonitoringPageState createState() => _ExerciseMonitoringPageState();
}

class _ExerciseMonitoringPageState extends State<ExerciseMonitoringPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      appBar: AppBar(
        backgroundColor: Color(0xFFE2BF65),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Exercise Monitoring',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise Log Section
            SectionTitle(title: 'Exercise Log'),
            ExerciseLogCard(
              activity: 'Morning Walk',
              duration: '30 minutes',
              date: 'Mon 24 Jan',
            ),
            ExerciseLogCard(
              activity: 'Evening Playtime',
              duration: '45 minutes',
              date: 'Sun 23 Jan',
            ),
            SizedBox(height: 20),

            // Activity Recommendations Section
            SectionTitle(title: 'Activity Recommendations'),
            RecommendationCard(
              recommendation: 'Daily walks for at least 30 minutes.',
            ),
            RecommendationCard(
              recommendation: 'Engage in interactive play to stimulate mental activity.',
            ),
            SizedBox(height: 20),

            // Goal Setting Section
            SectionTitle(title: 'Set Exercise Goals'),
            GoalSettingCard(
              goalName: 'Daily Walks',
              goalDescription: 'Walk your pet for at least 30 minutes daily.',
              progress: 70,  // Example progress percentage
            ),
            GoalSettingCard(
              goalName: 'Playtime',
              goalDescription: 'Engage in 1 hour of playtime weekly.',
              progress: 40,  // Example progress percentage
            ),
            SizedBox(height: 20),

            // Progress Tracking Section
            SectionTitle(title: 'Progress Tracking'),
            ProgressTrackingCard(
              title: 'Weekly Exercise Tracker',
              progress: 60,  // Example progress percentage
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;

  SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class ExerciseLogCard extends StatelessWidget {
  final String activity;
  final String duration;
  final String date;

  ExerciseLogCard({
    required this.activity,
    required this.duration,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 15),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                duration,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              Text(
                date,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          Icon(Icons.chevron_right, color: Colors.black54),
        ],
      ),
    );
  }
}

class RecommendationCard extends StatelessWidget {
  final String recommendation;

  RecommendationCard({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 15),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              recommendation,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.black54),
        ],
      ),
    );
  }
}

class GoalSettingCard extends StatelessWidget {
  final String goalName;
  final String goalDescription;
  final int progress;

  GoalSettingCard({
    required this.goalName,
    required this.goalDescription,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 15),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            goalName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          Text(
            goalDescription,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: Colors.grey[200],
            color: Colors.teal,
          ),
          SizedBox(height: 5),
          Text(
            '$progress% completed',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressTrackingCard extends StatelessWidget {
  final String title;
  final int progress;

  ProgressTrackingCard({
    required this.title,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: Colors.grey[200],
            color: Colors.teal,
          ),
          SizedBox(height: 5),
          Text(
            '$progress% completed',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
