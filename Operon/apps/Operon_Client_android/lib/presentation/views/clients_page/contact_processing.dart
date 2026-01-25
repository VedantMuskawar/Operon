import 'dart:isolate';
import 'package:flutter_contacts/flutter_contacts.dart' as device_contacts;
import 'package:dash_mobile/presentation/blocs/contacts/contact_state.dart';

/// Top-level function for isolate processing - processes contacts in chunks
/// Sends chunks via SendPort for incremental loading
/// Strategy: Send first small batch immediately, then larger batches
void processContactsInChunks(
  SendPort sendPort,
  List<device_contacts.Contact> contacts,
) {
  // Progressive loading strategy:
  // 1. First batch: Small (200-500) to show results immediately
  // 2. Subsequent batches: Larger for efficiency
  const firstBatchSize = 300; // Show first 300 contacts immediately
  final subsequentBatchSize = contacts.length > 8000 
      ? 1000  // Very large lists - process 1000 at a time
      : (contacts.length > 5000 
          ? 800  // Large lists - process 800 at a time
          : (contacts.length > 1000 ? 500 : 300));
  
  try {
    // Process and send first batch immediately for fast initial display
    if (contacts.isNotEmpty) {
      final firstChunk = contacts.take(firstBatchSize).toList();
      final processed = _processChunk(firstChunk);
      if (processed.isNotEmpty) {
        sendPort.send(processed);
      }
    }
    
    // Process remaining contacts in larger batches
    for (int i = firstBatchSize; i < contacts.length; i += subsequentBatchSize) {
      final chunk = contacts.skip(i).take(subsequentBatchSize).toList();
      final processed = _processChunk(chunk);
      if (processed.isNotEmpty) {
        sendPort.send(processed);
      }
    }
    // Send completion signal
    sendPort.send(null);
  } catch (e) {
    // Send error signal
    sendPort.send(<ContactEntry>[]);
  }
}

/// Process a chunk of contacts into ContactEntry objects
/// Optimized for speed - minimal processing, lazy load phone numbers
List<ContactEntry> _processChunk(List<device_contacts.Contact> contacts) {
  if (contacts.isEmpty) return <ContactEntry>[];
  
  final entries = <ContactEntry>[];
  
  for (final contact in contacts) {
    try {
      // Fast path: only process contacts with names
      final name = contact.displayName.trim();
      if (name.isEmpty) continue;

      // Since we loaded without properties, phones will be empty initially
      // Phone numbers will be loaded lazily when contact is tapped
      // This makes initial loading MUCH faster for large contact lists

      // Create contact entry with minimal data (name only)
      entries.add(
        ContactEntry(
          id: contact.id.isNotEmpty ? contact.id : 'unknown_${entries.length}',
          name: name,
          normalizedName: name.toLowerCase(),
          displayPhones: const [], // Will be loaded on demand
          normalizedPhones: const [], // Will be loaded on demand
          hasPhones: false, // Will be set to true when phone numbers are loaded
          contactId: contact.id.isNotEmpty ? contact.id : null,
        ),
      );
    } catch (e) {
      // Skip invalid contacts silently
      continue;
    }
  }
  
  return entries;
}

/// Process contacts with full details (for lazy loading)
/// This is called when a contact is tapped and needs phone numbers
Future<List<ContactEntry>> processContactWithDetails(
  String contactId,
  device_contacts.Contact contact,
) async {
  try {
    var name = contact.displayName.trim();
    if (name.isEmpty) {
      // Fallback to phone if no name
      if (contact.phones.isEmpty) return [];
      name = contact.phones.first.number.trim();
    }
    if (name.isEmpty) return [];

    // Extract and validate phone numbers
    final displayPhones = contact.phones
        .map((phone) => phone.number.trim())
        .where((number) => number.isNotEmpty)
        .toList();
        
    if (displayPhones.isEmpty) return [];

    // Normalize phone numbers
    final normalizedPhones = displayPhones
        .map((number) => number.replaceAll(RegExp(r'[^0-9+]'), ''))
        .where((number) => number.isNotEmpty && number.length >= 3)
        .toList();
        
    if (normalizedPhones.isEmpty) return [];

    return [
      ContactEntry(
        id: contactId,
        name: name,
        normalizedName: name.toLowerCase(),
        displayPhones: displayPhones,
        normalizedPhones: normalizedPhones,
        hasPhones: true,
        contactId: contact.id.isNotEmpty ? contact.id : null,
      ),
    ];
  } catch (e) {
    return [];
  }
}
