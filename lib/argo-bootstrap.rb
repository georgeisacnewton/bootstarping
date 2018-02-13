require 'mixlib/shellout'
require 'erubis'
require 'pp'
require 'tempfile'

require_relative 'argo-sdc-common'

class ArgoMkBootstrap < ArgoSdc::CLI
  include ArgoSdc::Location
  gen_opts(['image','flavor','network','zone','bootstrap','user','customer','conftag','products','chassis','destination'])
  def run

    self.banner="usage: #{$0} -C chassis -f package_size [-l location -D destination -c CUSTOMER -n network]"
    args = parse_options

    creator = ArgoSdc::creator

    config[:network] ||= 'SHARED'
    config[:user] ||= 'ictops'
    config[:customer] ||= 'ictops'
    config[:conftag] ||= config[:network].upcase

    raise "-s CHASSIS required" unless config[:chassis]
    template = load_template
    bootstrap = template.result({
				conftag: config[:conftag],
                                network: config[:network].upcase,
                                package: config[:flavor],
                                location: config[:zone],
                                owner: config[:user],
                                chassis: config[:chassis],
                                customer: config[:customer] || config[:user],
                                creator: creator,
                                products: Hash[config[:products].map{|i| p, e = i.split(':',2); [ p, e || config[:network].downcase ]}]
				})

    t = Tempfile.new(File.basename(__FILE__))
    t.write(bootstrap)
    t.close

    c = Mixlib::ShellOut.new([ 'scp', '-v', t.path, config[:destination] ])
    c.run_command
    c.error!
    File.unlink t.path
    puts "created #{config[:destination]}"
  end

  def load_template
    Erubis::Eruby.new(File.read(config[:bootstrap]))
  end

end

