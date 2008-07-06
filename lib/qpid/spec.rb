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

require "set"
require "rexml/document"
require "qpid/fields"
require "qpid/traverse"

module Spec

  include REXML

  class Container < Array

    def initialize()
      @cache = {}
    end

    def [](key)
      return @cache[key] if @cache.include?(key)

      case key
      when String
        value = find {|x| x.name == key.intern()}
      when Symbol
        value = find {|x| x.name == key}
      when Integer
        value = find {|x| x.id == key}
      else
        raise Exception.new("invalid key: #{key}")
      end

      @cache[key] = value
      return value
    end

  end

  class Root
    fields(:major, :minor, :classes, :constants, :domains)

    def find_method(name)
      classes.each do |c|
        c.methods.each do |m|
          if name == m.qname
            return m
          end
        end
      end

      return nil
    end
  end

  class Constant
    fields(:name, :id, :type, :docs)
  end

  class Domain
    fields(:name, :type)
  end

  class Class
    fields(:name, :id, :handler, :fields, :methods, :docs)
  end

  class Method
    fields(:name, :id, :content?, :responses, :synchronous?, :fields,
         :docs)

    def init()
      @response = false
    end

    attr :parent, true

    def response?; @response end
    def response=(b); @response = b end

    def qname
      :"#{parent.name}_#{name}"
    end
  end

  class Field
    fields(:name, :id, :type, :docs)

    def default
      case type
      when :bit then false
      when :octet, :short, :long, :longlong then 0
      when :shortstr, :longstr then ""
      when :table then {}
      end
    end

  end

  class Doc
    fields(:type, :text)
  end

  class Reference

    fields(:name)

    def init(&block)
      @resolver = block
    end

    def resolve(spec, klass)
      @resolver.call(spec, klass)
    end

  end

  class Loader

    def initialize()
      @stack = []
    end

    def load(obj)
      case obj
      when String
        elem = @stack[-1]
        result = Container.new()
        elem.elements.each(obj) {|e|
          @index = result.size
          result << load(e)
        }
        @index = nil
        return result
      else
        elem = obj
        @stack << elem
        begin
          result = send(:"load_#{elem.name}")
        ensure
          @stack.pop()
        end
        return result
      end
    end

    def element
      @stack[-1]
    end

    def text
      element.text
    end

    def attr(name, type = :string, default = nil)
      value = element.attributes[name]
      value = value.strip() unless value.nil?
      value = nil unless value.nil? or value.any?
      if value.nil? and not default.nil? then
        default
      else
        send(:"parse_#{type}", value)
      end
    end

    def parse_int(value)
      value.to_i
    end

    TRUE = ["yes", "true", "1"].to_set
    FALSE = ["no", "false", "0", nil].to_set

    def parse_bool(value)
      if TRUE.include?(value)
        true
      elsif FALSE.include?(value)
        false
      else
        raise Exception.new("parse error, expecting boolean: #{value}")
      end
    end

    def parse_string(value)
      value.to_s
    end

    def parse_symbol(value)
      value.intern() unless value.nil?
    end

    def parse_name(value)
      value.gsub(/[\s-]/, '_').intern() unless value.nil?
    end

    def load_amqp()
      Root.new(attr("major", :int), attr("minor", :int), load("class"),
               load("constant"), load("domain"))
    end

    def load_class()
      Class.new(attr("name", :name), attr("index", :int), attr("handler", :name),
                load("field"), load("method"), load("doc"))
    end

    def load_method()
      Method.new(attr("name", :name), attr("index", :int),
                 attr("content", :bool), load("response"),
                 attr("synchronous", :bool), load("field"), load("docs"))
    end

    def load_response()
      name = attr("name", :name)
      Reference.new {|spec, klass|
        response = klass.methods[name]
        if response.nil?
          raise Exception.new("no such method: #{name}")
        end
        response
      }
    end

    def load_field()
      type = attr("type", :name)
      if type.nil?
        domain = attr("domain", :name)
        type = Reference.new {|spec, klass|
          spec.domains[domain].type
        }
      end
      Field.new(attr("name", :name), @index, type, load("docs"))
    end

    def load_constant()
      Constant.new(attr("name", :name), attr("value", :int), attr("class", :name),
                   load("doc"))
    end

    def load_domain()
      Domain.new(attr("name", :name), attr("type", :name))
    end

    def load_doc()
      Doc.new(attr("type", :symbol), text)
    end

  end

  def Spec.load(spec)
    case spec
    when String
      spec = File.new(spec)
    end
    doc = Document.new(spec)
    spec = Loader.new().load(doc.root)
    spec.classes.each do |klass|
      klass.traverse! do |o|
        case o
        when Reference
          o.resolve(spec, klass)
        else
          o
        end
      end
      klass.methods.each do |m|
        m.parent = klass
        m.responses.each do |r|
          r.response = true
        end
      end
    end
    spec
  end

end
