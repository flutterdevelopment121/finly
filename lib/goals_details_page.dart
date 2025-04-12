import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui'; // For BackdropFilter
import 'package:intl/intl.dart'; // For date formatting

// Convert to StatefulWidget
class GoalDetailsPage extends StatefulWidget {
  final Map<String, dynamic> initialGoalData; // Receive the initial goal data

  const GoalDetailsPage({Key? key, required this.initialGoalData})
      : super(key: key);

  @override
  _GoalDetailsPageState createState() => _GoalDetailsPageState();
}

class _GoalDetailsPageState extends State<GoalDetailsPage> {
  late Map<String, dynamic> goalData; // Use state variable
  final supabase = Supabase.instance.client;
  bool isLoadingContribution = false; // To disable button while processing
  bool _needsRefresh = false; // Flag to indicate if previous page needs refresh

  // --- State for Contribution History ---
  List<Map<String, dynamic>> contributions = [];
  bool isLoadingHistory = true;
  String? historyErrorMessage;
  // --- End State for Contribution History ---

  @override
  void initState() {
    super.initState();
    // Initialize state with the passed data
    goalData = Map<String, dynamic>.from(widget.initialGoalData);
    // Fetch contribution history when the page loads
    _fetchContributionHistory();
  }

  // --- Function to Fetch Contribution History ---
  Future<void> _fetchContributionHistory() async {
    if (!mounted) return;
    setState(() {
      isLoadingHistory = true;
      historyErrorMessage = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in.");
      final goalId = goalData['id'];
      if (goalId == null) throw Exception("Goal ID is missing.");

      final response = await supabase
          .from('goal_contributions')
          .select()
          .eq('goal_id', goalId)
          .eq('user_id', user.id) // Ensure user owns the contributions
          .order('contribution_date', ascending: false); // Show newest first

      if (mounted) {
        setState(() {
          contributions = List<Map<String, dynamic>>.from(response.map((item) {
            // Ensure numeric types are handled correctly
            final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
            // Parse the date string
            final date =
                DateTime.tryParse(item['contribution_date'] as String? ?? '');
            return {
              'id': item['id'],
              'amount': amount,
              'contribution_date': date, // Store as DateTime object
              'notes': item['notes'] as String?, // Handle optional notes
            };
          }));
          isLoadingHistory = false;
        });
      }
    } catch (e) {
      print("Error fetching contribution history: $e");
      if (mounted) {
        setState(() {
          isLoadingHistory = false;
          historyErrorMessage = "Error loading history: ${e.toString()}";
        });
      }
    }
  }
  // --- End Function to Fetch Contribution History ---

  // --- Function to show the Add Contribution Dialog ---
  void _showAddContributionDialog() {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // To manage button loading state inside dialog
          builder: (context, setDialogState) {
            bool isAdding = false;

            return Dialog(
              backgroundColor: Colors.transparent,
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
                        children: [
                          Text(
                            "Add Contribution",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 20),
                          TextFormField(
                            controller: amountController,
                            style: TextStyle(color: Colors.white),
                            cursorColor: Colors.white,
                            decoration: InputDecoration(
                              labelText: "Amount",
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
                              errorStyle: TextStyle(color: Colors.yellowAccent),
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter an amount';
                              }
                              final amount = double.tryParse(value);
                              if (amount == null || amount <= 0) {
                                return 'Please enter a valid amount greater than 0';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
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
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent,
                                  foregroundColor: Colors.black,
                                  minimumSize: Size(80, 36),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: isAdding
                                    ? null
                                    : () async {
                                        if (formKey.currentState!.validate()) {
                                          final amount = double.parse(
                                              amountController.text);
                                          setDialogState(() => isAdding = true);
                                          try {
                                            await _addContribution(amount);
                                            if (mounted)
                                              Navigator.pop(
                                                  context); // Close dialog on success
                                          } catch (e) {
                                            // Error shown via SnackBar in _addContribution
                                          } finally {
                                            // Check if dialog context is still valid
                                            if (Navigator.of(context)
                                                .canPop()) {
                                              setDialogState(
                                                  () => isAdding = false);
                                            }
                                          }
                                        }
                                      },
                                child: isAdding
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.black,
                                            strokeWidth: 2.5))
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
          },
        );
      },
    );
  }

  // --- Function to Add Contribution to Supabase ---
  Future<void> _addContribution(double amount) async {
    if (isLoadingContribution) return; // Prevent double taps

    setState(() => isLoadingContribution = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception("User not logged in.");
      }
      final goalId = goalData['id'];
      if (goalId == null) {
        throw Exception("Goal ID is missing.");
      }

      // 1. Insert into goal_contributions table
      await supabase.from('goal_contributions').insert({
        'user_id': user.id,
        'goal_id': goalId,
        'amount': amount,
        // 'contribution_date' uses default value
      });

      // 2. Update the current_amount in the goals table
      final currentAmount =
          (goalData['current_amount'] as num?)?.toDouble() ?? 0.0;
      final newAmount = currentAmount + amount;

      await supabase
          .from('goals')
          .update({'current_amount': newAmount})
          .eq('id', goalId)
          .eq('user_id', user.id); // Ensure user owns the goal

      // 3. Update local state to reflect changes immediately
      if (mounted) {
        setState(() {
          goalData['current_amount'] = newAmount;
          _needsRefresh = true; // Mark that the previous page needs refresh
        });
        // 4. Refresh the contribution history list
        _fetchContributionHistory(); // <-- Add this call
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Contribution added successfully!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("Error adding contribution: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error adding contribution: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
      // Optionally re-throw if the dialog needs to know about the error
      // throw e;
    } finally {
      if (mounted) {
        setState(() => isLoadingContribution = false);
      }
    }
  }

  // --- Function to show the Edit Goal Dialog ---
  void _showEditGoalDialog() {
    // Pre-fill controllers with current data
    final nameController = TextEditingController(text: goalData['name'] ?? '');
    final targetAmountController = TextEditingController(
        text: (goalData['target_amount'] as num?)?.toString() ?? '0');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // To manage button loading state
          builder: (context, setDialogState) {
            bool isUpdating = false;

            return Dialog(
              backgroundColor: Colors.transparent,
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
                        children: [
                          Text(
                            "Edit Goal", // Dialog Title
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 20),
                          // Name Field
                          TextFormField(
                            controller: nameController,
                            style: TextStyle(color: Colors.white),
                            cursorColor: Colors.white,
                            decoration: InputDecoration(
                              labelText: "Goal Name",
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              errorStyle: TextStyle(color: Colors.yellowAccent),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a goal name';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 15),
                          // Target Amount Field
                          TextFormField(
                            controller: targetAmountController,
                            style: TextStyle(color: Colors.white),
                            cursorColor: Colors.white,
                            decoration: InputDecoration(
                              labelText: "Target Amount",
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
                              errorStyle: TextStyle(color: Colors.yellowAccent),
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a target amount';
                              }
                              final amount = double.tryParse(value);
                              if (amount == null || amount <= 0) {
                                return 'Please enter a valid amount greater than 0';
                              }
                              // Optional: Check if target is less than current amount
                              final currentAmount =
                                  (goalData['current_amount'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                              if (amount < currentAmount) {
                                return 'Target cannot be less than the amount already saved (₹${currentAmount.toStringAsFixed(2)})';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 25),
                          // Action Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: isUpdating
                                    ? null
                                    : () => Navigator.pop(context),
                                child: Text("Cancel",
                                    style: TextStyle(
                                        color: isUpdating
                                            ? Colors.grey
                                            : Colors.white)),
                              ),
                              SizedBox(width: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent, // Update color
                                  foregroundColor: Colors.white,
                                  minimumSize: Size(80, 36),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: isUpdating
                                    ? null
                                    : () async {
                                        if (formKey.currentState!.validate()) {
                                          final newName = nameController.text.trim();
                                          final newTargetAmount = double.parse(
                                              targetAmountController.text);

                                          setDialogState(() => isUpdating = true);
                                          try {
                                            await _updateGoalDetails(
                                                newName, newTargetAmount);
                                            if (mounted)
                                              Navigator.pop(
                                                  context); // Close dialog on success
                                          } catch (e) {
                                            // Error shown via SnackBar in _updateGoalDetails
                                          } finally {
                                            if (Navigator.of(context)
                                                .canPop()) {
                                              setDialogState(
                                                  () => isUpdating = false);
                                            }
                                          }
                                        }
                                      },
                                child: isUpdating
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5))
                                    : Text("Update"), // Button Text
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
          },
        );
      },
    );
  }
  // --- End Function to show the Edit Goal Dialog ---

  // --- Function to Update Goal Details in Supabase ---
  Future<void> _updateGoalDetails(String newName, double newTargetAmount) async {
    // Use isLoadingContribution flag or create a new one if needed
    if (isLoadingContribution) return;
    setState(() => isLoadingContribution = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in.");
      final goalId = goalData['id'];
      if (goalId == null) throw Exception("Goal ID is missing.");

      // Update the goals table
      await supabase
          .from('goals')
          .update({
            'name': newName,
            'target_amount': newTargetAmount,
          })
          .eq('id', goalId)
          .eq('user_id', user.id); // Ensure user owns the goal

      // Update local state
      if (mounted) {
        setState(() {
          goalData['name'] = newName;
          goalData['target_amount'] = newTargetAmount;
          _needsRefresh = true; // Mark that the previous page needs refresh
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Goal updated successfully!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("Error updating goal: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating goal: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
      throw e; // Re-throw for the dialog's catch block
    } finally {
      if (mounted) {
        setState(() => isLoadingContribution = false);
      }
    }
  }
  // --- End Function to Update Goal Details ---


  // --- Delete Goal Logic ---
  Future<void> _deleteGoal() async {
    final goalId = goalData['id'];
    final goalName = goalData['name'] ?? 'this goal';
    if (goalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot delete: Goal ID missing.')));
      return;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Delete Goal?', style: TextStyle(color: Colors.white)),
        content: Text(
            'Are you sure you want to delete "$goalName"?\nThis will also delete all its contributions and cannot be undone.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false), // Return false on cancel
            child: Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            onPressed: () =>
                Navigator.pop(context, true), // Return true on confirm
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Proceed with deletion
      try {
        final user = supabase.auth.currentUser;
        if (user == null) throw Exception("User not logged in.");

        // Deleting the goal will cascade delete contributions due to FOREIGN KEY constraint
        await supabase
            .from('goals')
            .delete()
            .eq('id', goalId)
            .eq('user_id', user.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Goal "$goalName" deleted successfully.'),
                backgroundColor: Colors.green),
          );
          // Pop back to the previous screen, indicating success/refresh needed
          Navigator.pop(context, true);
        }
      } catch (e) {
        print("Error deleting goal: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error deleting goal: ${e.toString()}'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // --- Widget to Build Contribution History List ---
  Widget _buildContributionHistoryList() {
    if (isLoadingHistory) {
      return Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (historyErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Text(
            historyErrorMessage!,
            style: TextStyle(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (contributions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Text(
            'No contributions recorded yet.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    // Use a standard ListView.builder
    return ListView.separated(
      shrinkWrap: true, // Important inside a Column
      physics:
          NeverScrollableScrollPhysics(), // Disable scrolling within the list itself
      itemCount: contributions.length,
      itemBuilder: (context, index) {
        final contribution = contributions[index];
        final contributionId = contribution['id']; // Get the contribution ID
        final amount = contribution['amount'] as double? ?? 0.0;
        final date = contribution['contribution_date'] as DateTime?;
        // Format the date nicely, handle null case
        final formattedDate = date != null
            ? DateFormat('MMM d, yyyy - hh:mm a').format(date) // Example format
            : 'Date unknown';

        return ListTile(
          dense: true, // Make items a bit smaller
          leading: Icon(Icons.check_circle_outline,
              color: Colors.greenAccent, size: 20),
          title: Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            formattedDate,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          // --- Add Trailing Delete Button ---
          trailing: IconButton(
            icon:
                Icon(Icons.close, color: Colors.red[300], size: 20), // 'X' icon
            tooltip: 'Delete Contribution',
            // Prevent accidental multi-taps while deleting
            onPressed: isLoadingContribution
                ? null
                : () {
                    // Pass contribution ID and amount to the delete function
                    _showDeleteContributionConfirmation(contributionId, amount);
                  },
          ),
          // --- End Trailing Delete Button ---
        );
      },
      separatorBuilder: (context, index) => Divider(
        color: Colors.white12, // Subtle divider
        height: 1,
        thickness: 1,
        indent: 16, // Optional indent
        endIndent: 16,
      ),
    );
  }
  // --- End Widget to Build Contribution History List ---

  // --- Show Confirmation Dialog for Deleting Contribution ---
  Future<void> _showDeleteContributionConfirmation(
      dynamic contributionId, double amount) async {
    if (contributionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot delete: Contribution ID missing.')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title:
            Text('Delete Contribution?', style: TextStyle(color: Colors.white)),
        content: Text(
            'Are you sure you want to delete this contribution of ₹${amount.toStringAsFixed(2)}?\nThis cannot be undone.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false), // Return false on cancel
            child: Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            onPressed: () =>
                Navigator.pop(context, true), // Return true on confirm
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteContribution(contributionId, amount);
    }
  }

  // --- Function to Delete Contribution from Supabase ---
  Future<void> _deleteContribution(
      dynamic contributionId, double amount) async {
    if (isLoadingContribution) return; // Prevent overlaps

    setState(() => isLoadingContribution = true); // Use the same loading flag

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in.");
      final goalId = goalData['id'];
      if (goalId == null) throw Exception("Goal ID is missing.");

      // 1. Delete from goal_contributions table
      await supabase
          .from('goal_contributions')
          .delete()
          .eq('id', contributionId)
          .eq('user_id', user.id); // Ensure user owns the contribution

      // 2. Update (subtract from) the current_amount in the goals table
      final currentGoalAmount =
          (goalData['current_amount'] as num?)?.toDouble() ?? 0.0;
      // Ensure the amount doesn't go below zero
      final newGoalAmount =
          (currentGoalAmount - amount).clamp(0.0, double.infinity);

      await supabase
          .from('goals')
          .update({'current_amount': newGoalAmount})
          .eq('id', goalId)
          .eq('user_id', user.id); // Ensure user owns the goal

      // 3. Update local state
      if (mounted) {
        setState(() {
          goalData['current_amount'] = newGoalAmount;
          _needsRefresh = true; // Mark that the previous page needs refresh
        });
        // 4. Refresh the contribution history list
        _fetchContributionHistory();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Contribution deleted successfully!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("Error deleting contribution: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error deleting contribution: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoadingContribution = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract data from the state variable 'goalData'
    // Use late final to ensure they are initialized and final
    late final String name = goalData['name'] ?? 'N/A';
    late final double target =
        (goalData['target_amount'] as num?)?.toDouble() ?? 0.0;
    late final double current =
        (goalData['current_amount'] as num?)?.toDouble() ?? 0.0;
    late final String id = goalData['id'] ?? 'N/A';
    late final double progress =
        (target > 0) ? (current / target).clamp(0.0, 1.0) : 0.0;

    // --- Determine Progress Bar Color ---
    Color progressBarColor;
    if (progress < 0.25) {
      progressBarColor = Colors.redAccent;
    } else if (progress < 0.75) {
      progressBarColor = Colors.yellowAccent;
    } else {
      progressBarColor = Colors.greenAccent;
    }
    // --- End Determine Progress Bar Color ---

    // Use WillPopScope to pass back the refresh status
    return WillPopScope(
      onWillPop: () async {
        // Pass back whether the previous page should refresh
        Navigator.pop(context, _needsRefresh);
        return false; // Prevent default back button behavior (we already popped)
      },
      child: Scaffold(
        appBar: AppBar(
          // Update AppBar title dynamically if name changes
          title: Text(name, style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            // Custom back button to handle WillPopScope
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context, _needsRefresh),
          ),
          iconTheme: IconThemeData(color: Colors.white),
          actions: [
            // --- Updated Edit Button ---
            IconButton(
              icon: Icon(Icons.edit, color: Colors.white),
              tooltip: 'Edit Goal', // Updated tooltip
              onPressed: _showEditGoalDialog, // Call the edit dialog function
            ),
            // --- End Updated Edit Button ---
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Delete Goal', // Updated tooltip
              onPressed: _deleteGoal, // Call the delete function
            ),
          ],
        ),
        backgroundColor: Colors.grey.shade900,
        // Use SingleChildScrollView to prevent overflow when history grows
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Goal Progress',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(height: 15),
                // Display Target and Current Amounts
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Target:',
                        style: TextStyle(fontSize: 16, color: Colors.white70)),
                    // Update Target amount dynamically
                    Text('₹${target.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Saved:',
                        style: TextStyle(fontSize: 16, color: Colors.white70)),
                    // Update Saved amount dynamically
                    Text('₹${current.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 18,
                            color:
                                progressBarColor, // Use determined color here too
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 15),
                // Progress Bar
                LinearProgressIndicator(
                  // Update progress dynamically
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(progressBarColor),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
                SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerRight,
                  // Update percentage dynamically
                  child: Text(
                    "${(progress * 100).toStringAsFixed(1)}%",
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
                SizedBox(height: 30),

                // Add Contribution Button
                Center(
                  child: ElevatedButton.icon(
                    onPressed: isLoadingContribution
                        ? null
                        : _showAddContributionDialog,
                    icon: isLoadingContribution
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(Icons.add_card, size: 20),
                    label: Text(isLoadingContribution
                        ? 'Adding...'
                        : 'Add Contribution'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        textStyle: TextStyle(fontSize: 16)),
                  ),
                ),
                SizedBox(height: 20),
                Divider(color: Colors.white24),
                SizedBox(height: 10),

                // --- Contribution History Section ---
                Text('Contribution History',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(height: 10),
                _buildContributionHistoryList(), // Call the history list widget
                // --- End Contribution History Section ---
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// --- End of GoalDetailsPage Widget ---
