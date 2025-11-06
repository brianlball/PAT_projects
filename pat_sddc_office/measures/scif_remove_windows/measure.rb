# frozen_string_literal: true
require 'set'

class ScifRemoveWindows < OpenStudio::Measure::ModelMeasure
  # --- UI ---
  def name
    return 'scif remove windows'
  end
  
  def description 
    return 'Remove all windows (FixedWindow, OperableWindow) in the given spaces and clean up related objects.'
  end
  
  def modeler_description 
    return  'Matches spaces by name (case-insensitive), gathers window SubSurfaces, removes interzone mates, detaches/removes ShadingControls that reference them, and removes DaylightingDeviceShelfs (plus the inside shelf geometry group).'
  end

  def arguments(_model)
    args = OpenStudio::Measure::OSArgumentVector.new
    default_spaces = [
      'Space 116', 'Space 122', 'Space 123'
    ]
    spaces = OpenStudio::Measure::OSArgument.makeStringArgument('space_names', true)
    spaces.setDisplayName('Target spaces (comma or semicolon separated)')
    spaces.setDescription('Case-insensitive exact space names, e.g. "Space 101; Space 102, Space 201"')
    spaces.setDefaultValue(default_spaces.join(', '))
    args << spaces

    # Optional: include skylights too?
    incl_skylight = OpenStudio::Measure::OSArgument.makeBoolArgument('include_skylights', true)
    incl_skylight.setDisplayName('Also remove Skylights?')
    incl_skylight.setDefaultValue(false)
    args << incl_skylight

    args
  end

  # --- helpers ---
  def parse_list(raw)
    raw.to_s.split(/[;,]/).map { |s| s.strip }.reject(&:empty?)
  end

  def window_type?(ss, include_skylights)
    t = ss.subSurfaceType
    return true  if t == 'FixedWindow' || t == 'OperableWindow'
    return true  if include_skylights && t == 'Skylight'
    false
  end

  # --- run ---
  def run(model, runner, user_arguments)
    super
    return false unless runner.validateUserArguments(arguments(model), user_arguments)

    raw_spaces   = runner.getStringArgumentValue('space_names', user_arguments).to_s
    inc_skylight = runner.getBoolArgumentValue('include_skylights', user_arguments)

    tokens = parse_list(raw_spaces)
    if tokens.empty?
      runner.registerAsNotApplicable('No space names provided.')
      return true
    end

    wanted = tokens.map(&:downcase).to_set
    target_spaces = model.getSpaces.select { |sp| wanted.include?(sp.nameString.downcase) }
    if target_spaces.empty?
      runner.registerError("No matching spaces found for: #{tokens.join(', ')}")
      return false
    end
    runner.registerInfo("Matched #{target_spaces.size} space(s): #{target_spaces.map(&:nameString).join(', ')}")

    # Collect target window subsurfaces (and handles for reference cleanup)
    targets = []
    target_spaces.each do |space|
      space.surfaces.each do |surf|
        surf.subSurfaces.each do |ss|
          targets << ss if window_type?(ss, inc_skylight)
        end
      end
    end

    if targets.empty?
      runner.registerAsNotApplicable('No windows (FixedWindow/OperableWindow) found in targeted spaces.')
      return true
    end

    target_handles = Set.new(targets.map { |t| t.handle.to_s })

    # --- Cleanup 1: ShadingControls that reference target subsurfaces
    removed_shading_controls = 0
    detached_refs = 0
    model.getShadingControls.each do |sc|
      next unless sc.respond_to?(:subSurfaces)
      current = sc.subSurfaces
      next if current.empty?
      keepers = current.reject { |ss| target_handles.include?(ss.handle.to_s) }
      if keepers.size < current.size
        if keepers.empty?
          sc.remove
          removed_shading_controls += 1
          runner.registerInfo("Removed ShadingControl '#{sc.nameString}' (no subsurfaces left)")
        elsif sc.respond_to?(:setSubSurfaces)
          sc.setSubSurfaces(keepers)
          detached_refs += 1
          runner.registerInfo("Detached removed windows from ShadingControl '#{sc.nameString}'")
        end
      end
    end

    # --- Cleanup 2: Daylighting shelves that reference target subsurfaces + inside geometry group
    removed_shelves = 0
    removed_ips_groups = 0
    model.getDaylightingDeviceShelfs.each do |shelf|
      sub = shelf.subSurface
      next unless target_handles.include?(sub.handle.to_s)

      # Try to remove inside shelf's interior partition surface group for clean geometry
      ips_opt = shelf.insideShelf
      if ips_opt.is_initialized
        ips = ips_opt.get
        grp_opt = ips.interiorPartitionSurfaceGroup
        if grp_opt.is_initialized
          grp = grp_opt.get
          runner.registerInfo("Removed InteriorPartitionSurfaceGroup '#{grp.nameString}'")
          grp.remove
          removed_ips_groups += 1
        end
      end

      runner.registerInfo("Removed DaylightingDeviceShelf '#{shelf.nameString}' (referenced '#{sub.nameString}')")
      shelf.remove
      removed_shelves += 1
    end

    # --- Remove windows themselves (and interzone mates)
    removed_windows = 0
    removed_mates   = 0
    targets.each do |ss|
      # Remove mate first if interzone to avoid dangle
      adj_opt = ss.adjacentSubSurface
      if adj_opt.is_initialized
        mate = adj_opt.get
        if mate.handle.to_s != ss.handle.to_s
          runner.registerInfo("Also removing adjacentSubSurface '#{mate.nameString}' (mate of '#{ss.nameString}')")
          mate.remove
          removed_mates += 1
        end
      end

      runner.registerInfo("Removing window '#{ss.nameString}' (#{ss.subSurfaceType})")
      ss.remove
      removed_windows += 1
    end

    runner.registerFinalCondition(
      "Removed #{removed_windows} window SubSurface(s)#{removed_mates > 0 ? " and #{removed_mates} interzone mate(s)" : ''}; "\
      "#{removed_shelves} DaylightingDeviceShelf object(s); "\
      "#{removed_ips_groups} inside shelf geometry group(s); "\
      "#{removed_shading_controls} ShadingControl(s) removed and #{detached_refs} ShadingControl(s) updated."
    )
    true
  end
end

ScifRemoveWindows.new.registerWithApplication
