When /^I start the Unsafe Browser(?: through the GNOME menu)?$/ do
  step 'I start "Unsafe Browser" via GNOME Activities Overview'
end

When /^I successfully start the Unsafe Browser$/ do
  step 'I start the Unsafe Browser'
  step 'I see and accept the Unsafe Browser start verification'
  step 'I see the "Starting the Unsafe Browser..." notification ' \
       'after at most 60 seconds'
  step 'the Unsafe Browser has started'
end

# This step works reliably only when there's no more than one tab:
# otherwise, browser.tabs.warnOnClose will block this with a
# "Quit and close tabs?" dialog.
When /^I close the (?:Tor|Unsafe) Browser$/ do
  @screen.press('ctrl', 'q')
end

def tor_browser_application_info(defaults)
  user = LIVE_USER
  binary = $vm.execute_successfully(
    'echo ${TBB_INSTALL}/firefox.real', libs: 'tor-browser'
  ).stdout.chomp
  cmd_regex = "#{binary} .* -profile " \
              "/home/#{user}/\.tor-browser/profile\.default"
  defaults.merge(
    {
      user:                        user,
      cmd_regex:                   cmd_regex,
      chroot:                      '',
      new_tab_button_image:        'TorBrowserNewTabButton.png',
      browser_reload_button_image: 'TorBrowserReloadButton.png',
      browser_stop_button_image:   'TorBrowserStopButton.png',
    }
  )
end

def unsafe_browser_application_info(defaults)
  user = 'clearnet'
  binary = $vm.execute_successfully(
    'echo ${TBB_INSTALL}/firefox.real', libs: 'tor-browser'
  ).stdout.chomp
  cmd_regex = "#{binary} .* " \
              "-profile /home/#{user}/\.unsafe-browser/profile\.default"
  defaults.merge(
    {
      user:                        user,
      cmd_regex:                   cmd_regex,
      chroot:                      '/var/lib/unsafe-browser/chroot',
      new_tab_button_image:        'UnsafeBrowserNewTabButton.png',
      browser_reload_button_image: 'UnsafeBrowserReloadButton.png',
      browser_stop_button_image:   'UnsafeBrowserStopButton.png',
    }
  )
end

def tor_launcher_application_info(defaults)
  user = 'tor-launcher'
  # We do not enable AppArmor confinement for the Tor Launcher.
  binary = $vm.execute_successfully(
    'echo ${TBB_INSTALL}/firefox-unconfined', libs: 'tor-browser'
  ).stdout.chomp
  tor_launcher_install = $vm.execute_successfully(
    'echo ${TOR_LAUNCHER_INSTALL}', libs: 'tor-browser'
  ).stdout.chomp
  cmd_regex = "#{binary}\s+-app #{tor_launcher_install}/application\.ini.*"
  defaults.merge(
    {
      user:                        user,
      cmd_regex:                   cmd_regex,
      chroot:                      '',
      new_tab_button_image:        nil,
      browser_reload_button_image: nil,
      browser_stop_button_image:   nil,
      address_bar_image:           nil,
      # The standalone Tor Launcher uses fewer libs than the full
      # browser.
      unused_tbb_libs:             defaults[:unused_tbb_libs]
        .concat(['libfreebl3.so', 'libfreeblpriv3.so',
                 'libnssckbi.so', 'libsoftokn3.so',]),
    }
  )
end

def xul_application_info(application)
  defaults = {
    address_bar_image: 'BrowserAddressBar.png',
    unused_tbb_libs:   ['libnssdbm3.so', 'libmozavcodec.so', 'libmozavutil.so'],
  }
  case application
  when 'Tor Browser'
    tor_browser_application_info(defaults)
  when 'Unsafe Browser'
    unsafe_browser_application_info(defaults)
  when 'Tor Launcher'
    tor_launcher_application_info(defaults)
  else
    raise "Invalid browser or XUL application: #{application}"
  end
end

When /^I open a new tab in the (.*)$/ do |browser|
  info = xul_application_info(browser)
  @screen.click(info[:new_tab_button_image])
  @screen.wait(info[:address_bar_image], 10)
end

When /^I open the address "([^"]*)" in the (.*)$/ do |address, browser|
  step "I open a new tab in the #{browser}"
  info = xul_application_info(browser)
  open_address = proc do
    @screen.click(info[:address_bar_image])
    # This static here since we have no reliable visual indicators
    # that we can watch to know when typing is "safe".
    sleep 5
    # The browser sometimes loses keypresses when suggestions are
    # shown, which we work around by pasting the address from the
    # clipboard, in one go.
    $vm.set_clipboard(address)
    @screen.press('ctrl', 'v')
    @screen.press('Return')
  end
  recovery_on_failure = proc do
    @screen.press('Escape')
    @screen.wait_vanish(info[:browser_stop_button_image], 3)
    open_address.call
  end
  retry_method = if browser == 'Tor Browser'
                   method(:retry_tor)
                 else
                   proc { |p, &b| retry_action(10, recovery_proc: p, &b) }
                 end
  open_address.call
  retry_method.call(recovery_on_failure) do
    @screen.wait_vanish(info[:browser_stop_button_image], 120)
    @screen.wait(info[:browser_reload_button_image], 120)
  end
end

def page_has_loaded_in_the_tor_browser(page_titles)
  page_titles = [page_titles] if page_titles.class == String
  assert_equal(Array, page_titles.class)
  if $language == 'German'
    browser_name = 'Tor-Browser'
    reload_action = 'Neu laden'
  else
    browser_name = 'Tor Browser'
    reload_action = 'Reload'
  end
  try_for(180) do
    # The 'Reload' button (graphically shown as a looping arrow)
    # is only shown when a page has loaded, so once we see the
    # expected title *and* this button has appeared, then we can be sure
    # that the page has fully loaded.
    @torbrowser.children(roleName: 'frame', showingOnly: true).any? do |frame|
      page_titles
        .map  { |page_title| "#{page_title} - #{browser_name}" }
        .any? { |page_title| page_title == frame.name }
    end &&
      @torbrowser.child(reload_action, roleName:    'push button',
                                       showingOnly: true)
  end
end

# This step is limited to the Tor Browser due to #7502 since dogtail
# uses the same interface.
Then /^"([^"]+)" has loaded in the Tor Browser$/ do |title|
  page_has_loaded_in_the_tor_browser(title)
end

Then /^the (.*) has no plugins installed$/ do |browser|
  step "I open the address \"about:plugins\" in the #{browser}"
  step 'I see "TorBrowserNoPlugins.png" after at most 30 seconds'
end

def xul_app_shared_lib_check(pid, chroot, expected_absent_tbb_libs = [])
  absent_tbb_libs = []
  unwanted_native_libs = []
  tbb_libs = $vm.execute_successfully("ls -1 #{chroot}${TBB_INSTALL}/*.so",
                                      libs: 'tor-browser').stdout.split
  firefox_pmap_info = $vm.execute("pmap --show-path #{pid}").stdout
  tbb_libs.each do |lib|
    lib_name = File.basename lib
    absent_tbb_libs << lib_name unless /\W#{lib}$/.match(firefox_pmap_info)
    native_libs = $vm.execute_successfully(
      "find /usr/lib /lib -name \"#{lib_name}\""
    ).stdout.split
    native_libs.each do |native_lib|
      if /\W#{native_lib}$"/.match(firefox_pmap_info)
        unwanted_native_libs << lib_name
      end
    end
  end
  absent_tbb_libs -= expected_absent_tbb_libs
  assert(absent_tbb_libs.empty? && unwanted_native_libs.empty?,
         'The loaded shared libraries for the firefox process are not the ' \
         "way we expect them.\n" \
         "Expected TBB libs that are absent: #{absent_tbb_libs}\n" \
         "Native libs that we don't want: #{unwanted_native_libs}")
end

Then /^the (.*) uses all expected TBB shared libraries$/ do |application|
  info = xul_application_info(application)
  pid = $vm.execute_successfully(
    "pgrep --uid #{info[:user]} --full --exact '#{info[:cmd_regex]}'"
  ).stdout.chomp
  assert_match(/\A\d+\z/, pid, "It seems like #{application} is not running")
  xul_app_shared_lib_check(pid, info[:chroot], info[:unused_tbb_libs])
end

Then /^the (.*) chroot is torn down$/ do |browser|
  info = xul_application_info(browser)
  try_for(30, msg: "The #{browser} chroot '#{info[:chroot]}' was " \
                      'not removed') do
    !$vm.execute("test -d '#{info[:chroot]}'").success?
  end
end

Then /^the (.*) runs as the expected user$/ do |browser|
  info = xul_application_info(browser)
  assert_vmcommand_success(
    $vm.execute("pgrep --full --exact '#{info[:cmd_regex]}'"),
    "The #{browser} is not running"
  )
  assert_vmcommand_success(
    $vm.execute(
      "pgrep --uid #{info[:user]} --full --exact '#{info[:cmd_regex]}'"
    ),
    "The #{browser} is not running as the #{info[:user]} user"
  )
end

When /^I download some file in the Tor Browser$/ do
  @some_file = 'tails-signing.key'
  some_url = "https://tails.boum.org/#{@some_file}"
  step "I open the address \"#{some_url}\" in the Tor Browser"
end

Then /^I get the browser download dialog$/ do
  @screen.wait('BrowserDownloadDialog.png', 60)
  @screen.wait('BrowserDownloadDialogSaveAsButton.png', 10)
end

When /^I save the file to the default Tor Browser download directory$/ do
  @screen.click('BrowserDownloadDialogSaveAsButton.png')
  @screen.wait('Gtk3SaveFileDialog.png', 10)
  @screen.press('Return')
end

Then /^the file is saved to the default Tor Browser download directory$/ do
  assert_not_nil(@some_file)
  expected_path = "/home/#{LIVE_USER}/Tor Browser/#{@some_file}"
  try_for(10) { $vm.file_exist?(expected_path) }
end

When /^I open the Tails homepage in the (.+)$/ do |browser|
  step "I open the address \"https://tails.boum.org\" in the #{browser}"
end

Then /^the Tails homepage loads in the Unsafe Browser$/ do
  @screen.wait('TailsHomepage.png', 60)
end

Then /^the Tor Browser shows the "([^"]+)" error$/ do |error|
  try_for(60) do
    page = @torbrowser.child('Problem loading page - Tor Browser',
                             roleName: 'frame')
    page.children(roleName: 'heading').any? { |heading| heading.text == error }
  end
end

Then /^I can listen to an Ogg audio track in Tor Browser$/ do
  test_url = 'https://archive.org/download/MussorgskyPicturesAtAnExhibitionorch.Ravel/09Mussorgsky_PicturesAtAnExhibition-LimogesTheMarketPlace.ogg'
  info = xul_application_info('Tor Browser')
  open_test_url = proc do
    step "I open the address \"#{test_url}\" in the Tor Browser"
  end
  recovery_on_failure = proc do
    @screen.press('Escape')
    @screen.wait_vanish(info[:browser_stop_button_image], 3)
    open_test_url.call
  end
  step 'no application is playing audio'
  open_test_url.call
  retry_tor(recovery_on_failure) do
    step '1 application is playing audio after 30 seconds'
  end
end

Then /^I can watch a WebM video in Tor Browser$/ do
  test_url = WEBM_VIDEO_URL
  info = xul_application_info('Tor Browser')
  open_test_url = proc do
    step "I open the address \"#{test_url}\" in the Tor Browser"
  end
  recovery_on_failure = proc do
    @screen.press('Escape')
    @screen.wait_vanish(info[:browser_stop_button_image], 3)
    open_test_url.call
  end
  open_test_url.call
  retry_tor(recovery_on_failure) do
    @screen.wait('TorBrowserSampleRemoteWebMVideoFrame.png', 30)
  end
end
