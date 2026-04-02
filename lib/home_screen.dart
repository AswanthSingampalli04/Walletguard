import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletguard/pred_screen.dart';
import 'package:walletguard/prediction_screen.dart';
import 'package:walletguard/profile_screen.dart';
import 'package:walletguard/signin_screen.dart';
import 'package:walletguard/transaction_history.dart';
import 'package:walletguard/ocr_receipt_screen.dart';
import 'package:walletguard/email_service.dart';
import 'Accounts_screen.dart';
import 'add_screen.dart';
import 'bills_remainders.dart';
import 'notifications_screen.dart';
import 'overview_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DatabaseReference _billsRef;
  late DatabaseReference _transactionsRef;

  @override
  void initState() {
    super.initState();

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _billsRef = FirebaseDatabase.instance.ref().child('bills_and_remainders').child(user.uid);
      _transactionsRef = FirebaseDatabase.instance.ref().child('transactions').child(user.uid);
      _checkExpenseAlert();
    }
  }

  Future<void> _checkExpenseAlert() async {
    try {
      final DataSnapshot snapshot = await _transactionsRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        int totalIncome = 0;
        int totalExpense = 0;

        data.forEach((key, value) {
          if (value is Map) {
            String transactionType = value['transactionType'] ?? '';
            int amount = int.tryParse(value['amount'] ?? '0') ?? 0;
            if (transactionType == 'Income') {
              totalIncome += amount;
            } else if (transactionType == 'Spent') {
              totalExpense += amount;
            }
          }
        });

        if (totalIncome > 0 && totalExpense > (totalIncome * 0.5)) {
          // Send email notification
          User? currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null && currentUser.email != null) {
            String alertType = totalExpense > totalIncome ? 'budget_exceeded' : 'expense_alert';
            String userName = await _getUserName();
            
            EmailService.sendExpenseAlert(
              recipientEmail: currentUser.email!,
              userName: userName,
              totalExpense: totalExpense.toDouble(),
              totalIncome: totalIncome.toDouble(),
              alertType: alertType,
            );
          }
          
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  title: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red),
                      SizedBox(width: 8),
                      Text('High Expense Alert'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your expenses have exceeded 50% of your income!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Current Status:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('Income: ₹$totalIncome'),
                      Text('Expenses: ₹$totalExpense'),
                      SizedBox(height: 8),
                      Text(
                        'Consider reviewing your spending habits and look for areas to save.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'I Understand',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                );
              },
            );
          }
        }
      }
    } catch (e) {
      print('Error checking expense alert: $e');
    }
  }

  void _onItemTapped(int index) {
     if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ViewTransactionsScreen()),
      );
    }
    else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PredictionScreen()),
      );
    }else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OverviewPage()),
      );
    }
    else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<String> _getUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedName = prefs.getString('userName');

    if (cachedName != null) {
      return cachedName; // Return cached name if available
    }

    final User? user = _auth.currentUser;
    if (user != null) {
      final DatabaseReference userRef =
      FirebaseDatabase.instance.ref().child('users').child(user.uid);
      final DataSnapshot snapshot = await userRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        String fetchedName = data['name'] ?? 'User';

        await prefs.setString('userName', fetchedName); // Cache the name locally
        return fetchedName;
      }
    }
    return 'User';
  }

  Future<List<Map<String, String>>> _getBills() async {
    final DataSnapshot snapshot = await _billsRef.get();
    List<Map<String, String>> bills = [];
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        if (value is Map) {
          bills.add({
            'name': value['name'] ?? '',
            'amount': value['amount'] ?? '',
            'frequency': value['frequency'] ?? '',
            'date': value['date'] ?? '',
          });
        }
      });
    }
    return bills;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.logout, color: Colors.blue),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SignInScreen()),
            );
          },
        ),
        title: Text(
          'Home',
          style: TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.blue),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NotificationsScreen()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                );
              },
              child: CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: Icon(Icons.person, color: Colors.blue),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade50, Colors.white],
          ),
        ),
        child: Scrollbar(
          thumbVisibility: true,
          thickness: 6.0,
          radius: Radius.circular(10),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<String>(
                  future: _getUserName(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Text(
                        'Loading...',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Text(
                        'Error loading name',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      );
                    }
                    return Text(
                      snapshot.data ?? 'User',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    );
                  },
                ),
                SizedBox(height: 4),
                Text(
                  'Welcome Back.. !!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 20),
                StreamBuilder<DatabaseEvent>(
                  stream: _transactionsRef.onValue,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Text('Error loading transactions: ${snapshot.error}');
                    }

                    if (snapshot.hasData && snapshot.data!.snapshot.exists) {
                      final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                      int income = 0;
                      int expense = 0;

                      data.forEach((key, value) {
                        if (value is Map) {
                          String transactionType = value['transactionType'] ?? '';
                          int amount = int.tryParse(value['amount'] ?? '0') ?? 0;
                          if (transactionType == 'Income') {
                            income += amount;
                          } else if (transactionType == 'Spent') {
                            expense += amount;
                          }
                        }
                      });

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Income',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '₹ $income',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Expense',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '₹ $expense',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Text('No transactions available');
                    }
                  },
                ),
                SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    title: Text(
                      'View Accounts',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    trailing: Icon(Icons.add, color: Colors.blue),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AccountsPage()),
                      );
                    },
                  ),
                ),
                SizedBox(height: 16),
                FutureBuilder<List<Map<String, String>>>(
                  future: _getBills(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading bills: ${snapshot.error}'));
                    }

                    final bills = snapshot.data ?? [];
                    if (bills.isEmpty) {
                      return Container(
                        margin: EdgeInsets.all(20),
                        padding: EdgeInsets.all(15),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 5,
                              offset: Offset(0, 3),
                            )
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'No bills added.',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BillAndRemainderPage(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text('Add a Bill'),
                            ),
                          ],
                        ),
                      );
                    }

                    return Container(
                      margin: EdgeInsets.all(20),
                      padding: EdgeInsets.all(15),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Bills and Reminder',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.add, color: Colors.blue),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BillAndRemainderPage(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 15),
                          ...bills.map((bill) {
                            return _buildBillDetails(
                              bill['name']!,
                              bill['amount']!,
                              bill['frequency']!,
                              bill['date']!,
                            );
                          }).toList(),
                        ],
                      ),
                    );
                  },
                ),
                SizedBox(height: 20),
                // OCR Receipt Scanner Section
                Container(
                  margin: EdgeInsets.all(20),
                  padding: EdgeInsets.all(15),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Receipt Scanner',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Icon(Icons.receipt_long, color: Colors.deepPurple),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Scan receipts and extract text automatically using OCR technology.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => OCRReceiptScreen()),
                            );
                          },
                          icon: Icon(Icons.camera_alt),
                          label: Text('Scan Receipt'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildBillDetails(String name, String amount, String frequency, String date) {
    return Container(
      margin: EdgeInsets.only(bottom: 15),
      padding: EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.blue,
            ),
          ),
          SizedBox(height: 5),
          Text(
            "Amount: $amount",
            style: TextStyle(color: Colors.black87),
          ),
          Text(
            "Frequency: $frequency",
            style: TextStyle(color: Colors.black87),
          ),
          Text(
            "Reminder Date: $date",
            style: TextStyle(color: Colors.black87),
          ),
        ],
      ),
    );
  }
}