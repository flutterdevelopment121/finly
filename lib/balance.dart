import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// Model for Category data
class Category {
  final String id; // Assuming UUID from Supabase
  final String name;

  Category({required this.id, required this.name});

  // Optional: Factory constructor for easy parsing from Supabase response
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }
}

class BalancePage extends StatefulWidget {
  final String cardName;
  final double balance;
  final dynamic cardId;
  final VoidCallback onHomePageRefreshNeeded;

  BalancePage(
      {required this.cardName,
      required this.balance,
      required this.cardId,
      required this.onHomePageRefreshNeeded});

  @override
  _BalancePageState createState() => _BalancePageState();
}

class _BalancePageState extends State<BalancePage> {
  final supabase = Supabase.instance.client;
  bool isIncome = true;
  double updatedBalance = 0.0;

  double _cardTotalIncome = 0.0;
  double _cardTotalExpense = 0.0;
  bool _isTotalsLoading = true;

  // --- State for Categories ---
  List<Category> _categories = [];
  bool _isCategoriesLoading = true;
  // --- End State for Categories ---

  // Key to refresh FutureBuilder
  UniqueKey _futureBuilderKey = UniqueKey();

  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    updatedBalance = widget.balance;
    _fetchCardTotals();
    _fetchCategories(); // Fetch categories when the page loads
  }

  Future<void> _fetchCardTotals() async {
    if (!mounted) return;
    setState(() {
      _isTotalsLoading = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final response = await supabase
          .from('transactions')
          .select('amount, type')
          .eq('user_id', user.id)
          .eq('card_id', widget.cardId);

      double income = 0.0;
      double expense = 0.0;

      for (var transaction in response) {
        final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
        final type = transaction['type'] as String?;

        if (type == 'income') {
          income += amount;
        } else if (type == 'expense') {
          expense += amount;
        }
      }

      if (mounted) {
        setState(() {
          _cardTotalIncome = income;
          _cardTotalExpense = expense;
          _isTotalsLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching card totals: $e");
      if (mounted) {
        setState(() {
          _isTotalsLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error fetching card summary: ${e.toString()}')),
        );
      }
    }
  }

  // --- New Function to Fetch Categories ---
  Future<void> _fetchCategories() async {
    if (!mounted) return;
    setState(() {
      _isCategoriesLoading = true;
    });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final response = await supabase
          .from('categories')
          .select('id, name') // Select ID and name
          .eq('user_id', user.id)
          .order('name', ascending: true); // Order alphabetically

      if (mounted) {
        setState(() {
          // Parse the response into Category objects
          _categories = response.map((map) => Category.fromMap(map)).toList();
          _isCategoriesLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching categories: $e");
      if (mounted) {
        setState(() {
          _isCategoriesLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching categories: ${e.toString()}')),
        );
      }
    }
  }
  // --- End New Function ---

  void toggleView(bool incomeSelected) {
    setState(() {
      isIncome = incomeSelected;
      _futureBuilderKey =
          UniqueKey(); // Change key to force FutureBuilder rebuild
    });
  }

  // --- Modified showAddTransactionDialog ---
  void showAddTransactionDialog() {
    TextEditingController amountController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    // Removed categoryController
    final formKey = GlobalKey<FormState>();
    String? _selectedCategoryId; // To hold the selected category ID

    // --- Add Category Dialog ---
    void showAddCategoryDialog(StateSetter setDialogStateParent) {
      TextEditingController newCategoryController = TextEditingController();
      final categoryFormKey = GlobalKey<FormState>();
      bool isAddingCategory = false;

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setCategoryDialogState) {
            // --- Apply transparent styling using Dialog -> ClipRRect -> BackdropFilter -> AlertDialog ---
            return Dialog(
              backgroundColor:
                  Colors.transparent, // Make outer Dialog transparent
              // Ensure the Dialog itself doesn't add excessive padding
              insetPadding:
                  EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  // Directly use AlertDialog inside BackdropFilter
                  child: AlertDialog(
                    // Apply background and shape directly to AlertDialog
                    backgroundColor: Colors.white.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(
                          color:
                              Colors.white.withOpacity(0.3)), // Add border here
                    ),
                    elevation: 0, // Remove shadow
                    // Adjust padding within AlertDialog
                    titlePadding: EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0.0),
                    contentPadding: EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
                    actionsPadding: EdgeInsets.fromLTRB(0.0, 8.0, 8.0, 8.0),
                    title: Text('Add New Category',
                        style: TextStyle(color: Colors.white)),
                    content: Form(
                      // Content is just the Form, which should allow shrinking
                      key: categoryFormKey,
                      child: TextFormField(
                        controller: newCategoryController,
                        style: TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          labelText: 'Category Name',
                          labelStyle: TextStyle(color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54)),
                          focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white)),
                          errorBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.redAccent)),
                          focusedErrorBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: Colors.redAccent, width: 2)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a category name';
                          }
                          // Check if category name already exists (case-insensitive)
                          if (_categories.any((cat) =>
                              cat.name.toLowerCase() ==
                              value.trim().toLowerCase())) {
                            return 'Category already exists';
                          }
                          return null;
                        },
                      ),
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: isAddingCategory
                            ? null
                            : () => Navigator.pop(context),
                        child: Text('Cancel',
                            style: TextStyle(
                                color: isAddingCategory
                                    ? Colors.grey
                                    : Colors.white)),
                      ),
                      ElevatedButton(
                        // --- Keep transparent style for Add button ---
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.transparent, // Make button transparent
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            side: BorderSide(
                                color: Colors.blueAccent) // Add border
                            ),
                        onPressed: isAddingCategory
                            ? null
                            : () async {
                                if (categoryFormKey.currentState!.validate()) {
                                  setCategoryDialogState(
                                      () => isAddingCategory = true);
                                  try {
                                    final user = supabase.auth.currentUser;
                                    if (user == null)
                                      throw Exception("User not logged in");
                                    final newCategoryName =
                                        newCategoryController.text.trim();

                                    // Insert into Supabase
                                    final response = await supabase
                                        .from('categories')
                                        .insert({
                                          'user_id': user.id,
                                          'name': newCategoryName
                                        })
                                        .select(
                                            'id, name') // Select the newly created category
                                        .single(); // Expecting a single row back

                                    if (mounted) {
                                      // Add the new category locally and update the parent dialog state
                                      final newCategory =
                                          Category.fromMap(response);
                                      setDialogStateParent(() {
                                        _categories.add(newCategory);
                                        _categories.sort((a, b) => a.name
                                            .compareTo(b.name)); // Keep sorted
                                        _selectedCategoryId = newCategory
                                            .id; // Auto-select the new category
                                      });
                                      Navigator.pop(
                                          context); // Close the add category dialog
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Category "${newCategory.name}" added'),
                                            backgroundColor: Colors.green),
                                      );
                                    }
                                  } catch (e) {
                                    print("Error adding category: $e");
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Error adding category: ${e.toString()}')),
                                      );
                                    }
                                  } finally {
                                    // Check if dialog is still mounted before setting state
                                    if (Navigator.of(context).canPop()) {
                                      setCategoryDialogState(
                                          () => isAddingCategory = false);
                                    }
                                  }
                                }
                              },
                        child: isAddingCategory
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                            : Text('Add'),
                      ),
                    ],
                  ),
                ),
              ),
            );
            // --- End Wrap ---
          });
        },
      );
    }
    // --- End Add Category Dialog ---

    // --- Main Transaction Dialog ---
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing while adding transaction
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          // --- State for Add button loading ---
          bool isAddingTransaction = false;

          return Dialog(
            backgroundColor: Colors.transparent, // Already transparent
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Add ${isIncome ? 'Income' : 'Expense'}",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 15),
                        TextFormField(
                          controller: amountController,
                          decoration: InputDecoration(
                            labelText: "Amount",
                            labelStyle: TextStyle(color: Colors.white70),
                            prefixText: '₹ ',
                            prefixStyle: TextStyle(color: Colors.white),
                            enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54)),
                            focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white)),
                            errorBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.redAccent)),
                            focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.redAccent, width: 2)),
                          ),
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: Colors.white),
                          cursorColor: Colors.white,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an amount';
                            }
                            if (double.tryParse(value) == null ||
                                double.parse(value) <= 0) {
                              return 'Please enter a valid positive amount';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 10),

                        // --- Category Dropdown ---
                        _isCategoriesLoading
                            ? Center(
                                child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(
                                        color: Colors.white)))
                            : DropdownButtonFormField<String>(
                                value: _selectedCategoryId,
                                items: [
                                  // Add a special item to trigger adding a new category
                                  DropdownMenuItem<String>(
                                    value: 'add_new_category', // Special value
                                    child: Row(
                                      children: [
                                        Icon(Icons.add_circle_outline,
                                            color: Colors.white,
                                            size: 20), // Changed Icon color
                                        SizedBox(width: 8),
                                        Text('Add New Category...',
                                            style: TextStyle(
                                                color: Colors
                                                    .white)), // Changed Text color
                                      ],
                                    ),
                                  ),
                                  // Map existing categories
                                  ..._categories.map((Category category) {
                                    return DropdownMenuItem<String>(
                                      value: category.id,
                                      child: Text(category.name,
                                          style: TextStyle(
                                              color: Colors
                                                  .white)), // Ensure item text is white
                                    );
                                  }).toList(),
                                ],
                                onChanged: (String? newValue) {
                                  if (newValue == 'add_new_category') {
                                    // Show the add category dialog
                                    // Pass setDialogState so the dropdown can be updated after adding
                                    showAddCategoryDialog(setDialogState);
                                  } else {
                                    setDialogState(() {
                                      _selectedCategoryId = newValue;
                                    });
                                  }
                                },
                                hint: Text("Select Category",
                                    style: TextStyle(color: Colors.white70)),
                                // --- Change dropdown menu background color ---
                                dropdownColor: Colors.black.withOpacity(
                                    0.8), // Dark semi-transparent background
                                iconEnabledColor:
                                    Colors.white, // Make dropdown arrow white
                                style: TextStyle(
                                    color: Colors
                                        .white), // Text color of selected item shown in button
                                decoration: InputDecoration(
                                  enabledBorder: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.white54)),
                                  focusedBorder: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.white)),
                                  errorBorder: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.redAccent)),
                                  focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color: Colors.redAccent, width: 2)),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 16), // Adjust padding
                                ),
                                validator: (value) {
                                  if (value == null ||
                                      value == 'add_new_category') {
                                    return 'Please select a category';
                                  }
                                  return null;
                                },
                                isExpanded:
                                    true, // Make dropdown take full width
                              ),
                        // --- End Category Dropdown ---

                        SizedBox(height: 10),
                        TextFormField(
                          controller: descriptionController,
                          decoration: InputDecoration(
                            labelText: "Description (Optional)",
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54)),
                            focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white)),
                          ),
                          style: TextStyle(color: Colors.white),
                          cursorColor: Colors.white,
                        ),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              // --- Disable Cancel button while adding ---
                              onPressed: isAddingTransaction
                                  ? null
                                  : () => Navigator.pop(context),
                              child: Text("Cancel",
                                  style: TextStyle(
                                      color: isAddingTransaction
                                          ? Colors.grey
                                          : Colors.white)),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isIncome
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                                foregroundColor: Colors.black,
                                minimumSize: Size(80, 36),
                              ),
                              // --- Disable Add button while adding ---
                              onPressed: isAddingTransaction
                                  ? null
                                  : () async {
                                      if (formKey.currentState!.validate()) {
                                        // Ensure a category ID is selected
                                        if (_selectedCategoryId == null ||
                                            _selectedCategoryId ==
                                                'add_new_category') {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    'Please select a valid category.')),
                                          );
                                          return;
                                        }

                                        // --- Set loading state ---
                                        setDialogState(
                                            () => isAddingTransaction = true);
                                        double amount =
                                            double.parse(amountController.text);
                                        try {
                                          // Pass categoryId instead of name
                                          await addTransaction(
                                            amount,
                                            _selectedCategoryId!, // Use the selected ID
                                            descriptionController.text.trim(),
                                          );
                                          if (mounted)
                                            Navigator.pop(
                                                context); // Close on success
                                        } catch (e) {
                                          // Error handled in addTransaction
                                        } finally {
                                          // --- Reset loading state ---
                                          if (Navigator.of(context).canPop()) {
                                            setDialogState(() =>
                                                isAddingTransaction = false);
                                          }
                                        }
                                      }
                                    },
                              // --- Show loader or text ---
                              child: isAddingTransaction
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.black))
                                  : Text("Add"),
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
        });
      },
    );
  }
  // --- End Modified showAddTransactionDialog ---

  // --- Modified addTransaction ---
  Future<void> addTransaction(
      double amount, String categoryId, String description) async {
    // Changed category to categoryId
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      double newBalance =
          isIncome ? updatedBalance + amount : updatedBalance - amount;

      // --- Perform updates sequentially ---
      // 1. Update card balance
      await supabase
          .from('cards')
          .update({'balance': newBalance})
          .eq('id', widget.cardId)
          .eq('user_id', user.id);

      // 2. Insert transaction record
      await supabase.from('transactions').insert({
        'user_id': user.id,
        'card_id': widget.cardId,
        'amount': amount,
        'category_id': categoryId, // Use the category ID
        'description': description,
        // 'created_at': DateTime.now().toIso8601String(), // Let Supabase handle timestamp
        'type': isIncome ? 'income' : 'expense'
      });
      // --- End sequential updates ---

      if (mounted) {
        setState(() {
          updatedBalance = newBalance;
          _futureBuilderKey = UniqueKey(); // Force rebuild of transaction list
        });

        _fetchCardTotals(); // Refresh totals on card

        widget.onHomePageRefreshNeeded(); // Refresh home page list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error adding transaction: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding transaction: ${e.toString()}')),
        );
      }
      throw e; // Re-throw error for the dialog's catch block
    }
  }
  // --- End Modified addTransaction ---

  // --- Modified fetchTransactions ---
  Future<List<Map<String, dynamic>>> fetchTransactions() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    // Fetch transactions and join with categories table to get the name
    // --- Select transaction id ---
    final List<dynamic> response = await supabase
        .from('transactions')
        // Select transaction id, other columns, AND the name from the related category
        .select('id, amount, description, type, created_at, categories(name)')
        .eq('user_id', user.id)
        .eq('card_id', widget.cardId)
        .eq('type', isIncome ? 'income' : 'expense')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
  // --- End Modified fetchTransactions ---

  // --- Function to Delete Transaction ---
  Future<void> _deleteTransaction(
      String transactionId, double amount, String type) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      // Calculate the balance adjustment needed
      double balanceChange = (type == 'income')
          ? -amount
          : amount; // Reverse the transaction amount
      double newBalance = updatedBalance + balanceChange;

      // --- Perform updates sequentially ---
      // 1. Update card balance FIRST
      await supabase
          .from('cards')
          .update({'balance': newBalance})
          .eq('id', widget.cardId)
          .eq('user_id', user.id);

      // 2. Delete the transaction record
      await supabase
          .from('transactions')
          .delete()
          .eq('id', transactionId)
          .eq('user_id', user.id); // Ensure user owns the transaction
      // --- End sequential updates ---

      if (mounted) {
        setState(() {
          updatedBalance = newBalance;
          _futureBuilderKey = UniqueKey(); // Force rebuild of transaction list
        });
        _fetchCardTotals(); // Refresh totals on card
        widget.onHomePageRefreshNeeded(); // Refresh home page list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error deleting transaction: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error deleting transaction: ${e.toString()}')),
        );
      }
      // Optionally re-throw if needed elsewhere
      //throw e;
    }
  }

  // --- End Function to Delete Transaction ---
  // --- Dialog for Deleting Transaction Confirmation ---
  void _showDeleteTransactionConfirmationDialog(
      String transactionId, double amount, String type, String description) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // Capture the dialog's context here
        // --- Apply transparent styling using custom Container ---
        return Dialog(
          backgroundColor: Colors.transparent, // Outer dialog transparent
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
          child: ClipRRect(
            // Clip the blurred container
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                // Custom container for dialog appearance
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), // Background color
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3)), // Border
                ),
                child: Column(
                  // Layout content vertically
                  mainAxisSize: MainAxisSize.min, // Shrink wrap content
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 12.0),
                      child: Text(
                        'Delete Transaction?',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 20.0),
                      child: Text(
                          'Are you sure you want to delete this transaction?\n"${description.isNotEmpty ? description : (type == 'income' ? 'Income' : 'Expense')}: ${currencyFormatter.format(amount)}"',
                          style: TextStyle(color: Colors.white70)),
                    ),
                    // Actions
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          8.0, 0.0, 8.0, 8.0), // Padding for actions row
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            child: Text('Cancel',
                                style: TextStyle(color: Colors.white)),
                            onPressed: () {
                              // Use the captured dialogContext to pop
                              Navigator.of(dialogContext).pop();
                            },
                          ),
                          SizedBox(width: 8), // Spacing between buttons
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.redAccent, // Destructive action color
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Delete'),
                            onPressed: () async {
                              // Pop the confirmation dialog FIRST using its own context
                              Navigator.of(dialogContext).pop();

                              // Show temporary feedback
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Deleting transaction...'),
                                      duration: Duration(seconds: 2)),
                                );
                              }

                              // Call the delete function
                              try {
                                await _deleteTransaction(
                                    transactionId, amount, type);
                              } catch (e) {
                                // Error is already handled and shown by _deleteTransaction
                                print(
                                    "Error during delete process (already shown to user): $e");
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        // --- End transparent styling ---
      },
    );
  }
  // --- End Dialog for Deleting Transaction Confirmation ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: Text(
          widget.cardName,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // --- Card Display Area (No changes needed here) ---
          Container(
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.white.withOpacity(0.1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Current Balance",
                          style:
                              TextStyle(fontSize: 16, color: Colors.white70)),
                      SizedBox(height: 8),
                      Text(currencyFormatter.format(updatedBalance),
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      SizedBox(height: 25),
                      _isTotalsLoading
                          ? Center(
                              child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white54)),
                            ))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Income",
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70)),
                                    SizedBox(height: 2),
                                    Text(
                                        currencyFormatter
                                            .format(_cardTotalIncome),
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.greenAccent)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("Expense",
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70)),
                                    SizedBox(height: 2),
                                    Text(
                                        currencyFormatter
                                            .format(_cardTotalExpense),
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.redAccent)),
                                  ],
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // --- Income/Expense Toggle (No changes needed here) ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildToggleChip("Income", true),
              _buildToggleChip("Expense", false),
            ],
          ),
          SizedBox(height: 10),
          // --- Transaction List (Modified) ---
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              // --- Use key to force rebuild ---
              key: _futureBuilderKey,
              future: fetchTransactions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(color: Colors.white));
                } else if (snapshot.hasError) {
                  return Center(
                      child: Text(
                          "Error loading transactions: ${snapshot.error}",
                          style: TextStyle(color: Colors.redAccent)));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                      child: Text(
                    "No ${isIncome ? 'income' : 'expense'} transactions found",
                    style: TextStyle(color: Colors.white70),
                  ));
                }

                final transactions = snapshot.data!;
                return ListView.builder(
                  padding: EdgeInsets.only(bottom: 80),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    // --- Extract transaction details ---
                    final transactionIdRaw = transaction['id']; // Get ID
                    final transactionId = transactionIdRaw.toString();

                    final amount =
                        (transaction['amount'] as num?)?.toDouble() ?? 0.0;
                    final description =
                        transaction['description'] as String? ?? '';
                    final type = transaction['type'] as String? ??
                        (isIncome
                            ? 'income'
                            : 'expense'); // Ensure type is available
                    final createdAtString =
                        transaction['created_at'] as String?;
                    final bool isTxIncome =
                        type == 'income'; // Use specific type from transaction
                    final Color amountColor =
                        isTxIncome ? Colors.greenAccent : Colors.redAccent;

                    final categoryData =
                        transaction['categories'] as Map<String, dynamic>?;
                    final categoryName =
                        categoryData?['name'] as String? ?? 'Uncategorized';

                    // Format date
                    String formattedDate = 'Date unknown';
                    if (createdAtString != null) {
                      try {
                        final dateTime =
                            DateTime.parse(createdAtString).toLocal();
                        formattedDate =
                            DateFormat('MMM d, yyyy h:mm a').format(dateTime);
                      } catch (e) {/* Handle error if needed */}
                    }
                    // --- End Extract ---

                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white.withOpacity(0.05),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          isTxIncome
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          color: amountColor,
                        ),
                        title: Text(
                          // Show description or category as title
                          description.isNotEmpty ? description : categoryName,
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // --- Show date in subtitle ---
                        subtitle: Text(
                          formattedDate, // Show formatted date
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        // --- Modified Trailing for Amount + Delete Button ---
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min, // Keep row compact
                          children: [
                            Text(
                              currencyFormatter.format(amount),
                              style: TextStyle(
                                color: amountColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(width: 8), // Spacing
                            IconButton(
                              icon: Icon(Icons.close,
                                  color: Colors.red, size: 18), // Delete icon
                              padding:
                                  EdgeInsets.zero, // Remove default padding
                              constraints:
                                  BoxConstraints(), // Remove default constraints
                              tooltip: 'Delete Transaction',
                              onPressed: () {
                                // --- Show confirmation before deleting ---
                                _showDeleteTransactionConfirmationDialog(
                                    transactionId,
                                    amount,
                                    type,
                                    description.isNotEmpty
                                        ? description
                                        : categoryName // Pass description/category for dialog
                                    );
                              },
                            ),
                          ],
                        ),
                        // --- End Modified Trailing ---
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // --- Floating Action Button (No changes needed here) ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddTransactionDialog,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: StadiumBorder(
          side: BorderSide(
            color: Colors.white.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        icon: Icon(Icons.add),
        label: Text("Add Transaction"),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --- _buildToggleChip (No changes needed here) ---
  Widget _buildToggleChip(String label, bool isSelectedType) {
    bool isActive = isIncome == isSelectedType;
    Color activeColor = isSelectedType ? Colors.greenAccent : Colors.redAccent;

    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: (_) => toggleView(isSelectedType),
      backgroundColor: Colors.black.withOpacity(.9),
      selectedColor: Colors.grey.shade700.withOpacity(0.5),
      labelStyle: TextStyle(
          color: isActive ? activeColor : Colors.white70,
          fontWeight: FontWeight.bold),
      shape: StadiumBorder(
          side: BorderSide(
              color: isActive ? activeColor : Colors.white.withOpacity(0.2),
              width: 1.5)),
      elevation: 0,
      pressElevation: 0,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
    );
  }
}
