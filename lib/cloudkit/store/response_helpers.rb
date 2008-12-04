module CloudKit::ResponseHelpers
  def response(status, content='', etag=nil, last_modified=nil)
    headers = {
      'Content-Type'  => 'application/json',
      'Cache-Control' => 'proxy-revalidate'}
    headers['Etag'] = etag if etag
    headers['Last-Modified'] = last_modified if last_modified
    CloudKit::Response.new(status, headers, content)
  end

  def json_id(id)
    "{\"id\":\"#{id}\"}"
  end

  def json_error(message)
    "{\"error\":\"#{message}\"}"
  end

  def json_list(list)
    "{\"documents\":[\n#{list}\n]}"
  end

  def status_404
    response(404, json_error('not found'))
  end

  def status_410
    response(410, json_error('entity previously deleted'))
  end

  def status_412
    response(412, json_error('precondition failed'))
  end

  def status_422
    response(422, json_error('unprocessable entity'))
  end

  def data_required
    response(400, json_error('data required'))
  end

  def id_required
    response(400, json_error('id required'))
  end

  def id_mismatch
    response(400, json_error('id mismatch in content'))
  end

  def invalid_entity_type
    response(400, json_error('valid entity type required'))
  end

  def etag_required
    response(400, json_error('etag required'))
  end

  def etag_mismatch
    response(400, json_error('etag mismatch in content'))
  end

  def precondition_conflict
    response(400, json_error('precondition conflict'))
  end
end
