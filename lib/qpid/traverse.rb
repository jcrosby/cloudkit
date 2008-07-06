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

class Object

  public

  def traverse()
    traverse! {|o| yield(o); o}
  end

  def traverse_children!()
    instance_variables.each {|v|
      value = instance_variable_get(v)
      replacement = yield(value)
      instance_variable_set(v, replacement) unless replacement.equal? value
    }
  end

  def traverse!(replacements = {})
    return replacements[__id__] if replacements.has_key? __id__
    replacement = yield(self)
    replacements[__id__] = replacement
    traverse_children! {|o| o.traverse!(replacements) {|c| yield(c)}}
    return replacement
  end

end

class Array
  def traverse_children!()
    map! {|o| yield(o)}
  end
end

class Hash
  def traverse_children!()
    mods = {}
    each_pair {|k, v|
      key = yield(k)
      value = yield(v)
      mods[key] = value unless key.equal? k and value.equal? v
      delete(k) unless key.equal? k
    }

    merge!(mods)
  end
end
