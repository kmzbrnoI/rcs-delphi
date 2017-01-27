////////////////////////////////////////////////////////////////////////////////
// RCSErrors.pas
//  Taken from MTB communication library
//  Error codes definiton
//   (c) Jan Horacek (jan.horacek@kmz-brno.cz),
////////////////////////////////////////////////////////////////////////////////

{
   LICENSE:

   Copyright 2016 Jan Horacek

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
  limitations under the License.
}

{
  DESCRIPTION:

  This file defines library error codes.

  It is necessary to keep this file synced with actual library error codes!
}

unit RCSErrors;

interface

uses SysUtils;

const
 RCS_GENERAL_EXCEPTION = 1000;
 RCS_FT_EXCEPTION = 1001;       // device is always closed when this exception happens
 RCS_FILE_CANNOT_ACCESS = 1010;
 RCS_FILE_DEVICE_OPENED = 1011;
 RCS_MODULE_INVALID_ADDR = 1100;
 RCS_MODULE_FAILED = 1102;
 RCS_PORT_INVALID_NUMBER = 1103;
 RCS_MODULE_UNKNOWN_TYPE = 1104;
 RCS_INVALID_SPEED = 1105;
 RCS_INVALID_SCOM_CODE = 1106;
 RCS_INVALID_MODULES_COUNT = 1107;
 RCS_INPUT_NOT_YET_SCANNED = 1108;

 RCS_ALREADY_OPENNED = 2001;
 RCS_CANNOT_OPEN_PORT = 2002;
 RCS_FIRMWARE_TOO_LOW = 2003;
 RCS_DEVICE_DISCONNECTED = 2004;
 RCS_SCANNING_NOT_FINISHED = 2010;
 RCS_NOT_OPENED = 2011;
 RCS_ALREADY_STARTED = 2012;
 RCS_OPENING_NOT_FINISHED = 2021;
 RCS_NO_MODULES = 2025;
 RCS_NOT_STARTED = 2031;

 RCS_INVALID_PACKET = 3100;
 RCS_MODULE_NOT_ANSWERED_CMD = 3101;
 RCS_MODULE_NOT_ANSWERED_CMD_GIVING_UP = 3102;
 RCS_MODULE_OUT_SUM_ERROR = 3106;
 RCS_MODULE_OUT_SUM_ERROR_GIVING_UP = 3107;
 RCS_MODULE_IN_SUM_ERROR = 3108;
 RCS_MODULE_IN_SUM_ERROR_GIVING_UP = 3109;

 RCS_MODULE_NOT_RESPONDED_FB = 3121;
 RCS_MODULE_NOT_RESPONDED_FB_GIVING_UP = 3122;
 RCS_MODULE_IN_FB_SUM_ERROR = 3126;
 RCS_MODULE_IN_FB_SUM_ERROR_GIVING_UP = 3127;
 RCS_MODULE_OUT_FB_SUM_ERROR = 3128;
 RCS_MODULE_OUT_FB_SUM_ERROR_GIVING_UP = 3129;
 RCS_MODULE_INVALID_FB_SUM = 3125;
 RCS_MODULE_NOT_RESPONDING_PWR_ON = 3131;

 RCS_MODULE_PWR_ON_IN_SUM_ERROR = 3136;
 RCS_MODULE_PWR_ON_IN_SUM_ERROR_GIVING_UP = 3137;
 RCS_MODULE_PWR_ON_OUT_SUM_ERROR = 3138;
 RCS_MODULE_PWR_ON_OUT_SUM_ERROR_GIVING_UP = 3139;

 RCS_MODULE_FAIL = 3141;
 RCS_MODULE_RESTORED = 3142;
 RCS_MODULE_INVALID_DATA = 3145;

 RCS_MODULE_REWIND_IN_SUM_ERROR = 3162;
 RCS_MODULE_REWIND_OUT_SUM_ERROR = 3163;

 RCS_MODULE_SCAN_IN_SUM_ERROR = 3166;
 RCS_MODULE_SCAN_IN_SUM_ERROR_GIVING_UP = 3167;
 RCS_MODULE_SCAN_OUT_SUM_ERROR = 3168;
 RCS_MODULE_SCAN_OUT_SUM_ERROR_GIVING_UP = 3169;

 RCS_MODULE_SC_IN_SUM_ERROR = 3176;
 RCS_MODULE_SC_IN_SUM_ERROR_GIVING_UP = 3177;
 RCS_MODULE_SC_OUT_SUM_ERROR = 3178;
 RCS_MODULE_SC_OUT_SUM_ERROR_GIVING_UP = 3179;

type
  EAlreadyOpened = class(Exception);
  ECannotOpenPort = class(Exception);
  EFirmwareTooLog = class(Exception);
  ENotOpened = class(Exception);
  EAlreadyStarted = class(Exception);
  EOpeningNotFinished = class(Exception);
  ENoModules = class(Exception);
  ENotStarted = class(Exception);
  EInvalidScomCode = class(Exception);


implementation

end.
