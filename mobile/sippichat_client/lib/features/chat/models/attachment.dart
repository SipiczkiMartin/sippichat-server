class Attachment {
  final String id;
  final String type;
  final String? filename;
  final String? mimeType;
  final int? size;
  final String? storageKey;
  final String? externalUrl;
  final dynamic metadata;
  final int sortOrder;

  const Attachment({
    required this.id,
    required this.type,
    this.filename,
    this.mimeType,
    this.size,
    this.storageKey,
    this.externalUrl,
    this.metadata,
    required this.sortOrder,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json["id"],
      type: json["type"],
      filename: json["filename"],
      mimeType: json["mime_type"],
      size: json["size"],
      storageKey: json["storage_key"],
      externalUrl: json["external_url"],
      metadata: json["metadata"],
      sortOrder: json["sort_order"] ?? 0,
    );
  }
}
