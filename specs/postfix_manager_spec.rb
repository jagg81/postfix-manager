$:.unshift "#{File.dirname(__FILE__)}/"
require "helpers"

include PostfixManagerTest

describe Postfix::PostfixManager do        
  
  after(:all) do
    @mgr = PostfixManager.new()
    @mgr.delete_all_from_active_queue
		@mgr.rollback_config
		@mgr.reload_system
	end
  
  describe "Configuration Management" do  	
  	describe "Reading param values from Postfix config file" do
  		before{
	  		@mgr = PostfixManager.new()
	  	}
	  	
	  	it "should not raise errors" do  			
  			lambda{
  				@mgr.get_config_value("config_directory")
  			}.should_not raise_error  			
  		end
  		
  		it "reading postfix directory path from config" do  			
  			postfix_dir = @mgr.get_config_value("config_directory")  			
  			File.directory?(postfix_dir).should be_true
  		end  		  		
  	end
  	  	
  	describe "Setting param values in Postfix config file" do
  		before(:all) do  	
  			@mgr = PostfixManager.new()
  			@new_relayhost_value = "#{rand(10000)}.test.com"
	      @params = {"relayhost" => @new_relayhost_value}
  		end
  		before{ }
	  	after{ @mgr.rollback_config }	  		
	  	after(:all) do	  		
	  		@mgr.rollback_config
	  	end
  		
  		subject { @mgr }
  		
  		it "should not raise errors" do  			
  			lambda{
  				subject.set_config_values(@params)
  			}.should_not raise_error
  		end
  		
  		it "should raise ArgumentError if params is not a dt hash" do  			
				lambda{
  				subject.set_config_values([])
  			}.should raise_error(ArgumentError)
  		end
  		
  		it "should change relayhost value in config file" do
				relayhost_value = @mgr.get_config_value("relayhost")
				lambda{
  				@mgr.set_config_values(@params)
  				relayhost_value = @mgr.get_config_value("relayhost")
  			}.should change{ relayhost_value }.from(relayhost_value).to(@new_relayhost_value)  			
  		end
  	end
  	
  	describe "High Level methods for Configuration Management" do  		  
  		
  		describe "setting relayhost value ON" do
  			before(:all) do
  				@mgr = PostfixManager.new()
	  			@value = PostfixManager.relay_on_value
	  		end
	  		before{
	  			@mgr.turn_relay_on
		  	}
		  	after(:all) do
		  		@mgr.rollback_config
		  	end  				
		  	
  			subject{
  				relay_val = @mgr.get_config_value("relayhost")
  				relay_val ? relay_val : "" 
  			}
  			
  			it "should set relayhost value ON" do	    				
	  			subject.should == @value
	  		end
	  		
  		end
  		
  		describe "setting relayhost value OFF" do
  			before(:all) do
  				@mgr = PostfixManager.new()
	  			@value = PostfixManager.relay_off_value
	  		end
	  		before{
	  			@mgr.turn_relay_off
		  	}
		  	after(:all) do
		  		@mgr.rollback_config
		  	end  				
  			
  			subject{
  				relay_val = @mgr.get_config_value("relayhost")
  				relay_val ? relay_val : "" 
  			}
  			
  			it "should set relayhost value OFF" do	    				
	  			subject.should == @value
	  		end
	  			  			  	
  		end
  		
  		describe "setting defer_transports value" do
  			before(:all) do
  				@mgr = PostfixManager.new()
	  			@value = PostfixManager.defer_transports_value
	  		end
	  		before{
	  			@mgr.set_defer_transports_local
		  	}
		  	after(:all) do
		  		@mgr.rollback_config
		  	end  				
  			
  			subject{
  				val = @mgr.get_config_value("defer_transports")
  				val ? val : "" 
  			}
  			
  			it "should set defer_transports to default value" do	    					  			
	  			subject.should == @value
	  		end	  			  			  	
  		end  		
  	end  	
  end
  
  
  describe "Queue management" do
  	before(:all) do
  		# Use a valid e-mail address in email_to, otherwise
	    # expect "Should turn relay ON and flush postfix queue" test to failed
	    # can't deliver email to this 'FAKE' recipient => bulkemail@test.com
	    @email_to = 'bulkemail@test.com'            #recipient of the bulk emails  
	    @bulk_size = 2                              #number of emails to send in bulk
	    @time_to_wait = 3                            #default slack time between running processes (seconds)
	    @timer = 6											             #timer goes off after the waiting time expires (seconds)
	                                                 #currently is a function of the bulk size and time to wait
  	end
  	
  	def wait_and_return_queue_size(mgr, timer, sleep_time)
			queue_size_1 = mgr.get_number_msgs_queued
      queue_size_2 = queue_size_1
      
      #	beyond 60secs, bounced emails changed their status and our bash_script
      # can no loger read messages correctly from the queue
      timeout = Time.now + timer
      while Time.now < timeout && queue_size_1 > 0 do
        queue_size_1 = mgr.get_number_msgs_queued
        sleep(sleep_time)
#        puts "queue_size_before => #{queue_size_1}"
#        puts "queue_size_after => #{queue_size_2}"
        queue_size_2 = queue_size_1
      end
      queue_size_1
		end
  
    # context "relayhost is ON" do    
    #   before(:all) do
    #         @mgr = PostfixManager.new()
    #         @mgr.turn_relay_on
    #         @mgr.reload_system          
    #   end
    #   before{         
    #     @mgr.delete_all_from_active_queue
    #     mock_bulk_email(@bulk_size, @email_to)
    #       }
    #       after(:all) do
    #         @mgr.rollback_config
    #       end         
    #             
    #       subject{ @mgr.get_msgs_in_deferred_queue }
    #       
    #       it "should not queue up emails" do
    #         wait_and_return_queue_size(@mgr, @timer, @time_to_wait)
    #         subject.should have(0).items
    #       end
    # end
  	
  	context "relayhost is OFF" do
  		before(:all) do
				@mgr = PostfixManager.new()
				@mgr.turn_relay_off
				@mgr.reload_system
				@mgr.delete_all_from_active_queue
  			mock_bulk_email(@bulk_size, @email_to)
  		end
  		before{	  			
  			
	  	}
	  	after(:all) do
	  		@mgr.rollback_config
	  	end  				
			  		
			subject{ @mgr.get_msgs_in_deferred_queue }
			
			it "should queue up emails" do
				wait_and_return_queue_size(@mgr, @timer, @time_to_wait)
				subject.should have(@bulk_size).items
			end
			
			it "should read recipient email address correctly" do				
				subject.each do |msg|
					msg[:email].should eq(@email_to)
				end
			end
			
			it "should not release emails when queue is fluhed" do 
				lambda{
					@mgr.flush_queue
					wait_and_return_queue_size(@mgr, @timer, @time_to_wait)
				}.should_not change(subject, :size)
			end
			
  	end
  	
#     context "Defer Transports local is OFF" do
#       before(:all) do
#         @mgr = PostfixManager.new()
#         @mgr.turn_relay_on
#         @mgr.set_defer_transports_local(false)
# #       @mgr.reload_system
#         @mgr.delete_all_from_active_queue
#         mock_bulk_email(@bulk_size, @email_to)
#       end
#       before{         
#         
#       }
#       after(:all) do
#         @mgr.rollback_config
#       end         
#             
#       subject{ @mgr.get_msgs_in_deferred_queue }
#       
#       it "should not queue up emails" do
#         wait_and_return_queue_size(@mgr, @timer, @time_to_wait)
#         subject.should have(0).items
#       end           
#     end
  	
#     context "Defer Transports local is ON" do
#       before(:all) do
#         @mgr = PostfixManager.new()
#         @mgr.turn_relay_on
#         @mgr.set_defer_transports_local
# #       @mgr.reload_system
#         @mgr.delete_all_from_active_queue
#         mock_bulk_email(@bulk_size, @email_to)
#       end
#       before{         
#         
#       }
#       after(:all) do
#         @mgr.rollback_config
#       end         
#             
#       subject{ @mgr.get_msgs_in_deferred_queue }
#       
#       it "should queue up emails" do
#         wait_and_return_queue_size(@mgr, @timer, @time_to_wait)
#         subject.should have(@bulk_size).items
#       end
#       
#       it "should read recipient email address correctly" do       
#         subject.each do |msg|
#           msg[:email].should eq(@email_to)
#         end
#       end
#       
#       it "should release emails when queue is flushed" do 
#         lambda{
#           @mgr.flush_queue
#           wait_and_return_queue_size(@mgr, @timer, @time_to_wait)
#         }.should change(subject, :size)
#       end
#     end
  	
  	context "Relayhost OFF & Defer Transports local is ON" do
  		before(:all) do
				@mgr = PostfixManager.new()
				@mgr.turn_relay_off
				@mgr.set_defer_transports_local
				@mgr.delete_all_from_active_queue
  			mock_bulk_email(@bulk_size, @email_to)
  		end
  		before{	  			
  			
	  	}
	  	after(:all) do
	  		@mgr.rollback_config
	  	end  				
			  		
			subject{ @mgr.get_msgs_in_deferred_queue }
			
			it "should queue up emails" do
				wait_and_return_queue_size(@mgr, @timer, @time_to_wait)
				subject.should have(@bulk_size).items
			end
			
			it "should read recipient email address correctly" do				
				subject.each do |msg|
					msg[:email].should eq(@email_to)
				end
			end
			
			it "should not release emails when queue is fluhed" do 
				lambda{
					@mgr.flush_queue
					wait_and_return_queue_size(@mgr, @timer, @time_to_wait)
				}.should_not change(subject, :size)
			end
  	end    	
  end
  
end
