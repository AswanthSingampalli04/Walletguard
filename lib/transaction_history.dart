import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:walletguard/pred_screen.dart';
import 'add_screen.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'overview_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewTransactionsScreen extends StatefulWidget {
  @override
  _ViewTransactionsScreenState createState() => _ViewTransactionsScreenState();
}

class _ViewTransactionsScreenState extends State<ViewTransactionsScreen> {
  int _selectedIndex = 3;
  final databaseRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> transactions = [];
  TextEditingController amountController = TextEditingController();
  TextEditingController personController = TextEditingController();
  TextEditingController notesController = TextEditingController();
  String selectedCategory = 'Cash';
  String selectedPaymentMethod = 'Cash';
  String? selectedDate;

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
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final DatabaseReference transactionsRef = databaseRef.child('transactions').child(user.uid);
      DatabaseEvent event = await transactionsRef.once();

      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          transactions = data.entries.map((entry) {
            final transaction = entry.value as Map<dynamic, dynamic>;
            return {
              'id': entry.key,
              'amount': transaction['amount']?.toString() ?? '0',
              'category': transaction['category']?.toString() ?? 'Uncategorized',
              'dateTime': transaction['dateTime']?.toString() ?? 'No date',
              'notes': transaction['notes']?.toString() ?? '',
              'transactionType': transaction['transactionType']?.toString() ?? 'Expense',
              'paymentMethod': transaction['paymentMethod']?.toString() ?? 'Cash',
              'person': transaction['person']?.toString() ?? 'No person',
              'attachment': transaction['attachment']?.toString() ?? 'No file attached',
            };
          }).toList();

          // Sort transactions by date (most recent first)
          transactions.sort((a, b) => (b['dateTime'] ?? '').compareTo(a['dateTime'] ?? ''));
        });
      }
    }
  }

  void _showOptionsDialog(Map<String, dynamic> transaction) {
    final isIncome = (transaction['transactionType'] ?? 'Expense') == 'Income';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              color: isIncome ? Colors.blue : Colors.red,
            ),
            SizedBox(width: 8),
            Text(
              'Transaction Details',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Person', transaction['person'] ?? 'No person'),
              _buildDetailRow('Amount', '₹${transaction['amount'] ?? '0'}'),
              _buildDetailRow('Type', transaction['transactionType'] ?? 'Expense'),
              _buildDetailRow('Category', transaction['category'] ?? 'Uncategorized'),
              _buildDetailRow('Payment Method', transaction['paymentMethod'] ?? 'Cash'),
              _buildDetailRow('Date & Time', transaction['dateTime'] ?? 'No date'),
              if (transaction['notes']?.isNotEmpty ?? false)
                _buildDetailRow('Notes', transaction['notes'] ?? ''),
              _buildDetailRow('Attachment', transaction['attachment'] ?? 'No file attached'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditDialog(transaction);
            },
            child: Text(
              'Edit',
              style: TextStyle(color: Colors.blue),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(transaction['id']);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String key) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete', style: TextStyle(color: Colors.red)),
        content: Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.deepPurple)),
          ),
          TextButton(
            onPressed: () {
              _deleteTransaction(key);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(String key) async {
    await databaseRef.child('transactions').child(FirebaseAuth.instance.currentUser!.uid).child(key).remove();
    setState(() {
      transactions.removeWhere((txn) => txn['id'] == key);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Transaction deleted successfully!")),
    );
  }

  void _showEditDialog(Map<String, dynamic> transaction) {
    setState(() {
      amountController.text = transaction['amount'];
      notesController.text = transaction['notes'] ?? '';
      selectedCategory = transaction['category'];
      selectedPaymentMethod = transaction['paymentMethod'];
    });
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Transaction',
          style: TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold
          )
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(amountController, 'Amount', Icons.currency_rupee),
            _buildTextField(notesController, 'Notes', Icons.notes),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              _saveTransaction(transaction['id']);
              Navigator.pop(context);
            },
            child: Text(
              'Save',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTransaction(String key) async {
    await databaseRef.child('transactions').child(FirebaseAuth.instance.currentUser!.uid).child(key).update({
      "amount": amountController.text,
      "notes": notesController.text,
      "category": selectedCategory,
      "paymentMethod": selectedPaymentMethod,
    });
    
    // Refresh the transactions list
    _fetchTransactions();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Transaction updated successfully!"),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.deepPurple),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Transaction History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade50, Colors.white],
          ),
        ),
        child: transactions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No transactions yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add your first transaction using the + button',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                final isIncome = (transaction['transactionType'] ?? 'Expense') == 'Income';
                
                return GestureDetector(
                  onTap: () => _showOptionsDialog(transaction),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: isIncome ? Colors.blue : Colors.red,
                              width: 4,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      transaction['person'] ?? 'No person',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isIncome
                                          ? Colors.blue.withOpacity(0.1)
                                          : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isIncome ? '+₹${transaction['amount'] ?? '0'}' : '-₹${transaction['amount'] ?? '0'}',
                                      style: TextStyle(
                                        color: isIncome ? Colors.blue : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.category_outlined,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    transaction['category'] ?? 'Uncategorized',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    transaction['dateTime'] ?? 'No date',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
