// This is the Debian specific preferences file for Mozilla Firefox
// You can make any change in here, it is the purpose of this file.
// You can, with this file and all files present in the
// /etc/thunderbird/pref directory, override any preference that is
// present in /usr/lib/thunderbird/defaults/pref directory.
// While your changes will be kept on upgrade if you modify files in
// /etc/thunderbird/pref, please note that they won't be kept if you
// do them in /usr/lib/thunderbird/defaults/pref.

pref("extensions.update.enabled", false);

// Use LANG environment variable to choose locale from system
// The old environment setting 'pref("intl.locale.matchOS", true);' is
// currently not working anymore. The new introduced setting
// 'intl.locale.requested' is now used for this. Setting an empty string is
// pulling the system locale into Thunderbird.
pref("intl.locale.requested", "");

// Disable default mail checking (gnome).
pref("mail.shell.checkDefaultMail", false);

// if you are not using gnome
pref("network.protocol-handler.app.http", "x-www-browser");
pref("network.protocol-handler.app.https", "x-www-browser");

// Disable mail indexing
pref("mailnews.database.global.indexer.enabled", false);

// Disable chat
pref("mail.chat.enabled", false);

// Hide the "Know your rights" message
pref("mail.rights.version", 1);

// Disable system addons
pref("extensions.autoDisableScopes", 3);
pref("extensions.enabledScopes", 4);

// Only show the tab bar if there's more than one tab to display
pref("mail.tabs.autoHide", true);

// Try to disable "Would you like to help Thunderbird Mail/News by automatically reporting memory usage, performance, and responsiveness to Mozilla"
pref("toolkit.telemetry.prompted", 2);
pref("toolkit.telemetry.rejected", true);
pref("toolkit.telemetry.enabled", false);

// Only allow SSL channels when fetching from the ISP.
pref("mailnews.auto_config.fetchFromISP.sslOnly", true);
// Only allow Thunderbird's automatic configuration wizard to use and
// configure secure (SSL/TLS) protocols.
pref("mailnews.auto_config.sslOnly", true);
pref("mailnews.auto_config.guess.sslOnly", true);

// Drop auto-fetched configurations using Oauth2 -- they do not work
// since we disable needed functionality (like JavaScript and cookies)
// in the embedded browser.
pref("mailnews.auto_config.account_constraints.allow_oauth2", false);
// The timeout (in seconds) for each guess
pref("mailnews.auto_config.guess.timeout", 30);

// Disable Autocrypt by default for new accounts (#16222).
// This does not change anything for accounts that were created before.
pref("mail.server.default.enableAutocrypt", false);

// Don't decrypt subordinate message parts that otherwise might reveal
// decrypted content to the attacker, i.e. the optional part of the fixes
// for EFAIL.
// Reference: https://www.thunderbird.net/en-US/thunderbird/52.9.1/releasenotes/
pref("mailnews.p7m_subparts_external", true);

// Sanitize mime headers
pref("mail.mime.avoid_fingerprinting", true);

// Make all system-wide dictionaries available
pref("spellchecker.dictionary_path", "/usr/share/hunspell");

/*
  Network settings adopted from TorBirdy
*/

// Use a manual proxy configuration.
pref("network.proxy.type", 1);
// Same as in config/chroot_local-includes/usr/share/tails/tor-browser-prefs.js
pref("network.security.ports.banned", "631,6136,4444,4445,6668,7656,7657,7658,7659,7660,8998,9040,9050,9062,9150,9051");
// Number of seconds to wait before attempting to recontact an unresponsive proxy server.
pref("network.proxy.failover_timeout", 1800);

// Configure Thunderbird to use the SOCKS5 proxy.
pref("network.proxy.socks", "127.0.0.1");
pref("network.proxy.socks_port", 9050);
pref("network.proxy.socks_version", 5);

// Set DNS proxying through SOCKS5.
pref("network.proxy.socks_remote_dns", true);
// Disable DNS prefetching.
pref("network.dns.disablePrefetch", true);

// https://lists.torproject.org/pipermail/tor-talk/2011-September/021398.html
// "Towards a Tor-safe Mozilla Thunderbird"
// These options enable a warning that tagnaq suggests.

// Warn when an application is to be launched.
pref("network.protocol-handler.warn-external.http", true);
pref("network.protocol-handler.warn-external.https", true);
pref("network.protocol-handler.warn-external.ftp", true);
pref("network.protocol-handler.warn-external.file", true);
pref("network.protocol-handler.warn-external-default", true);

// Likely privacy violations
// https://blog.torproject.org/blog/experimental-defense-website-traffic-fingerprinting
// https://bugs.torproject.org/3914
pref("network.http.pipelining", true);
pref("network.http.pipelining.aggressive", true);
pref("network.http.pipelining.maxrequests", 12);
pref("network.http.connection-retry-timeout", 0);
pref("network.http.max-persistent-connections-per-proxy", 256);
pref("network.http.pipelining.reschedule-timeout", 15000);
pref("network.http.pipelining.read-timeout", 60000);

// We do not fully understand the privacy issues of the SPDY protocol
// We have no reason to believe that anyone would actually use it with
// Thunderbird but we fail closed to keep users safe out of an abundance of
// caution.
pref("network.http.spdy.enabled", false);
// We want pipelined requests and a bunch of them, as is explained in the
// experimental-defense-website-traffic-fingerprinting blog post by Torbutton
// author Mike Perry.
pref("network.http.pipelining.ssl", true);
pref("network.http.proxy.pipelining", true);
pref("network.http.sendRefererHeader", 2);
// https://bugs.torproject.org/16673
pref("network.http.altsvc.enabled", false);
pref("network.http.altsvc.oe", false);

// Disable proxy bypass issue.
// Websockets have no use in Thunderbird over Tor; some versions of the
// underlying Mozilla networking code allowed websockets to bypass the proxy
// settings - this is deadly to Tor users:
// https://blog.torproject.org/blog/firefox-security-bug-proxy-bypass-current-tbbs
// We don't want user's of Thunderbird to even come close to such a bypass
// issue and so we have disabled websockets out of an abundance of caution.
// XXX: Couldn't find this setting in the Thunderbird source code or on
//      http://kb.mozillazine.org
//      It seems like it has been removed years ago:
//      https://bugzilla.mozilla.org/show_bug.cgi?id=1091016
//      Possible workaround:
//      https://bugzilla.mozilla.org/show_bug.cgi?id=1091016#c24
pref("network.websocket.enabled", false);
// Cookies are allowed, but not third-party cookies. For Gmail and Twitter.
pref("network.cookie.cookieBehavior", 1);
// http://kb.mozillazine.org/Network.cookie.lifetimePolicy
// 2: cookie expires at the end of the session.
pref("network.cookie.lifetimePolicy", 2);
// Disable link prefetching.
pref("network.prefetch-next", false);

/*
Security
*/

// Default is always false for OCSP.
// OCSP servers may log information about a user as they use the internet
// generally; it's everything we hate about CRLs and more.
pref("security.OCSP.enabled", 1);
pref("security.OCSP.GET.enabled", false);
// XXX: Couldn't find this setting in the Thunderbird source code or on
//      http://kb.mozillazine.org
pref("security.OCSP.require", false);
// Disable TLS Session Ticket.
// See https://trac.torproject.org/projects/tor/ticket/4099
// XXX: Couldn't find this setting in the Thunderbird source code or on
//      http://kb.mozillazine.org
//      It seems like it has been removed:
//      https://bugzilla.mozilla.org/show_bug.cgi
//      "security.ssl.disable_session_identifiers" seems to be a replacement:
//      https://bugzilla.mozilla.org/show_bug.cgi?id=967977
pref("security.enable_tls_session_tickets", false);
// Enable SSL3?
// We do not want to enable a known weak protocol; users should use only use TLS
pref("security.enable_ssl3", false);
// Thunderbird 23.0 uses the following preference.
// https://bugs.torproject.org/11253
// March 2017: See https://bugs.torproject.org/20751
pref("security.tls.version.min", 3);
// Display a dialog warning the user when entering an insecure site from a secure one.
pref("security.warn_entering_weak", true);
// Display a dialog warning the user when submtting a form to an insecure site.
pref("security.warn_submit_insecure", true);
// Enable SSL FalseStart.
// This should be safe and improve TLS performance
pref("security.ssl.enable_false_start", true);
// Reject all connection attempts to servers using the old SSL/TLS protocol.
pref("security.ssl.require_safe_negotiation", true);
// Warn when connecting to a server that uses an old protocol version.
pref("security.ssl.treat_unsafe_negotiation_as_broken", true);
// Disable 'extension blocklist' which might leak the OS information.
// See https://trac.torproject.org/projects/tor/ticket/6734
pref("extensions.blocklist.enabled", false);
// Strict: certificate pinning is always enforced.
pref("security.cert_pinning.enforcement_level", 2);

/*
Mail
*/

// Prevent hostname leaks.
pref("mail.smtpserver.default.hello_argument", "[127.0.0.1]");
// Compose messages in plain text (by default).
pref("mail.html_compose", false);
pref("mail.identity.default.compose_html", false);
// Send message as plain text.
pref("mail.default_html_action", 1);
// Disable Thunderbird's 'Get new account' wizard.
pref("mail.provider.enabled", false);
// Don't ask to be the default client.
pref("mail.shell.checkDefaultClient", false);
pref("mail.shell.checkDefaultMail", false);
// Disable inline attachments.
pref("mail.inline_attachments", false);
// Disable IMAP IDLE
// See https://trac.torproject.org/projects/tor/ticket/6337
// XXX: We might want to enable this useful feature in Tails
pref("mail.server.default.use_idle", false);
// Thunderbird's autoconfig wizard is designed to enable an initial
// mail fetch (by setting login_at_start) for the first account it
// creates (which will become the "default" account, see
// msgMail3PaneWindow.js for details) which side-steps the settings
// we apply in fixupTorbirdySettingsOnNewAccount(). Hence, fool
// Thunderbird to think that this initial mail fetch has already
// been done so we get the settings we want.
// XXX: We can probably remove this in Tails
pref("mail.startup.enabledMailCheckOnce", true);

/*
Browser
*/
// Disable caching.
// XXX: I don't know why caching is disabled by TorBirdy. We could use
//      the Tor Browser settings instead, which disables disk caching
//      and offline caching but enables memory caching.
pref("browser.cache.disk.enable", false);
pref("browser.cache.memory.enable", false);
pref("browser.cache.offline.enable", false);
pref("browser.formfill.enable", false);
// https://bugs.torproject.org/22944
pref("browser.chrome.site_icons", false);
pref("browser.chrome.favicons", false);
pref("signon.autofillForms", false);

// https://bugs.torproject.org/10367
pref("datareporting.healthreport.service.enabled", false);
pref("datareporting.healthreport.uploadEnabled", false);
pref("datareporting.policy.dataSubmissionEnabled", false);
pref("datareporting.healthreport.about.reportUrl", "data:text/plain,");

// https://bugs.torproject.org/16254
pref("browser.search.countryCode", "US");
pref("browser.search.region", "US");
pref("browser.search.geoip.url", "");

// These have been copied from Tor Browser and don't apply to Thunderbird
// since the browser surface is limited (Gmail/Twitter) but we set them
// nevertheless.
// Disable client-side session and persistent storage.
// XXX: Tor Browser 9.0 has this setting set to "true"
pref("dom.storage.enabled", false);
// https://bugs.torproject.org/15758
pref("device.sensors.enabled", false);
// https://bugs.torproject.org/5293
// XXX: Tor Browser 9.0 has this setting set to "true"
pref("dom.battery.enabled", false);
// https://bugs.torproject.org/6204
pref("dom.enable_performance", false);
// https://bugs.torproject.org/13023
pref("dom.gamepad.enabled", false);
// https://bugs.torproject.org/8382
// XXX: Tor Browser 9.0 has this setting set to "true"
pref("dom.indexedDB.enabled", false);
// https://bugs.torproject.org/13024
pref("dom.enable_resource_timing", false);
// https://bugs.torproject.org/16336
pref("dom.enable_user_timing", false);
// https://bugs.torproject.org/17046
pref("dom.event.highrestimestamp.enabled", true);

// https://bugs.torproject.org/11817
pref("extensions.getAddons.cache.enabled", false);

/*
Chat and Calendar
*/

// Thunderbird 15 introduces the chat feature so disable the preferences below.
pref("purple.logging.log_chats", false);
pref("purple.logging.log_ims", false);
pref("purple.logging.log_system", false);
pref("purple.conversations.im.send_typing", false);

// Messenger related preferences.
// Do not report idle.
pref("messenger.status.reportIdle", false);
pref("messenger.status.awayWhenIdle", false);
// Set the following preferences to empty strings.
pref("messenger.status.defaultIdleAwayMessage", "");
pref("messenger.status.userDisplayName", "");
// Do not connect automatically.
pref("messenger.startup.action", 0);
// Ignore invitations; do not automatically accept them.
pref("messenger.conversations.autoAcceptChatInvitations", 0);
// Do not format incoming messages.
pref("messenger.options.filterMode", 0);
// On copying the content in the chat window, remove the time information.
// See `comm-central/chat/locales/conversations.properties' for more information.
pref("messenger.conversations.selections.systemMessagesTemplate", "%message%");
pref("messenger.conversations.selections.contentMessagesTemplate", "%sender%: %message%");
pref("messenger.conversations.selections.actionMessagesTemplate", "%sender% %message%");

// Mozilla Lightning.
pref("calendar.useragent.extra", "");

/*
Other Settings
*/

// Disable Google Safe Browsing (#22567).
pref("browser.safebrowsing.enabled", false);
pref("browser.safebrowsing.malware.enabled", false);

// Disable Microsoft Family Safety (From TBB: #21686).
pref("security.family_safety.mode", 0);

// RSS.
pref("rss.display.prefer_plaintext", true);
// These are similar to the mailnews.* settings.
pref("rss.display.disallow_mime_handlers", 3);
pref("rss.display.html_as", 1);
pref("rss.show.content-base", 1);

// Override the user agent by setting it to an empty string.
pref("general.useragent.override", "");

// Disable WebGL.
pref("webgl.disabled", true);

// Disable Telemetry completely.
pref("toolkit.telemetry.enabled", false);

// Disable Geolocation.
pref("geo.enabled", false);

// Disable JavaScript (email).
pref("javascript.enabled", false);

// Disable WebM, WAV, Ogg, PeerConnection.
pref("media.navigator.enabled", false);
pref("media.peerconnection.enabled", false);
pref("media.cache_size", 0);

// Disable CSS :visited selector.
pref("layout.css.visited_links_enabled", false);

// Disable downloadable fonts.
pref("gfx.downloadable_fonts.enabled", false);

// Disable third-party images.
pref("permissions.default.image", 3);
