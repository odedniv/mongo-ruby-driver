require 'test/unit'
require 'tools/mongo_config'

class Test::Unit::TestCase
  # Ensure sharded cluster is available as an instance variable and that
  # a new set is spun up for each TestCase class
  def ensure_sc
    if defined?(@@current_class) and @@current_class == self.class
      @@sc.start
    else
      @@current_class = self.class
      dbpath = 'sc'
      opts = Mongo::Config::DEFAULT_SHARDED_SIMPLE.merge(:dbpath => dbpath).merge(:routers => 4)
      #debug 1, opts
      config = Mongo::Config.cluster(opts)
      #debug 1, config
      @@sc = Mongo::Config::ClusterManager.new(config)
      @@sc.start
    end
    @sc = @@sc
  end

  def ensure_rs
    if defined?(@@current_class) and @@current_class == self.class
      @@rs.start
    else
      @@current_class = self.class
      dbpath = 'rs'
      opts = Mongo::Config::DEFAULT_REPLICA_SET.merge(:dbpath => dbpath)
      #debug 1, opts
      config = Mongo::Config.cluster(opts)
      #debug 1, config
      @@rs = Mongo::Config::ClusterManager.new(config)
      @@rs.start
    end
    @rs = @@rs
  end

  # Generic code for rescuing connection failures and retrying operations.
  # This could be combined with some timeout functionality.
  def rescue_connection_failure(max_retries=30)
    retries = 0
    begin
      yield
    rescue Mongo::ConnectionFailure => ex
      #puts "Rescue attempt #{retries}: from #{ex}"
      retries += 1
      raise ex if retries > max_retries
      sleep(2)
      retry
    end
  end
end

def silently
  warn_level = $VERBOSE
  $VERBOSE = nil
  begin
    result = yield
  ensure
    $VERBOSE = warn_level
  end
  result
end

begin
  require 'rubygems' if RUBY_VERSION < "1.9.0" && !ENV['C_EXT']
  silently { require 'shoulda' }
  silently { require 'mocha' }
rescue LoadError
  puts <<MSG

This test suite requires shoulda and mocha.
You can install them as follows:
  gem install shoulda
  gem install mocha

MSG
  exit
end

require 'bson_ext/cbson' if !(RUBY_PLATFORM =~ /java/) && ENV['C_EXT']

unless defined? MONGO_TEST_DB
  MONGO_TEST_DB = 'ruby-test-db'
end

unless defined? TEST_PORT
  TEST_PORT = ENV['MONGO_RUBY_DRIVER_PORT'] ? ENV['MONGO_RUBY_DRIVER_PORT'].to_i : Mongo::Connection::DEFAULT_PORT
end

unless defined? TEST_HOST
  TEST_HOST = ENV['MONGO_RUBY_DRIVER_HOST'] || 'localhost'
end

class Test::Unit::TestCase
  include Mongo
  include BSON

  def self.standard_connection(options={})
    Connection.new(TEST_HOST, TEST_PORT, options)
  end

  def standard_connection(options={})
    self.class.standard_connection(options)
  end

  def self.host_port
    "#{mongo_host}:#{mongo_port}"
  end

  def self.mongo_host
    TEST_HOST
  end

  def self.mongo_port
    TEST_PORT
  end

  def host_port
    self.class.host_port
  end

  def mongo_host
    self.class.mongo_host
  end

  def mongo_port
    self.class.mongo_port
  end

  def new_mock_socket(host='localhost', port=27017)
    socket = Object.new
    socket.stubs(:setsockopt).with(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
    socket.stubs(:close)
    socket.stubs(:closed?)
    socket
  end

  def new_mock_db
    Object.new
  end

  def assert_raise_error(klass, message=nil)
    begin
      yield
    rescue => e
      if klass.to_s != e.class.to_s
        flunk "Expected exception class #{klass} but got #{e.class}.\n #{e.backtrace}"
      end

      if message && !e.message.include?(message)
        p e.backtrace
        flunk "#{e.message} does not include #{message}.\n#{e.backtrace}"
      end
    else
      flunk "Expected assertion #{klass} but none was raised."
    end
  end
end
