/// Branding configuration for a tenant's UI.
/// Stored as a nested object in `_platform/tenants/{tenant_id}`.
/// All fields are optional; app defaults apply if not set.
class Branding {
  const Branding({
    this.colorPrimary,
    this.colorSecondary,
    this.colorAccent,
    this.logoUrl,
    this.forceTheme,
  });

  /// Primary color (hex, e.g., '#534AB7').
  final String? colorPrimary;

  /// Secondary color (hex, optional).
  final String? colorSecondary;

  /// Accent color (hex, optional).
  final String? colorAccent;

  /// URL to tenant's logo image.
  final String? logoUrl;

  /// Force UI theme: 'light', 'dark', or null (auto-detect from device).
  final String? forceTheme;

  /// Create Branding from Firestore map (snake_case keys).
  factory Branding.fromJson(Map<String, dynamic> json) {
    return Branding(
      colorPrimary: json['color_primary'] as String?,
      colorSecondary: json['color_secondary'] as String?,
      colorAccent: json['color_accent'] as String?,
      logoUrl: json['logo_url'] as String?,
      forceTheme: json['force_theme'] as String?,
    );
  }

  /// Convert to Firestore map (snake_case keys, omit null values).
  Map<String, dynamic> toJson() => {
        if (colorPrimary != null) 'color_primary': colorPrimary,
        if (colorSecondary != null) 'color_secondary': colorSecondary,
        if (colorAccent != null) 'color_accent': colorAccent,
        if (logoUrl != null) 'logo_url': logoUrl,
        if (forceTheme != null) 'force_theme': forceTheme,
      };

  /// Create a copy with optional field overrides.
  Branding copyWith({
    String? colorPrimary,
    String? colorSecondary,
    String? colorAccent,
    String? logoUrl,
    String? forceTheme,
  }) =>
      Branding(
        colorPrimary: colorPrimary ?? this.colorPrimary,
        colorSecondary: colorSecondary ?? this.colorSecondary,
        colorAccent: colorAccent ?? this.colorAccent,
        logoUrl: logoUrl ?? this.logoUrl,
        forceTheme: forceTheme ?? this.forceTheme,
      );
}
