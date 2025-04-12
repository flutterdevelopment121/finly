import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui'; // For BackdropFilter
import 'goals_details_page.dart'; // Import the GoalDetailsPage

class SetGoalsPage extends StatefulWidget {
  @override
  _SetGoalsPageState createState() => _SetGoalsPageState();
}

class _SetGoalsPageState extends State<SetGoalsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> goals = [];
  bool isLoading = true;
  String? errorMessage; // To store potential error messages

  @override
  void initState() {
    super.initState();
    _fetchGoals();
  }

  Future<void> _fetchGoals() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null; // Reset error on fetch
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        // Should ideally not happen if page is protected, but good practice
        throw Exception("User not logged in.");
      }

      final response = await supabase
          .from('goals')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          goals = List<Map<String, dynamic>>.from(response.map((goal) {
            // Ensure numeric types are handled correctly
            final targetAmount =
                (goal['target_amount'] as num?)?.toDouble() ?? 0.0;
            final currentAmount =
                (goal['current_amount'] as num?)?.toDouble() ?? 0.0;
            return {
              'id': goal['id'],
              'name': goal['name'] as String? ?? 'Unnamed Goal',
              'target_amount': targetAmount,
              'current_amount': currentAmount,
              // Add other fields like deadline if needed
            };
          }));
          isLoading = false;
        });
      }
    } catch (error) {
      print("Error fetching goals: $error");
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = "Error fetching goals: ${error.toString()}";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error fetching goals. Please try again."),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- Add New Goal ---
  Future<void> _addNewGoal(String name, double targetAmount) async {
    if (!mounted) return;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception("User not logged in.");
      }

      // Basic validation (can be enhanced in the dialog)
      if (name.trim().isEmpty || targetAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Please provide a valid name and target amount (> 0).'),
              backgroundColor: Colors.orange),
        );
        return; // Don't proceed
      }

      await supabase.from('goals').insert({
        'name': name.trim(),
        'target_amount': targetAmount,
        'user_id': user.id,
        'current_amount': 0.0, // Start with 0 saved
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Goal "$name" added successfully!'),
              backgroundColor: Colors.green),
        );
        _fetchGoals(); // Refresh the list
      }
    } catch (e) {
      print("Error adding goal: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error adding goal: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
      throw e; // Re-throw for the dialog's catch block if needed
    }
  }

  void _showAddGoalDialog() {
    final nameController = TextEditingController();
    final targetAmountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // To manage button loading state
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
                            "Set New Goal",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 20),
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
                              errorStyle: TextStyle(
                                  color:
                                      Colors.yellowAccent), // Error text color
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a goal name';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 15),
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
                              errorStyle: TextStyle(
                                  color:
                                      Colors.yellowAccent), // Error text color
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
                                          final name = nameController.text;
                                          final targetAmount = double.parse(
                                              targetAmountController
                                                  .text); // Already validated

                                          setDialogState(() => isAdding = true);
                                          try {
                                            await _addNewGoal(
                                                name, targetAmount);
                                            if (mounted)
                                              Navigator.pop(
                                                  context); // Close dialog on success
                                          } catch (e) {
                                            // Error shown via SnackBar in _addNewGoal
                                          } finally {
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
                                    : Text("Add Goal"),
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

  Widget _buildGoalsList() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            errorMessage!,
            style: TextStyle(color: Colors.redAccent, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (goals.isEmpty) {
      return Center(
        child: Text(
          "No goals set yet.\nTap the + button to add your first goal!",
          style: TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: goals.length,
      itemBuilder: (context, index) {
        final goal = goals[index];
        final double target = goal['target_amount'];
        final double current = goal['current_amount'];
        // Prevent division by zero and handle completed goals
        final double progress =
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

        return InkWell(
          onTap: () {
            // Navigate to Goal Details Page
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GoalDetailsPage(
                  // Corrected parameter name:
                  initialGoalData: goal,
                ),
              ),
            ).then((value) {
              // Optional: Refresh list if changes might have occurred on details page
              if (value == true) {
                // Check if details page indicated a change
                _fetchGoals();
              }
            });
          },
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.white.withOpacity(0.1),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: ClipRRect(
              // Apply clipping for the BackdropFilter
              borderRadius: BorderRadius.circular(15),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Subtle blur
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    // Need this inner decoration if using BackdropFilter
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.transparent, // Inner container transparent
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal['name'],
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Target: ₹${target.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                      Text(
                        "Saved: ₹${current.toStringAsFixed(2)}",
                        style: TextStyle(
                            fontSize: 14,
                            // Optionally match text color to progress bar
                            color: progressBarColor,
                            fontWeight: FontWeight
                                .w500 // Slightly less bold than details page
                            ),
                      ),
                      SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        // --- Apply the dynamic color ---
                        valueColor:
                            AlwaysStoppedAnimation<Color>(progressBarColor),
                        // --- End Apply the dynamic color ---
                        minHeight: 8, // Make the progress bar thicker
                        borderRadius: BorderRadius.circular(
                            4), // Rounded corners for progress bar
                      ),
                      SizedBox(height: 4),
                      Align(
                        // Align percentage text to the right
                        alignment: Alignment.centerRight,
                        child: Text(
                          "${(progress * 100).toStringAsFixed(1)}%",
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Your Goals",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, // Match homepage style
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white), // Back button color
      ),
      backgroundColor: Colors.grey.shade900, // Match homepage style
      body: RefreshIndicator(
        // Add pull-to-refresh
        onRefresh: _fetchGoals,
        color: Colors.white,
        backgroundColor: Colors.grey.shade800,
        child: _buildGoalsList(),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addGoalButton', // Unique heroTag
        onPressed: _showAddGoalDialog,
        // --- Updated Style ---
        backgroundColor:
            Colors.white.withOpacity(0.3), // Match home screen style
        tooltip: 'Add New Goal',
        child: Icon(Icons.add,
            color: Colors.white), // Match home screen icon color
        // --- End Updated Style ---
      ),
    );
  }
}
