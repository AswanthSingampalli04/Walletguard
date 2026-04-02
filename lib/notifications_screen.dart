import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:walletguard/transaction_history.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:walletguard/pred_screen.dart';
import 'add_screen.dart';
import 'home_screen.dart';
import 'overview_screen.dart';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedIndex = 0;

  final DatabaseReference _billsRef =
  FirebaseDatabase.instance.ref().child('bills_and_remainders');
  List<Map<String, String>> _todayReminders = [];

  @override
  void initState() {
    super.initState();
    _fetchReminders();
  }
  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OverviewPage()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PredictionScreen()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ViewTransactionsScreen()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }
  Future<void> _fetchReminders() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("No user is logged in.");
        return;
      }

      // Fetch only the reminders for the logged-in user
      DatabaseReference userBillsRef = _billsRef.child(user.uid);
      DatabaseEvent event = await userBillsRef.once();

      List<Map<String, String>> reminders = [];

      if (event.snapshot.value != null && event.snapshot.value is Map) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

        data.forEach((key, value) {
          if (value is Map) {
            String billDate = value['date'] ?? '';
            if (billDate == todayDate) {
              reminders.add({
                'name': value['name'] ?? 'Unknown',
                'amount': value['amount'] ?? '0',
                'frequency': value['frequency'] ?? 'Unknown',
              });
            }
          }
        });
      }

      setState(() {
        _todayReminders = reminders;
      });

      print("Today's Reminders: $_todayReminders");
    } catch (e) {
      print('Error fetching reminders: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: _todayReminders.isEmpty
            ? Center(child: Text('No reminders for today.'))
            : ListView.builder(
          itemCount: _todayReminders.length,
          itemBuilder: (context, index) {
            final reminder = _todayReminders[index];
            return Card(
              child: ListTile(
                title: Text(reminder['name']!),
                subtitle: Text(
                  'Amount: ₹${reminder['amount']}\nFrequency: ${reminder['frequency']}',
                ),
                leading:
                Icon(Icons.notifications_active, color: Colors.red),
              ),
            );
          },
        ),
      ),
      floatingActionButton: SizedBox(
        height: 60,
        width: 60,
        child: FloatingActionButton(
          backgroundColor: Colors.blue,
          elevation: 8,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddTransactionScreen()),
            );
          },
          child: Icon(
            Icons.add,
            size: 30,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 8,
        child: Container(
          height: 60,
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MaterialButton(
                    minWidth: 40,
                    onPressed: () => _onItemTapped(0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.home,
                          color: _selectedIndex == 0 ? Colors.blue : Colors.grey,
                        ),
                        Text(
                          'Home',
                          style: TextStyle(
                            color: _selectedIndex == 0 ? Colors.blue : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  MaterialButton(
                    minWidth: 40,
                    onPressed: () => _onItemTapped(1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.dashboard,
                          color: _selectedIndex == 1 ? Colors.blue : Colors.grey,
                        ),
                        Text(
                          'Overview',
                          style: TextStyle(
                            color: _selectedIndex == 1 ? Colors.blue : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MaterialButton(
                    minWidth: 40,
                    onPressed: () => _onItemTapped(2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.recommend,
                          color: _selectedIndex == 2 ? Colors.blue : Colors.grey,
                        ),
                        Text(
                          'Prediction',
                          style: TextStyle(
                            color: _selectedIndex == 2 ? Colors.blue : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  MaterialButton(
                    minWidth: 40,
                    onPressed: () => _onItemTapped(3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: _selectedIndex == 3 ? Colors.blue : Colors.grey,
                        ),
                        Text(
                          'Wallet',
                          style: TextStyle(
                            color: _selectedIndex == 3 ? Colors.blue : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
