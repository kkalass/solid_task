# A Framework for Local-First, Interoperable Apps on Solid

## 1. Executive Summary
 This document outlines an architecture for building local-first, collaborative, and truly interoperable applications using Solid Pods as a synchronization backend. The core challenge is to enable robust, conflict-free data merging (CRDTs) without sacrificing the semantic interoperability promised by RDF and Linked Data.
 
 The proposed solution is a framework where data resources are self-describing: they link to a public set of merge rules and to the collections they belong to. This enables different applications to discover and collaborate on the same data in a standardized, robust way. The entire system, including all synchronization metadata, uses a consistent RDF data model.
 
 ## 2. Core Principles
 * **Local-First**: The application must be fully functional offline. All data is cached locally, and network is used only for synchronization.
 * **True Interoperability**: The data is clean, standard RDF. It becomes fully interoperable by linking to a public "ruleset" that defines how to collaborate on it.
 * **Declarative Merge Behavior**: Developers declare the desired conflict resolution strategy for each piece of data using a simple mapping system, rather than implementing complex merge algorithms.
 * **Discoverability**: Data resources are not isolated. They link to their governing rules and the indices they are part of, enabling any client to discover how to interact with and manage the data without prior knowledge.
 * **Decentralized & Server-Agnostic**: The Solid Pod acts as a simple, passive storage bucket. All synchronization logic resides within the client-side library.
 
 ## 3. The Three Core Components
 Our architecture is built on three pillars that work in concert.
 
 ### Pillar 1: The Data Layer (Standard RDF)
 
 This is the "what." It's the data itself, including the mechanics for synchronization and links to its own "instruction manuals" and collections.
 
 * **Format**: Data is stored as a single, self-contained RDF resource (e.g., in Turtle format).
 * **Vocabulary**: It uses well-known, public vocabularies (e.g., schema.org) to ensure semantic meaning.
 * **Structure**: The resource is clean and self-describing. It contains the data itself, the embedded CRDT mechanics, a link to its governing rules, and links to any indices it is a part of.
 
 #### Example: `recipe-123.ttl`

This example shows how the recipe data, its vector clock, a tombstone, and links to its rules and indices all coexist in one file, with the primary data prioritized for readability.

```ttl
@prefix schema: <https://schema.org/> .
@prefix crdt: <https://example.org/crdt#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

# -- Primary Data (Human-Readable Payload) --
<> a schema:Recipe;
   schema:name "Tomato Soup" ;
   schema:keywords "vegan" . # The "quick" tag was deleted

# -- CRDT & Synchronization Metadata --

# Link to the ruleset that governs this resource
<> crdt:isGovernedBy <https://example.com/crdt-mappings/recipe-v1.ttl> .

# Links to collections/indices this resource is a part of
<> crdt:belongsToIndex <../index/root-index.ttl> ;
   crdt:isIndexedForSearchIn <../search/full-text-index.ttl> .

# The Vector Clock for the entire resource, modeled as structured RDF
<> crdt:hasClockEntry
    [
        crdt:clientId <https://example.com/clients/A>;
        crdt:clockValue "15"^^xsd:integer
    ],
    [
        crdt:clientId <https://example.com/clients/B>;
        crdt:clockValue "8"^^xsd:integer
    ].

# The RDF-Star tombstone marking the deletion
<< <> schema:keywords "quick" >> crdt:isDeleted true .
```

### Pillar 2: The Rules Layer (CRDT Mapping RDF)

This is the "how." It defines the rules for merging, published as an open standard.

* **Format**: A separate RDF file, acting as a vocabulary or profile, defines the mapping between RDF properties and the CRDT algorithms used to merge them.
* **Publication**: This file must be published at a stable, public, and dereferenceable URL. This allows any third-party application to discover and implement the correct collaborative behavior.

#### Example: recipe-v1.ttl (published at https://example.com/crdt-mappings/)

```ttl
@prefix schema: <https://schema.org/> .
@prefix crdt: <https://example.org/crdt#> .

<> a crdt:ClassMapping;
   crdt:appliesToClass schema:Recipe;
   crdt:propertyMapping
     [ crdt:property schema:name; crdt:mergeWith crdt:LWW_Register ],
     [ crdt:property schema:keywords; crdt:mergeWith crdt:2P_Set ],
     [ crdt:property schema:recipeInstructions; crdt:mergeWith crdt:Sequence ] .
```

### Pillar 3: The Mechanics Layer (RDF-Star & Vector Clocks)

This is the "with what." It provides the low-level metadata needed for the rules to operate, embedded directly within the data file.

* **Vector Clocks**: The overall state of each resource is versioned using a Vector Clock. To maintain full interoperability, the clock is modeled as structured RDF, not an opaque string. This allows the clock's components (client IDs and their values) to be queryable and linkable parts of the graph.
* **RDF-Star**: This standard is used to contain CRDT datatype metadata, like for example tombstones for managing deletions in sets (as required by the 2P_Set CRDT).

## 4. Synchronization Workflow
The synchronization process is designed to be highly efficient and robust by using a consistent, RDF-based, and self-describing approach.

### 4.1. Efficient Discovery: The RDF-based Sharded Index

To avoid fetching thousands of individual data files on startup, the client first synchronizes a sharded index.

* **Root Index**: The client starts by fetching a single root-index.ttl file. This file is a CRDT itself and contains a list of all active shard files. It can also describe the sharding algorithm used.
* **Shard Sync**: The client then fetches all shard files listed in the root index. Thanks to standard HTTP caching, any shard that has not changed since the last sync will result in a 304 Not Modified response.
* **Shard Structure**: Each shard file is a CRDT that contains a collection of statements about the vector clocks of the resources it tracks. This provides a complete overview of the server's state.

#### Example: shard-n.ttl

```ttl
@prefix crdt: <https://example.org/crdt#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

# Vector clock for this shard file itself
<> crdt:hasClockEntry [ crdt:clientId <...>; crdt:clockValue "..."^^xsd:integer ].

# Link to the rules governing this shard file
<> crdt:isGovernedBy <https://example.com/crdt-mappings/shard-v1.ttl> .

# The mapping of resources to their clocks.
# Each resource is a subject, and its clock entries are its properties.
<../recipes/recipe-123.ttl> crdt:hasClockEntry
    [
        crdt:clientId <https://example.com/clients/A>;
        crdt:clockValue "15"^^xsd:integer
    ],
    [
        crdt:clientId <https://example.com/clients/B>;
        crdt:clockValue "8"^^xsd:integer
    ].

<../recipes/recipe-456.ttl> crdt:hasClockEntry
    [
        crdt:clientId <https://example.com/clients/A>;
        crdt:clockValue "18"^^xsd:integer
    ],
    [
        crdt:clientId <https://example.com/clients/B>;
        crdt:clockValue "9"^^xsd:integer
    ].
```

### 4.2. Reading and Merging Data

* **Identify Changes**: The client compares the vector clocks from the synchronized shards with its local cache to identify which resources need updating.
* **Fetch Full State**: For each changed resource, the client downloads the full RDF file from the server.
* **Apply Rules**: The client reads the `crdt:isGovernedBy` link in the data to fetch the correct CRDT Mapping RDF file (if not already cached).
* **Property-by-Property Merge**: The library iterates through the properties and applies the specified logic from the mapping file. The result is a new, merged RDF graph for the resource.


### 4.3. Creating and Updating Data
* **Update Data**: When a user modifies a resource, the client creates a new version of its RDF graph locally.
* **Update Index**: The client reads the `crdt:belongsToIndex` link from the resource. It follows this link to discover the root index, determine the correct shard, and update that shard's CRDT with the new vector clock for the modified resource.
* **Upload**: The client uploads the new version of the data resource and the updated index shard file to the Solid Pod.

## 5. Benefits of this Architecture
* **True Interoperability**: By publishing the merge rules and linking to them from the data, any application can learn how to correctly and safely collaborate.
* **Robust Conflict Resolution**: Using proven CRDT patterns for each data type ensures conflicts are handled automatically and predictably.
* **Discoverability and Resilience**: The system is highly discoverable. Any application can start with a single data resource and discover its rules and collections, making updates more robust.
* **High Performance & Consistency**: The RDF-based sharded index and state-based sync with HTTP caching ensure that synchronization is fast and bandwidth-efficient, while maintaining a consistent data model.

## 6. Alignment with Standardization Efforts

This architecture is not designed in a vacuum. Its core goal of enabling different applications to collaborate on shared RDF data requires common, agreed-upon standards.

The principles outlined here align directly with the work of community groups dedicated to this exact problem. The most notable of these is the **W3C CRDT for RDF Community Group**.

* **Link**: https://www.w3.org/community/crdt4rdf/

This group's mission is to specify how Conflict-Free Replicated Data Types should be applied to RDF data to enable interoperable, real-time collaboration. The "Rules Layer" (Pillar 2) of this architecture—a published, linkable file defining merge behaviors—is precisely the kind of specification that this group aims to standardize.

By adopting and contributing to such standards, a framework built on this architecture can move from being a powerful, single-system solution to being a compliant component in a much larger, truly interoperable, and collaborative semantic web.