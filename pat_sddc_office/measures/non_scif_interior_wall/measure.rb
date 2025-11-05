# frozen_string_literal: true
require 'set'

# Sets a specific Construction on interzone walls for a list of spaces (STRICT: only when both spaces are targeted).
class SetInteriorWallConstructionForSpaces < OpenStudio::Measure::ModelMeasure
  def name
    'Set Interior Wall Construction for Spaces (Strict)'
  end

  def description
    "Assigns the given Construction (default: 'Typical Interior Wall') to interzone walls between spaces "\
    "ONLY when both adjacent spaces are in the provided list. Exterior/adiabatic walls are not modified."
  end

  def modeler_description
    "Resolves input space names to handles once, then uses handle-string comparison for all matching. "\
    "For each interzone wall whose two spaces are both targeted, sets the Construction on BOTH mate surfaces."
  end

  # -------------------- Arguments --------------------
  def arguments(_model)
    args = OpenStudio::Measure::OSArgumentVector.new

    default_spaces = [
      'Space 101', 'Space 102', 'Space 103', 'Space 104', 'Space 105', 'Space 106',
      'Space 107', 'Space 108', 'Space 109', 'Space 110', 'Space 111', 'Space 112',
      'Space 113', 'Space 114', 'Space 115', 'Space 117', 'Space 118'
    ]

    space_names = OpenStudio::Measure::OSArgument.makeStringArgument('space_names', true)
    space_names.setDisplayName('Target Spaces (comma-separated exact names)')
    space_names.setDescription('Case-insensitive exact match to Space names. Example: "Space 101, Space 102".')
    space_names.setDefaultValue(default_spaces.join(', '))
    args << space_names

    construction_name = OpenStudio::Measure::OSArgument.makeStringArgument('construction_name', true)
    construction_name.setDisplayName('Construction Name to Apply')
    construction_name.setDescription("Must exist in the model. Applied only to interzone walls whose adjacent space is also targeted.")
    construction_name.setDefaultValue('Typical Interior Wall')
    args << construction_name

    args
  end

  # -------------------- Helpers --------------------
  def parse_space_names(raw)
    raw.split(',').map { |s| s.strip }.reject(&:empty?)
  end

  def find_construction_base_by_name(model, name)
    model.getConstructionBases.find { |c| c.nameString.casecmp(name).zero? }
  end

  def interzone_wall?(s)
    s.surfaceType == 'Wall' &&
      s.outsideBoundaryCondition == 'Surface' &&
      s.adjacentSurface.is_initialized
  end

  # -------------------- Run --------------------
  def run(model, runner, user_arguments)
    super
    return false unless runner.validateUserArguments(arguments(model), user_arguments)

    raw_spaces = runner.getStringArgumentValue('space_names', user_arguments).to_s
    target_construction_name = runner.getStringArgumentValue('construction_name', user_arguments).to_s

    tokens = parse_space_names(raw_spaces)
    if tokens.empty?
      runner.registerAsNotApplicable('No space names provided. Nothing to do.')
      return true
    end

    cons = find_construction_base_by_name(model, target_construction_name)
    unless cons
      runner.registerError("Construction '#{target_construction_name}' not found in model.")
      return false
    end

    # Resolve names -> spaces -> handle strings
    by_lower_name = {}
    model.getSpaces.each { |s| by_lower_name[s.nameString.downcase] = s }
    target_handles = Set.new
    not_found = []

    tokens.each do |t|
      sp = by_lower_name[t.downcase]
      if sp
        target_handles << sp.handle.to_s
      else
        not_found << t
      end
    end

    runner.registerWarning("No model space matched (exact): #{not_found.join(', ')}") unless not_found.empty?

    if target_handles.empty?
      runner.registerAsNotApplicable('None of the provided space names matched any spaces in the model.')
      return true
    end

    runner.registerInfo("Matched #{target_handles.size} space(s) by handle. Strict mode: update only if BOTH sides targeted.")

    # Iterate interzone walls of targeted spaces; operate per unique pair
    processed_pairs = Set.new
    pairs_considered = 0
    pairs_updated    = 0

    model.getSpaces.each do |space|
      next unless target_handles.include?(space.handle.to_s)

      space.surfaces.each do |surf|
        next unless interzone_wall?(surf)

        adj_surf = surf.adjacentSurface.get
        adj_space_opt = adj_surf.space
        next unless adj_space_opt.is_initialized

        adj_space = adj_space_opt.get

        # STRICT: both spaces must be targeted
        next unless target_handles.include?(adj_space.handle.to_s)

        # Unique pair key to avoid double-processing from the other side
        key = [surf.handle.to_s, adj_surf.handle.to_s].sort.join('|')
        next if processed_pairs.include?(key)
        processed_pairs << key

        pairs_considered += 1

        # Unconditionally set on BOTH sides (idempotent, ensures OSM shows it explicitly)
        ok1 = surf.setConstruction(cons)
        ok2 = adj_surf.setConstruction(cons)

        if ok1 && ok2
          pairs_updated += 1
          runner.registerInfo("Set construction on pair: '#{surf.nameString}' (#{space.nameString}) ↔ "\
                              "'#{adj_surf.nameString}' (#{adj_space.nameString})")
        else
          runner.registerWarning("Failed to set construction on a pair involving '#{surf.nameString}' / '#{adj_surf.nameString}'")
        end
      end
    end

    if pairs_considered.zero?
      runner.registerAsNotApplicable('No interzone wall pairs found where BOTH adjacent spaces are in the target list.')
      return true
    end

    runner.registerFinalCondition("Updated #{pairs_updated} of #{pairs_considered} interzone wall pair(s) "\
                                  "between targeted spaces. Construction: '#{cons.nameString}'.")
    true
  end
end

SetInteriorWallConstructionForSpaces.new.registerWithApplication
