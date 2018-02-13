require 'pp'
require 'mixlib/shellout'
require 'json'

require_relative 'argo-sdc-common'

class ArgoSdcDelete < ArgoSdc::CLI
  include ArgoSdc::Location
  gen_opts(['user','zone','keyid','idbautodelete', 'verbose'])
  def run
    ArgoSdc::setupenv(config)

    # Later versions of Mixlib::CLI don't mutate ARGV.
    # They leave unparsed args in @cli_arguments
    self.banner="Usage: #{$0} (options) SERIAL"
    args = parse_options
    machines = config[:cli_arguments] || args

    if config[:verbose]
      print "CLI options: "
      pp config
    end

    machines.each do |m|
      puts m
      idb_command = ['curl',"http://idb.services.dmtio.net/hosts?q=#{m}&fields=location,offline,host"]
      c = Mixlib::ShellOut.new(idb_command)
      c.run_command
      idb_info = JSON.parse(c.stdout)
      

      if config[:verbose]
	print "IDB info for #{m}: "
	pp idb_info
      end

      if idb_info.length > 0
        config[:zone] = idb_info[0]['location']
        raise "unknown zone: #{config[:zone]}" unless LOCATIONS[config[:zone]]

        delete_from_idb = config[:idbautodelete]

        if idb_info[0]['offline']
          delete_from_idb = false
        end  

        unless idb_info[0]['offline'] or delete_from_idb
          print "#{m} is not offline in the IDB. Type \"yes\" to take it offline! "
          input = $stdin.gets.strip
          if input == 'yes'
           delete_from_idb = true
          end
        end

        if delete_from_idb
          puts "Offlining #{m} in the IDB"
          delete_command = ['/usr/local/bin/host-offline', m]
          c = Mixlib::ShellOut.new(delete_command)
          c.run_command
          puts c.stdout if config[:verbose]
          c.error!
        end
      else
        puts "Could not find #{m} in IDB. Proceeding with SDC deletion."
      end

      idb_info.each { |i|
        puts "Removing #{i['host']} from monitoring"
        command = [ 'remove-monitoring', i['host'] ]
        c = Mixlib::ShellOut.new(command)
        c.run_command
        puts c.stdout
        c.error!
      }
      command = ["sdc-deletemachine", m]
      c = Mixlib::ShellOut.new(command)
      c.run_command
      puts c.stdout if config[:verbose]
      c.error!

      puts "Adding :terminated flag in idb"
      timenow = { :terminated => Time.now.strftime("%Y-%m-%dT%H:%M:%S") }
      command=["curl","-sX","PUT","idb.services.dmtio.net/hosts/#{m}","-d",timenow.to_json]
      c = Mixlib::ShellOut.new(command)
      c.run_command
      #puts c.stdout if config[:verbose] # this produces a lot output
      c.error!
    end
  end
end
