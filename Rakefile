require 'rubygems'
require 'rake'
require 'rspec/core/rake_task'
#require 'rake/gempackagetask'

namespace :postfixmgr do
  desc 'Initialize fresh env'
  task :install do
    require 'lib/postfix_manager'    
  	include Postfix
  	@mgr = PostfixManager.new()
  	@mgr.turn_relay_off
  	@mgr.set_defer_transports_local    	    
  end
  
  desc 'Run postfix manager Web Service'
  task :server do
    sh 'rackup config.ru'
  end
  
  task :gem do
    spec = Gem::Specification.new do |s|
      s.name          = "postfix-manager"
      s.version       = "0.0.2"
      s.author        = "Jorge Gonzalez"
      s.email         = "jagg81@gmail.com"
      #s.platform      = "Gem::Platform::RUBY"
      s.summary       = "A ruby wrapper for Postfix management"
      s.files         = FileList["{bin,tests,lib,docs}/**/*"].exclude("rdoc").to_a  
      s.bindir = "bin"
      #s.executables << 'postfix_manager'
      #s.default_executable  = "bin/postfix_manager"
      s.require_path  = "lib"
      #s.autorequire   = "config"   #(predicated)
      #s.test_file    = ""
      s.has_rdoc      = false
      s.extra_rdoc_files = ["README"]
      #s.add_dependency("ftools")
    end

    Rake::GemPackageTask.new(spec) do |pkg|
      pkg.need_tar = true
    end      
  end
  
  desc 'Pesaje Tests'
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = './specs/**/*_spec.rb'
    t.rspec_opts = ['--format progress', '--color']
  end

end
