# GraphMetal
3D Rendering for GenericGraph

### GraphRenderer

GraphRenderer performs the render pass, using the helper class GraphWireframe to issue drawing commands to the render pipeline.

GraphView integrates GraphRenderer with SwiftUI.

In your app, create a class that adopts RendererableGraphContaoler and pass it to the GraphView initializer. 

Modify the graph as desired, then call fireGraphChange, providing a RenderableGraphChange describing the modifications.
fireGraphChange uses NotificationCenter to publish a notification that the graph has changed; GraphRenderer registers as an Observer for GraphChange notifications

When GraphRenderer receives a  notification it reads the graph and generates the data needed to update the Metal buffers. This data is held in a temporary variable until the next draw cycle.

If the graph is going to be large and/or modifications frequent, it may be appropriate to execute the modifications on a background thread, e.g., using a dispatch queue. That will permit the graph to be modified without impacting graphics performance.

### POVController

POV defines the point of view, a/k/a eye or camera.

POVController manages the POV and provides handlers for certain gestures

