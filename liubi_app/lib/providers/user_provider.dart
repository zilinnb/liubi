import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class UserProvider with ChangeNotifier {
  String _token = '';
  User? _userInfo;

  String get token => _token;
  User? get userInfo => _userInfo;
  bool get isLoggedIn => _token.isNotEmpty;

  UserProvider() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final savedToken = await StorageService.getToken();
    final savedInfo = await StorageService.getUserInfo();
    if (savedToken != null && savedToken.isNotEmpty) {
      _token = savedToken;
      if (savedInfo != null) {
        _userInfo = User.fromJson(savedInfo);
      }
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> sendCode(String email, int type) async {
    return await ApiService().post('/auth/send-code', data: {
      'email': email,
      'type': type,
    });
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String code,
    required String password,
    String nickname = '',
  }) async {
    final res = await ApiService().post('/auth/register', data: {
      'email': email,
      'code': code,
      'password': password,
      'nickname': nickname,
    });
    if (res['code'] == 200) {
      final data = res['data'] as Map<String, dynamic>;
      _token = data['token'] as String;
      _userInfo = User.fromJson(data['user'] as Map<String, dynamic>);
      await StorageService.setToken(_token);
      await StorageService.setUserInfo(data['user'] as Map<String, dynamic>);
      notifyListeners();
    }
    return res;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await ApiService().post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    if (res['code'] == 200) {
      final data = res['data'] as Map<String, dynamic>;
      _token = data['token'] as String;
      _userInfo = User.fromJson(data['user'] as Map<String, dynamic>);
      await StorageService.setToken(_token);
      await StorageService.setUserInfo(data['user'] as Map<String, dynamic>);
      notifyListeners();
    }
    return res;
  }

  Future<Map<String, dynamic>> loginByCode(String email, String code) async {
    final res = await ApiService().post('/auth/login-code', data: {
      'email': email,
      'code': code,
    });
    if (res['code'] == 200) {
      final data = res['data'] as Map<String, dynamic>;
      _token = data['token'] as String;
      _userInfo = User.fromJson(data['user'] as Map<String, dynamic>);
      await StorageService.setToken(_token);
      await StorageService.setUserInfo(data['user'] as Map<String, dynamic>);
      notifyListeners();
    }
    return res;
  }

  Future<Map<String, dynamic>> fetchProfile() async {
    final res = await ApiService().get('/auth/profile');
    if (res['code'] == 200) {
      _userInfo = User.fromJson(res['data'] as Map<String, dynamic>);
      await StorageService.setUserInfo(res['data'] as Map<String, dynamic>);
      notifyListeners();
    }
    return res;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await ApiService().put('/auth/profile', data: data);
    if (res['code'] == 200) {
      await fetchProfile();
    }
    return res;
  }

  Future<Map<String, dynamic>> changeUsername(String newUsername) async {
    return await ApiService().post('/auth/change-username', data: {
      'new_username': newUsername,
    });
  }

  Future<Map<String, dynamic>> changePhone(String phone) async {
    return await ApiService().post('/auth/change-phone', data: {
      'phone': phone,
    });
  }

  Future<Map<String, dynamic>> changeEmail(String email, {String? code}) async {
    return await ApiService().post('/auth/change-email', data: {
      'email': email,
      if (code != null) 'code': code,
    });
  }

  Future<Map<String, dynamic>> changePassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    return await ApiService().post('/auth/change-password', data: {
      'email': email,
      'code': code,
      'new_password': newPassword,
    });
  }

  Future<Map<String, dynamic>> followUser(int userId) async {
    return await ApiService().post('/users/$userId/follow');
  }

  Future<Map<String, dynamic>?> fetchUserProfile(int userId) async {
    try {
      final res = await ApiService().get('/users/$userId');
      if (res['code'] == 200) {
        return res['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchRecommendUsers() async {
    try {
      final res = await ApiService().get('/users/recommend');
      if (res['code'] == 200) {
        return List<Map<String, dynamic>>.from((res['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      }
    } catch (_) {}
    return [];
  }

  Future<String?> pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (picked == null) return null;
    try {
      final res = await ApiService().uploadFile('/upload/image', picked.path);
      if (res['code'] == 200) {
        final url = res['data']?['url'] as String?;
        if (url != null) {
          await updateProfile({'avatar': url});
        }
        return url;
      }
    } catch (_) {}
    return null;
  }

  Future<void> updateBgImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 800);
    if (picked == null) return;
    try {
      final res = await ApiService().uploadFile('/upload/image', picked.path);
      if (res['code'] == 200) {
        final url = res['data']?['url'] as String?;
        if (url != null) {
          await updateProfile({'bg_image': url});
        }
      }
    } catch (_) {}
  }

  Future<void> removeBgImage() async {
    try {
      await updateProfile({'bg_image': ''});
    } catch (_) {}
  }

  Future<void> markNotificationsRead(String type) async {
    try {
      String typeParam;
      if (type == 'like') {
        typeParam = '1,6';
      } else if (type == 'comment') {
        typeParam = '2,5';
      } else if (type == 'follow') {
        typeParam = '3';
      } else {
        typeParam = '1,2,3,5,6';
      }
      await ApiService().post('/notifications/read-all?type=$typeParam');
    } catch (_) {}
  }

  void logout() {
    _token = '';
    _userInfo = null;
    StorageService.clearAll();
    notifyListeners();
  }
}
