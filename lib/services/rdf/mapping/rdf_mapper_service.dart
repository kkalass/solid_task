import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/mapping/rdf_mapper_registry.dart';
import 'package:solid_task/services/rdf/rdf_constants.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';

/// Service for converting objects to/from RDF
///
/// This service handles the complete workflow of serializing/deserializing
/// domain objects to/from RDF, using the registered mappers.
final class RdfMapperService {
  final RdfMapperRegistry _registry;
  final ContextLogger _logger;

  /// Creates a new RDF mapper service
  RdfMapperService({
    required RdfMapperRegistry registry,
    LoggerService? loggerService,
  }) : _registry = registry,
       _logger = (loggerService ?? LoggerService()).createLogger(
         'RdfMapperService',
       );

  /// Access to the registry for registering custom mappers
  RdfMapperRegistry get registry => _registry;

  T fromTriples<T>(
    String storageRoot,
    List<Triple> triples,
    RdfSubject rdfSubject, {
    RdfSubjectDeserializer<T>? subjectDeserializer,
    RdfBlankNodeTermDeserializer<T>? blankNodeDeserializer,
  }) {
    return fromGraph(
      storageRoot,
      RdfGraph(triples: triples),
      rdfSubject,
      subjectDeserializer: subjectDeserializer,
      blankNodeDeserializer: blankNodeDeserializer,
    );
  }

  T fromGraph<T>(
    String storageRoot,
    RdfGraph graph,
    RdfSubject rdfSubject, {
    RdfSubjectDeserializer<T>? subjectDeserializer,
    RdfBlankNodeTermDeserializer<T>? blankNodeDeserializer,
  }) {
    _logger.debug('Delegated mapping graph to ${T.toString()}');

    var context = DeserializationContextImpl(
      storageRoot: storageRoot,
      graph: graph,
      registry: _registry,
    );

    return context.fromRdf(
      rdfSubject,
      null,
      subjectDeserializer,
      null,
      blankNodeDeserializer,
    );
  }

  List<Object> fromGraphAllSubjects(String storageRoot, RdfGraph graph) {
    // FIXME what do we do with type iris that are actually child subjects like the vector clock?
    /*
    Das Problem ist: diese können ziemlich generische Typen wie z.Bsp
    einfach MapEntry<String,int> haben - und ihre Mapper werden normalerweise
    auch nicht global registriert, sondern lokal am entsprechenden property
    bzw. bei der (de)serialisierung ihrer parents im code direkt.

    Die kann ich dann also auch gar nicht hier deserialisieren. 

    Ich könnte natürlich einfach warnen dass ich keinen deserializer habe
    und nicht eine exception werfen. Aber es wäre schon doof, immer diese
    warnungen zu sehen für solche legitimen Fälle. Macht es denn Sinn, wenn 
    ein SubjectDeserializer die Typen seiner Children angibt? Dann könnte 
    ich mir natürlich schon eher etwas basteln um die Warnung zu unterdrücken.

    Nachteil ist hier, dass "unnatürlicher" manueller Aufwand getrieben werden 
    müsste, es wirkt umständlich und wie eine Krücke.

    Eine andere Option wäre natürlich auch, zu überwachen, welche Triples gelesen wurden.
    und die dann ggf. über spezielle Objekte raus zu geben oder zu warnen 
    wenn das Dokument nicht vollständig gelesen wurde. Keine schlechte Idee,
    geht auch in die Richtung der other map in Java für JSON. Man könnte 
    dafür ja z. B. Json-LD nutzen und die übrigen properties dort hinein 
    packen - aber das ist Zukunftsmusik und für jetzt zu aufwändig. 
    
    */

    var deserializationSubjects = graph.findTriples(
      predicate: RdfConstants.typeIri,
    );

    var context = DeserializationContextImpl(
      storageRoot: storageRoot,
      graph: graph,
      registry: _registry,
    );

    return deserializationSubjects
        .map((triple) {
          final subject = triple.subject;
          final object = triple.object;
          if ((subject is! IriTerm) || (object is! IriTerm)) {
            _logger.warning(
              "Will skip deserialization of subject $subject with type $object because both subject and type need to be IRIs in order to be able to deserialize.",
            );
            return null;
          }
          return context.fromRdfByTypeIri(subject, object);
        })
        .whereType<Object>()
        .toList();
  }

  /// Map an object to RDF graph
  ///
  /// Converts a domain object to an RDF graph using the registered mapper
  ///
  /// @param instance The object to convert
  /// @param uri Optional URI to use as the subject
  /// @return RDF graph representing the object
  /// @throws StateError if no mapper is registered for type T
  RdfGraph toGraph<T>(
    String storageRoot,
    T instance, {
    RdfSubjectSerializer? serializer,
  }) {
    _logger.debug('Converting instance of ${T.toString()} to RDF graph');

    final context = SerializationContextImpl(
      storageRoot: storageRoot,
      registry: _registry,
    );

    var (_, triples) = context.subject(instance, serializer: serializer);

    return RdfGraph(triples: triples);
  }

  RdfGraph toGraphFromList<T>(
    String storageRoot,
    List<T> instances, {
    RdfSubjectSerializer? serializer,
  }) {
    _logger.debug('Converting instance of ${T.toString()} to RDF graph');

    final context = SerializationContextImpl(
      storageRoot: storageRoot,
      registry: _registry,
    );
    var triples =
        instances.expand((instance) {
          var (_, triples) = context.subject(instance, serializer: serializer);
          return triples;
        }).toList();

    return RdfGraph(triples: triples);
  }
}
