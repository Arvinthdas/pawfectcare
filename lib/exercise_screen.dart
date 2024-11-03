import 'dart:convert'; // Importing dart package for JSON encoding and decoding.
import 'package:flutter/material.dart'; // Importing Flutter package for UI components.
import 'package:flutter/services.dart'; // Importing services for working with assets like JSON.
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firebase Firestore for database interactions.
import 'package:intl/intl.dart'; // Importing intl package for date formatting.
import 'activitydetails_screen.dart'; // Importing a custom screen for activity details.
import 'addactivity_screen.dart'; // Importing a custom screen for adding an activity.
import 'package:fl_chart/fl_chart.dart'; // Importing fl_chart package for chart visualizations.

class ExerciseMonitoringPage extends StatefulWidget {
  final String petType; // Pet type (e.g., dog or cat).
  final String breed; // Breed of the pet.
  final int age; // Age of the pet.
  final String petId; // ID of the pet.
  final String userId; // ID of the user.

  // Constructor to initialize the above fields.
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

// Stateful widget to manage the state of the exercise monitoring page.
class _ExerciseMonitoringPageState extends State<ExerciseMonitoringPage> {
  bool _isLoading = true; // Variable to track loading state.
  String _exerciseRecommendations =
      "Loading exercise recommendations..."; // Default exercise recommendation message.
  DateTimeRange? _selectedDateRange; // Variable to store selected date range.
  Map<String, dynamic> _activityStats = {}; // Map to store activity statistics.

  @override
  void initState() {
    super.initState(); // Call the parent's initState method.
    _loadExerciseRecommendations(); // Load exercise recommendations when the page initializes.
    // Default date range is set to the last 7 days.
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now(),
    );
    _calculateActivityStats(); // Calculate activity stats on initialization.
  }

  // Function to load exercise recommendations based on breed data.
  Future<void> _loadExerciseRecommendations() async {
    setState(() {
      _isLoading = true; // Set loading state to true.
    });

    try {
      // Load breed-specific data from the JSON file based on pet type.
      Map<String, dynamic> breedData =
          await _loadBreedSpecificData(widget.petType);
      // Generate an exercise plan using the loaded breed data.
      Map<String, dynamic> exerciseInfo =
      _generateExercisePlanWithConditions(breedData);

      setState(() {
        _exerciseRecommendations =
            exerciseInfo['exercisePlan']; // Set exercise recommendations.
        _isLoading = false; // Stop loading once the recommendations are loaded.
      });
    } catch (e) {
      setState(() {
        // Handle any errors and stop loading.
        _exerciseRecommendations = "Error loading exercise recommendations: $e";
        _isLoading = false;
      });
    }
  }

  // Function to load breed-specific data from a JSON file.
  Future<Map<String, dynamic>> _loadBreedSpecificData(String petType) async {
    String jsonString; // Declare a variable to hold the JSON string.
    if (petType.toLowerCase() == 'dog') {
      // Load dog breeds JSON if pet type is 'dog'.
      jsonString = await rootBundle.loadString('assets/dog_breeds.json');
    } else if (petType.toLowerCase() == 'cat') {
      // Load cat breeds JSON if pet type is 'cat'.
      jsonString = await rootBundle.loadString('assets/cat_breeds.json');
    } else {
      // Throw an error if pet type is unsupported.
      throw Exception("Unsupported pet type");
    }
    // Return the parsed JSON data as a Map.
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  // Function to generate exercise plan using decision logic based on breed data.
  Map<String, dynamic> _generateExercisePlanWithConditions(
      Map<String, dynamic> breedData) {
    String breed = widget.breed.toLowerCase(); // Convert breed to lowercase.
    int age = widget.age; // Get the pet's age.

    // Fetch the breed-specific info from the breed data.
    List<dynamic> breeds = breedData[
        widget.petType.toLowerCase() == 'dog' ? 'Dog Breeds' : 'Cat Breeds'];
    Map<String, dynamic>? breedSpecificInfo = breeds.firstWhere(
      (breedInfo) => breedInfo['name'].toString().toLowerCase() == breed,
      orElse: () => null,
    );

    // If breed-specific info is not found, return a default message.
    if (breedSpecificInfo == null) {
      return {
        'exercisePlan':
            'No specific exercise recommendations found for this breed.'
      };
    }

    // Get the activity level, exercise recommendations, and age-related exercises.
    String activityLevel = breedSpecificInfo['activity_level'] ?? 'Unknown';
    String exerciseRecommendations =
        breedSpecificInfo['exercise_recommendations'] ??
            'No specific exercise recommendations available.';
    String ageCategory = age < 2 ? 'puppy' : (age >= 7 ? 'senior' : 'adult');
    String ageRelatedExercise = breedSpecificInfo['age_related_exercise']
            [ageCategory] ??
        'No age-related exercise advice available.';
    String specialHealthConsiderations =
        breedSpecificInfo['special_health_considerations'] ?? 'None';

    // Build the exercise plan string.
    String exercisePlan = "Exercise Recommendations for $breed:\n";
    exercisePlan += "$activityLevel\n";
    exercisePlan += "$exerciseRecommendations\n";
    exercisePlan += "$ageRelatedExercise\n";
    exercisePlan += "$specialHealthConsiderations\n";

    return {
      'exercisePlan': exercisePlan
    }; // Return the generated exercise plan.
  }

  // Function to calculate activity statistics for the selected date range.
  Future<void> _calculateActivityStats() async {
    setState(() {
      _isLoading = true; // Set loading state to true while fetching data.
    });

    try {
      // Fetch activity logs from Firestore for the selected date range.
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('activityLogs')
          .where('date', isGreaterThanOrEqualTo: _selectedDateRange!.start)
          .where('date', isLessThanOrEqualTo: _selectedDateRange!.end)
          .get();

      int totalMinutes = 0; // Total activity duration.
      // Maps to store intensity distribution and activity type breakdown.
      Map<String, int> intensityDistribution = {
        'Low': 0,
        'Moderate': 0,
        'High': 0
      };
      Map<String, int> typeBreakdown = {};

      // Loop through activity logs and calculate stats.
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        int duration = data['duration'] ?? 0;
        String intensity = data['intensity'] ?? 'Unknown';
        String activityType = data['activityType'] ?? 'Unknown';

        totalMinutes += duration; // Accumulate total duration.

        // Update intensity distribution map.
        if (intensityDistribution.containsKey(intensity)) {
          intensityDistribution[intensity] =
              intensityDistribution[intensity]! + duration;
        } else {
          intensityDistribution[intensity] = duration;
        }

        // Update activity type breakdown map.
        if (typeBreakdown.containsKey(activityType)) {
          typeBreakdown[activityType] = typeBreakdown[activityType]! + duration;
        } else {
          typeBreakdown[activityType] = duration;
        }
      }

      // Calculate percentages for intensity distribution.
      Map<String, double> intensityPercentages =
          intensityDistribution.map((key, value) {
        double percentage = totalMinutes > 0 ? (value / totalMinutes) * 100 : 0;
        return MapEntry(key, percentage);
      });

      setState(() {
        // Store calculated statistics.
        _activityStats = {
          'totalMinutes': totalMinutes,
          'intensityDistribution': intensityPercentages,
          'typeBreakdown': typeBreakdown,
        };
        _isLoading = false; // Stop loading.
      });
    } catch (e) {
      setState(() {
        _isLoading = false; // Stop loading in case of error.
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error calculating activity statistics: $e')),
      );
    }
  }

  // Function to allow the user to select a date range.
  Future<void> _selectDateRange() async {
    DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDateRange: _selectedDateRange,
    );

    // If a valid date range is selected, recalculate stats.
    if (pickedRange != null) {
      setState(() {
        _selectedDateRange = pickedRange;
      });
      _calculateActivityStats(); // Recalculate stats for the new date range.
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor:
            const Color(0xFFF7EFF1), // Set background color for the page.
        appBar: AppBar(
          backgroundColor:
              const Color(0xFFE2BF65), // Set app bar background color.
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(), // Back button.
          ),
          title: const Text(
            'Exercise Monitoring', // App bar title.
            style: TextStyle(
                color: Colors.black,
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Color(0xFF037171), // Indicator color.
            labelColor: Colors.white, // Label color.
            unselectedLabelColor: Colors.black,
            labelStyle: TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Activity Tracker'), // First tab.
              Tab(text: 'Exercise Recommendations and Tips'), // Second tab.
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Body content for each tab.
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Activity Logs', onAddPressed: () {
                    // Navigate to AddActivityScreen when Add button is pressed.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddActivityScreen(
                            petId: widget.petId, userId: widget.userId),
                      ),
                    );
                  }),
                  const SizedBox(height: 10), // Spacing.
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE2BF65), // Button color.
                    ),
                    onPressed: _selectDateRange, // Select date range button.
                    child: const Text(
                      'Select Date Range',
                      style: TextStyle(
                        backgroundColor: Color(0xFFE2BF65),
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20), // Spacing.
                  _buildActivityLogs(), // Display activity logs.
                  const SizedBox(height: 20), // Spacing.
                  const Text(
                    "Activity Analysis",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10), // Spacing.
                  _buildActivityStats(), // Display activity stats.
                ],
              ),
            ),
            _buildExerciseRecommendationsTab(), // Exercise recommendations tab.
          ],
        ),
      ),
    );
  }

  // Widget to build section header with an add button.
  Widget _buildSectionHeader(String title,
      {required VoidCallback onAddPressed}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        TextButton(
          onPressed: onAddPressed, // Add button callback.
          child: const Row(
            children: [
              Icon(Icons.add, color: Colors.black), // Add icon.
              Text('Add', style: TextStyle(color: Colors.black)), // Add label.
            ],
          ),
        ),
      ],
    );
  }

  // Widget to display activity logs based on the selected date range.
  Widget _buildActivityLogs() {
    return StreamBuilder<QuerySnapshot>(
      // Listen to the activityLogs collection.
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('activityLogs')
          .where('date', isGreaterThanOrEqualTo: _selectedDateRange!.start)
          .where('date', isLessThanOrEqualTo: _selectedDateRange!.end)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // Display loading indicator while waiting for data.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // Display error message if there is an error fetching data.
        if (snapshot.hasError) {
          return const Center(child: Text('Error fetching activity logs'));
        }
        // Display message if there are no activity logs available.
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No activity logs available'));
        }

        final activityLogs = snapshot.data!.docs; // Fetch activity logs.

        return ListView.builder(
          shrinkWrap: true, // Limit list height.
          physics: const NeverScrollableScrollPhysics(), // Disable scrolling.
          itemCount: activityLogs.length, // Count of logs.
          itemBuilder: (context, index) {
            final activity = activityLogs[index];
            // Build each activity card.
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

  // Widget to build each activity card.
  Widget _buildActivityCard(String activityId, String activityType,
      String duration, String intensity, Timestamp date, String notes) {
    return GestureDetector(
      onTap: () {
        // Navigate to ActivityDetailsScreen when tapped.
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
      onLongPress: () => _confirmDelete(activityId), // Confirm deletion.
      child: Card(
        color: Colors.white, // Card background color.
        elevation: 3, // Card shadow.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10), // Rounded corners.
        ),
        margin: const EdgeInsets.symmetric(vertical: 8.0), // Margin.
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Card padding.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activityType,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text('Duration: $duration minutes',
                  style: const TextStyle(fontSize: 16)),
              Text('Intensity: $intensity',
                  style: const TextStyle(fontSize: 16)),
              Text(
                  'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(date.toDate())}',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              const SizedBox(height: 5),
              Text('Notes: ${notes.isNotEmpty ? notes : 'No notes available'}',
                  style: TextStyle(fontSize: 16, color: Colors.grey[800])),
            ],
          ),
        ),
      ),
    );
  }

  // Function to show a confirmation dialog for deleting an activity.
  Future<void> _confirmDelete(String activityId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Activity'),
        content: const Text('Are you sure you want to delete this activity?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Cancel button.
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteActivity(activityId); // Delete activity.
              Navigator.of(context).pop(); // Close the dialog.
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Function to delete an activity from Firestore.
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
        const SnackBar(content: Text('Activity deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting activity: $e')),
      );
    }
  }

  // Widget to build activity statistics.
  Widget _buildActivityStats() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator()); // Show loading indicator.
    }

    // Check if there are any stats to show.
    if (_activityStats.isEmpty || _activityStats['totalMinutes'] == 0) {
      // Display "No data available" when there's no activity data.
      return Center(
        child: Text(
          'No data available for the selected date range.',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
      );
    }

    // Extract data for intensity distribution and type breakdown.
    Map<String, double> intensityDistribution =
        _activityStats['intensityDistribution'] ?? {};
    Map<String, int> typeBreakdown = _activityStats['typeBreakdown'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 15), // Spacing.
        const Text('Intensity Distribution:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20), // Spacing.
        _buildIntensityPieChart(intensityDistribution), // Display pie chart.
        const SizedBox(height: 20), // Spacing.
        const Text('Time Breakdown by Activity Type:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20), // Spacing.
        ...typeBreakdown.entries.map((entry) {
          return Text('${entry.key}: ${entry.value} minutes',
              style: const TextStyle(fontSize: 16));
        }).toList(),
        const SizedBox(height: 20), // Spacing.
        const Text('Time Breakdown Bar Chart',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20), // Spacing.
        _buildActivityTypeBarChart(typeBreakdown), // Display bar chart.
      ],
    );
  }

  // Helper function to build the intensity distribution pie chart.
  Widget _buildIntensityPieChart(Map<String, double> intensityDistribution) {
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: intensityDistribution.entries.map((entry) {
            return PieChartSectionData(
              color: _getIntensityColor(
                  entry.key), // Assign color based on intensity.
              value: entry.value, // Pie section value.
              title:
                  '${entry.key}\n${entry.value.toStringAsFixed(1)}%', // Title with percentage.
              radius: 60, // Radius of the section.
              titleStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
              titlePositionPercentageOffset: 0.55, // Title position.
            );
          }).toList(),
          sectionsSpace: 2,
          centerSpaceRadius: 40, // Center space in the pie chart.
          borderData: FlBorderData(show: false), // No border.
        ),
      ),
    );
  }

  // Helper function to get color based on intensity type.
  Color _getIntensityColor(String intensity) {
    switch (intensity) {
      case 'Low':
        return Colors.green; // Green for low intensity.
      case 'Moderate':
        return Colors.yellow; // Yellow for moderate intensity.
      case 'High':
        return Colors.red; // Red for high intensity.
      default:
        return Colors.grey; // Default color for unknown intensity.
    }
  }

  // Helper function to build the activity type bar chart.
  Widget _buildActivityTypeBarChart(Map<String, int> typeBreakdown) {
    List<BarChartGroupData> barChartGroups = [];
    int index = 0;

    // Iterate over each activity type and duration to build bar chart groups.
    typeBreakdown.forEach((activityType, duration) {
      barChartGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: duration.toDouble(),
              color: Colors.blue, // Bar color.
              width: 25, // Bar width.
            ),
          ],
          showingTooltipIndicators: [0],
        ),
      );
      index++; // Increment index for each bar.
    });

    return Container(
      height: 300, // Bar chart height.
      child: BarChart(
        BarChartData(
          backgroundColor: Colors.white60, // Background color for the chart.
          alignment: BarChartAlignment.spaceAround, // Alignment for bars.
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                String activityType =
                    typeBreakdown.keys.elementAt(group.x.toInt());
                // Tooltip logic can be added here if necessary.
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true, interval: 10), // Left axis titles.
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      typeBreakdown.keys
                          .elementAt(value.toInt()), // Bottom axis labels.
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
                reservedSize: 50,
              ),
            ),
          ),
          gridData: const FlGridData(show: true), // Show grid lines.
          borderData: FlBorderData(show: false), // No border.
          barGroups: barChartGroups, // Bar groups data.
        ),
      ),
    );
  }

  // Widget for the exercise recommendations tab.
  Widget _buildExerciseRecommendationsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(), // Show loading indicator.
      );
    } else {
      // Split exercise plan into sections.
      List<String> exercisePlanSections = _exerciseRecommendations.split('\n');

      String petType = widget.petType; // Get pet type.
      String trainingTips =
          _getTrainingTips(petType); // Get training tips based on pet type.

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildExerciseCard('Activity Level',
                  exercisePlanSections[1]), // Display activity level.
              _buildExerciseCard('Exercise Recommendations',
                  exercisePlanSections[2]), // Display exercise recommendations.
              _buildExerciseCard('Age-Related Exercise',
                  exercisePlanSections[3]), // Display age-related exercise.
              _buildExerciseCard('Special Health Considerations',
                  exercisePlanSections[4]), // Display health considerations.
              _buildTipsCard(
                  'Training Tips', trainingTips), // Display training tips.
            ],
          ),
        ),
      );
    }
  }

  // Method to provide training tips based on pet type.
  String _getTrainingTips(String petType) {
    if (petType.toLowerCase() == 'dog') {
      // Return training tips for dogs.
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
      // Return training tips for cats.
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

  // Widget to build tips card.
  Widget _buildTipsCard(String title, String tips) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0), // Margin for the card.
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Padding inside the card.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title, // Title of the card.
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0), // Spacing.
            Text(tips, style: const TextStyle(fontSize: 16)), // Tips content.
          ],
        ),
      ),
    );
  }

  // Widget to build exercise card with given title and content.
  Widget _buildExerciseCard(String title, String content) {
    return Card(
      color: Colors.white,
      elevation: 3, // Card shadow.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), // Rounded corners.
      ),
      margin: const EdgeInsets.symmetric(vertical: 8.0), // Margin for the card.
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Padding inside the card.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title, // Card title.
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10), // Spacing below the title.
            Text(
              content, // Content of the card.
              style:
                  const TextStyle(fontSize: 16), // Font size for the content.
            ),
          ],
        ),
      ),
    );
  }
}
