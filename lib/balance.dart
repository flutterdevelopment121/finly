import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';

class BalancePage extends StatefulWidget {
  final String cardName;
  final double balance;
  final int cardId;

  BalancePage(
      {required this.cardName, required this.balance, required this.cardId});

  @override
  _BalancePageState createState() => _BalancePageState();
}

class _BalancePageState extends State<BalancePage> {
  final supabase = Supabase.instance.client;
  bool isIncome = true;
  double updatedBalance = 0.0;

  @override
  void initState() {
    super.initState();
    updatedBalance = widget.balance;
  }

  void toggleView(bool incomeSelected) {
    setState(() {
      isIncome = incomeSelected;
    });
  }

  void showAddTransactionDialog() {
    TextEditingController amountController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    TextEditingController categoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      decoration: InputDecoration(
                        labelText: "Amount",
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                    ),
                    TextField(
                      controller: categoryController,
                      decoration: InputDecoration(
                        labelText: "Category",
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                      style: TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: "Description",
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                      style: TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("Cancel",
                              style: TextStyle(color: Colors.white)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                          ),
                          onPressed: () async {
                            double amount =
                                double.tryParse(amountController.text) ?? 0.0;
                            if (amount > 0) {
                              await addTransaction(
                                  amount,
                                  categoryController.text,
                                  descriptionController.text);
                              setState(() {});
                            }
                            Navigator.pop(context);
                          },
                          child: Text("Add",
                              style: TextStyle(color: Colors.white)),
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
  }

  Future<void> addTransaction(
      double amount, String category, String description) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      double newBalance =
          isIncome ? updatedBalance + amount : updatedBalance - amount;

      // Update cards table first, then transactions table
      await supabase
          .from('cards')
          .update({'balance': newBalance}).eq('id', widget.cardId);

      await supabase.from('transactions').insert({
        'user_id': user.id,
        'card_id': widget.cardId,
        'amount': amount,
        'category': category,
        'description': description,
        'created_at': DateTime.now().toIso8601String(),
        'type': isIncome ? 'income' : 'expense'
      });

      setState(() {
        updatedBalance = newBalance;
      });
    } catch (e) {
      print("Error adding transaction: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: Text("Balance Details"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
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
                  padding: EdgeInsets.all(16),
                  width: 500,
                  height: 250,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(widget.cardName,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      SizedBox(height: 20),
                      Text("₹${updatedBalance.toStringAsFixed(2)}",
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 40), // Increased space
                child: GestureDetector(
                  onTap: () => toggleView(true),
                  child: Text("Income",
                      style: TextStyle(
                          fontSize: 18,
                          color: isIncome ? Colors.greenAccent : Colors.white)),
                ),
              ),
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 40), // Increased space
                child: GestureDetector(
                  onTap: () => toggleView(false),
                  child: Text("Expense",
                      style: TextStyle(
                          fontSize: 18,
                          color: isIncome ? Colors.white : Colors.redAccent)),
                ),
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchTransactions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text("Error loading transactions"));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                      child: Text(
                    "No transactions found",
                    style: TextStyle(color: Colors.white),
                  ));
                }

                final transactions = snapshot.data!;
                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        border:
                            Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: ListTile(
                        title: Text(
                          transaction['category'],
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          transaction['description'],
                          style: TextStyle(color: Colors.white70),
                        ),
                        trailing: Text(
                          "₹${transaction['amount'].toStringAsFixed(2)}",
                          style: TextStyle(
                              color: transaction['type'] == 'income'
                                  ? Colors.greenAccent
                                  : Colors.redAccent),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: showAddTransactionDialog,
              child: Text("Add Transaction",
                  style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> fetchTransactions() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return [];

      final List<dynamic> response = await supabase
          .from('transactions')
          .select()
          .eq('user_id', user.id)
          .eq('card_id', widget.cardId)
          .eq('type', isIncome ? 'income' : 'expense')
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        return []; // Return an empty list if no data is found
      }

      return List<Map<String, dynamic>>.from(
          response); // Properly cast response
    } catch (e) {
      print("Error fetching transactions: $e");
      return [];
    }
  }
}
