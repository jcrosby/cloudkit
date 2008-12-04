module CloudKit::Validators
  def check(options, *methods)
    methods.to_a.inject(nil) do |result, method|
      result || send(method, options)
    end
  end

  def has_data(options)
    data_required unless options[:data]
  end

  def has_id(options)
    id_required unless options[:id]
  end

  def no_if_none_match(options)
    if options[:if_none_match]
      status_412
    end
  end
end
