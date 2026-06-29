import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';

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
  bool _isLoading = true;
  // Use Vercel URL in production, and 10.0.2.2 for local emulator testing
  final String _webUrl = kReleaseMode 
      ? 'https://fta-web-view.vercel.app' 
      : 'http://10.0.2.2:3000';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'FileUploadChannel',
        onMessageReceived: (JavaScriptMessage message) async {
          debugPrint('FileUploadChannel received: ${message.message}');
          if (message.message == 'open') {
            try {
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['xls', 'xlsx'],
              );

              if (result != null && result.files.single.path != null) {
                File file = File(result.files.single.path!);
                List<int> bytes = await file.readAsBytes();
                String base64String = base64Encode(bytes);
                
                if (mounted) {
                  _controller.runJavaScript("if (window.onNativeFileSelected) { window.onNativeFileSelected('$base64String'); }");
                }
              }
            } catch (e) {
              debugPrint('Error picking file: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to pick file')),
                );
              }
            }
          }
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

  void _showDevDialog() {
    final TextEditingController ipController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dev Mode'),
        content: TextField(
          controller: ipController,
          decoration: const InputDecoration(
            hintText: 'e.g. 192.168.1.5',
            labelText: 'Local IP Address',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final ip = ipController.text.trim();
              if (ip.isNotEmpty) {
                _controller.loadRequest(Uri.parse('http://$ip:3000'));
              }
              Navigator.pop(context);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
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
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              
              // Native Splash Screen Overlay
              IgnorePointer(
                ignoring: !_isLoading, // Let touches pass through when hidden
                child: AnimatedOpacity(
                  opacity: _isLoading ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    color: const Color(0xFF121212), // Dark theme background
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/icon.png',
                            width: 120,
                            height: 120,
                          ),
                          const SizedBox(height: 32),
                          const CircularProgressIndicator(
                            color: Colors.greenAccent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onLongPress: _showDevDialog,
                  child: Container(
                    width: 60,
                    height: 60,
                    color: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
