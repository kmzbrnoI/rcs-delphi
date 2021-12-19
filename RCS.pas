////////////////////////////////////////////////////////////////////////////////
// RCS.pas
// Interface to Railroad Control System (e.g. MTB, simulator, possibly DCC).
// (c) Jan Horacek, Michal Petrilak 2017-2020
// jan.horacek@kmz-brno.cz, engineercz@gmail.com
// license: Apache license v2.0
////////////////////////////////////////////////////////////////////////////////

{
   LICENSE:

   Copyright 2017-2021 Jan Horacek, Michal Petrilak

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
  TRCSIFace class allows its parent to load dll library with railroad control
  system and simply use its functions.
}

{
  WARNING:
   It is required to check whether functions in this class are really mapped to
   dll functions (the do not have to exist)
}

unit RCS;

interface

uses
  SysUtils, Classes, Windows, RCSErrors, Generics.Collections;

const
  _RCS_MOD_NONE = $0;
  _RCS_MOD_MTB_POT_ID = $10;
  _RCS_MOD_MTB_REGP_ID = $30;
  _RCS_MOD_MTB_UNI_ID = $40;
  _RCS_MOD_MTB_UNIOUT_ID = $50;
  _RCS_MOD_MTB_TTL_ID = $60;
  _RCS_MOD_MTB_TTLOUT_ID = $70;

  // RCS API supported versions.
  // Versions at end of the array are picked preferrably.
  _RCS_API_SUPPORTED_VERSIONS : array[0..2] of Cardinal = (
    $0301, $0401, $0501 // v1.3, v1.4, v1.5
  );

type
  TRCSLogLevel = (
    llNo = 0,
    llErrors = 1,
    llWarnings = 2,
    llInfo = 3,
    llCommands = 4,
    llRawCommands = 5,
    llDebug = 6
  );

  ///////////////////////////////////////////////////////////////////////////
  // Events called from library to TRCSIFace:

  TStdNotifyEvent = procedure (Sender: TObject; data: Pointer); stdcall;
  TStdLogEvent = procedure (Sender: TObject; data: Pointer; logLevel: Integer; msg: PChar); stdcall;
  TStdErrorEvent = procedure (Sender: TObject; data: Pointer; errValue: word; errAddr: Cardinal; errMsg: PChar); stdcall;
  TStdModuleChangeEvent = procedure (Sender: TObject; data: Pointer; module: Cardinal); stdcall;

  ///////////////////////////////////////////////////////////////////////////
  // Events called from TRCSIFace to parent:

  TLogEvent = procedure (Sender: TObject; logLevel: TRCSLogLevel; msg: string) of object;
  TErrorEvent = procedure (Sender: TObject; errValue: word; errAddr: Cardinal; errMsg: PChar) of object;
  TModuleChangeEvent = procedure (Sender: TObject; module: Cardinal) of object;

  ///////////////////////////////////////////////////////////////////////////
  // Prototypes of functions called to library:

  TDllPGeneral = procedure(); stdcall;
  TDllFGeneral = function(): Integer; stdcall;
  TDllFCardGeneral = function(): Cardinal; stdcall;

  TDllFileIO = function(filename: PChar): Integer; stdcall;
  TDllFileIOProc = procedure(filename: PChar); stdcall;

  TDllSetLogLevel = procedure(loglevel: Cardinal); stdcall;
  TDllGetLogLevel = function(): Cardinal; stdcall;

  TDllBoolGetter = function(): Boolean; stdcall;
  TDllModuleGet = function(module, port: Cardinal): Integer; stdcall;
  TDllModuleSet = function(module, port: Cardinal; state: Integer): Integer; stdcall;
  TDllModuleBoolGetter = function(module: Cardinal): Boolean; stdcall;
  TDllModuleIntGetter = function(module: Cardinal): Integer; stdcall;
  TDllModuleCardGetter = function(module: Cardinal): Cardinal; stdcall;
  TDllModuleStringGetter = function(module: Cardinal; str: PChar; strMaxLen: Cardinal): Integer; stdcall;

  TDllDeviceSerialGetter = procedure(index: Integer; serial: PChar; serialLen: Cardinal); stdcall;
  TDllDeviceVersionGetter = function(version: PChar; versionMaxLen: Cardinal): Integer; stdcall;
  TDllApiVersionAsker = function(version: Integer): Boolean; stdcall;
  TDllApiVersionSetter = function(version: Integer): Integer; stdcall;
  TDllVersionGetter = procedure(version: PChar; versionMaxLen: Cardinal); stdcall;

  TDllStdNotifyBind = procedure(event: TStdNotifyEvent; data: Pointer); stdcall;
  TDllStdLogBind = procedure(event: TStdLogEvent; data: Pointer); stdcall;
  TDllStdErrorBind = procedure(event: TStdErrorEvent; data: Pointer); stdcall;
  TDllStdModuleChangeBind = procedure(event: TStdModuleChangeEvent; data: Pointer); stdcall;

  ///////////////////////////////////////////////////////////////////////////

  TRCSInputState = (
    isOff = 0,
    isOn = 1,
    failure = RCS_MODULE_FAILED,
    notYetScanned = RCS_INPUT_NOT_YET_SCANNED,
    unavailableModule = RCS_MODULE_INVALID_ADDR,
    unavailablePort = RCS_PORT_INVALID_NUMBER
  );

  TRCSOutputState = (
    osDisabled = 0,
    osEnabled = 1,
    osf60 = 60,
    osf120 = 120,
    osf180 = 180,
    osf240 = 240,
    osf300 = 300,
    osf600 = 600,
    osf33 = 33,
    osf66 = 66,
    osFailure = RCS_MODULE_FAILED,
    osNotYetScanned = RCS_INPUT_NOT_YET_SCANNED,
    osUnavailableModule = RCS_MODULE_INVALID_ADDR,
    osUnavailablePort = RCS_PORT_INVALID_NUMBER
  );

  ///////////////////////////////////////////////////////////////////////////

  TRCSIPortType = (
    iptPlain = 0,
    iptIR = 1
  );

  TRCSOPortType = (
    optPlain = 0,
    optSCom = 1
  );

  ///////////////////////////////////////////////////////////////////////////

  TRCSIFace = class
  private
    dllName: string;
    dllHandle: Cardinal;
    mApiVersion: Cardinal;

    // ------------------------------------------------------------------
    // Functions called to library:

    // config file load/save
    dllFuncLoadConfig: TDllFileIO;
    dllFuncSaveConfig: TDllFileIO;
    dllFuncSetConfigFileName: TDllFileIOProc;

    // logging
    dllFuncSetLogLevel: TDllSetLogLevel;
    dllFuncGetLogLevel: TDllGetLogLevel;

    // dialogs
    dllFuncShowConfigDialog : TDllPGeneral;
    dllFuncHideConfigDialog : TDllPGeneral;

    // open/close
    dllFuncOpen : TDllFGeneral;
    dllFuncClose : TDllFGeneral;
    dllFuncOpened : TDllBoolGetter;

    // start/stop
    dllFuncStart : TDllFGeneral;
    dllFuncStop : TDllFGeneral;
    dllFuncStarted : TDllBoolGetter;

    // ports IO
    dllFuncGetInput : TDllModuleGet;
    dllFuncGetOutput : TDllModuleGet;
    dllFuncSetOutput : TDllModuleSet;
    dllFuncSetInput : TDllModuleSet;
    dllFuncGetInputType : TDllModuleGet;
    dllFuncGetOutputType : TDllModuleGet;

    // modules
    dllFuncIsModule : TDllModuleBoolGetter;
    dllFuncIsModuleFailure: TDllModuleBoolGetter;
    dllFuncIsModuleError: TDllModuleBoolGetter;
    dllFuncIsModuleWarning: TDllModuleBoolGetter;
    dllFuncGetModuleCount : TDllFCardGeneral;
    dllFuncGetMaxModuleAddr : TDllFCardGeneral;
    dllFuncGetModuleType : TDllModuleIntGetter;
    dllFuncGetModuleTypeStr : TDllModuleStringGetter;
    dllFuncGetModuleName : TDllModuleStringGetter;
    dllFuncGetModuleFW : TDllModuleStringGetter;
    dllFuncGetModuleInputsCount : TDllModuleCardGetter;
    dllFuncGetModuleOutputsCount : TDllModuleCardGetter;

    // versions
    dllFuncApiSupportsVersion : TDllApiVersionAsker;
    dllFuncApiSetVersion : TDllApiVersionSetter;
    dllFuncGetDeviceVersion : TDllDeviceVersionGetter;
    dllFuncGetVersion : TDllVersionGetter;

    // features
    dllFuncIsSimulation : TDllBoolGetter;

    // ------------------------------------------------------------------
    // Events from TRCSIFace

    eBeforeOpen : TNotifyEvent;
    eAfterOpen : TNotifyEvent;
    eBeforeClose : TNotifyEvent;
    eAfterClose : TNotifyEvent;

    eBeforeStart : TNotifyEvent;
    eAfterStart : TNotifyEvent;
    eBeforeStop : TNotifyEvent;
    eAfterStop : TNotifyEvent;

    eOnError: TErrorEvent;
    eOnLog : TLogEvent;
    eOnModuleChange : TModuleChangeEvent;
    eOnInputChange : TModuleChangeEvent;
    eOnOutputChange : TModuleChangeEvent;
    eOnScanned : TNotifyEvent;

     procedure Reset();
     procedure PickApiVersion();
     function IsSimulation(): Boolean;

  public

    // list of unbound functions
    unbound: TList<string>;

     constructor Create();
     destructor Destroy(); override;

     procedure LoadLib(path: string; configFn: string);
     procedure UnloadLib();

     ////////////////////////////////////////////////////////////////////

     // file I/O
     procedure LoadConfig(fn: string);
     procedure SaveConfig(fn: string);
     procedure SetConfigFileName(fn: string);

     // logging
     procedure SetLogLevel(loglevel: TRCSLogLevel);
     function GetLogLevel(): TRCSLogLevel;
     class function LogLevelToString(ll: TRCSLogLevel): string;

     // dialogs
     procedure ShowConfigDialog();
     procedure HideConfigDialog();
     function HasDialog(): Boolean;

     // device open/close
     procedure Open();
     procedure Close();
     function Opened(): Boolean;

     // communication start/stop
     procedure Start();
     procedure Stop();
     function Started(): Boolean;

     // I/O functions:
     procedure SetOutput(module, port: Cardinal; state: Integer); overload;
     procedure SetOutput(module, port: Cardinal; state: TRCSOutputState); overload;
     function GetInput(module, port: Cardinal): TRCSInputState;
     procedure SetInput(module, port: Cardinal; State : Integer);
     function GetOutput(module, port: Cardinal): Integer;
     function GetOutputState(module, port: Cardinal): TRCSOutputState; overload;

     function GetInputType(module, port: Cardinal): TRCSIPortType;
     function GetOutputType(module, port: Cardinal): TRCSOPortType;

     // modules:
     function IsModule(Module: Cardinal): Boolean;
     function IsModuleFailure(module: Cardinal): Boolean;
     function IsModuleError(module: Cardinal): Boolean;
     function IsModuleWarning(module: Cardinal): Boolean;
     function IsNonFailedModule(module: Cardinal): Boolean;
     function GetModuleCount(): Cardinal;
     function GetMaxModuleAddr(): Cardinal;
     function GetModuleType(Module: Cardinal): string;
     function GetModuleName(module: Cardinal): string;
     function GetModuleFW(Module: Cardinal): string;
     function GetModuleInputsCount(Module: Cardinal): Cardinal;
     function GetModuleOutputsCount(Module: Cardinal): Cardinal;

     // versions:
     function GetDllVersion(): string;
     function GetDeviceVersion(): string;
     class function IsApiVersionSupport(version: Cardinal): Boolean;

     property BeforeOpen: TNotifyEvent read eBeforeOpen write eBeforeOpen;
     property AfterOpen: TNotifyEvent read eAfterOpen write eAfterOpen;
     property BeforeClose: TNotifyEvent read eBeforeClose write eBeforeClose;
     property AfterClose: TNotifyEvent read eAfterClose write eAfterClose;

     property BeforeStart: TNotifyEvent read eBeforeStart write eBeforeStart;
     property AfterStart: TNotifyEvent read eAfterStart write eAfterStart;
     property BeforeStop: TNotifyEvent read eBeforeStop write eBeforeStop;
     property AfterStop: TNotifyEvent read eAfterStop write eAfterStop;

     property OnError: TErrorEvent read eOnError write eOnError;
     property OnLog: TLogEvent read eOnLog write eOnLog;
     property OnModuleChanged: TModuleChangeEvent read eOnModuleChange write eOnModuleChange;
     property OnInputChanged: TModuleChangeEvent read eOnInputChange write eOnInputChange;
     property OnOutputChanged: TModuleChangeEvent read eOnOutputChange write eOnOutputChange;

     property OnScanned: TNotifyEvent read eOnScanned write eOnScanned;

     property Lib: string read dllName;
     property apiVersion: Cardinal read mApiVersion;
     property simulation: Boolean read IsSimulation;
     function apiVersionStr(): string;
     class function apiVersionComparable(version: Cardinal): Cardinal;

  end;


implementation

////////////////////////////////////////////////////////////////////////////////

function GetLastOsError(_ErrCode: integer; out _Error: string; const _Format: string = ''): DWORD; overload;
var
  s: string;
begin
  Result := _ErrCode;
  if Result <> ERROR_SUCCESS then
    s := SysErrorMessage(Result)
  else
    s := ('unknown OS error');
  if _Format <> '' then
    try
      _Error := Format(_Format, [Result, s])
    except
      _Error := s;
    end else
    _Error := s;
end;

function GetLastOsError(out _Error: string; const _Format: string = ''): DWORD; overload;
begin
  Result := GetLastOsError(GetLastError, _Error, _Format);
end;

////////////////////////////////////////////////////////////////////////////////

constructor TRCSIFace.Create();
 begin
  inherited;
  Self.unbound := TList<string>.Create();
  Self.Reset();
 end;

destructor TRCSIFace.Destroy();
 begin
  if (Self.dllHandle <> 0) then Self.UnloadLib();
  Self.unbound.Free();
  inherited;
 end;

////////////////////////////////////////////////////////////////////////////////

procedure TRCSIFace.Reset();
 begin
  Self.dllHandle := 0;
  Self.mApiVersion := _RCS_API_SUPPORTED_VERSIONS[High(_RCS_API_SUPPORTED_VERSIONS)];

  dllFuncLoadConfig := nil;
  dllFuncSaveConfig := nil;

  // logging
  dllFuncSetLogLevel := nil;
  dllFuncGetLogLevel := nil;

  // dialogs
  dllFuncShowConfigDialog := nil;
  dllFuncHideConfigDialog := nil;

  // open/close
  dllFuncOpen := nil;
  dllFuncClose := nil;
  dllFuncOpened := nil;

  // start/stop
  dllFuncStart := nil;
  dllFuncStop := nil;
  dllFuncStarted := nil;

  // ports IO
  dllFuncGetInput := nil;
  dllFuncGetOutput := nil;
  dllFuncSetOutput := nil;
  dllFuncSetInput := nil;
  dllFuncGetInputType := nil;
  dllFuncGetOutputType := nil;

  // modules
  dllFuncIsModule := nil;
  dllFuncIsModuleFailure := nil;
  dllFuncIsModuleError := nil;
  dllFuncIsModuleWarning := nil;
  dllFuncGetModuleCount := nil;
  dllFuncGetMaxModuleAddr := nil;
  dllFuncGetModuleType := nil;
  dllFuncGetModuleTypeStr := nil;
  dllFuncGetModuleName := nil;
  dllFuncGetModuleFW := nil;

  // versions
  dllFuncGetDeviceVersion := nil;
  dllFuncGetVersion := nil;
  dllFuncApiSupportsVersion := nil;
  dllFuncApiSetVersion := nil;

  // simulation
  dllFuncIsSimulation := nil;
 end;

////////////////////////////////////////////////////////////////////////////////
// Events from dll library, these evetns must be declared as functions
// (not as functions of objects)

procedure dllBeforeOpen(Sender: TObject; data: Pointer); stdcall;
 begin
  try
    if (Assigned(TRCSIFace(data).BeforeOpen)) then TRCSIFace(data).BeforeOpen(TRCSIFace(data));
  except

  end;
 end;

procedure dllAfterOpen(Sender: TObject; data: Pointer); stdcall;
 begin
  try
    if (Assigned(TRCSIFace(data).AfterOpen)) then TRCSIFace(data).AfterOpen(TRCSIFace(data));
  except

  end;
 end;

procedure dllBeforeClose(Sender: TObject; data: Pointer); stdcall;
 begin
  try
    if (Assigned(TRCSIFace(data).BeforeClose)) then TRCSIFace(data).BeforeClose(TRCSIFace(data));
  except

  end;
 end;

procedure dllAfterClose(Sender: TObject; data: Pointer); stdcall;
 begin
  try
    if (Assigned(TRCSIFace(data).AfterClose)) then TRCSIFace(data).AfterClose(TRCSIFace(data));
  except

  end;
 end;

procedure dllBeforeStart(Sender: TObject; data: Pointer); stdcall;
 begin
  try
    if (Assigned(TRCSIFace(data).BeforeStart)) then TRCSIFace(data).BeforeStart(TRCSIFace(data));
  except

  end;
 end;

procedure dllAfterStart(Sender: TObject; data: Pointer); stdcall;
 begin
  try
    if (Assigned(TRCSIFace(data).AfterStart)) then TRCSIFace(data).AfterStart(TRCSIFace(data));
  except

  end;
 end;

procedure dllBeforeStop(Sender: TObject; data: Pointer); stdcall;
 begin
  try
    if (Assigned(TRCSIFace(data).BeforeStop)) then TRCSIFace(data).BeforeStop(TRCSIFace(data));
  except

  end;
 end;

procedure dllAfterStop(Sender: TObject; data: Pointer); stdcall;
 begin
  try
    if (Assigned(TRCSIFace(data).AfterStop)) then TRCSIFace(data).AfterStop(TRCSIFace(data));
  except

  end;
 end;

procedure dllOnError(Sender: TObject; data: Pointer; errValue: word; errAddr: Cardinal; errMsg: PChar); stdcall;
 begin
  try
    if (Assigned(TRCSIFace(data).OnError)) then TRCSIFace(data).OnError(TRCSIFace(data), errValue, errAddr, errMsg);
  except

  end;
 end;

procedure dllOnLog(Sender: TObject; data: Pointer; logLevel: Integer; msg: PChar); stdcall;
 begin
  try
    if (Assigned(TRCSIFace(data).OnLog)) then TRCSIFace(data).OnLog(TRCSIFace(data), TRCSLogLevel(logLevel), msg);
  except

  end;
 end;

procedure dllOnModuleChanged(Sender: TObject; data: Pointer; module: Cardinal); stdcall;
 begin
  try
    if (Assigned(TRCSIFace(data).OnModuleChanged)) then TRCSIFace(data).OnModuleChanged(TRCSIFace(data), module);
  except

  end;
 end;

procedure dllOnInputChanged(Sender: TObject; data: Pointer; module: Cardinal); stdcall;
 begin
  try
    if (Assigned(TRCSIFace(data).OnInputChanged)) then TRCSIFace(data).OnInputChanged(TRCSIFace(data), module);
    if (TRCSIFace.apiVersionComparable(TRCSIFace(data).apiVersion) < $0105) then
      if (Assigned(TRCSIFace(data).OnModuleChanged)) then TRCSIFace(data).OnModuleChanged(TRCSIFace(data), module);
  except

  end;
 end;

procedure dllOnOutputChanged(Sender: TObject; data: Pointer; module: Cardinal); stdcall;
 begin
  try
    if (Assigned(TRCSIFace(data).OnOutputChanged)) then TRCSIFace(data).OnOutputChanged(TRCSIFace(data), module);
    if (TRCSIFace.apiVersionComparable(TRCSIFace(data).apiVersion) < $0105) then
      if (Assigned(TRCSIFace(data).OnModuleChanged)) then TRCSIFace(data).OnModuleChanged(TRCSIFace(data), module);
  except

  end;
 end;

procedure dllOnScanned(Sender: TObject; data: Pointer); stdcall;
 begin
  try
    if (Assigned(TRCSIFace(data).OnScanned)) then TRCSIFace(data).OnScanned(TRCSIFace(data));
  except

  end;
 end;

////////////////////////////////////////////////////////////////////////////////
// Load dll library

procedure TRCSIFace.LoadLib(path: string; configFn: string);
var dllFuncStdNotifyBind: TDllStdNotifyBind;
    dllFuncOnErrorBind: TDllStdErrorBind;
    dllFuncOnLogBind: TDllStdLogBind;
    dllFuncOnChangedBind: TDllStdModuleChangeBind;
    errorCode: dword;
    errorStr: string;
 begin
  Self.unbound.Clear();

  if (dllHandle <> 0) then Self.UnloadLib();

  dllName := path;
  dllHandle := LoadLibrary(PChar(dllName));
  if (dllHandle = 0) then
   begin
    errorCode := GetLastOsError(errorStr);
    raise ERCSCannotLoadLib.Create('Cannot load library: error '+IntToStr(errorCode)+': '+errorStr+'!');
   end;

  // library API version
  dllFuncApiSupportsVersion := TDllApiVersionAsker(GetProcAddress(dllHandle, 'ApiSupportsVersion'));
  dllFuncApiSetVersion := TDllApiVersionSetter(GetProcAddress(dllHandle, 'ApiSetVersion'));
  if ((not Assigned(dllFuncApiSupportsVersion)) or (not Assigned(dllFuncApiSetVersion))) then
   begin
    Self.mApiVersion := $0201; // default v1.2
    if (not Self.IsApiVersionSupport(Self.mApiVersion)) then
     begin
      Self.UnloadLib();
      raise ERCSUnsupportedApiVersion.Create('Unsupported library version: v1.2');
     end;
   end else begin
    try
      Self.PickApiVersion(); // will pick right version or raise exception
    except
      Self.UnloadLib();
      raise;
    end;
   end;

  // one of te supported versions picked here

  // config file load/save
  dllFuncLoadConfig := TDllFileIO(GetProcAddress(dllHandle, 'LoadConfig'));
  if (not Assigned(dllFuncLoadConfig)) then unbound.Add('LoadConfig');
  dllFuncSaveConfig := TDllFileIO(GetProcAddress(dllHandle, 'SaveConfig'));
  if (not Assigned(dllFuncSaveConfig)) then unbound.Add('SaveConfig');
  dllFuncSetConfigFileName := TDllFileIOProc(GetProcAddress(dllHandle, 'SetConfigFileName'));

  // logging
  dllFuncSetLogLevel := TDllSetLogLevel(GetProcAddress(dllHandle, 'SetLogLevel'));
  if (not Assigned(dllFuncSetLogLevel)) then unbound.Add('SetLogLevel');
  dllFuncGetLogLevel := TDllGetLogLevel(GetProcAddress(dllHandle, 'GetLogLevel'));
  if (not Assigned(dllFuncGetLogLevel)) then unbound.Add('GetLogLevel');

  // dialogs
  dllFuncShowConfigDialog := TDllPGeneral(GetProcAddress(dllHandle, 'ShowConfigDialog'));
  dllFuncHideConfigDialog := TDllPGeneral(GetProcAddress(dllHandle, 'HideConfigDialog'));

  // open/close
  dllFuncOpen := TDllFGeneral(GetProcAddress(dllHandle, 'Open'));
  if (not Assigned(dllFuncOpen)) then unbound.Add('Open');
  dllFuncClose := TDllFGeneral(GetProcAddress(dllHandle, 'Close'));
  if (not Assigned(dllFuncClose)) then unbound.Add('Close');
  dllFuncOpened := TDllBoolGetter(GetProcAddress(dllHandle, 'Opened'));
  if (not Assigned(dllFuncOpened)) then unbound.Add('Opened');

  // start/stop
  dllFuncStart := TDllFGeneral(GetProcAddress(dllHandle, 'Start'));
  if (not Assigned(dllFuncStart)) then unbound.Add('Start');
  dllFuncStop := TDllFGeneral(GetProcAddress(dllHandle, 'Stop'));
  if (not Assigned(dllFuncStop)) then unbound.Add('Stop');
  dllFuncStarted := TDllBoolGetter(GetProcAddress(dllHandle, 'Started'));
  if (not Assigned(dllFuncStarted)) then unbound.Add('Started');

  // ports IO
  dllFuncGetInput := TDllModuleGet(GetProcAddress(dllHandle, 'GetInput'));
  if (not Assigned(dllFuncGetInput)) then unbound.Add('GetInput');
  dllFuncGetOutput := TDllModuleGet(GetProcAddress(dllHandle, 'GetOutput'));
  if (not Assigned(dllFuncGetOutput)) then unbound.Add('GetOutput');
  dllFuncSetOutput := TDllModuleSet(GetProcAddress(dllHandle, 'SetOutput'));
  if (not Assigned(dllFuncSetOutput)) then unbound.Add('SetOutputf');

  dllFuncSetInput := TDllModuleSet(GetProcAddress(dllHandle, 'SetInput'));

  dllFuncGetInputType := TDllModuleGet(GetProcAddress(dllHandle, 'GetInputType'));
  if (not Assigned(dllFuncGetInputType)) then unbound.Add('GetInputType');
  dllFuncGetOutputType := TDllModuleGet(GetProcAddress(dllHandle, 'GetOutputType'));
  if (not Assigned(dllFuncGetOutputType)) then unbound.Add('GetOutputType');

  // modules
  dllFuncIsModule := TDllModuleBoolGetter(GetProcAddress(dllHandle, 'IsModule'));
  if (not Assigned(dllFuncIsModule)) then unbound.Add('IsModule');
  dllFuncIsModuleFailure := TDllModuleBoolGetter(GetProcAddress(dllHandle, 'IsModuleFailure'));
  if (not Assigned(dllFuncIsModuleFailure)) then unbound.Add('IsModuleFailure');
  dllFuncIsModuleError := TDllModuleBoolGetter(GetProcAddress(dllHandle, 'IsModuleError'));
  if ((not Assigned(dllFuncIsModuleError)) and (apiVersionComparable(Self.mApiVersion) >= $0105)) then
    unbound.Add('IsModuleError');
  dllFuncIsModuleWarning := TDllModuleBoolGetter(GetProcAddress(dllHandle, 'IsModuleWarning'));
  if ((not Assigned(dllFuncIsModuleWarning)) and (apiVersionComparable(Self.mApiVersion) >= $0105)) then
    unbound.Add('IsModuleWarning');
  dllFuncGetModuleCount := TDllFCardGeneral(GetProcAddress(dllHandle, 'GetModuleCount'));
  if (not Assigned(dllFuncGetModuleCount)) then unbound.Add('GetModuleCount');
  dllFuncGetMaxModuleAddr := TDllFCardGeneral(GetProcAddress(dllHandle, 'GetMaxModuleAddr'));
  if (not Assigned(dllFuncGetMaxModuleAddr)) then unbound.Add('GetMaxModuleAddr');

  dllFuncGetModuleTypeStr := TDllModuleStringGetter(GetProcAddress(dllHandle, 'GetModuleTypeStr'));
  if (not Assigned(dllFuncGetModuleTypeStr)) then
   begin
    dllFuncGetModuleType := TDllModuleIntGetter(GetProcAddress(dllHandle, 'GetModuleType'));
    if (not Assigned(dllFuncGetModuleType)) then unbound.Add('GetModuleTypeStr');
   end;

  dllFuncGetModuleName := TDllModuleStringGetter(GetProcAddress(dllHandle, 'GetModuleName'));
  if (not Assigned(dllFuncGetModuleName)) then unbound.Add('GetModuleName');
  dllFuncGetModuleFW := TDllModuleStringGetter(GetProcAddress(dllHandle, 'GetModuleFW'));
  if (not Assigned(dllFuncGetModuleFW)) then unbound.Add('GetModuleFW');

  // these 2 function are not neccesarry, so we do not check bindings
  dllFuncGetModuleInputsCount := TDllModuleCardGetter(GetProcAddress(dllHandle, 'GetModuleInputsCount'));
  dllFuncGetModuleOutputsCount := TDllModuleCardGetter(GetProcAddress(dllHandle, 'GetModuleOutputsCount'));

  // versions
  dllFuncGetDeviceVersion := TDllDeviceVersionGetter(GetProcAddress(dllHandle, 'GetDeviceVersion'));
  if (not Assigned(dllFuncGetDeviceVersion)) then unbound.Add('GetDeviceVersion');
  dllFuncGetVersion := TDllVersionGetter(GetProcAddress(dllHandle, 'GetDriverVersion'));
  if (not Assigned(dllFuncGetVersion)) then unbound.Add('GetDriverVersion');

  // events open/close
  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindBeforeOpen'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllBeforeOpen, self)
  else unbound.Add('BindBeforeOpen');

  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindAfterOpen'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllAfterOpen, self)
  else unbound.Add('BindAfterOpen');

  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindBeforeClose'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllBeforeClose, self)
  else unbound.Add('BindBeforeClose');

  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindAfterClose'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllAfterClose, self)
  else unbound.Add('BindAfterClose');

  // events start/stop
  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindBeforeStart'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllBeforeStart, self)
  else unbound.Add('BindBeforeStart');

  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindAfterStart'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllAfterStart, self)
  else unbound.Add('BindAfterStart');

  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindBeforeStop'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllBeforeStop, self)
  else unbound.Add('BindBeforeStop');

  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindAfterStop'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllAfterStop, self)
  else unbound.Add('BindAfterStop');

  // other events
  dllFuncOnErrorBind := TDllStdErrorBind(GetProcAddress(dllHandle, 'BindOnError'));
  if (Assigned(dllFuncOnErrorBind)) then dllFuncOnErrorBind(@dllOnError, self)
  else unbound.Add('BindOnError');

  dllFuncOnLogBind := TDllStdLogBind(GetProcAddress(dllHandle, 'BindOnLog'));
  if (Assigned(dllFuncOnLogBind)) then dllFuncOnLogBind(@dllOnLog, self)
  else unbound.Add('BindOnLog');

  dllFuncOnChangedBind := TDllStdModuleChangeBind(GetProcAddress(dllHandle, 'BindOnModuleChanged'));
  if (apiVersionComparable(Self.mApiVersion) >= $0105) then
  begin
    if (Assigned(dllFuncOnChangedBind)) then
      dllFuncOnChangedBind(@dllOnModuleChanged, self)
    else unbound.Add('BindOnModuleChanged');
  end;

  dllFuncOnChangedBind := TDllStdModuleChangeBind(GetProcAddress(dllHandle, 'BindOnInputChanged'));
  if (Assigned(dllFuncOnChangedBind)) then dllFuncOnChangedBind(@dllOnInputChanged, self)
  else unbound.Add('BindOnInputChanged');

  dllFuncOnChangedBind := TDllStdModuleChangeBind(GetProcAddress(dllHandle, 'BindOnOutputChanged'));
  if (Assigned(dllFuncOnChangedBind)) then dllFuncOnChangedBind(@dllOnOutputChanged, self)
  else unbound.Add('BindOnOutputChanged');

  dllFuncStdNotifyBind := TDllStdNotifyBind(GetProcAddress(dllHandle, 'BindOnScanned'));
  if (Assigned(dllFuncStdNotifyBind)) then dllFuncStdNotifyBind(@dllOnScanned, self)
  else unbound.Add('BindOnScanned');

  // features

  dllFuncIsSimulation := TDllBoolGetter(GetProcAddress(dllHandle, 'IsSimulation'));

  if (Assigned(dllFuncLoadConfig)) then
    Self.LoadConfig(configFn);
 end;

procedure TRCSIFace.UnloadLib();
 begin
  if (Self.dllHandle = 0) then
    raise ERCSNoLibLoaded.Create('No library loaded, cannot unload!');

  FreeLibrary(Self.dllHandle);
  Self.Reset();
 end;

////////////////////////////////////////////////////////////////////////////////
// Parent should call these methods:
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// file I/O

procedure TRCSIFace.LoadConfig(fn: string);
var res: Integer;
 begin
  if (not Assigned(dllFuncLoadConfig)) then
    raise ERCSFuncNotAssigned.Create('FFuncLoadConfig not assigned');

  res := dllFuncLoadConfig(PChar(fn));

  if (res = RCS_FILE_CANNOT_ACCESS) then
    raise ERCSCannotAccessFile.Create('Cannot read file '+fn+'!')
  else if (res = RCS_FILE_DEVICE_OPENED) then
    raise ERCSDeviceOpened.Create('Cannot reload config, device opened!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
 end;

procedure TRCSIFace.SaveConfig(fn: string);
var res: Integer;
 begin
  if (not Assigned(dllFuncSaveConfig)) then
    raise ERCSFuncNotAssigned.Create('FFuncSaveConfig not assigned');

  res := dllFuncSaveConfig(PChar(fn));

  if (res = RCS_FILE_CANNOT_ACCESS) then
    raise ERCSCannotAccessFile.Create('Cannot write to file '+fn+'!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
 end;

procedure TRCSIFace.SetConfigFileName(fn: string);
 begin
  if (not Assigned(dllFuncSetConfigFileName)) then
    raise ERCSFuncNotAssigned.Create('FFuncSetConfigFileName not assigned');
  dllFuncSetConfigFileName(PChar(fn));
end;

////////////////////////////////////////////////////////////////////////////////
// logging

procedure TRCSIFace.SetLogLevel(loglevel: TRCSLogLevel);
 begin
  if (not Assigned(dllFuncSetLogLevel)) then
    raise ERCSFuncNotAssigned.Create('FFuncSetLogLevel not assigned');
  dllFuncSetLogLevel(Cardinal(loglevel));
 end;

function TRCSIFace.GetLogLevel(): TRCSLogLevel;
 begin
  if (not Assigned(dllFuncGetLogLevel)) then
    raise ERCSFuncNotAssigned.Create('FFuncGetLogLevel not assigned');
  Result := TRCSLogLevel(dllFuncGetLogLevel());
 end;

class function TRCSIFace.LogLevelToString(ll: TRCSLogLevel): string;
begin
 case (ll) of
   llNo: Result := 'No';
   llErrors: Result := 'Err';
   llWarnings: Result := 'Warn';
   llInfo: Result := 'Info';
   llCommands: Result := 'Cmd';
   llRawCommands: Result := 'Raw';
   llDebug: Result := 'Debug';
 else
   Result := '?';
 end;
end;

////////////////////////////////////////////////////////////////////////////////
// dialogs:

procedure TRCSIFace.ShowConfigDialog();
 begin
  if (Assigned(dllFuncShowConfigDialog)) then
    dllFuncShowConfigDialog()
  else
    raise ERCSFuncNotAssigned.Create('FFuncShowConfigDialog not assigned');
 end;

procedure TRCSIFace.HideConfigDialog();
 begin
  if (Assigned(dllFuncHideConfigDialog)) then
    dllFuncHideConfigDialog()
  else
    raise ERCSFuncNotAssigned.Create('FFuncHideConfigDialog not assigned');
 end;

function TRCSIFace.HasDialog(): Boolean;
begin
 Result := Assigned(Self.dllFuncShowConfigDialog);
end;

////////////////////////////////////////////////////////////////////////////////
// open/close:

procedure TRCSIFace.Open();
var res: Integer;
 begin
  if (not Assigned(dllFuncOpen)) then
    raise ERCSFuncNotAssigned.Create('FFuncOpen not assigned');

  res := dllFuncOpen();

  if (res = RCS_ALREADY_OPENNED) then
    raise ERCSAlreadyOpened.Create('Device already opened!')
  else if (res = RCS_CANNOT_OPEN_PORT) then
    raise ERCSCannotOpenPort.Create('Cannot open this port!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
 end;

procedure TRCSIFace.Close();
var res: Integer;
 begin
  if (not Assigned(dllFuncClose)) then
    raise ERCSFuncNotAssigned.Create('FFuncClose not assigned');

  res := dllFuncClose();

  if (res = RCS_NOT_OPENED) then
    raise ERCSNotOpened.Create('Device not opened!')
  else if (res = RCS_SCANNING_NOT_FINISHED) then
    raise ERCSScanningNotFinished.Create('Initial scanning of modules not finished, cannot close!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
 end;

function TRCSIFace.Opened(): Boolean;
 begin
  if (not Assigned(dllFuncOpened)) then
    raise ERCSFuncNotAssigned.Create('FFuncOpened not assigned')
  else
    Result := dllFuncOpened();
 end;

////////////////////////////////////////////////////////////////////////////////
// start/stop:

procedure TRCSIFace.Start();
var res: Integer;
begin
  if (not Assigned(dllFuncStart)) then
    raise ERCSFuncNotAssigned.Create('FFuncStart not assigned');

  res := dllFuncStart();

  if (res = RCS_ALREADY_STARTED) then
    raise ERCSAlreadyStarted.Create('Communication already started!')
  else if (res = RCS_FIRMWARE_TOO_LOW) then
    raise ERCSFirmwareTooLow.Create('RCS-PC module firware too low!')
  else if (res = RCS_NO_MODULES) then
    raise ERCSNoModules.Create('No modules found, cannot start!')
  else if (res = RCS_NOT_OPENED) then
    raise ERCSNotOpened.Create('Device not opened, cannot start!')
  else if (res = RCS_SCANNING_NOT_FINISHED) then
    raise ERCSScanningNotFinished.Create('Initial scanning of modules not finished, cannot start!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
end;

procedure TRCSIFace.Stop();
var res: Integer;
begin
  if (not Assigned(dllFuncStop)) then
    raise ERCSFuncNotAssigned.Create('FFuncStop not assigned');

  res := dllFuncStop();

  if (res = RCS_NOT_STARTED) then
    raise ERCSNotStarted.Create('Device not started, cannot stop!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
end;

function TRCSIFace.Started(): Boolean;
begin
  if (not Assigned(dllFuncStarted)) then
    raise ERCSFuncNotAssigned.Create('FFuncStarted not assigned')
  else
    Result := dllFuncStarted();
end;

////////////////////////////////////////////////////////////////////////////////
// module I/O:

function TRCSIFace.GetInput(module, port: Cardinal): TRCSInputState;
var tmp: Integer;
 begin
  if (not Assigned(dllFuncGetInput)) then
    raise ERCSFuncNotAssigned.Create('FFuncGetInput not assigned');

  tmp := dllFuncGetInput(module, port);

  if (tmp = RCS_NOT_STARTED) then
    raise ERCSNotStarted.Create('Railroad Control System not started!')
  else if (tmp = RCS_GENERAL_EXCEPTION) then
    raise ERCSGeneralException.Create('General exception in RCS library!')
  else if (tmp = RCS_MODULE_DEPRECATED_FAILED) then
    tmp := RCS_MODULE_FAILED;

  Result := TRCSInputState(tmp);
 end;

procedure TRCSIFace.SetOutput(module, port: Cardinal; state: Integer);
var res: Integer;
 begin
  if (not Assigned(dllFuncSetOutput)) then
    raise ERCSFuncNotAssigned.Create('FFuncSetOutput not assigned');

  res := dllFuncSetOutput(module, port, state);

  if (res = RCS_NOT_STARTED) then
    raise ERCSNotStarted.Create('Railroad Control System not started!')
  else if (res = RCS_MODULE_INVALID_ADDR) then
    raise ERCSModuleNotAvailable.Create('Module '+IntToStr(module)+' not available on bus!')
  else if ((res = RCS_MODULE_FAILED) or (res = RCS_MODULE_DEPRECATED_FAILED)) then
    raise ERCSModuleFailed.Create('Module '+IntToStr(module)+' failed!')
  else if (res = RCS_PORT_INVALID_NUMBER) then
    raise ERCSInvalidModulePort.Create('Invalid port number!')
  else if (res = RCS_PORT_INVALID_VALUE) then
    raise ERCSInvalidScomCode.Create('Invalid port value : '+IntToStr(state)+'!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
 end;

procedure TRCSIFace.SetOutput(module, port: Cardinal; state: TRCSOutputState);
begin
  Self.SetOutput(module, port, Integer(state));
end;

procedure TRCSIFace.SetInput(module, port: Cardinal; state: Integer);
var res: Integer;
 begin
  if (not Assigned(dllFuncSetInput)) then
    raise ERCSFuncNotAssigned.Create('FFuncSetInput not assigned');

  res := dllFuncSetInput(module, port, state);

  if (res = RCS_MODULE_INVALID_ADDR) then
    raise ERCSModuleNotAvailable.Create('Module '+IntToStr(module)+' not available on bus!')
  else if ((res = RCS_MODULE_FAILED) or (res = RCS_MODULE_DEPRECATED_FAILED)) then
    raise ERCSModuleFailed.Create('Module '+IntToStr(module)+' failed!')
  else if (res = RCS_PORT_INVALID_NUMBER) then
    raise ERCSInvalidModulePort.Create('Invalid port number!')
  else if (res = RCS_PORT_INVALID_VALUE) then
    raise ERCSInvalidScomCode.Create('Invalid port value : '+IntToStr(state)+'!')
  else if (res <> 0) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
 end;

function TRCSIFace.GetOutput(module, port: Cardinal): Integer;
 begin
  if (not Assigned(dllFuncGetOutput)) then
    raise ERCSFuncNotAssigned.Create('FFuncGetOutput not assigned');

  Result := dllFuncGetOutput(module, port);

  if (Result = RCS_NOT_STARTED) then
    raise ERCSNotStarted.Create('Railroad Control System not started!')
  else if (Result = RCS_GENERAL_EXCEPTION) then
    raise ERCSGeneralException.Create('General exception in RCS library!');
 end;

function TRCSIFace.GetOutputState(module, port: Cardinal): TRCSOutputState;
begin
  Result := TRCSOutputState(Self.GetOutput(module, port));
end;

function TRCSIFace.GetInputType(module, port: Cardinal): TRCSIPortType;
var res: Integer;
 begin
  if (not Assigned(dllFuncGetInputType)) then
    Exit(TRCSIPortType.iptPlain); // Backward compatibility

  res := dllFuncGetInputType(module, port);

  if (res = RCS_MODULE_INVALID_ADDR) then
    raise ERCSModuleNotAvailable.Create('Module '+IntToStr(module)+' not available on bus!')
  else if (res = RCS_PORT_INVALID_NUMBER) then
    raise ERCSInvalidModulePort.Create('Invalid port number!');

  Result := TRCSIPortType(res);
 end;

function TRCSIFace.GetOutputType(module, port: Cardinal): TRCSOPortType;
var res: Integer;
 begin
  if (not Assigned(dllFuncGetOutputType)) then
    Exit(TRCSOPortType.optPlain); // Backward compatibility

  res := dllFuncGetOutputType(module, port);

  if (res = RCS_MODULE_INVALID_ADDR) then
    raise ERCSModuleNotAvailable.Create('Module '+IntToStr(module)+' not available on bus!')
  else if (res = RCS_PORT_INVALID_NUMBER) then
    raise ERCSInvalidModulePort.Create('Invalid port number!');

  Result := TRCSOPortType(res);
 end;

////////////////////////////////////////////////////////////////////////////////
// modules:

function TRCSIFace.IsModule(Module: Cardinal): Boolean;
 begin
  if (Assigned(dllFuncIsModule)) then
    Result := dllFuncIsModule(Module)
  else
    raise ERCSFuncNotAssigned.Create('FFuncModuleExists not assigned');
 end;

function TRCSIFace.IsModuleFailure(module: Cardinal): Boolean;
 begin
  if (Assigned(dllFuncIsModuleFailure)) then
    Result := dllFuncIsModuleFailure(Module)
  else
    raise ERCSFuncNotAssigned.Create('FFuncIsModuleFailure not assigned');
 end;

function TRCSIFace.IsModuleError(module: Cardinal): Boolean;
begin
  if (Assigned(dllFuncIsModuleError)) then
    Result := dllFuncIsModuleError(Module)
  else
    Result := false; // not implemented in older API (<= 1.4)
end;

function TRCSIFace.IsModuleWarning(module: Cardinal): Boolean;
begin
  if (Assigned(dllFuncIsModuleWarning)) then
    Result := dllFuncIsModuleWarning(Module)
  else
    Result := false; // not implemented in older API (<= 1.4)
end;

function TRCSIFace.IsNonFailedModule(module: Cardinal): Boolean;
 begin
  Result := ((Self.IsModule(module)) and (not Self.IsModuleFailure(module)));
 end;

function TRCSIFace.GetModuleCount(): Cardinal;
 begin
  if (Assigned(dllFuncGetModuleCount)) then
    Result := dllFuncGetModuleCount()
  else
    raise ERCSFuncNotAssigned.Create('FFuncGetModuleCount not assigned');
 end;

function TRCSIFace.GetMaxModuleAddr(): Cardinal;
 begin
  if (Assigned(dllFuncGetMaxModuleAddr)) then
    Result := dllFuncGetMaxModuleAddr()
  else
    raise ERCSFuncNotAssigned.Create('FFuncGetMaxModuleAddr not assigned');
 end;

function TRCSIFace.GetModuleType(Module: Cardinal): string;
const STR_LEN: Integer = 32;
var str: PWideChar;
    res: Integer;
 begin
  if (not Assigned(dllFuncGetModuleTypeStr) and (not Assigned(dllFuncGetModuleType))) then
    raise ERCSFuncNotAssigned.Create('FFuncGetModuleTypeStr not assigned');

  if (Assigned(dllFuncGetModuleTypeStr)) then
   begin
    GetMem(str, SizeOf(WideChar)*(STR_LEN+1));
    try
      res := dllFuncGetModuleTypeStr(Module, str, STR_LEN);

      if (res = RCS_MODULE_INVALID_ADDR) then
        raise ERCSInvalidModuleAddr.Create('Invalid module address : '+IntToStr(Module)+'!');

      Result := string(str);
    finally
      FreeMem(str);
    end;
   end else begin
    // Leep backward compatibility with libraries, which do not support
    // GetModuleTypeStr function.

    res := dllFuncGetModuleType(Module);

    case (res) of
      _RCS_MOD_MTB_UNI_ID: Result := 'MTB-UNI';
      _RCS_MOD_MTB_UNIOUT_ID: Result := 'MTB-UNIo';
      _RCS_MOD_MTB_TTL_ID: Result := 'MTB-TTL';
      _RCS_MOD_MTB_TTLOUT_ID: Result := 'MTB-TTLo';

      RCS_MODULE_INVALID_ADDR: raise ERCSInvalidModuleAddr.Create('Invalid module address : '+IntToStr(Module)+'!');
    end;
   end;
 end;

function TRCSIFace.GetModuleName(Module: Cardinal): string;
const STR_LEN: Integer = 128;
var str: PWideChar;
    res: Integer;
 begin
  GetMem(str, SizeOf(WideChar)*(STR_LEN+1));
  try
    if (not Assigned(dllFuncGetModuleName)) then
      raise ERCSFuncNotAssigned.Create('FFuncGetModuleName not assigned');

    res := dllFuncGetModuleName(Module, str, STR_LEN);

    if (res = RCS_MODULE_INVALID_ADDR) then
      raise ERCSInvalidModuleAddr.Create('Invalid module address : '+IntToStr(Module)+'!');
    Result := string(str);
  finally
    FreeMem(str);
  end;
 end;

function TRCSIFace.GetModuleFW(Module: Cardinal): string;
const STR_LEN: Integer = 16;
var str: PWideChar;
    res: Integer;
 begin
  if (not Assigned(dllFuncGetModuleFW)) then
    raise ERCSFuncNotAssigned.Create('FFuncGetModuleFirmware not assigned');

  GetMem(str, SizeOf(WideChar)*(STR_LEN+1));
  try
    res := dllFuncGetModuleFW(Module, str, STR_LEN);

    if (res = RCS_MODULE_INVALID_ADDR) then
      raise ERCSInvalidModuleAddr.Create('Invalid module adderess: '+IntToStr(Module)+'!')
    else if (res <> 0) then
      raise ERCSGeneralException.Create('General exception in RCS library!');

    Result := string(str);
  finally
    FreeMem(str);
  end;
 end;

function TRCSIFace.GetModuleInputsCount(Module: Cardinal): Cardinal;
 begin
  if (not Assigned(dllFuncGetModuleInputsCount)) then
    Exit(16);

  Result := dllFuncGetModuleInputsCount(Module);

  if (Result = RCS_MODULE_INVALID_ADDR) then
    raise ERCSInvalidModuleAddr.Create('Invalid module adderess: '+IntToStr(Module)+'!');
 end;

function TRCSIFace.GetModuleOutputsCount(Module: Cardinal): Cardinal;
 begin
  if (not Assigned(dllFuncGetModuleOutputsCount)) then
    Exit(16);

  Result := dllFuncGetModuleOutputsCount(Module);

  if (Result = RCS_MODULE_INVALID_ADDR) then
    raise ERCSInvalidModuleAddr.Create('Invalid module adderess: '+IntToStr(Module)+'!');
 end;

////////////////////////////////////////////////////////////////////////////////
// versions:

function TRCSIFace.GetDeviceVersion(): string;
const STR_LEN: Integer = 32;
var str: PWideChar;
    res: Integer;
 begin
  if (not Assigned(dllFuncGetDeviceVersion)) then
    raise ERCSFuncNotAssigned.Create('FFuncGetLibVersion not assigned');

  GetMem(str, SizeOf(WideChar)*(STR_LEN+1));
  try
    res := dllFuncGetDeviceVersion(str, STR_LEN);

    if (res = RCS_DEVICE_DISCONNECTED) then
      raise ERCSNotOpened.Create('Device not opened, cannot read version!');

    Result := string(str);
  finally
    FreeMem(str);
  end;
 end;

function TRCSIFace.GetDllVersion(): String;
const STR_LEN: Integer = 32;
var str: PWideChar;
 begin
  if (not Assigned(dllFuncGetVersion)) then
    raise ERCSFuncNotAssigned.Create('FFuncGetDriverVersion not assigned');

  GetMem(str, SizeOf(WideChar)*(STR_LEN+1));
  try
    dllFuncGetVersion(str, STR_LEN);
    Result := string(str);
  finally
    FreeMem(str);
  end;
 end;

////////////////////////////////////////////////////////////////////////////////

class function TRCSIFace.IsApiVersionSupport(version: Cardinal): Boolean;
var i: Integer;
begin
 for i := Low(_RCS_API_SUPPORTED_VERSIONS) to High(_RCS_API_SUPPORTED_VERSIONS) do
   if (_RCS_API_SUPPORTED_VERSIONS[i] = version) then
     Exit(true);
 Result := false;
end;

////////////////////////////////////////////////////////////////////////////////

procedure TRCSIFace.PickApiVersion();
begin
 for var i := High(_RCS_API_SUPPORTED_VERSIONS) downto Low(_RCS_API_SUPPORTED_VERSIONS) do
  begin
   if (Self.dllFuncApiSupportsVersion(_RCS_API_SUPPORTED_VERSIONS[i])) then
    begin
     Self.mApiVersion := _RCS_API_SUPPORTED_VERSIONS[i];
     if (Self.dllFuncApiSetVersion(Self.mApiVersion) <> 0) then
       raise ERCSCannotLoadLib.Create('ApiSetVersion returned nonzero result!');
     Exit();
    end;
  end;

 raise ERCSUnsupportedApiVersion.Create('Library does not support any of the supported versions');
end;

////////////////////////////////////////////////////////////////////////////////

function TRCSIFace.IsSimulation(): Boolean;
begin
 if ((Assigned(Self.dllFuncIsSimulation)) and (Assigned(Self.dllFuncSetInput))) then
   Result := Self.dllFuncIsSimulation()
 else
   Result := false;
end;

////////////////////////////////////////////////////////////////////////////////

function TRCSIFace.apiVersionStr(): string;
begin
 Result := IntToStr(Self.mApiVersion and $FF) + '.' + IntToStr((Self.mApiVersion shr 8) and $FF);
end;

class function TRCSIFace.apiVersionComparable(version: Cardinal): Cardinal;
begin
  // revert two lower bytes
  Result := ((version and $FF) shl 8) or ((version shr 8) and $FF);
end;

////////////////////////////////////////////////////////////////////////////////

end.//unit

