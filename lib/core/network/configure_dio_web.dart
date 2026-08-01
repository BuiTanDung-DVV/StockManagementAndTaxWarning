import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

void configureDioForPlatform(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter()..withCredentials = true;
}
