#$:.unshift "#{File.dirname(__FILE__)}"
require 'postfix_manager'
require 'logger'

module Postfix
	class PostfixWS
		
		attr_accessor :logger
		
		def initialize(options={})
			@logger = (options[:logger] || Logger.new(STDOUT))
			@logger.level = Logger.const_get(options[:log_level] || "INFO")
			
			yield if block_given?
			@mgr = initMgr
		end
		
		class << self
			attr_accessor :login, :pass   
		end
		
		def call(env)
			@request = Rack::Request.new(env)
			@response = Rack::Response.new
			
			case @request.path_info
				when '/'
				unless @request.request_method == "GET"					
					@logger.info "Bad Resquest"
					@response.status = 405 
					return @response.finish
				end
				base_uri = @request.url
				methods = { "queue_size" => base_uri + "queue_size",
									"enable_delivery" => base_uri + "enable_delivery",
									"disable_delivery" => base_uri + "disable_delivery",
									"clear_queue" => base_uri + "clear_queue",
									"status" => base_uri + "status"} 
				data = {"version-1" => methods}
				@response.body << data.to_json
				@response.status = 200
				@response.headers["Content-Type"] = "application/json"
				
				when	'/queue_size'						
				unless @request.request_method == "GET"					
					@logger.info "Bad Resquest"
					@response.status = 405 
					return @response.finish
				end
				# may be enclosed this in a Begin/Rescue block?
				data = queue_size						
				@response.body << data.to_json
				@response.status = 200
				@response.headers["Content-Type"] = "application/json"
				
				when	'/enable_delivery'
				unless @request.request_method == "POST"
					@logger.info "Bad Resquest"
					@response.status = 405 
					return @response.finish
				end
				enable_delivery
				@response.status = 204			
				
				when	'/disable_delivery'
				unless @request.request_method == "POST"
					@logger.info "Bad Resquest"
					@response.status = 405 
					return @response.finish
				end
				disable_delivery
				@response.status = 204
				
				when	'/clear_queue'
				unless @request.request_method == "POST"
					@logger.info "Bad Resquest"
					@response.status = 405 
					return @response.finish
				end
				clear_queue
				@response.status = 204
				
				when	'/status'
				unless @request.request_method == "GET"
					@logger.info "Bad Resquest"
					@response.status = 405 
					return @response.finish
				end
				data = status
				@response.body << data.to_json
				@response.status = 200
				@response.headers["Content-Type"] = "application/json"
			end
			
			@response.finish		
		end
		
		def queue_size				
			data = {:queue_size => @mgr.get_number_msgs_queued}
		end
		
		def enable_delivery			
			@mgr.turn_relay_on
			@mgr.flush_queue
		end
		
		def disable_delivery			
			@mgr.set_defer_transports_local
			@mgr.turn_relay_off
		end
		
		def clear_queue			
			@mgr.delete_all_from_active_queue
		end
		
		def status					
			data = {:queue_size => @mgr.get_number_msgs_queued,
						:relayhost => @mgr.get_config_value("relayhost"),
						:defer_transports => @mgr.get_config_value("defer_transports")}
		end
		
		private
		def initMgr			
			PostfixWS.login && PostfixWS.pass ? PostfixManager.new(PostfixWS.login, PostfixWS.pass) : PostfixManager.new()						
		end
	end
end