class PlateValidator {
  
  // Strict regex for Indian Vehicle Plates:
  // e.g. MH12AB1234
  // 2 uppercase letters + 1-2 digits + 1-2 uppercase letters + 4 digits
  static final RegExp _indianPlateRegex = RegExp(r'^[A-Z]{2}[0-9]{1,2}[A-Z]{1,2}[0-9]{4}$');

  /// Validates if the given string is a valid Indian number plate.
  static bool isValidIndianPlate(String plate) {
    if (plate.isEmpty) return false;
    // Just check the pattern directly on the input (assuming it's already cleaned or strict format)
    return _indianPlateRegex.hasMatch(plate);
  }

  /// Cleans raw OCR text to extract a potential plate number.
  /// - Converts to Uppercase
  /// - Removes spaces and special characters
  static String cleanPlateText(String text) {
    if (text.isEmpty) return '';
    
    // Uppercase
    String upper = text.toUpperCase();
    
    // Remove anything that is not A-Z or 0-9
    String clean = upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    
    return clean;
  }
}
