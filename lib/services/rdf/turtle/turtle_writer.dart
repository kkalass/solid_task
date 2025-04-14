import '../rdf_graph.dart';

/// A writer for the Turtle RDF format
class TurtleWriter {
  /// Prefix map for commonly used namespaces
  final Map<String, String> prefixes;
  
  /// Should the output be formatted?
  final bool prettyPrint;
  
  /// Base URI for relative URIs
  final String? baseUri;
  
  /// Creates a new TurtleWriter
  TurtleWriter({
    this.prefixes = const {
      'rdf': 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
      'rdfs': 'http://www.w3.org/2000/01/rdf-schema#',
      'xsd': 'http://www.w3.org/2001/XMLSchema#',
      'owl': 'http://www.w3.org/2002/07/owl#',
      'foaf': 'http://xmlns.com/foaf/0.1/',
      'dc': 'http://purl.org/dc/elements/1.1/',
      'crdt': 'http://solid-task.org/crdt/ns#',
      'item': 'http://solid-task.org/items/ns#',
    },
    this.prettyPrint = true,
    this.baseUri,
  });
  
  /// Serializes an RDF graph to Turtle format
  String write(RdfGraph graph) {
    final buffer = StringBuffer();
    
    // Add base directive if present
    if (baseUri != null) {
      buffer.writeln('@base <$baseUri> .');
      if (prettyPrint) buffer.writeln();
    }
    
    // Write prefix declarations
    prefixes.forEach((prefix, uri) {
      buffer.writeln('@prefix $prefix: <$uri> .');
    });
    
    if (prettyPrint) buffer.writeln();
    
    // Group triples by subject
    final subjectGroups = <String, List<Triple>>{};
    for (var triple in graph.triples) {
      subjectGroups.putIfAbsent(triple.subject, () => []).add(triple);
    }
    
    // Write triples grouped by subject
    var firstSubject = true;
    subjectGroups.forEach((subject, triplesForSubject) {
      if (!firstSubject && prettyPrint) buffer.writeln();
      firstSubject = false;
      
      buffer.write(_formatResource(subject));
      buffer.write(' ');
      
      // Group remaining triples by predicate
      final predicateGroups = <String, List<Triple>>{};
      for (var triple in triplesForSubject) {
        predicateGroups.putIfAbsent(triple.predicate, () => []).add(triple);
      }
      
      var firstPredicate = true;
      predicateGroups.forEach((predicate, triplesForPredicate) {
        if (!firstPredicate) {
          buffer.write(';\n${prettyPrint ? '    ' : ''}');
        }
        firstPredicate = false;
        
        buffer.write(_formatResource(predicate));
        buffer.write(' ');
        
        var firstObject = true;
        for (var triple in triplesForPredicate) {
          if (!firstObject) {
            buffer.write(', ');
          }
          firstObject = false;
          
          buffer.write(_formatObject(triple.object));
        }
      });
      
      buffer.write(' .');
      if (prettyPrint) buffer.writeln();
    });
    
    return buffer.toString();
  }
  
  /// Formats a resource (subject or predicate)
  String _formatResource(String resource) {
    if (resource.startsWith('_:')) {
      return resource;
    }
    
    // Check for known prefixes
    for (var entry in prefixes.entries) {
      if (resource.startsWith(entry.value)) {
        return '${entry.key}:${resource.substring(entry.value.length)}';
      }
    }
    
    return '<$resource>';
  }
  
  /// Formats an object (can be literal or resource)
  String _formatObject(String object) {
    if (object.startsWith('http://') || object.startsWith('https://') || object.startsWith('_:')) {
      return _formatResource(object);
    } else {
      return _formatLiteral(object);
    }
  }
  
  /// Formats a literal
  String _formatLiteral(String literal) {
    // This is a simplified implementation that doesn't handle datatype and language tags
    // For a full implementation, the Triple would need to contain datatype/language information
    final value = _escapeString(literal);
    
    // Check if it's a simple numeric literal
    if (RegExp(r'^\d+(\.\d+)?$').hasMatch(literal)) {
      return literal;
    }
    
    // Check if it's a boolean
    if (literal.toLowerCase() == 'true' || literal.toLowerCase() == 'false') {
      return literal.toLowerCase();
    }
    
    return '"$value"';
  }
  
  /// Adds escape characters to a string
  String _escapeString(String str) {
    return str
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('\t', '\\t');
  }
}