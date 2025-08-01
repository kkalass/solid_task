import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:rdf_mapper_annotations/rdf_mapper_annotations.dart';
import 'package:rdf_vocabularies_core/foaf.dart';
import 'package:rdf_vocabularies_core/solid.dart';
//import 'package:rdf_vocabularies_core/space.dart';

@RdfGlobalResource(FoafPerson.classIri, IriStrategy())
class WebIdProfile {
  @RdfIriPart()
  final String iri;

  @RdfProperty(Solid.oidcIssuer, iri: IriMapping.mapper(IriFullMapper))
  final Iterable<String> issuers;

  @RdfProperty(
    IriTerm.prevalidated('http://www.w3.org/ns/pim/space#storage'),
    iri: IriMapping.mapper(IriFullMapper),
  )
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
