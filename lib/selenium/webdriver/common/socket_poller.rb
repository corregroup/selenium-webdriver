require "selenium/webdriver/common/platform"
require "socket"

module Selenium
  module WebDriver
    class SocketPoller

      def initialize(host, port, timeout = 0, interval = 0.25)
        @host     = host
        @port     = Integer(port)
        @timeout  = Integer(timeout)
        @interval = interval
      end

      #
      # Returns true if the server is listening within the given timeout,
      # false otherwise.
      #
      # @return [Boolean]
      #

      def connected?
        with_timeout { listening? }
      end

      #
      # Returns true if the server has stopped listening within the given timeout,
      # false otherwise.
      #
      # @return [Boolean]
      #

      def closed?
        with_timeout { not listening? }
      end

      private

      NOT_CONNECTED_ERRORS = [Errno::ECONNREFUSED, Errno::ENOTCONN, SocketError]
      NOT_CONNECTED_ERRORS << Errno::EPERM if Platform.cygwin?

      CONNECTED_ERRORS = [Errno::EISCONN]
      CONNECTED_ERRORS << Errno::EINVAL if Platform.win?

      def listening?
        addr     = Socket.getaddrinfo(@host, @port, Socket::AF_INET, Socket::SOCK_STREAM)
        sock     = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
        sockaddr = Socket.pack_sockaddr_in(@port, addr[0][3])

        begin
          sock.connect_nonblock sockaddr
        rescue Errno::EINPROGRESS, Errno::EALREADY
          wait # we should select() here, but JRuby has problems..
          retry
        rescue *CONNECTED_ERRORS
          # yay!
        end

        sock.close
        true
      rescue *NOT_CONNECTED_ERRORS => e
        $stderr.puts [@host, @port].inspect if $DEBUG
        false
      end

      def with_timeout(&blk)
        max_time = Time.now + @timeout

        (
          return true if yield
          wait
        ) until Time.now > max_time

        false
      end

      def wait
        sleep @interval
      end

    end # SocketPoller
  end # WebDriver
end # Selenium
