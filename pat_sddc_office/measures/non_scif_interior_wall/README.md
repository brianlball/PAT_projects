

###### (Automatically generated documentation)

# Set Interior Wall Construction for Spaces (Strict)

## Description
Assigns the given Construction (default: 'Typical Interior Wall') to interzone walls between spaces ONLY when both adjacent spaces are in the provided list. Exterior/adiabatic walls are not modified.

## Modeler Description
Resolves input space names to handles once, then uses handle-string comparison for all matching. For each interzone wall whose two spaces are both targeted, sets the Construction on BOTH mate surfaces.

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### Target Spaces (comma-separated exact names)
Case-insensitive exact match to Space names. Example: "Space 101, Space 102".
**Name:** space_names,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false


### Construction Name to Apply
Must exist in the model. Applied only to interzone walls whose adjacent space is also targeted.
**Name:** construction_name,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false






