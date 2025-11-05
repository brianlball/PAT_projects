

###### (Automatically generated documentation)

# Remove Subsurfaces by Name

## Description
Deletes OS:SubSurface objects that match the provided names.

## Modeler Description
Parses a list of names, finds matching SubSurfaces, optionally removes adjacent mates and cleans references, then deletes them.

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### SubSurface names (comma or semicolon separated)

**Name:** subsurface_names,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false


### Match names case-insensitively?

**Name:** case_insensitive,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false


### Also remove adjacentSubSurface (if interzone mate exists)?

**Name:** remove_adjacent_mates,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false


### Detach from ShadingControls and remove DaylightingDeviceShelves that reference removed subsurfaces?

**Name:** cleanup_references,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false






