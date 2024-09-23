import 'package:flutter/material.dart';

class PetHealthScreen extends StatefulWidget {
  @override
  _PetHealthScreenState createState() => _PetHealthScreenState();
}

class _PetHealthScreenState extends State<PetHealthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
          'Pet Health',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.medical_services_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Health Log'),
            Tab(text: 'Vaccinations & Reminders'),
            Tab(text: 'Emotional Support'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHealthLogTab(),
          _buildVaccinationsAndRemindersTab(),
          _buildEmotionalSupportTab(),
        ],
      ),
    );
  }

  Widget _buildHealthLogTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: 'Health Checkup Logs'),
          HealthCheckupCard(
            title: 'Annual Checkup',
            date: 'Mon 24 Jan',
            doctor: 'Dr. Green',
            notes: 'All good, no concerns.',
          ),
          HealthCheckupCard(
            title: 'Dental Checkup',
            date: 'Tue 12 Feb',
            doctor: 'Dr. Raam',
            notes: 'Clean teeth, no issues.',
          ),
          SizedBox(height: 20),
          SectionTitle(title: 'Medical History'),
          MedicalHistoryCard(
            title: 'Skin Infection',
            date: 'Wed 13 Mar',
            doctor: 'Dr. Jerry',
            treatment: 'Antibiotics and cream.',
          ),
          MedicalHistoryCard(
            title: 'Ear Infection',
            date: 'Thu 14 Apr',
            doctor: 'Dr. Klein',
            treatment: 'Ear drops and cleaning.',
          ),
          SizedBox(height: 20),
          SectionTitle(title: 'Reminders'),
          ReminderCard(
            reminder: 'Check next vaccination due in 2 months.',
          ),
          ReminderCard(
            reminder: 'Schedule next dental checkup in 6 months.',
          ),
        ],
      ),
    );
  }

  Widget _buildVaccinationsAndRemindersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: 'Vaccination Schedule'),
          VaccinationCard(
            title: 'Rabies Vaccination',
            date: 'Due in 3 months',
            doctor: 'Dr. Green',
          ),
          VaccinationCard(
            title: 'Distemper',
            date: 'Completed',
            doctor: 'Dr. Raam',
          ),
          SizedBox(height: 20),
          SectionTitle(title: 'Medical Records'),
          MedicalRecordCard(
            title: 'Allergy Test',
            date: 'Completed on Tue 12 Feb',
            details: 'No significant allergies found.',
          ),
          MedicalRecordCard(
            title: 'Blood Test',
            date: 'Completed on Wed 13 Mar',
            details: 'Normal levels for all parameters.',
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionalSupportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: 'Articles'),
          ArticleCard(
            title: 'Understanding Pet Anxiety',
            content: 'Learn about common causes of anxiety in pets and how to manage them effectively.',
          ),
          ArticleCard(
            title: 'The Importance of Bonding with Your Pet',
            content: 'Discover why building a strong bond with your pet is crucial for their emotional well-being.',
          ),
          SizedBox(height: 20),
          SectionTitle(title: 'Videos'),
          VideoCard(
            title: 'Managing Pet Stress',
            link: 'https://www.example.com/managing-pet-stress',
          ),
          VideoCard(
            title: 'Creating a Calm Environment for Your Pet',
            link: 'https://www.example.com/creating-calm-environment',
          ),
          SizedBox(height: 20),
          SectionTitle(title: 'Support Groups'),
          SupportGroupCard(
            name: 'Pet Owners Support Network',
            link: 'https://www.example.com/pet-owners-network',
          ),
          SupportGroupCard(
            name: 'Pet Care Community',
            link: 'https://www.example.com/pet-care-community',
          ),
          SizedBox(height: 20),
          SectionTitle(title: 'Tips for Managing Pet Stress'),
          TipCard(
            tip: 'Maintain a consistent routine to help your pet feel secure and relaxed.',
          ),
          TipCard(
            tip: 'Provide plenty of exercise and mental stimulation to reduce stress levels.',
          ),
        ],
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

class HealthCheckupCard extends StatelessWidget {
  final String title;
  final String date;
  final String doctor;
  final String notes;

  HealthCheckupCard({
    required this.title,
    required this.date,
    required this.doctor,
    required this.notes,
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
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          Text(
            date,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 5),
          Text(
            doctor,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Notes: $notes',
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

class MedicalHistoryCard extends StatelessWidget {
  final String title;
  final String date;
  final String doctor;
  final String treatment;

  MedicalHistoryCard({
    required this.title,
    required this.date,
    required this.doctor,
    required this.treatment,
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
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          Text(
            date,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 5),
          Text(
            doctor,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Treatment: $treatment',
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

class ReminderCard extends StatelessWidget {
  final String reminder;

  ReminderCard({required this.reminder});

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

class VaccinationCard extends StatelessWidget {
  final String title;
  final String date;
  final String doctor;

  VaccinationCard({
    required this.title,
    required this.date,
    required this.doctor,
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
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                date,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              Text(
                doctor,
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

class MedicalRecordCard extends StatelessWidget {
  final String title;
  final String date;
  final String details;

  MedicalRecordCard({
    required this.title,
    required this.date,
    required this.details,
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
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          Text(
            date,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 5),
          Text(
            details,
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

class ArticleCard extends StatelessWidget {
  final String title;
  final String content;

  ArticleCard({
    required this.title,
    required this.content,
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
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            content,
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

class VideoCard extends StatelessWidget {
  final String title;
  final String link;

  VideoCard({
    required this.title,
    required this.link,
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
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.play_circle_fill, color: Colors.teal),
            onPressed: () {
              // Open video link
            },
          ),
        ],
      ),
    );
  }
}

class SupportGroupCard extends StatelessWidget {
  final String name;
  final String link;

  SupportGroupCard({
    required this.name,
    required this.link,
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
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.link, color: Colors.teal),
            onPressed: () {
              // Open support group link
            },
          ),
        ],
      ),
    );
  }
}

class TipCard extends StatelessWidget {
  final String tip;

  TipCard({required this.tip});

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
        tip,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
