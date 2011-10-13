$:.unshift "#{File.dirname(__FILE__)}/../lib"

require 'rubygems'
require 'mongrel'
require 'rack'
require 'json'
require 'postfix_ws'
require 'pp'
require 'rspec'
require 'rack/test'

ENV['RACK_ENV'] = 'test'

describe Postfix::PostfixWS do
	include Rack::Test::Methods
		
	def app
		Postfix::PostfixWS.login = "root"
		Postfix::PostfixWS.pass = ""
		Postfix::PostfixWS.new
	end
	
	before(:all) do 
		@discovery_uri = '/'
	end	
	
	shared_examples_for "GET only resource" do |uri|
		before(:all) do
			@uri = uri
		end
		
		context "GET request" do
			
			it "should return status OK" do			
				get @uri
				last_response.status.should eq(200)
			end
			
		end
		
		context "Other HTTP methods beside GET" do
			
			it "should not respond to POST" do
				post @uri
				last_response.status.should eq(405)
			end
			
			it "should not respond to PUT" do
				put @uri
				last_response.status.should eq(405)
			end
			
			it "should not respond to DELETE" do
				delete @uri
				last_response.status.should eq(405)
			end		
		end
	end
	
	shared_examples_for "POST only resource" do |uri|
		before(:all) do
			@uri = uri
		end
		
		context "POST request" do
			
			it "should return status OK {no content}" do			
				post @uri
				last_response.status.should eq(204)
			end
			
		end
		
		context "Other HTTP methods beside POST" do
			
			it "should not respond to GET" do
				get @uri
				last_response.status.should eq(405)
			end
			
			it "should not respond to PUT" do
				put @uri
				last_response.status.should eq(405)
			end
			
			it "should not respond to DELETE" do
				delete @uri
				last_response.status.should eq(405)
			end		
		end
	end
	
	describe "API Discovery" do
		before(:all) { }

		it_behaves_like "GET only resource", '/'
		
		context "Check Response Body" do
			before(:all) do
				get @discovery_uri
				@resources = JSON.parse(last_response.body, :symbolize_names => true)
			end
			
			subject { @resources }
									
			it "should return a json object in the body" do				
				subject.should be_true
			end
			
			it "should have a version" do
				subject.keys.first.to_s.should include("version")
			end
			
			it "should have resources for each method" do				
				subject.values.first.each_pair do |method_name, resource|
				 resource.should match(/http:\/\//)
				end				
			end
		end
		
		
	end
	
	describe "Queue Size" do
		before(:all) do						
			@method = :queue_size
		end
		
		it_behaves_like "GET only resource", '/queue_size'
		
		context "Check Response Body" do			
			before(:all) do				
				get @discovery_uri
				@resources = JSON.parse(last_response.body, :symbolize_names => true).values.first
				get @resources[@method]
			end
			
			subject { JSON.parse(last_response.body, :symbolize_names => true) }
			
			it "should return a json object in the body" do				
				subject.should be_true
			end
			
			it "should return a Fixnum as value" do				
				subject[@method].should be_kind_of(Fixnum)
			end
			
			it "should respond to method" do
				app.should respond_to(@method)				
			end			
		end		
		
	end
	
	describe "Enable Delivery" do
		before(:all) do
			@method = :enable_delivery
		end
		
		it_behaves_like "POST only resource", '/enable_delivery'
		
		context "Check Response Body" do
			before(:all) do				
				get @discovery_uri
				@resources = JSON.parse(last_response.body, :symbolize_names => true).values.first
				get @resources[@method]
			end
					
			subject { last_response.body }
			
			it "should not have a body" do				
				subject.should be_empty				
			end
		end
	end
	
	describe "Disable Delivery" do
		before(:all) do
			@method = :disable_delivery
		end
		
		it_behaves_like "POST only resource", '/disable_delivery'
		
		context "Check Response Body" do
			before(:all) do				
				get @discovery_uri
				@resources = JSON.parse(last_response.body, :symbolize_names => true).values.first
				get @resources[@method]
			end
					
			subject { last_response.body }
			
			it "should not have a body" do				
				subject.should be_empty				
			end
		end
	end
	
	describe "Clear Queue" do
		before(:all) do
			@method = :clear_queue
		end
		
		it_behaves_like "POST only resource", '/clear_queue'
		
		context "Check Response Body" do
			before(:all) do				
				get @discovery_uri
				@resources = JSON.parse(last_response.body, :symbolize_names => true).values.first
				get @resources[@method]
			end
					
			subject { last_response.body }
			
			it "should not have a body" do				
				subject.should be_empty				
			end
		end
	end
	
	describe "Status" do
		before(:all) do
			@method = :status
		end
		
		it_behaves_like "GET only resource", '/status'
		
		context "Check Response Body" do			
			before(:all) do				
				get @discovery_uri
				@resources = JSON.parse(last_response.body, :symbolize_names => true).values.first
				get @resources[@method]
			end
			
			subject { JSON.parse(last_response.body, :symbolize_names => true) }
			
			it "should return a json object in the body" do				
				subject.should be_true
			end
			
			it "should have a relayhost element" do
				subject.has_key?(:relayhost).should be_true
			end
			
			it "should have a queue_size element" do
				subject.has_key?(:queue_size).should be_true
			end
			
			it "should have a defer_transports element" do
				subject.has_key?(:defer_transports).should be_true
			end
									
		end		
	end
	
end