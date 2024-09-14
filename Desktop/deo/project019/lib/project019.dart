import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:mysql1/mysql1.dart'; // MySQL package

void main() async {
  // Initialize the database
  final userDatabase = DatabaseHelper.instance;
  await userDatabase.createTable(); // Ensure the table is created

  // Register the user and store in the database
  Map<String, dynamic> userDetails = registerUser();

  if (verifyEmail(userDetails['email'])) {
    print("\nRegistration complete!\n");
    displayUserDetails(userDetails);

    // Store user details in the database
    await userDatabase.insertUser(userDetails);
    print("User details stored in the database.");

    // Login process
    await loginUser();
  } else {
    print("Email verification failed. Registration aborted.");
    exit(0);
  }
}

// Database helper class using MySQL
class DatabaseHelper {
  static final String _host = 'localhost';
  static final int _port = 3306; // Default MySQL port
  static final String _user = 'root'; // MySQL username
  static final String _password = 'password'; // MySQL password
  static final String _dbName = 'userDatabase'; // Database name

  // Singleton instance
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  MySqlConnection? _connection;

  // Initialize the MySQL database connection
  Future<MySqlConnection> get connection async {
    if (_connection != null) return _connection!;

    var settings = ConnectionSettings(
      host: _host,
      port: _port,
      user: _user,
      password: _password,
      db: _dbName,
    );

    _connection = await MySqlConnection.connect(settings);
    return _connection!;
  }

  // Method to create the users table if it doesn't exist
  Future<void> createTable() async {
    var conn = await connection;
    await conn.query('''
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        firstName VARCHAR(50),
        lastName VARCHAR(50),
        gender VARCHAR(10),
        email VARCHAR(100),
        phoneNumber VARCHAR(15),
        username VARCHAR(50),
        password VARCHAR(100)
      )
    ''');
  }

  // Insert a new user into the users table
  Future<void> insertUser(Map<String, dynamic> user) async {
    var conn = await connection;
    await conn.query('''
      INSERT INTO users (firstName, lastName, gender, email, phoneNumber, username, password)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
      user['firstName'],
      user['lastName'],
      user['gender'],
      user['email'],
      user['phoneNumber'],
      user['username'],
      user['password']
    ]);
  }

  // Fetch a user by username
  Future<Map<String, dynamic>?> getUser(String username) async {
    var conn = await connection;
    var results = await conn.query(
        'SELECT * FROM users WHERE username = ?', [username]);

    if (results.isNotEmpty) {
      var row = results.first;
      return {
        'id': row['id'],
        'firstName': row['firstName'],
        'lastName': row['lastName'],
        'gender': row['gender'],
        'email': row['email'],
        'phoneNumber': row['phoneNumber'],
        'username': row['username'],
        'password': row['password']
      };
    }
    return null;
  }

  // Update a user's password by username
  Future<void> updateUserPassword(String username, String newPassword) async {
    var conn = await connection;
    await conn.query('''
      UPDATE users SET password = ? WHERE username = ?
    ''', [newPassword, username]);
  }

  // Close the database connection
  Future<void> close() async {
    if (_connection != null) {
      await _connection!.close();
      _connection = null;
    }
  }
}

// Step 1: Registration Process
Map<String, dynamic> registerUser() {
  print("=== Registration Process ===");

  String firstName = getInput("Enter your first name:", validateName);
  String lastName = getInput("Enter your last name:", validateName);
  String gender = selectGender();
  String email = getInput("Enter your email:", validateEmail);
  String phoneNumber = getInput("Enter your phone number:", validatePhoneNumber);
  String username = getInput("Create your username:", validateUsername);
  String password = createAndConfirmPassword();

  return {
    'firstName': firstName,
    'lastName': lastName,
    'gender': gender,
    'email': email,
    'phoneNumber': phoneNumber,
    'username': username,
    'password': hashPassword(password)
  };
}

// Simulate Email Verification
bool verifyEmail(String email) {
  print("\nA verification email has been sent to $email.");
  print("Type 'verified' to simulate email verification:");
  return stdin.readLineSync() == 'verified';
}

// Display user details after registration
void displayUserDetails(Map<String, dynamic> userDetails) {
  print("Name: ${userDetails['firstName']} ${userDetails['lastName']}");
  print("Gender: ${userDetails['gender']}");
  print("Email: ${userDetails['email']}");
  print("Phone Number: ${userDetails['phoneNumber']}");
  print("Username: ${userDetails['username']}");
}

// Step 2: Login Process
Future<void> loginUser() async {
  final db = DatabaseHelper.instance;
  while (true) {
    print("\n=== Login Page ===");
    String loginUsername = getInput("Enter your username:", validateNonEmpty);
    String loginPassword = getInput("Enter your password:", validateNonEmpty);

    // Fetch user from database
    Map<String, dynamic>? dbUser = await db.getUser(loginUsername);

    if (dbUser != null && hashPassword(loginPassword) == dbUser['password']) {
      print("Login successful! Welcome, ${dbUser['username']}.");
      exit(0);
    } else {
      print("Invalid username or password.");
      if (offerPasswordReset(dbUser?['email'], dbUser?['phoneNumber'])) {
        String newPassword = createAndConfirmPassword();
        // Update password in the database
        await db.updateUserPassword(dbUser!['username'], hashPassword(newPassword));
        print("Password reset successful. Please log in with your new password.");
      }
    }
  }
}

// Utility Functions
String getInput(String prompt, Function validator) {
  while (true) {
    print(prompt);
    String? input = stdin.readLineSync();
    if (validator(input)) return input!;
    print("Invalid input. Please try again.");
  }
}

bool validateName(String? name) =>
    name != null && name.isNotEmpty && RegExp(r'^[a-zA-Z]+$').hasMatch(name);

String selectGender() {
  for (int i = 0; i < 3; i++) {
    print("Select your gender: (Type 1 for Male, 2 for Female)");
    String? genderChoice = stdin.readLineSync();
    if (genderChoice == '1') return "Male";
    if (genderChoice == '2') return "Female";
    if (i < 2) print("Invalid choice. Please select 1 or 2.");
  }
  print("Too many invalid attempts. Registration aborted.");
  exit(0);
}

bool validateEmail(String? email) =>
    email != null && email.isNotEmpty && RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);

bool validatePhoneNumber(String? phone) =>
    phone != null && RegExp(r'^\d{10}$').hasMatch(phone);

bool validateUsername(String? username) =>
    username != null && username.length >= 3 && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(username);

String createAndConfirmPassword() {
  while (true) {
    String? tempPassword = getInput(
      "Create your password (min 8 chars, including upper/lowercase, number, special char):",
      validatePassword
    );
    String? confirmPassword = getInput("Confirm your password:", validateNonEmpty);
    if (tempPassword == confirmPassword) return tempPassword!;
    print("Passwords do not match. Please try again.");
  }
}

bool validatePassword(String? password) =>
    password != null &&
    password.length >= 8 &&
    RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$')
        .hasMatch(password);

String hashPassword(String password) =>
    sha256.convert(utf8.encode(password)).toString();

bool offerPasswordReset(String? registeredEmail, String? registeredPhone) {
  print("Forgot your password? (yes/no)");
  if (stdin.readLineSync()?.toLowerCase() == 'yes') {
    print("Enter your registered email or phone number:");
    String? input = stdin.readLineSync();
    if (input == registeredEmail || input == registeredPhone) return true;
    print("Provided details do not match our records. Password reset denied.");
  }
  return false;
}

bool validateNonEmpty(String? input) => input != null && input.isNotEmpty;
