// lib/src/tawk_visitor.dart
/// Use [TawkVisitor] to set the visitor name, email, and a pre-filled message.
class TawkVisitor {
  /// Visitor's name.
  final String? name;

  /// Visitor's email.
  final String? email;

  /// [Secure mode](https://developer.tawk.to/jsapi/#SecureMode).
  final String? hash;

  /// Pre-filled message for the chat.
  final String? message;

  TawkVisitor({
    this.name,
    this.email,
    this.hash,
    this.message,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    if (name != null) {
      data['name'] = name;
    }

    if (email != null) {
      data['email'] = email;
    }

    if (hash != null) {
      data['hash'] = hash;
    }

    // Note: The 'message' field is handled separately in the JavaScript.
    return data;
  }
}
