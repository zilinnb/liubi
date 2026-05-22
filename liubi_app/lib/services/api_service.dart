import 'package:dio/dio.dart';
import 'storage_service.dart';

class ApiService {
  static const String BASE_URL = 'https://liu.bi/api';

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: BASE_URL,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await StorageService.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        handler.next(response);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // 版本检查接口不需要登录，401不应清除token
          if (error.requestOptions.path != '/version/check') {
            await StorageService.clearAll();
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) async {
    final response = await _dio.get(path, queryParameters: queryParameters);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(String path, {dynamic data, int? timeout, bool noTimeout = false}) async {
    Options? options;
    if (noTimeout) {
      options = Options(receiveTimeout: Duration.zero, sendTimeout: Duration.zero);
    } else if (timeout != null) {
      options = Options(receiveTimeout: Duration(seconds: timeout), sendTimeout: Duration(seconds: timeout));
    }
    final response = await _dio.post(path, data: data, options: options);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> put(String path, {dynamic data}) async {
    final response = await _dio.put(path, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> delete(String path, {Map<String, dynamic>? queryParameters}) async {
    final response = await _dio.delete(path, queryParameters: queryParameters);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadFile(String path, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post(path, data: formData);
    return response.data as Map<String, dynamic>;
  }
}
