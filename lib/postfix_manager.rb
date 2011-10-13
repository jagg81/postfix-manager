#$:.unshift "#{File.dirname(__FILE__)}/"
require "fileutils"
include FileUtils

module Postfix
	class PostfixManager

		MANAGER_HOME = File.expand_path "#{File.dirname(__FILE__)}/.."
		MAIN_CONFIG_FILENAME = "main.cf"
		MGR_FILENAME_PREFIX = "postfix_mgr_temp_"
		POSTCAT_CMD = " -exec postcat {} \+ "
		POSTCAT_CMD_FIND = " find /var/spool/postfix/ -name "
		TMP_DIRECTORY = "/var/tmp/postfix_manager/"
		DUMP_DIRECTORY = "lib/scripts/dumps/"
		ACTIVEQUEUE_FILENAME = "active_queue.log"
		MSG_BODY_PREFIX_FILENAME = "_msg"
		RELAY_ON_VALUE = ""
		RELAY_OFF_VALUE = "[thisisabogushost.test.com]:587"
		DEFER_TRANSPORTS_LOCAL_VALUE = "smtp local"

		class << self
			def relay_on_value; RELAY_ON_VALUE; end
			def relay_off_value; RELAY_OFF_VALUE; end
			def defer_transports_value; DEFER_TRANSPORTS_LOCAL_VALUE; end
		end

		# NOTE:  do all these commands require sudo all the time?
		def postqueue(command)
			sudo("postqueue #{command}")
		end

		def postfix(command)
			sudo("postfix #{command}")
		end

		def postconf(command)
			sudo("postconf #{command}")
		end

		def postsuper(command)
			sudo("postsuper #{command}")
		end

		def sudo(command)
			system("#{sudo_prefix} #{command}")
		end

		def sudo_prefix
			if @sudo_prefix
				@sudo_prefix
			else
				if @login && @password
					@sudo_prefix = "echo #{@password} | sudo -S -u #{@login} "
				else
					@sudo_prefix = "sudo"
					##FIXME: this can fail for other reasons, and doing it in #initialize
					##makes it difficult to test command generation.
					#raise "missing sudo privileges" unless self.reload_system
				end
				@sudo_prefix
			end
		end

		def initialize(login=nil, password=nil)
			@login = login
			@password = password

			#regxep for getting values out of the main.cf config file
			@regexp_config_value = Regexp.new(/(\=\s*)([^...]+\S+$)/)
			#regxep for getting values out of the main.cf config file
			@regexp_msg_body = Regexp.new(/^.+\nFrom:.+\n\n(.+)\n.+$/)

			#main config backup filename
			@backup_config_filename = MGR_FILENAME_PREFIX + MAIN_CONFIG_FILENAME
						
			@active_queue_file = "#{TMP_DIRECTORY}#{ACTIVEQUEUE_FILENAME}"
			@msgs_queued = []

			self.init_environment

			@config_dir = get_config_value("config_directory")
			raise "postfix config directory not found" unless @config_dir
			@config_dir += '/'
		end

		#reload postfix to force taking changes in the main config file
		def reload_system()
			postfix("reload")
		end

		#revert changes made in the main config file
		def rollback_config()
			rollback_config_file(MAIN_CONFIG_FILENAME)
		end

		#flush postfix "active" queue, attempt to deliver all queued emails
		def flush_queue()
			postqueue("-f")
		end

		#get config value from main config file
		def get_config_value(param)
			config_keyval = `sudo postconf #{param}`
			config_keyval =~ @regexp_config_value
			$2
		end

		#return an array of hashes with all e-mails contained the referred queue of postfix
		#i.e. [ {:msg_id => 'USFD876234', :email => user1@test.com},
		#       {:msg_id => 'YUHI982723', :email => user2@test.com}  ]
		def get_msgs_in_deferred_queue()
			dump_deferred_queue
			yield @msgs_queued if block_given?
			@msgs_queued
		end

		#look for a msg(email) in the queue with an specific postfix email ID (a.k.a. msg_id)
		def get_msg_by_id(msg_id)
			dump_msg_content(msg_id)
			msg_file = IO.read("#{DUMP_DIRECTORY}_#{msg_id}")
			msg_file =~ @regexp_msg_body
			msg_obj = { :id => msg_id, :body => $1 }
			yield msg_obj if block_given?
			msg_obj
		end

		#returns number of e-mails in the deferred queue (default)
		def get_number_msgs_queued(deferred=true)
			get_msgs_in_deferred_queue if deferred
			@msgs_queued.size
		end

		#delete emails in the active queue by msg_id
		def delete_msg_from_active_queue(msg_id)
			postsuper("-d #{msg_id}")
		end

		#delete all emails in the active queue
		def delete_all_from_active_queue()
			postsuper("-d ALL")
		end

		# High Level methods
		# turn relay on
		def turn_relay_on
			set_relayhost(RELAY_ON_VALUE)
		end
		# turn relay off
		def turn_relay_off(relay_val=nil)
			relay_val ||= RELAY_OFF_VALUE
			set_relayhost(relay_val)
		end

		# set defer transport to deliver locally
		def set_defer_transports_local(on=true)
			value = on ? DEFER_TRANSPORTS_LOCAL_VALUE : ""
			set_config_values("defer_transports" => value)
			#TODO: error checking could easily go in #reload_system itself
			raise "Failed to reload system" unless reload_system
		end

		def set_relayhost(host)
			set_config_values("relayhost" => host)
			#TODO: error checking could easily go in #reload_system itself
			raise "Failed to reload system" unless reload_system
			#sleep(2)
		end

		#change parameters in the main config file
		#pass a hash structure with key={parameter_name}/value={parameter_new_value}
		def set_config_values(params)
			raise ArgumentError unless params.is_a?(Hash)

			#TODO change this to create a new directory with backup files
			unless config_file?(@backup_config_filename)
				#TODO change this to set filename to include unix datetime taken when obj PostfixManager is initialized
				create_backup_file(MAIN_CONFIG_FILENAME)
			end

			#FIXME:  this can be done all in a single postconf command.
			# set each of the values pass in the params hash table
			params.each do |key,value|
				set_config_single_value(key.to_s, value.to_s)
			end
		end

		#set values in postfix main.cf config file
		def set_config_single_value(param_name, param_value)
			postconf("-e #{param_name}='#{param_value}'")
		end

		def rollback_config_file(filename)
			res = false
			filename_tmp = MGR_FILENAME_PREFIX + filename
			from = @config_dir + filename
			to = @config_dir + filename_tmp

			if config_file?(filename) && config_file?(filename_tmp)
				if sudo("rm #{from}")
					res = sudo("mv #{to} #{from}")
				end
			end
			res
		end

		#gets deferred emails from queue and flush info to a tmp file
		def dump_deferred_queue()
			@msgs_queued.clear
			return @msgs_queued unless `postqueue -p` =~ /^[-|Host].+\n/
			$' =~ /^--.+$/
			messages = $`.split("\n\n")
			messages.each do |msg|
				msg =~ /^(.+?)\s.+\n.+\s.+\n.+\s(\w.+)$/
				@msgs_queued.push({:id => $1, :email => $2})
			end
		end

		#runs shell script to dump message content
		def dump_msg_content(msg_id)
			sudo("#{POSTCAT_CMD_FIND} #{msg_id} #{POSTCAT_CMD} >> #{DUMP_DIRECTORY}_#{msg_id}")
		end

		#check the running environment for scripts and sub-directories needed in runtime
		def init_environment
			#@dump_dir = "#{POSTFIX_MANAGER_HOME}/#{POSTFIX_DUMP_DIRECTORY}"

			#create local dump directory if needed
			mkdir(TMP_DIRECTORY) unless File.directory?(TMP_DIRECTORY)


		end

		#private METHODS (utilities functions)
		private
		def create_backup_file(filename)

			from = @config_dir + filename
			to = @config_dir + MGR_FILENAME_PREFIX + filename

			if config_file?(filename)
				#File.copy(from, to, true)
				#true
				sudo("cp #{from} #{to}")
			else
				false
			end
		end

		def config_file?(filename)
			File.file?(@config_dir + filename)
		end

	end
end
