require 'mixlib/shellout'
require 'json'
require 'pp'
require 'tempfile'
require 'net/http'
require 'uri'

require_relative 'argo-sdc-common'

class ArgoSdcCreate < ArgoSdc::CLI
  include ArgoSdc::Location
  gen_opts(['segment','image','flavor','network','zone','bootstrap','user','customer','keyid','products', 'conftag', 'verbose'])

  def create_machine(image, flavor, network)
    bootstrap     = false
    bootstrap_url = ENV['BOOTSTRAP_URL'] || 'http://bootstrap.services.dmtio.net/v1/get_bootstrap';
    bootstrap_uri = URI(bootstrap_url);
    customer      = config[:customer] || config[:user];
    products      = Hash[config[:products].map{|i| p, e = i.split(':',2); [ p, e || config[:network].downcase ]}];
    post_data     = {
      "chassis" => "SDC_VIRTUAL",
      "package" => "#{config[:flavor]}",
      "location" => "#{config[:zone]}",
      "owner" => "#{config[:user]}",
      "customer" => "#{customer}",
      "network" => "#{config[:network].upcase}",
      "conftag" => "#{config[:conftag]}",
      "creator" => "#{config[:creator]}",
      "products" => []
    };
    products.each do |prod,env|
      post_data['products'].push({"name" => prod, "environment" => env});
    end
    Net::HTTP.new(bootstrap_uri.host, bootstrap_uri.port).start do |client|
      request                 = Net::HTTP::Post.new(bootstrap_uri.path)
      request.body            = post_data.to_json
      request["Content-Type"] = "application/json"
      res = client.request(request)
      raise "Error code #{res.code} trying to post to #{bootstrap_url}" if res.code != "200"
      json_return = JSON.parse(res.body);
      raise "Error from bootstrap api: #{json_return['error']}" if json_return['error']
      bootstrap = json_return['bootstrap']
    end

    t = Tempfile.new(File.basename(__FILE__))
    t.write(bootstrap)
    t.close

    command = [ 'sdc-createmachine', '--image', image, '--package', flavor, '--networks', network, '--script', t.path, '--metadata', 'creator=' + config[:creator] ]

    machine = run_command(command)
    File.unlink t.path

    return machine
  end

  def run
    ArgoSdc::setupenv(config)

    raise "unknown zone: #{config[:zone]}" unless LOCATIONS[config[:zone]]

    image = image(config[:image])['id']
    raise "unknown image" unless image

    flavor = flavor(config[:flavor])['id']
    raise "unknown flavor" unless flavor

    config[:creator] = ArgoSdc::creator

    gotmachine = false

    until gotmachine
      network_obj = network() # This potentially updates config[:network] if segmetn is set
      network = network_obj['id']
      raise "unknown network" unless network

      config[:conftag] ||= config[:network].upcase

      raise "PROD machines can only be created as ictops" if config[:network].upcase == 'PROD' && config[:user] != 'ictops'

      machine = create_machine(image, flavor, network)

      puts "Attempting to create #{machine['id']}"

      got_machine_result = false

      until got_machine_result
        sleep 5
        info = run_command([ 'sdc-getmachine', machine['id'] ])
              
        if info['ips'] and info['ips'].any?
          got_machine_result = true
          gotmachine = true

	  product           = ENV['PRODUCT_OVERRIDE'] || File.dirname(__FILE__).split('/')[2]
	  environment       = ENV['ENVIRONMENT_OVERRRIDE'] || `getenv #{product} | grep '^ENVIRONMENT=' | cut -d'"' -f2`.chomp()
	  customer      = config[:customer] || config[:user];
	  products      = Hash[config[:products].map{|i| p, e = i.split(':',2); [ p, e || config[:network].downcase ]}];
	  command = [ 'sdc-addmachinetags', '--tag', "creator=#{config[:creator]}", '--tag', "customer=#{customer}", '--tag', "environment=#{environment}", '--tag', "owner=#{config[:user]}", '--tag', "product=#{products.keys.join(',')}", machine['id'] ]
	  puts run_command(command)

        elsif info['state'] == 'failed'
          got_machine_result = true
          config[:tried_networks] ||= []
          config[:tried_networks].push(network_obj['name'])
          puts "CREATION FAILED in #{network_obj['name']}, maybe it should be put in config.DISABLED_NETWORKS"
          if config[:segment]
            exit -1
          else 
            puts "Retrying in a different segment"
          end
        else
          puts 'Waiting for IP'
        end
      end
    end

	pp info['ips']
      end

  def load_template
    Erubis::Eruby.new(File.read(config[:bootstrap]))
  end

  def run_command(command)
    command_to_run = Array(command).join(' ')
    puts command_to_run if config[:verbose]
    command_result = `#{command_to_run}`
    JSON.parse(command_result)
  end

  def image(name)
    images.select{|i| i['name'] == name}.last
  end

  def images
    @images ||= run_command('sdc-listimages')
  end

  def flavor(name)
    flavors.select{|i| i['name'] == name}.first
  end

  def flavors
    @flavors ||= run_command('sdc-listpackages')
  end

  def network()
    if config[:segment]
      network = networks.select{|i| i['name'] == config[:segment]}.first
      unless network
	pp networks
	raise "unknown network" unless network
      end
      config[:network] = network['name'].split('-')[0].upcase
      return network
    end 

    config[:tried_networks] ||= []
    # we randomly grab a mathcing network
    our_networks = networks.select{|i| i['name'].split('-').first == config[:network] }
    possible_networks = our_networks.select{|i| (not disabled_networks().include?(i['name'])) && (not config[:tried_networks].include?(i['name']))}


    if possible_networks.length > 0
      return possible_networks.sample
    else
      puts 'No networks to provision in !'
      puts "Segments in #{name}: #{our_networks.map{|i| i['name']}.join(', ')}"
      puts "Disabled Networks: #{disabled_networks.join(', ')}"
      puts "Networks where we did not succeed: #{config[:tried_networks].join(', ')}"
      puts "Selected segment: #{config[:segment]}" if config[:segment]
      exit 1
    end
  end

  def disabled_networks
    unless @disabled_networks
    # hacky stuff to disable certain networks for now
      product           = ENV['PRODUCT_OVERRIDE'] || File.dirname(__FILE__).split('/')[2]
      environment       = ENV['ENVIRONMENT_OVERRRIDE'] || `getenv #{product} | grep '^ENVIRONMENT=' | cut -d'"' -f2`.chomp()
      puts "product=#{product} environment=#{environment}" if config[:verbose]
      @disabled_networks = `curl -s http://deployit.lax.dmtio.net:19601/deployments/#{product}/#{environment} | jq -r '.config.DISABLED_NETWORKS'`.chomp().split(' ')
    end
    @disabled_networks
  end

  def networks
    @networks ||= run_command('sdc-listnetworks')
  end

end

