import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/material.dart';

class EmailService {
  static const String _gmailUsername = 'your-email@gmail.com'; // Replace with your Gmail
  static const String _gmailAppPassword = 'YOUR_GMAIL_PASS_KEY'; // Replace with your actual GMAIL_PASS_KEY

  static Future<bool> sendExpenseAlert({
    required String recipientEmail,
    required String userName,
    required double totalExpense,
    required double totalIncome,
    required String alertType,
  }) async {
    try {
      final smtpServer = gmail(_gmailUsername, _gmailAppPassword);

      String subject = '';
      String body = '';

      switch (alertType) {
        case 'expense_alert':
          subject = '⚠️ Budget Alert - High Expenses Detected';
          body = '''
Dear $userName,

This is an automated alert from your BudgetGuard app.

📊 Expense Summary:
• Total Income: ₹${totalIncome.toStringAsFixed(2)}
• Total Expenses: ₹${totalExpense.toStringAsFixed(2)}
• Expense Ratio: ${((totalExpense / totalIncome) * 100).toStringAsFixed(1)}%

⚠️ Your expenses have exceeded 80% of your income. Please review your spending habits and consider adjusting your budget.

Tips to reduce expenses:
• Review subscription services
• Track daily spending
• Set weekly budget limits
• Consider meal planning

Best regards,
BudgetGuard Team
          ''';
          break;
        case 'budget_exceeded':
          subject = '🚨 Budget Exceeded - Action Required';
          body = '''
Dear $userName,

🚨 BUDGET EXCEEDED 🚨

Your current expenses (₹${totalExpense.toStringAsFixed(2)}) have exceeded your income (₹${totalIncome.toStringAsFixed(2)}).

Immediate Action Required:
1. Review all recent transactions
2. Identify non-essential expenses
3. Consider temporary spending freeze
4. Contact financial advisor if needed

Your BudgetGuard app is here to help you get back on track!

Best regards,
BudgetGuard Team
          ''';
          break;
        case 'monthly_report':
          subject = '📈 Monthly Budget Report';
          body = '''
Dear $userName,

📊 Your Monthly Budget Report

Financial Summary:
• Total Income: ₹${totalIncome.toStringAsFixed(2)}
• Total Expenses: ₹${totalExpense.toStringAsFixed(2)}
• Savings: ₹${(totalIncome - totalExpense).toStringAsFixed(2)}

Keep up the good work with your budgeting!

Best regards,
BudgetGuard Team
          ''';
          break;
      }

      final message = Message()
        ..from = Address(_gmailUsername, 'BudgetGuard App')
        ..recipients.add(recipientEmail)
        ..subject = subject
        ..text = body;

      final sendReport = await send(message, smtpServer);

      print('Message sent: ' + sendReport.toString());
      return true;
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }

  static Future<bool> sendReceiptEmail({
    required String recipientEmail,
    required String userName,
    required String extractedText,
    required String receiptDate,
  }) async {
    try {
      final smtpServer = gmail(_gmailUsername, _gmailAppPassword);

      final message = Message()
        ..from = Address(_gmailUsername, 'BudgetGuard App')
        ..recipients.add(recipientEmail)
        ..subject = '🧾 Scanned Receipt - $receiptDate'
        ..text = '''
Dear $userName,

Your receipt has been successfully scanned and processed.

📅 Date: $receiptDate
🧾 Extracted Text:
$extractedText

This receipt has been saved to your BudgetGuard account. You can view and categorize this expense in your transaction history.

Best regards,
BudgetGuard Team
        ''';

      final sendReport = await send(message, smtpServer);
      print('Receipt email sent: ' + sendReport.toString());
      return true;
    } catch (e) {
      print('Error sending receipt email: $e');
      return false;
    }
  }

  static Future<bool> sendBillReminder({
    required String recipientEmail,
    required String userName,
    required String billName,
    required String dueDate,
    required double amount,
  }) async {
    try {
      final smtpServer = gmail(_gmailUsername, _gmailAppPassword);

      final message = Message()
        ..from = Address(_gmailUsername, 'BudgetGuard App')
        ..recipients.add(recipientEmail)
        ..subject = '📅 Bill Reminder - $billName Due Soon'
        ..text = '''
Dear $userName,

📅 BILL REMINDER 📅

Bill Details:
• Bill Name: $billName
• Due Date: $dueDate
• Amount: ₹${amount.toStringAsFixed(2)}
• Days Remaining: ${_calculateDaysRemaining(dueDate)}

Please ensure timely payment to avoid late fees. You can mark this bill as paid in your BudgetGuard app.

Best regards,
BudgetGuard Team
        ''';

      final sendReport = await send(message, smtpServer);
      print('Bill reminder sent: ' + sendReport.toString());
      return true;
    } catch (e) {
      print('Error sending bill reminder: $e');
      return false;
    }
  }

  static String _calculateDaysRemaining(String dueDate) {
    try {
      DateTime due = DateTime.parse(dueDate);
      DateTime now = DateTime.now();
      Duration difference = due.difference(now);
      return difference.inDays.toString();
    } catch (e) {
      return 'Unknown';
    }
  }

  static void showEmailSentDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.email, color: Colors.green),
              SizedBox(width: 8),
              Text('Email Sent'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  static void showEmailErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Email Failed'),
            ],
          ),
          content: Text('Failed to send email: $error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
