import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper_annotations/rdf_mapper_annotations.dart';
import 'package:rdf_vocabularies_core/foaf.dart';
import 'package:rdf_vocabularies_core/solid.dart';
//import 'package:rdf_vocabularies_core/space.dart';

/*
@prefix : <#>.
@prefix acl: <http://www.w3.org/ns/auth/acl#>.
@prefix foaf: <http://xmlns.com/foaf/0.1/>.
@prefix ldp: <http://www.w3.org/ns/ldp#>.
@prefix schema: <http://schema.org/>.
@prefix solid: <http://www.w3.org/ns/solid/terms#>.
@prefix space: <http://www.w3.org/ns/pim/space#>.
@prefix pro: <./>.
@prefix inbox: </inbox/>.
@prefix kk: </>.

pro:card a foaf:PersonalProfileDocument; foaf:maker :me; foaf:primaryTopic :me.

:me
    a schema:Person, foaf:Person;
    acl:trustedApp
            [
                acl:mode acl:Append, acl:Read, acl:Write;
                acl:origin <http://localhost:4400>
            ],
            [
                acl:mode acl:Append, acl:Read, acl:Write;
                acl:origin <http://localhost:52927>
            ];
    ldp:inbox inbox:;
    space:preferencesFile </settings/prefs.ttl>;
    space:storage kk:;
    solid:account kk:;
    solid:oidcIssuer <https://datapod.igrant.io>;
    solid:privateTypeIndex </settings/privateTypeIndex.ttl>;
    solid:publicTypeIndex </settings/publicTypeIndex.ttl>;
    foaf:name "Klas Kala\u00df".
*/
@RdfGlobalResource(FoafPerson.classIri, IriStrategy())
class WebIdProfile {
  @RdfIriPart()
  final String iri;

  @RdfProperty(Solid.oidcIssuer)
  final Iterable<String> issuers;

  @RdfProperty(IriTerm.prevalidated('http://www.w3.org/ns/pim/space#storage'))
  final Iterable<String> storage;

  @RdfUnmappedTriples()
  final RdfGraph other;

  @RdfProperty(FoafPerson.name)
  final String? name;

  WebIdProfile({
    required this.iri,
    required this.issuers,
    required this.storage,
    required this.other,
    required this.name,
  });
}
