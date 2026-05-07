import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';
import '../services/theme_controller.dart';
import 'register_screen.dart';
import 'customer_dashboard.dart';
import 'restaurant_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isPasswordObscured = true;
  bool _isLoading = false;
  


  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize fade-in animations for rich premium aesthetics
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
    
    // Set initial role in ThemeController
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ThemeController().updateRole('customer');
    });

    _checkAutoLogin();
  }

  bool _isAutoLoginChecking = true;

  Future<void> _checkAutoLogin() async {
    final user = await FirebaseService.tryAutoLogin();
    if (user != null) {
      if (mounted) {
        // Update Theme role context to correct user role
        ThemeController().updateRole(user.role);

        if (user.role == 'customer') {
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
    } else {
      if (mounted) {
        setState(() {
          _isAutoLoginChecking = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }



  // Reset password action
  Future<void> _handlePasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showErrorSnackBar("Lütfen şifre sıfırlama bağlantısı göndermek için geçerli bir e-posta adresi girin.");
      return;
    }

    setState(() => _isLoading = true);
    final error = await FirebaseService.resetPassword(email);
    setState(() => _isLoading = false);

    if (error != null) {
      _showErrorSnackBar(error);
    } else {
      _showSuccessDialog(
        "Şifre Sıfırlama",
        "Şifre sıfırlama bağlantısı e-posta adresinize gönderildi. Lütfen gelen kutunuzu (ve gereksiz klasörünü) kontrol edin.",
      );
    }
  }

  // Sign In Action
  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final error = await FirebaseService.signIn(
      email: email,
      password: password,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (error != null) {
      _showErrorSnackBar(error);
    } else {
      // Navigate to the correct Dashboard dynamically based on their actual database profile role
      final actualRole = FirebaseService.currentUser?.role ?? 'customer';
      ThemeController().updateRole(actualRole);

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

  void _showSuccessDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Text(
          content,
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Tamam"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isAutoLoginChecking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F10),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoActivityIndicator(radius: 18, color: Colors.amber),
              SizedBox(height: 16),
              Text(
                "Oturum Kontrol Ediliyor...",
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Dynamic Glowing Orbs in Background for ultra premium looks
          Positioned(
            top: -100,
            right: -100,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.08),
              ),
            ),
          ),

          // Demo Mode Banner
          if (FirebaseService.useDemoMode)
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade800, Colors.orange.shade700],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Demo Modu Etkin (Firebase Çevrimdışı Modu)",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Main Layout Content
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),
                        
                        // Animated Brand Logo / Symbol
                        Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.primaryColor.withValues(alpha: 0.15),
                              border: Border.all(
                                color: theme.primaryColor.withValues(alpha: 0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.primaryColor.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: Icon(
                              Icons.restaurant_menu_rounded,
                              size: 52,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title & Description
                        Text(
                          "Hoş Geldiniz",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Giriş yaparak lezzet keşfine başlayın.",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 36),



                        // E-posta Adresi Text Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                          decoration: const InputDecoration(
                            labelText: "E-posta Adresi",
                            prefixIcon: Icon(Icons.email_outlined, size: 20, color: Colors.white54),
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
                              return "Lütfen şifrenizi girin.";
                            }
                            if (value.length < 6) {
                              return "Şifreniz en az 6 karakter olmalıdır.";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

                        // Şifremi Unuttum? Button
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _handlePasswordReset,
                            child: const Text("Şifremi Unuttum?"),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Giriş Yap ElevatedButton
                        _isLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12.0),
                                  child: CupertinoActivityIndicator(radius: 14, color: Colors.white),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: _handleSignIn,
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("Giriş Yap"),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward, size: 18),
                                  ],
                                ),
                              ),
                        const SizedBox(height: 28),

                        // Navigation Row: "Hesabınız yok mu? Hemen Kayıt Ol"
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Hesabınız yok mu? ",
                              style: theme.textTheme.bodyMedium,
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                      );
                                    },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text("Hemen Kayıt Ol"),
                            ),
                          ],
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
