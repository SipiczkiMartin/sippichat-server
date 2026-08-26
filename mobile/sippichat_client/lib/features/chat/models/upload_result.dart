class UploadResult {
  final String storageKey;
  final String url;
  final String filename;
  final String mimeType;
  final int size;
  final String type;

  const UploadResult({
    required this.storageKey,
    required this.url,
    required this.filename,
    required this.mimeType,
    required this.size,
    required this.type,
  });

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      storageKey: json['storage_key'] as String,
      url: json['url'] as String,
      filename: json['filename'] as String,
      mimeType: json['mime_type'] as String,
      size: json['size'] as int,
      type: json['type'] as String,
    );
  }
}
