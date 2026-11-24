import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'bottom_navigation_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();

  // Tab: true = Sign In, false = Sign Up
  bool _isSignIn = true;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  // Regex patterns
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp _nameRegex = RegExp(r"^[a-zA-Z\s'-]{2,}$");

  // State
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('remembered_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Email validation using RFC-compliant Regex
    if (email.isEmpty) {
      _showError('Please enter your email address');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      _showError('Please enter a valid email address (e.g. name@example.com)');
      return;
    }

    // Password validation: minimum 6 chars
    if (password.isEmpty) {
      _showError('Please enter your password');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters long');
      return;
    }

    if (!_isSignIn) {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final confirmPassword = _confirmPasswordController.text;

      // Name regex validation (letters, spaces, hyphens, min 2 chars)
      if (firstName.isEmpty) {
        _showError('Please enter your first name');
        return;
      }
      if (!_nameRegex.hasMatch(firstName)) {
        _showError(
          'First name should only contain letters and be at least 2 characters',
        );
        return;
      }

      if (lastName.isNotEmpty && !_nameRegex.hasMatch(lastName)) {
        _showError('Last name should only contain letters');
        return;
      }

      // Password strength check on signup (at least 1 letter and 1 number)
      final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
      final hasDigit = RegExp(r'[0-9]').hasMatch(password);
      if (!hasLetter || !hasDigit) {
        _showError('Password must contain at least one letter and one number');
        return;
      }

      if (confirmPassword.isEmpty) {
        _showError('Please confirm your password');
        return;
      }
      if (password != confirmPassword) {
        _showError('Passwords do not match');
        return;
      }

      setState(() => _isLoading = true);
      try {
        await _authService.signUp(
          firstName: firstName,
          lastName: lastName,
          email: email,
          password: password,
        );

        if (_rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('remembered_email', email);
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const BottomNav()),
          );
        }
      } on FirebaseAuthException catch (e) {
        _showError(e.message ?? 'Sign up failed');
      } catch (e) {
        _showError('Something went wrong. Please try again.');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      // Sign In
      setState(() => _isLoading = true);
      try {
        await _authService.signIn(email: email, password: password);

        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString('remembered_email', email);
        } else {
          await prefs.remove('remembered_email');
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const BottomNav()),
          );
        }
      } on FirebaseAuthException catch (e) {
        _showError(e.message ?? 'Invalid email or password');
      } catch (e) {
        _showError('Something went wrong. Please try again.');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _handleForgotPassword() {
    final email = _emailController.text.trim();
    showDialog(
      context: context,
      builder: (ctx) {
        final resetCtrl = TextEditingController(text: email);
        return AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your registered email address to receive a password reset link:',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: resetCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Enter Email Address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final targetEmail = resetCtrl.text.trim();
                if (targetEmail.isEmpty || !targetEmail.contains('@')) {
                  _showError('Enter a valid email');
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _authService.sendPasswordResetEmail(targetEmail);
                  _showSuccess('Password reset link sent to your email!');
                } catch (e) {
                  _showError('Failed to send reset email');
                }
              },
              child: const Text('Send Link'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF9F7F2),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top back arrow (for sign up or navigation)
              Row(
                children: [
                  if (!_isSignIn)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      onPressed: () => setState(() => _isSignIn = true),
                    )
                  else
                    const SizedBox(height: 40),
                ],
              ),

              // App Logo / Icon Header
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF242424) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      'assets/applogo/applogo.png',
                      width: 44,
                      height: 44,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.track_changes_rounded,
                        color: Colors.black,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Title
              Text(
                _isSignIn ? 'Access Your StreakUP' : 'Begin Your StreakUP',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _isSignIn
                      ? 'Sign in to access your habits, track attendance, and preserve your daily streaks.'
                      : 'Sign up to start tracking your daily habits and preserve streaks with live updates.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : const Color(0xFF6E6E6E),
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Main Card Container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Segmented Tab Switcher (Sign in / Sign up)
                    Container(
                      height: 48,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2C2C2C)
                            : const Color(0xFFF1F1F5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isSignIn = true),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _isSignIn
                                      ? (isDark
                                            ? const Color(0xFF3D3D3D)
                                            : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: _isSignIn
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.06,
                                            ),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Sign in',
                                  style: TextStyle(
                                    fontWeight: _isSignIn
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: _isSignIn
                                        ? (isDark ? Colors.white : Colors.black)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isSignIn = false),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: !_isSignIn
                                      ? (isDark
                                            ? const Color(0xFF3D3D3D)
                                            : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: !_isSignIn
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.06,
                                            ),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Sign up',
                                  style: TextStyle(
                                    fontWeight: !_isSignIn
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: !_isSignIn
                                        ? (isDark ? Colors.white : Colors.black)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // SIGN UP SPECIFIC: First Name & Last Name
                    if (!_isSignIn) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'First name',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _firstNameController,
                                  hintText: 'Enter first name',
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Last name',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _lastNameController,
                                  hintText: 'Enter last name',
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email Field
                    const Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'Enter Email Address',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 16),

                    // Password Field
                    const Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _passwordController,
                      hintText: '••••••••••••',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      isDark: isDark,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),

                    // SIGN UP SPECIFIC: Confirm Password
                    if (!_isSignIn) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Confirm password',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        hintText: '••••••••••••',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _obscureConfirmPassword,
                        isDark: isDark,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                      ),
                    ],

                    // Remember Me & Forgot Password (Sign In Only)
                    if (_isSignIn) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _rememberMe,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  activeColor: Colors.black,
                                  onChanged: (val) {
                                    setState(() => _rememberMe = val ?? false);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Remember Me',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: _handleForgotPassword,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFE53935),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // BLACK BUTTON (Sign in / Register)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        onPressed: _isLoading ? null : _handleSubmit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isSignIn ? 'Sign in' : 'Register',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Bottom Toggle Prompt
                    Center(
                      child: GestureDetector(
                        onTap: () => setState(() => _isSignIn = !_isSignIn),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            children: [
                              TextSpan(
                                text: _isSignIn
                                    ? "Don't have an account? "
                                    : 'Already Have An Account? ',
                              ),
                              TextSpan(
                                text: _isSignIn ? 'Sign Up' : 'Sign In',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required bool isDark,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: Colors.grey, size: 18)
              : null,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
