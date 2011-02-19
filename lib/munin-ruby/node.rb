module Munin
  class Node
    attr_reader :host, :port
    attr_reader :version, :services
    attr_reader :timestamp
    
    # Setup a new node
    # host - Server hostname or IP address
    # port - Server port (default to 4949)
    # list - List of services to request. Empty array if need to fetch all
    def initialize(host, port=4949, list=[])
      @host          = host
      @port          = port
      @stats         = {}
      @services      = []
      @version       = ''
      @only_services = list || []
      run
    end
    
    # Get service stats
    def service(name)
      if @stats.key?(name)
        @stats[name]
      else
        raise Munin::NoSuchService, "Service with name #{name} does not exist."
      end
    end
    
    private
    
    # Fetch node information and stats
    def run
      begin
        @timestamp = Time.now
        @socket = TCPSocket.new(@host, @port)
        @socket.sync = true ; @socket.gets
        fetch_version
        fetch_services
        @socket.close
      rescue Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::ECONNRESET, EOFError => ex
        raise Munin::SessionError, ex.message
      end
    end
    
    # Fetch node server version
    def fetch_version
      @socket.puts("version")
      @version = @socket.readline.strip.split(' ').last
    end
    
    # Fetch list of services and its stats
    def fetch_services
      @socket.puts("list")
      services = @socket.readline.split(' ').map { |s| s.strip }.sort
      services = services.select { |s| @only_services.include?(s) } unless @only_services.empty?
      services.each { |s| @services << s ; @stats[s] = fetch(s) }
    end
    
    # Fetch service information
    def fetch(service)
      @socket.puts("fetch #{service}")
      content = []
      while(str = @socket.readline) do
        break if str.strip == '.'
        content << str.strip.split(' ')
      end
      Stat.new(service, content)
    end
  end
end