import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:solid_task/ext/solid/pod/profile/web_id_profile.dart';
import 'package:http/http.dart' as http;
import 'package:solid_task/ext/solid/pod/profile/web_id_profile.rdf_mapper.g.dart';

class WebIdProfileLoader {
  final http.Client _client;
  final RdfMapper _rdfMapper;

  WebIdProfileLoader({required http.Client client})
    : _client = client,
      // Note that we use a custom mapper for WebIdProfile to avoid
      // cyclic dependencies: this service is used for loading the webId profile
      // within the SolidAuthService, which in turn is needed to query the pod URL.
      // So we need to decouple those two.
      _rdfMapper = RdfMapper.withMappers(
        (r) => r.registerMapper(WebIdProfileMapper()),
      );

  Future<WebIdProfile> load(String webId) async {
    final response = await _client.get(
      Uri.parse(webId),
      headers: {'Accept': 'text/turtle, application/ld+json;q=0.9, */*;q=0.8'},
    );
    if (response.statusCode == 200) {
      return _rdfMapper.decodeObject<WebIdProfile>(
        response.body,
        documentUrl: webId,
      );
    }
    throw Exception(
      "Failed to load WebIdProfile. Status code ${response.statusCode}",
    );
  }
}
