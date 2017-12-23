unit pjscontroller;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, MacroIntf, MacroDefIntf, forms, lazideintf, lazlogger, process ;

Type

  { TServerInstance }

  TServerInstance = Class(TCollectionItem)
  private
    FlastProject: String;
    FPort: Word;
    FProcess: TProcess;
    FRunError: String;
    FServerName: String;
    FString: String;
    function GetRunning: Boolean;
  Protected
    Property Process : TProcess Read FProcess;
  Public
    Destructor Destroy; override;
    Procedure StartServer;
    Procedure StopServer;
    Property Port : Word Read FPort Write FPort;
    Property BaseDir : String Read FString Write FString;
    Property ServerName : String Read FServerName Write FServerName;
    Property Running : Boolean Read GetRunning;
    Property RunError : String Read FRunError;
    Property LastProject : String Read FlastProject Write Flastproject;
  end;

  { TServerInstanceList }

  TServerInstanceList = Class(TCollection)
  private
    function GetInstance(AIndex : Integer): TServerInstance;
  Public
    Function IndexOfPort(APort: Word) : integer;
    Function FindByPort(Aindex : Integer) : TServerInstance;
    Function AddInstance(aPort : Word; Const ABaseURL, aServerName : String) : TServerInstance;
    Property Instances [AIndex : Integer] : TServerInstance Read GetInstance; default;
  end;
  { TPJSController }

  TPJSController = Class
  Private
    FOnRefresh: TNotifyEvent;
    FServerInstances: TServerInstanceList;
    function GetPasJSBrowser(const s: string; const Data: PtrInt; var Abort: boolean): string;
    function GetPasJSNodeJS(const s: string; const Data: PtrInt; var Abort: boolean): string;
    function GetProjectURL(const s: string; const Data: PtrInt; var Abort: boolean): string;
    function MaybeStartServer(Sender: TObject; var Handled: boolean): TModalResult;
  Public
    Constructor Create;
    Destructor Destroy; override;
    Class Procedure DoneInstance;
    Class Function instance :  TPJSController;
    Procedure Hook; virtual;
    Procedure UnHook; virtual;
    Procedure RefreshView;
    Property ServerInstances : TServerInstanceList Read FServerInstances;
    Property OnRefresh : TNotifyEvent Read FOnRefresh Write FonRefresh;
  end;

Const
  // Custom settings in .lpi
  PJSProjectWebBrowser =  'PasJSWebBrowserProject';
  PJSProjectURL = 'PasJSURL';
  PJSProjectHTMLFile = 'PasJSHTMLFile';
  PJSProjectPort = 'PasJSPort';


implementation

uses FileUtil, LazFileUtils, PJSDsgnOptions;

Var
  ctrl : TPJSController;

{ TServerInstanceList }

function TServerInstanceList.GetInstance(AIndex : Integer): TServerInstance;
begin
  Result:=Items[AIndex] as TServerInstance;
end;

function TServerInstanceList.IndexOfPort(APort: Word): integer;
begin
  Result:=Count-1;
  While (Result>=0) and (GetInstance(Result).Port<>APort) do Dec(Result);
end;

function TServerInstanceList.FindByPort(Aindex: Integer): TServerInstance;

Var
  I : Integer;

begin
  I:=IndexOfPort(Aindex);
  If I=-1 then
    Result:=nil
  else
    Result:=GetInstance(I);
end;

function TServerInstanceList.AddInstance(aPort: Word; const ABaseURL,
  aServerName: String): TServerInstance;
begin
  Result:=Add as TServerInstance;
  Result.Port:=aPort;
  Result.BaseDir:=ABaseURL;
  Result.ServerName:=aServerName;
end;

{ TServerInstance }

function TServerInstance.GetRunning: Boolean;
begin
  Result:=Assigned(FProcess);
  if Result then
    Result:=Process.Running;
end;

destructor TServerInstance.Destroy;
begin
  StopServer;
  FreeAndNil(FProcess);
  inherited;
end;

procedure TServerInstance.StartServer;
begin
  if Running then
    exit;
  If not Assigned(FProcess) then
    FProcess:=TProcess.Create(Nil);
  FProcess.Executable:=ServerName;
  FProcess.Parameters.Add('-q');
  FProcess.Parameters.Add('-p');
  FProcess.Parameters.Add(IntToStr(Port));
  {$IFDEF WINDOWS}
  FProcess.Options:=[poNoConsole];
  {$ENDIF}
  DebugLN(['Starting server from Directory : ',BaseDir]);
  FProcess.CurrentDirectory:=BaseDir;
  try
    FProcess.Execute;
  except
    On E : Exception do
      begin
      FRunError:=E.Message;
      Raise;
      end;
  end;
  TPJSController.Instance.RefreshView;
end;

procedure TServerInstance.StopServer;
begin
  if Running then
    FProcess.Terminate(0);
  TPJSController.Instance.RefreshView;
end;

class procedure TPJSController.DoneInstance;

begin
  FreeAndNil(Ctrl)
end;

class function TPJSController.instance: TPJSController;

begin
  if ctrl=Nil then
    Ctrl:=TPJSController.Create;
  Result:=Ctrl;
end;

{ TPJSController }

function TPJSController.GetPasJSBrowser(const s: string; const Data: PtrInt; var Abort: boolean): string;

begin
  Abort:=False;
  Result:=PJSOptions.BrowserFileName;
  if Result='' then
    Result:=GetStandardBrowser;
  IdeMacros.SubstituteMacros(Result);
  if (Result<>'') and not FilenameIsAbsolute(Result) then
    Result:=FindDefaultExecutablePath(Result);
end;

function TPJSController.GetPasJSNodeJS(const s: string; const Data: PtrInt; var Abort: boolean): string;

begin
  Abort:=False;
  Result:=PJSOptions.NodeJSFileName;
  if Result='' then
    Result:=GetStandardNodeJS;
  IdeMacros.SubstituteMacros(Result);
  if (Result<>'') and not FilenameIsAbsolute(Result) then
    Result:=FindDefaultExecutablePath(Result);
end;

function TPJSController.GetProjectURL(const s: string; const Data: PtrInt; var Abort: boolean): string;

Var
  FN : String;

begin
  DebugLN(['LazarusIDE.ActiveProject.CustomData[PJSProjectWebBrowser]: ',LazarusIDE.ActiveProject.CustomData[PJSProjectWebBrowser]]);
  Abort:=LazarusIDE.ActiveProject.CustomData[PJSProjectWebBrowser]<>'1';
  if Abort then
    exit;
  DebugLN(['LazarusIDE.ActiveProject.CustomData[PJSProjectURL]: ',LazarusIDE.ActiveProject.CustomData[PJSProjectURL]]);
  Result:=LazarusIDE.ActiveProject.CustomData[PJSProjectURL];
  if (Result='') then
    begin
    FN:=LazarusIDE.ActiveProject.CustomData[PJSProjectHTMLFile];
    DebugLN(['LazarusIDE.ActiveProject.CustomData[PJSProjectHTMLFile]: ',LazarusIDE.ActiveProject.CustomData[PJSProjectHTMLFile]]);
    if (FN='') then
      FN:=ChangeFileExt(ExtractFileName(LazarusIDE.ActiveProject.ProjectInfoFile),'.html');
    Result:=LazarusIDE.ActiveProject.CustomData[PJSProjectPort];
    if (Result<>'') and (Result<>'0') then
      Result:=Format('http://localhost:%s/%s',[Result,FN])
    else
      {$IFDEF WINDOWS}
      Result:=Format('file:///%s',[ExtractFilePath(LazarusIDE.ActiveProject.ProjectInfoFile)+FN]);
      {$ELSE}
      Result:=Format('file://%s',[ExtractFilePath(LazarusIDE.ActiveProject.ProjectInfoFile)+FN]);
      {$ENDIF}
    end;
  Abort:=(Result='');
  DebugLN(['GetProjectURL : ',Result]);
end;

function TPJSController.MaybeStartServer(Sender: TObject; var Handled: boolean): TModalResult;

Var
  ServerPort : Word;
  WebProject : Boolean;
  BaseDir : String;
  aInstance : TServerInstance;

begin
  With LazarusIDE.ActiveProject do
    begin
    DebugLn(['WebProject:=',CustomData[PJSProjectWebBrowser]]);
    DebugLn(['ServerPort:=',CustomData[PJSProjectPort]]);
    DebugLn(['BaseDir:=',ProjectInfoFile]);
    WebProject:=CustomData[PJSProjectWebBrowser]='1';
    ServerPort:=StrToIntDef(CustomData[PJSProjectPort],0);
    BaseDir:=ExtractFilePath(ProjectInfoFile);
    end;
  // Exit if we don't need to do anything
  if Not (WebProject and (ServerPort>0)) then
    Exit;
  aInstance:=ServerInstances.FindByPort(ServerPort);
  If Ainstance<>Nil then
    begin
    Writeln('Have instance running on port ',ServerPort);
    if Not SameFileName(BaseDir,aInstance.BaseDir) then
      begin
      Writeln('Instance on port ',ServerPort,' serves different directory: ',aInstance.BaseDir);
      // We should ask the user what to do ?
      If aInstance.Running then
        aInstance.StopServer;
      end;
    end
  else
    begin
//    Writeln('No instance running on port ',ServerPort, 'allocating it');
    aInstance:=ServerInstances.AddInstance(ServerPort,BaseDir,PJSOptions.GetParsedHTTPServerFilename);
    end;
  aInstance.LastProject:=LazarusIDE.ActiveProject.ProjectInfoFile;
  aInstance.StartServer;
  Handled:=False;
end;

constructor TPJSController.Create;
begin
  // Nothing for the moment
  FServerInstances:=TServerInstanceList.Create(TServerInstance);
end;

destructor TPJSController.Destroy;
begin
  Unhook;
  FreeAndNil(FServerInstances);
  inherited Destroy;
end;

procedure TPJSController.Hook;
begin
  IDEMacros.Add(TTransferMacro.Create('Pas2JSBrowser','','Pas2JS selected Browser executable',@GetPasJSBrowser,[]));
  IDEMacros.Add(TTransferMacro.Create('Pas2JSNodeJS','','Pas2JS selected NodeJS xecutable',@GetPasJSNodeJS,[]));
  IDEMacros.Add(TTransferMacro.Create('Pas2JSProjectURL','','Pas2JS current project URL',@GetProjectURL,[]));
  LazarusIDE.AddHandlerOnRunWithoutDebugInit(@MaybeStartServer);
end;

procedure TPJSController.UnHook;
begin
  // Nothing for the moment
end;

procedure TPJSController.RefreshView;
begin
  If Assigned(FOnRefresh) then
    FOnRefresh(Self);
end;

finalization
  TPJSController.DoneInstance;
end.

