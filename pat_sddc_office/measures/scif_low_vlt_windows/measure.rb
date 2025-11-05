# frozen_string_literal: true
require 'set'

class ScifLowVltWindows < OpenStudio::Measure::ModelMeasure
  # --- UI ---
  def name 
    return 'Scif Low Vlt Windows'
  end
  def description
    return 'For exterior FixedWindows in the given spaces, replace their construction with the LVLT variant (appends LVLT to the current construction name).'
  end
  
  def modeler_description
    return 'For exterior FixedWindows in the given spaces, replace their construction with the LVLT variant (appends LVLT to the current construction name).'
  end

  def arguments(_model)
    args = OpenStudio::Measure::OSArgumentVector.new
    default_spaces = [
      'Space 116', 'Space 119', 'Space 120', 'Space 121', 'Space 122', 'Space 123',      
      'Space 201', 'Space 202', 'Space 203', 'Space 204', 'Space 205', 'Space 206',
      'Space 207', 'Space 208', 'Space 209', 'Space 210', 'Space 211', 'Space 212',
      'Space 213', 'Space 214', 'Space 215', 'Space 216', 'Space 217', 'Space 218',
      'Space 219', 'Space 220', 'Space 221', 'Space 222', 'Space 223'
    ]

    # the name of the space to add to the model
    space_name = OpenStudio::Measure::OSArgument.makeStringArgument('space_name', true)
    space_name.setDisplayName('New space name')
    space_name.setDescription('This name will be used as the name of the new space.')
    space_name.setDefaultValue(default_spaces.join(', '))
    args << space_name

    # Optional: let the suffix be configurable (default " LVLT")
    suffix = OpenStudio::Measure::OSArgument.makeStringArgument('lvlt_suffix', true)
    suffix.setDisplayName("Suffix to append to construction name")
    suffix.setDescription("The LVLT construction is found by <current name> + this suffix.")
    suffix.setDefaultValue(' LVLT')
    args << suffix

    args
  end

  # --- helpers ---
  def parse_space_list(raw)
    raw.split(/[;,]/).map { |s| s.strip }.reject(&:empty?)
  end

  def exterior_fixed_window?(ss)
    return false unless ss.subSurfaceType == 'FixedWindow'
    parent = ss.surface
    return false unless parent.is_initialized
    s = parent.get
    s.outsideBoundaryCondition == 'Outdoors'
  end

  def find_construction_base_by_name(model, name)
    # Works for any ConstructionBase subclass (opaque or fenestration)
    model.getConstructionBases.find { |c| c.nameString == name }
  end

  # --- run ---
  def run(model, runner, user_arguments)
    super
    return false unless runner.validateUserArguments(arguments(model), user_arguments)

    raw_spaces = runner.getStringArgumentValue('space_name', user_arguments).to_s
    suffix     = runner.getStringArgumentValue('lvlt_suffix', user_arguments).to_s

    tokens = parse_space_list(raw_spaces)
    if tokens.empty?
      runner.registerAsNotApplicable('No space names provided.')
      return true
    end

    wanted = tokens.map(&:downcase).to_set
    targets = model.getSpaces.select { |sp| wanted.include?(sp.nameString.downcase) }
    if targets.empty?
      runner.registerError("No matching spaces found for: #{tokens.join(', ')}")
      return false
    end
    runner.registerInfo("Matched #{targets.size} space(s): #{targets.map(&:nameString).join(', ')}")

    examined = 0
    changed  = 0
    already  = 0
    missing  = 0
    no_cons  = 0

    targets.each do |space|
      space.surfaces.each do |surf|
        # only exterior parents
        next unless surf.outsideBoundaryCondition == 'Outdoors'

        surf.subSurfaces.each do |ss|
          next unless ss.subSurfaceType == 'FixedWindow'
          examined += 1

          # Get current construction (must be explicitly set to change by name)
          cons_opt = ss.construction
          unless cons_opt.is_initialized
            no_cons += 1
            runner.registerInfo("Skip: '#{ss.nameString}' (#{space.nameString}) has no explicit construction.")
            next
          end

          cons = cons_opt.get
          base_name = cons.nameString

          # If it already ends with the suffix, skip
          if base_name.end_with?(suffix)
            already += 1
            next
          end

          target_name = base_name + suffix
          lvlt = find_construction_base_by_name(model, target_name)

          unless lvlt
            missing += 1
            runner.registerWarning("LVLT construction not found for '#{base_name}' → wanted '#{target_name}' "\
                                   "(window: '#{ss.nameString}', space: '#{space.nameString}')")
            next
          end

          if ss.setConstruction(lvlt)
            changed += 1
            runner.registerInfo("Set LVLT construction '#{target_name}' on '#{ss.nameString}' (#{space.nameString})")
          else
            runner.registerWarning("Failed to set LVLT construction on '#{ss.nameString}' (#{space.nameString})")
          end
        end
      end
    end

    if examined.zero?
      runner.registerAsNotApplicable('No exterior FixedWindow subsurfaces found in the targeted spaces.')
      return true
    end

    runner.registerFinalCondition(
      "Examined #{examined} exterior FixedWindow(s). "\
      "Updated #{changed}. Already LVLT: #{already}. Missing LVLT: #{missing}. "\
      "No explicit construction: #{no_cons}."
    )
    true
  end
end

ScifLowVltWindows.new.registerWithApplication
