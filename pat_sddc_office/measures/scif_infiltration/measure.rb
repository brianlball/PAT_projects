# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class ScifInfiltration < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'scif infiltration'
  end

  # human readable description
  def description
    return 'reduce infiltration to scif levels'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'reduce infiltration to scif levels'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # Argument: list of space names (comma-separated string)
    space_names = OpenStudio::Measure::OSArgument.makeStringArgument('space_names', true)
    space_names.setDefaultValue('')
    space_names.setDisplayName('Target Spaces/SpaceTypes (comma-separated names)')
    space_names.setDescription('If blank, all SpaceInfiltration:DesignFlowRate objects will be updated. Otherwise, only those attached to a Space or SpaceType whose name matches (case-insensitive).')
    args << space_names

    flow = OpenStudio::Measure::OSArgument.makeDoubleArgument('flow_per_ext_area', true)
    flow.setDisplayName('Flow per Exterior Surface Area (m^3/s-m^2)')
    flow.setDefaultValue(0.000127) # set your preferred default
    args << flow
  
    return args
  end

    # --- helpers ---
    def set_flow_per_exterior_area(inf, val, runner)
      ok = inf.setFlowperExteriorSurfaceArea(val)  # implicitly sets method to Flow/ExteriorArea
      runner.registerWarning("Failed to set Flow/ExteriorArea on '#{inf.nameString}'") unless ok
      ok
    end

    def name_in_targets?(inf, targets)
      return true if targets.nil? # nil means "apply to all"

      # Check Space
      sp_opt = inf.space
      if sp_opt.is_initialized
        sp_name = sp_opt.get.nameString.downcase
        return true if targets.include?(sp_name)
      end

      # Check SpaceType
      st_opt = inf.spaceType
      if st_opt.is_initialized
        st_name = st_opt.get.nameString.downcase
        return true if targets.include?(st_name)
      end

      # Not targeted
      false
    end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)  # Do **NOT** remove this line

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

      val = runner.getDoubleArgumentValue('flow_per_ext_area', user_arguments)

      raw_list = runner.getStringArgumentValue('space_names', user_arguments).to_s

      # Build target set (nil => apply to all)
      targets =
        if raw_list.strip.empty?
          nil
        else
          Set.new(
            raw_list.split(',').map { |s| s.strip }.reject(&:empty?).map(&:downcase)
          )
        end

      updated = 0
      skipped = 0

      model.getSpaceInfiltrationDesignFlowRates.each do |inf|
        if name_in_targets?(inf, targets)
          if set_flow_per_exterior_area(inf, val, runner)
            updated += 1
            attach = if inf.space.is_initialized
                       "Space='#{inf.space.get.nameString}'"
                     elsif inf.spaceType.is_initialized
                       "SpaceType='#{inf.spaceType.get.nameString}'"
                     else
                       'Unassigned'
                     end
            runner.registerInfo("Set Flow/ExteriorArea=#{val} on '#{inf.nameString}' (#{attach})")
          else
            runner.registerWarning("Failed to set value on '#{inf.nameString}'")
          end
        else
          skipped += 1
        end
      end

      target_desc = targets ? "for #{targets.size} target name(s)" : "for ALL objects"
      runner.registerFinalCondition("Updated #{updated} SpaceInfiltration:DesignFlowRate object(s) (#{target_desc}); skipped #{skipped}.")
      true
  end
end

# register the measure to be used by the application
ScifInfiltration.new.registerWithApplication
