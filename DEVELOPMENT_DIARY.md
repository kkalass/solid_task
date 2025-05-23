# Development Diary

This is an experiment: when working on a project, I often discuss
stuff with myself by writing down my thoughts and iterating on them.

I thought, that this might be an interesting approach for this project:
to put everything related unfiltered into a text file. It is some
type of information and you will probably eventually need a RAG agent
to get knowledge out of it ;-) - but why not try it.

Plus: if I take notes of all my thoughts in a text document, I can share
it with copilot and maybe that helps with treating copilot as a pair programmer.

## 2025-04-22

I took a break for a few days, and I wonder how I should continue now,
what to tackle next? There are still many parts I am not entirely happy
with. For example, the sync service and the repository - there is still
some work to do. It should be generic and not bound to the app, since
both are generic concepts.

Anyways, the behaviour of the sync service needs to be controllable by the
(dev) user - for example we need to be able to control which parts of
the graph are stored in which files. Still - there should be a reasonable
default for this.

The question where in a pod to store which parts of a graph actually
belongs to a PodAdapter or PodConfiguration, right?

I like PodConfiguration, but this class should also control for example, how
we map triples to files in the pod, which needs an implementation of an algorithm.

## 2025-04-23

Yesterday, I restructured the code base a bit and went towards extracting the
rdf and solid specific code parts to separate libraries. But I will do so only once
the first prototype is finished and I am happy with the initial, simple version.

I also enhanced the sync service such that one can provide a pod configuration provider
which provides the pod configuration (for example by using the auth stuff to get to the pod url)
and which in turn controls how the triples are mapped to files.

Anyways, I am still struggling with how I want the sync service to integrate with the locally
stored data, so lets try to brainstorm:

When reading from the solid pod, I will get a graph, and thus a list of subjects that need to
be stored - but here I am not really typesafe, for me those are just subjects. I could organize
them by (rdf?) type, though - so I could have a "repository" per type - but is this really helpful?

But what I do need, is some guidance on what to read / query from the solid pod. Maybe my hesitation
here comes from the fact, that currently I am working with files on the pod, but I do plan
to use SPARQL in future - at least optionally and depending on the Pod's capabilities. And I want
to be able to download only the changes since last time - but how to identify them reliably? This also
may have to do with CRDT and using statebased vs. commandbased CRDT. Currently I am working
statebased.

The Copilot Agent already added some code to handle upload/download timestamps and to query the latest
changes locally based on last upload timestamp. While I guess that this approach works for uploading,
it will not work for downloading. So I guess I remove this code for now and keep it really simple
(uploading/downloading) all files / items.

Another potential problem lurking in the back of my head is, that I rely on the complete items being read
and written - when I start asking for changed triples, this might become a problem. I still would like to
keep the complicated rdf stuff in the serialization layer and let my application work with simple
dart instances, not having to know anything about rdf. But could this mean that I need to support partial
updates of instances from the server, because I do not get all triples of a single subject? Not sure yet,
I guess I will have to wait with that.

---
Hmm, really interesting: working with Agents makes it even harder than usual to
estimate how long a task will take. I asked the agent to add tests to only a
specific part of the codebase, but this already takes hours of back and forth and
the agent seems to get itself ever deeper into trouble :-/

I mean, it is a good idea to add tests, right ;-)?

The annoying thing is, that this stops me from proceeding with what I really wanted
to get at, so I take it down as a note just to not forget. See further down (Next commands for the agents).

It is actually quite annoying, that the agent sends you off the track every now and then.
I communicated clearly my architecture preferences, but every time it is supposed to do a
task that is not so small, it takes multiple rounds to get it right. It violates
the preferences often without really justifying it.

But the worst thing about working with the copilot agent is, that it constantly makes you wait :-/

### Next commands for the Agent

* "As an expert dart developer who values clean code, idiomatic dart and clean architecture, please review the library in lib/ext/rdf (the tests are in test/ext/rdf) and make suggestions for improvements if any are advisable. Is it well structured? Are the namings good and clear? Is it following dart best practices and is it using idiomatic dart?"
* "As a senior dart developer, please convert the rdf parser and serializer to a plugin architecture so that library users may add different formats (or different implementations of the formats we support)"
* "As an experienced writer of technical documentation, go through all files in lib/ext/rdf and document them thoroughly. Make sure to especially create great top-of-the-class API documentation, including package level documentation (library directive). Your target audience are dart developers who might not be very familiar with RDF and its serialization formats like e.g. Turtle"

ok, lets do the same for the rdf_orm library now

* "As an expert dart developer who values clean code, idiomatic dart and clean architecture, please review the library in lib/ext/rdf_orm (the tests are in test/ext/rdf_orm) and make suggestions for improvements if any are advisable. Is it well structured? Are the namings good and clear? Is it following dart best practices and is it using idiomatic dart?"
* "As an experienced dart developer, implement all sensible tests for all files in lib/ext/rdf_orm   "
* "As an experienced writer of technical documentation, go through all files in lib/ext/rdf_orm and document them thoroughly. Make sure to especially create great top-of-the-class API documentation, including package level documentation (library directive). Your target audience are dart developers who might not be very familiar with RDF and its serialization formats like e.g. Turtle"

## 2025-04-24

Wow, Copilot Agent is so frustrating! I tried to make it write tests for rdf_orm, but it failed miserably, not being able to
fix the compilation errors itself, halucinating code and insisting on changing the API of the main code instead of adjusting the tests
to use the actually existing API. Very frustrating experience.

So, I will give windsurf a go as they

Hmm, this does not go nicely either. I also tried to let any of the agents implement a rdf_orm facade, but while windsurf
was a bit better, both did not do so well.

The main problem seems to be, that those agents are not very good at following instructions. They do not make correct use
of existing code - they always start to halucinate instead of reminding themselves of the APIs they are going to code against first.

I am currently also thinking about my API here actually: the deserialization context used to have the storage root
so that the Item deserializer can make use of it. But from the rdf_orm point of view, this feels strange. Both in the
serializer and the deserializer. In the end, whether or not a mapper needs the current storage root is an implementation
detail of that mapper.

So, I see two ways to solve this problem:

* Force the user to instantiate a new Mapper (and essentially a new service and a new registry) for every call
* Find some way to pass data to the Mapper.

So, the typesafe way would probably be, to enhance the Context classes with another type parameter - but this will
not be enough. I would have to even use this Context Paramter on the registry, the service and the mappers/serializers/deserializers.

While this is fine for me personally, I believe that others might be scared by this.

OTOH, just passing in and casting some data blob seems so wrong as well, as would be using something like thread locals in java.

We could pass in a registration callback

```dart
orm.toGraph(instance,{register:(registry)=>registry.registerSubjectMapper(ItemMapper(baseUrl))})
```

That would keep the interface clean, but I am not sure if this is the best way to go.

After fixing the issue with the storageRoot which did not belong in (de)serializationcontext, I went back
to vscode agent for test generation.

This time, with the following prompt:

> Please implement tests for lib/ext/rdf_orm. But do not invent APIs or classes or methods you use in your implementation, rather read the source code for the classes you need. You find the rdf library code for example in lib/ext/rdf/ - also classes like IriTerm are underneath.
>
> Please do not change any of those classes but let your tests use the methods exactly like they are. After implementing a test, compile and run it and fix any errors you find.

Ok, this worked way better than my previous approaches. We had a little bit back-and-forth for fixing some stuff, but the Agent did pretty well with this prompt.

Next I will try to get feedback again on the API itself:

> As an expert dart developer who values clean code, idiomatic dart and clean architecture, please review the library in lib/ext/rdf_orm (the tests are in test/ext/rdf_orm) and make suggestions for improvements if any are advisable. Is it well structured? Are the namings good and clear? Is it following dart best practices and is it using idiomatic dart? Is the API how you would expect it given its functionality, or are some method/class names or signatures unexpected?

But different topic: In parallel, I am preparing to release lib/ext/rdf as a library in its own right, dubbed rdf_core. I extracted
the code to a clean and simple fresh new project, but copied over .git directory to keep the history.

Then, I asked windsurf for the next steps with the following prompt:

> Please read the code including comments in lib. I want to publish this as a library on pubdev, and I want this library to be of really high standards. I want a nice github page showing off the library and how clean and nice to use it is. This github page should be similar to those landing pages of really big and successfull libraries and it should include the generated api documentation. What are the next steps? Can you help me with it?

## 2025-04-25

Nice, my first milestone: I have released <https://kkalass.github.io/rdf_core/> successfully - yay!

Now, I am working on brushing up rdf_mapper, but there is still some way to go for this one:

* DONE: extract code from solid_task to rdf_mapper library on github => done
* DONE: rdf_core: iriterm validation => done
* DONE: rdf_core: constants: rethink naming convention (*Iri) and create for all known namespaces constants classes with all known properties to make it easier for newcomes. Open: How to communicate which Types can have which properties?
* DONE: rdf_core: Brag about the vocab stuff in README and Homepage, make it easy to access it incl. API documentation. Update examples to use vocab where applicable, but make sure to also show how to work directly with the URLs. Make it simple for people new to all this RDF stuff to understand what vocab is and why and how this is useful. Give pointers to resources on the web if applicable
* DONE: Fix the rdf_core handling for blank nodes: They must not require a label, the label merely is a feature of the serialization. Open question: should I optionally allow explicit lables for BlankNodeTerms, or should I put this completely into serialization alone? => labels are only internal state and are optional. For serialization we always generate new labels. => done

* DONE: Update the rdf_mapper to use the correct BlankNodeTerm
* rdf_mapper: in rdf_mapper_test write meaningful serialization/deserialization tests for all types of mappers
* DONE: rdf_mapper: what about the naming RdfMapper vs. RdfSubjectMapper etc? 
* DONE: rdf_mapper: Make sure the examples in RdfMapper.registerXYZMapper are correct and transport well why one would want to register a mapper of a certain type and where the difference is. (Address vs. Person vs. PersonRef vs. MoneyValue or similar)
* DONE: rdf_mapper: Continue with the publishing: let the LLM review the project, add documentation, example, homepage etc.
* DONE: rdf_mapper: consistency nitpicking: the subject mapper can be registered directly in the registry, while the others are only registered on the facade. Maybe we should remove the subject mapper registration from the registry.

## 2025-04-30

Nice - I have extracted rdf_mapper in the last few days and updated solid_task to the new, hugely improved API.

There are of course still many possible improvements for rdf_core and rdf_mapper, but my plan is rather, to focus on the solid side of things next.

* introduce rdf_pod_mapper or similar. Idea is: this library sits on top of rdf_mapper and allows to persist into a solid pod, maybe including a fluent SPARQL api in dart.
* solid_sync on the other hand sits on top of this persistence library and maybe an extra crdt library and allows to sync crdt between a pod and a local storage like my hive based backend. Maybe this is more crdt_sync and possibly not really dependent on solid - or there is a crdt, crdt_sync and a solid_sync library. Lets see. But what would be important to me: we need to be clear on the type of crdt, maybe even supporting both state and command based crdt.
* can I somehow extract and generalize those files that are shared between projects? I mean tool, .github, .vscode/settings etc.

Ok, I am trying to implement the new way of vocabulary handling (actually: generating dart classes for easy Discoverability) and this is quite advanced because of inheritance across vocabularies and - even worse - enhancements of classes with predicates across vocabularies!

My Testcase currently is rdf:Bag, which is a rdfs:Container which is a rdfs:Resource and it should thus have rdf:type but also some predicates defined in rdfs

The agent is having a hard time, and here are some thoughts that I cannot give to it yet because it is still working on other problems:

* DONE: remove the _knownNamespaceToVocab in cross_vocabulary_resolver.dart. While the parser does not return the prefixes, you can extract them at least from turtle string really easy - just grep for @prefix lines.
* DONE: we must prefix the predicate with the namespace if we are including cross-namespace predicates
* The documentation of foreign predicates is worse than the one of own predicates (? still the case?), but it should probably be more verbose.
* idea: the description often is not very helpful, maybe we should provide a way to load a json with additional or more detailed documentation for well-known vocabularies and let a LLM generate that, maybe even with examples so one knows what rdf:value on Resource is good for and how and when it shall be used?
* formatting of generated classes unfortunately violates dart conventions
* DONE: builder quality: there are codepaths for usage without cross_vocabulary_resolver - why? Can't we remove them?


### Prompt for rdf_vocabulary_to_dart documentation/readme update

> You are a very senior and experienced technical documentation writer who writes clear yet concise documentation that is very well received by the target audience. Our target audience are dart developers who are not very familiar with rdf and rdf concepts.
>
> This project - based on rdf_core - generates classes out of RDF vocabularies (identified by their IRI). It generates two types of classes: the main vocabulary class with IriTerm constants for all the terms within that vocabulary, suitable for people already familiar with RDF and RDF vocabularies.
>
> But it also generates for every RDF Class of the vocabulary a distinct class. eg: https://schema.org vocabulary will have all terms in Schema, while the class https://schema.org/Person will lead to a dart class SchemaPerson which contains the IRIs of all properties of that RDF class - including those of superclasses, including rdf and rdfs. Properties from foreign vocabularies will be prefixed accordingly.
>
> Look at the build.yaml to understand how it is used.
>
> Please rewrite the README to create a world-class readme for our project hosted on github and eventually deployed to pub.dev

## 2025-05-02

Ok, I have extracted the vocabulary generation code to a new project and now need to find ways to correctly process everything.

Currently failing are:

* http://www.w3.org/2001/XMLSchema# 

* http://xmlns.com/foaf/0.1/ => XML/RDF
* http://www.w3.org/2004/02/skos/core# => XML/RDF
* http://www.w3.org/2006/vcard/ns# => Turtle, fails due to 'true' instead of "true"^^<xsd:bool>
* http://www.w3.org/ns/auth/acl# => Turtle, empty IRI
* https://schema.org => Turtle, fails ?
* http://www.w3.org/ns/solid/terms# => Turtle, also fails parsing