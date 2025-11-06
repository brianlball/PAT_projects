

###### (Automatically generated documentation)

# scif remove windows

## Description
Remove all windows (FixedWindow, OperableWindow) in the given spaces and clean up related objects.

## Modeler Description
Matches spaces by name (case-insensitive), gathers window SubSurfaces, removes interzone mates, detaches/removes ShadingControls that reference them, and removes DaylightingDeviceShelfs (plus the inside shelf geometry group).

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### Target spaces (comma or semicolon separated)
Case-insensitive exact space names, e.g. "Space 101; Space 102, Space 201"
**Name:** space_names,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false


### Also remove Skylights?

**Name:** include_skylights,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false






