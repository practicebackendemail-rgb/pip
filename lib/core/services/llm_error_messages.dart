import 'dart:async';
import 'dart:io';

/// Turns a provider failure into something Pip can say: what happened and
/// what to do, never raw JSON. The full error still goes to the debug log.
String describeLlmError(Object error) {
  final s = error.toString();
  final lower = s.toLowerCase();

  if (error is TimeoutException) {
    return "My brain took too long to answer. Let's try that again in a moment.";
  }
  if (error is SocketException || lower.contains('failed host lookup') || lower.contains('connection refused')) {
    return "I can't reach the internet right now. Check your connection and ask me again.";
  }
  if (s.contains('429') || lower.contains('quota') || lower.contains('resource_exhausted') || lower.contains('rate limit')) {
    if (lower.contains('limit: 0')) {
      return "This model isn't included in your key's free plan. Pick another model in Settings → AI model.";
    }
    return "I've hit the usage limit on your API key. Wait a minute and try again, "
        'or switch to a lighter model in Settings → AI model.';
  }
  if (s.contains('401') || s.contains('403') || lower.contains('api key not valid') || lower.contains('rejected')) {
    return 'My API key was rejected. Check it in Settings → AI model.';
  }
  if (lower.contains('not configured')) {
    return "I don't have a brain yet! Add an API key in Settings → AI model.";
  }
  if (s.contains('404') || lower.contains('not found') || lower.contains('no longer available')) {
    return "That model isn't available anymore. Pick another one in Settings → AI model.";
  }
  if (RegExp(r'\b5\d\d\b').hasMatch(s)) {
    return "My brain's provider is having trouble right now. Try again in a little while.";
  }
  return 'Something went wrong while I was thinking. Try asking again.';
}
