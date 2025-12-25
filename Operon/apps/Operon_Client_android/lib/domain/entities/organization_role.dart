enum SalaryType { salaryMonthly, wages }

class PageCrudPermissions {
  const PageCrudPermissions({
    this.create = false,
    this.edit = false,
    this.delete = false,
  });

  final bool create;
  final bool edit;
  final bool delete;

  Map<String, dynamic> toJson() {
    return {
      'create': create,
      'edit': edit,
      'delete': delete,
    };
  }

  factory PageCrudPermissions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PageCrudPermissions();
    return PageCrudPermissions(
      create: json['create'] as bool? ?? false,
      edit: json['edit'] as bool? ?? false,
      delete: json['delete'] as bool? ?? false,
    );
  }

  PageCrudPermissions copyWith({
    bool? create,
    bool? edit,
    bool? delete,
  }) {
    return PageCrudPermissions(
      create: create ?? this.create,
      edit: edit ?? this.edit,
      delete: delete ?? this.delete,
    );
  }
}

class RolePermissions {
  const RolePermissions({
    this.sections = const {},
    this.pages = const {},
  });

  final Map<String, bool> sections; // section name -> visible
  final Map<String, PageCrudPermissions> pages; // page name -> CRUD permissions

  bool canAccessSection(String sectionName) {
    return sections[sectionName] ?? false;
  }

  PageCrudPermissions? permissionFor(String pageName) {
    final direct = pages[pageName];
    if (direct != null) return direct;
    switch (pageName) {
      case 'zonesCity':
      case 'zonesRegion':
        return pages['deliveryZones'];
      case 'zonesPrice':
        return pages['deliveryPrices'];
      default:
        return null;
    }
  }

  bool canCreate(String pageName) {
    return permissionFor(pageName)?.create ?? false;
  }

  bool canEdit(String pageName) {
    return permissionFor(pageName)?.edit ?? false;
  }

  bool canDelete(String pageName) {
    return permissionFor(pageName)?.delete ?? false;
  }

  Map<String, dynamic> toJson() {
    return {
      'sections': sections,
      'pages': pages.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    };
  }

  factory RolePermissions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RolePermissions();
    final sectionsData = json['sections'] as Map<String, dynamic>? ?? {};
    final pagesData = json['pages'] as Map<String, dynamic>? ?? {};
    return RolePermissions(
      sections: sectionsData.map(
        (key, value) => MapEntry(key, value as bool? ?? false),
      ),
      pages: pagesData.map(
        (key, value) => MapEntry(
          key,
          PageCrudPermissions.fromJson(value as Map<String, dynamic>?),
        ),
      ),
    );
  }

  RolePermissions copyWith({
    Map<String, bool>? sections,
    Map<String, PageCrudPermissions>? pages,
  }) {
    return RolePermissions(
      sections: sections ?? this.sections,
      pages: pages ?? this.pages,
    );
  }
}

class OrganizationRole {
  const OrganizationRole({
    required this.id,
    required this.title,
    required this.salaryType,
    required this.colorHex,
    this.permissions = const RolePermissions(),
  });

  final String id;
  final String title;
  final SalaryType salaryType;
  final String colorHex;
  final RolePermissions permissions;

  bool get isAdmin => title.toUpperCase() == 'ADMIN';

  bool canAccessSection(String sectionName) {
    if (isAdmin) return true;
    return permissions.canAccessSection(sectionName);
  }

  bool canCreate(String pageName) {
    if (isAdmin) return true;
    return permissions.canCreate(pageName);
  }

  bool canEdit(String pageName) {
    if (isAdmin) return true;
    return permissions.canEdit(pageName);
  }

  bool canDelete(String pageName) {
    if (isAdmin) return true;
    return permissions.canDelete(pageName);
  }

  bool canAccessPage(String pageName) {
    if (isAdmin) return true;
    return permissions.permissionFor(pageName) != null;
  }

  Map<String, dynamic> toJson() {
    return {
      'roleId': id,
      'title': title,
      'salaryType': salaryType.name,
      'colorHex': colorHex,
      'permissions': permissions.toJson(),
    };
  }

  factory OrganizationRole.fromJson(Map<String, dynamic> json, String docId) {
    return OrganizationRole(
      id: json['roleId'] as String? ?? docId,
      title: json['title'] as String? ?? 'Untitled',
      salaryType: (json['salaryType'] as String?) == SalaryType.wages.name
          ? SalaryType.wages
          : SalaryType.salaryMonthly,
      colorHex: json['colorHex'] as String? ?? '#6F4BFF',
      permissions: RolePermissions.fromJson(
        json['permissions'] as Map<String, dynamic>?,
      ),
    );
  }

  OrganizationRole copyWith({
    String? id,
    String? title,
    SalaryType? salaryType,
    String? colorHex,
    RolePermissions? permissions,
  }) {
    return OrganizationRole(
      id: id ?? this.id,
      title: title ?? this.title,
      salaryType: salaryType ?? this.salaryType,
      colorHex: colorHex ?? this.colorHex,
      permissions: permissions ?? this.permissions,
    );
  }
}

