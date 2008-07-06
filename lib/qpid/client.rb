#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
# 
#   http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

require "thread"
require "qpid/peer"
require "qpid/queue"

module Qpid

  class Client
    def initialize(host, port, spec, vhost = "/")
      @host = host
      @port = port
      @spec = spec
      @vhost = vhost

      @mechanism = nil
      @response = nil
      @locale = nil

      @queues = {}
      @mutex = Mutex.new()

      @closed = false
      @code = nil
      @started = ConditionVariable.new()

      @conn = Connection.new(@host, @port, @spec)
      @peer = Peer.new(@conn, ClientDelegate.new(self))
    end

    attr_reader :mechanism, :response, :locale 
    attr_accessor :failed

    def closed?; @closed end
    def closed=(value); @closed = value end
    def code; @code end

    def wait()
      @mutex.synchronize do
        @started.wait(@mutex)
      end
      raise EOFError.new() if closed?
    end

    def signal_start()
      @started.broadcast()
    end

    def queue(key)
      @mutex.synchronize do
        q = @queues[key]
        if q.nil?
          q = Queue.new()
          @queues[key] = q
        end
        return q
      end
    end

    def close_queues
      @mutex.synchronize do
        @queues.each do |key, queue|
          queue.close
        end
      end
    end
    
    def fail_queues
      @mutex.synchronize do
        @queues.each do |key, queue|
          queue.fail
        end
      end
    end

    def start(response, mechanism="AMQPLAIN", locale="en_US")
      @response = response
      @mechanism = mechanism
      @locale = locale

      @conn.connect()
      @conn.init()
      @peer.start()
      wait()
      channel(0).connection_open(:virtual_host => @vhost, :insist => true)
    end

    def channel(id)
      return @peer.channel(id)
    end

    def really_closed?
      @conn.closed?
    end

    def close(msg = nil)
      @closed = true
      @code = msg
      @peer.close()
    end
  end

  class ClientDelegate
    include Delegate

    def initialize(client)
      @client = client
    end

    #cleanup after a disaster
    def cleanup
      @client.fail_queues
      @client.failed = true
    end

    def connection_start(ch, msg)
      ch.connection_start_ok(:mechanism => @client.mechanism,
                             :response => @client.response,
                             :locale => @client.locale)
    end

    def connection_tune(ch, msg)
      ch.connection_tune_ok(*msg.fields)
      @client.signal_start()
    end

    def connection_close(ch, msg)
      puts "CONNECTION CLOSED: #{msg.args.join(", ")}"
      @client.close(msg)
    end

    def channel_close(ch, msg)
      puts "CHANNEL[#{ch.id}] CLOSED: #{msg.args.join(", ")}"
      ch.channel_close_ok()
      ch.close()
    end

    def basic_deliver(ch, msg)
      queue = @client.queue(msg.consumer_tag)
      queue << msg
    end

  end

end
