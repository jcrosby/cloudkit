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

require "socket"
require "qpid/codec"

include Codec

module Qpid

  class Connection

    def initialize(host, port, spec)
      @host = host
      @port = port
      @spec = spec
    end

    attr_reader(:host, :port, :spec)

    def connect()
      @sock = TCPSocket.open(@host, @port)
      @out = Encoder.new(@sock)
      @in = Decoder.new(@sock)
    end

    def init()
      @out.write("AMQP")
      [1, 1, @spec.major, @spec.minor].each {|o|
        @out.octet(o)
      }
    end

    def write(frame)
#      puts "OUT #{frame.inspect()}"
      @out.octet(@spec.constants[frame.payload.type].id)
      @out.short(frame.channel)
      frame.payload.encode(@out)
      @out.octet(frame_end)
    end

    def read()
      type = @spec.constants[@in.octet()].name
      channel = @in.short()
      payload = Payload.decode(type, @spec, @in)
      oct = @in.octet()
      if oct != frame_end
        raise Exception.new("framing error: expected #{frame_end}, got #{oct}")
      end
      frame = Frame.new(channel, payload)
#      puts " IN #{frame.inspect}"
      return frame
    end

    def closed?
      @sock.closed? || @sock.eof?
    end

    private

    def frame_end
      @spec.constants[:"frame_end"].id
    end

  end

  class Frame

    def initialize(channel, payload)
      @channel = channel
      @payload = payload
    end

    attr_reader(:channel, :payload)

  end

  class Payload

    TYPES = {}

    def Payload.singleton_method_added(name)
      if name == :type
        TYPES[type] = self
      end
    end

    def Payload.decode(type, spec, dec)
      klass = TYPES[type]
      klass.decode(spec, dec)
    end

  end

  class Method < Payload

    def initialize(method, args)
      if args.size != method.fields.size
        raise ArgumentError.new("argument mismatch #{method} #{args}")
      end
      @method = method
      @args = args
    end

    attr_reader(:method, :args)

    def Method.type; :frame_method end

    def type; Method.type end

    def encode(encoder)
      buf = StringWriter.new()
      enc = Encoder.new(buf)
      enc.short(@method.parent.id)
      enc.short(@method.id)
      @method.fields.zip(self.args).each {|f, a|
        if a.nil?; a = f.default end
        enc.encode(f.type, a)
      }
      enc.flush()
      encoder.longstr(buf.to_s)
    end

    def Method.decode(spec, decoder)
      buf = decoder.longstr()
      dec = Decoder.new(StringReader.new(buf))
      klass = spec.classes[dec.short()]
      meth = klass.methods[dec.short()]
      args = meth.fields.map {|f| dec.decode(f.type)}
      return Method.new(meth, args)
    end

    def inspect(); "#{method.qname}(#{args.join(", ")})" end

  end

  class Header < Payload

    def Header.type; :frame_header end

    def initialize(klass, weight, size, properties)
      @klass = klass
      @weight = weight
      @size = size
      @properties = properties
    end

    attr_reader :weight, :size, :properties

    def type; Header.type end

    def encode(encoder)
      buf = StringWriter.new()
      enc = Encoder.new(buf)
      enc.short(@klass.id)
      enc.short(@weight)
      enc.longlong(@size)

      # property flags
      nprops = @klass.fields.size
      flags = 0
      0.upto(nprops - 1) do |i|
        f = @klass.fields[i]
        flags <<= 1
        flags |= 1 unless @properties[f.name].nil?
        # the last bit indicates more flags
        if i > 0 and (i % 15) == 0
          flags <<= 1
          if nprops > (i + 1)
            flags |= 1
            enc.short(flags)
            flags = 0
          end
        end
      end
      flags <<= ((16 - (nprops % 15)) % 16)
      enc.short(flags)

      # properties
      @klass.fields.each do |f|
        v = @properties[f.name]
        enc.encode(f.type, v) unless v.nil?
      end
      enc.flush()
      encoder.longstr(buf.to_s)
    end

    def Header.decode(spec, decoder)
      dec = Decoder.new(StringReader.new(decoder.longstr()))
      klass = spec.classes[dec.short()]
      weight = dec.short()
      size = dec.longlong()

      # property flags
      bits = []
      while true
        flags = dec.short()
        15.downto(1) do |i|
          if flags >> i & 0x1 != 0
            bits << true
          else
            bits << false
          end
        end
        break if flags & 0x1 == 0
      end

      # properties
      properties = {}
      bits.zip(klass.fields).each do |b, f|
        properties[f.name] = dec.decode(f.type) if b
      end
      return Header.new(klass, weight, size, properties)
    end

    def inspect(); "#{@klass.name}(#{@properties.inspect()})" end

  end

  class Body < Payload

    def Body.type; :frame_body end

    def type; Body.type end

    def initialize(content)
      @content = content
    end

    attr_reader :content

    def encode(enc)
      enc.longstr(@content)
    end

    def Body.decode(spec, dec)
      return Body.new(dec.longstr())
    end

  end

end
