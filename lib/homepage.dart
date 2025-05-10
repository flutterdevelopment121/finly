import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'balance.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> cards = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCards();
  }

  Future<void> fetchCards() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          // Navigate to login if user is null
          Navigator.pushReplacementNamed(context, '/');
          // Ensure isLoading is reset if we return early or navigate away
          setState(() => isLoading = false);
        }
        return;
      }
      final response = await supabase
          .from('cards')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      // Check mounted again before setState, as async gap might unmount
      if (mounted) {
        setState(() {
          cards = response
              .map((card) => {
                    'id': card['id'],
                    'name': card['name'] as String,
                    'balance': (card['balance'] as num).toDouble(),
                  })
              .toList();
          // isLoading will be set to false in the finally block
        });
      }
    } catch (error) {
      print("Error fetching cards: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching cards: ${error.toString()}")),
        );
        // isLoading will be set to false in the finally block
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _buildDashboard() {
    if (isLoading) {
      return Center(
          child: CircularProgressIndicator(
        color: Colors.white,
      ));
    }
    if (cards.isEmpty) {
      return Center(
        child: Text(
          // More user-friendly message
          "No cards found.\nAdd one using the + button below!",
          style: TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: fetchCards, // Call fetchCards when pulled down
      color: Colors.white, // Color of the refresh indicator
      backgroundColor: Colors.grey.shade800, // Background of the indicator
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: cards.length,
          // Ensure ListView can always be scrolled to enable RefreshIndicator
          physics: const AlwaysScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final card = cards[index];
            final cardId = card['id'];
          final cardName = card['name'] as String; // Ensure type
          final cardBalance = (card['balance'] as num).toDouble(); // Ensure type
          return InkWell(
            onTap: () async {
              // Navigate and refresh on return
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BalancePage(
                    cardName: cardName,
                    balance: cardBalance,
                    cardId: cardId,
                    // Pass the fetchCards method correctly
                    onHomePageRefreshNeeded: fetchCards,
                  ),
                ),
              );
              // Always refresh cards when returning from BalancePage.
              fetchCards();
            },
            onLongPress: () {
              _showCardOptionsDialog(cardId, cardName);
            },
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 10),
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
                    padding: EdgeInsets.all(16),
                    // Remove fixed height, let content define it
                    constraints:
                        BoxConstraints(minHeight: 150), // Use minHeight
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          cardName,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "₹${cardBalance.toStringAsFixed(2)}",
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        ),
      ),
    );
  }

  // --- Dialog for Edit/Delete Options ---
  void _showCardOptionsDialog(dynamic cardId, String currentName) {
    showDialog(
      context: context,
      // Make the underlying barrier transparent if needed, or keep default dimming
      //barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        // --- Apply transparent styling using a custom Container ---
        return Dialog(
          backgroundColor:
              Colors.transparent, // Ensure outer dialog is transparent
          elevation: 0, // No shadow on the dialog itself
          insetPadding: EdgeInsets.symmetric(
              horizontal: 40.0,
              vertical: 24.0), // Control spacing around the dialog
          child: ClipRRect(
            // Clip the blurred container to rounded corners
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                // Custom container instead of AlertDialog
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(
                      0.2), // Background color for the content area
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3)), // Border
                ),
                child: Column(
                  // Use Column for layout
                  mainAxisSize:
                      MainAxisSize.min, // Size the container to fit the content
                  crossAxisAlignment: CrossAxisAlignment
                      .stretch, // Stretch children horizontally
                  children: [
                    // Title Section (Mimicking AlertDialog title style)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          24.0, 20.0, 24.0, 16.0), // Adjusted padding
                      child: Text(
                        'Card Options',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white), // Use theme for consistency
                        textAlign: TextAlign.start,
                      ),
                    ),
                    // Content Section (ListTiles)
                    // Use InkWell for tap effects if needed, or keep ListTile directly
                    ListTile(
                      leading: Icon(Icons.edit, color: Colors.blueAccent),
                      title: Text('Edit Name',
                          style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(context); // Close this dialog first
                        _showEditCardNameDialog(cardId, currentName);
                      },
                    ),
                    Divider(
                        color: Colors.white.withOpacity(0.2),
                        height: 1,
                        indent: 16,
                        endIndent: 16), // Optional divider
                    ListTile(
                      leading: Icon(Icons.delete, color: Colors.redAccent),
                      title: Text('Delete Card',
                          style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(context); // Close this dialog first
                        _showDeleteConfirmationDialog(cardId, currentName);
                      },
                    ),
                    // Add padding at the bottom if needed
                    SizedBox(height: 16),
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

  void _showEditCardNameDialog(dynamic cardId, String currentName) {
    TextEditingController nameController =
        TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>(); // For validation

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(// To manage button loading state
            builder: (context, setDialogState) {
          bool isUpdating = false;

          return AlertDialog(
            backgroundColor: Colors.grey.shade800,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title:
                Text('Edit Card Name', style: TextStyle(color: Colors.white)),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: nameController,
                style: TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  labelText: 'New Card Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white54),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a card name';
                  }
                  if (value.trim() == currentName) {
                    return 'Please enter a different name';
                  }
                  return null;
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: isUpdating ? null : () => Navigator.pop(context),
                child: Text('Cancel',
                    style: TextStyle(
                        color: isUpdating ? Colors.grey : Colors.white)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  minimumSize: Size(80, 36),
                ),
                onPressed: isUpdating
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          final newName = nameController.text.trim();
                          setDialogState(() => isUpdating = true);
                          try {
                            await _updateCardName(cardId, newName);
                            if (mounted)
                              Navigator.pop(context); // Close dialog on success
                          } catch (e) {
                            // Error handled in _updateCardName
                          } finally {
                            // Check mounted state for the dialog before setting state
                            // This uses the 'context' captured by the builder
                            if (Navigator.of(context).canPop()) {
                              setDialogState(() => isUpdating = false);
                            }
                          }
                        }
                      },
                child: isUpdating
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Text('Update'),
              ),
            ],
          );
        });
      },
    );
  }

  // --- Function to Update Card Name in Supabase ---
  Future<void> _updateCardName(dynamic cardId, String newName) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in.");

      await supabase
          .from('cards')
          .update({'name': newName})
          .eq('id', cardId) // Match the card ID
          .eq('user_id', user.id); // Ensure user owns the card

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Card name updated successfully!'),
              backgroundColor: Colors.green),
        );
        fetchCards(); // Refresh the list
      }
    } catch (e) {
      print("Error updating card name: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating card name: ${e.toString()}')),
        );
      }
      throw e; // Re-throw to be caught by dialog
    }
  }

  void _showDeleteConfirmationDialog(dynamic cardId, String cardName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade800,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Delete Card?', style: TextStyle(color: Colors.white)),
          content: Text(
              'Are you sure you want to delete the card "$cardName"?\nThis action cannot be undone.',
              style: TextStyle(color: Colors.white70)),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop(); // Close the confirmation dialog
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, // Destructive action color
                foregroundColor: Colors.white,
              ),
              child: Text('Delete'),
              onPressed: () async {
                Navigator.of(context)
                    .pop(); // Close the confirmation dialog first
                try {
                  await _deleteCard(cardId);
                } catch (e) {
                  // Error is shown via SnackBar in _deleteCard
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- Function to Delete Card from Supabase ---
  Future<void> _deleteCard(dynamic cardId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in.");

      // Delete associated transactions first (important!)
      await supabase
          .from('transactions')
          .delete()
          .eq('card_id', cardId)
          .eq('user_id', user.id); // Ensure user owns transactions

      // Then delete the card
      await supabase
          .from('cards')
          .delete()
          .eq('id', cardId) // Match the card ID
          .eq('user_id', user.id); // Ensure user owns the card

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Card and associated transactions deleted successfully!'),
              backgroundColor: Colors.green),
        );
        fetchCards(); // Refresh the list
      }
    } catch (e) {
      print("Error deleting card: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting card: ${e.toString()}')),
        );
      }
      throw e; // Re-throw error if needed elsewhere
    }
  }

  void showAddCardDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController balanceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        // Use StatefulBuilder to manage state within the dialog
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isAdding =
                false; // State variable for the button loading state

            return Dialog(
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: EdgeInsets.all(20), // Increased padding slightly
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          // Added a title to the dialog
                          "Add New Card",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: "Card Name",
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          style: TextStyle(color: Colors.white),
                          cursorColor: Colors.white,
                        ),
                        SizedBox(height: 15),
                        TextField(
                          controller: balanceController,
                          decoration: InputDecoration(
                            labelText: "Initial Balance",
                            labelStyle: TextStyle(color: Colors.white70),
                            prefixText: '₹ ',
                            prefixStyle: TextStyle(color: Colors.white),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: Colors.white),
                          cursorColor: Colors.white,
                        ),
                        SizedBox(height: 25),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Cancel button - disable while adding
                            TextButton(
                              onPressed: isAdding
                                  ? null
                                  : () => Navigator.pop(context),
                              child: Text("Cancel",
                                  style: TextStyle(
                                      color: isAdding
                                          ? Colors.grey
                                          : Colors.white)),
                            ),
                            SizedBox(width: 10),
                            // Add button - shows loading indicator
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                foregroundColor: Colors.black,
                                // Minimum size to accommodate loader
                                minimumSize: Size(80, 36),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              // Disable button while adding by setting onPressed to null
                              onPressed: isAdding
                                  ? null
                                  : () async {
                                      // Basic Validation
                                      final name = nameController.text.trim();
                                      final balanceStr =
                                          balanceController.text.trim();
                                      if (name.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  "Please enter a card name.")),
                                        );
                                        return;
                                      }
                                      if (balanceStr.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  "Please enter an initial balance.")),
                                        );
                                        return;
                                      }
                                      double? balance =
                                          double.tryParse(balanceStr);
                                      if (balance == null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  "Please enter a valid balance number.")),
                                        );
                                        return;
                                      }

                                      // Set loading state for the button
                                      setDialogState(() {
                                        isAdding = true;
                                      });

                                      try {
                                        await addNewCard(name, balance);
                                        // Close dialog ONLY on success
                                        if (mounted) Navigator.pop(context);
                                      } catch (e) {
                                        // Error is handled in addNewCard
                                        print("Error caught in dialog: $e");
                                      } finally {
                                        // Ensure loading state is always reset
                                        // Check if the dialog state is still valid
                                        if (Navigator.of(context).canPop()) {
                                          setDialogState(() {
                                            isAdding = false;
                                          });
                                        }
                                      }
                                    },
                              // Show loader or text based on isAdding state
                              child: isAdding
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.black,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text("Add"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> addNewCard(String name, double balance) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception("User not logged in."); // Throw error if user is null
      }
      await supabase.from('cards').insert({
        'name': name,
        'balance': balance,
        'user_id': user.id,
        // 'created_at' is handled by Supabase default value or trigger
      });
      // Refresh the main list after successful insertion
      fetchCards();
    } catch (e) {
      print("Error adding card: $e");
      // Show error message to the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding card: ${e.toString()}')),
        );
      }
      // Re-throw the error so the dialog's catch block knows it failed
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("FINLY",
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout', // Add tooltip
            onPressed: () async {
              await supabase.auth.signOut();
              // Ensure context is valid before navigating
              if (mounted) {
                Navigator.pushReplacementNamed(
                    context, '/'); // Go to login/splash
              }
            },
          )
        ],
      ),
      backgroundColor: Colors.grey.shade900,
      body: _buildDashboard(),
      // --- Updated Floating Action Buttons ---
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end, // Align buttons to the end
        children: [
          // Profile Button
          FloatingActionButton(
            heroTag: 'profileButton', // Add unique heroTag
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
            backgroundColor: Colors.white.withOpacity(0.3),
            tooltip: 'Profile', // Add tooltip
            child: Icon(Icons.person, color: Colors.white),
          ),
          SizedBox(width: 10), // Spacing

          // --- New Calendar Button --- Added ---
          FloatingActionButton(
            heroTag: 'calendarButton', // Unique heroTag
            onPressed: () {
              // TODO: Make sure '/calendar' route is defined in main.dart
              Navigator.pushNamed(context, '/calendar');
            },
            backgroundColor: Colors.white.withOpacity(0.3), // Same style
            tooltip: 'Calendar View', // Add tooltip
            child: Icon(Icons.calendar_month_outlined,
                color: Colors.white), // Calendar icon
          ),
          SizedBox(width: 10), // Spacing
          // --- End New Calendar Button ---

          // --- New Daily Allowance Button ---
          FloatingActionButton(
            heroTag: 'dailyAllowanceButton', // Unique heroTag
            onPressed: () {
              // Navigate to the new page (route name to be defined)
              Navigator.pushNamed(context, '/daily_allowance');
            },
            backgroundColor: Colors.white.withOpacity(0.3), // Same style
            tooltip: 'Daily Allowance', // Add tooltip
            child: Icon(Icons.calculate_outlined,
                color: Colors.white), // Example icon
          ),
          SizedBox(width: 10), // Spacing
          // --- End New Button ---
          // --- Set Goals Button ---
          FloatingActionButton(
            heroTag: 'setGoalsButton', // Unique heroTag for Set Goals
            onPressed: () {
              // Navigate to the Set Goals page (define this route in your main.dart)
              Navigator.pushNamed(context, '/set_goals');
            },
            backgroundColor:
                Colors.white.withOpacity(0.3), // Keep the style consistent
            tooltip: 'Set Goals', // Updated tooltip
            child: Icon(Icons.flag_outlined, // Icon representing goals
                color: Colors.white),
          ),
          SizedBox(width: 10), // Spacing

          // Category Spending Button (New)
          FloatingActionButton(
            heroTag: 'categorySpendingButton', // Add unique heroTag
            onPressed: () {
              Navigator.pushNamed(context, '/category_spending');
            },
            backgroundColor: Colors.white.withOpacity(0.3), // Same style
            tooltip: 'Category Spending', // Add tooltip
            child: Icon(Icons.pie_chart_outline,
                color: Colors.white), // Example icon
          ),
          SizedBox(width: 10), // Spacing

          // Add Card Button
          FloatingActionButton(
            heroTag: 'addCardButton', // Add unique heroTag
            onPressed: showAddCardDialog,
            backgroundColor: Colors.white.withOpacity(0.3), // Same style
            tooltip: 'Add New Card', // Add tooltip
            child: Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
