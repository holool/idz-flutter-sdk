import 'dart:async';

import 'package:dmrtd/dmrtd.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Data extracted from the NFC chip of an ID card.
class NfcResult {
  final String firstName;
  final String lastName;
  final String documentNumber;
  final String country;
  final String nationality;
  final String gender;
  final DateTime dateOfBirth;
  final DateTime dateOfExpiry;
  final String? personalNumber;
  final Uint8List? faceImage;

  /// Whether passive authentication (SOD signature + DG hash) was verified.
  /// `null` when not attempted — current reader does not run PA.
  final bool? passiveAuthenticationPassed;

  /// Whether chip / active authentication was verified.
  /// `null` when not attempted — current reader does not run CA/AA.
  final bool? chipAuthenticationPassed;

  const NfcResult({
    required this.firstName,
    required this.lastName,
    required this.documentNumber,
    required this.country,
    required this.nationality,
    required this.gender,
    required this.dateOfBirth,
    required this.dateOfExpiry,
    this.personalNumber,
    this.faceImage,
    this.passiveAuthenticationPassed,
    this.chipAuthenticationPassed,
  });

  /// Serialize to the shape the backend expects in the
  /// `nfc_card_reading` multipart form field. See
  /// [IdzApiClient.verifyDocument] (and siblings) `nfcCardReading`.
  ///
  /// Optional fields are omitted when null so missing data does not
  /// surface as a literal `null` in the stored JSON.
  Map<String, dynamic> toApiJson() {
    final iso = DateFormat('yyyy-MM-dd');
    return <String, dynamic>{
      'documentNumber': documentNumber,
      'givenNames': firstName,
      'surname': lastName,
      'dateOfBirth': iso.format(dateOfBirth),
      'dateOfExpiry': iso.format(dateOfExpiry),
      'sex': gender,
      if (personalNumber != null && personalNumber!.isNotEmpty)
        'personalNumber': personalNumber,
      if (nationality.isNotEmpty) 'nationality': nationality,
      if (country.isNotEmpty) 'issuingCountry': country,
      if (passiveAuthenticationPassed != null)
        'passive_authentication_passed': passiveAuthenticationPassed,
      if (chipAuthenticationPassed != null)
        'chip_authentication_passed': chipAuthenticationPassed,
    };
  }
}

enum _NfcState { form, reading, result }

/// Screen that reads an ID card's NFC chip using BAC authentication.
///
/// Extracts MRZ data (DG1) and face photo (DG2) from the chip.
/// Requires document number, date of birth, and expiry date as BAC key.
class NfcReadingScreen extends StatefulWidget {
  final void Function(NfcResult data) onComplete;
  final VoidCallback onSkip;
  final VoidCallback? onCancel;

  /// Pre-filled MRZ data for BAC authentication.
  /// When all three are provided, the form is skipped and reading starts
  /// automatically as soon as NFC is available.
  final String? documentNumber;
  final DateTime? dateOfBirth;
  final DateTime? dateOfExpiry;

  const NfcReadingScreen({
    super.key,
    required this.onComplete,
    required this.onSkip,
    this.onCancel,
    this.documentNumber,
    this.dateOfBirth,
    this.dateOfExpiry,
  });

  @override
  State<NfcReadingScreen> createState() => _NfcReadingScreenState();
}

class _NfcReadingScreenState extends State<NfcReadingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _docNumberCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _doeCtrl = TextEditingController();

  _NfcState _state = _NfcState.form;
  bool _isNfcAvailable = false;
  String _statusMessage = '';
  NfcResult? _nfcResult;

  late Timer _nfcPoller;

  bool get _hasPrefilledData =>
      widget.documentNumber != null &&
      widget.dateOfBirth != null &&
      widget.dateOfExpiry != null;

  @override
  void initState() {
    super.initState();
    _checkNfc();
    _nfcPoller = Timer.periodic(const Duration(seconds: 3), (_) => _checkNfc());

    // Auto-start reading when MRZ data is pre-filled
    if (_hasPrefilledData) {
      _docNumberCtrl.text = widget.documentNumber!;
      _dobCtrl.text = DateFormat.yMd().format(widget.dateOfBirth!);
      _doeCtrl.text = DateFormat.yMd().format(widget.dateOfExpiry!);
      // Wait for NFC check then auto-start
      _autoStartWhenReady();
    }
  }

  Future<void> _autoStartWhenReady() async {
    // Give NFC status check time to complete
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted && _isNfcAvailable) {
      _readCard();
    }
    // If not available yet, the poller will keep checking.
    // We listen for NFC becoming available in _checkNfc.
  }

  @override
  void dispose() {
    _nfcPoller.cancel();
    _docNumberCtrl.dispose();
    _dobCtrl.dispose();
    _doeCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkNfc() async {
    try {
      final status = await NfcProvider.nfcStatus;
      if (mounted) {
        final wasAvailable = _isNfcAvailable;
        setState(() => _isNfcAvailable = status == NfcStatus.enabled);
        // Auto-start when NFC becomes available and we have pre-filled data
        if (!wasAvailable &&
            _isNfcAvailable &&
            _hasPrefilledData &&
            _state == _NfcState.form) {
          _readCard();
        }
      }
    } on PlatformException {
      if (mounted) setState(() => _isNfcAvailable = false);
    }
  }

  DateTime? _parseDateCtrl(TextEditingController ctrl) {
    if (ctrl.text.isEmpty) return null;
    return DateFormat.yMd().parse(ctrl.text);
  }

  Future<void> _pickDate(
    TextEditingController ctrl, {
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      firstDate: firstDate,
      initialDate: _parseDateCtrl(ctrl) ?? lastDate,
      lastDate: lastDate,
    );
    if (picked != null && mounted) {
      ctrl.text = DateFormat.yMd().format(picked);
    }
  }

  Future<void> _readCard() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final docNumber = _docNumberCtrl.text.trim();
    final dob = _parseDateCtrl(_dobCtrl)!;
    final doe = _parseDateCtrl(_doeCtrl)!;

    setState(() {
      _state = _NfcState.reading;
      _statusMessage = 'Waiting for ID card...';
    });

    final nfc = NfcProvider();
    try {
      await nfc.connect(
        iosAlertMessage: 'Hold your phone near your ID card...',
      );
      final passport = Passport(nfc);

      // Try reading EF.CardAccess (used for PACE). Most BAC-only cards
      // (like Algerian IDs) don't have it and the read can hang, so
      // we wrap it in a short timeout.
      _setStatus('Reading card access...');
      try {
        await passport.readEfCardAccess().timeout(
          const Duration(seconds: 4),
          onTimeout: () =>
              throw TimeoutException('EF.CardAccess not available'),
        );
      } catch (_) {
        // Card may not have EF.CardAccess — skip and proceed to BAC.
      }

      _setStatus('Authenticating...');
      final bacKey = DBAKey(docNumber, dob, doe);
      await passport.startSession(bacKey);

      _setStatus('Reading data groups...');
      final efcom = await passport.readEfCOM();

      EfDG1? dg1;
      if (efcom.dgTags.contains(EfDG1.TAG)) {
        _setStatus('Reading MRZ data...');
        dg1 = await passport.readEfDG1();
      }

      EfDG2? dg2;
      if (efcom.dgTags.contains(EfDG2.TAG)) {
        _setStatus('Reading face image...');
        dg2 = await passport.readEfDG2();
      }

      await nfc.disconnect(iosAlertMessage: 'Finished reading card');

      if (dg1 == null) {
        throw Exception('Could not read MRZ data from card');
      }

      final optional = dg1.mrz.optionalData.trim();
      final result = NfcResult(
        firstName: dg1.mrz.firstName,
        lastName: dg1.mrz.lastName,
        documentNumber: dg1.mrz.documentNumber,
        country: dg1.mrz.country,
        nationality: dg1.mrz.nationality,
        gender: dg1.mrz.gender,
        dateOfBirth: dg1.mrz.dateOfBirth,
        dateOfExpiry: dg1.mrz.dateOfExpiry,
        personalNumber: optional.isEmpty ? null : optional,
        faceImage: dg2?.imageData as Uint8List?,
      );

      if (mounted) {
        setState(() {
          _nfcResult = result;
          _state = _NfcState.result;
        });
      }
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      String alertMsg = 'Failed to read card. Please try again.';
      if (e is PassportError && msg.contains('security status not satisfied')) {
        alertMsg = 'Authentication failed. Check document number and dates.';
      } else if (msg.contains('timeout')) {
        alertMsg = 'Timeout — hold your phone steady near the card.';
      } else if (msg.contains('tag was lost')) {
        alertMsg = 'Lost contact with card. Hold steady and try again.';
      } else if (msg.contains('invalidated by user')) {
        alertMsg = 'Cancelled.';
      }

      try {
        await nfc.disconnect(iosErrorMessage: alertMsg);
      } catch (_) {}

      if (mounted) {
        setState(() => _state = _NfcState.form);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(alertMsg)));
      }
    }
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _statusMessage = msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Read ID Card (NFC)'),
        leading: widget.onCancel != null
            ? IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close),
              )
            : null,
        actions: [
          TextButton(
            onPressed: _state == _NfcState.reading ? null : widget.onSkip,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: switch (_state) {
        _NfcState.form => _buildForm(),
        _NfcState.reading => _buildReading(),
        _NfcState.result => _buildResult(),
      },
    );
  }

  Widget _buildForm() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.nfc, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'NFC Chip Reading',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the details printed on your ID card, then hold '
              'your phone near the card to read the chip.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isNfcAvailable ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: _isNfcAvailable ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  _isNfcAvailable ? 'NFC is available' : 'NFC not available',
                  style: TextStyle(
                    color: _isNfcAvailable ? Colors.green : Colors.red,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _docNumberCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Document Number',
                hintText: 'e.g. 123456789',
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                LengthLimitingTextInputFormatter(14),
              ],
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dobCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Date of Birth',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () {
                final now = DateTime.now();
                _pickDate(
                  _dobCtrl,
                  firstDate: DateTime(now.year - 100),
                  lastDate: DateTime(now.year - 10),
                );
              },
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _doeCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Date of Expiry',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () {
                final now = DateTime.now();
                _pickDate(
                  _doeCtrl,
                  firstDate: DateTime(now.year - 10),
                  lastDate: DateTime(now.year + 15),
                );
              },
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isNfcAvailable ? _readCard : null,
              icon: const Icon(Icons.contactless),
              label: const Text('Read Card'),
            ),
            if (!_isNfcAvailable) ...[
              const SizedBox(height: 12),
              Text(
                'Enable NFC in your device settings to read the card chip.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 32),
            Icon(Icons.nfc, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Hold your phone near the ID card and keep it steady.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final result = _nfcResult!;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.check_circle, size: 48, color: Colors.green[600]),
          const SizedBox(height: 12),
          Text(
            'Card Read Successfully',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (result.faceImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                result.faceImage!,
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: Colors.grey[200],
                  child: const Center(child: Text('Image not available')),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoRow('Name', '${result.firstName} ${result.lastName}'),
                  _infoRow('Document No.', result.documentNumber),
                  _infoRow('Nationality', result.nationality),
                  _infoRow('Gender', result.gender),
                  _infoRow(
                    'Date of Birth',
                    DateFormat.yMMMd().format(result.dateOfBirth),
                  ),
                  _infoRow(
                    'Date of Expiry',
                    DateFormat.yMMMd().format(result.dateOfExpiry),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => widget.onComplete(result),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continue to Camera'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
