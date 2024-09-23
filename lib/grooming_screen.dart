import 'package:flutter/material.dart';

class GroomingPage extends StatefulWidget {
  @override
  _GroomingPageState createState() => _GroomingPageState();
}

class _GroomingPageState extends State<GroomingPage> {
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
          'Grooming Schedule',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.save_outlined, color: Colors.white),
            onPressed: () {
              // Save/update functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grooming History Section
            Text(
              'Grooming History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            GroomingCard(
              date: 'Mon 01 Aug',
              service: 'Full Grooming',
              groomer: 'Groomer A',
            ),
            GroomingCard(
              date: 'Tue 15 Aug',
              service: 'Bath and Brush',
              groomer: 'Groomer B',
            ),
            SizedBox(height: 20),
            // Reminders Section
            Text(
              'Grooming Reminders',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            ReminderCard(
              reminder: 'Next grooming due in 2 weeks.',
            ),
            SizedBox(height: 20),
            // Grooming Tips Section
            Text(
              'Grooming Tips',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            TipsCard(
              tip: 'Regular brushing helps reduce shedding and keeps your pet’s coat healthy.',
            ),
            TipsCard(
              tip: 'Trim your pet’s nails regularly to avoid overgrowth and discomfort.',
            ),
          ],
        ),
      ),
    );
  }
}

class GroomingCard extends StatelessWidget {
  final String date;
  final String service;
  final String groomer;

  GroomingCard({
    required this.date,
    required this.service,
    required this.groomer,
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
                date,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                service,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              Text(
                groomer,
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

class ReminderCard extends StatelessWidget {
  final String reminder;

  ReminderCard({required this.reminder});

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
      child: Row(
        children: [
          Expanded(
            child: Text(
              reminder,
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

class TipsCard extends StatelessWidget {
  final String tip;

  TipsCard({required this.tip});

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
      child: Row(
        children: [
          Expanded(
            child: Text(
              tip,
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
