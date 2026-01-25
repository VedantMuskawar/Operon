import 'package:core_bloc/core_bloc.dart';

class ContactState extends BaseState {
  const ContactState({
    super.status = ViewStatus.initial,
    super.message,
    this.allContacts = const [],
    this.filteredContacts = const [],
    this.hasMore = false,
    this.isLoadingChunk = false,
    this.searchQuery = '',
    this.contactsIndex = const {},
    this.phoneIndex = const {},
    this.recentContacts = const [],
    this.contactDetailsCache = const {},
  });

  final List<ContactEntry> allContacts;
  final List<ContactEntry> filteredContacts;
  final bool hasMore;
  final bool isLoadingChunk;
  final String searchQuery;
  final Map<String, List<ContactEntry>> contactsIndex; // First letter -> contacts
  final Map<String, Set<int>> phoneIndex; // Normalized phone -> contact indices
  final List<ContactEntry> recentContacts;
  final Map<String, ContactEntry> contactDetailsCache; // Cached full contact details

  bool get isSearchActive => searchQuery.trim().isNotEmpty;

  @override
  ContactState copyWith({
    ViewStatus? status,
    String? message,
    List<ContactEntry>? allContacts,
    List<ContactEntry>? filteredContacts,
    bool? hasMore,
    bool? isLoadingChunk,
    String? searchQuery,
    Map<String, List<ContactEntry>>? contactsIndex,
    Map<String, Set<int>>? phoneIndex,
    List<ContactEntry>? recentContacts,
    Map<String, ContactEntry>? contactDetailsCache,
    bool clearMessage = false,
    bool clearSearch = false,
  }) {
    return ContactState(
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
      allContacts: allContacts ?? this.allContacts,
      filteredContacts: filteredContacts ?? this.filteredContacts,
      hasMore: hasMore ?? this.hasMore,
      isLoadingChunk: isLoadingChunk ?? this.isLoadingChunk,
      searchQuery: clearSearch ? '' : (searchQuery ?? this.searchQuery),
      contactsIndex: contactsIndex ?? this.contactsIndex,
      phoneIndex: phoneIndex ?? this.phoneIndex,
      recentContacts: recentContacts ?? this.recentContacts,
      contactDetailsCache: contactDetailsCache ?? this.contactDetailsCache,
    );
  }
}

/// Contact entry model for the contact page
class ContactEntry {
  const ContactEntry({
    required this.id,
    required this.name,
    required this.normalizedName,
    this.displayPhones = const [],
    this.normalizedPhones = const [],
    this.hasPhones = false,
    this.contactId, // FlutterContacts contact ID for lazy loading
  });

  final String id;
  final String name;
  final String normalizedName;
  final List<String> displayPhones;
  final List<String> normalizedPhones;
  final bool hasPhones;
  final String? contactId; // For lazy loading phone numbers

  String get primaryDisplayPhone =>
      displayPhones.isNotEmpty ? displayPhones.first : '-';

  ContactEntry copyWith({
    String? id,
    String? name,
    String? normalizedName,
    List<String>? displayPhones,
    List<String>? normalizedPhones,
    bool? hasPhones,
    String? contactId,
  }) {
    return ContactEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      displayPhones: displayPhones ?? this.displayPhones,
      normalizedPhones: normalizedPhones ?? this.normalizedPhones,
      hasPhones: hasPhones ?? this.hasPhones,
      contactId: contactId ?? this.contactId,
    );
  }
}
