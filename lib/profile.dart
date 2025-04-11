import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  User? _user;
  double _totalBalance = 0.0;
  double _totalEarnings = 0.0;
  double _totalSpend = 0.0;
  bool _isLoading = true; // Combined loading state

  @override
  void initState() {
    super.initState();
    _fetchAllProfileData(); // Fetch user profile and financial data
  }

  // Fetches all necessary data concurrently
  Future<void> _fetchAllProfileData() async {
    // Ensure loading state is true when fetching starts
    // No need to check _isLoading here, just set it.
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        // Not logged in, navigate away
        if (mounted)
          Navigator.pushReplacementNamed(
              context, '/'); // Assuming '/' is your login/splash route
        return;
      }

      // Use Future.wait to fetch financial data in parallel
      final results = await Future.wait([
        _fetchTotalBalance(currentUser.id),
        _fetchTotalTransactions(currentUser.id),
      ]);

      // Process results safely
      final balanceResult =
          results[0] as double; // Cast result from _fetchTotalBalance
      final transactionSums = results[1]
          as Map<String, double>; // Cast result from _fetchTotalTransactions

      if (mounted) {
        setState(() {
          _user = currentUser; // Set user state here after successful fetch
          _totalBalance = balanceResult;
          _totalEarnings = transactionSums['income'] ?? 0.0;
          _totalSpend = transactionSums['expense'] ?? 0.0;
          _isLoading = false; // Set loading false after all data is fetched
        });
      }
    } catch (e) {
      print('Error fetching profile data: $e'); // Log the error for debugging
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error fetching profile data: ${e.toString()}')),
        );
        // Still need to set user and stop loading, even if financial data fails partially
        // Or decide on a different error state UI
        setState(() {
          _user =
              supabase.auth.currentUser; // Try setting user again just in case
          _isLoading = false; // Stop loading even on error
        });
      }
    }
  }

  // Fetches the sum of balances from all user cards
  Future<double> _fetchTotalBalance(String userId) async {
    try {
      final response = await supabase
          .from('cards')
          .select('balance') // Select only the balance
          .eq('user_id', userId);

      double total = 0.0;
      for (var card in response) {
        // Ensure balance is treated as a number and handle potential nulls
        total += (card['balance'] as num?)?.toDouble() ?? 0.0;
      }
      return total;
    } catch (e) {
      print('Error fetching total balance: $e');
      // Re-throw the error to be caught by _fetchAllProfileData
      // or return 0.0 and handle potential partial data display
      throw Exception('Failed to fetch total balance: $e');
    }
  }

  // Fetches all transactions and calculates total income and expenses
  Future<Map<String, double>> _fetchTotalTransactions(String userId) async {
    try {
      final response = await supabase
          .from('transactions')
          .select('amount, type') // Select amount and type
          .eq('user_id', userId);

      double incomeTotal = 0.0;
      double expenseTotal = 0.0;

      for (var transaction in response) {
        final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
        final type = transaction['type'] as String?;

        if (type == 'income') {
          incomeTotal += amount;
        } else if (type == 'expense') {
          // Expenses are usually stored as positive numbers,
          // but represent spending. Keep it positive for display consistency.
          expenseTotal += amount;
        }
      }

      return {
        'income': incomeTotal,
        'expense': expenseTotal,
      };
    } catch (e) {
      print('Error fetching transactions: $e');
      // Re-throw the error
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        // Navigate back to the login/home page after sign out
        // Use pushReplacementNamed to prevent going back to the profile page
        Navigator.pushReplacementNamed(
            context, '/'); // Ensure this route exists and is correct
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
        title: Text('Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey.shade800,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : _user == null // Check if user data failed to load after trying
              ? Center(
                  child: Column(
                  // Provide option to retry
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
                  // Add RefreshIndicator to allow pull-to-refresh
                  onRefresh:
                      _fetchAllProfileData, // Call the main fetch function on refresh
                  color: Colors.white, // Spinner color
                  backgroundColor:
                      Colors.grey.shade800, // Background for spinner
                  child: ListView(
                    // Use ListView for scrollable content
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
                                Icons.person_outline, // Using outline variant
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

                      SizedBox(height: 40),

                      // --- Logout Button ---
                      Center(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor:
                                Colors.redAccent, // Text/Icon color
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
                      SizedBox(height: 20), // Add some padding at the bottom
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
        color: Colors.white.withOpacity(0.1), // Subtle background
        border:
            Border.all(color: Colors.white.withOpacity(0.2)), // Subtle border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Summary (All Cards)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Divider(color: Colors.white24, height: 25), // Visual separator
          _buildSummaryRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Total Balance Left:',
            amount: _totalBalance,
            color: Colors.blueAccent, // A neutral/positive color for balance
          ),
          SizedBox(height: 12),
          _buildSummaryRow(
            icon: Icons.arrow_upward_rounded,
            label: 'Total Earnings (Income):',
            amount: _totalEarnings,
            color: Colors.greenAccent, // Green for income
          ),
          SizedBox(height: 12),
          _buildSummaryRow(
            icon: Icons.arrow_downward_rounded,
            label: 'Total Spending (Expense):',
            amount: _totalSpend,
            color: Colors.redAccent, // Red for expenses
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
          // Use Expanded to push amount to the end
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade300,
            ),
          ),
        ),
        Text(
          // Format currency nicely
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
