local SecurityConstants = {}

SecurityConstants.SECURITY_STATUS = {
  ERROR = -1,
  SUCCESS = 0,
  NO_DATA = 1,
  NO_ENCRYPTION = 2,
}

SecurityConstants.BIO_TYPES = {
  SOURCE = 0,
  FILTER = 1
}

SecurityConstants.PROTOCOLS = {
  AUTO = 0,
  SSL = 1,
  TLS = 2,
  DTLS = 3,
}

return SecurityConstants
