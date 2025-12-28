class PlateValidator {
  // Regex for Indian Vehicle Plates
  // Formats handled: 
  // AA 00 AA 0000 (Standard)
  // AA 00 A 0000 (Old/Commercial sometimes)
  // AA 00 0000 (Very old, might need broadening if required)
  // DL 1C AA 0000 (Delhi specific) -> This regex might need tweaking for specific states if strictness is required.
  // Current strict regex from rules: ^[A-Z]{2}[0-9]{1,2}[A-Z]{1,2}[0-9]{4}$
  
  static final RegExp _indianPlateRegex = RegExp(r'^[A-Z]{2}[0-9]{1,2}[A-Z]{1,2}[0-9]{4}$');

  /// Validates if the given string is a valid Indian number plate.
  static bool isValidIndianPlate(String plate) {
    // Remove all spaces and dashes before checking
    String clean = plate.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return _indianPlateRegex.hasMatch(clean);
  }

  /// Cleans raw OCR text to extract a potential plate number.
  /// - Converts to Uppercase
  /// - Removes special characters (spaces, dashes, dots)
  /// - Corrects common OCR errors (e.g., 'O' -> '0', 'I' -> '1' in number positions if logic allows, 
  ///   but simple cleaning is safer at this stage).
  static String cleanOCRResult(String raw) {
    String upper = raw.toUpperCase();
    
    // Remove anything that is not A-Z or 0-9
    String clean = upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    
    // Return the cleaned string which can then be passed to isValidIndianPlate
    return clean;
  }
  
  /// Formats a clean plate into readable format (AA 00 AA 0000) for display (Optional)
  static String formatPlate(String cleanPlate) {
    if (!isValidIndianPlate(cleanPlate)) return cleanPlate;
    // Basic formatting logic could go here
    return cleanPlate;
  }
}
