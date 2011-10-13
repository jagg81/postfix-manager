require "specs/helpers"

describe "Postfix command wrapper" do

  before(:all) do
    @mgr = PostfixManager.new
    @mgr.rollback_config
  end

  specify "reload_system" do
    @mgr.should_receive(:system).with("sudo postfix reload")
    @mgr.reload_system
  end

  specify "flush_queue" do
    @mgr.should_receive(:system).with("sudo postqueue -f")
    @mgr.flush_queue
  end

  specify "delete_msg_from_active_queue" do
    @mgr.should_receive(:system).with("sudo postsuper -d 2")
    @mgr.delete_msg_from_active_queue(2)
  end

  specify "delete_all_from_active_queue" do
    @mgr.should_receive(:system).with("sudo postsuper -d ALL")
    @mgr.delete_all_from_active_queue
  end

  specify "set_config_single_value" do
    @mgr.should_receive(:system).with("sudo postconf -e foo='bar'")
    @mgr.set_config_single_value("foo", "bar")
  end

  specify "dump_msg_content" do
    @mgr.should_receive(:system).with("sudo  find /var/spool/postfix/ -name  2  -exec postcat {} +  >> lib/scripts/dumps/_2")
    @mgr.dump_msg_content(2)
  end

  specify "set_config_values" do
    @mgr.should_receive(:system).with(/cp/)
    @mgr.should_receive(:system).with("sudo postconf -e foo='bar'")
    @mgr.should_receive(:system).with("sudo postconf -e baz='bat'")
    @mgr.set_config_values("foo" => "bar", "baz" => "bat")
  end

  specify "set_relayhost" do
    @mgr.should_receive(:system).with(/cp/)
    @mgr.should_receive(:system).with("sudo postconf -e relayhost=''")
    @mgr.should_receive(:system).once.with("sudo postfix reload").and_return(true)
    @mgr.set_relayhost("")
  end

  specify "turn_relay_on" do
    @mgr.should_receive(:system).once.with(/cp/)
    @mgr.should_receive(:system).with("sudo postconf -e relayhost=''")
    @mgr.should_receive(:system).once.with("sudo postfix reload").and_return(true)
    @mgr.turn_relay_on
  end

  specify "turn_relay_off" do
    @mgr.should_receive(:system).once.with(/cp/)
    @mgr.should_receive(:system).with("sudo postconf -e relayhost='[thisisabogushost.test.com]:587'")
    @mgr.should_receive(:system).once.with("sudo postfix reload").and_return(true)
    @mgr.turn_relay_off
  end

  specify "set_defer_transports_local" do
  	@mgr.should_receive(:system).once.with(/cp/)
  	@mgr.should_receive(:system).with("sudo postconf -e defer_transports='smtp local'")
  	@mgr.should_receive(:system).once.with("sudo postfix reload").and_return(true)
  	@mgr.set_defer_transports_local
 	end

 	specify "dump_deferred_queue" do
 		@mgr.should_receive(:`).once.with("postqueue -p")
 		@mgr.dump_deferred_queue.instance_of?(Array).should be_true
 	end

end
