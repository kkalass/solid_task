import 'package:solid_task/ext/rdf/core/constants/rdf_constants.dart';
import 'package:solid_task/ext/rdf/core/graph/rdf_term.dart';
import 'package:solid_task/ext/rdf/core/graph/triple.dart';
import 'package:solid_task/ext/rdf_orm/rdf_iri_term_serializer.dart';
import 'package:solid_task/ext/rdf_orm/rdf_literal_term_serializer.dart';
import 'package:solid_task/ext/rdf_orm/rdf_mapper_registry.dart';
import 'package:solid_task/ext/rdf_orm/rdf_subject_serializer.dart';
import 'package:solid_task/ext/rdf_orm/serialization_context.dart';

class SerializationContextImpl extends SerializationContext {
  @override
  final String storageRoot;
  final RdfMapperRegistry _registry;

  SerializationContextImpl({
    required this.storageRoot,
    required RdfMapperRegistry registry,
  }) : _registry = registry;

  @override
  List<Triple> childSubject<T>(
    RdfSubject subject,
    RdfPredicate predicate,
    T instance, {
    RdfSubjectSerializer<T>? serializer,
  }) {
    var ser = (serializer ?? _registry.getSubjectSerializer<T>());

    var (childIri, childTriples) = ser.toRdfSubject(
      instance,
      this,
      parentSubject: subject,
    );

    return [
      // Add rdf:type for the child
      constant(childIri, RdfConstants.typeIri, ser.typeIri),
      ...childTriples,
      // connect the parent to the child
      constant(subject, predicate, childIri),
    ];
  }

  @override
  Triple constant(
    RdfSubject subject,
    RdfPredicate predicate,
    RdfObject object,
  ) => Triple(subject, predicate, object);

  @override
  Triple iri<T>(
    RdfSubject subject,
    RdfPredicate predicate,
    T instance, {
    RdfIriTermSerializer<T>? serializer,
  }) {
    var term = (serializer ?? _registry.getIriSerializer<T>()).toIriTerm(
      instance,
      this,
    );
    return Triple(subject, predicate, term);
  }

  @override
  Triple literal<T>(
    RdfSubject subject,
    RdfPredicate predicate,
    T instance, {
    RdfLiteralTermSerializer<T>? serializer,
  }) {
    var term = (serializer ?? _registry.getLiteralSerializer<T>())
        .toLiteralTerm(instance, this);
    return Triple(subject, predicate, term);
  }

  @override
  (RdfSubject, List<Triple>) subject<T>(
    T instance, {
    RdfSubjectSerializer<T>? serializer,
  }) {
    var ser = (serializer ?? _registry.getSubjectSerializer<T>());
    var (iri, triples) = ser.toRdfSubject(instance, this);
    return (
      iri,
      [
        // Add rdf:type
        constant(iri, RdfConstants.typeIri, ser.typeIri),
        ...triples,
      ],
    );
  }
}
