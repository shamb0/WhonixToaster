def gedit
  @gedit ||= Dogtail::Application.new('gedit')
end

def gedit_text_buffer
  gedit
    .child(roleName: 'frame',       showingOnly: true)
    .child(roleName: 'scroll pane', showingOnly: true)
    .child(roleName: 'text',        showingOnly: true)
end

def seahorse_menu_click_helper(main, sub, verify = nil)
  try_for(60) do
    step "process \"#{verify}\" is running" if verify
    @screen.hide_cursor
    @screen.wait(main, 10).click
    @screen.wait(sub, 10).click
    return
  end
end

Given /^I generate an OpenPGP key named "([^"]+)" with password "([^"]+)"$/ do |name, pwd|
  @passphrase = pwd
  @key_name = name
  gpg_key_recipe = <<RECIPE
     Key-Type: RSA
     Key-Length: 4096
     Subkey-Type: RSA
     Subkey-Length: 4096
     Name-Real: #{@key_name}
     Name-Comment: Blah
     Name-Email: #{@key_name}@test.org
     Expire-Date: 0
     Passphrase: #{pwd}
     %commit
RECIPE
  recipe_path = '/tmp/gpg_key_recipe'
  $vm.file_overwrite(recipe_path, gpg_key_recipe)
  $vm.execute("chown #{LIVE_USER}:#{LIVE_USER} #{recipe_path}")
  c = $vm.execute("gpg --batch --gen-key < #{recipe_path}",
                  user: LIVE_USER)
  assert(c.success?, "Failed to generate OpenPGP key:\n#{c.stderr}")
end

When /^I type a message into gedit$/ do
  step 'I start "gedit" via GNOME Activities Overview'
  text_buffer = gedit_text_buffer
  text_buffer.grabFocus
  text_buffer.typeText('ATTACK AT DAWN')
end

def deal_with_pinentry
  pinentry = Dogtail::Application.new('pinentry-gtk-2')
  pinentry.child('', roleName: 'password text').typeText(@passphrase)
  pinentry.button('OK').click
end

def maybe_deal_with_pinentry
  deal_with_pinentry
rescue Dogtail::Failure
  # The passphrase was cached or we wasn't prompted at all (e.g. when
  # only encrypting to a public key)
end

def gedit_copy_all_text
  gedit_text_buffer.right_click
  gedit.child('Select All', roleName: 'menu item', showingOnly: true).click
  gedit_text_buffer.right_click
  gedit.child('Copy', roleName: 'menu item', showingOnly: true).click
end

def gedit_paste_into_a_new_tab
  gedit.button('New').click
  gedit_text_buffer.right_click
  gedit.child('Paste', roleName: 'menu item', showingOnly: true).click
end

def encrypt_sign_helper
  gedit_copy_all_text
  seahorse_menu_click_helper('GpgAppletIconNormal.png',
                             'GpgAppletSignEncrypt.png')
  @screen.wait('GpgAppletChooseKeyWindow.png', 30).click
  # We don't have a good visual indicator for when we can continue without
  # keystrokes being lost.
  sleep 5
  yield
  maybe_deal_with_pinentry
  gedit_paste_into_a_new_tab
end

def decrypt_verify_helper(icon)
  gedit_copy_all_text
  seahorse_menu_click_helper(icon, 'GpgAppletDecryptVerify.png')
  maybe_deal_with_pinentry
  @screen.wait('GpgAppletResults.png', 20)
  @screen.wait('GpgAppletResultsMsg.png', 20)
end

When /^I encrypt the message using my OpenPGP key$/ do
  encrypt_sign_helper do
    @screen.type(@key_name)
    @screen.press('Return')
    @screen.press('Return')
  end
end

Then /^I can decrypt the encrypted message$/ do
  decrypt_verify_helper('GpgAppletIconEncrypted.png')
  @screen.wait('GpgAppletResultsEncrypted.png', 20)
end

When /^I sign the message using my OpenPGP key$/ do
  encrypt_sign_helper do
    @screen.press('Tab')
    @screen.press('Down')
    @screen.press('Return')
  end
end

Then /^I can verify the message's signature$/ do
  decrypt_verify_helper('GpgAppletIconSigned.png')
  @screen.wait('GpgAppletResultsSigned.png', 20)
end

When /^I both encrypt and sign the message using my OpenPGP key$/ do
  encrypt_sign_helper do
    @screen.wait('GpgAppletEncryptionKey.png', 20).click
    @screen.press('space')
    @screen.wait('GpgAppletKeySelected.png', 10)
    @screen.press('Tab')
    @screen.press('Down')
    @screen.press('Return')
    @screen.press('Return')
  end
end

Then /^I can decrypt and verify the encrypted message$/ do
  decrypt_verify_helper('GpgAppletIconEncrypted.png')
  @screen.wait('GpgAppletResultsEncrypted.png', 20)
  @screen.wait('GpgAppletResultsSigned.png', 20)
end

When /^I symmetrically encrypt the message with password "([^"]+)"$/ do |pwd|
  @passphrase = pwd
  gedit_copy_all_text
  seahorse_menu_click_helper('GpgAppletIconNormal.png',
                             'GpgAppletEncryptPassphrase.png')
  deal_with_pinentry # enter password
  deal_with_pinentry # confirm password
  gedit_paste_into_a_new_tab
end
