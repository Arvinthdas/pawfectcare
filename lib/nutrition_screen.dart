import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'addfood_screen.dart';
import 'addmeal_screen.dart';
import 'fooddetails_screen.dart';
import 'mealdetail_screen.dart';

class NutritionPage extends StatefulWidget {
  final String petId;
  final String userId;
  final String petName;


  NutritionPage({required this.petId, required this.userId, required this.petName});

  @override
  _NutritionPageState createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true; // Loading state
  String _dietPlan = "Loading personalized diet plan...";
  String? _currentPetId; // Store the current pet ID
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  DateTime _selectedDate = DateTime.now(); // Store the selected date

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadDietPlan();

    // Initialize local notifications
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _initializeNotifications();
    _scheduleDailyNotification();
  }

  void _initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('app_icon'); // Make sure you have an app icon

    final InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload != null) {
          print('Notification payload: ${response.payload}');
        }
      },
    );
  }

  void _scheduleDailyNotification() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      22, // Schedule for 10 PM
      00,
    );

    // If the scheduled time has already passed, schedule for the next day
    final tz.TZDateTime notificationTime = scheduledTime.isBefore(now)
        ? scheduledTime.add(Duration(days: 1))
        : scheduledTime;

    print('Scheduling notification for: $notificationTime'); // Debug log

    flutterLocalNotificationsPlugin.zonedSchedule(
      0, // Notification ID
      'Daily Nutrition Summary',
      'The daily nutrition summary is ready. You can view it now.',
      notificationTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_nutrition_channel',
          'Daily Nutrition',
          channelDescription: 'Notification for daily nutrition summary',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  void _handleTabChange() {
    if (_tabController.index == 2) {
      _loadDietPlan();
    }
  }

  Future<void> _loadDietPlan() async {
    if (_currentPetId == widget.petId) {
      // If the pet ID hasn't changed, don't reload the diet plan
      return;
    }

    setState(() {
      _currentPetId = widget.petId; // Update the current pet ID
      _isLoading = true; // Start loading
    });

    try {
      Map<String, dynamic> petDetails = await fetchPetDetails(widget.petId);

      if (petDetails['type'] == null || petDetails['breed'] == null || petDetails['age'] == null || petDetails['weight'] == null) {
        throw Exception("Missing required pet details");
      }

      Map<String, dynamic> breedData = await loadBreedSpecificData(petDetails['type']);

      Map<String, dynamic> dietInfo = generateDietPlanWithDecisionTree(petDetails, breedData);
      setState(() {
        _dietPlan = dietInfo['dietPlan'];
        _isLoading = false; // Stop loading
      });
    } catch (e) {
      setState(() {
        _dietPlan = "Error loading diet plan: $e";
        _isLoading = false; // Stop loading on error
      });
    }
  }

  Future<Map<String, dynamic>> fetchPetDetails(String petId) async {
    DocumentSnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('pets')
        .doc(petId)
        .get();

    if (snapshot.exists) {
      return snapshot.data() as Map<String, dynamic>;
    } else {
      throw Exception("Pet not found");
    }
  }

  Future<Map<String, dynamic>> loadBreedSpecificData(String petType) async {
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

  Map<String, dynamic> generateDietPlanWithDecisionTree(
      Map<String, dynamic> petDetails, Map<String, dynamic> breedData) {
    String breed = petDetails['breed'] ?? '';
    int age = petDetails['age'] ?? 0;
    double weight = petDetails['weight']?.toDouble() ?? 0.0;
    String petType = petDetails['type']?.toLowerCase() ?? '';

    List<dynamic> breeds = breedData[petType == 'dog' ? 'Dog Breeds' : 'Cat Breeds'];
    Map<String, dynamic>? breedSpecificInfo = breeds.firstWhere(
            (breedInfo) => breedInfo['name'].toString().toLowerCase() == breed.toLowerCase(),
        orElse: () => null);

    if (breedSpecificInfo == null) {
      return {'dietPlan': 'No specific diet plan found for this breed.'};
    }

    String dietPlan = "Diet recommendations for $breed:\n";
    dietPlan += "${breedSpecificInfo['dietary_recommendations'] ?? 'No specific dietary recommendations.'}\n";

    String ageCategory = age < 2 ? 'puppy' : (age >= 7 ? 'senior' : 'adult');
    dietPlan += "Age-specific advice: ${breedSpecificInfo['age_related_recommendations'][ageCategory] ?? 'No age-specific advice.'}\n";

    if (weight < (breedSpecificInfo['average_weight_kg'][0] ?? 0.0)) {
      dietPlan += "Weight advice: The pet is below the typical weight range. Consider a higher calorie diet.\n";
    } else if (weight > (breedSpecificInfo['average_weight_kg'][1] ?? 0.0)) {
      dietPlan += "Weight advice: The pet is above the typical weight range. Monitor calorie intake to avoid obesity.\n";
    } else {
      dietPlan += "Weight advice: The pet's weight is within the typical range.\n";
    }

    if (breedSpecificInfo.containsKey('special_considerations')) {
      dietPlan += "Special considerations: ${breedSpecificInfo['special_considerations']}\n";
    }

    return {'dietPlan': dietPlan};
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Color(0xFFF7EFF1),
        appBar: AppBar(
          backgroundColor: Color(0xFFE2BF65),
          title: Text(
            'Nutrition',
            style: TextStyle(
                color: Colors.black,
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Color(0xFF037171),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.black,
            labelStyle: TextStyle(fontSize: 15,fontStyle: FontStyle.italic ,fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Meal Reminder'),
              Tab(text: 'Food Intake Tracker'),
              Tab(text: 'Personalized Diet Plans'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMealReminderTab(),
            _buildFoodIntakeTrackerTab(),
            _buildPersonalizedDietPlansTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMealReminderTab() {
    return SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    _buildSectionHeader('Meal History', onAddPressed: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => AddMealScreen(userId: widget.userId, petId: widget.petId, petName: widget.petName),
    ),
    );
    }),
    SizedBox(height: 10),
    _buildMealHistory(),
    SizedBox(height: 20),
      _buildSectionHeader('Upcoming Meals', onAddPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddMealScreen(userId: widget.userId, petId: widget.petId, petName: widget.petName),
          ),
        );
      }),
      SizedBox(height: 10),
      _buildUpcomingMeals(),
    ],
    ),
    );
  }

  Widget _buildFoodIntakeTrackerTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Food Intake', onAddPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddFoodScreen(userId: widget.userId, petId: widget.petId),
              ),
            );
          }),
          SizedBox(height: 10),
          _buildDateFilterButton(),
          SizedBox(height: 10),
          _buildFoodDetails(),
          SizedBox(height: 20),
          _buildDailyNutritionChart(),
        ],
      ),
    );
  }

  Widget _buildDateFilterButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFE2BF65),
      ),
      onPressed: () async {
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );

        if (pickedDate != null) {
          setState(() {
            _selectedDate = pickedDate; // Update selected date
          });
        }
      },
      child: Text(
          'Filter by Date: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
              style: TextStyle(
                backgroundColor:Color(0xFFE2BF65),
                color: Colors.black,
              ),
      ),
    );
  }

  Widget _buildFoodDetails() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('foods')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        0,
        0,
      )))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        23,
        59,
      )))
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching food details'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No food details available for this date.'));
        }

        final foodItems = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: foodItems.length,
          itemBuilder: (context, index) {
            final food = foodItems[index];
            return _buildFoodCard(food);
          },
        );
      },
    );
  }

  Widget _buildFoodCard(DocumentSnapshot food) {
    String formattedDate = DateFormat('dd/MM/yyyy HH:mm').format((food['timestamp'] as Timestamp).toDate());

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FoodDetailScreen(
              foodId: food.id,
              userId: widget.userId,
              petId: widget.petId,
            ),
          ),
        );
      },
      onLongPress: () {
        _showDeleteFoodDialog(food.id);
      },
      child: Card(
        color: Colors.white,
        elevation: 3,
        margin: EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(food['foodName'] ?? 'No Food Name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Type: ${food['foodType'] ?? 'Unknown'}', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              Text('Date: $formattedDate', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteFoodDialog(String foodId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Food Item'),
          content: Text('Are you sure you want to delete this food item?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _deleteFood(foodId); // Delete food item
                Navigator.of(context).pop();
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFood(String foodId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('foods')
          .doc(foodId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Food item deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting food item: $e')),
      );
    }
  }

  Widget _buildDailyNutritionChart() {
    DateTime now = DateTime.now();
    DateTime tenPM = DateTime(now.year, now.month, now.day, 22, 0); // 10 PM today

    if (_selectedDate.isAfter(now)) {
      return const Center(
        child: Text(
          'Nutrition data for future dates is not available yet.',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    } else if (_selectedDate.isAtSameMomentAs(now) && now.isBefore(tenPM)) {
      return const Center(
        child: Text(
          'The daily nutrition summary will be available at 10 PM today.',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('pets')
            .doc(widget.petId)
            .collection('foods')
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          0,
          0,
        )))
            .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          23,
          59,
        )))
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error fetching nutrition data'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No nutrition data available for this date.'));
          }

          final foodItems = snapshot.data!.docs;
          final nutritionData = _calculateDailyNutrition(foodItems);

          return Column(
            children: [
              Text(
                'Daily Intake Chart',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20), // Add some space between the title and the chart
              _buildPieChart(nutritionData, chartSize: 80), // Pass a larger size if needed
            ],
          );
        },
      );
    }
  }

  Map<String, double> _calculateDailyNutrition(List<QueryDocumentSnapshot> foodItems) {
    double totalCarbs = 0;
    double totalProtein = 0;
    double totalFat = 0;
    double totalCalcium = 0;
    double totalVitamins = 0;

    for (var food in foodItems) {
      totalCarbs += (food['carbs'] ?? 0).toDouble();
      totalProtein += (food['protein'] ?? 0).toDouble();
      totalFat += (food['fat'] ?? 0).toDouble();
      totalCalcium += (food['calcium'] ?? 0).toDouble();
      totalVitamins += (food['vitamins'] ?? 0).toDouble();
    }

    return {
      'Carbs': totalCarbs,
      'Protein': totalProtein,
      'Fat': totalFat,
      'Calcium': totalCalcium,
      'Vitamins': totalVitamins,
    };
  }

  Widget _buildPieChart(Map<String, double> nutritionData, {double chartSize = 50}) {
    List<PieChartSectionData> sections = nutritionData.entries
        .map((entry) {
      Color color;
      switch (entry.key) {
        case 'Carbs':
          color = Colors.blue;
          break;
        case 'Protein':
          color = Colors.green;
          break;
        case 'Fat':
          color = Colors.red;
          break;
        case 'Calcium':
          color = Colors.orange;
          break;
        case 'Vitamins':
          color = Colors.purple;
          break;
        default:
          color = Colors.grey;
      }

      return PieChartSectionData(
        value: entry.value,
        title: '${entry.key}: ${entry.value.toStringAsFixed(1)}g',
        radius: chartSize, // Use the passed size
        titleStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        color: color,
      );
    }).toList();

    return SizedBox(
      height: 300, // You can adjust this height for better visibility
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          borderData: FlBorderData(show: false),
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {});
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalizedDietPlansTab() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    } else {
      List<String> dietPlanSections = _dietPlan.split('\n');
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDietCard('Diet Recommendations Based on your pet\'s breed, age, and weight', dietPlanSections[1]),
              _buildDietCard('Age-Specific Advice', dietPlanSections[2]),
              _buildDietCard('Weight Advice', dietPlanSections[3]),
              if (dietPlanSections.length > 4)
                _buildDietCard('Special Considerations', dietPlanSections[4]),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDietCard(String title, String content) {
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

  Widget _buildMealHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('meals')
          .where('date', isLessThanOrEqualTo: DateTime.now())
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching meal history'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No meal history available'));
        }

        final meals = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: meals.length,
          itemBuilder: (context, index) {
            final meal = meals[index];
            return _buildMealCard(meal, true);
          },
        );
      },
    );
  }

  Widget _buildUpcomingMeals() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('meals')
          .where('date', isGreaterThan: DateTime.now())
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching upcoming meals'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No upcoming meals available'));
        }

        final upcomingMeals = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: upcomingMeals.length,
          itemBuilder: (context, index) {
            final meal = upcomingMeals[index];
            return _buildMealCard(meal, false);
          },
        );
      },
    );
  }

  Widget _buildMealCard(DocumentSnapshot meal, bool isHistory) {
    String formattedDate = DateFormat('dd/MM/yyyy HH:mm').format((meal['date'] as Timestamp).toDate());

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MealDetailScreen(
              mealRecord: meal,
              userId: widget.userId,
              petId: widget.petId,
              petName: widget.petName,
            ),
          ),
        );
      },
      onLongPress: () {
        _showDeleteDialog(meal.id);
      },
      child: Card(
        color: Colors.white,
        elevation: 3,
        margin: EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meal['mealName'] ?? 'No Meal Name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Date: $formattedDate', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              Text('Notes: ${meal['notes'] ?? 'No Notes'}', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(String mealId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Meal'),
          content: Text('Are you sure you want to delete this meal?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _deleteMeal(mealId); // Delete meal
                Navigator.of(context).pop();
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

Future<void> _deleteMeal(String mealId) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('pets')
        .doc(widget.petId)
        .collection('meals')
        .doc(mealId)
        .delete();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Meal deleted successfully!')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error deleting meal: $e')),
    );
  }
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
}

