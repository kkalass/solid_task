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
