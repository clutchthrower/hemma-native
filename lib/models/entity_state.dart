class EntityState {
  final String entityId;
  final String state;
  final Map<String, dynamic> attributes;
  final DateTime lastChanged;
  final DateTime lastUpdated;

  const EntityState({
    required this.entityId,
    required this.state,
    required this.attributes,
    required this.lastChanged,
    required this.lastUpdated,
  });

  String get domain => entityId.split('.').first;

  factory EntityState.fromJson(Map<String, dynamic> json) {
    return EntityState(
      entityId: json['entity_id'] as String,
      state: json['state'] as String? ?? 'unknown',
      attributes: (json['attributes'] as Map?)?.cast<String, dynamic>() ?? {},
      lastChanged: DateTime.tryParse(json['last_changed'] as String? ?? '') ??
          DateTime.now(),
      lastUpdated: DateTime.tryParse(json['last_updated'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  T attr<T>(String key, T fallback) {
    final v = attributes[key];
    if (v is T) return v;
    return fallback;
  }

  double? attrDouble(String key) {
    final v = attributes[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  EntityState copyWith({
    String? state,
    Map<String, dynamic>? attributes,
    DateTime? lastChanged,
    DateTime? lastUpdated,
  }) {
    return EntityState(
      entityId: entityId,
      state: state ?? this.state,
      attributes: attributes ?? this.attributes,
      lastChanged: lastChanged ?? this.lastChanged,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
