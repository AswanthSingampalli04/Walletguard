import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:walletguard/prediction_screen.dart';

class PredictionScreen extends StatefulWidget {
  @override
  _PredictionScreenState createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final DatabaseReference databaseRef = FirebaseDatabase.instance.ref("transactions");
  String predictedExpense = "Fetching expense prediction...";
  String predictedIncome = "Fetching income prediction...";
  String savings = "Calculating savings...";
  bool isLoadingExpense = false;
  bool isLoadingIncome = false;

  @override
  void initState() {
    super.initState();
    _fetchAndPredictExpense();
    _fetchAndPredictIncome();
  }

  Future<void> _fetchAndPredictExpense() async {
    setState(() {
      isLoadingExpense = true;
    });

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        predictedExpense = "User not logged in.";
        isLoadingExpense = false;
      });
      return;
    }

    DatabaseReference userTransactionsRef = databaseRef.child(user.uid);
    DatabaseEvent event = await userTransactionsRef.once();

    if (event.snapshot.value == null) {
      setState(() {
        predictedExpense = "No transaction data found.";
        isLoadingExpense = false;
      });
      return;
    }

    Map<dynamic, dynamic> transactionsData = event.snapshot.value as Map<dynamic, dynamic>;

    Map<String, double> monthlyExpenses = {};
    transactionsData.forEach((key, transaction) {
      if (transaction["transactionType"] == "Spent") {
        _aggregateMonthlyData(monthlyExpenses, transaction);
      }
    });

    _processAndPredict(monthlyExpenses, "expense");
  }

  Future<void> _fetchAndPredictIncome() async {
    setState(() {
      isLoadingIncome = true;
    });

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        predictedIncome = "User not logged in.";
        isLoadingIncome = false;
      });
      return;
    }

    DatabaseReference userTransactionsRef = databaseRef.child(user.uid);
    DatabaseEvent event = await userTransactionsRef.once();

    if (event.snapshot.value == null) {
      setState(() {
        predictedIncome = "No transaction data found.";
        isLoadingIncome = false;
      });
      return;
    }

    Map<dynamic, dynamic> transactionsData = event.snapshot.value as Map<dynamic, dynamic>;

    Map<String, double> monthlyIncome = {};
    transactionsData.forEach((key, transaction) {
      if (transaction["transactionType"] == "Income") {
        _aggregateMonthlyData(monthlyIncome, transaction);
      }
    });

    _processAndPredict(monthlyIncome, "income");
  }

  void _aggregateMonthlyData(Map<String, double> monthlyData, Map<dynamic, dynamic> transaction) {
    String date = transaction["dateTime"] ?? "";
    double amount = double.tryParse(transaction["amount"].toString()) ?? 0.0;

    if (date.isNotEmpty) {
      List<String> dateSegments = date.split(" ")[0].split("-");
      if (dateSegments.length >= 2) {
        String month = "${dateSegments[0]}-${dateSegments[1]}";
        monthlyData[month] = (monthlyData[month] ?? 0) + amount;
      }
    }
  }

  void _processAndPredict(Map<String, double> monthlyData, String type) {
    List<String> sortedMonths = monthlyData.keys.toList()..sort();
    if (sortedMonths.isEmpty) {
      setState(() {
        if (type == "expense") {
          predictedExpense = "No valid 'spent' transactions found.";
          isLoadingExpense = false;
        } else {
          predictedIncome = "No valid 'income' transactions found.";
          isLoadingIncome = false;
        }
      });
      return;
    }

    List<String> lastThreeMonths = sortedMonths.reversed.take(3).toList();
    lastThreeMonths.sort();

    double month1 = lastThreeMonths.length > 0 ? monthlyData[lastThreeMonths[0]] ?? 0.0 : 0.0;
    double month2 = lastThreeMonths.length > 1 ? monthlyData[lastThreeMonths[1]] ?? 0.0 : 0.0;
    double month3 = lastThreeMonths.length > 2 ? monthlyData[lastThreeMonths[2]] ?? 0.0 : 0.0;

    _predictNextMonth(type, month1, month2, month3);
  }

  Future<void> _predictNextMonth(String type, double month1, double month2, double month3) async {
    // Calculate base prediction from historical data with type-specific patterns
    double average = (month1 + month2 + month3) / 3;
    double predictedValue = 0.0;
    
    if (type == "expense") {
      // Expense prediction: typically more volatile, seasonal patterns
      double trend = (month3 - month1) / 2; // Calculate trend
      double seasonality = 1.0;
      
      // Add seasonal factors (higher expenses in certain months)
      int currentMonth = DateTime.now().month;
      if (currentMonth >= 11 && currentMonth <= 12) {
        seasonality = 1.2; // Holiday season
      } else if (currentMonth >= 1 && currentMonth <= 2) {
        seasonality = 1.1; // New year/winter
      } else if (currentMonth >= 6 && currentMonth <= 8) {
        seasonality = 1.05; // Summer
      }
      
      // Expenses usually grow slightly month-to-month due to inflation
      predictedValue = (average + trend * 0.3) * seasonality * 1.02;
      
    } else {
      // Income prediction: usually more stable, predictable patterns
      double trend = (month3 - month1) / 2;
      
      // Income patterns: potential bonuses, salary increments
      int currentMonth = DateTime.now().month;
      double incomeFactor = 1.0;
      
      // Common bonus months (April, Dec)
      if (currentMonth == 4 || currentMonth == 12) {
        incomeFactor = 1.15; // Bonus season
      } else if (currentMonth == 1 || currentMonth == 7) {
        incomeFactor = 1.05; // Potential salary increments
      }
      
      // Income is generally more stable than expenses
      predictedValue = (average + trend * 0.1) * incomeFactor;
    }
    
    // Ensure positive values and reasonable limits
    predictedValue = predictedValue.clamp(0.0, double.infinity);
    
    setState(() {
      if (type == "expense") {
        predictedExpense = "₹${predictedValue.toStringAsFixed(2)}";
        isLoadingExpense = false;
      } else {
        predictedIncome = "₹${predictedValue.toStringAsFixed(2)}";
        isLoadingIncome = false;
      }
      _calculateSavings();
    });
  }

  void _calculateSavings() {
    double income = double.tryParse(predictedIncome.replaceAll("₹", "")) ?? 0.0;
    double expense = double.tryParse(predictedExpense.replaceAll("₹", "")) ?? 0.0;
    double calculatedSavings = income - expense;
    
    // Apply realistic savings adjustment factors
    double adjustedSavings = calculatedSavings;
    
    if (calculatedSavings > 0) {
      // Positive savings: apply conservative adjustment (people often save less than planned)
      double savingsRate = 0.85; // 85% of theoretical savings is more realistic
      
      // Adjust based on savings amount
      if (calculatedSavings > 50000) {
        savingsRate = 0.75; // Higher amounts have lower actual savings rates
      } else if (calculatedSavings > 20000) {
        savingsRate = 0.80;
      } else if (calculatedSavings < 5000) {
        savingsRate = 0.90; // Small amounts are easier to save
      }
      
      adjustedSavings = calculatedSavings * savingsRate;
      
    } else {
      // Negative savings (deficit): apply realistic adjustment
      // People often cut back when in deficit, but not fully
      adjustedSavings = calculatedSavings * 0.7; // 70% of deficit is more realistic
    }
    
    setState(() {
      savings = "₹${adjustedSavings.toStringAsFixed(2)}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Monthly Financial Prediction',
          style: TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade50, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Predictions Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 20),
                _buildPredictionCard(
                  "Predicted Income",
                  predictedIncome,
                  isLoadingIncome,
                  Icons.trending_up,
                  Colors.green,
                  "Expected income for next month",
                ),
                SizedBox(height: 16),
                _buildPredictionCard(
                  "Predicted Expense",
                  predictedExpense,
                  isLoadingExpense,
                  Icons.trending_down,
                  Colors.red,
                  "Expected expenses for next month",
                ),
                SizedBox(height: 16),
                _buildPredictionCard(
                  "Estimated Savings",
                  savings,
                  false,
                  Icons.savings,
                  Colors.blue,
                  "Potential savings for next month",
                ),
                SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => TransactionScreen()),
                      );
                    },
                    icon: Icon(Icons.lightbulb_outline, size: 24),
                    label: Text(
                      'View Recommendations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionCard(
    String title,
    String value,
    bool isLoading,
    IconData icon,
    Color color,
    String description,
  ) {
    return Container(
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
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
        ],
      ),
    );
  }
}
