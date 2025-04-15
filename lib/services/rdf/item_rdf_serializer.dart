// filepath: /Users/klaskalass/privat/solid_task/lib/services/rdf/item_rdf_serializer.dart
import 'package:solid_task/models/item.dart';
import 'package:solid_task/services/logger_service.dart';
import 'package:solid_task/services/rdf/item_rdf_mapper.dart';
import 'package:solid_task/services/rdf/rdf_graph.dart';
import 'package:solid_task/services/rdf/rdf_parser.dart';
import 'package:solid_task/services/rdf/rdf_serializer.dart';
import 'package:solid_task/services/rdf/task_ontology_constants.dart';

/// Service for converting Items to RDF and vice versa
///
/// This class coordinates the conversion between Item domain objects
/// and their serialized RDF representation, delegating specific tasks
/// to specialized components.
class ItemRdfSerializer {
  final ContextLogger _logger;
  final RdfSerializer _serializer;
  final RdfParser _parser;
  final ItemRdfMapper _mapper;

  /// Creates a new ItemRdfSerializer for converting Items to/from RDF.
  ///
  /// Uses the factory pattern to create appropriate RDF serializer and parser implementations.
  ///
  /// Parameters:
  /// - [loggerService]: Optional logger for diagnostic information
  /// - [contentType]: MIME type for serialization format (defaults to 'text/turtle')
  /// - [serializerFactory]: Factory for creating RDF serializers
  /// - [parserFactory]: Factory for creating RDF parsers
  /// - [mapper]: Mapper between Items and RDF graphs
  ItemRdfSerializer({
    LoggerService? loggerService,
    String? contentType = 'text/turtle',
    RdfSerializerFactory? serializerFactory,
    RdfParserFactory? parserFactory,
    ItemRdfMapper? mapper,
  }) : _logger = (loggerService ?? LoggerService()).createLogger(
         'ItemRdfSerializer',
       ),
       _serializer = (serializerFactory ??
               RdfSerializerFactory(loggerService: loggerService))
           .createSerializer(contentType: contentType),
       _parser = (parserFactory ??
               RdfParserFactory(loggerService: loggerService))
           .createParser(contentType: contentType),
       _mapper = mapper ?? ItemRdfMapper(loggerService: loggerService);

  /// Converts an Item to an RDF graph
  RdfGraph itemToRdf(Item item) => _mapper.mapItemToRdf(item);

  /// Extracts an Item from an RDF graph
  Item rdfToItem(RdfGraph graph, String itemUri) =>
      _mapper.mapRdfToItem(graph, itemUri);

  /// Serializes an Item to a string representation in the configured format
  String itemToString(Item item) {
    return _serializer.write(itemToRdf(item), prefixes: _mapper.commonPrefixes);
  }

  /// Parses an Item from a string representation in the specified format
  Item itemFromString(String content, String itemId, {String? documentUrl}) {
    _logger.debug('Parsing Item from string content with ID: $itemId');

    final graph = _parser.parse(content, documentUrl: documentUrl);
    final itemUri = TaskOntologyConstants.makeTaskUri(itemId);

    return rdfToItem(graph, itemUri);
  }
}
