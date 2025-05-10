# FINLY Budget App

FINLY is a mobile application built with Flutter designed to help users manage their personal finances, track spending, set budgets, and achieve financial goals. It utilizes Supabase for backend services, including authentication and data storage.

## Features

*   **User Authentication:** Secure login and registration using Supabase Auth.
*   **Homepage Dashboard:**
    *   Displays a list of user's cards with current balances.
    *   Pull-down to refresh card balances.
    *   Allows adding new cards with an initial balance.
    *   Provides options to edit card names and delete cards (which also removes associated transactions).
    *   Quick navigation via Floating Action Buttons to:
        *   Profile Management
        *   Calendar View (Placeholder for future transaction calendar)
        *   Daily Allowance Management
        *   Goal Setting
        *   Category-wise Spending Analysis
*   **Card Balance Management (Balance Page):**
    *   Detailed view for each card, showing current balance, total income, and total expenses for that card.
    *   Add income or expense transactions associated with the selected card.
    *   Transactions can be assigned to categories; users can add new categories on the fly.
    *   List of transactions (income/expense) with description, category, date, and amount.
    *   Ability to delete individual transactions, which also updates the card balance.
    *   **PDF Statement Generation:** Users can generate and download/print a PDF statement of transactions for a selected card within a specified date range.
*   **Category Spending Analysis (Category List Page):**
    *   Lists all categories with a summary of total income and total expenses for each.
    *   Categories are sorted with the highest spending at the top.
    *   Pull-down to refresh category summaries.
    *   View detailed transactions for a specific category.
*   **Goal Setting & Tracking (Goals List & Details Page):**
    *   Define financial goals with a target amount.
    *   Track progress towards goals (current amount saved, percentage complete).
    *   Add contributions to goals.
    *   View a history of contributions for each goal.
    *   Edit goal details (name, target amount).
    *   Delete goals (which also removes associated contributions).
    *   Delete individual contributions from a goal.
    *   **Move Funds:** Transfer the current amount saved in a goal directly to a selected card, creating an "income" transaction for the card and updating its balance.
*   **Profile Management:** (Assumed) View and manage user profile details.
*   **Daily Allowance:** (Assumed) Set and monitor daily spending limits.

## Technology Stack

*   **Frontend:** Flutter & Dart
*   **Backend & Database:** Supabase (Authentication, Database)
*   **PDF Generation:** `pdf` and `printing` packages.

## Setup and Installation

1.  **Clone the Repository:**
    ```bash
    git clone <your-repository-url>
    cd budget # Or your project's root directory name
    ```

2.  **Install Flutter:**
    Ensure you have the Flutter SDK installed and configured on your system. Refer to the Official Flutter Installation Guide.

3.  **Set up Supabase:**
    *   Go to Supabase.io and create a new project.
    *   In your Supabase project dashboard, navigate to `Project Settings` > `API`.
    *   Find your **Project URL** and **anon public Key**.

4.  **Configure Supabase Credentials:**
    *   Open the `lib/main.dart` file in your project.
    *   Locate the `Supabase.initialize` block:
        ```dart
        await Supabase.initialize(
          url: 'YOUR_SUPABASE_URL', // <-- Replace with your Project URL
          anonKey: 'YOUR_SUPABASE_ANON_KEY', // <-- Replace with your anon public Key
        );
        ```
    *   Replace `'YOUR_SUPABASE_URL'` and `'YOUR_SUPABASE_ANON_KEY'` with the actual credentials obtained from your Supabase project.

    **Note:** For production applications, it is strongly recommended *not* to hardcode sensitive keys directly in the source code. Use environment variables or a configuration management solution (e.g., `flutter_dotenv`) to handle secrets securely.

5.  **Install Dependencies:**
    Run the following command in your project's root directory:
    ```bash
    flutter pub get
    ```

## Running the App

1.  **Ensure a device or emulator is running.**
2.  **Run the app from your terminal:**
    ```bash
    flutter run
    ```

This will build and launch the FINLY Budget app on your connected device or emulator.

---

To try the app via a pre-built package, you can download the APK file (if provided by the developer).
