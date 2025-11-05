# frozen_string_literal: true
require 'set'

class RemoveSubsurfacesByName < OpenStudio::Measure::ModelMeasure
  # --- UI ---
  def name = 'Remove Subsurfaces by Name'
  def description = 'Deletes OS:SubSurface objects that match the provided names.'
  def modeler_description = 'Parses a list of names, finds matching SubSurfaces, optionally removes adjacent mates and cleans references, then deletes them.'

  def arguments(_model)
    args = OpenStudio::Measure::OSArgumentVector.new

    default_list = [
      'Sub Surface 12', 'Sub Surface 14', 'Sub Surface 18',
      'Sub Surface 20', 'Sub Surface 22', 'Sub Surface 24'
    ].join(', ')

    names = OpenStudio::Measure::OSArgument.makeStringArgument('subsurface_names', true)
    names.setDisplayName('SubSurface names (comma or semicolon separated)')
    names.setDefaultValue(default_list)
    args << names

    ci = OpenStudio::Measure::OSArgument.makeBoolArgument('case_insensitive', true)
    ci.setDisplayName('Match names case-insensitively?')
    ci.setDefaultValue(true)
    args << ci

    rm_mate = OpenStudio::Measure::OSArgument.makeBoolArgument('remove_adjacent_mates', true)
    rm_mate.setDisplayName('Also remove adjacentSubSurface (if interzone mate exists)?')
    rm_mate.setDefaultValue(false)
    args << rm_mate

    cleanup = OpenStudio::Measure::OSArgument.makeBoolArgument('cleanup_references', true)
    cleanup.setDisplayName('Detach from ShadingControls and remove DaylightingDeviceShelves that reference removed subsurfaces?')
    cleanup.setDefaultValue(true)
    args << cleanup

    args
  end

  # --- helpers ---
  def parse_names(raw)
    raw.split(/[;,]/).map { |s| s.strip }.reject(&:empty?)
  end

  # --- run ---
  def run(model, runner, user_arguments)
    super
    return false unless runner.validateUserArguments(arguments(model), user_arguments)

    raw   = runner.getStringArgumentValue('subsurface_names', user_arguments).to_s
    ci    = runner.getBoolArgumentValue('case_insensitive', user_arguments)
    rm_m  = runner.getBoolArgumentValue('remove_adjacent_mates', user_arguments)
    clean = runner.getBoolArgumentValue('cleanup_references', user_arguments)

    tokens = parse_names(raw)
    if tokens.empty?
      runner.registerAsNotApplicable('No subsurface names provided.')
      return true
    end

    wanted =
      if ci
        Set.new(tokens.map(&:downcase))
      else
        Set.new(tokens)
      end

    # Find targets
    targets = model.getSubSurfaces.select do |ss|
      nm = ss.nameString
      ci ? wanted.include?(nm.downcase) : wanted.include?(nm)
    end

    if targets.empty?
      runner.registerAsNotApplicable("No SubSurfaces matched any of: #{tokens.join(', ')}")
      return true
    end

    runner.registerInfo("Matched #{targets.size} SubSurface(s): #{targets.map(&:nameString).join(', ')}")

    # Optional cleanup: collect handles for quick membership checks
    target_handles = Set.new(targets.map { |t| t.handle.to_s })

    if clean
      # Detach from ShadingControls
      model.getShadingControls.each do |sc|
        next unless sc.respond_to?(:subSurfaces)
        current = sc.subSurfaces
        keepers = current.reject { |ss| target_handles.include?(ss.handle.to_s) }
        if keepers.size < current.size
          if keepers.empty?
            sc.remove
            runner.registerInfo("Removed empty ShadingControl '#{sc.nameString}' (no subsurfaces left)")
          elsif sc.respond_to?(:setSubSurfaces)
            sc.setSubSurfaces(keepers)
            runner.registerInfo("Detached removed subsurfaces from ShadingControl '#{sc.nameString}'")
          end
        end
      end

    # remove daylighting device shelves referencing target subsurfaces
    model.getDaylightingDeviceShelfs.each do |dds|
      sub = dds.subSurface             # direct SubSurface (not Optional)
      next unless target_handles.include?(sub.handle.to_s)
      runner.registerInfo("Removed DaylightingDeviceShelf '#{dds.nameString}' (referenced '#{sub.nameString}')")
      dds.remove
    end

    end

    # Delete targets (optionally also delete interzone mates)
    removed = 0
    removed_mates = 0
    targets.each do |ss|
      # Remove mate first if requested, so we don't leave a dangling ref
      if rm_m
        adj = ss.adjacentSubSurface
        if adj.is_initialized
          m = adj.get
          m.remove
          removed_mates += 1
          runner.registerInfo("Also removed adjacentSubSurface '#{m.nameString}' (mate of '#{ss.nameString}')")
        end
      end

      runner.registerInfo("Removing SubSurface '#{ss.nameString}'")
      ss.remove
      removed += 1
    end

    runner.registerFinalCondition("Removed #{removed} SubSurface(s)#{rm_m ? " and #{removed_mates} adjacent mate(s)" : ''}.")
    true
  end
end

RemoveSubsurfacesByName.new.registerWithApplication
