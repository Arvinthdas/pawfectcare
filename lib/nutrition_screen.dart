import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'addmeal_screen.dart';
import 'mealdetail_screen.dart';

class NutritionPage extends StatefulWidget {
  final String petId;
  final String userId;

  NutritionPage({required this.petId, required this.userId});

  @override
  _NutritionPageState createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _dietPlan = "Loading personalized diet plan...";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDietPlan(); // Load the diet plan when the widget is initialized
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDietPlan() async {
    try {
      // Fetch pet details from Firestore
      Map<String, dynamic> petDetails = await fetchPetDetails(widget.petId);

      // Check if required fields are available
      if (petDetails['type'] == null || petDetails['breed'] == null || petDetails['age'] == null || petDetails['weight'] == null) {
        throw Exception("Missing required pet details");
      }

      // Load breed-specific data from the local JSON file
      Map<String, dynamic> breedData = await loadBreedSpecificData(petDetails['type']);

      // Generate the personalized diet plan using decision tree logic
      Map<String, dynamic> dietInfo = generateDietPlanWithDecisionTree(petDetails, breedData);
      setState(() {
        _dietPlan = dietInfo['dietPlan'];
      });
    } catch (e) {
      setState(() {
        _dietPlan = "Error loading diet plan: $e";
      });
    }
  }

  // Fetch pet details from Firestore
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

  // Load breed-specific data
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

  // Decision tree logic to generate the diet plan
  Map<String, dynamic> generateDietPlanWithDecisionTree(
      Map<String, dynamic> petDetails, Map<String, dynamic> breedData) {
    String breed = petDetails['breed'] ?? '';
    int age = petDetails['age'] ?? 0;
    double weight = petDetails['weight']?.toDouble() ?? 0.0;
    String petType = petDetails['type']?.toLowerCase() ?? '';

    // Find breed-specific data
    List<dynamic> breeds = breedData[petType == 'dog' ? 'Dog Breeds' : 'Cat Breeds'];
    Map<String, dynamic>? breedSpecificInfo = breeds.firstWhere(
            (breedInfo) => breedInfo['name'].toString().toLowerCase() == breed.toLowerCase(),
        orElse: () => null);

    if (breedSpecificInfo == null) {
      return {'dietPlan': 'No specific diet plan found for this breed.'};
    }

    // Initialize the diet plan with general recommendations
    String dietPlan = "Diet recommendations for $breed:\n";
    dietPlan += "${breedSpecificInfo['dietary_recommendations'] ?? 'No specific dietary recommendations.'}\n";

    // Decision Tree Logic
    // Step 1: Age-based decisions
    String ageCategory = age < 2 ? 'puppy' : (age >= 7 ? 'senior' : 'adult');
    dietPlan += "Age-specific advice: ${breedSpecificInfo['age_related_recommendations'][ageCategory] ?? 'No age-specific advice.'}\n";

    // Step 2: Weight-based decisions
    if (weight < (breedSpecificInfo['average_weight_kg'][0] ?? 0.0)) {
      dietPlan += "Weight advice: The pet is below the typical weight range. Consider a higher calorie diet.\n";
    } else if (weight > (breedSpecificInfo['average_weight_kg'][1] ?? 0.0)) {
      dietPlan += "Weight advice: The pet is above the typical weight range. Monitor calorie intake to avoid obesity.\n";
    } else {
      dietPlan += "Weight advice: The pet's weight is within the typical range.\n";
    }

    // Step 3: Activity level and health considerations
    if (breedSpecificInfo.containsKey('special_considerations')) {
      dietPlan += "Special considerations: ${breedSpecificInfo['special_considerations']}\n";
    }

    return {'dietPlan': dietPlan};
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Number of tabs
      child: Scaffold(
        backgroundColor: Color(0xFFF7EFF1),
        appBar: AppBar(
          backgroundColor: Color(0xFFE2BF65),
          title: Text(
            'Nutrition',
            style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Meal Reminder'),
              Tab(text: 'Food and Water Intake Tracker'),
              Tab(text: 'Personalized Diet Plans'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMealReminderTab(),
            _buildFoodWaterIntakeTrackerTab(),
            _buildPersonalizedDietPlansTab(),
          ],
        ),
      ),
    );
  }

// Tab 1: Meal Reminder
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
                builder: (context) => AddMealScreen(userId: widget.userId, petId: widget.petId),
              ),
            );
          }),
          SizedBox(height: 10),
          _buildMealHistory(),
          SizedBox(height: 20),
          _buildSectionHeader('Upcoming Meals', onAddPressed: () {
            // Navigate to AddMealScreen when +Add is pressed
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddMealScreen(userId: widget.userId, petId: widget.petId),
              ),
            );
          }),
          SizedBox(height: 10),
          _buildUpcomingMeals(),
        ],
      ),
    );
  }



  // Tab 2: Food and Water Intake Tracker
  Widget _buildFoodWaterIntakeTrackerTab() {
    return Center(
      child: Text(
        'Food and Water Intake Tracker content goes here.',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

// Meal History
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


// Upcoming Meals
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upcoming Meals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: upcomingMeals.length,
              itemBuilder: (context, index) {
                final meal = upcomingMeals[index];
                return _buildMealCard(meal, false);
              },
            ),
          ],
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
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _deleteMeal(mealId);
                Navigator.of(context).pop(); // Close the dialog
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




  // Tab 3: Personalized Diet Plans
  Widget _buildPersonalizedDietPlansTab() {
    List<String> dietPlanSections = _dietPlan.split('\n');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDietCard('Diet Recommendations Based on you pet`s breed, age and weight', dietPlanSections[1]),
            _buildDietCard('Age-Specific Advice', dietPlanSections[2]),
            _buildDietCard('Weight Advice', dietPlanSections[3]),
            if (dietPlanSections.length > 4)
              _buildDietCard('Special Considerations', dietPlanSections[4]),
          ],
        ),
      ),
    );
  }

  // Helper method to create a card for each section
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
}