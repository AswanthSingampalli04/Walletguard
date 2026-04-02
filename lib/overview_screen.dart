import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:walletguard/transaction_history.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:walletguard/pred_screen.dart';
import 'add_screen.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';

class _Badge extends StatelessWidget {
  final String text;
  final double size;
  final Color color;

  const _Badge(
    this.text, {
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text.length > 8 ? text.substring(0, 8) + '...' : text,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 8,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class OverviewPage extends StatefulWidget {
  @override
  _OverviewPageState createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  int _selectedIndex = 0;
  Map<String, double> chartData = {};
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final DateFormat _firebaseFormat = DateFormat("yyyy-MM-dd HH:mm");
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();

  Map<String, double> incomeData = {};
  Map<String, double> expenseData = {};
  Map<String, double> categoryWiseData = {};
  List<BarChartGroupData> monthlyBarData = [];

  String selectedChartType = 'Income vs Expense';
  String selectedBarFilter = 'Income';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
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

  Future<void> _loadTransactions() async {
    print("Fetching transactions from Firebase...");
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("No user is logged in.");
        return;
      }

      // Fetch only transactions related to the logged-in user
      DatabaseReference userTransactionsRef = _database.ref('transactions').child(user.uid);
      DatabaseEvent event = await userTransactionsRef.once();

      print("Data Snapshot: ${event.snapshot.value}");

      if (event.snapshot.value == null || event.snapshot.value is! Map) {
        print('No data found or data format is invalid.');
        return;
      }

      final rawData = event.snapshot.value as Map<dynamic, dynamic>;
      final data = rawData.map((key, value) =>
          MapEntry(key.toString(), Map<String, dynamic>.from(value as Map)));

      print("Parsed Data: $data");

      Map<String, double> incomeMap = {};
      Map<String, double> expenseMap = {};
      Map<String, double> categoryMap = {};
      List<double> monthIncome = List.filled(12, 0);
      List<double> monthExpense = List.filled(12, 0);

      data.forEach((key, transaction) {
        final amount = double.tryParse(transaction['amount'].toString()) ?? 0;
        final transactionType = transaction['transactionType'] ?? '';
        final category = transaction['category'] ?? '';
        final dateTimeString = transaction['dateTime'] ?? '';

        DateTime? dateTime;
        try {
          dateTime = _firebaseFormat.parse(dateTimeString);
        } catch (e) {
          print("Error parsing date: $dateTimeString");
          return;
        }

        print("Processing transaction: $transaction");

        if (dateTime.isAfter(_startDate.subtract(Duration(days: 1))) &&
            dateTime.isBefore(_endDate.add(Duration(days: 1)))) {
          if (transactionType == 'Income') {
            incomeMap.update(category, (value) => value + amount, ifAbsent: () => amount);
            monthIncome[dateTime.month - 1] += amount;
          } else if (transactionType == 'Spent') {
            expenseMap.update(category, (value) => value + amount, ifAbsent: () => amount);
            monthExpense[dateTime.month - 1] += amount;
            categoryMap.update(category, (value) => value + amount, ifAbsent: () => amount);
          }
        }
      });

      print("Final Income Data: $incomeMap");
      print("Final Expense Data: $expenseMap");

      setState(() {
        incomeData = incomeMap;
        expenseData = expenseMap;
        categoryWiseData = categoryMap;
        _generateBarChartData(monthIncome, monthExpense);
      });
    } catch (e) {
      print('Error loading transactions: $e');
    }
  }


  void _generateBarChartData(List<double> monthIncome, List<double> monthExpense) {
    List<BarChartGroupData> barChartData = [];
    for (int i = 0; i < 12; i++) {
      double value = selectedBarFilter == 'Income' ? monthIncome[i] : monthExpense[i];
      barChartData.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(toY: value, color: selectedBarFilter == 'Income' ? Colors.green : Colors.red, width: 10),
        ],
      ));
    }
    setState(() {
      monthlyBarData = barChartData;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _loadTransactions();
    }
  }

  PieChartData _buildPieChart(BuildContext context) {
    Map<String, double> chartData = {};
    double totalValue = 0;

    // Select chart data based on the selected chart type
    if (selectedChartType == 'Income vs Expense') {
      chartData = {
        'Income': incomeData.values.fold(0, (sum, item) => sum + item),
        'Expense': expenseData.values.fold(0, (sum, item) => sum + item)
      };
    } else if (selectedChartType == 'Only Expense') {
      chartData = expenseData;
    } else {
      chartData = categoryWiseData;
    }

    // Calculate total value for percentage calculation
    totalValue = chartData.values.fold(0, (sum, item) => sum + item);

    return PieChartData(
      sections: chartData.entries.map((entry) {
        final percentage = (entry.value / totalValue) * 100;
        final colorIndex = chartData.keys.toList().indexOf(entry.key) % Colors.primaries.length;
        return PieChartSectionData(
          value: entry.value,
          title: '${percentage.toStringAsFixed(1)}%',
          titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          color: Colors.primaries[colorIndex],
          radius: 70,
          showTitle: true,
          badgeWidget: _Badge(
            entry.key,
            size: 30,
            color: Colors.primaries[colorIndex],
          ),
          badgePositionPercentageOffset: .98,
        );
      }).toList(),
      sectionsSpace: 2,
      centerSpaceRadius: 40,
      pieTouchData: PieTouchData(
        touchCallback: (FlTouchEvent event, PieTouchResponse? pieTouchResponse) {
          if (event is FlTapUpEvent && pieTouchResponse != null && pieTouchResponse.touchedSection != null) {
            final sectionIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
            final key = chartData.keys.elementAt(sectionIndex);
            final value = chartData[key]!;
            final percentage = (value / totalValue) * 100;

            // Use context from the widget tree
            showDialog(
              context: context,
              builder: (BuildContext dialogContext) {
                return AlertDialog(
                  title: Text('$key Details'),
                  content: Text('Amount: $value\nPercentage: ${percentage.toStringAsFixed(1)}%'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('OK'))
                  ],
                );
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildLegend() {
    Map<String, double> chartData = {};
    
    if (selectedChartType == 'Income vs Expense') {
      chartData = {
        'Income': incomeData.values.fold(0, (sum, item) => sum + item),
        'Expense': expenseData.values.fold(0, (sum, item) => sum + item)
      };
    } else if (selectedChartType == 'Only Expense') {
      chartData = expenseData;
    } else {
      chartData = categoryWiseData;
    }

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Legend',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: chartData.entries.map((entry) {
              final colorIndex = chartData.keys.toList().indexOf(entry.key) % Colors.primaries.length;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.primaries[colorIndex],
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    entry.key,
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  BarChartData _buildBarChart() {
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final maxValue = monthlyBarData.isEmpty ? 1000 : 
        monthlyBarData.map((group) => group.barRods.first.toY).reduce((a, b) => a > b ? a : b);
    
    return BarChartData(
      barGroups: monthlyBarData,
      titlesData: FlTitlesData(
        show: true,
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value == 0) return Text('0', style: TextStyle(fontSize: 10));
              if (maxValue >= 1000000) {
                return Text('${(value / 1000000).toStringAsFixed(1)}M', style: TextStyle(fontSize: 10));
              } else if (maxValue >= 1000) {
                return Text('${(value / 1000).toStringAsFixed(0)}K', style: TextStyle(fontSize: 10));
              } else {
                return Text('${value.toInt()}', style: TextStyle(fontSize: 10));
              }
            },
            reservedSize: 40,
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value >= 0 && value < 12) {
                return Text(monthNames[value.toInt()], style: TextStyle(fontSize: 10));
              }
              return Text('');
            },
            reservedSize: 30,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey.shade300),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          );
        },
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final month = monthNames[group.x.toInt()];
            final value = rod.toY;
            String formattedValue;
            if (value >= 1000000) {
              formattedValue = '${(value / 1000000).toStringAsFixed(2)}M';
            } else if (value >= 1000) {
              formattedValue = '${(value / 1000).toStringAsFixed(1)}K';
            } else {
              formattedValue = value.toStringAsFixed(0);
            }
            return BarTooltipItem(
              '$month\n${selectedBarFilter}: ₹$formattedValue',
              TextStyle(color: Colors.white, fontSize: 12),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBarSummary() {
    double total = 0;
    double average = 0;
    double maxMonth = 0;
    String maxMonthName = '';
    
    if (monthlyBarData.isNotEmpty) {
      total = monthlyBarData.fold(0, (sum, group) => sum + group.barRods.first.toY);
      average = total / 12;
      
      final maxGroup = monthlyBarData.reduce((a, b) => 
          a.barRods.first.toY > b.barRods.first.toY ? a : b);
      maxMonth = maxGroup.barRods.first.toY;
      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      maxMonthName = monthNames[maxGroup.x.toInt()];
    }
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selectedBarFilter == 'Income' ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selectedBarFilter == 'Income' ? Colors.green.shade200 : Colors.red.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Total', _formatAmount(total), Icons.account_balance_wallet),
              _buildSummaryItem('Average', _formatAmount(average), Icons.trending_up),
              _buildSummaryItem('Peak Month', '$maxMonthName\n₹${_formatAmount(maxMonth)}', Icons.star),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Overview',
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
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
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
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date Range',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDate(context, true),
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: Colors.blue, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    _dateFormat.format(_startDate),
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('to', style: TextStyle(color: Colors.grey[600])),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDate(context, false),
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: Colors.blue, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    _dateFormat.format(_endDate),
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Container(
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
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Chart Analysis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedChartType,
                              items: [
                                'Income vs Expense',
                                'Only Expense',
                                'Category Wise'
                              ].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedChartType = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Container(
                      height: 300,
                      child: PieChart(_buildPieChart(context)),
                    ),
                    SizedBox(height: 16),
                    _buildLegend(),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Container(
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
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Monthly Analysis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedBarFilter,
                              items: ['Income', 'Expense'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedBarFilter = newValue;
                                    _loadTransactions();
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildBarSummary(),
                    SizedBox(height: 20),
                    Container(
                      height: 300,
                      child: BarChart(_buildBarChart()),
                    ),
                  ],
                ),
              ),
            ],
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
}
