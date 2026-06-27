import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

void main() {
  runApp(const MoneyTrackerApp());
}

class MoneyTrackerApp extends StatelessWidget {
  const MoneyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Money Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WebShellScreen(),
    );
  }
}

class WebShellScreen extends StatefulWidget {
  const WebShellScreen({super.key});

  @override
  State<WebShellScreen> createState() => _WebShellScreenState();
}

class _WebShellScreenState extends State<WebShellScreen> {
  late final WebViewController _controller;
  // Use Vercel URL in production, and 10.0.2.2 for local emulator testing
  final String _webUrl = kReleaseMode 
      ? 'https://finance-tracker.vercel.app' 
      : 'http://10.0.2.2:3000';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'FileUploadChannel',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('FileUploadChannel received: ${message.message}');
        },
      )
      ..addJavaScriptChannel(
        'NativeShareChannel',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('NativeShareChannel received: ${message.message}');
        },
      )
      ..addJavaScriptChannel(
        'HapticFeedbackChannel',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('HapticFeedbackChannel triggered');
          HapticFeedback.lightImpact();
        },
      )
      ..addJavaScriptChannel(
        'ToastChannel',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('ToastChannel received: ${message.message}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message.message),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      )
      ..loadRequest(Uri.parse(_webUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PopScope(
          canPop: false,
          onPopInvoked: (bool didPop) async {
            if (didPop) return;
            
            if (await _controller.canGoBack()) {
              await _controller.goBack();
            } else {
              SystemNavigator.pop();
            }
          },
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }
}
