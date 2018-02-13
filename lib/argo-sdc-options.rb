require 'mixlib/cli'

require_relative 'argo-sdc-location'

module ArgoSdc
  class CLI
    include Mixlib::CLI
    def self.gen_opts(optionlist)
      option :image,
      :short => "-i IMAGE",
      :long  => "--image IMAGE",
      :default => 'ubuntu-certified-14.04',
      :description => "The image to use [ubuntu-certified-14.04]"

      option :flavor,
      :short => "-f FLAVOR",
      :long  => "--flavor FLAVOR",
      :default => '2x4x32-kvm',
      :description => "The flavor to use [2x4x32-kvm]"

      option :network,
      :short => "-n NETWORK",
      :long  => "--network NETWORK",
      :default => 'Shared',
      :description => "Network segment [SHARED|PROD]",
      :proc => Proc.new { |n| n.downcase.capitalize }

      option :zone,
      :short => "-z ZONE",
      :long  => "--zone ZONE",
      :default => ArgoSdc::Location::my_zone(),
      :description => "Zone of the VM [lax|56m]"

      option :bootstrap,
      :short => "-b BOOTSTRAP",
      :long  => "--bootstrap BOOTSTRAP",
      :default => File.join(File.dirname(__FILE__), 'bootstrap.erb'),
      :description => "Bootstrap to use"

      option :user,
      :short => "-u USER",
      :long => "--user USER",
      :default => ENV.fetch('SDC_ACCOUNT', ENV['USER']),
      :description => 'Joyent user id',
      :required => true

      option :customer,
      :short => "-c CUSTOMER",
      :long => "--customer CUSTOMER",
      :description => 'Customer [CNN|CAPI|...]'

      option :keyid,
      :short => '-k KEYID',
      :long => '--keyid KEYID',
      :default => ENV['SDC_KEY_ID'],
      :description => 'SDC ssh key id',
      :required => true

      option :products,
      :short => '-p PRODUCTS',
      :long => '--products PRODUCTS',
      :proc => lambda { |o| o.split(/[\s,]+/) },
      :description => 'Comma-separated list of product:environment pairs to product-install',
      :default => []

      option :segment,
      :short => '-s SEGMENT',
      :long  => '--segment SEGMENT',
      :description => 'Specific segment to provision the new machine. Default is a random one'

      option :idbautodelete,
      :short => '-O',
      :long => '--idbautooffline',
      :description => 'Offline machine in IDB too',
      :boolean => true,
      :default => false

      option :conftag,
      :long => '--conftag TAG',
      :description => 'Conftag'

      option :verbose,
      :boolean => true,
      :long => '--verbose',
      :short => '-v',
      :description => 'Verbose output'

      option :chassis,
      :short => "-C CHASSIS",
      :long => "--chassis CHASSIS",
      :description => 'Chassis [SDC_VIRTUAL|VMWARE_VIRTUAL|...]'

      option :destination,
      :short => "-D [host:]path",
      :long => "--destination [host:]path",
      :default => "./bootstrap.sh",
      :description => 'scp the script to destination e.g. remotehost:~/argo-bootstrap.sh'

      options.keep_if {|i| optionlist.include? "#{i}"}
    end
  end
end
