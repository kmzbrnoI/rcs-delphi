////////////////////////////////////////////////////////////////////////////////
// RCS.pas
// Interface to Railroad Control System (e.g. MTB, simulator, possibly DCC).
// (c) Jan Horacek, Michal Petrilak 2009-2017
// jan.horacek@kmz-brno.cz, engineercz@gmail.com
// license: Apache license v2.0
////////////////////////////////////////////////////////////////////////////////

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
  SysUtils, Classes, Windows, RCSErrors;

type
  ///////////////////////////////////////////////////////////////////////////
  // Events called from library to TRCSIFace:

  TStdNotifyEvent = procedure (Sender: TObject; data:Pointer); stdcall;
  TStdLogEvent = procedure (Sender: TObject; data:Pointer; logLevel:Integer; msg:PChar); stdcall;
  TStdErrorEvent = procedure (Sender: TObject; data:Pointer; errValue: word; errAddr: byte; errMsg:PChar); stdcall;
  TStdModuleChangeEvent = procedure (Sender: TObject; data:Pointer; module: byte); stdcall;

  ///////////////////////////////////////////////////////////////////////////
  // Events called from TRCSIFace to parent:

  TOnLogEvent = procedure (Sender: TObject; logLevel:Integer; msg:PChar) of object;
  TOnErrorEvent = procedure (Sender: TObject; errValue: word; errAddr: byte; errMsg:PChar) of object;
  TOnModuleChangeEvent = procedure (Sender: TObject; module: byte) of object;

  ///////////////////////////////////////////////////////////////////////////
  // Prototypes of functions called to library:

  TDllPGeneral = procedure(); stdcall;
  TDllFGeneral = function():Integer; stdcall;
  TDllFCardGeneral = function():Cardinal; stdcall;

  TDllFileIO = function(filename:PChar):Integer; stdcall;

  TDllSetLogLevel = procedure(loglevel:Cardinal); stdcall;
  TDllGetLogLevel = function(loglevel:Cardinal):Cardinal; stdcall;

  TDllOpenDevice = function(device:PChar; persist:boolean):Integer; stdcall;
  TDllBoolGetter = function():boolean; stdcall;
  TDllModuleGet = function(module, port:Cardinal):Integer; stdcall;
  TDllModuleSet = function(module, port:Cardinal; state:Integer):Integer; stdcall;
  TDllModuleBoolGetter = function(module:Cardinal):boolean; stdcall;
  TDllModuleIntGetter = function(module:Cardinal):Integer; stdcall;
  TDllModuleStringGetter = function(module:Cardinal; str:PChar; strMaxLen:Cardinal):Integer; stdcall;

  TDllDeviceSerialGetter = procedure(index:Integer; serial:PChar; serialLen:Cardinal); stdcall;
  TDllDeviceVersionGetter = function(version:PChar; versionMaxLen:Cardinal):Integer; stdcall;
  TDllVersionGetter = procedure(version:PChar; versionMaxLen:Cardinal); stdcall;

  TDllStdNotifyBind = procedure(event:TStdNotifyEvent; data:Pointer); stdcall;
  TDllStdLogBind = procedure(event:TStdLogEvent; data:Pointer); stdcall;
  TDllStdErrorBind = procedure(event:TStdErrorEvent; data:Pointer); stdcall;
  TDllStdModuleChangeBind = procedure(event:TStdModuleChangeEvent; data:Pointer); stdcall;

  ///////////////////////////////////////////////////////////////////////////

  // Custom exceptions: (TODO)
  EFuncNotAssigned = class(Exception);

  ///////////////////////////////////////////////////////////////////////////

  TRCSIFace = class
  private
    dllName: string;
    dllHandle: Cardinal;

    // ------------------------------------------------------------------
    // Functions called to library:

    // config file load/save
    dllFuncLoadConfig: TDllFileIO;
    dllFuncSaveConfig: TDllFileIO;

    // logging
    dllFuncSetLogLevelFile: TDllSetLogLevel;
    dllFuncSetLogLevel: TDllSetLogLevel;
    dllFuncGetLogLevel: TDllGetLogLevel;

    // dialogs
    dllFuncShowConfigDialog : TDllPGeneral;
    dllFuncHideConfigDialog : TDllPGeneral;

    // open/close
    dllFuncOpen : TDllFGeneral;
    dllFuncOpenDevice : TDllOpenDevice;
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

    // devices
    dllFuncGetDeviceCount : TDllFGeneral;
    dllFuncGetDeviceSerial : TDllDeviceSerialGetter;

    // modules
    dllFuncIsModule : TDllModuleBoolGetter;
    dllFuncIsModuleFailure: TDllModuleBoolGetter;
    dllFuncGetModuleCount : TDllFCardGeneral;
    dllFuncGetModuleType : TDllModuleIntGetter;
    dllFuncGetModuleName : TDllModuleStringGetter;
    dllFuncGetModuleFW : TDllModuleStringGetter;

    // versions
    dllFuncGetDeviceVersion : TDllDeviceVersionGetter;
    dllFuncGetVersion : TDllVersionGetter;

    // events open/close
    dllFuncBindBeforeOpen: TDllStdNotifyBind;
    dllFuncBindAfterOpen: TDllStdNotifyBind;
    dllFuncBindBeforeClose: TDllStdNotifyBind;
    dllFuncBindAfterClose: TDllStdNotifyBind;

    // events start/stop
    dllFuncBindBeforeStart: TDllStdNotifyBind;
    dllFuncBindAfterStart: TDllStdNotifyBind;
    dllFuncBindBeforeStop: TDllStdNotifyBind;
    dllFuncBindAfterStop: TDllStdNotifyBind;

    // other events
    dllFuncBindOnError : TDllStdErrorBind;
    dllFuncBindOnLog : TDllStdLogBind;
    dllFuncBindOnInputChanged : TStdModuleChangeEvent;
    dllFuncBindOnOutputChanged : TStdModuleChangeEvent;

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

    eOnError: TOnErrorEvent;
    eOnLog : TOnLogEvent;
    eOnInputChange : TOnModuleChangeEvent;
    eOnOutputChange : TOnModuleChangeEvent;

     procedure SetLibName(s: string);

  public

     procedure Open();                                                           // otevrit zarizeni
     procedure Close();                                                          // uzavrit zarizeni

     procedure Start();                                                          // spustit komunikaci
     procedure Stop();                                                           // zastavit komunikaci

     procedure SetOutput(Board, Output: Integer; state: Integer);                // nastavit vystupni port
     function GetInput(Board, Input: Integer): Integer;                          // vratit hodnotu na vstupnim portu
     procedure SetInput(Board, Input: Integer; State : integer);                 // nastavit vstupni port (pro debug ucely)
     function GetOutput(Board, Port:Integer):Integer;                            // ziskani stavu vystupu

     procedure ShowConfigDialog();                                               // zobrazit konfiguracni dialog knihovny
     procedure HideConfigDialog();                                               // skryt konfiguracni dialog knihovny
     procedure ShowAboutDialog();                                                // zobrazit about dialog knihvny

     function GetLibVersion():string;                                            // vrati verzi knihovny
     function GetDeviceVersion():string;                                         // vrati verzi FW v MTB-USB desce
     function GetDriverVersion():string;                                         // vrati verzi MTBdrv drivery v knihovne

     function GetModuleName(Module:Integer):string;                              // vrati jmeno modulu
     procedure SetModuleName(Module:Integer; aName:string);                      // nastavi jmeno modulu

     function GetModuleExists(Module:Integer):boolean;                           // vrati jestli modul existuje
     function GetModuleType(Module:Integer):string;                              // vrati typ modulu
     function GetModuleFirmware(Module:integer):String;                          // vrati verzi FW v modulu

     procedure SetBusSpeed(Speed:Integer);                                       // nastavi rychlost sbernice, mozno volat pouze pri zastavene komunikaci
     procedure SetScanInterval(Interval:integer);                                // nastavi ScanInterval sbernice

     procedure LoadLib();                                                        // nacte knihovnu

     // eventy z TMTBIFace do rodice:
     property BeforeOpen:TNotifyEvent read eBeforeOpen write eBeforeOpen;
     property AfterOpen:TNotifyEvent read eAfterOpen write eAfterOpen;
     property BeforeClose:TNotifyEvent read eBeforeClose write eBeforeClose;
     property AfterClose:TNotifyEvent read eAfterClose write eAfterClose;

     property BeforeStart:TNotifyEvent read eBeforeStart write eBeforeStart;
     property AfterStart:TNotifyEvent read eAfterStart write eAfterStart;
     property BeforeStop:TNotifyEvent read eBeforeStop write eBeforeStop;
     property AfterStop:TNotifyEvent read eAfterStop write eAfterStop;

     property OnError:TOnErrorEvent read eOnError write eOnError;
     property OnError:TOnErrorEvent read eOnError write eOnError;
     property OnInputChanged:TOnModuleChangeEvent read eOnInputChange write eOnInputChange;
     property OnOutputChanged:TOnModuleChangeEvent read eOnOutputChange write eOnOutputChange;

     constructor Create(AOwner: TComponent); override;
     destructor Destroy; override;

     property Lib: string read dllName write SetLibName;

  end;


implementation

////////////////////////////////////////////////////////////////////////////////

constructor TRCSIFace.Create(AOwner: TComponent);
 begin
  inherited;
 end;

destructor TRCSIFace.Destroy;
 begin
  if Assigned(FFuncOnUnload) then FFuncOnUnload();
  inherited;
 end;

////////////////////////////////////////////////////////////////////////////////

procedure TRCSIFace.SetLibName(s: string);
 begin
  if FileExists(s) then
    FLibname := s
  else
    raise Exception.Create('Library '+s+' not found');
 end;

////////////////////////////////////////////////////////////////////////////////
// eventy z dll knihovny:

procedure OnLibBeforeOpen(Sender:TObject; data:Pointer); stdcall;
 begin
  if (Assigned(TRCSIFace(data).OnBeforeOpen)) then TRCSIFace(data).OnBeforeOpen(TRCSIFace(data));
 end;

procedure OnLibAfterOpen(Sender:TObject; data:Pointer); stdcall;
 begin
  if (Assigned(TRCSIFace(data).OnAfterOpen)) then TRCSIFace(data).OnAfterOpen(TRCSIFace(data));
 end;

procedure OnLibBeforeClose(Sender:TObject; data:Pointer); stdcall;
 begin
  if (Assigned(TRCSIFace(data).OnBeforeClose)) then TRCSIFace(data).OnBeforeClose(TRCSIFace(data));
 end;

procedure OnLibAfterClose(Sender:TObject; data:Pointer); stdcall;
 begin
  if (Assigned(TRCSIFace(data).OnAfterClose)) then TRCSIFace(data).OnAfterClose(TRCSIFace(data));
 end;

procedure OnLibBeforeStart(Sender:TObject; data:Pointer); stdcall;
 begin
  if (Assigned(TRCSIFace(data).OnBeforeStart)) then TRCSIFace(data).OnBeforeStart(TRCSIFace(data));
 end;

procedure OnLibAfterStart(Sender:TObject; data:Pointer); stdcall;
 begin
  if (Assigned(TRCSIFace(data).OnAfterStart)) then TRCSIFace(data).OnAfterStart(TRCSIFace(data));
 end;

procedure OnLibBeforeStop(Sender:TObject; data:Pointer); stdcall;
 begin
  if (Assigned(TRCSIFace(data).OnBeforeStop)) then TRCSIFace(data).OnBeforeStop(TRCSIFace(data));
 end;

procedure OnLibAfterStop(Sender:TObject; data:Pointer); stdcall;
 begin
  if (Assigned(TRCSIFace(data).OnAfterStop)) then TRCSIFace(data).OnAfterStop(TRCSIFace(data));
 end;

procedure OnLibError(Sender: TObject; data:Pointer; errValue: word; errAddr: byte; errMsg:string); stdcall;
 begin
  if (Assigned(TRCSIFace(data).OnError)) then TRCSIFace(data).OnError(TRCSIFace(data), errValue, errAddr, errMsg);
 end;

procedure OnLibInputChanged(Sender: TObject; data:Pointer; board:byte); stdcall;
 begin
  if (Assigned(TRCSIFace(data).OnInputChanged)) then TRCSIFace(data).OnInputChanged(TRCSIFace(data), board);
 end;

procedure OnLibOutputChanged(Sender: TObject; data:Pointer; board:byte); stdcall;
 begin
  if (Assigned(TRCSIFace(data).OnOutputChanged)) then TRCSIFace(data).OnOutputChanged(TRCSIFace(data), board);
 end;

////////////////////////////////////////////////////////////////////////////////
// nacist dll knihovnu

procedure TRCSIFace.LoadLib();
var setterNotify: TSetDllNotifyEvent;
    setterErr: TSetDllErrEvent;
    setterModuleChanged: TSetDllEventChange;
 begin
  FLib := LoadLibrary(PChar(FLibname));
  if (FLib = 0) then
    raise Exception.Create('Library not loaded');

  FFuncOnUnload           := TODProc(GetProcAddress(FLib, 'onunload'));
  FFuncSetOutput          := TODSetOutput(GetProcAddress(FLib, 'setoutput'));
  FFuncSetInput           := TODSetInput(GetProcAddress(FLib, 'setinput'));
  FFuncGetInput           := TODGetInput(GetProcAddress(FLib, 'getinput'));
  FFuncGetOutput          := TODGetOutput(GetProcAddress(FLib, 'getoutput'));
  FFuncShowConfigDialog   := TODProc(GetProcAddress(FLib, 'showconfigdialog'));
  FFuncHideConfigDialog   := TODProc(GetProcAddress(FLib, 'hideconfigdialog'));
  FFuncShowAboutDialog    := TODProc(GetProcAddress(FLib, 'showaboutdialog'));
  FFuncStart              := TODProc(GetProcAddress(FLib, 'start'));
  FFuncStop               := TODProc(GetProcAddress(FLib, 'stop'));
  FFuncGetLibVersion      := TODFuncStr(GetProcAddress(FLib, 'getlibversion'));
  FFuncGetDeviceVersion   := TODFuncStr(GetProcAddress(FLib, 'getdeviceversion'));
  FFuncGetDriverVersion   := TODFuncStr(GetProcAddress(FLib, 'getdriverversion'));
  FFuncGetModuleFirmware  := TODModuleStr(GetProcAddress(FLib, 'getmodulefirmware'));
  FFuncModuleExists       := TODModuleExists(GetProcAddress(FLib, 'getmoduleexists'));
  FFuncGetModuleType      := TODModuleStr(GetProcAddress(FLib, 'getmoduletype'));
  FFuncGetModuleName      := TODModuleStr(GetProcAddress(FLib, 'getmodulename'));
  FFuncSetModuleName      := TODSetModuleName(GetProcAddress(FLib, 'setmodulename'));
  FFuncSetBusSpeed        := TODSetBusSpeed(GetProcAddress(FLib, 'setmtbspeed'));
  FFuncSetScanInterval    := TODSetScanInterval(GetProcAddress(FLib, 'settimerinterval'));
  FFuncOpen               := TODProc(GetProcAddress(FLib, 'open'));
  FFuncClose              := TODProc(GetProcAddress(FLib, 'close'));

  // assign events:
  setterNotify := TSetDllNotifyEvent(GetProcAddress(FLib, 'setbeforeopen'));
  if (Assigned(setterNotify)) then setterNotify(@OnLibBeforeOpen, self);
  setterNotify := TSetDllNotifyEvent(GetProcAddress(FLib, 'setafteropen'));
  if (Assigned(setterNotify)) then setterNotify(@OnLibAfterOpen, self);
  setterNotify := TSetDllNotifyEvent(GetProcAddress(FLib, 'setbeforeclose'));
  if (Assigned(setterNotify)) then setterNotify(@OnLibBeforeClose, self);
  setterNotify := TSetDllNotifyEvent(GetProcAddress(FLib, 'setafterclose'));
  if (Assigned(setterNotify)) then setterNotify(@OnLibAfterClose, self);

  setterNotify := TSetDllNotifyEvent(GetProcAddress(FLib, 'setbeforestart'));
  if (Assigned(setterNotify)) then setterNotify(@OnLibBeforeStart, self);
  setterNotify := TSetDllNotifyEvent(GetProcAddress(FLib, 'setafterstart'));
  if (Assigned(setterNotify)) then setterNotify(@OnLibAfterStart, self);
  setterNotify := TSetDllNotifyEvent(GetProcAddress(FLib, 'setbeforestop'));
  if (Assigned(setterNotify)) then setterNotify(@OnLibBeforeStop, self);
  setterNotify := TSetDllNotifyEvent(GetProcAddress(FLib, 'setafterstop'));
  if (Assigned(setterNotify)) then setterNotify(@OnLibafterStop, self);

  setterErr := TSetDllErrEvent(GetProcAddress(FLib, 'setonerror'));
  if (Assigned(setterErr)) then setterErr(@OnLibError, self);

  setterModuleChanged := TSetDllEventChange(GetProcAddress(FLib, 'setoninputchange'));
  if (Assigned(setterModuleChanged)) then setterModuleChanged(@OnLibInputChanged, self);
  setterModuleChanged := TSetDllEventChange(GetProcAddress(FLib, 'setonoutputchange'));
  if (Assigned(setterModuleChanged)) then setterModuleChanged(@OnLibOutputChanged, self);
 end;

////////////////////////////////////////////////////////////////////////////////
// metody volane do knihovny:

procedure TRCSIFace.ShowAboutDialog();
 begin
  if (Assigned(FFuncShowAboutDialog)) then
    FFuncShowAboutDialog()
  else
    raise EFuncNotAssigned.Create('FFuncShowAboutDialog not assigned');
 end;

procedure TRCSIFace.ShowConfigDialog();
 begin
  if (Assigned(FFuncShowConfigDialog)) then
    FFuncShowConfigDialog()
  else
    raise EFuncNotAssigned.Create('FFuncShowConfigDialog not assigned');
 end;

procedure TRCSIFace.HideConfigDialog();
 begin
  if (Assigned(FFuncHideConfigDialog)) then
    FFuncHideConfigDialog()
  else
    raise EFuncNotAssigned.Create('FFuncHideConfigDialog not assigned');
 end;

function TRCSIFace.GetInput(Board, Input: Integer): Integer;
 begin
  if (Assigned(FFuncGetInput)) then
    Result := FFuncGetInput(Board, Input)
  else
    raise EFuncNotAssigned.Create('FFuncGetInput not assigned');
 end;

procedure TRCSIFace.SetOutput(Board, Output: Integer; state: Integer);
 begin
  if (Assigned(FFuncSetOutput)) then
    FFuncSetOutput(Board, Output, state)
  else
    raise EFuncNotAssigned.Create('FFuncSetOutput not assigned');
 end;

procedure TRCSIFace.SetInput(Board, Input: Integer; state: Integer);
 begin
  if (Assigned(FFuncSetInput)) then
    FFuncSetInput(Board, Input, state)
  else
    raise EFuncNotAssigned.Create('FFuncSetInput not assigned');
 end;

function TRCSIFace.GetOutput(Board, Port:Integer):Integer;
begin
  if (Assigned(FFuncGetOutput)) then
    Result := FFuncGetOutput(Board, Port)
  else
    raise EFuncNotAssigned.Create('FFuncGetOutput not assigned');
end;

function TRCSIFace.GetLibVersion():String;
 begin
  if (Assigned(FFuncGetLibVersion)) then
    Result := FFuncGetLibVersion()
  else
    raise EFuncNotAssigned.Create('FFuncGetLibVersion not assigned');
 end;

function TRCSIFace.GetDriverVersion():String;
 begin
  if (Assigned(FFuncGetDriverVersion)) then
    Result := FFuncGetDriverVersion()
  else
    raise EFuncNotAssigned.Create('FFuncGetDriverVersion not assigned');
 end;

function TRCSIFace.GetDeviceVersion():String;
 begin
  if (Assigned(FFuncGetDeviceVersion)) then
    Result := FFuncGetDeviceVersion()
  else
    raise EFuncNotAssigned.Create('FFuncGetDeviceVersion not assigned');
 end;

function TRCSIFace.GetModuleExists(Module:Integer):boolean;
 begin
  if (Assigned(FFuncModuleExists)) then
    Result := FFuncModuleExists(Module)
  else
    raise EFuncNotAssigned.Create('FFuncModuleExists not assigned');
 end;

function TRCSIFace.GetModuleType(Module:Integer):string;
 begin
  if (Assigned(FFuncGetModuleType)) then
    Result := FFuncGetModuleType(Module)
  else
    raise EFuncNotAssigned.Create('FFuncGetModuleType not assigned');
 end;

function TRCSIFace.GetModuleName(Module:Integer):string;
 begin
  if (Assigned(FFuncGetModuleName)) then
    Result := FFuncGetModuleName(Module)
  else
    raise EFuncNotAssigned.Create('FFuncGetModuleName not assigned');
 end;

procedure TRCSIFace.SetModuleName(Module:Integer; aName:string);
 begin
  if (Assigned(FFuncSetModuleName)) then
    FFuncSetModuleName(Module, aName)
  else
    raise EFuncNotAssigned.Create('FFuncSetModuleName not assigned');
 end;

procedure TRCSIFace.SetBusSpeed(Speed:Integer);
 begin
  if (Assigned(FFuncSetBusSpeed)) then
    FFuncSetBusSpeed(Speed)
  else
    raise EFuncNotAssigned.Create('FFuncSetBusSpeed not assigned');
 end;

procedure TRCSIFace.Open();
 begin
  if (Assigned(FFuncOpen)) then
    FFuncOpen()
  else
    raise EFuncNotAssigned.Create('FFuncOpen not assigned');
 end;

procedure TRCSIFace.Close();
 begin
  if (Assigned(FFuncClose)) then
    FFuncClose()
  else
    raise EFuncNotAssigned.Create('FFuncClose not assigned');
 end;

procedure TRCSIFace.Start();
begin
  if (Assigned(FFuncStart)) then
    FFuncStart()
  else
    raise EFuncNotAssigned.Create('FFuncStart not assigned');
end;

procedure TRCSIFace.Stop();
begin
  if (Assigned(FFuncStop)) then
    FFuncStop()
  else
    raise EFuncNotAssigned.Create('FFuncStop not assigned');
end;

function TRCSIFace.GetModuleFirmware(Module:integer):string;
 begin
  if (Assigned(FFuncGetModuleFirmware)) then
    Result := FFuncGetModuleFirmware(Module)
  else
    raise EFuncNotAssigned.Create('FFuncGetModuleFirmware not assigned');
 end;

procedure TRCSIFace.SetScanInterval(Interval:integer);
 begin
  if (Assigned(FFuncSetScanInterval)) then
    FFuncSetScanInterval(Interval)
  else
    raise EFuncNotAssigned.Create('FFuncSetScanInterval not assigned');
 end;

////////////////////////////////////////////////////////////////////////////////

end.//unit

