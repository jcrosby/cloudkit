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

module Qpid

  class Closed < Exception; end

  class Queue < Queue

    @@END = Object.new()
    @@FAILED = Object.new()

    def close()
      # sentinal to indicate the end of the queue
      puts "closing queue"
      self << @@END
    end
    
    def fail()
      puts "failing queues"
      self << @@FAILED
    end

    def pop(*args)
      result = super(*args)
      if @@END.equal? result
        # we put another sentinal on the end in case there are
        # subsequent calls to pop by this or other threads
        self << @@END
        raise Closed.new()
      elsif @@FAILED == result
        self << @@FAILED
        raise "Failed"
      else
        return result
      end
    end

    alias shift pop
    alias deq pop

  end

end
