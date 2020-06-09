require 'uri'

def apt_sources
  $vm.execute_successfully(
    'cat /etc/apt/sources.list /etc/apt/sources.list.d/*'
  ).stdout
end

Given /^the only hosts in APT sources are "([^"]*)"$/ do |hosts_str|
  hosts = hosts_str.split(',')
  apt_sources.chomp.each_line do |line|
    next unless line.start_with? 'deb'

    source_host = URI(line.split[1]).host
    raise "Bad APT source '#{line}'" unless hosts.include?(source_host)
  end
end

Given /^no proposed-updates APT suite is enabled$/ do
  assert_no_match(/\s\S+-proposed-updates\s/, apt_sources)
end

Given /^no experimental APT suite is enabled for deb[.]torproject[.]org$/ do
  # sdscoq7snqtznauu.onion == deb.torproject.org
  assert_no_match(/sdscoq7snqtznauu[.]onion.*experimental/, apt_sources)
end

When /^I configure APT to use non-onion sources$/ do
  script = <<-SCRIPT
  use strict;
  use warnings FATAL => "all";
  s{vwakviie2ienjx6t[.]onion}{ftp.us.debian.org};
  s{sgvtcaew4bxjd7ln[.]onion}{security.debian.org};
  s{sdscoq7snqtznauu[.]onion}{deb.torproject.org};
  s{jenw7xbd6tf7vfhp[.]onion}{deb.tails.boum.org};
  SCRIPT
  # VMCommand:s cannot handle newlines, and they're irrelevant in the
  # above perl script any way
  script.delete!("\n")
  $vm.execute_successfully(
    "perl -pi -E '#{script}' /etc/apt/sources.list /etc/apt/sources.list.d/*"
  )
end

When /^I update APT using apt$/ do
  recovery_proc = proc do
    step 'I kill the process "apt"'
    $vm.execute('rm -rf /var/lib/apt/lists/*')
  end
  retry_tor(recovery_proc) do
    Timeout.timeout(15 * 60) do
      $vm.execute_successfully("echo #{@sudo_password} | " \
                               'sudo -S apt update', user: LIVE_USER)
    end
  end
end

def wait_for_package_installation(package)
  try_for(2 * 60) do
    $vm.execute_successfully("dpkg -s '#{package}' 2>/dev/null " \
                             "| grep -qs '^Status:.*installed$'")
  end
end

Then /^I install "(.+)" using apt$/ do |package|
  recovery_proc = proc do
    step 'I kill the process "apt"'
    # We can't use execute_successfully here: the package might not be
    # installed at this point, and then "apt purge" would return non-zero.
    $vm.execute("apt purge #{package}")
  end
  retry_tor(recovery_proc) do
    Timeout.timeout(3 * 60) do
      $vm.execute("echo #{@sudo_password} | " \
                  "sudo -S DEBIAN_PRIORITY=critical apt -y install #{package}",
                  user:  LIVE_USER,
                  spawn: true)
      wait_for_package_installation(package)
    end
  end
end

def wait_for_package_removal(package)
  try_for(3 * 60) do
    # Once purged, a package is removed from the installed package status
    # database and "dpkg -s" returns a non-zero exit code
    !$vm.execute("dpkg -s #{package}").success?
  end
end

Then /^I uninstall "(.+)" using apt$/ do |package|
  $vm.execute_successfully("echo #{@sudo_password} | " \
                               "sudo -S apt -y purge #{package}",
                           user:  LIVE_USER,
                           spawn: true)
  wait_for_package_removal(package)
end

When /^I configure APT to prefer an old version of cowsay$/ do
  apt_source = 'deb tor+http://deb.tails.boum.org/ asp-test-upgrade-cowsay main'
  apt_pref = <<~PREF
    Package: cowsay
    Pin: release o=Tails,a=asp-test-upgrade-cowsay
    Pin-Priority: 999
  PREF
  $vm.file_overwrite('/etc/apt/sources.list.d/asp-test-upgrade-cowsay.list',
                     apt_source)
  $vm.file_overwrite('/etc/apt/preferences.d/asp-test-upgrade-cowsay', apt_pref)
end

When /^I install an old version "([^"]*)" of the cowsay package using apt$/ do |version|
  step 'I update APT using apt'
  step 'I install "cowsay" using apt'
  step "the installed version of package \"cowsay\" is \"#{version}\""
end

When /^I revert the APT tweaks that made it prefer an old version of cowsay$/ do
  $vm.execute_successfully(
    'rm -f /etc/apt/sources.list.d/asp-test-upgrade-cowsay.list ' \
    '/etc/apt/preferences.d/asp-test-upgrade-cowsay'
  )
end

When /^the installed version of package "([^"]*)" is( newer than)? "([^"]*)"( after Additional Software has been started)?$/ do |package, newer_than, version, asp|
  step 'the Additional Software installation service has started' if asp
  current_version = $vm.execute_successfully(
    "dpkg-query -W -f='${Version}' #{package}"
  ).stdout
  if newer_than
    cmd_helper("dpkg --compare-versions '#{version}' lt '#{current_version}'")
  else
    assert_equal(version, current_version)
  end
end

When /^I start Synaptic$/ do
  step 'I start "Synaptic Package Manager" via GNOME Activities Overview'
  deal_with_polkit_prompt(@sudo_password)
  @synaptic = Dogtail::Application.new('synaptic')
  # The seemingly spurious space is needed because that is how this
  # frame is named...
  @synaptic.child(
    'Synaptic Package Manager ', roleName: 'frame', recursive: false
  )
end

When /^I update APT using Synaptic$/ do
  recovery_proc = proc do
    step 'I kill the process "synaptic"'
    step 'I start Synaptic'
  end
  retry_tor(recovery_proc) do
    @synaptic.button('Reload').click
    sleep 10 # It might take some time before APT starts downloading
    try_for(15 * 60, msg: 'Took too much time to download the APT data') do
      !$vm.process_running?('/usr/lib/apt/methods/tor+http')
    end
    assert_raise(Dogtail::Failure) do
      @synaptic.child(roleName: 'dialog', recursive: false)
               .child('Error', roleName: 'icon', retry: false)
    end
    unless $vm.process_running?('synaptic')
      raise 'Synaptic process vanished, did it segfault again?'
    end
  end
end

Then /^I install "(.+)" using Synaptic$/ do |package_name|
  recovery_proc = proc do
    step 'I kill the process "synaptic"'
    # We can't use execute_successfully here: the package might not be
    # installed at this point, and then "apt purge" would return non-zero.
    $vm.execute("apt -y purge #{package_name}")
    step 'I start Synaptic'
  end
  retry_tor(recovery_proc) do
    @synaptic.button('Search').click
    find_dialog = @synaptic.dialog('Find')
    find_dialog.child(roleName: 'text').typeText(package_name)
    find_dialog.button('Search').click
    package_list = @synaptic.child('Installed Version',
                                   roleName: 'table column header').parent
    package_entry = package_list.child(package_name, roleName: 'table cell')
    package_entry.doubleClick
    @synaptic.button('Apply').click
    apply_prompt = nil
    try_for(60) do
      apply_prompt = @synaptic.dialog('Summary')
      true
    end
    apply_prompt.button('Apply').click
    try_for(4 * 60) do
      @synaptic.child('Changes applied', roleName: 'frame', recursive: false)
      true
    end
    step 'I kill the process "synaptic"'
  end
end
