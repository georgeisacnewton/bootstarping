require 'mixlib/shellout'
require 'json'

module ArgoSdc
  module Location
    def self.my_zone()
      e = Mixlib::ShellOut.new('getenv', '--format', 'json', '--host')
      e.run_command
      e.error!
      JSON.parse(e.stdout)['LOCATION']
    end

    LOCATIONS = {
      'lax' => 'https://compute.api.services.lax.dmtio.net',
      '56m' => 'https://compute.api.services.56m.dmtio.net'
    }
  end
end
