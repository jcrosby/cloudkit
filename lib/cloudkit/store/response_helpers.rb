module CloudKit::ResponseHelpers
  def status_404
    json_error_response(404, 'not found')
  end

  def status_405(methods)
    response = json_error_response(405, 'method not allowed')
    response['Allow'] = methods.join(', ')
    response
  end

  def status_410
    json_error_response(410, 'entity previously deleted')
  end

  def status_412
    json_error_response(412, 'precondition failed')
  end

  def status_422
    json_error_response(422, 'unprocessable entity')
  end

  def internal_server_error
    json_error_response(500, 'unknown server error')
  end

  def data_required
    json_error_response(400, 'data required')
  end

  def invalid_entity_type
    json_error_response(400, 'valid entity type required')
  end

  def etag_required
    json_error_response(400, 'etag required')
  end

  def allow(methods)
    CloudKit::Response.new(200, {'Allow' => methods.join(', ')})
  end

  def response(status, content='', etag=nil, last_modified=nil, options={})
    cache_control = options[:cache] == false ? 'no-cache' : 'proxy-revalidate'
    headers = {
      'Content-Type'  => 'application/json',
      'Cache-Control' =>  cache_control}
    headers.merge!('ETag' => "\"#{etag}\"") if etag
    headers.merge!('Last-Modified' => last_modified) if last_modified
    CloudKit::Response.new(status, headers, content)
  end

  def json_meta_response(status, uri, etag, last_modified)
    json = JSON.generate(
      :ok            => true,
      :uri           => uri,
      :etag          => etag,
      :last_modified => last_modified)
    response(status, json, nil, nil, :cache => false)
  end

  def json_error(message)
    "{\"error\":\"#{message}\"}"
  end

  def json_error_response(status, message)
    "trying to throw a json error message for #{status} #{message}"
    response(status, json_error(message), nil, nil, :cache => false)
  end
end
