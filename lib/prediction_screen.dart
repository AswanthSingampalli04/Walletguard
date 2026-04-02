import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class TransactionScreen extends StatefulWidget {
  @override
  _TransactionScreenState createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final DatabaseReference databaseRef = FirebaseDatabase.instance.ref("transactions");
  List<Map<String, String>> transactionPredictions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTransactionsForCurrentMonth();
  }

  Future<void> _fetchTransactionsForCurrentMonth() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    DatabaseReference userTransactionsRef = databaseRef.child(user.uid);
    DatabaseEvent event = await userTransactionsRef.once();

    if (event.snapshot.value != null) {
      Map<dynamic, dynamic> transactionsData = event.snapshot.value as Map<dynamic, dynamic>;
      DateTime now = DateTime.now();
      String currentMonth = "${now.year}-${now.month}";
      List<Map<String, String>> predictions = [];

      for (var transaction in transactionsData.values) {
        if (transaction["dateTime"] != null) {
          try {
            String transactionDate = transaction["dateTime"].split(" ")[0];
            List<String> dateParts = transactionDate.split("-");
            String transactionMonth = "${dateParts[0]}-${int.parse(dateParts[1])}";

            if (transactionMonth == currentMonth) {
              double amount = double.tryParse(transaction["amount"].toString()) ?? 0.0;
              String paymentMethod = transaction["paymentMethod"] ?? "Unknown";
              String creditDebit = (transaction["transactionType"] == "Income") ? "Credit" : "Debit";
              String prediction = await predictCluster(amount, creditDebit, paymentMethod);
              String cluster = prediction.replaceAll(RegExp(r'[^0-9]'), '');

              if (cluster == '3') {
                predictions.add({
                  "amount": amount.toString(),
                  "credit_debit": creditDebit,
                  "transaction_type": paymentMethod,
                  "prediction": prediction,
                });
              }
            }
          } catch (e) {
            print("🚨 Error parsing date: ${transaction["dateTime"]}");
          }
        }
      }

      setState(() {
        transactionPredictions = predictions;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<String> predictCluster(double amount, String creditDebit, String transactionType) async {
    final url = Uri.parse("https://nondenotatively-unterse-rickey.ngrok-free.dev/predict");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "amount": amount.toString(),
          "credit_debit": creditDebit,
          "transaction_type": transactionType,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return "Predicted Cluster: ${data['predicted_cluster']}";
      } else {
        return "Error: Could not get prediction.";
      }
    } catch (e) {
      return "Error: $e";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Monthly Transaction Predictions",
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
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              )
            : transactionPredictions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 48,
                      color: Colors.blue.withOpacity(0.5),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "No Predictions Available",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "No transactions found for this month in Cluster 3.",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction Analysis',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Review your transaction predictions and recommendations',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 24),
                    ...transactionPredictions.map((transaction) => _buildPredictionCard(transaction)).toList(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPredictionCard(Map<String, String> transaction) {
    return Container(
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
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    transaction['credit_debit'] == 'Credit' ? Icons.arrow_upward : Icons.arrow_downward,
                    color: transaction['credit_debit'] == 'Credit' ? Colors.green : Colors.red,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "₹${transaction['amount']}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        transaction['transaction_type']!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    transaction['credit_debit']!,
                    style: TextStyle(
                      color: transaction['credit_debit'] == 'Credit' ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection(
                  "Prediction Analysis",
                  transaction['prediction']!,
                  Icons.analytics,
                ),
                SizedBox(height: 16),
                _buildInfoSection(
                  "Recommendation",
                  "⚠️ Consider reducing unnecessary expenses and focus on saving more.",
                  Icons.lightbulb_outline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.blue),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[800],
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
