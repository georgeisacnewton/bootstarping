require_relative 'argo-sdc-location'
require_relative 'argo-sdc-options'

ENV['SDC_TESTING']='true'

module ArgoSdc
  include ArgoSdc::Location
  def self.creator
    ENV['SUDO_USER'] || ENV['LOGNAME'] || ENV['USER']
  end

  def self.setupenv(config)
    if ENV['SDC_KEY_ID'].nil? || ENV['SDC_KEY_ID'] == ''
      ENV['SDC_KEY_ID'] = `ssh-add -l | grep '(RSA)' | cut -d' ' -f2 | head -n1 | tr -d "\n"`
    end
    if config[:keyid]
      ENV['SDC_KEY_ID'] = config[:keyid]
    end

    if ENV['SDC_ACCOUNT'].nil? || ENV['SDC_ACCOUNT'] == ''
      ENV['SDC_ACCOUNT'] = ENV['user']
    end
    if config[:user]
      ENV['SDC_ACCOUNT'] = config[:user]
    end
    
    ENV['SDC_URL'] = LOCATIONS[config[:zone]]
    ENV['SDC_TESTING'] = 'true'
  end
end
