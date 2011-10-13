$:.unshift "#{File.dirname(__FILE__)}/../lib"

require 'postfix_manager'
require 'thread'
require 'digest/sha1'

include Postfix

module PostfixManagerTest
  
  #send {n} emails to the same {recipient}
  def mock_bulk_email(number, recipient, body=nil, path=false)   
    body = "This is a bulk email test" if !body && !path
    prefix_cmd = "echo #{body}"
    prefix_cmd = "cat #{body}" if path 
    number.times do |n|    
      #puts "sending email No. #{n+1}"
      system("#{prefix_cmd} |mail -s 'this email cannot be delivered #{n+1}' #{recipient}")
    end
    sleep(2)
  end
  
  def clean_queue(mgr)
    raise "PostfixManager instance missing" if !mgr.instance_of?(PostfixManager)
    mgr = PostfixManager.new()
    mgr.delete_all_from_active_queue
    sleep(10)
  end
  
  def get_hash(content)
    Digest::SHA1.hexdigest(content)
  end
    
end
