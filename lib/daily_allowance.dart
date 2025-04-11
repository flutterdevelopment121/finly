import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DailyAllowancePage extends StatefulWidget {
  @override
  _DailyAllowancePageState createState() => _DailyAllowancePageState();
}

class _DailyAllowancePageState extends State<DailyAllowancePage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _cardAllowances = [];
  bool _isLoading = true;
  String? _error;
  DateTime? _periodEndDate; // To display the end date of the cycle

  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final dateFormatter = DateFormat('MMM d, yyyy'); // For displaying dates

  @override
  void initState() {
    super.initState();
    _calculateAllowances();
  }

  Future<void> _calculateAllowances() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _periodEndDate = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception("User not logged in.");
      }

      // 1. Fetch Cards
      final response = await supabase
          .from('cards')
          .select('id, name, balance')
          .eq('user_id', user.id);

      final List<Map<String, dynamic>> cards =
          List<Map<String, dynamic>>.from(response);

      // 2. Calculate Date Range and Remaining Days
      final now = DateTime.now();
      // Create a date-only version of 'now' for accurate day difference calculation
      final today = DateTime(now.year, now.month, now.day);

      DateTime startDate;
      DateTime nextCycleStartDate;

      if (today.day >= 10) {
        // Current cycle started on the 10th of this month
        startDate = DateTime(today.year, today.month, 10);
        // Next cycle starts on the 10th of next month
        nextCycleStartDate = DateTime(today.year, today.month + 1, 10);
      } else {
        // Current cycle started on the 10th of last month
        startDate = DateTime(today.year, today.month - 1, 10);
        // Next cycle starts on the 10th of this month
        nextCycleStartDate = DateTime(today.year, today.month, 10);
      }

      // The current period ends the day before the next cycle starts
      final periodEndDate = nextCycleStartDate.subtract(Duration(days: 1));

      // Calculate remaining days (inclusive of today)
      int remainingDays = periodEndDate.difference(today).inDays + 1;

      // Handle edge case where period might be ending today or already passed
      if (remainingDays <= 0) {
        remainingDays =
            1; // Avoid division by zero, show full balance for today
      }

      // 3. Calculate Allowance for each card
      List<Map<String, dynamic>> allowances = [];
      for (var card in cards) {
        final balance = (card['balance'] as num?)?.toDouble() ?? 0.0;
        double dailyAllowance = (balance > 0 && remainingDays > 0)
            ? balance / remainingDays
            : balance;
        // If balance is negative, show the negative balance as allowance doesn't make sense
        if (balance < 0) {
          dailyAllowance = balance;
        }

        allowances.add({
          'name': card['name'],
          'balance': balance,
          'allowance': dailyAllowance,
        });
      }

      if (mounted) {
        setState(() {
          _cardAllowances = allowances;
          _periodEndDate = periodEndDate; // Store for display
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error calculating allowances: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Failed to calculate daily allowances: ${e.toString()}";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: Text('Daily Allowance', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey.shade900,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _calculateAllowances,
        color: Colors.white,
        backgroundColor: Colors.grey.shade900,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error!,
              style: TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center),
        ),
      );
    }

    if (_cardAllowances.isEmpty) {
      return Center(
        child: Text('No cards found to calculate allowance.',
            style: TextStyle(color: Colors.white70)),
      );
    }

    return ListView(
      // Use ListView to include header text easily
      children: [
        if (_periodEndDate != null)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text(
              'Suggested daily spending until ${dateFormatter.format(_periodEndDate!)}:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ListView.builder(
          shrinkWrap: true, // Important when nested inside another ListView
          physics:
              NeverScrollableScrollPhysics(), // Disable scrolling for the inner list
          itemCount: _cardAllowances.length,
          itemBuilder: (context, index) {
            final item = _cardAllowances[index];
            final allowance = item['allowance'] as double;
            final balance = item['balance'] as double;
            final Color allowanceColor =
                allowance >= 0 ? Colors.lightBlueAccent : Colors.redAccent;

            return Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withOpacity(0.08),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    // Allow card name to wrap if long
                    child: Text(
                      item['name'] as String,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFormatter.format(allowance),
                        style: TextStyle(
                          color: allowanceColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Bal: ${currencyFormatter.format(balance)}', // Show current balance for context
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
