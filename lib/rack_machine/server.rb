module RackMachine
  module Server
    module ClassMethods

    end
    
    module InstanceMethods
      def post_init
        puts "-- someone connected to the echo server!"
      end
      
      def receive_data data
        send_data ">>>you sent: #{data}"
      end
      
      def unbind
        puts "-- someone disconnected from the echo server!"
      end
    end
    
    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
    end
  end
end
