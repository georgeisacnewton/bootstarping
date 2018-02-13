Gem::Specification.new do |s|
  s.name        = 'argo-sdc-utils'
  s.version     = "0.4.0"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Brian Akins']
  s.email       = ['brian.akins@turner.com']
  s.summary     = ''
  s.description = ''

  s.files        = Dir.glob('{bin,lib}/**/*')
  s.executables  = Dir.glob('bin/*').map{|f| File.basename(f)}.reject{|f| f =~ /^ac-/}
  s.require_path = 'lib'

  s.add_dependency('erubis')
  s.add_dependency('mixlib-cli')
  s.add_dependency('mixlib-shellout')
  s.add_dependency('json')

end
