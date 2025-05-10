import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui'; // For ImageFilter

// --- Data Models ---

// Re-using Category model (ensure it's accessible, e.g., defined here or imported)
class Category {
  final String id; // Assuming UUID from Supabase
  final String name;

  Category({required this.id, required this.name});

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }
}

// Model for category summary including totals
class CategorySummary {
  final String id;
  final String name;
  double totalIncome;
  double totalExpense;

  CategorySummary({
    required this.id,
    required this.name,
    this.totalIncome = 0.0,
    this.totalExpense = 0.0,
  });

  // Calculated net amount for the category
  double get netAmount => totalIncome - totalExpense;
}

// --- Category List Page ---

class CategoryListPage extends StatefulWidget {
  @override
  _CategoryListPageState createState() => _CategoryListPageState();
}

class _CategoryListPageState extends State<CategoryListPage> {
  final supabase = Supabase.instance.client;
  List<CategorySummary> _categorySummaries = [];
  bool _isLoading = true;
  String? _error; // To store potential errors

  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    _fetchDataAndCalculateSummaries();
  }

  Future<void> _fetchDataAndCalculateSummaries() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null; // Reset error on refresh
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception("User not logged in.");
      }

      // 1. Fetch all categories
      final categoriesResponse = await supabase
          .from('categories')
          .select('id, name')
          .eq('user_id', user.id);

      final List<Category> categories =
          categoriesResponse.map((map) => Category.fromMap(map)).toList();

      // 2. Fetch all transactions (consider optimization for large datasets later)
      final transactionsResponse = await supabase
          .from('transactions')
          .select('amount, type, category_id') // Select necessary fields
          .eq('user_id', user.id);
      // .not('category_id', 'is', null); // Optionally ignore uncategorized

      // 3. Calculate summaries
      Map<String, CategorySummary> summariesMap = {
        for (var category in categories)
          category.id: CategorySummary(id: category.id, name: category.name)
      };

      // Add a placeholder for uncategorized if needed
      // const String uncategorizedId = 'uncategorized';
      // summariesMap[uncategorizedId] = CategorySummary(id: uncategorizedId, name: 'Uncategorized');

      for (var transaction in transactionsResponse) {
        final categoryId = transaction['category_id'] as String?;
        final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
        final type = transaction['type'] as String?;

        // Use placeholder if categoryId is null
        final summaryKey = categoryId; // ?? uncategorizedId;

        if (summaryKey != null && summariesMap.containsKey(summaryKey)) {
          if (type == 'income') {
            summariesMap[summaryKey]!.totalIncome += amount;
          } else if (type == 'expense') {
            summariesMap[summaryKey]!.totalExpense += amount;
          }
        }
        // If you want to include uncategorized, handle the case where summaryKey is null
        // else if (summaryKey == uncategorizedId) { ... }
      }

      if (mounted) {
        setState(() {
          _categorySummaries = summariesMap.values.toList()
            // Sort summaries by total expense in descending order
            ..sort((a, b) => b.totalExpense.compareTo(a.totalExpense));
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching category summaries: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Failed to load category data: ${e.toString()}";
        });
      }
    }
  }

  void _navigateToDetail(String categoryId, String categoryName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailPage(
          categoryId: categoryId,
          categoryName: categoryName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title:
            Text('Spending by Category', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey.shade900,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDataAndCalculateSummaries,
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
          child: Text(
            _error!,
            style: TextStyle(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_categorySummaries.isEmpty) {
      return Center(
        child: Text(
          'No categories found or no transactions recorded yet.',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemCount: _categorySummaries.length,
      itemBuilder: (context, index) {
        final summary = _categorySummaries[index];
        final netAmount = summary.netAmount;
        final netColor = netAmount >= 0 ? Colors.greenAccent : Colors.redAccent;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color:
                Colors.white.withOpacity(0.08), // Slightly different background
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              summary.name,
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Income: ${currencyFormatter.format(summary.totalIncome)}',
                    style: TextStyle(
                        color: Colors.greenAccent.withOpacity(0.8),
                        fontSize: 12),
                  ),
                  Text(
                    'Expense: ${currencyFormatter.format(summary.totalExpense)}',
                    style: TextStyle(
                        color: Colors.redAccent.withOpacity(0.8), fontSize: 12),
                  ),
                ],
              ),
            ),
            trailing: Text(
              currencyFormatter
                  .format(netAmount.abs()), // Show absolute net amount
              style: TextStyle(
                color: netColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            onTap: () => _navigateToDetail(summary.id, summary.name),
          ),
        );
      },
    );
  }
}

// --- Category Detail Page ---

class CategoryDetailPage extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const CategoryDetailPage({
    Key? key,
    required this.categoryId,
    required this.categoryName,
  }) : super(key: key);

  @override
  _CategoryDetailPageState createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage> {
  final supabase = Supabase.instance.client;
  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  // Use FutureBuilder to handle loading/error states for transactions
  Future<List<Map<String, dynamic>>> _fetchCategoryTransactions() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in.");
    }

    try {
      final response = await supabase
          .from('transactions')
          .select() // Select all columns for detail view
          .eq('user_id', user.id)
          .eq('category_id', widget.categoryId)
          .order('created_at', ascending: false); // Order by date

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Error fetching category transactions: $e");
      // Re-throw the error to be caught by FutureBuilder
      throw Exception('Failed to load transactions for ${widget.categoryName}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: Text(widget.categoryName, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey.shade900,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchCategoryTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: Colors.white));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  snapshot.error.toString(),
                  style: TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No transactions found for this category.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final transactions = snapshot.data!;

          return ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
              final description = transaction['description'] as String? ?? '';
              final type = transaction['type'] as String?;
              final createdAtString = transaction['created_at'] as String?;
              final bool isIncome = type == 'income';
              final Color amountColor =
                  isIncome ? Colors.greenAccent : Colors.redAccent;

              // Format date
              String formattedDate = 'Date unknown';
              if (createdAtString != null) {
                try {
                  final dateTime = DateTime.parse(createdAtString).toLocal();
                  // Example format: Apr 12, 2024 10:30 PM
                  formattedDate =
                      DateFormat('MMM d, yyyy h:mm a').format(dateTime);
                } catch (e) {
                  print("Error parsing date: $e");
                }
              }

              return Container(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withOpacity(0.05),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    isIncome
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: amountColor,
                  ),
                  title: Text(
                    // Show description or fallback text
                    description.isNotEmpty
                        ? description
                        : (isIncome ? 'Income' : 'Expense'),
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    formattedDate, // Show formatted date
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  trailing: Text(
                    currencyFormatter.format(amount),
                    style: TextStyle(
                      color: amountColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
