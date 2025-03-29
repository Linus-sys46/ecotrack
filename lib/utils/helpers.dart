// utilty functions

String? validateEmail(String email) {
  if (email.isEmpty) return 'Email cannot be empty';
  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
  if (!emailRegex.hasMatch(email)) return 'Enter a valid email';
  return null;
}

String formatDate(DateTime date) {
  return "${date.day}/${date.month}/${date.year}";
}
