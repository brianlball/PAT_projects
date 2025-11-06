# frozen_string_literal: true

class FanPressureRise < OpenStudio::Measure::ModelMeasure
  def name = 'Add to Fan Pressure Rise (DOAS/PVAV)'
  def description = "Adds a specified pressure rise (entered in inH2O) to existing fan pressure rise values for "\
                    "DOAS (Fan:ConstantVolume) and/or PVAV (Fan:VariableVolume)."
  def modeler_description = description

  # ---------------- Arguments ----------------
  def arguments(_model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # Which systems?
    choices = OpenStudio::StringVector.new
    %w[DOAS PVAV BOTH].each { |c| choices << c }
    sys = OpenStudio::Measure::OSArgument.makeChoiceArgument('system_type', choices, true)
    sys.setDisplayName('System type to modify')
    sys.setDefaultValue('BOTH')
    args << sys

    # Additive pressure rise in inH2O
    pr = OpenStudio::Measure::OSArgument.makeDoubleArgument('add_pressure_rise_inH2O', true)
    pr.setDisplayName('Additive Pressure Rise (inH₂O)')
    pr.setDefaultValue(3.0)
    args << pr

    # DOAS exhaust fan inclusion
    inc_exh = OpenStudio::Measure::OSArgument.makeBoolArgument('include_doas_exhaust_fans', true)
    inc_exh.setDisplayName('For DOAS: include fans with "Exhaust" in the fan name?')
    inc_exh.setDefaultValue(false)
    args << inc_exh

    # Optional AirLoop name filter
    flt = OpenStudio::Measure::OSArgument.makeStringArgument('air_loop_name_filter', false)
    flt.setDisplayName('AirLoopHVAC name filter (optional, comma/semicolon substrings)')
    flt.setDefaultValue('')
    args << flt

    args
  end

  # ---------------- Helpers ----------------
  def inH2O_to_Pa(x) = x.to_f * 249.0889

  def parse_list(raw)
    raw.to_s.split(/[;,]/).map { |s| s.strip }.reject(&:empty?)
  end

  def loop_name_matches?(loop_opt, filters_downcase)
    return false unless loop_opt.is_initialized
    return true if filters_downcase.empty?
    ln = loop_opt.get.nameString.downcase
    filters_downcase.any? { |sub| ln.include?(sub) }
  end

  def loop_is_doas?(loop_opt)
    return false unless loop_opt.is_initialized
    loop_opt.get.nameString.downcase.include?('doas')
  end

  def loop_is_pvav?(loop_opt)
    return false unless loop_opt.is_initialized
    # heuristic: name contains 'pvav' OR 'vav' and not doas; adjust if your naming differs
    n = loop_opt.get.nameString.downcase
    (n.include?('pvav') || n.include?('vav')) && !n.include?('doas')
  end

  # ---------------- Run ----------------
  def run(model, runner, user_arguments)
    super
    return false unless runner.validateUserArguments(arguments(model), user_arguments)

    system_type   = runner.getStringArgumentValue('system_type', user_arguments) # DOAS, PVAV, BOTH
    add_inH2O     = runner.getDoubleArgumentValue('add_pressure_rise_inH2O', user_arguments)
    include_exh   = runner.getBoolArgumentValue('include_doas_exhaust_fans', user_arguments)
    filter_raw    = runner.getStringArgumentValue('air_loop_name_filter', user_arguments)

    add_Pa = inH2O_to_Pa(add_inH2O)
    filters = parse_list(filter_raw).map(&:downcase)

    runner.registerInfo("Adding #{add_inH2O} inH₂O (~#{add_Pa.round(1)} Pa) to existing fan pressure rise.")
    runner.registerInfo("Target systems: #{system_type}. AirLoop filter(s): #{filters.join(', ')}") unless filters.empty?
    runner.registerInfo("DOAS exhaust fans: #{include_exh ? 'included' : 'excluded'}.")

    loops_considered = 0
    fans_touched     = 0

    # Fan:ConstantVolume (DOAS)
    if %w[DOAS BOTH].include?(system_type)
      model.getFanConstantVolumes.each do |fan|
        loop_opt = fan.airLoopHVAC
        next unless loop_name_matches?(loop_opt, filters) # apply optional loop filter
        next unless loop_is_doas?(loop_opt)               # ensure it's on a DOAS loop by name

        # Exhaust inclusion/exclusion by fan name
        fname = fan.nameString
        is_exhaust = fname.downcase.include?('exhaust')
        next if is_exhaust && !include_exh

        loops_considered += 1

        current = fan.pressureRise # Pa
        new_val = current + add_Pa
        fan.setPressureRise(new_val)
        fans_touched += 1
        runner.registerInfo("DOAS #{is_exhaust ? '(Exhaust) ' : ''}Fan:ConstantVolume '#{fname}' "\
                            "on loop '#{loop_opt.get.nameString}': #{current.round(1)} -> #{new_val.round(1)} Pa")
      end
    end

    # Fan:VariableVolume (PVAV)
    if %w[PVAV BOTH].include?(system_type)
      model.getFanVariableVolumes.each do |fan|
        loop_opt = fan.airLoopHVAC
        next unless loop_name_matches?(loop_opt, filters)
        next unless loop_is_pvav?(loop_opt)

        loops_considered += 1

        current = fan.pressureRise # Pa
        new_val = current + add_Pa
        fan.setPressureRise(new_val)
        fans_touched += 1
        runner.registerInfo("PVAV Fan:VariableVolume '#{fan.nameString}' on loop '#{loop_opt.get.nameString}': "\
                            "#{current.round(1)} -> #{new_val.round(1)} Pa")
      end
    end

    if fans_touched.zero?
      msg =
        if filters.empty?
          "No matching fans found. Check that loop names identify DOAS/PVAV and that fan types exist."
        else
          "No matching fans found under the provided AirLoop filter(s)."
        end
      runner.registerAsNotApplicable(msg)
      return true
    end

    runner.registerFinalCondition("Updated pressure rise (added #{add_Pa.round(1)} Pa) on #{fans_touched} fan(s).")
    true
  end
end

FanPressureRise.new.registerWithApplication
