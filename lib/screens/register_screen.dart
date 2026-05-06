import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';
import 'customer_dashboard.dart';
import 'restaurant_dashboard.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordObscured = true;
  bool _isLoading = false;

  // Dropdown State: Default is Müşteri
  String _selectedRoleLabel = "Müşteri";
  final List<String> _roleOptions = ["Müşteri", "Restoran Sahibi"];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Handle Sign Up
  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    // Map dropdown selections to database role tags
    final role = _selectedRoleLabel == 'Müşteri' ? 'customer' : 'restaurant_owner';

    final error = await FirebaseService.signUp(
      email: email,
      password: password,
      fullName: fullName,
      role: role,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (error != null) {
      _showErrorSnackBar(error);
    } else {
      // Navigate to correct page and clear stack
      final actualRole = FirebaseService.currentUser?.role ?? role;
      if (actualRole == 'customer') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CustomerDashboard()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RestaurantDashboard()),
          (route) => false,
        );
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.primaryColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Yeni Hesap Oluştur",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Stack(
        children: [
          // Background Glow Orbs
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.06),
              ),
            ),
          ),

          // Main Registration Form
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Dynamic Icon Container
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                              border: Border.all(
                                color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 44,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Ad Soyad Text Field
                        TextFormField(
                          controller: _fullNameController,
                          keyboardType: TextInputType.name,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                          decoration: const InputDecoration(
                            labelText: "Ad Soyad",
                            prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: Colors.white54),
                            hintText: "Örn: Ahmet Yılmaz",
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Lütfen adınızı ve soyadınızı girin.";
                            }
                            if (value.trim().split(' ').length < 2) {
                              return "Lütfen tam adınızı girin (Ad ve Soyad).";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // E-posta Text Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                          decoration: const InputDecoration(
                            labelText: "E-posta",
                            prefixIcon: Icon(Icons.email_outlined, size: 20, color: Colors.white54),
                            hintText: "Örn: ahmet@example.com",
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Lütfen e-posta adresinizi girin.";
                            }
                            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(value.trim())) {
                              return "Lütfen geçerli bir e-posta adresi girin.";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // Şifre Text Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _isPasswordObscured,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            labelText: "Şifre",
                            prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Colors.white54),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20,
                                color: Colors.white54,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordObscured = !_isPasswordObscured;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Lütfen bir şifre belirleyin.";
                            }
                            if (value.length < 6) {
                              return "Şifreniz en az 6 karakter olmalıdır.";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // Hesap Türü Dropdown Field
                        Theme(
                          data: Theme.of(context).copyWith(
                            canvasColor: theme.cardColor,
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedRoleLabel,
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                            decoration: const InputDecoration(
                              labelText: "Hesap Türü",
                              prefixIcon: Icon(Icons.switch_account_outlined, size: 20, color: Colors.white54),
                            ),
                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.primaryColor),
                            items: _roleOptions.map((String val) {
                              return DropdownMenuItem<String>(
                                value: val,
                                child: Text(
                                  val,
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w500, color: Colors.white),
                                ),
                              );
                            }).toList(),
                            onChanged: (newVal) {
                              if (newVal != null) {
                                setState(() {
                                  _selectedRoleLabel = newVal;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Kaydı Tamamla ElevatedButton
                        _isLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12.0),
                                  child: CupertinoActivityIndicator(radius: 14, color: Colors.white),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: _handleSignUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.secondary,
                                  foregroundColor: Colors.white,
                                  shadowColor: theme.colorScheme.secondary.withValues(alpha: 0.3),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("Kaydı Tamamla"),
                                    SizedBox(width: 8),
                                    Icon(Icons.check_circle_outline, size: 18),
                                  ],
                                ),
                              ),
                        const SizedBox(height: 24),

                        // Back to login navigation link
                        Center(
                          child: TextButton(
                            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                            child: const Text("Zaten bir hesabım var. Giriş Yap"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
