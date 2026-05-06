import '../../auth/services/auth_service.dart';

class FormValidationHelper {
  static String? requiredField(
    String? value, {
    required String fieldName,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    return null;
  }

  static String? email(String? value, {String label = 'an email'}) {
    final requiredResult = requiredField(value, fieldName: label);
    if (requiredResult != null) return requiredResult;
    if (!AuthService.isValidEmailFormat(value!.trim())) {
      return 'Enter a valid ${label == 'an email' ? 'email address' : label}';
    }
    return null;
  }

  static String? minLength(
    String? value, {
    required int min,
    required String fieldName,
  }) {
    final requiredResult = requiredField(value, fieldName: fieldName);
    if (requiredResult != null) return requiredResult;
    if (value!.length < min) {
      return '${_capitalize(fieldName)} must be at least $min characters';
    }
    return null;
  }

  static String? confirmPassword({
    required String? value,
    required String originalPassword,
  }) {
    if ((value ?? '') != originalPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
