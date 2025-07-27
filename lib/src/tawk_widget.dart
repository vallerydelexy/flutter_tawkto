import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'tawk_visitor.dart';

/// [Tawk] Widget.
class Tawk extends StatefulWidget {
  /// Tawk direct chat link.
  final String directChatLink;

  /// Object used to set the visitor name, email, and pre-filled message.
  final TawkVisitor? visitor;

  /// Called right after the widget is rendered.
  final Function? onLoad;

  /// Called when a link pressed.
  final Function(String)? onLinkTap;

  /// Render your own loading widget.
  final Widget? placeholder;

  const Tawk({
    Key? key,
    required this.directChatLink,
    this.visitor,
    this.onLoad,
    this.onLinkTap,
    this.placeholder,
  }) : super(key: key);

  @override
  _TawkState createState() => _TawkState();
}

class _TawkState extends State<Tawk> {
  late InAppWebViewController _controller;
  bool _isLoading = true;

  // This single function will handle setting visitor attributes AND the pre-filled message.
  void _setupTawk(TawkVisitor visitor) {
    // Encode the attributes (name, email, hash) from your TawkVisitor
    final attributesJson = jsonEncode(visitor.toJson());

    // IMPORTANT: Encode the message separately to handle special characters
    // and newlines, creating a valid JavaScript string literal.
    final messageJson = jsonEncode(visitor.message ?? '');

    String javascriptString;

    // This JavaScript logic will be injected into the webview.
    // It sets the textarea value and dispatches an 'input' event
    // to ensure the Tawk.to app recognizes the change.
    final messageLogic = '''
      setTimeout(function() {
        const messageTextarea = document.querySelector('textarea[aria-label="chat-message-textarea"]');
        if (messageTextarea && messageTextarea.value === '') {
          messageTextarea.value = $messageJson;
          messageTextarea.dispatchEvent(new Event('input', { bubbles: true }));
        }
      }, 500);
    ''';

    // Combine setting attributes and pre-filling the message in one script
    // to avoid overwriting Tawk_API.onLoad.
    if (Platform.isIOS) {
      javascriptString = '''
        Tawk_API = Tawk_API || {};
        Tawk_API.setAttributes($attributesJson);
        $messageLogic
      ''';
    } else {
      javascriptString = '''
        Tawk_API = Tawk_API || {};
        Tawk_API.onLoad = function() {
          Tawk_API.setAttributes($attributesJson);
          $messageLogic
        };
      ''';
    }

    _controller.evaluateJavascript(source: javascriptString);
  }

  @override
  void initState() {
    super.initState();
    // The init() call was moved here to ensure it runs once.
    init();
  }

  void init() async {
    if (Platform.isAndroid) {
      await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);

      var swAvailable = await AndroidWebViewFeature.isFeatureSupported(
          AndroidWebViewFeature.SERVICE_WORKER_BASIC_USAGE);
      var swInterceptAvailable = await AndroidWebViewFeature.isFeatureSupported(
          AndroidWebViewFeature.SERVICE_WORKER_SHOULD_INTERCEPT_REQUEST);

      if (swAvailable && swInterceptAvailable) {
        AndroidServiceWorkerController serviceWorkerController =
            AndroidServiceWorkerController.instance();

        await serviceWorkerController
            .setServiceWorkerClient(AndroidServiceWorkerClient(
          shouldInterceptRequest: (request) async {
            return null;
          },
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InAppWebView(
          gestureRecognizers: {}..add(Factory<VerticalDragGestureRecognizer>(
              () => VerticalDragGestureRecognizer())),
          initialUrlRequest: URLRequest(url: WebUri(widget.directChatLink)),
          onWebViewCreated: (webViewController) {
            setState(() {
              _controller = webViewController;
            });
          },
          onLoadStop: (_, __) {
            // All JavaScript injection now happens in _setupTawk
            if (widget.visitor != null) {
              _setupTawk(widget.visitor!);
            }

            if (widget.onLoad != null) {
              widget.onLoad!();
            }

            setState(() {
              _isLoading = false;
            });
          },
          onConsoleMessage: (controller, consoleMessage) {
            // Useful for debugging JavaScript errors in your Flutter console
            print(consoleMessage);
          },
        ),
        _isLoading
            ? widget.placeholder ??
                const Center(
                  child: CircularProgressIndicator(),
                )
            : Container(),
      ],
    );
  }
}
