/// Helper utility to detect and format network-related errors
class NetworkErrorHelper {
  /// Checks if an error is a network connectivity error
  static bool isNetworkError(dynamic error) {
    if (error == null) return false;
    
    final errorString = error.toString().toLowerCase();
    final errorMessage = error is Exception ? error.toString() : errorString;
    
    // Common network error patterns
    final networkPatterns = [
      'unable to resolve host',
      'no address associated with hostname',
      'network is unreachable',
      'connection refused',
      'connection timed out',
      'socketexception',
      'failed host lookup',
      'unavailable',
      'unreachable',
      'internet',
      'network',
      'dns',
      'firestore.googleapis.com',
    ];
    
    return networkPatterns.any((pattern) => errorMessage.contains(pattern));
  }
  
  /// Gets a user-friendly error message for network errors
  static String getNetworkErrorMessage(dynamic error) {
    if (!isNetworkError(error)) {
      return 'An error occurred. Please try again.';
    }
    
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('unable to resolve host') || 
        errorString.contains('no address associated with hostname')) {
      return 'No internet connection. Please check your network and try again.';
    }
    
    if (errorString.contains('connection timed out') || 
        errorString.contains('timeout')) {
      return 'Connection timed out. Please check your internet connection.';
    }
    
    if (errorString.contains('connection refused')) {
      return 'Unable to connect to server. Please try again later.';
    }
    
    if (errorString.contains('network is unreachable')) {
      return 'Network is unreachable. Please check your connection.';
    }
    
    return 'Network error. Please check your internet connection and try again.';
  }
  
  /// Checks if error suggests retrying is appropriate
  static bool shouldRetry(dynamic error) {
    if (!isNetworkError(error)) return false;
    
    final errorString = error.toString().toLowerCase();
    
    // Retry on transient network errors, not on permanent failures
    final retryablePatterns = [
      'unable to resolve host',
      'connection timed out',
      'network is unreachable',
      'unavailable',
      'timeout',
    ];
    
    return retryablePatterns.any((pattern) => errorString.contains(pattern));
  }
}

