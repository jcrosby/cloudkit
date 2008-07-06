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

module Codec
  # is there a better way to do this?
  class StringWriter

    def initialize(str = "")
      @str = str
    end

    def write(value)
      @str << value
    end

    def to_s()
      return @str
    end

  end

  class EOF < Exception; end

  class Encoder

    def initialize(out)
      @out = out
      @bits = []
    end

    attr_reader(:out)

    def encode(type, value)
      send(type, value)
    end

    def bit(b)
      @bits << b
    end

    def octet(o)
      pack("C", o)
    end

    def short(s)
      pack("n", s)
    end

    def long(l)
      pack("N", l)
    end

    def longlong(l)
      lower = l & 0xffffffff
      upper = (l & ~0xffffffff) >> 32
      long(upper)
      long(lower)
    end

    def shortstr(s)
      # shortstr is actually octetstr
      octet(s.length)
      write(s)
    end

    def longstr(s)
      case s
      when Hash
        table(s)
      else
        long(s.length)
        write(s)
      end
    end

    def table(t)
      t = {} if t.nil?
      enc = Encoder.new(StringWriter.new())
      t.each {|key, value|
        enc.shortstr(key)
        # I offer this chicken to the gods of polymorphism. May they
        # choke on it.
        case value
        when String
          type = :longstr
          desc = "S"
        when Numeric
          type = :long
          desc = "I"
        else
          raise Exception.new("unknown table value: #{value.class}")
        end
        enc.write(desc)
        enc.encode(type, value)
      }
      longstr(enc.out.to_s())
    end

    def write(str)
      flushbits()
      @out.write(str)
#      puts "OUT #{str.inspect()}"
    end

    def pack(fmt, *args)
      write(args.pack(fmt))
    end

    def flush()
      flushbits()
    end

    private

    def flushbits()
      if @bits.empty? then return end

      bytes = []
      index = 0
      @bits.each {|b|
        bytes << 0 if index == 0
        if b then bytes[-1] |= 1 << index end
        index = (index + 1) % 8
      }
      @bits.clear()
      bytes.each {|b|
        octet(b)
      }
    end

  end

  class StringReader

    def initialize(str)
      @str = str
      @index = 0
    end

    def read(n)
      result = @str[@index, n]
      @index += result.length
      return result
    end

  end

  class Decoder

    def initialize(_in)
      @in = _in
      @bits = []
    end

    def decode(type)
      return send(type)
    end

    def bit()
      if @bits.empty?
        byte = octet()
        7.downto(0) {|i|
          @bits << (byte[i] == 1)
        }
      end
      return @bits.pop()
    end

    def octet()
      return unpack("C", 1)
    end

    def short()
      return unpack("n", 2)
    end

    def long()
      return unpack("N", 4)
    end

    def longlong()
      upper = long()
      lower = long()
      return upper << 32 | lower
    end

    def shortstr()
      # shortstr is actually octetstr
      return read(octet())
    end

    def longstr()
      return read(long())
    end

    def table()
      dec = Decoder.new(StringReader.new(longstr()))
      result = {}
      while true
        begin
          key = dec.shortstr()
        rescue EOF
          break
        end
        desc = dec.read(1)
        case desc
        when "S"
          value = dec.longstr()
        when "I"
          value = dec.long()
        else
          raise Exception.new("unrecognized descriminator: #{desc.inspect()}")
        end
        result[key] = value
      end
      return result
    end

    def read(n)
      return "" if n == 0
      result = @in.read(n)
      if result.nil? or result.empty?
        raise EOF.new()
      else
#        puts " IN #{result.inspect()}"
        return result
      end
    end

    def unpack(fmt, size)
      result = read(size).unpack(fmt)
      if result.length == 1
        return result[0]
      else
        return result
      end
    end

  end

end
