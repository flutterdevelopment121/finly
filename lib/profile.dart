import 'dart:math'; // Import for min/max functions
import 'dart:ui' as ui; // Import dart:ui for canvas operations

import 'package:fl_chart/fl_chart.dart'; // Import fl_chart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import intl
import 'package:supabase_flutter/supabase_flutter.dart';

// --- Custom Dot Painter with Label ---
// (Keep the CustomDotPainterWithLabel class exactly as it was)
class CustomDotPainterWithLabel extends FlDotPainter {
  final Color dotColor;
  final Color strokeColor;
  final double dotRadius;
  final double strokeWidth;
  final Color labelColor;
  final double labelFontSize;

  CustomDotPainterWithLabel({
    this.dotColor = Colors.blue,
    this.strokeColor = Colors.black,
    this.dotRadius = 4.0,
    this.strokeWidth = 1.0,
    this.labelColor = Colors.white,
    this.labelFontSize = 9.0,
  });

  @override
  void draw(ui.Canvas canvas, FlSpot spot, Offset center) {
    // 1. Draw the stroke (optional border)
    if (strokeWidth > 0) {
      final strokePaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, dotRadius, strokePaint);
    }

    // 2. Draw the main dot
    final mainPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, dotRadius, mainPaint);

    // 3. Prepare and draw the text label
    final textStyle = TextStyle(
        color: labelColor,
        fontSize: labelFontSize,
        fontWeight: FontWeight.bold,
        shadows: [
          // Optional: Add a slight shadow for better readability
          Shadow(
            blurRadius: 1.0,
            color: Colors.black.withOpacity(0.5),
            offset: Offset(0.5, 0.5),
          ),
        ]);

    // Format the amount (using compact currency)
    final formattedAmount =
        NumberFormat.compactCurrency(symbol: '₹', decimalDigits: 0)
            .format(spot.y);

    final textSpan = TextSpan(
      text: formattedAmount,
      style: textStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout();

    // Calculate position for the text (centered above the dot)
    final textOffset = Offset(
      center.dx - (textPainter.width / 2),
      center.dy -
          dotRadius -
          textPainter.height -
          2, // Position above the dot with some padding
    );

    textPainter.paint(canvas, textOffset);
  }

  @override
  Size getSize(FlSpot spot) {
    return Size(dotRadius * 2, dotRadius * 2);
  }

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) {
    if (a is! CustomDotPainterWithLabel || b is! CustomDotPainterWithLabel) {
      // Fallback if types don't match (though they should in normal use)
      return t < 0.5 ? a : b;
    }
    return CustomDotPainterWithLabel(
      dotColor: Color.lerp(a.dotColor, b.dotColor, t)!,
      strokeColor: Color.lerp(a.strokeColor, b.strokeColor, t)!,
      dotRadius: ui.lerpDouble(a.dotRadius, b.dotRadius, t)!,
      strokeWidth: ui.lerpDouble(a.strokeWidth, b.strokeWidth, t)!,
      labelColor: Color.lerp(a.labelColor, b.labelColor, t)!,
      labelFontSize: ui.lerpDouble(a.labelFontSize, b.labelFontSize, t)!,
    );
  }

  @override
  Color get mainColor => dotColor;

  @override
  List<Object?> get props => [
        dotColor,
        strokeColor,
        dotRadius,
        strokeWidth,
        labelColor,
        labelFontSize,
      ];
}

// Data structure for monthly spending
class MonthlySpending {
  final DateTime month;
  final double amount;

  MonthlySpending({required this.month, required this.amount});
}

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  User? _user;
  double _totalBalance = 0.0;
  double _totalEarnings = 0.0; // Will hold yearly earnings
  double _totalSpend = 0.0; // Will hold yearly spend
  bool _isLoading = true; // Combined loading state

  // --- State for Line Chart ---
  List<MonthlySpending> _monthlySpendingData =
      []; // Will hold yearly chart data
  int _touchedIndexLineChart = -1; // For highlighting the selected month dot
  String _chartErrorMessage = ''; // Specific error message for the chart

  // --- Chart Colors ---
  final Color _lineColor = Colors.blueAccent; // Color for the line graph
  final Color _selectedDotColor =
      Colors.purpleAccent; // Highlight color for selected month dot
  final Color _selectedBgColor = Colors.purpleAccent
      .withOpacity(0.1); // Background for selected month range

  @override
  void initState() {
    super.initState();
    _fetchAllProfileData(); // Fetch user profile, financial data, and chart data
  }

  // --- REFINED Data Processing Logic for Current Year ---
  List<MonthlySpending> _processAndFillMonthlyDataCurrentYear(
      List<MonthlySpending> rawData) {
    final now = DateTime.now();
    final int currentYear = now.year;
    final int currentMonth = now.month; // Get the current month number (1-12)

    // Filter raw data to include only the current year
    final currentYearRawData =
        rawData.where((item) => item.month.year == currentYear).toList();

    // If no data for the current year, create a list from Jan to current month with 0s
    if (currentYearRawData.isEmpty) {
      List<MonthlySpending> emptyYearData = [];
      for (int m = 1; m <= currentMonth; m++) {
        emptyYearData
            .add(MonthlySpending(month: DateTime(currentYear, m), amount: 0.0));
      }
      return emptyYearData;
    }

    // Create a map for quick lookup of existing data for the current year
    final Map<DateTime, double> rawDataMap = {
      for (var item in currentYearRawData) item.month: item.amount
    };

    // Determine the date range within the current year (Jan to current month or last data month)
    DateTime startDate = DateTime(currentYear, 1); // Always start from January
    // Determine the end month: either the current month or the last month with data, whichever is later
    DateTime maxDataDate = currentYearRawData.last.month;
    DateTime endDate =
        DateTime(currentYear, max(currentMonth, maxDataDate.month));

    final List<MonthlySpending> processedData = [];
    DateTime monthIterator = startDate;

    // Iterate from January to the determined end date, month by month
    while (monthIterator.isBefore(endDate) ||
        monthIterator.isAtSameMomentAs(endDate)) {
      // Check if data exists for the current month in the original map
      final amount =
          rawDataMap[monthIterator] ?? 0.0; // Default to 0.0 if missing
      processedData.add(MonthlySpending(month: monthIterator, amount: amount));

      // Move to the next month
      monthIterator = DateTime(monthIterator.year, monthIterator.month + 1);
      // Handle year transition if needed (though unlikely within single year processing)
      if (monthIterator.year > currentYear) break;
    }

    return processedData;
  }

  // Fetches all necessary data concurrently
  Future<void> _fetchAllProfileData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _chartErrorMessage = ''; // Reset chart error on refresh
    });

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/');
        return;
      }

      // Use Future.wait to fetch financial data and monthly spending in parallel
      final results = await Future.wait([
        _fetchTotalBalance(currentUser.id), // Fetches overall balance
        _fetchTotalTransactions(
            currentUser.id), // Fetches YEARLY income/expense
        _fetchMonthlySpending(currentUser.id), // Fetches YEARLY raw chart data
      ]);

      // Process results safely
      final balanceResult = results[0] as double;
      final transactionSums = results[1] as Map<String, double>; // Yearly sums
      final rawMonthlySpendingResult =
          results[2] as List<MonthlySpending>; // Yearly raw chart data

      // --- Process and fill the monthly data FOR CURRENT YEAR ---
      final processedSpendingData =
          _processAndFillMonthlyDataCurrentYear(rawMonthlySpendingResult);
      // --- End processing ---

      if (mounted) {
        setState(() {
          _user = currentUser;
          _totalBalance = balanceResult; // Overall balance
          _totalEarnings = transactionSums['income'] ?? 0.0; // Yearly income
          _totalSpend = transactionSums['expense'] ?? 0.0; // Yearly expense
          // Use the processed yearly data for the chart
          _monthlySpendingData = processedSpendingData;
          _isLoading = false;

          // Update touched index: Highlight the last month with actual spending,
          // or the very last month if all are zero.
          if (_monthlySpendingData.isNotEmpty) {
            // Find the last index with a non-zero amount
            int lastRealSpendingIndex =
                _monthlySpendingData.lastIndexWhere((d) => d.amount > 0);
            // If no spending found (all zeros), default to the last index
            _touchedIndexLineChart = lastRealSpendingIndex != -1
                ? lastRealSpendingIndex
                : _monthlySpendingData.length - 1;
          } else {
            _touchedIndexLineChart = -1;
          }
        });
      }
    } catch (e) {
      print('Error fetching profile data: $e'); // Log the error
      if (mounted) {
        bool isChartError =
            e.toString().toLowerCase().contains('monthly spending');

        setState(() {
          _user = supabase.auth.currentUser;
          _isLoading = false;

          if (isChartError) {
            _chartErrorMessage = 'Could not load spending chart data.';
          } else {
            _chartErrorMessage = '';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('Error fetching profile data: ${e.toString()}')),
            );
          }
        });
      }
    }
  }

  // Fetches the sum of balances from all user cards (Overall Balance)
  Future<double> _fetchTotalBalance(String userId) async {
    try {
      final response =
          await supabase.from('cards').select('balance').eq('user_id', userId);
      double total = 0.0;
      for (var card in response) {
        total += (card['balance'] as num?)?.toDouble() ?? 0.0;
      }
      return total;
    } catch (e) {
      print('Error fetching total balance: $e');
      throw Exception('Failed to fetch total balance: $e');
    }
  }

  // Fetches transactions FOR THE CURRENT YEAR and calculates total income and expenses
  Future<Map<String, double>> _fetchTotalTransactions(String userId) async {
    try {
      // 1. Determine the start and end dates for the current year
      final now = DateTime.now();
      final startOfYear =
          DateTime(now.year, 1, 1); // January 1st of current year
      final startOfNextYear =
          DateTime(now.year + 1, 1, 1); // January 1st of next year

      // 2. Fetch transactions within the current year
      final response = await supabase
          .from('transactions')
          .select('amount, type')
          .eq('user_id', userId)
          .gte(
              'created_at',
              startOfYear
                  .toIso8601String()) // Greater than or equal to start of year
          .lt(
              'created_at',
              startOfNextYear
                  .toIso8601String()); // Less than start of next year

      double incomeTotal = 0.0;
      double expenseTotal = 0.0;

      // 3. Calculate totals (same logic as before)
      for (var transaction in response) {
        final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
        final type = transaction['type'] as String?;
        if (type == 'income') {
          incomeTotal += amount;
        } else if (type == 'expense') {
          expenseTotal += amount;
        }
      }
      return {'income': incomeTotal, 'expense': expenseTotal};
    } catch (e) {
      print('Error fetching yearly transactions: $e'); // Updated log message
      throw Exception('Failed to fetch yearly transactions: $e');
    }
  }

  // Fetches transactions FOR THE CURRENT YEAR and calculates monthly totals
  Future<List<MonthlySpending>> _fetchMonthlySpending(String userId) async {
    try {
      // Determine the start and end dates for the current year
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);
      final startOfNextYear = DateTime(now.year + 1, 1, 1);

      // Fetch transactions within the current year
      final response = await supabase
          .from('transactions')
          .select('amount, created_at')
          .eq('user_id', userId)
          .eq('type', 'expense')
          .gte('created_at', startOfYear.toIso8601String()) // Filter >= Jan 1st
          .lt('created_at',
              startOfNextYear.toIso8601String()) // Filter < Jan 1st next year
          .order('created_at', ascending: true);

      final Map<DateTime, double> monthlyTotals = {};
      for (var transaction in response) {
        final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
        final createdAtString = transaction['created_at'] as String?;
        if (createdAtString == null) continue;

        final createdAt = DateTime.tryParse(createdAtString)?.toLocal();
        if (createdAt == null) continue;

        // Group by month (start of the month)
        final monthKey = DateTime(createdAt.year, createdAt.month);
        monthlyTotals[monthKey] = (monthlyTotals[monthKey] ?? 0.0) + amount;
      }

      // Convert map to sorted list for the chart
      List<MonthlySpending> spendingData = monthlyTotals.entries
          .map(
              (entry) => MonthlySpending(month: entry.key, amount: entry.value))
          .toList();
      spendingData.sort((a, b) => a.month.compareTo(b.month)); // Ensure sorted

      return spendingData; // Return raw data for the current year
    } catch (e) {
      print('Error fetching yearly monthly spending data: $e');
      throw Exception('Failed to fetch yearly monthly spending data: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${error.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: Text('Profile & Overview',
            style: TextStyle(color: Colors.white)), // Updated title
        backgroundColor: Colors.grey.shade800,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : _user == null
              ? Center(
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Could not load user profile.',
                        style: TextStyle(color: Colors.white)),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _fetchAllProfileData,
                      child: Text('Retry'),
                    )
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _fetchAllProfileData,
                  color: Colors.white,
                  backgroundColor: Colors.grey.shade800,
                  child: ListView(
                    padding: EdgeInsets.all(16.0),
                    children: [
                      // --- User Info Section ---
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.person_outline,
                                size: 50,
                                color: Colors.grey.shade900,
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              'Welcome!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              _user?.email ?? 'No email found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 40),

                      // --- Financial Summary Section ---
                      _buildFinancialSummaryCard(),

                      SizedBox(height: 40), // Spacing before the chart

                      // --- Monthly Spending Chart Section ---
                      Text(
                        'Monthly Spending Trend (${DateTime.now().year})', // Add year to title
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 20),
                      _buildChartSection(), // Display chart or error/empty message

                      SizedBox(height: 40), // Spacing after the chart

                      // --- Change Password Button --- Added ---
                      Center(
                        child: OutlinedButton.icon(
                          // Using OutlinedButton for visual distinction
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Colors.amberAccent, // Text/Icon color
                            side: BorderSide(
                                color: Colors.amberAccent.withOpacity(0.7)),
                            padding: EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                          ),
                          onPressed: () {
                            // TODO: Make sure '/change_password' route is defined in main.dart
                            Navigator.pushNamed(context, '/change_password');
                          },
                          icon: Icon(Icons.lock_reset_outlined),
                          label: Text(
                            'Change Password',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      SizedBox(height: 20), // Spacing between buttons

                      // --- Logout Button ---
                      Center(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.redAccent,
                            shadowColor: Colors.transparent,
                            side: BorderSide(color: Colors.redAccent),
                            padding: EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                          ),
                          onPressed: _signOut,
                          icon: Icon(Icons.logout),
                          label: Text(
                            'Logout',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  // Helper widget for the financial summary card
  Widget _buildFinancialSummaryCard() {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Summary', // Removed (All Cards) as income/expense is yearly
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Divider(color: Colors.white24, height: 25),
          _buildSummaryRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Total Balance Left:', // Overall balance
            amount: _totalBalance,
            color: Colors.blueAccent,
          ),
          SizedBox(height: 12),
          _buildSummaryRow(
            icon: Icons.arrow_upward_rounded,
            label: 'Earnings This Year:', // Clarified label
            amount: _totalEarnings, // Yearly income
            color: Colors.greenAccent,
          ),
          SizedBox(height: 12),
          _buildSummaryRow(
            icon: Icons.arrow_downward_rounded,
            label: 'Spending This Year:', // Clarified label
            amount: _totalSpend, // Yearly expense
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  // Helper widget for a single row in the summary card
  Widget _buildSummaryRow(
      {required IconData icon,
      required String label,
      required double amount,
      required Color color}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade300,
            ),
          ),
        ),
        Text(
          '₹${NumberFormat.currency(symbol: '', decimalDigits: 2).format(amount)}', // Use NumberFormat for better currency display
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // Widget to build the chart container or message
  Widget _buildChartSection() {
    if (_chartErrorMessage.isNotEmpty) {
      return Container(
        height: 250, // Match chart height
        alignment: Alignment.center,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Optional: Style error message container
          borderRadius: BorderRadius.circular(15),
          color: Colors.red.withOpacity(0.1),
          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        ),
        child: Text(
          _chartErrorMessage,
          style: TextStyle(color: Colors.redAccent, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }
    // Show message only if not loading and data is truly empty
    if (_monthlySpendingData.isEmpty && !_isLoading) {
      return Container(
        height: 250, // Match chart height
        alignment: Alignment.center,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Optional: Style empty message container
          borderRadius: BorderRadius.circular(15),
          color: Colors.white.withOpacity(0.05),
          // border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          'No spending data to display for ${DateTime.now().year} yet.', // Updated empty message
          style: TextStyle(color: Colors.grey, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }
    // If loading or data exists, build the chart
    return _buildLineChart();
  }

  // Line Chart Widget using CustomDotPainterWithLabel - NOW SCROLLABLE
  Widget _buildLineChart() {
    if (_monthlySpendingData.isEmpty)
      return SizedBox(height: 250); // Placeholder height

    final double minX = 0;
    final double maxX = max(0, _monthlySpendingData.length - 1).toDouble();

    // --- Calculate Minimum Width for Scrolling ---
    // Estimate width needed per month (adjust this value based on desired spacing)
    const double widthPerMonth = 60.0;
    // Calculate total minimum width based on number of months
    final double minChartWidth = _monthlySpendingData.length * widthPerMonth;
    // Ensure minimum width is at least the screen width minus padding
    final screenWidth = MediaQuery.of(context).size.width;
    final double containerPadding =
        16.0 * 2; // Horizontal padding of the outer ListView
    final double availableWidth = screenWidth - containerPadding;
    final double calculatedWidth = max(availableWidth, minChartWidth);
    // --- End Width Calculation ---

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, // Enable horizontal scrolling
      child: Container(
        height: 250, // Keep fixed height
        width:
            calculatedWidth, // Use calculated width (allows scrolling if needed)
        padding: EdgeInsets.only(
            top: 24,
            right: 16 +
                (widthPerMonth /
                    2), // Add padding to avoid clipping last label/dot
            bottom: 8,
            left: 16), // Add left padding
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.white.withOpacity(0.05),
        ),
        child: LineChart(
          LineChartData(
            clipData: FlClipData.all(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: _calculateHorizontalInterval(),
              getDrawingHorizontalLine: (value) {
                return FlLine(color: Colors.white12, strokeWidth: 1);
              },
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 55,
                  interval: _calculateHorizontalInterval(),
                  getTitlesWidget: (value, meta) {
                    if (value == meta.min) return Container();
                    return Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Text(
                        NumberFormat.compactCurrency(
                                symbol: '₹', decimalDigits: 0)
                            .format(value),
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 10),
                        textAlign: TextAlign.right,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < _monthlySpendingData.length) {
                      final month = _monthlySpendingData[index].month;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          DateFormat.MMM().format(month),
                          style: TextStyle(
                            color: index == _touchedIndexLineChart
                                ? _selectedDotColor
                                : Colors.grey.shade400,
                            fontSize: 10,
                            fontWeight: index == _touchedIndexLineChart
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return Text('');
                  },
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.white12, width: 1),
            ),
            minX: minX,
            maxX: maxX, // maxX is based on index count, which is fine
            minY: 0,
            maxY: _calculateMaxY(),
            lineBarsData: [
              LineChartBarData(
                spots: _getChartSpots(),
                isCurved: true,
                gradient: LinearGradient(
                  colors: [_lineColor.withOpacity(0.8), _lineColor],
                ),
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      final bool isTouched = (index == _touchedIndexLineChart);
                      final Color currentDotColor =
                          isTouched ? _selectedDotColor : _lineColor;
                      final Color currentLabelColor = isTouched
                          ? _selectedDotColor
                          : Colors.white.withOpacity(0.8);

                      return CustomDotPainterWithLabel(
                        dotColor: currentDotColor,
                        dotRadius: isTouched ? 6 : 4,
                        strokeColor: Colors.white.withOpacity(0.5),
                        strokeWidth: 1.0,
                        labelColor: currentLabelColor,
                        labelFontSize: 9.0,
                      );
                    }),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      _lineColor.withOpacity(0.3),
                      _lineColor.withOpacity(0.0)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                showingIndicators: _touchedIndexLineChart != -1
                    ? [_touchedIndexLineChart]
                    : [],
              ),
            ],
            lineTouchData: LineTouchData(
              enabled: true, // Enable touch interactions
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (spot) => Colors.black.withOpacity(0.8),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots
                      .map((spot) {
                        final index = spot.spotIndex;
                        if (index < 0 || index >= _monthlySpendingData.length)
                          return null; // Safety check
                        final data = _monthlySpendingData[index];
                        return LineTooltipItem(
                          '${DateFormat.yMMMM().format(data.month)}\n',
                          TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                          children: [
                            TextSpan(
                              text: NumberFormat.currency(
                                      symbol: '₹ ', decimalDigits: 2)
                                  .format(data.amount), // Formatted amount
                              style: TextStyle(
                                  color: _lineColor,
                                  fontWeight: FontWeight.normal,
                                  fontSize: 11),
                            ),
                          ],
                          textAlign: TextAlign.left,
                        );
                      })
                      .whereType<LineTooltipItem>()
                      .toList(); // Filter out nulls
                },
              ),
              touchCallback:
                  (FlTouchEvent event, LineTouchResponse? touchResponse) {
                if (!event.isInterestedForInteractions ||
                    touchResponse == null ||
                    touchResponse.lineBarSpots == null ||
                    touchResponse.lineBarSpots!.isEmpty) {
                  return;
                }
                final value = touchResponse.lineBarSpots![0].spotIndex;

                // Update the highlighted dot on touch/hover events
                if (event is FlTapDownEvent ||
                    event is FlLongPressStart ||
                    event is FlPointerHoverEvent ||
                    event is FlLongPressMoveUpdate) {
                  if (value != _touchedIndexLineChart) {
                    setState(() {
                      _touchedIndexLineChart = value;
                    });
                  }
                }
              },
              // --- Adjust background highlight width calculation ---
              getTouchedSpotIndicator: (barData, spotIndexes) {
                if (spotIndexes.isEmpty) return [];
                // Width of each section on the x-axis within the potentially wider chart
                // Use maxX which represents the number of intervals (length - 1)
                double sectionWidth = calculatedWidth / (maxX > 0 ? maxX : 1);
                // If only one point (maxX is 0), use a fixed width or the whole chart width
                if (maxX == 0) {
                  sectionWidth = calculatedWidth;
                }

                // Make the background slightly narrower than the full section width
                double bgWidth = sectionWidth * 0.8;

                return spotIndexes.map((index) {
                  return TouchedSpotIndicatorData(
                    FlLine(
                      color: _selectedBgColor,
                      strokeWidth: bgWidth,
                    ),
                    FlDotData(show: false),
                  );
                }).toList();
              },
              getTouchLineStart: (_, __) => 0,
              getTouchLineEnd: (_, __) => double.infinity,
            ),
            extraLinesData: ExtraLinesData(
                // Ensure space for bg highlight at bottom
                horizontalLines: [
                  HorizontalLine(y: 0, color: Colors.transparent)
                ]),
          ),
          duration: Duration(milliseconds: 250), // Animation duration
          curve: Curves.easeInOut, // Animation curve
        ),
      ),
    );
  }

  // Helper to get FlSpot list for line chart
  List<FlSpot> _getChartSpots() {
    if (_monthlySpendingData.isEmpty) return [];
    return _monthlySpendingData.asMap().entries.map((entry) {
      int index = entry.key;
      MonthlySpending data = entry.value;
      return FlSpot(index.toDouble(), data.amount);
    }).toList();
  }

  // Helper to calculate max Y value for the line chart axis
  double _calculateMaxY() {
    if (_monthlySpendingData.isEmpty) return 1000.0; // Default max Y if no data
    double maxAmount = 0;
    for (var data in _monthlySpendingData) {
      if (data.amount > maxAmount) {
        maxAmount = data.amount;
      }
    }
    // If maxAmount is very low (e.g., all zeros), use a reasonable default max
    if (maxAmount < 500) return 1000.0;

    double paddedMax = maxAmount * 1.35; // Increased padding to 35%
    return paddedMax;
  }

  // Helper to calculate interval for Y axis and grid lines
  double _calculateHorizontalInterval() {
    final maxY = _calculateMaxY();
    if (maxY <= 0) return 200.0; // Default interval

    // Aim for roughly 4-6 grid lines/labels
    if (maxY <= 1000) return 200;
    if (maxY <= 2000) return 400;
    if (maxY <= 5000) return 1000;
    if (maxY <= 10000) return 2000;
    if (maxY <= 25000) return 5000;
    if (maxY <= 50000) return 10000;
    if (maxY <= 100000) return 20000;

    // Generic fallback: divide max by 5 and round to a nice number
    double interval = maxY / 5.0;
    if (interval > 10000) return (interval / 10000).ceil() * 10000;
    if (interval > 1000) return (interval / 1000).ceil() * 1000;
    if (interval > 100) return (interval / 100).ceil() * 100;
    return (interval / 10).ceil() * 10;
  }
} // End of _ProfilePageState
