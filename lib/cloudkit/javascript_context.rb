module CloudKit
  class JavascriptContext
    import org.mozilla.javascript.Context
    import org.mozilla.javascript.Scriptable
    import org.mozilla.javascript.ScriptableObject
    import org.mozilla.javascript.Undefined
    import org.mozilla.javascript.NativeArray
    import org.mozilla.javascript.NativeObject

    def initialize
      @context = Context.enter
      @scope = @context.init_standard_objects
      @context.evaluate_string(@scope, "window = {};", "<eval>", 1, nil)
    end

    def load(file)
      @context.evaluate_string(@scope, File.read(file), file, 1, nil)
    end

    def eval(script)
      unwrap(@context.evaluate_string(@scope, script, "<eval>", 1, nil))
    end

    def get(name)
      ScriptableObject.getProperty(@scope, name)
    end

    def put(name, value)
      ScriptableObject.putProperty(@scope, name, value)
    end

    private

    def unwrap(object)
      case object
      when Java::OrgMozillaJavascript::NativeArray
        objects = @context.class.js_to_java(object, java.lang.Object[]).to_a
        objects.map { |o| unwrap(o) }
      when Java::OrgMozillaJavascript::NativeObject
        object.get_all_ids.inject({}) { |m,o| m[o] = object.get(o, @scope); m }
      else
        object
      end
    end

  end
end
