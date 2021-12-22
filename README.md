# GraphMetal
3D Rendering of labeled directed multigraphs

A rendered graph looks like a ball-and-stick figure floating in space.

GraphMetal depends on the GenericGraph package for the graphs that it renders.

## Rendering

**`GraphRenderer`** performs the render pass, calling on **`GraphWireframe`** to add the
actual drawing commands to the render pipeline.

**`GraphView`** integrates GraphRenderer with SwiftUI. It works on both macOS and iOS.

**`RenderController`** provides a few settable properties that affect the rendered figure

In your app, create a class that adopts RendererableGraphContainer and pass it to the
GraphView initializer. 

You app can modify the graph as desired then call `fireGraphChange` on the container class,
providing a RenderableGraphChange describing the modifications. fireGraphChange uses
NotificationCenter to publish a notification that the graph has changed, which is then
picked up by GraphRenderer.

When GraphRenderer receives a notification it reads the graph and generates the data needed
to update the Metal buffers. This data is held in a temporary variable until the next draw cycle.

GraphRenderer supports cases where the graph is modified on a background thread, as well as
cases where it's modified on the main thread. If the graph is going to be large and/or
modifications frequent, it may be appropriate to execute the modifications on a background
thread, e.g., using a dispatch queue. 

## Point of View

**`POV`** defines the point of view, a/k/a eye or camera.

**`POVController`** manages the POV and provides support for certain gestures. These let you move
the figure around, zoom in or out, and change the POV's orientation.
