@product
Feature: Browsing the web using the Tor Browser
  As a Whonix user
  when I browse the web using the Tor Browser
  all Internet traffic should flow only through Tor

  @check_tor_leaks
  Scenario: Playing an Ogg audio track
    Given I have started Whonix Workstation and logged in and the network is connected
