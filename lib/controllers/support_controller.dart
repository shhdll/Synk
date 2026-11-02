import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/support_model.dart';

class SupportController extends ChangeNotifier {
  SupportController({SupportModel? model}) : _model = model ?? SupportModel();

  final SupportModel _model;

  SupportCategory _category = SupportCategory.problem;
  String _message = '';
  bool _isSending = false;

  SupportCategory get category => _category;
  bool get isSending => _isSending;
  String? get email => _model.userEmail;
  int get length => _message.trim().length;
  bool get canSend =>
      !_isSending &&
      length >= SupportModel.minLength &&
      length <= SupportModel.maxLength;

  void setCategory(SupportCategory value) {
    _category = value;
    notifyListeners();
  }

  void setMessage(String value) {
    _message = value;
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
      return await _model.send(
        category: _category,
        message: _message,
        appVersion: version,
      );
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }
}
