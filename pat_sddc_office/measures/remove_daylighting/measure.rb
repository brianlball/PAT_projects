# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class RemoveDaylighting < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'remove daylighting'
  end

  # human readable description
  def description
    return 'remove daylighting sensors from thermalzones'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'remove daylighting sensors from thermalzones'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # Argument: list of space names (comma-separated string)
    #space_names = OpenStudio::Measure::OSArgument.makeStringArgument('space_names', true)
    #space_names.setDisplayName('Space names (comma-separated)')
    #space_names.setDescription('List of space names whose shading groups should be removed')
    #args << space_names

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
    #space_arg = runner.getStringArgumentValue('space_names', user_arguments)
    #target_spaces = space_arg.split(',').map { |s| s.strip.downcase }

    removed = 0
    
    #remove all daylighting
    model.getThermalZones.each do |zone|
      if zone.primaryDaylightingControl.is_initialized
        zone.primaryDaylightingControl.get.remove
        runner.registerInfo("Removed primary daylighting control from zone: #{zone.nameString}")
      end
    end
    # 1) Remove shelves + their geometry
    model.getDaylightingDeviceShelfs.each do |shelf|
        # Inside shelf (InteriorPartitionSurface)
        ips_opt = shelf.insideShelf 
        if ips_opt.is_initialized
            ips = ips_opt.get
            ips_group_opt = ips.interiorPartitionSurfaceGroup
            if ips_group_opt.is_initialized
                ips_group_name = ips_group_opt.get.nameString
                runner.registerInfo("Removed interiorPartitionSurfaceGroup: #{ips_group_name}")
                ips_group_opt.get.remove
            end
        end
        shelf_name = shelf.nameString
        runner.registerInfo("Removed DaylightingDeviceShelf: #{shelf_name}")
        shelf.remove 
    end
    
    return true
  end
end

# register the measure to be used by the application
RemoveDaylighting.new.registerWithApplication
