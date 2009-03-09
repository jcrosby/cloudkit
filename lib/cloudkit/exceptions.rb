module CloudKit

  # HistoricalIntegrityViolation exceptions are raised when an attempt is made
  # to modify an archived or deleted version of a resource.
  class HistoricalIntegrityViolation < Exception; end

  # InvalidURIFormat exceptions are raised during attempts to get or generate
  # cannonical URIs from non-collection or non-resource URIs.
  class InvalidURIFormat < Exception; end
end
