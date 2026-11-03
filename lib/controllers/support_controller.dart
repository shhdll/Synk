import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/support_model.dart';

class SupportController extends ChangeNotifier {
  SupportController({SupportModel? model}) : _model = model ?? SupportModel();

  final SupportModel _model;

  SupportCategory _category = SupportCategory.problem;
  String _message = '';
  bool _isSending = false;
  bool _sent = false;
  String? _replyTo;
  final List<XFile> _screenshots = [];

  SupportCategory get category => _category;
  bool get isSending => _isSending;
  // True once the message went through; the screen shows the thank-you.
  bool get sent => _sent;
  int get length => _message.trim().length;
  bool get canSend => length >= SupportModel.minLength && !_isSending;

  // Where the team replies: the account email unless the user changed it.
  String? get email => _replyTo ?? _model.userEmail;

  // Screenshots can go with any kind of message.
  List<XFile> get screenshots => List.unmodifiable(_screenshots);
  bool get canAddScreenshot =>
      _screenshots.length < SupportModel.maxScreenshots;

  void setCategory(SupportCategory value) {
    _category = value;
    notifyListeners();
  }

  void setMessage(String value) {
    _message = value;
    notifyListeners();
  }

  void setReplyTo(String value) {
    final trimmed = value.trim();
    _replyTo = trimmed.isEmpty || trimmed == _model.userEmail ? null : trimmed;
    notifyListeners();
  }

  Future<void> addScreenshot() async {
    if (!canAddScreenshot) return;
    final XFile? file;
    try {
      file = await _model.pickScreenshot();
    } catch (error) {
      debugPrint('SYNK: screenshot picker failed: $error');
      return;
    }
    if (file == null || !canAddScreenshot) return;
    _screenshots.add(file);
    notifyListeners();
  }

  void removeScreenshot(XFile file) {
    _screenshots.remove(file);
    notifyListeners();
  }

  Future<SupportResult> send() async {
    _isSending = true;
    notifyListeners();
    try {
      String? version;
      try {
        final info = await PackageInfo.fromPlatform();
        version = '${info.version} (${info.buildNumber})';
      } catch (_) {}

      final paths = <String>[];
      for (final file in _screenshots) {
        try {
          paths.add(await _model.uploadScreenshot(file));
        } catch (error) {
          // The message still goes, just without that screenshot.
          debugPrint('SYNK: screenshot upload failed: $error');
        }
      }

      final result = await _model.send(
        category: _category,
        message: _message,
        appVersion: version,
        screenshots: paths,
        replyTo: _replyTo,
      );
      _sent = result == SupportResult.sent;
      return result;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }
}
