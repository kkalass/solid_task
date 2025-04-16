/// Represents a SOLID user's identity
class UserIdentity {
  /// The WebID of the user, uniquely identifies a user in the SOLID ecosystem
  final String webId;

  /// The storage URL for the user's Pod
  final String? podUrl;

  /// Creates a new user identity with the given WebID and Pod URL
  const UserIdentity({required this.webId, this.podUrl});

  /// Creates a copy of this identity with modified properties
  UserIdentity copyWith({String? webId, String? podUrl}) {
    return UserIdentity(
      webId: webId ?? this.webId,
      podUrl: podUrl ?? this.podUrl,
    );
  }
}
