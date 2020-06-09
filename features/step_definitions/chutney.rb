def chutney_src_dir
  "#{GIT_DIR}/submodules/chutney"
end

# XXX: giving up on a few worst offenders for now
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
def ensure_chutney_is_running
  # Ensure that a fresh chutney instance is running, and that it will
  # be cleaned upon exit. We only do it once, though, since the same
  # setup can be used throughout the same test suite run.
  return if $chutney_initialized

  chutney_listen_address = $vmnet.bridge_ip_addr
  chutney_script = "#{chutney_src_dir}/chutney"
  assert(
    File.executable?(chutney_script),
    "It does not look like '#{chutney_src_dir}' is the Chutney source tree"
  )
  network_definition = "#{GIT_DIR}/features/chutney/test-network"
  env = {
    'CHUTNEY_LISTEN_ADDRESS' => chutney_listen_address,
    'CHUTNEY_DATA_DIR'       => "#{$config['TMPDIR']}/chutney-data",
    # The default value (60s) is too short for "chutney wait_for_bootstrap"
    # to succeed reliably.
    'CHUTNEY_START_TIME'     => '600',
  }

  chutney_data_dir_cleanup = proc do
    if File.directory?(env['CHUTNEY_DATA_DIR'])
      FileUtils.rm_r(env['CHUTNEY_DATA_DIR'])
    end
  end

  chutney_cmd = proc do |cmd|
    debug_log("chutney: #{cmd}")
    Dir.chdir(chutney_src_dir) do
      cmd_helper([chutney_script, cmd, network_definition], env)
    end
  end

  # After an unclean shutdown of the test suite (e.g. Ctrl+C) the
  # tor processes are left running, listening on the same ports we
  # are about to use. If chutney's data dir also was removed, this
  # will prevent chutney from starting the network unless the tor
  # processes are killed manually.
  begin
    cmd_helper(['pkill', '--full', '--exact',
                "tor -f #{env['CHUTNEY_DATA_DIR']}/nodes/.*/torrc --quiet",])
  rescue StandardError
    # Nothing to kill
  end

  if KEEP_CHUTNEY
    begin
      chutney_cmd.call('start')
    rescue Test::Unit::AssertionFailedError
      if File.directory?(env['CHUTNEY_DATA_DIR'])
        raise 'You are running with --keep-snapshots or --keep-chutney, ' \
              'but Chutney failed ' \
              'to start with its current data directory. To recover you ' \
              "likely want to delete '#{env['CHUTNEY_DATA_DIR']}' and " \
              'all test suite snapshots and then start over.'
      else
        chutney_cmd.call('configure')
        chutney_cmd.call('start')
      end
    end
  else
    chutney_cmd.call('stop')
    chutney_data_dir_cleanup.call
    chutney_cmd.call('configure')
    chutney_cmd.call('start')
  end

  # Documentation: submodules/chutney/README, "Waiting for the network" section
  chutney_cmd.call('wait_for_bootstrap')

  at_exit do
    chutney_cmd.call('stop')
    chutney_data_dir_cleanup.call unless KEEP_CHUTNEY
  end

  # We have to sanity check that all nodes are running because
  # `chutney start` will return success even if some nodes fail.
  status = chutney_cmd.call('status')
  match = Regexp.new('^(\d+)/(\d+) nodes are running$').match(status)
  assert_not_nil(match, "Chutney's status did not contain the expected " \
                        'string listing the number of running nodes')
  running, total = match[1, 2].map(&:to_i)
  assert_equal(
    total, running, "Chutney is only running #{running}/#{total} nodes"
  )

  $chutney_initialized = true
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength

When /^I configure Tails to use a simulated Tor network$/ do
  # At the moment this step essentially assumes that we boot with 'the
  # network is unplugged', run this step, and then 'the network is
  # plugged'. I believe we can make this pretty transparent without
  # the need of a dedicated step by using tags (e.g. @fake_tor or
  # whatever -- possibly we want the opposite, @real_tor,
  # instead).
  #
  # There are two time points where we for a scenario must ensure that
  # the client configuration below is enabled if and only if the
  # scenario is tagged, and that is:
  #
  # 1. During a proper boot, as soon as the remote shell is up in the
  #    'the computer boots Tails' step.
  #
  # 2. When restoring a snapshot, in restore_background().
  #
  # If we do this, it doesn't even matter if a snapshot is made of an
  # untagged scenario (without the conf), and we later restore it with
  # a tagged scenario.
  #
  # Note: We probably have to clear the /var/lib/tor data dir when we
  # switch mode. Possibly there are other such problems that make this
  # abstraction impractical and it's better that we avoid it an go
  # with the more explicit, step-based approach.

  assert($vm.execute('service tor status').failure?,
         'Running this step when Tor is running is probably not intentional')
  ensure_chutney_is_running
  # Most of these lines are taken from chutney's client template.
  client_torrc_lines = [
    'TestingTorNetwork 1',
    'AssumeReachable 1',
    'PathsNeededToBuildCircuits 0.25',
    'TestingBridgeDownloadSchedule 0, 5',
    'TestingClientConsensusDownloadSchedule 0, 5',
    'TestingClientDownloadSchedule 0, 5',
    'TestingDirAuthVoteExit *',
    'TestingDirAuthVoteGuard *',
    'TestingDirAuthVoteHSDir *',
    'TestingMinExitFlagThreshold 0',
    'V3AuthNIntervalsValid 2',
    # Enabling TestingTorNetwork disables ClientRejectInternalAddresses
    # so the Tor client will happily try LAN connections. Coupled with
    # that TestingTorNetwork is enabled on all exits, and their
    # ExitPolicyRejectPrivate is disabled, we will allow exiting to
    # LAN hosts. We have at least one test that tries to make sure
    # that is *not* possible (Scenario: The Tor Browser cannot access
    # the LAN) so we cannot allow it. We'll have to rethink all this
    # if we ever want to run all services locally as well (#9520).
    'ClientRejectInternalAddresses 1',
  ]
  # We run one client in chutney so we easily can grep the generated
  # DirAuthority lines and use them.
  client_torrcs = Dir.glob(
    "#{$config['TMPDIR']}/chutney-data/nodes/*client/torrc"
  )
  dir_auth_lines = File.open(client_torrcs.first) do |f|
    f.grep(/^(Alternate)?(Dir|Bridge)Authority\s/)
  end
  client_torrc_lines.concat(dir_auth_lines)
  $vm.file_append('/etc/tor/torrc', client_torrc_lines)
end

def chutney_onionservice_info
  hs_hostname_file_path = Dir.glob(
    "#{$config['TMPDIR']}/chutney-data/nodes/*hs/hidden_service/hostname"
  ).first
  hs_hostname = File.open(hs_hostname_file_path) do |f|
    f.read.chomp
  end
  hs_torrc_path = Dir.glob(
    "#{$config['TMPDIR']}/chutney-data/nodes/*hs/torrc"
  ).first
  _, hs_port, local_address_port = File.open(hs_torrc_path) do |f|
    f.grep(/^HiddenServicePort/).first.split
  end
  local_address, local_port = local_address_port.split(':')
  [local_address, local_port, hs_hostname, hs_port]
end

def chutney_onionservice_redir(remote_address, remote_port)
  redir_unit_name = 'tails-test-suite-redir.service'
  bus = ENV['USER'] == 'root' ? '--system' : '--user'
  kill_redir = proc do
    begin
      if system('/bin/systemctl', bus, '--quiet', 'is-active', redir_unit_name)
        system('/bin/systemctl', bus, 'stop', redir_unit_name)
      end
    rescue StandardError
      # noop
    end
  end
  kill_redir.call
  local_address, local_port, = chutney_onionservice_info
  $chutney_onionservice_job = fatal_system(
    '/usr/bin/systemd-run',
    bus,
    "--unit=#{redir_unit_name}",
    '--service-type=forking',
    '--quiet',
    # XXX: enable this once we require systemd v236 or newer
    # for running our test suite
    # '--collect',
    '/usr/bin/redir',
    "#{local_address}:#{local_port}",
    "#{remote_address}:#{remote_port}"
  )
  add_after_scenario_hook { kill_redir.call }
  $chutney_onionservice_job
end
