require 'addressable/uri'

module EventMachine
  module WebSocket
    class Client < EventMachine::Connection
      HEADER = /^([^:]+):\s*([^$]+)/

      attr_reader :state, :request
      
      def websocket_connection_completed
      end
      
      def receive_message(msg)
      end

      def connection_completed
        @state   = :handshake
        @request = {}
        @data    = ''
        send_upgrade
      end

      def receive_data(data)
        @data << data
        dispatch
      end

      def unbind
        @state = :closed
      end

      def dispatch
        while case @state
          when :handshake
            new_request
          when :connected
            process_message
          else raise RuntimeError, "invalid state: #{@state}"
          end
        end
      end

      def new_request
        if @data.match(/\r\n\r\n$/)
          lines = @data.split("\r\n")

          lines.each do |line|
            h = HEADER.match(line)
            next unless h
            @request[h[1].strip] = h[2].strip
          end
            
          unless websocket_connection?
            process_bad_request
            return false
          else
            @data  = ''
            @state = :connected
            
            websocket_connection_completed
            
            return true
          end
        end

        false
      end
      
      def process_bad_request
        close_connection_after_writing
        raise "Not a WebSocket endpoint"
      end
      
      def websocket_connection?
        @request['Connection'] == 'Upgrade' and @request['Upgrade'] == 'WebSocket'
      end

      def send_upgrade
        upgrade =  "GET / HTTP/1.1\r\n"
        upgrade << "Upgrade: WebSocket\r\n"
        upgrade << "Connection: Upgrade\r\n"
        upgrade << "\r\n"
        send_data upgrade
      end

      def process_message
        while msg = @data.slice!(/\000([^\377]*)\377/)
          msg.gsub!(/^\x00|\xff$/, '')
          receive_message(msg)
        end
        false
      end

      def send_message(data)
        send_data("\x00#{data}\xff")
      end
    end
  end
end