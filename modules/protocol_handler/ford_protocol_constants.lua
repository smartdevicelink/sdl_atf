--- Module which provides constants for the Ford protocol
--
-- *Dependencies:* none
--
-- *Globals:* none
-- @module protocol_handler.ford_protocol_constants
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local SDLProtocolConstants = {}
--- Frame type enumeration
SDLProtocolConstants.FRAME_TYPE = {
  CONTROL_FRAME = 0x00,
  SINGLE_FRAME = 0x01,
  FIRST_FRAME = 0x02,
  CONSECUTIVE_FRAME = 0x03,
}
--- Service type enumeration
SDLProtocolConstants.SERVICE_TYPE = {
  CONTROL = 0x00,
  PCM = 0x0A,
  VIDEO = 0x0B,
  BULK_DATA = 0x0F,
  RPC = 0x07,
}
--- frame info enumeration
SDLProtocolConstants.FRAME_INFO = {
  HEARTBEAT = 0x00,
  LAST_FRAME = 0x00,
  START_SERVICE = 0x01,
  START_SERVICE_ACK = 0x02,
  START_SERVICE_NACK = 0x03,
  END_SERVICE = 0x04,
  END_SERVICE_ACK = 0x05,
  END_SERVICE_NACK = 0x06,
  SERVICE_DATA_ACK = 0xFE,
  HEARTBEAT_ACK = 0xFF
}

return SDLProtocolConstants
