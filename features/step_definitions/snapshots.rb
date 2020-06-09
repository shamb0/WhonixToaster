CHECKPOINTS =
  {
    'whonix-greeter'                              => {
      description:       "I have started Whonix Workstation and logged in and the network is connected",
      parent_checkpoint: nil,
      steps:             [
        'I start the computer',
      ],
    },
  }.freeze

# XXX: giving up on a few worst offenders for now
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
def reach_checkpoint(name)
  scenario_indent = ' ' * 4
  step_indent = ' ' * 6

  step 'a computer'
  if VM.snapshot_exists?(name)
    $vm.restore_snapshot(name)
  else
    checkpoint = CHECKPOINTS[name]
    checkpoint_description = checkpoint[:description]
    parent_checkpoint = checkpoint[:parent_checkpoint]
    steps = checkpoint[:steps]
    if parent_checkpoint
      if VM.snapshot_exists?(parent_checkpoint)
        $vm.restore_snapshot(parent_checkpoint)
      else
        reach_checkpoint(parent_checkpoint)
      end
      post_snapshot_restore_hook(parent_checkpoint)
    end
    debug_log(scenario_indent + "Checkpoint: #{checkpoint_description}",
              color: :white, timestamp: false)
    step_action = 'Given'
    if parent_checkpoint
      parent_description = CHECKPOINTS[parent_checkpoint][:description]
      debug_log(step_indent + "#{step_action} #{parent_description}",
                color: :green, timestamp: false)
      step_action = 'And'
    end
    steps.each do |s|
      begin
        step(s)
      rescue StandardError => e
        debug_log(scenario_indent +
                  "Step failed while creating checkpoint: #{s}",
                  color: :red, timestamp: false)
        raise e
      end
      debug_log(step_indent + "#{step_action} #{s}",
                color: :green, timestamp: false)
      step_action = 'And'
    end
    $vm.save_snapshot(name)
  end
  # VM#save_snapshot restores the RAM-only snapshot immediately
  # after saving it, in which case post_snapshot_restore_hook is
  # useful to ensure we've reached a good starting point, so we run
  # it in all cases, including even when've just saved a new snapshot.
  post_snapshot_restore_hook(name)
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength

# For each checkpoint we generate a step to reach it.
CHECKPOINTS.each do |name, desc|
  step_regex = Regexp.new("^#{Regexp.escape(desc[:description])}$")
  Given step_regex do
    begin
      reach_checkpoint(name)
    rescue StandardError => e
      debug_log("    Generated snapshot step failed with exception:\n" \
                "      #{e.class}: #{e}\n", color: :red, timestamp: false)
      raise e
    end
  end
end
