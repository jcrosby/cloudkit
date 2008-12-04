module CloudKit::GetHelpers
  def collection(type, options)
    unless options[:id]
      result = @db[type]
      if ([:etag, :remote_user].any?{|k| options[k]} || is_view?(type))
        result = result.filter(
          options.reject{|k,v| k == :if_none_match})
      end
      result = result.map(:content).join(",\n") || []
      response(200, json_list(result))
    end
  end

  def current_resource(type, options)
    result = @db[type].filter(options.reject{|k,v| k == :if_none_match})
    if result.any?
      if options[:if_none_match].try(:first) == result.first[:etag]
        return response(
          304,
          '',
          result.first[:etag],
          result.first[:last_modified])
      end
      response(
        200,
        result.first[:content],
        result.first[:etag],
        result.first[:last_modified])
    end
  end

  def removed_resource(type, options)
    result = @db[self.class.history(type)].filter(identify(
      options.reject{|k,v| k == :if_none_match},
      :entity_id => options[:id]))
    status_410 if result.any?
  end

  def resource_history(type, options)
    if is_history?(type)
      current = current_resource(self.class.current(type), options)
      return status_404 unless current
      return id_required unless options[:id]
      if options[:etag] && options[:if_none_match]
        return precondition_conflict
      end
      options.rekey!(:id, :entity_id)
      if options[:if_none_match]
        result = @db[type].filter(identify(
          options.reject{|k,v| k == :if_none_match})).reverse_order(:id)
        result = result.filter(~{:etag => options[:if_none_match]})
      else
        result = @db[type].filter(
          options.filter_merge!(identify(
            options))).reverse_order(:id)
      end
      result = result.map(:content).join(",\n") || []
      response(200, json_list(result))
    end
  end

  def resource_version(type, options)
    result = @db[self.class.history(type)].filter(identify(
      options.reject{|k,v| k == :if_none_match},
      :entity_id => options[:id],
      :etag      => options[:etag]))
    if result.any?
      response(
        200,
        result.first[:content],
        result.first[:etag],
        result.first[:last_modified])
    end
  end
end
