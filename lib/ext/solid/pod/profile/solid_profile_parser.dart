/// Interface for profile parsing operations
abstract class SolidProfileParser {
  /// Parse a profile document to extract the pod storage URL
  ///
  /// [webId] The WebID URL of the profile
  /// [content] The profile document content
  /// [contentType] The content type of the document
  Future<String?> parseStorageUrl(
    String webId,
    String content,
    String contentType,
  );
}
