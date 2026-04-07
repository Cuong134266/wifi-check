// LoginScreen không còn được sử dụng trong flow mới.
// App mở thẳng CheckinScreen, login xảy ra inline khi bấm Điểm danh.
// Giữ file này để tương thích nếu cần sau này.

import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Redirecting...')),
    );
  }
}
