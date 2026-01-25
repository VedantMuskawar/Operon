import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:core_bloc/core_bloc.dart';
import 'package:dash_mobile/presentation/blocs/contacts/contact_state.dart';

class ContactCubit extends Cubit<ContactState> {
  ContactCubit() : super(const ContactState());

  Timer? _searchDebounce;
  static const int _maxSearchResults = 100;
  static const int _chunkSize = 50;

  /// Initialize contact loading - called from UI
  void initializeLoading() {
    emit(state.copyWith(
      status: ViewStatus.loading,
      allContacts: const [],
      filteredContacts: const [],
      hasMore: false,
      isLoadingChunk: false,
      message: null,
    ));
  }

  /// Add a chunk of contacts incrementally
  /// Optimized to batch index building for better performance
  void loadContactChunk(List<ContactEntry> chunk) {
    if (isClosed || chunk.isEmpty) return;

    final startIndex = state.allContacts.length;
    final updatedContacts = [...state.allContacts, ...chunk];
    
    // Build index incrementally - optimized for large lists
    final updatedIndex = Map<String, List<ContactEntry>>.from(state.contactsIndex);
    final updatedPhoneIndex = Map<String, Set<int>>.from(state.phoneIndex);
    
    // Batch process contacts for indexing
    for (int i = startIndex; i < updatedContacts.length; i++) {
      final contact = updatedContacts[i];
      
      // Index by first letter (only if name exists)
      if (contact.normalizedName.isNotEmpty) {
        final firstChar = contact.normalizedName[0];
        final firstLetter = RegExp(r'[A-Za-z]').hasMatch(firstChar)
            ? firstChar.toUpperCase()
            : '#';
        updatedIndex.putIfAbsent(firstLetter, () => []).add(contact);
      }
      
      // Index by phone numbers (only first phone for performance)
      if (contact.normalizedPhones.isNotEmpty) {
        final phone = contact.normalizedPhones.first;
        updatedPhoneIndex.putIfAbsent(phone, () => {}).add(i);
      }
    }

    // Update filtered contacts if not searching
    List<ContactEntry> updatedFiltered;
    if (state.isSearchActive) {
      // Keep current search results
      updatedFiltered = state.filteredContacts;
    } else {
      // Show all loaded contacts immediately
      updatedFiltered = updatedContacts;
    }

    emit(state.copyWith(
      allContacts: updatedContacts,
      filteredContacts: updatedFiltered,
      contactsIndex: updatedIndex,
      phoneIndex: updatedPhoneIndex,
      isLoadingChunk: false,
      hasMore: true, // Assume more until told otherwise
      status: ViewStatus.success,
    ));
  }
  
  /// Batch load multiple chunks at once to reduce UI rebuilds
  void loadContactChunks(List<List<ContactEntry>> chunks) {
    if (isClosed || chunks.isEmpty) return;
    
    // Combine all chunks
    final allNewContacts = <ContactEntry>[];
    for (final chunk in chunks) {
      allNewContacts.addAll(chunk);
    }
    
    if (allNewContacts.isEmpty) return;
    
    // Process as single large chunk
    loadContactChunk(allNewContacts);
  }

  /// Signal that all contacts have been loaded
  void finishLoading() {
    if (isClosed) return;
    emit(state.copyWith(
      hasMore: false,
      isLoadingChunk: false,
      status: ViewStatus.success,
    ));
  }

  /// Set loading chunk indicator
  void setLoadingChunk(bool isLoading) {
    if (isClosed) return;
    emit(state.copyWith(isLoadingChunk: isLoading));
  }

  /// Search contacts with debounce and pre-indexed lookup
  void searchContacts(String query) {
    _searchDebounce?.cancel();
    
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _performSearch('');
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(trimmed);
    });
  }

  void _performSearch(String query) {
    if (isClosed) return;

    if (query.isEmpty) {
      // Reset to show all contacts
      emit(state.copyWith(
        searchQuery: '',
        filteredContacts: state.allContacts,
        status: ViewStatus.success,
      ));
      return;
    }

    // Normalize query
    final normalized = query.toLowerCase().trim();
    final digitsQuery = normalized.replaceAll(RegExp(r'[^0-9+]'), '');

    // Use pre-indexed maps for fast lookup
    final results = <ContactEntry>[];
    final seenIds = <String>{};

    // Search by name (first letter index)
    if (normalized.isNotEmpty) {
      final firstLetter = normalized[0].toUpperCase();
      final candidates = state.contactsIndex[firstLetter] ?? [];
      
      for (final contact in candidates) {
        if (results.length >= _maxSearchResults) break;
        if (seenIds.contains(contact.id)) continue;
        
        if (contact.normalizedName.contains(normalized)) {
          results.add(contact);
          seenIds.add(contact.id);
        }
      }
    }

    // Search by phone number
    if (digitsQuery.isNotEmpty && results.length < _maxSearchResults) {
      final phoneMatches = state.phoneIndex[digitsQuery];
      if (phoneMatches != null) {
        for (final index in phoneMatches) {
          if (results.length >= _maxSearchResults) break;
          if (index < state.allContacts.length) {
            final contact = state.allContacts[index];
            if (!seenIds.contains(contact.id)) {
              // Check if phone contains the query
              final matches = contact.normalizedPhones.any(
                (phone) => phone.contains(digitsQuery),
              );
              if (matches) {
                results.add(contact);
                seenIds.add(contact.id);
              }
            }
          }
        }
      }
      
      // Also search all contacts for partial phone matches
      if (results.length < _maxSearchResults) {
        for (final contact in state.allContacts) {
          if (results.length >= _maxSearchResults) break;
          if (seenIds.contains(contact.id)) continue;
          
          final phoneMatch = contact.normalizedPhones.any(
            (phone) => phone.contains(digitsQuery),
          );
          if (phoneMatch) {
            results.add(contact);
            seenIds.add(contact.id);
          }
        }
      }
    }

    emit(state.copyWith(
      searchQuery: query,
      filteredContacts: results,
      status: ViewStatus.success,
    ));
  }

  /// Reset search and show all contacts
  void resetSearch() {
    if (isClosed) return;
    _searchDebounce?.cancel();
    emit(state.copyWith(
      searchQuery: '',
      filteredContacts: state.allContacts,
    ));
  }

  /// Update contact with full details (lazy loading)
  void updateContactDetails(ContactEntry updatedContact) {
    if (isClosed) return;

    // Update in allContacts
    final updatedAll = state.allContacts.map((contact) {
      return contact.id == updatedContact.id ? updatedContact : contact;
    }).toList();

    // Update in filteredContacts if present
    final updatedFiltered = state.filteredContacts.map((contact) {
      return contact.id == updatedContact.id ? updatedContact : contact;
    }).toList();

    // Update cache
    final updatedCache = Map<String, ContactEntry>.from(state.contactDetailsCache);
    updatedCache[updatedContact.id] = updatedContact;

    emit(state.copyWith(
      allContacts: updatedAll,
      filteredContacts: updatedFiltered,
      contactDetailsCache: updatedCache,
    ));
  }

  /// Add contact to recent contacts
  void addRecentContact(ContactEntry contact) {
    if (isClosed) return;

    final updatedRecent = List<ContactEntry>.from(state.recentContacts);
    updatedRecent.removeWhere((c) => c.id == contact.id);
    updatedRecent.insert(0, contact);
    if (updatedRecent.length > 5) {
      updatedRecent.removeLast();
    }

    emit(state.copyWith(recentContacts: updatedRecent));
  }

  /// Handle loading error
  void setError(String message) {
    if (isClosed) return;
    emit(state.copyWith(
      status: ViewStatus.failure,
      message: message,
      isLoadingChunk: false,
    ));
  }

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    return super.close();
  }
}
