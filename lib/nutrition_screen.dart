import 'package:flutter/material.dart';

class NutritionPage extends StatefulWidget {
  @override
  _NutritionPageState createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage> {
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
          'Pet Nutrition',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.restaurant_menu, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nutrition Recommendations Section
            SectionTitle(title: 'Nutrition Recommendations'),
            NutritionRecommendationCard(
              recommendation: 'Include more proteins in the diet for better muscle health.',
            ),
            NutritionRecommendationCard(
              recommendation: 'Add fibre-rich vegetables for improved digestion.',
            ),
            SizedBox(height: 20),
            // Meal Plans Section
            SectionTitle(title: 'Meal Plans'),
            MealPlanCard(
              mealTime: 'Breakfast',
              foodItems: 'Chicken, Carrots, Rice',
              calories: '500 kcal',
            ),
            MealPlanCard(
              mealTime: 'Dinner',
              foodItems: 'Beef, Peas, Sweet Potato',
              calories: '600 kcal',
            ),
            SizedBox(height: 20),
            // Food Logs Section
            SectionTitle(title: 'Food Logs'),
            FoodLogCard(
              date: 'Mon 24 Jan',
              foodItems: 'Chicken, Rice',
              calories: '500 kcal',
            ),
            FoodLogCard(
              date: 'Tue 25 Jan',
              foodItems: 'Beef, Carrots',
              calories: '550 kcal',
            ),
            SizedBox(height: 20),
            // Calorie Tracker Section
            SectionTitle(title: 'Calorie Tracker'),
            CalorieTrackerCard(
              date: 'Mon 24 Jan',
              totalCalories: '1500 kcal',
              caloriesRemaining: '200 kcal',
            ),
            CalorieTrackerCard(
              date: 'Tue 25 Jan',
              totalCalories: '1600 kcal',
              caloriesRemaining: '300 kcal',
            ),
            SizedBox(height: 20),
            // Save/Update Button
            Center(
              child: ElevatedButton(
                onPressed: () {},
                child: Text('Save/Update'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, backgroundColor: Color(0xFFE2BF65), // Text color
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
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
        TextButton(
          onPressed: () {},
          child: Text(
            'See all',
            style: TextStyle(
              fontSize: 16,
              color: Colors.teal,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class NutritionRecommendationCard extends StatelessWidget {
  final String recommendation;

  NutritionRecommendationCard({required this.recommendation});

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
      child: Text(
        recommendation,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class MealPlanCard extends StatelessWidget {
  final String mealTime;
  final String foodItems;
  final String calories;

  MealPlanCard({
    required this.mealTime,
    required this.foodItems,
    required this.calories,
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
            mealTime,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Food Items: $foodItems',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Calories: $calories',
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

class FoodLogCard extends StatelessWidget {
  final String date;
  final String foodItems;
  final String calories;

  FoodLogCard({
    required this.date,
    required this.foodItems,
    required this.calories,
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
            date,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Food Items: $foodItems',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Calories: $calories',
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

class CalorieTrackerCard extends StatelessWidget {
  final String date;
  final String totalCalories;
  final String caloriesRemaining;

  CalorieTrackerCard({
    required this.date,
    required this.totalCalories,
    required this.caloriesRemaining,
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
            date,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Total Calories: $totalCalories',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Calories Remaining: $caloriesRemaining',
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
