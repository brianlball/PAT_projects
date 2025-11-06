

###### (Automatically generated documentation)

# Add to Fan Pressure Rise (DOAS/PVAV)

## Description
Adds a specified pressure rise (entered in inH2O) to existing fan pressure rise values for DOAS (Fan:ConstantVolume) and/or PVAV (Fan:VariableVolume).

## Modeler Description
Adds a specified pressure rise (entered in inH2O) to existing fan pressure rise values for DOAS (Fan:ConstantVolume) and/or PVAV (Fan:VariableVolume).

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### System type to modify

**Name:** system_type,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

**Choice Display Names** ["DOAS", "PVAV", "BOTH"]


### Additive Pressure Rise (inH₂O)

**Name:** add_pressure_rise_inH2O,
**Type:** Double,
**Units:** ,
**Required:** true,
**Model Dependent:** false


### For DOAS: include fans with "Exhaust" in the fan name?

**Name:** include_doas_exhaust_fans,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false


### AirLoopHVAC name filter (optional, comma/semicolon substrings)

**Name:** air_loop_name_filter,
**Type:** String,
**Units:** ,
**Required:** false,
**Model Dependent:** false






