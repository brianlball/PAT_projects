# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class RemoveShadingsurface < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'remove shadingsurface'
  end

  # human readable description
  def description
    return 'remove shading surface by space name'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'remove shading surface by space name'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # Argument: list of space names (comma-separated string)
    space_names = OpenStudio::Measure::OSArgument.makeStringArgument('space_names', true)
    space_names.setDisplayName('Space names (comma-separated)')
    space_names.setDescription('List of space names whose shading groups should be removed')
    args << space_names

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)  # Do **NOT** remove this line

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Parse input space names
    space_arg = runner.getStringArgumentValue('space_names', user_arguments)
    target_spaces = space_arg.split(',').map { |s| s.strip.downcase }

    removed = 0

    model.getShadingSurfaceGroups.each do |group|
      sp_opt = group.space   # -> OpenStudio::OptionalSpace
      next unless sp_opt.is_initialized

      space = sp_opt.get
      if target_spaces.include?(space.nameString.downcase)
        group.remove
        runner.registerInfo("Removed shading surface group '#{group.nameString}' from space '#{space.nameString}'")
        removed += 1
      end
    end
  
    return true
  end
end

# register the measure to be used by the application
RemoveShadingsurface.new.registerWithApplication
