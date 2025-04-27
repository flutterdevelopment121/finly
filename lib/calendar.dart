import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart'; // For date formatting

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final supabase = Supabase.instance.client;
  User? _user;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  List<Map<String, dynamic>> _transactionsForSelectedDay = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _user = supabase.auth.currentUser;
    _selectedDay = _focusedDay; // Select today initially
    if (_user != null) {
      _fetchTransactionsForDay(_selectedDay!);
    } else {
      // Handle case where user is somehow null
      setState(() {
        _isLoading = false;
        _errorMessage = 'User not logged in.';
      });
      // Optionally navigate back to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/');
        }
      });
    }
  }

  Future<void> _fetchTransactionsForDay(DateTime day) async {
    if (!mounted || _user == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _transactionsForSelectedDay = []; // Clear previous transactions
    });

    try {
      final userId = _user!.id;
      // Define the date range for the selected day
      final startOfDay = DateTime(day.year, day.month, day.day);
      final endOfDay = DateTime(day.year, day.month, day.day + 1);

      final response = await supabase
          .from('transactions')
          .select('''
            id,
            amount,
            type,
            description,
            created_at,
            card_id,
            category_id,
            cards ( name ),
            categories ( name )
          ''')
          .eq('user_id', userId)
          .gte('created_at', startOfDay.toIso8601String()) // Greater than or equal to start of day
          .lt('created_at', endOfDay.toIso8601String()) // Less than start of next day
          .order('created_at', ascending: false); // Show newest first for the day

      if (mounted) {
        setState(() {
          _transactionsForSelectedDay = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching transactions for day: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load transactions: ${e.toString()}';
        });
      }
    }
  }

  // Function to show the date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? DateTime.now(),
      firstDate: DateTime(2000), // Adjust range as needed
      lastDate: DateTime(2101),
      // Optional: Customize theme to match app
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.blueAccent, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Colors.white, // body text color
            ),
            dialogBackgroundColor: Colors.grey.shade800,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueAccent, // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDay) {
      setState(() {
        _selectedDay = picked;
        _focusedDay = picked; // Update focused day as well
      });
      _fetchTransactionsForDay(picked);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: Text('Transaction Calendar', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey.shade800,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_calendar_outlined, color: Colors.white),
            tooltip: 'Select Date',
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Calendar Widget ---
          TableCalendar(
            locale: 'en_US', // Optional: Set locale
            firstDay: DateTime.utc(2010, 1, 1), // Adjust range as needed
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              // Use `isSameDay` for accurate comparison ignoring time
              return isSameDay(_selectedDay, day);
            },
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.monday, // Optional
            // --- Styling for Dark Theme ---
            headerStyle: HeaderStyle(
              formatButtonVisible: false, // Hide format button (Month/Week/2Weeks)
              titleCentered: true,
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 18.0),
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
            ),
            calendarStyle: CalendarStyle(
              // Today's date highlight
              todayDecoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(color: Colors.white),
              // Selected date highlight
              selectedDecoration: BoxDecoration(
                color: Colors.purpleAccent, // Use a highlight color
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              // Weekend/Weekday text styles
              defaultTextStyle: TextStyle(color: Colors.white70),
              weekendTextStyle: TextStyle(color: Colors.white54),
              // Outside month days style
              outsideTextStyle: TextStyle(color: Colors.white30),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: Colors.white60),
              weekendStyle: TextStyle(color: Colors.white54),
            ),
            // --- End Styling ---
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay; // update `_focusedDay` here as well
                });
                _fetchTransactionsForDay(selectedDay);
              }
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              // No need to call `setState()` here
              _focusedDay = focusedDay;
            },
          ),
          const Divider(color: Colors.white24, height: 1),
          // --- Transaction List ---
          Expanded(
            child: _buildTransactionList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_errorMessage.isNotEmpty) {
      return Center(
          child: Text(_errorMessage, style: TextStyle(color: Colors.redAccent)));
    }
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_transactionsForSelectedDay.isEmpty) {
      return Center(
        child: Text(
          'No transactions recorded on ${DateFormat.yMMMd().format(_selectedDay!)}.',
          style: TextStyle(color: Colors.grey, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(8.0),
      itemCount: _transactionsForSelectedDay.length,
      itemBuilder: (context, index) {
        final transaction = _transactionsForSelectedDay[index];
        final bool isIncome = transaction['type'] == 'income';
        final double amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
        final String description = transaction['description'] ?? '';
        // Safely access nested data with null checks
        final String cardName = transaction['cards']?['name'] ?? 'Unknown Card';
        final String categoryName = transaction['categories']?['name'] ?? 'Uncategorized';
        final DateTime createdAt = DateTime.parse(transaction['created_at']).toLocal();


        return Card(
          color: Colors.grey.shade800.withOpacity(0.8),
          margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: Icon(
              isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: isIncome ? Colors.greenAccent : Colors.redAccent,
            ),
            title: Text(
              '₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: isIncome ? Colors.greenAccent : Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty)
                  Text(description, style: TextStyle(color: Colors.white)),
                Text(
                  '$cardName • $categoryName',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                 Text( // Show time of transaction
                   DateFormat.jm().format(createdAt), // Format like '5:08 PM'
                   style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                 ),
              ],
            ),
            isThreeLine: description.isNotEmpty, // Adjust layout if description exists
          ),
        );
      },
    );
  }
}
