#\ -p 8080
$:.unshift "#{File.dirname(__FILE__)}/lib/"

gem 'rack'
gem 'json'
gem 'mongrel'

require 'rubygems'
require 'mongrel'
require 'rack'
require 'json'
require 'postfix_ws'

Postfix::PostfixWS.login = "root"
Postfix::PostfixWS.pass = ""

run Postfix::PostfixWS.new
