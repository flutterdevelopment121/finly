# FINLY Budget App

FINLY is a mobile application built with Flutter designed to help users manage their personal finances, track spending, set budgets, and achieve financial goals. It utilizes Supabase for backend services, including authentication and data storage.

## Features

*   **User Authentication:** Secure login and registration using Supabase Auth.
*   **Homepage Dashboard:** (Assumed) A central view of financial status.
*   **Profile Management:** View and manage user profile details.
*   **Category Spending:** Track expenses based on categories.
*   **Daily Allowance:** Set and monitor daily spending limits.
*   **Goal Setting:** Define and track financial goals.
*   **(Potential) Balance Overview:** View current account balances.
*   **(Potential) Goal Details:** View detailed progress on specific goals.

## Technology Stack

*   **Frontend:** Flutter & Dart
*   **Backend & Database:** Supabase (Authentication, Database)

## Setup and Installation

1.  **Clone the Repository:**
    ```bash
    git clone <your-repository-url>
    cd budget # Or your project's root directory name
    ```

2.  **Install Flutter:**
    Ensure you have the Flutter SDK installed and configured on your system. Refer to the [Official Flutter Installation Guide](https://docs.flutter.dev/get-started/install).

3.  **Set up Supabase:**
    *   Go to [Supabase.io](https://supabase.io/) and create a new project.
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

to install the app and try download the apk file.

