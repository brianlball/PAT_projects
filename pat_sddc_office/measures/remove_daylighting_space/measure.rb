# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class RemoveDaylightingSpace < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'remove daylighting by space'
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

    default_spaces = [
      'Space 116', 'Space 119', 'Space 120', 'Space 121', 'Space 122', 'Space 123',      
      'Space 201', 'Space 202', 'Space 203', 'Space 204', 'Space 205', 'Space 206',
      'Space 207', 'Space 208', 'Space 209', 'Space 210', 'Space 211', 'Space 212',
      'Space 213', 'Space 214', 'Space 215', 'Space 216', 'Space 217', 'Space 218',
      'Space 219', 'Space 220', 'Space 221', 'Space 222', 'Space 223'
    ]

    # Argument: list of space names (comma-separated string)
    space_names = OpenStudio::Measure::OSArgument.makeStringArgument('space_names', true)
    space_names.setDisplayName('Space names (comma-separated)')
    space_names.setDescription('List of space names whose shading groups should be removed')
    space_names.setDefaultValue(default_spaces.join(', '))
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
    name_tokens   = space_arg.split(',').map { |s| s.strip }.reject(&:empty?)
    wanted_names  = name_tokens.map(&:downcase).to_set

    target_spaces = model.getSpaces.select { |sp| wanted_names.include?(sp.nameString.downcase) }

    if target_spaces.empty?
      runner.registerError("No matching spaces found for: #{name_tokens.join(', ')}")
      return false
    end

    target_space_names = space_arg.split(',').map { |s| s.strip.downcase }

    removed = 0
    
    # 1) Remove shelves + their geometry
    model.getDaylightingDeviceShelfs.each do |shelf|
        # Inside shelf (InteriorPartitionSurface)
        ips_opt = shelf.insideShelf 
        if ips_opt.is_initialized
            ips = ips_opt.get
            ips_group_opt = ips.interiorPartitionSurfaceGroup
            if ips_group_opt.is_initialized
              #check space name on interiorPartitionSurfaceGroup
              sp_opt = ips_group_opt.get.space
              next unless sp_opt.is_initialized
              space = sp_opt.get
              if target_space_names.include?(space.nameString.downcase)
                ips_group_name = ips_group_opt.get.nameString
                runner.registerInfo("Removed interiorPartitionSurfaceGroup: #{ips_group_name} from #{space.nameString}")
                ips_group_opt.get.remove
                
                shelf_name = shelf.nameString
                runner.registerInfo("Removed DaylightingDeviceShelf: #{shelf_name} from #{space.nameString}")
                shelf.remove 
        
                zone = space.thermalZone
                next unless zone.is_initialized
                zn = zone.get
                if zn.primaryDaylightingControl.is_initialized
                  zn.primaryDaylightingControl.get.remove
                  runner.registerInfo("Removed primary daylighting control from zone: #{zn.nameString}")
                end
    
              end  
            end
        end
    end
    
    target_tz = []
    target_spaces.each do |space|
      if space.thermalZone.is_initialized
        target_tz << space.thermalZone.get
      end
      dlc = space.daylightingControls
      dlc.each do |dl|
        dl.remove
        runner.registerInfo("Removed daylighting control sensor #{dl.nameString} from zone: #{space.nameString}")
      end
    end

    #loop over TZ and remove lingering daylighting control
    target_tz.each do |zone|
      if zone.primaryDaylightingControl.is_initialized
        zone.primaryDaylightingControl.get.remove
        runner.registerInfo("Removed primary daylighting control from zone: #{zone.nameString}")
      end
    end
    
    return true
  end
end

# register the measure to be used by the application
RemoveDaylightingSpace.new.registerWithApplication
