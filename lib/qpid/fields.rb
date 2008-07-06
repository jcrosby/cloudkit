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

class Class
  def fields(*fields)
    module_eval {
      def initialize(*args, &block)
        args = init_fields(*args)

        if respond_to? :init
          init(*args) {|*a| yield(*a)}
        elsif args.any?
          raise ArgumentException.new("extra arguments: #{args}")
        end
      end
    }

    vars = fields.map {|f| :"@#{f.to_s().chomp("?")}"}

    define_method(:init_fields) {|*args|
      vars.each {|v|
        instance_variable_set(v, args.shift())
      }
      args
    }

    vars.each_index {|i|
      define_method(fields[i]) {
        instance_variable_get(vars[i])
      }
    }
  end
end
