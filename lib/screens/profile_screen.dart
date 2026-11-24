import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/circle_crop_screen.dart';
import '../widgets/app_toast.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _CountryCode {
  final String name;
  final String flag;
  final String dialCode;
  final int minDigits;
  final int maxDigits;
  final String pattern;

  const _CountryCode({
    required this.name,
    required this.flag,
    required this.dialCode,
    required this.minDigits,
    required this.maxDigits,
    required this.pattern,
  });

  bool isValid(String input) => RegExp(pattern).hasMatch(input);
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  String? _avatarBase64;
  bool _isLoading = true;
  bool _isSaving = false;

  // Validation error strings
  String? _nameError;
  String? _phoneError;

  // Country code list & selected country code
  static const List<_CountryCode> _countryCodes = [
    _CountryCode(
      name: 'India',
      flag: '🇮🇳',
      dialCode: '+91',
      minDigits: 10,
      maxDigits: 10,
      pattern: r'^[6-9]\d{9}$',
    ),
    _CountryCode(
      name: 'Indonesia',
      flag: '🇮🇩',
      dialCode: '+62',
      minDigits: 9,
      maxDigits: 13,
      pattern: r'^[8][1-9]\d{7,11}$',
    ),
    _CountryCode(
      name: 'United States',
      flag: '🇺🇸',
      dialCode: '+1',
      minDigits: 10,
      maxDigits: 10,
      pattern: r'^[2-9]\d{9}$',
    ),
    _CountryCode(
      name: 'United Kingdom',
      flag: '🇬🇧',
      dialCode: '+44',
      minDigits: 10,
      maxDigits: 10,
      pattern: r'^[1-9]\d{9}$',
    ),
    _CountryCode(
      name: 'United Arab Emirates',
      flag: '🇦🇪',
      dialCode: '+971',
      minDigits: 9,
      maxDigits: 9,
      pattern: r'^[5]\d{8}$',
    ),
    _CountryCode(
      name: 'Singapore',
      flag: '🇸🇬',
      dialCode: '+65',
      minDigits: 8,
      maxDigits: 8,
      pattern: r'^[89]\d{7}$',
    ),
    _CountryCode(
      name: 'Germany',
      flag: '🇩🇪',
      dialCode: '+49',
      minDigits: 10,
      maxDigits: 11,
      pattern: r'^[1-9]\d{9,10}$',
    ),
    _CountryCode(
      name: 'Canada',
      flag: '🇨🇦',
      dialCode: '+1',
      minDigits: 10,
      maxDigits: 10,
      pattern: r'^[2-9]\d{9}$',
    ),
    _CountryCode(
      name: 'Australia',
      flag: '🇦🇺',
      dialCode: '+61',
      minDigits: 9,
      maxDigits: 9,
      pattern: r'^[4]\d{8}$',
    ),
  ];

  late _CountryCode _selectedCountryCode;

  @override
  void initState() {
    super.initState();
    _selectedCountryCode = _countryCodes.first; // Defaults to India +91
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  /// Converts words to Title Case / Camel Casing (e.g., "varun kumar" -> "Varun Kumar")
  String _toCamelCase(String text) {
    if (text.trim().isEmpty) return '';
    return text
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _emailController.text = user.email ?? '';
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      _nameController.text = _toCamelCase(user.displayName!);
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final first = (data['firstName'] ?? '').toString().trim();
        final last = (data['lastName'] ?? '').toString().trim();
        final fullName = '$first $last'.trim();
        if (fullName.isNotEmpty && _nameController.text.isEmpty) {
          _nameController.text = _toCamelCase(fullName);
        }

        // Restore country code & phone
        final savedDialCode = (data['dialCode'] ?? '').toString().trim();
        if (savedDialCode.isNotEmpty) {
          final matched = _countryCodes.firstWhere(
            (c) => c.dialCode == savedDialCode,
            orElse: () => _countryCodes.first,
          );
          _selectedCountryCode = matched;
        }

        _phoneController.text = (data['phone'] ?? '').toString();
        _dobController.text = (data['dob'] ?? '').toString();

        final avatar = data['avatarBase64'] as String?;
        if (avatar != null && avatar.isNotEmpty) {
          _avatarBase64 = avatar;
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickAndChangeAvatar() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF2563EB)),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _processPickedImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _processPickedImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPickedImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (file == null) return;
      final rawBytes = await file.readAsBytes();

      if (!mounted) return;

      // 1. Open Grid & Circle Alignment Crop Screen
      final croppedBytes = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(
          builder: (_) => CircleCropScreen(imageBytes: rawBytes),
        ),
      );

      if (croppedBytes != null && croppedBytes is List<int>) {
        final base64 = await _profileService.saveAvatarBytes(croppedBytes);
        if (base64 != null && mounted) {
          setState(() => _avatarBase64 = base64);
          AppToast.success(context, 'Profile photo updated!');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to update picture: $e');
      }
    }
  }

  Future<void> _selectDateOfBirth() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    DateTime initial = DateTime(2000, 1, 1);
    if (_dobController.text.isNotEmpty) {
      try {
        final parts = _dobController.text.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          initial = DateTime(year, month, day);
        }
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select Date of Birth',
      cancelText: 'Cancel',
      confirmText: 'Confirm',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF2563EB),
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF2563EB),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF1F2937),
                  ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final day = picked.day.toString().padLeft(2, '0');
      final month = picked.month.toString().padLeft(2, '0');
      final year = picked.year.toString();
      setState(() {
        _dobController.text = '$day/$month/$year';
      });
    }
  }

  void _showCountryCodePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Country Code',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _countryCodes.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final item = _countryCodes[index];
                  final isSelected = item.dialCode == _selectedCountryCode.dialCode &&
                      item.name == _selectedCountryCode.name;
                  return ListTile(
                    leading: Text(item.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(item.name),
                    trailing: Text(
                      item.dialCode,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? const Color(0xFF2563EB) : Colors.grey,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedCountryCode = item;
                        _phoneError = null; // Re-validate on next submit
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _validateInputs() {
    bool isValid = true;
    final name = _nameController.text.trim();
    final rawPhone = _phoneController.text.trim().replaceAll(RegExp(r'[\s\-]'), '');

    // 1. Name Validation: min 3, max 30 chars
    if (name.length < 3) {
      setState(() => _nameError = 'Name must be at least 3 characters');
      isValid = false;
    } else if (name.length > 30) {
      setState(() => _nameError = 'Name cannot exceed 30 characters');
      isValid = false;
    } else {
      setState(() => _nameError = null);
    }

    // 2. Phone Validation according to Country Code Regex
    if (rawPhone.isNotEmpty) {
      if (!_selectedCountryCode.isValid(rawPhone)) {
        setState(() {
          _phoneError = 'Invalid ${_selectedCountryCode.name} number (${_selectedCountryCode.minDigits} digits)';
        });
        isValid = false;
      } else {
        setState(() => _phoneError = null);
      }
    } else {
      setState(() => _phoneError = null);
    }

    return isValid;
  }

  Future<void> _saveChanges() async {
    final user = _authService.currentUser;
    if (user == null) return;

    if (!_validateInputs()) return;

    setState(() => _isSaving = true);

    try {
      final formattedName = _toCamelCase(_nameController.text.trim());
      _nameController.text = formattedName;

      final nameParts = formattedName.split(' ');
      final first = nameParts.isNotEmpty ? nameParts.first : '';
      final last = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      await user.updateDisplayName(formattedName);

      // Persist to Cloud Firestore: name, phone, dialCode, dob
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'firstName': first,
        'lastName': last,
        'displayName': formattedName,
        'dialCode': _selectedCountryCode.dialCode,
        'phone': _phoneController.text.trim(),
        'dob': _dobController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        AppToast.success(context, 'Profile updated successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Error saving changes: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final inputBg = isDark ? const Color(0xFF262626) : const Color(0xFFFAFAFA);
    final borderColor = isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final labelColor = isDark ? Colors.grey[400]! : const Color(0xFF374151);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Completion Banner
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: 0.8,
                                    minHeight: 6,
                                    backgroundColor: isDark
                                        ? const Color(0xFF333333)
                                        : const Color(0xFFE5E7EB),
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'You only need 20% more!',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Complete your data, and get our voucher of free shipping fee!',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 2. Profile Avatar with Edit Badge
                          Center(
                            child: Stack(
                              children: [
                                Container(
                                  width: 105,
                                  height: 105,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark
                                        ? const Color(0xFF2A2A2A)
                                        : const Color(0xFFE2E8F0),
                                    border: Border.all(
                                      color: isDark ? Colors.white12 : Colors.white,
                                      width: 3,
                                    ),
                                    image: _avatarBase64 != null
                                        ? DecorationImage(
                                            image: MemoryImage(base64Decode(_avatarBase64!)),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _avatarBase64 == null
                                      ? Center(
                                          child: Text(
                                            _nameController.text.isNotEmpty
                                                ? _nameController.text[0].toUpperCase()
                                                : 'U',
                                            style: TextStyle(
                                              fontSize: 38,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: _pickAndChangeAvatar,
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.edit_outlined,
                                        color: Color(0xFF2563EB),
                                        size: 19,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // 3. Name Field with 3-30 chars constraint & Camel-casing helper
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildFieldLabel('Name', labelColor),
                              Text(
                                '${_nameController.text.length}/30',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _nameController,
                            hint: 'Your full name',
                            maxLength: 30,
                            errorText: _nameError,
                            isDark: isDark,
                            inputBg: inputBg,
                            borderColor: borderColor,
                            textColor: textColor,
                            onChanged: (val) {
                              setState(() {
                                if (val.length >= 3 && val.length <= 30) {
                                  _nameError = null;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 18),

                          // 4. Email Address with VERIFIED badge
                          Row(
                            children: [
                              _buildFieldLabel('Email Address', labelColor),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check,
                                      size: 13,
                                      color: Color(0xFF2563EB),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'VERIFIED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2563EB),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _emailController,
                            hint: 'your.email@example.com',
                            readOnly: true,
                            isDark: isDark,
                            inputBg: inputBg,
                            borderColor: borderColor,
                            textColor: isDark ? Colors.grey[300]! : const Color(0xFF4B5563),
                          ),
                          const SizedBox(height: 18),

                          // 5. Phone Number with Country Code selector + regex validation
                          _buildFieldLabel('Phone Number', labelColor),
                          const SizedBox(height: 8),
                          _buildPhoneField(
                            isDark: isDark,
                            inputBg: inputBg,
                            borderColor: borderColor,
                            textColor: textColor,
                          ),
                          if (_phoneError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                _phoneError!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                              ),
                            ),
                          const SizedBox(height: 18),

                          // 6. Date of Birth with Calendar Picker
                          _buildFieldLabel('Date of Birth', labelColor),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _selectDateOfBirth,
                            child: AbsorbPointer(
                              child: _buildTextField(
                                controller: _dobController,
                                hint: 'dd/mm/yyyy',
                                isDark: isDark,
                                inputBg: inputBg,
                                borderColor: borderColor,
                                textColor: textColor,
                                suffixIcon: Icon(
                                  Icons.calendar_month_rounded,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF2563EB),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // Bottom "Saved Change" Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: scaffoldBg,
                      border: Border(
                        top: BorderSide(
                          color: isDark ? const Color(0xFF222222) : const Color(0xFFF3F4F6),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(27),
                          ),
                        ),
                        onPressed: _isSaving ? null : _saveChanges,
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Saved Change',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFieldLabel(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    required Color inputBg,
    required Color borderColor,
    required Color textColor,
    bool readOnly = false,
    int? maxLength,
    String? errorText,
    ValueChanged<String>? onChanged,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: errorText != null ? Colors.redAccent : borderColor,
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            maxLength: maxLength,
            onChanged: onChanged,
            keyboardType: keyboardType,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              counterText: '',
              hintText: hint,
              suffixIcon: suffixIcon,
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[600] : const Color(0xFF9CA3AF),
                fontSize: 15,
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildPhoneField({
    required bool isDark,
    required Color inputBg,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _phoneError != null ? Colors.redAccent : borderColor,
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          // Country Code Dropdown Trigger
          GestureDetector(
            onTap: _showCountryCodePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Text(_selectedCountryCode.flag, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text(
                    _selectedCountryCode.dialCode,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 24,
            width: 1,
            color: borderColor,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          // Phone Digits Input
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              onChanged: (_) {
                if (_phoneError != null) setState(() => _phoneError = null);
              },
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Enter phone number',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[600] : const Color(0xFF9CA3AF),
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
