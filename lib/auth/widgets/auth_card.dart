import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_custom_clippers/flutter_custom_clippers.dart';
import '../../routes.dart';
import '../services/auth_service.dart';

class AuthCard extends StatefulWidget {
  final bool isLogin;
  const AuthCard({super.key, required this.isLogin});

  @override
  State<AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends State<AuthCard> {
  static const _kSignupParentEmailField = 'signup_parent_email';
  static const _kChildLoginParentEmailField = 'child_login_parent_email';
  static const _kLoginEmailField = 'login_email';
  static const _kSignupEmailField = 'signup_email';

  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _signupChildUsernameController = TextEditingController();
  final _signupParentUsernameController = TextEditingController();
  final _signupChildEmailController = TextEditingController();
  final _signupParentEmailController = TextEditingController();
  final _signupChildPasswordController = TextEditingController();
  final _signupParentPasswordController = TextEditingController();
  final _signupChildConfirmPasswordController = TextEditingController();
  final _signupParentConfirmPasswordController = TextEditingController();
  final _parentEmailController = TextEditingController();
  final _childLoginParentEmailController = TextEditingController();
  final _childLoginUsernameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _role = 'child';
  final Map<String, String?> _emailFieldErrors = {};
  final Map<String, Timer> _emailValidationTimers = {};
  final Map<String, int> _emailValidationRunIds = {};
  /// Sign-up: child uses parent email + username only (synthetic Auth email under the hood).
  bool _childNoOwnEmail = false;
  /// Login: child signs in with parent email + username + password.
  bool _childUsernameLogin = false;

  bool _isValidEmail(String value) {
    return AuthService.isValidEmailFormat(value);
  }

  Future<bool> _ensureDomainIsValid(String email, {required String label}) async {
    final domainStatus = await AuthService.hasResolvableEmailDomain(email);
    if (domainStatus == false) {
      if (!mounted) return false;
      final normalizedLabel = label.trim().isEmpty ? 'email' : '$label email';
      setState(() {
        _errorMessage =
            'Incorrect $normalizedLabel domain. Please check and try again.';
      });
      return false;
    }
    return true;
  }

  void _onEmailChangedRealtime({
    required String fieldKey,
    required String value,
    required String label,
  }) {
    _emailValidationTimers[fieldKey]?.cancel();

    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      if (_emailFieldErrors[fieldKey] != null && mounted) {
        setState(() => _emailFieldErrors[fieldKey] = null);
      }
      return;
    }

    final runId = (_emailValidationRunIds[fieldKey] ?? 0) + 1;
    _emailValidationRunIds[fieldKey] = runId;

    _emailValidationTimers[fieldKey] = Timer(
      const Duration(milliseconds: 450),
      () async {
        final normalizedLabel = label.trim().isEmpty ? 'email' : '$label email';
        if (!AuthService.isValidEmailFormat(normalized)) {
          if (!mounted || _emailValidationRunIds[fieldKey] != runId) return;
          setState(() {
            _emailFieldErrors[fieldKey] = 'Enter a valid $normalizedLabel';
          });
          return;
        }

        final domainStatus = await AuthService.hasResolvableEmailDomain(
          normalized,
        );
        if (!mounted || _emailValidationRunIds[fieldKey] != runId) return;
        setState(() {
          _emailFieldErrors[fieldKey] = domainStatus == false
              ? 'Incorrect $normalizedLabel domain'
              : null;
        });
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _signupChildUsernameController.dispose();
    _signupParentUsernameController.dispose();
    _signupChildEmailController.dispose();
    _signupParentEmailController.dispose();
    _signupChildPasswordController.dispose();
    _signupParentPasswordController.dispose();
    _signupChildConfirmPasswordController.dispose();
    _signupParentConfirmPasswordController.dispose();
    _parentEmailController.dispose();
    _childLoginParentEmailController.dispose();
    _childLoginUsernameController.dispose();
    for (final timer in _emailValidationTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  TextEditingController get _signupUsernameController =>
      _role == 'parent'
          ? _signupParentUsernameController
          : _signupChildUsernameController;

  TextEditingController get _signupEmailController =>
      _role == 'parent' ? _signupParentEmailController : _signupChildEmailController;

  TextEditingController get _signupPasswordController => _role == 'parent'
      ? _signupParentPasswordController
      : _signupChildPasswordController;

  TextEditingController get _signupConfirmPasswordController => _role == 'parent'
      ? _signupParentConfirmPasswordController
      : _signupChildConfirmPasswordController;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.isLogin) {
        if (_childUsernameLogin) {
          final ok = await _ensureDomainIsValid(
            _childLoginParentEmailController.text.trim(),
            label: 'parent',
          );
          if (!ok) return;
        } else {
          final ok = await _ensureDomainIsValid(
            _emailController.text.trim(),
            label: '',
          );
          if (!ok) return;
        }

        final UserCredential credential;
        if (_childUsernameLogin) {
          credential = await _authService.signInChildNoOwnEmail(
            parentEmail: _childLoginParentEmailController.text,
            username: _childLoginUsernameController.text,
            password: _passwordController.text,
          );
        } else {
          credential = await _authService.signIn(
            _emailController.text,
            _passwordController.text,
          );
        }
        final user = credential.user;
        await user?.reload();

        final isVerified = await _authService.reloadAndCheckEffectiveVerified();
        if (!isVerified) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(AuthService.emailNotVerifiedYet),
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pushReplacementNamed(context, AppRoutes.verifyEmail);
          }
          return;
        }

        final role = await _authService.readRole(user?.uid);
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            role == 'parent' ? AppRoutes.parentApprovals : AppRoutes.community,
          );
        }
      } else {
        final signupUsername = _signupUsernameController.text.trim();
        final signupEmail = _signupEmailController.text.trim();
        final signupPassword = _signupPasswordController.text;
        final signupConfirmPassword = _signupConfirmPasswordController.text;
        if (signupPassword != signupConfirmPassword) {
          throw 'Passwords do not match';
        }
        if (_role == 'child' && _childNoOwnEmail) {
          final ok = await _ensureDomainIsValid(
            _parentEmailController.text.trim(),
            label: 'parent',
          );
          if (!ok) return;
          final cred = await _authService.signUpChildNoOwnEmail(
            parentEmail: _parentEmailController.text,
            username: signupUsername,
            password: signupPassword,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Welcome! Your parent email is saved for safety notices.',
                ),
                backgroundColor: Colors.green,
              ),
            );
            final role = await _authService.readRole(cred.user?.uid);
            if (!mounted) return;
            Navigator.pushReplacementNamed(
              context,
              role == 'parent'
                  ? AppRoutes.parentApprovals
                  : AppRoutes.community,
            );
          }
        } else {
          final ok = await _ensureDomainIsValid(signupEmail, label: '');
          if (!ok) return;
          await _authService.signUp(
            signupEmail,
            signupPassword,
            username: signupUsername,
            role: _role,
            parentEmail:
                _role == 'child' ? _parentEmailController.text.trim() : null,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Verification email sent. Please check your inbox.'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pushReplacementNamed(context, AppRoutes.verifyEmail);
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email first';
      });
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() {
        _errorMessage = 'Enter a valid email address';
      });
      return;
    }
    final domainStatus = await AuthService.hasResolvableEmailDomain(email);
    if (domainStatus == false) {
      setState(() {
        _errorMessage = 'Incorrect email domain. Please check and try again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset link sent to your email.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        child: Stack(
          children: [
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipPath(
                clipper: WaveClipperOne(reverse: true, flip: true),
                child: Container(
                  height: 60,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                    const SizedBox(height: 20),
                    if (widget.isLogin)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => setState(() {
                                    _childUsernameLogin = !_childUsernameLogin;
                                    _errorMessage = null;
                                    _emailFieldErrors[_kLoginEmailField] = null;
                                    _emailFieldErrors[_kChildLoginParentEmailField] =
                                        null;
                                  }),
                          child: Text(
                            _childUsernameLogin
                                ? 'Use email & password instead'
                                : 'Child: sign in with parent email + username',
                            style: const TextStyle(
                              color: Color(0xFF7B1FA2),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    if (!widget.isLogin)
                      TextFormField(
                        controller: _signupUsernameController,
                        decoration: const InputDecoration(
                          hintText: 'User Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (!widget.isLogin &&
                              (value == null || value.isEmpty)) {
                            return 'Please enter a username';
                          }
                          if (!widget.isLogin &&
                              _role == 'child' &&
                              _childNoOwnEmail &&
                              AuthService.normalizeChildUsername(value ?? '')
                                      .length <
                                  3) {
                            return 'Username: at least 3 letters or numbers';
                          }
                          return null;
                        },
                      ),
                    if (!widget.isLogin) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _RoleOption(
                              icon: Icons.face,
                              label: 'Child',
                              selected: _role == 'child',
                              onTap: () => setState(() {
                                _role = 'child';
                                _emailFieldErrors[_kSignupEmailField] = null;
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _RoleOption(
                              icon: Icons.family_restroom,
                              label: 'Parent',
                              selected: _role == 'parent',
                              onTap: () => setState(() {
                                _role = 'parent';
                                _childNoOwnEmail = false;
                                _emailFieldErrors[_kSignupParentEmailField] = null;
                                _emailFieldErrors[_kSignupEmailField] = null;
                              }),
                            ),
                          ),
                        ],
                      ),
                      if (_role == 'child') ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _parentEmailController,
                          onChanged: (value) => _onEmailChangedRealtime(
                            fieldKey: _kSignupParentEmailField,
                            value: value,
                            label: 'parent',
                          ),
                          decoration: InputDecoration(
                            hintText: 'Parent Email',
                            prefixIcon: const Icon(Icons.family_restroom),
                            errorText: _emailFieldErrors[_kSignupParentEmailField],
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (_role != 'child') return null;
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter parent email';
                            }
                            if (!_isValidEmail(value)) {
                              return 'Enter a valid parent email';
                            }
                            final liveError =
                                _emailFieldErrors[_kSignupParentEmailField];
                            if (liveError != null) return liveError;
                            return null;
                          },
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () => setState(() {
                                      _childNoOwnEmail = !_childNoOwnEmail;
                                      _errorMessage = null;
                                    }),
                            icon: Icon(
                              _childNoOwnEmail
                                  ? Icons.check_circle_outline
                                  : Icons.touch_app_outlined,
                              size: 18,
                            ),
                            label: Text(
                              _childNoOwnEmail
                                  ? 'I have my own email'
                                  : "Tap here: I don't have my own email (use parent email + username)",
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              side: BorderSide(
                                color: const Color(0xFF7B1FA2).withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              foregroundColor: const Color(0xFF7B1FA2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                    if (widget.isLogin && _childUsernameLogin) ...[
                      TextFormField(
                        controller: _childLoginParentEmailController,
                        onChanged: (value) => _onEmailChangedRealtime(
                          fieldKey: _kChildLoginParentEmailField,
                          value: value,
                          label: 'parent',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: "Parent's email",
                          prefixIcon: const Icon(Icons.family_restroom),
                          errorText:
                              _emailFieldErrors[_kChildLoginParentEmailField],
                        ),
                        validator: (value) {
                          if (!_childUsernameLogin) return null;
                          if (value == null || value.trim().isEmpty) {
                            return "Enter your parent's email";
                          }
                          if (!_isValidEmail(value)) {
                            return 'Enter a valid email';
                          }
                          final liveError =
                              _emailFieldErrors[_kChildLoginParentEmailField];
                          if (liveError != null) return liveError;
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _childLoginUsernameController,
                        textCapitalization: TextCapitalization.none,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          hintText: 'Your username',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (!_childUsernameLogin) return null;
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your username';
                          }
                          if (AuthService.normalizeChildUsername(value)
                                  .length <
                              3) {
                            return 'At least 3 letters or numbers';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                    ] else if (widget.isLogin) ...[
                      TextFormField(
                        controller: _emailController,
                        onChanged: (value) => _onEmailChangedRealtime(
                          fieldKey: _kLoginEmailField,
                          value: value,
                          label: '',
                        ),
                        decoration: InputDecoration(
                          hintText: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          errorText: _emailFieldErrors[_kLoginEmailField],
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (_childUsernameLogin) return null;
                          if (value == null || value.isEmpty) {
                            return 'Please enter an email';
                          }
                          if (!_isValidEmail(value)) {
                            return 'Enter a valid email address';
                          }
                          final liveError = _emailFieldErrors[_kLoginEmailField];
                          if (liveError != null) return liveError;
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                    ] else if (!widget.isLogin &&
                        (_role == 'parent' ||
                            (_role == 'child' && !_childNoOwnEmail))) ...[
                      TextFormField(
                        controller: _signupEmailController,
                        onChanged: (value) => _onEmailChangedRealtime(
                          fieldKey: _kSignupEmailField,
                          value: value,
                          label: '',
                        ),
                        decoration: InputDecoration(
                          hintText: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          errorText: _emailFieldErrors[_kSignupEmailField],
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an email';
                          }
                          if (!_isValidEmail(value)) {
                            return 'Enter a valid email address';
                          }
                          final liveError = _emailFieldErrors[_kSignupEmailField];
                          if (liveError != null) return liveError;
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextFormField(
                      controller:
                          widget.isLogin ? _passwordController : _signupPasswordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        final passwordRegex =
                            RegExp(r'^.{6,}$'); // At least 6 characters
                        if (!widget.isLogin && !passwordRegex.hasMatch(value)) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    if (!widget.isLogin) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _signupConfirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          hintText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value != _signupPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (widget.isLogin && !_childUsernameLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _sendPasswordReset,
                          child: const Text("Forget Password?",
                              style: TextStyle(color: Colors.black54)),
                        ),
                      ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(_errorMessage!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12)),
                      ),
                    const SizedBox(height: 19),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 40),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(widget.isLogin ? 'Login' : 'SignUp',
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.white)),
                    ),
                  ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF7B1FA2) : Colors.grey.shade600;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color:
              selected ? const Color(0xFF7B1FA2).withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF7B1FA2) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
