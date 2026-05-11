/// Supported IDz document types.
enum DocumentType {
  algerianNationalId('algerian_national_id'),
  algerianDrivingLicense('algerian_driving_license');

  final String wireValue;
  const DocumentType(this.wireValue);

  static DocumentType? fromWireValue(String? value) {
    for (final type in DocumentType.values) {
      if (type.wireValue == value) return type;
    }
    return null;
  }

  static DocumentType? fromWire(String? value) => fromWireValue(value);
}
