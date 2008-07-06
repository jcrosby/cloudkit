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
require "qpid/queue"
require "qpid/connection"
require "qpid/fields"

module Qpid

  class Peer

    def initialize(conn, delegate)
      @conn = conn
      @delegate = delegate
      @outgoing = Queue.new()
      @work = Queue.new()
      @channels = {}
      @mutex = Mutex.new()
    end

    def channel(id)
      @mutex.synchronize do
        ch = @channels[id]
        if ch.nil?
          ch = Channel.new(id, self, @outgoing, @conn.spec)
          @channels[id] = ch
        end
        return ch
      end
    end

    def channel_delete(id)
      @channels.delete(id)
    end

    def start()
      spawn(:writer)
      spawn(:reader)
      spawn(:worker)
    end

    def close()
      @mutex.synchronize do
        @channels.each_value do |ch|
          ch.close()
          @outgoing.close()
          @work.close()
        end
      end
    end

    private

    def cleanup
      @delegate.cleanup
    end

    def spawn(method, *args)
      Thread.new do
        begin
          send(method, *args)
          # is this the standard way to catch any exception?
        rescue Closed => e
          puts "#{method} #{e}"
        rescue Object => e
          print e
          e.backtrace.each do |line|
            print "\n  ", line
          end
          print "\n"
        end
      end
    end

    def reader()
      while true
        frame = @conn.read()
        ch = channel(frame.channel)
        ch.dispatch(frame, @work)
      end
    rescue Object, EOF => boom
      puts boom
      cleanup
    end

    def writer()
      while true
        @conn.write(@outgoing.pop())
      end
    rescue Object => boom
      puts boom
      cleanup
    end

    def worker()
      while true
        dispatch(@work.pop())
      end
    rescue => boom
      puts boom
      cleanup
    end

    def dispatch(queue)
      frame = queue.pop()
      ch = channel(frame.channel)
      payload = frame.payload
      if payload.method.content?
        content = Qpid::read_content(queue)
      else
        content = nil
      end

      message = Message.new(payload.method, payload.args, content)
      @delegate.dispatch(ch, message)
    end

  end

  class Channel
    def initialize(id, peer, outgoing, spec)
      @id = id
      @peer = peer
      @outgoing = outgoing
      @spec = spec
      @incoming = Queue.new()
      @responses = Queue.new()
      @queue = nil
      @closed = false
    end

    attr_reader :id

    def closed?; @closed end

    def close()
      return if closed?
      @peer.channel_delete(@id)
      @closed = true
      @incoming.close()
      @responses.close()
    end

    def dispatch(frame, work)
      payload = frame.payload
      case payload
      when Method
        if payload.method.response?
          @queue = @responses
        else
          @queue = @incoming
          work << @incoming
        end
      end
      @queue << frame
    end

    def method_missing(name, *args)
      method = @spec.find_method(name)
       if method.nil?
         raise NoMethodError.new("undefined method '#{name}' for #{self}:#{self.class}")
       end

      if args.size == 1 and args[0].instance_of? Hash
        kwargs = args[0]
        invoke_args = method.fields.map do |f|
          kwargs[f.name]
        end
        content = kwargs[:content]
      else
        invoke_args = []
        method.fields.each do |f|
          if args.any?
            invoke_args << args.shift()
          else
            invoke_args << f.default
          end
        end
        if method.content? and args.any?
          content = args.shift()
        else
          content = nil
        end
        if args.any? then raise ArgumentError.new("#{args.size} extr arguments") end
      end
      return invoke(method, invoke_args, content)
    end

    def invoke(method, args, content = nil)
      raise Closed() if closed?
      frame = Frame.new(@id, Method.new(method, args))
      @outgoing << frame

      if method.content?
        content = Content.new() if content.nil?
        write_content(method.parent, content, @outgoing)
      end

      nowait = false
      f = method.fields[:"nowait"]
      nowait = args[method.fields.index(f)] unless f.nil?

      unless nowait or method.responses.empty?
        resp = @responses.pop().payload
        if resp.method.content?
          content = read_content(@responses)
        else
          content = nil
        end
        if method.responses.include? resp.method
          return Message.new(resp.method, resp.args, content)
        else
          # XXX: ValueError doesn't actually exist
          raise ValueError.new(resp)
        end
      end
    end

    def write_content(klass, content, queue)
      size = content.size
      header = Frame.new(@id, Header.new(klass, content.weight, size, content.headers))
      queue << header
      content.children.each {|child| write_content(klass, child, queue)}
      queue << Frame.new(@id, Body.new(content.body)) if size > 0
    end

  end

  def Qpid.read_content(queue)
    frame = queue.pop()
    header = frame.payload
    children = []
    1.upto(header.weight) { children << read_content(queue) }
    size = header.size
    read = 0
    buf = ""
    while read < size
      body = queue.pop()
      content = body.payload.content
      buf << content
      read += content.size
    end
    buf.freeze()
    return Content.new(header.properties.clone(), buf, children)
  end

  class Content
    def initialize(headers = {}, body = "", children = [])
      @headers = headers
      @body = body
      @children = children
    end

    attr_reader :headers, :body, :children

    def size; body.size end
    def weight; children.size end

    def [](key); @headers[key] end
    def []=(key, value); @headers[key] = value end
  end

  class Message
    fields(:method, :args, :content)

    alias fields args

    def method_missing(name)
      return args[@method.fields[name].id]
    end

    def inspect()
      "#{method.qname}(#{args.join(", ")})"
    end
  end

  module Delegate
    def dispatch(ch, msg)
      send(msg.method.qname, ch, msg)
    end
  end

end
