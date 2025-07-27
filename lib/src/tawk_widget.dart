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

  void _setUser(TawkVisitor visitor) {
    final json = jsonEncode(visitor.toJson());
    String javascriptString;

    if (Platform.isIOS) {
      javascriptString = '''
        Tawk_API = Tawk_API || {};
        Tawk_API.setAttributes($json);
      ''';
    } else {
      javascriptString = '''
        Tawk_API = Tawk_API || {};
        Tawk_API.onLoad = function() {
          Tawk_API.setAttributes($json);
        };
      ''';
    }

    _controller.evaluateJavascript(source: javascriptString);
  }

  void _setPrefilledMessage(String message) {
    String javascriptString = '''
      Tawk_API = Tawk_API || {};
      Tawk_API.onLoad = function() {
        Tawk_API.setAttributes({
          'message': '$message'
        }, function(error){
          // You can handle errors here if needed
        });
        
        // A more direct way to pre-fill the textarea
        setTimeout(function() {
          const messageTextarea = document.querySelector('textarea[aria-label="chat-message-textarea"]');
          if (messageTextarea) {
            messageTextarea.value = '$message';
            messageTextarea.dispatchEvent(new Event('input', { bubbles: true }));
          }
        }, 1000); // Delay to ensure the widget is fully loaded
      };
    ''';
    _controller.evaluateJavascript(source: javascriptString);
  }

  @override
  void initState() {
    super.initState();
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
            init();
            if (widget.visitor != null) {
              _setUser(widget.visitor!);
              if (widget.visitor!.message != null && widget.visitor!.message!.isNotEmpty) {
                _setPrefilledMessage(widget.visitor!.message!);
              }
            }

            if (widget.onLoad != null) {
              widget.onLoad!();
            }

            setState(() {
              _isLoading = false;
            });
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
