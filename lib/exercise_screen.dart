import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'activitydetails_screen.dart';
import 'addactivity_screen.dart';
import 'package:fl_chart/fl_chart.dart';

class ExerciseMonitoringPage extends StatefulWidget {
  final String petType;
  final String breed;
  final int age;
  final String petId;
  final String userId;

  ExerciseMonitoringPage({
    required this.petType,
    required this.breed,
    required this.age,
    required this.petId,
    required this.userId,
  });

  @override
  _ExerciseMonitoringPageState createState() => _ExerciseMonitoringPageState();
}

class _ExerciseMonitoringPageState extends State<ExerciseMonitoringPage> {
  bool _isLoading = true;
  String _exerciseRecommendations = "Loading exercise recommendations...";
  DateTimeRange? _selectedDateRange;
  Map<String, dynamic> _activityStats = {};

  @override
  void initState() {
    super.initState();
    _loadExerciseRecommendations();
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(Duration(days: 7)),
      end: DateTime.now(),
    ); // Default to last 7 days
    _calculateActivityStats();
  }

  Future<void> _loadExerciseRecommendations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> breedData = await _loadBreedSpecificData(widget.petType);
      Map<String, dynamic> exerciseInfo = _generateExercisePlanWithDecisionTree(breedData);

      setState(() {
        _exerciseRecommendations = exerciseInfo['exercisePlan'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _exerciseRecommendations = "Error loading exercise recommendations: $e";
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _loadBreedSpecificData(String petType) async {
    String jsonString;
    if (petType.toLowerCase() == 'dog') {
      jsonString = await rootBundle.loadString('assets/dog_breeds.json');
    } else if (petType.toLowerCase() == 'cat') {
      jsonString = await rootBundle.loadString('assets/cat_breeds.json');
    } else {
      throw Exception("Unsupported pet type");
    }
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  Map<String, dynamic> _generateExercisePlanWithDecisionTree(Map<String, dynamic> breedData) {
    String breed = widget.breed.toLowerCase();
    int age = widget.age;

    List<dynamic> breeds = breedData[widget.petType.toLowerCase() == 'dog' ? 'Dog Breeds' : 'Cat Breeds'];
    Map<String, dynamic>? breedSpecificInfo = breeds.firstWhere(
          (breedInfo) => breedInfo['name'].toString().toLowerCase() == breed,
      orElse: () => null,
    );

    if (breedSpecificInfo == null) {
      return {'exercisePlan': 'No specific exercise recommendations found for this breed.'};
    }

    String activityLevel = breedSpecificInfo['activity_level'] ?? 'Unknown';
    String exerciseRecommendations = breedSpecificInfo['exercise_recommendations'] ?? 'No specific exercise recommendations available.';
    String ageCategory = age < 2 ? 'puppy' : (age >= 7 ? 'senior' : 'adult');
    String ageRelatedExercise = breedSpecificInfo['age_related_exercise'][ageCategory] ?? 'No age-related exercise advice available.';
    String specialHealthConsiderations = breedSpecificInfo['special_health_considerations'] ?? 'None';

    String exercisePlan = "Exercise Recommendations for $breed:\n";
    exercisePlan += "$activityLevel\n";
    exercisePlan += "$exerciseRecommendations\n";
    exercisePlan += "$ageRelatedExercise\n";
    exercisePlan += "$specialHealthConsiderations\n";

    return {'exercisePlan': exercisePlan};
  }

  Future<void> _calculateActivityStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('activityLogs')
          .where('date', isGreaterThanOrEqualTo: _selectedDateRange!.start)
          .where('date', isLessThanOrEqualTo: _selectedDateRange!.end)
          .get();

      int totalMinutes = 0;
      Map<String, int> intensityDistribution = {'Low': 0, 'Moderate': 0, 'High': 0};
      Map<String, int> typeBreakdown = {};

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        int duration = data['duration'] ?? 0;
        String intensity = data['intensity'] ?? 'Unknown';
        String activityType = data['activityType'] ?? 'Unknown';

        totalMinutes += duration;

        if (intensityDistribution.containsKey(intensity)) {
          intensityDistribution[intensity] = intensityDistribution[intensity]! + duration;
        } else {
          intensityDistribution[intensity] = duration;
        }

        if (typeBreakdown.containsKey(activityType)) {
          typeBreakdown[activityType] = typeBreakdown[activityType]! + duration;
        } else {
          typeBreakdown[activityType] = duration;
        }
      }

      Map<String, double> intensityPercentages = intensityDistribution.map((key, value) {
        double percentage = totalMinutes > 0 ? (value / totalMinutes) * 100 : 0;
        return MapEntry(key, percentage);
      });

      setState(() {
        _activityStats = {
          'totalMinutes': totalMinutes,
          'intensityDistribution': intensityPercentages,
          'typeBreakdown': typeBreakdown,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error calculating activity statistics: $e')),
      );
    }
  }

  Future<void> _selectDateRange() async {
    DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDateRange: _selectedDateRange,
    );

    if (pickedRange != null) {
      setState(() {
        _selectedDateRange = pickedRange;
      });
      _calculateActivityStats(); // Recalculate stats for the new date range
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Activity Tracker'),
              Tab(text: 'Exercise Recommendations and Tips'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Activity Logs', onAddPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddActivityScreen(petId: widget.petId, userId: widget.userId),
                      ),
                    );
                  }),
                  SizedBox(height: 10),
                  _buildActivityLogs(),
                  SizedBox(height: 20),
                  Text(
                    "Activity Analysis",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _selectDateRange,
                    child: Text('Select Date Range'),
                  ),
                  SizedBox(height: 10),
                  _buildActivityStats(),
                ],
              ),
            ),
            _buildExerciseRecommendationsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {required VoidCallback onAddPressed}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        TextButton(
          onPressed: onAddPressed,
          child: Row(
            children: [
              Icon(Icons.add, color: Colors.black),
              Text('Add', style: TextStyle(color: Colors.black)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityLogs() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('activityLogs')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching activity logs'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No activity logs available'));
        }

        final activityLogs = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: activityLogs.length,
          itemBuilder: (context, index) {
            final activity = activityLogs[index];
            return _buildActivityCard(
              activity.id,
              activity['activityType'] ?? 'No Activity Type',
              activity['duration']?.toString() ?? '0',
              activity['intensity'] ?? 'Unknown',
              activity['date'],
              activity['notes'] ?? '',
            );
          },
        );
      },
    );
  }

  Widget _buildActivityCard(String activityId, String activityType, String duration, String intensity, Timestamp date, String notes) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActivityDetailsScreen(
              activityId: activityId,
              petId: widget.petId,
              userId: widget.userId,
            ),
          ),
        );
      },
      onLongPress: () => _confirmDelete(activityId),
      child: Card(
        color: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activityType,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text('Duration: $duration minutes', style: TextStyle(fontSize: 16)),
              Text('Intensity: $intensity', style: TextStyle(fontSize: 16)),
              Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(date.toDate())}', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              SizedBox(height: 5),
              Text('Notes: ${notes.isNotEmpty ? notes : 'No notes available'}', style: TextStyle(fontSize: 16, color: Colors.grey[800])),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String activityId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Activity'),
        content: Text('Are you sure you want to delete this activity?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteActivity(activityId);
              Navigator.of(context).pop();
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteActivity(String activityId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('activityLogs')
          .doc(activityId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Activity deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting activity: $e')),
      );
    }
  }

  Widget _buildActivityStats() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    int totalMinutes = _activityStats['totalMinutes'] ?? 0;
    Map<String, double> intensityDistribution = _activityStats['intensityDistribution'] ?? {};
    Map<String, int> typeBreakdown = _activityStats['typeBreakdown'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Total Time Spent: ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black), // Bold text
              ),
              TextSpan(
                text: '${totalMinutes} minutes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal,color: Colors.black), // Normal text
              ),
            ],
          ),
        ),
        SizedBox(height: 15),

        // Intensity Distribution Text and Pie Chart
        Text('Intensity Distribution:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        _buildIntensityPieChart(intensityDistribution),
        SizedBox(height: 10),

        // Time Breakdown by Activity Type
        Text('Time Breakdown by Activity Type:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ...typeBreakdown.entries.map((entry) {
          return Text('${entry.key}: ${entry.value} minutes', style: TextStyle(fontSize: 16));
        }).toList(),

        SizedBox(height: 20),
        Text('Time Breakdown Bar Chart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        _buildActivityTypeBarChart(typeBreakdown),
      ],
    );

  }

// Helper to build the intensity distribution pie chart
  Widget _buildIntensityPieChart(Map<String, double> intensityDistribution) {
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: intensityDistribution.entries.map((entry) {
            return PieChartSectionData(
              color: _getIntensityColor(entry.key), // Assign a color based on intensity type
              value: entry.value,
              title: '${entry.key}\n${entry.value.toStringAsFixed(1)}%', // Display activity and percentage
              radius: 60,
              titleStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
              titlePositionPercentageOffset: 0.55, // Adjust title position if necessary
            );
          }).toList(),
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

// Helper to assign colors based on intensity type
  Color _getIntensityColor(String intensity) {
    switch (intensity) {
      case 'Low':
        return Colors.green;
      case 'Moderate':
        return Colors.yellow;
      case 'High':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildActivityTypeBarChart(Map<String, int> typeBreakdown) {
    List<BarChartGroupData> barChartGroups = [];
    int index = 0;

    typeBreakdown.forEach((activityType, duration) {
      barChartGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: duration.toDouble(),
              color: Colors.blue,
              width: 25,
            ),
          ],
          showingTooltipIndicators: [0],
        ),
      );
      index++;
    });

    return Container(
      height: 300,
      child: BarChart(
        BarChartData(
          backgroundColor: Colors.white60,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              //tooltipBackgroundgColor: Colors.grey[700],
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                String activityType = typeBreakdown.keys.elementAt(group.x.toInt());
                // return BarTooltipItem(
                //   '$activityType\n${rod.toY.toInt()} minutes',
                //   TextStyle(color: Colors.white),
                // );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, interval: 10),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      typeBreakdown.keys.elementAt(value.toInt()),
                      style: TextStyle(fontSize: 12),
                    ),
                  );
                },
                reservedSize: 50,
              ),
            ),
          ),
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: false),
          barGroups: barChartGroups,
        ),
      ),
    );
  }



  Widget _buildExerciseRecommendationsTab() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    } else {
      List<String> exercisePlanSections = _exerciseRecommendations.split('\n');


      String petType = widget.petType;
      String trainingTips = _getTrainingTips(petType);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildExerciseCard('Activity Level', exercisePlanSections[1]),
              _buildExerciseCard('Exercise Recommendations', exercisePlanSections[2]),
              _buildExerciseCard('Age-Related Exercise', exercisePlanSections[3]),
              _buildExerciseCard('Special Health Considerations', exercisePlanSections[4]),
              // New compartment for training tips
              _buildTipsCard('Training Tips', trainingTips),
            ],
          ),
        ),
      );
    }
  }

// Method to get training tips based on pet type
  String _getTrainingTips(String petType) {
    if (petType.toLowerCase() == 'dog') {
      return '''
10 Simple Dog Training Tips:\n
1. Use Positive Reinforcement: Reward your dog for good behavior.\n
2. Find the Right Reward: Some dogs prefer treats, others play or affection.\n
3. Be Consistent: Use the same commands and tone every time.\n
4. Train Frequently but Briefly: Keep sessions to 5 minutes.\n
5. Build Up Gradually: Break complex behaviors into smaller steps.\n
6. Make It Fun: Mix in playtime and teach fun tricks.\n
7. Praise Small Improvements: Celebrate every progress.\n
8. Incorporate Training into Daily Life: Use commands during regular activities.\n
9. Use Hand Signals: Combine gestures with verbal commands.\n
10. Get Professional Help: Consider hiring a trainer if needed.\n
''';
    } else {
      return '''
9 Simple Cat Training Tips:\n
1. Start Simple: Teach your cat basic skills first.\n
2. Keep Sessions Short: Limit training to 3-5 minutes a day.\n
3. Minimize Distractions: Choose a quiet spot for training.\n
4. Reward Right Away: Use a clicker and treat immediately.\n
5. Choose the Right Treats: Find what your cat likes best.\n
6. No Punishments: Avoid punishing bad behavior; redirect instead.\n
7. Be Consistent: Use the same commands and signals.\n
8. Pick the Right Time: Train when your cat is alert.\n
9. Involve Others: Get family members involved for consistency.
''';
    }
  }

// Widget to build the tips card
  Widget _buildTipsCard(String title, String tips) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.0),
            Text(tips, style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }


  Widget _buildExerciseCard(String title, String content) {
    return Card(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              content,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
