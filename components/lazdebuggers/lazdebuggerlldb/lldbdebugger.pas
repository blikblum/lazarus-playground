(*
  settings set target.output-path /tmp/out.txt
*)
unit LldbDebugger;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, math, DbgIntfDebuggerBase, DbgIntfBaseTypes, LazLoggerBase,
  LazClasses, LazFileUtils, Maps, strutils, DebugProcess, LldbInstructions,
  LldbHelper;

type

  (*
   *  Commands
   *)

  TLldbDebugger = class;
  TLldbDebuggerCommand = class;

  { TLldbDebuggerCommandQueue }

  TLldbDebuggerCommandQueue = class(TRefCntObjList)
  private
    FDebugger: TLldbDebugger;
    FLockQueueRun: Integer;
    function Get(Index: Integer): TLldbDebuggerCommand;
    procedure Put(Index: Integer; const AValue: TLldbDebuggerCommand);
  private
    FRunningCommand: TLldbDebuggerCommand;
    procedure Run; // Call Debugger.OnIdle // set IsIdle
  protected
    procedure CommandFinished(ACommand: TLldbDebuggerCommand);
  public
    constructor Create(ADebugger: TLldbDebugger);
    destructor Destroy; override;
    procedure LockQueueRun;
    procedure UnLockQueueRun;
    property Items[Index: Integer]: TLldbDebuggerCommand read Get write Put; default;
    procedure QueueCommand(AValue: TLldbDebuggerCommand);
    procedure DoLineDataReceived(var ALine: String);
    property RunningCommand: TLldbDebuggerCommand read FRunningCommand;
  end;

  { TLldbDebuggerCommand }

  TLldbDebuggerCommand = class(TRefCountedObject)
  private
    FOwner: TLldbDebugger;
    function GetDebuggerState: TDBGState;
    function GetCommandQueue: TLldbDebuggerCommandQueue;
    function GetInstructionQueue: TLldbInstructionQueue;
  protected
    procedure DoLineDataReceived(var ALine: String); virtual;
    procedure DoExecute; virtual; abstract;
    procedure Finished;

    procedure InstructionSucceeded(AnInstruction: TObject);
    procedure InstructionFailed(AnInstruction: TObject);

    procedure QueueInstruction(AnInstruction: TLldbInstruction);
    procedure SetDebuggerState(const AValue: TDBGState);
    property Debugger: TLldbDebugger read FOwner;
    property CommandQueue: TLldbDebuggerCommandQueue read GetCommandQueue;
    property InstructionQueue: TLldbInstructionQueue read GetInstructionQueue;
    property DebuggerState: TDBGState read GetDebuggerState;
  public
    constructor Create(AOwner: TLldbDebugger);
    destructor Destroy; override;
    procedure Execute;
  end;

  { TLldbDebuggerCommandInit }

  TLldbDebuggerCommandInit = class(TLldbDebuggerCommand)
  protected
    procedure DoExecute; override;
  end;

  { TLldbDebuggerCommandRun }

  TLldbDebuggerCommandRun = class(TLldbDebuggerCommand)
  private type
    TExceptionInfoCommand = (exiReg0, exiClass, exiMsg);
    TExceptionInfoCommands = set of TExceptionInfoCommand;
  private
    FState: (crInit, crRunning, crReadingThreads, crStopped, crStoppedAtException, crDone);
    FThreadInstr: TLldbInstructionThreadList;
    FCurrentExceptionInfo: record
      FHasCommandData: TExceptionInfoCommands; // cleared in Setstate
      FObjAddress: TDBGPtr;
      FExceptClass: String;
      FExceptMsg: String;
    end;
    procedure ThreadInstructionSucceeded(Sender: TObject);
    procedure ExceptionReadReg0Success(Sender: TObject);
    procedure ExceptionReadClassSuccess(Sender: TObject);
    procedure ExceptionReadMsgSuccess(Sender: TObject);
  protected
    procedure DoLineDataReceived(var ALine: String); override;
    procedure RunInstructionSucceeded(AnInstruction: TObject);
  public
    constructor Create(AOwner: TLldbDebugger);
    destructor Destroy; override;
  end;

  { TLldbDebuggerCommandRunStep }

  TLldbDebuggerCommandRunStep = class(TLldbDebuggerCommandRun)
  private
    FStepAction: TLldbInstructionProcessStepAction;
  protected
    procedure DoExecute; override;
  public
    constructor Create(AOwner: TLldbDebugger; AStepAction: TLldbInstructionProcessStepAction);
  end;

  { TLldbDebuggerCommandRunLaunch }

  TLldbDebuggerCommandRunLaunch = class(TLldbDebuggerCommandRun)
  private
    FRunInstr: TLldbInstruction;
    procedure ExceptBreakInstructionFinished(Sender: TObject);
    procedure TargetCreated(Sender: TObject);
  protected
    procedure DoExecute; override;
  end;

  { TLldbDebuggerCommandStop }

  TLldbDebuggerCommandStop = class(TLldbDebuggerCommand)
  private
    procedure StopInstructionSucceeded(Sender: TObject);
  protected
    procedure DoExecute; override;
  end;

  { TLldbDebuggerCommandLocals }

  TLldbDebuggerCommandLocals = class(TLldbDebuggerCommand)
  private
    FLocals: TLocals;
    FLocalsInstr: TLldbInstructionLocals;
    procedure DoLocalsFreed(Sender: TObject);
    procedure LocalsInstructionFinished(Sender: TObject);
  protected
    procedure DoExecute; override;
  public
    constructor Create(AOwner: TLldbDebugger; ALocals: TLocals);
    destructor Destroy; override;
  end;

  { TLldbDebuggerCommandEvaluate }

  TLldbDebuggerCommandEvaluate = class(TLldbDebuggerCommand)
  private
    FInstr: TLldbInstructionExpression;
    FWatchValue: TWatchValue;
    FExpr: String;
    FFlags: TDBGEvaluateFlags;
    FCallback: TDBGEvaluateResultCallback;
    procedure DoWatchFreed(Sender: TObject);
    procedure EvalInstructionFailed(Sender: TObject);
    procedure EvalInstructionSucceeded(Sender: TObject);
  protected
    procedure DoExecute; override;
  public
    // TODO: Pass FCurrentStackFrame to create
    constructor Create(AOwner: TLldbDebugger; AWatchValue: TWatchValue);
    constructor Create(AOwner: TLldbDebugger; AnExpr: String; AFlags: TDBGEvaluateFlags;
                       ACallback: TDBGEvaluateResultCallback);
    destructor Destroy; override;
  end;

  (*
   *  Debugger
   *)
  { TLldbDebugger }

  TLldbDebugger = class(TDebuggerIntf)
  private
    FDebugProcess: TDebugProcess;
    FDebugInstructionQueue: TLldbInstructionQueue;
    FCommandQueue: TLldbDebuggerCommandQueue;
    FCurrentLocation: TDBGLocationRec;
    FCurrentStackFrame: Integer;
    FCurrentThreadId: Integer;
    FTargetWidth: Byte;
    FTargetRegisters: array[0..2] of String;
    FExceptionBreakId: Integer;
    FLldbMissingBreakSetDisable: Boolean;
    FExceptionInfo: record
      FReg0Cmd, FExceptClassCmd, FExceptMsgCmd: String;
      FAtExcepiton: Boolean; // cleared in Setstate
    end;
    (* DoAfterLineReceived is called after DebugInstruction.ProcessInputFromDbg
         (but not if ProcessInputFromDbg already handled the Line)
       DoAfterLineReceived will first call CommandQueue.DoLineDataReceived
    *)
    procedure DoAfterLineReceived(var ALine: String);  //
    procedure DoBeforeLineReceived(var ALine: String); // Before DebugInstruction.ProcessInputFromDbg
    procedure DoCmdLineDebuggerTerminated(Sender: TObject);
    procedure DoLineSentToDbg(Sender: TObject; ALine: String);

    function  LldbRun: Boolean;
    function  LldbStep(AStepAction: TLldbInstructionProcessStepAction): Boolean;
    function  LldbStop: Boolean;
    function  LldbEvaluate(const AExpression: String; EvalFlags: TDBGEvaluateFlags; ACallback: TDBGEvaluateResultCallback): Boolean;
  protected
    procedure DoBeginReceivingLines(Sender: TObject);
    procedure DoEndReceivingLines(Sender: TObject);
    procedure LockRelease; override;
    procedure UnlockRelease; override;
    procedure QueueCommand(const ACommand: TLldbDebuggerCommand);
    procedure SetState(const AValue: TDBGState);
    //procedure DoState(const OldState: TDBGState); override;
    //procedure DoBeforeState(const OldState: TDBGState); override;
    function DoExceptionHit(AExcClass, AExcMsg: String): Boolean;
    function DoBreakpointHit(BrkId: Integer): Boolean;

    property CurrentThreadId: Integer read FCurrentThreadId;
    property CurrentStackFrame: Integer read FCurrentStackFrame;
    property CurrentLocation: TDBGLocationRec read FCurrentLocation;
    property DebugInstructionQueue: TLldbInstructionQueue read FDebugInstructionQueue;
    property CommandQueue: TLldbDebuggerCommandQueue read FCommandQueue;
  protected
    function  CreateBreakPoints: TDBGBreakPoints; override;
    function  CreateLocals: TLocalsSupplier; override;
    //function  CreateLineInfo: TDBGLineInfo; override;
    function  CreateRegisters: TRegisterSupplier; override;
    function  CreateCallStack: TCallStackSupplier; override;
    //function  CreateDisassembler: TDBGDisassembler; override;
    function  CreateWatches: TWatchesSupplier; override;
    function  CreateThreads: TThreadsSupplier; override;
    function  GetTargetWidth: Byte; override;

    function  GetSupportedCommands: TDBGCommands; override;
    //function  GetCommands: TDBGCommands; override;
    function  RequestCommand(const ACommand: TDBGCommand;
              const AParams: array of const;
              const ACallback: TMethod): Boolean; override;
  public
//    class function CreateProperties: TDebuggerProperties; override; // Creates debuggerproperties
    class function Caption: String; override;
//    class function ExePaths: String; override;

    constructor Create(const AExternalDebugger: String); override;
    destructor Destroy; override;
    procedure Init; override;         // Initializes external debugger
    procedure Done; override;         // Kills external debugger

    class function RequiredCompilerOpts(ATargetCPU, ATargetOS: String
      ): TDebugCompilerRequirements; override;
    function GetLocation: TDBGLocationRec; override;
//    function GetProcessList({%H-}AList: TRunningProcessInfoList): boolean; override;
//    function NeedReset: Boolean; override;
    procedure TestCmd(const ACommand: String); override;
  end;


procedure Register;

implementation

type

  {%region
    *****
    *****     Threads
    ***** }

  { TLldbDebuggerCommandThreads }

  TLldbDebuggerCommandThreads = class(TLldbDebuggerCommand)
  private
//    FCurrentThreads: TThreads;
    procedure ThreadInstructionSucceeded(Sender: TObject);
    //procedure StopInstructionSucceeded(Sender: TObject);
  protected
    procedure DoExecute; override;
  public
//    property  CurrentThreads: TThreads read FCurrentThreads write FCurrentThreads;
  end;

  { TLldbThreads }

  TLldbThreads = class(TThreadsSupplier)
  private
    function GetDebugger: TLldbDebugger;
  protected
    procedure DoStateEnterPause; override;
    procedure ReadFromThreadInstruction(Instr: TLldbInstructionThreadList);
  public
    procedure RequestMasterData; override;
    procedure ChangeCurrentThread(ANewId: Integer); override;
    property Debugger: TLldbDebugger read GetDebugger;
  end;

  {%endregion   ^^^^^  Threads  ^^^^^   }

  {%region
    *****
    *****     CallStack
    ***** }

  { TLldbDebuggerCommandCallStack }

  TLldbDebuggerCommandCallStack = class(TLldbDebuggerCommand)
  private
    FCurrentCallStack: TCallStackBase;
    procedure DoCallstackFreed(Sender: TObject);
    procedure StackInstructionFinished(Sender: TObject);
  protected
    procedure DoExecute; override;
  public
    constructor Create(AOwner: TLldbDebugger; ACurrentCallStack: TCallStackBase);
    destructor Destroy; override;
    property  CurrentCallStack: TCallStackBase read FCurrentCallStack;
  end;

  { TLldbCallStack }

  TLldbCallStack = class(TCallStackSupplier)
  protected
    //procedure Clear;
    //procedure DoThreadChanged;
    procedure ParentRequestEntries(ACallstack: TCallStackBase);
  public
    procedure RequestAtLeastCount(ACallstack: TCallStackBase;
      ARequiredMinCount: Integer); override;
    procedure UpdateCurrentIndex; override;
    procedure RequestCurrent(ACallstack: TCallStackBase); override;
    procedure RequestEntries(ACallstack: TCallStackBase); override;
  end;

  {%endregion   ^^^^^  CallStack  ^^^^^   }

  {%region
    *****
    *****     Locals
    ***** }

  { TLldbLocals }

  TLldbLocals = class(TLocalsSupplier)
  public
    procedure RequestData(ALocals: TLocals); override;
  end;

  {%endregion   ^^^^^  Locals  ^^^^^   }

  {%region
    *****
    *****     Watches
    ***** }

  { TLldbWatches }

  TLldbWatches = class(TWatchesSupplier)
  private
  protected
    procedure InternalRequestData(AWatchValue: TWatchValue); override;
  public
  end;

  {%endregion   ^^^^^  Watches  ^^^^^   }

  {%region
    *****
    *****     BreakPoint
    ***** }

  { TLldbBreakPoint }

  TLldbBreakPoint = class(TDBGBreakPoint)
  private
    FBreakID: Integer;
    FCurrentInstruction: TLldbInstruction;
    FNeededChanges: TDbgBpChangeIndicators;
    procedure InstructionSetBreakFinished(Sender: TObject);
    procedure InstructionUpdateBreakFinished(Sender: TObject);
    procedure SetBreakPoint;
    procedure ReleaseBreakPoint;
    procedure UpdateProperties(AChanged: TDbgBpChangeIndicators);
    procedure DoCurrentInstructionFinished;
    procedure CancelCurrentInstruction;
  protected
    procedure DoStateChange(const AOldState: TDBGState); override;
    procedure DoPropertiesChanged(AChanged: TDbgBpChangeIndicators); override;
  public
//    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;
//    procedure DoLogExpression(const AnExpression: String); override;
  end;

  { TLldbBreakPoints }

  TLldbBreakPoints = class(TDBGBreakPoints)
  protected
    function FindById(AnId: Integer): TLldbBreakPoint;
  end;

  {%endregion   ^^^^^  BreakPoint  ^^^^^   }

  {%region
    *****
    *****     Register
    ***** }

  { TLldbDebuggerCommandRegister }

  TLldbDebuggerCommandRegister = class(TLldbDebuggerCommand)
  private
    FRegisters: TRegisters;
    procedure RegisterInstructionFinished(Sender: TObject);
  protected
    procedure DoExecute; override;
  public
    constructor Create(AOwner: TLldbDebugger; ARegisters: TRegisters);
    destructor Destroy; override;
    property Registers: TRegisters read FRegisters;
  end;

  { TLldbRegisterSupplier }

  TLldbRegisterSupplier = class(TRegisterSupplier)
  public
    procedure Changed;
    procedure RequestData(ARegisters: TRegisters); override;
  end;

{ TLldbDebuggerCommandRun }

procedure TLldbDebuggerCommandRun.ThreadInstructionSucceeded(Sender: TObject);
begin
  FState := crStopped;

  // defer until after dsPause
  TLldbThreads(Debugger.Threads).ReadFromThreadInstruction(TLldbInstructionThreadList(Sender));
end;

procedure TLldbDebuggerCommandRun.ExceptionReadReg0Success(Sender: TObject);
begin
  FCurrentExceptionInfo.FObjAddress := StrToInt64Def(TLldbInstructionReadExpression(Sender).Res, 0);
  Include(FCurrentExceptionInfo.FHasCommandData, exiReg0);
end;

procedure TLldbDebuggerCommandRun.ExceptionReadClassSuccess(Sender: TObject);
var
  s: String;
  i: SizeInt;
begin
  // (char * ) $2 = 0x005c18d0 "\tException"
  s := TLldbInstructionReadExpression(Sender).Res;
  i := pos('"', s);
  if i > 0 then begin
    if s[i+1] = '\' then inc(i);
    s := copy(s, i+2, Length(s)-i-2);
  end;
  FCurrentExceptionInfo.FExceptClass := s;
  Include(FCurrentExceptionInfo.FHasCommandData, exiClass);
end;

procedure TLldbDebuggerCommandRun.ExceptionReadMsgSuccess(Sender: TObject);
var
  s: String;
  i: SizeInt;
begin
  s := TLldbInstructionReadExpression(Sender).Res;
  i := pos('"', s);
  if i > 0 then
    s := copy(s, i+1, Length(s)-i-1);
  FCurrentExceptionInfo.FExceptMsg := s;
  Include(FCurrentExceptionInfo.FHasCommandData, exiMsg);
end;

procedure TLldbDebuggerCommandRun.DoLineDataReceived(var ALine: String);
  function GetBreakPointId(AReason: String): Integer;
  var
    i: Integer;
  begin
    i := pos('.', AReason);
    if i = 0 then i := Length(AReason)+1;
    Result := StrToIntDef(copy(AReason, 12, i-12), -1);
    debugln(['DoBreakPointHit ', AReason, ' / ', Result]);
  end;

  procedure DoException;
  var
    ExcClass, ExcMsg: String;
    CanContinue: Boolean;
  begin
    if exiClass in FCurrentExceptionInfo.FHasCommandData then
      ExcClass := FCurrentExceptionInfo.FExceptClass
    else
      ExcClass := '<Unknown Class>'; // TODO: move to IDE
    if exiMsg in FCurrentExceptionInfo.FHasCommandData then
      ExcMsg := FCurrentExceptionInfo.FExceptMsg
    else
      ExcMsg := '<Unknown Message>'; // TODO: move to IDE

    CanContinue := Debugger.DoExceptionHit(ExcClass, ExcMsg);

    if CanContinue
    then begin
      FCurrentExceptionInfo.FHasCommandData := []; // no state change
  // TODO: handle continue stepping
  // TODO: wait for SetLocation / lldb sents the frame info in the next output line
      Debugger.LldbRun; // XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      exit;
    end
    else
      SetDebuggerState(dsPause); // after GetLocation => dsPause may run stack, watches etc
  end;

  procedure DoBreakPointHit(BrkId: Integer);
  var
    BreakPoint: TLldbBreakPoint;
    CanContinue: Boolean;
  begin
    CanContinue := Debugger.DoBreakpointHit(BrkId);

    if CanContinue
    then begin
      // Important trigger State => as snapshot is taken in TDebugManager.DebuggerChangeState
      SetDebuggerState(dsInternalPause);
// TODO: handle continue stepping
// TODO: wait for SetLocation / lldb sents the frame info in the next output line
      Debugger.LldbRun; //XIXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
    end
    else begin
      SetDebuggerState(dsPause);
    end;
  end;

var
  Instr: TLldbInstruction;
  found: TStringArray;
  AnId, SrcLine, i: Integer;
  AnIsCurrent: Boolean;
  AnAddr, stack, frame: TDBGPtr;
  AFuncName, AFile, AReminder, AFullFile, s: String;
  AnArgs: TStringList;
begin
  (* When the debuggee stops (pause), the following will be received:
    // for EXCEPTIONS ONLY  (less the spaces between * ) )
     p/x $eax
     (unsigned int) $1 = 0x04dfd920
     p ((char *** )$eax)[0][3]
     (char * ) $2 = 0x005c18d0 "\tException"
     p ((char ** )$eax)[1]
     (char * ) $3 = 0x00000000 <no value available>

    // Hit breakpoint
      Process 10992 stopped
     * thread #1: tid=0x1644: 0x00409e91, 0x0158FF38, 0x0158FF50 &&//FULL: \FPC\SVN\fixes_3_0\rtl\win32\..\inc\except.inc &&//SHORT: except.inc &&//LINE: 185 &&//MOD: project1.exe &&//FUNC: fpc_raiseexception(OBJ=0x038f5a90, ANADDR=0x00401601, AFRAME=0x0158ff58) <<&&//FRAME"
       thread #2: tid=0x27bc: 0x77abf8dc, 0x0557FE64, 0x0557FEC8 &&//FULL:  &&//SHORT:  &&//LINE:  &&//MOD: ntdll.dll &&//FUNC: NtDelayExecution <<&&//FRAME"
      Process 10992 stopped
      * stopped in thread #1, stop reason = breakpoint 6.1
          frame #0: 0x0042b855 &&//FULL: \tmp\New Folder (2)\unit1.pas &&//SHORT: unit1.pas &&//LINE: 54 &&//MOD: project1.exe &&//FUNC: FORMCREATE(this=0x04c81248, SENDER=0x04c81248) <<&&//FRAME
  *)

  {%region exception }
  s := TrimLeft(ALine);
  Instr := nil;
  if StrStartsWith(s, Debugger.FExceptionInfo.FReg0Cmd, True) then begin
    Instr := TLldbInstructionReadExpression.Create;
    Instr.OnSuccess := @ExceptionReadReg0Success;
  end
  else
  if StrStartsWith(s, Debugger.FExceptionInfo.FExceptClassCmd, True) then begin
    Instr := TLldbInstructionReadExpression.Create;
    Instr.OnSuccess := @ExceptionReadClassSuccess;
  end
  else
  if StrStartsWith(s, Debugger.FExceptionInfo.FExceptMsgCmd, True) then begin
    Instr := TLldbInstructionReadExpression.Create;
    Instr.OnSuccess := @ExceptionReadMsgSuccess;
  end;

  if Instr <> nil then begin
    ALine := '';
    debugln(['Reading exception info']);
    assert(InstructionQueue.RunningInstruction = nil, 'InstructionQueue.RunningInstruction = nil');
    QueueInstruction(Instr);
    Instr.ReleaseReference;
    exit;
  end;
  {%endregion exception }

  // STEP 1:   Process 10992 stopped
  if (FState = crRunning) and StrMatches(ALine, ['Process ', 'stopped']) then begin
    FState := crReadingThreads;
    debugln(['Reading thread info']);
    FThreadInstr := TLldbInstructionThreadListReader.Create();
    FThreadInstr.OnFinish := @ThreadInstructionSucceeded;
    QueueInstruction(FThreadInstr);
    exit;
  end;

  // STEP 2:   * stopped in thread #1, stop reason = breakpoint 6.1
  if StrMatches(ALine, ['* stopped in thread #', ', stop reason = ', ''], found) then begin
    FState := crStopped;
    debugln(['Reading stopped thread']);
    Debugger.FCurrentThreadId := StrToIntDef(found[0], 0);
    Debugger.FCurrentStackFrame := 0;
    InstructionQueue.SetKnownThreadAndFrame(Debugger.FCurrentThreadId, 0);
    Debugger.Threads.CurrentThreads.CurrentThreadId := Debugger.FCurrentThreadId; // set again from thread list
    ALine := '';

    if StrStartsWith(found[1], 'breakpoint ') then begin
      i := GetBreakPointId(found[1]);
      if i = Debugger.FExceptionBreakId then
        FState := crStoppedAtException
      else
        DoBreakPointHit(i);
    end
    else
      SetDebuggerState(dsPause);
    exit;
  end;

  // STEP 3:   frame #0: 0x0042b855 &&//FULL: \tmp\New Folder (2)\unit1.pas &&//SHORT: unit1.pas &&//LINE: 54 &&//MOD: project1.exe &&//FUNC: FORMCREATE(this=0x04c81248, SENDER=0x04c81248) <<&&//FRAME
  if ParseNewFrameLocation(ALine, AnId, AnIsCurrent, AnAddr, stack, frame, AFuncName, AnArgs,
    AFile, AFullFile, SrcLine, AReminder)
  then begin
    debugln(['Reading frame info']);
    AnArgs.Free;
    Debugger.FCurrentLocation.Address := AnAddr;
    Debugger.FCurrentLocation.FuncName := AFuncName;
    Debugger.FCurrentLocation.SrcFile := AFile;
    Debugger.FCurrentLocation.SrcFullName := AFullFile;
    Debugger.FCurrentLocation.SrcLine := SrcLine;

    if FState = crStoppedAtException then
      DoException;

    if DebuggerState in [dsPause, dsInternalPause, dsStop] then
      Debugger.DoCurrent(Debugger.FCurrentLocation);
    ALine := '';

    FState := crDone;
    Finished;
    exit;
  end;

  // Executed, if "frame #0" was not found
  if FState = crStoppedAtException then begin // did not get location
    Debugger.FCurrentLocation.Address := 0;
    Debugger.FCurrentLocation.FuncName := '';
    Debugger.FCurrentLocation.SrcFile := '';
    Debugger.FCurrentLocation.SrcFullName := '';
    Debugger.FCurrentLocation.SrcLine := -1;
    DoException;
    Finished;
  end;

end;

procedure TLldbDebuggerCommandRun.RunInstructionSucceeded(AnInstruction: TObject
  );
begin
  FState := crRunning;
  FCurrentExceptionInfo.FHasCommandData := [];
end;

constructor TLldbDebuggerCommandRun.Create(AOwner: TLldbDebugger);
begin
  FState := crInit;
  inherited Create(AOwner);
end;

destructor TLldbDebuggerCommandRun.Destroy;
begin
  FThreadInstr.ReleaseReference;
  inherited Destroy;
end;

{ TLldbDebuggerCommandLocals }

procedure TLldbDebuggerCommandLocals.LocalsInstructionFinished(Sender: TObject
  );
var
  n: String;
  i: Integer;
begin
  if FLocals <> nil then begin
    FLocals.Clear;
    for i := 0 to FLocalsInstr.Res.Count - 1 do begin
      n := FLocalsInstr.Res.Names[i];
      FLocals.Add(n, FLocalsInstr.Res.Values[n]);
    end;
    FLocals.SetDataValidity(ddsValid);
  end;

  ReleaseRefAndNil(FLocalsInstr);
  Finished;
end;

procedure TLldbDebuggerCommandLocals.DoLocalsFreed(Sender: TObject);
begin
  FLocals := nil;
  if FLocalsInstr <> nil then begin
    FLocalsInstr.OnFinish := nil;
    FLocalsInstr.Cancel;
    ReleaseRefAndNil(FLocalsInstr);
    Finished;
  end;
end;

procedure TLldbDebuggerCommandLocals.DoExecute;
begin
  if FLocalsInstr <> nil then begin
    FLocalsInstr.OnFinish := nil;
    ReleaseRefAndNil(FLocalsInstr);
  end;
  FLocalsInstr := TLldbInstructionLocals.Create();
  FLocalsInstr.OnFinish := @LocalsInstructionFinished;
  QueueInstruction(FLocalsInstr);
end;

constructor TLldbDebuggerCommandLocals.Create(AOwner: TLldbDebugger;
  ALocals: TLocals);
begin
  FLocals := ALocals;
  FLocals.AddFreeNotification(@DoLocalsFreed);
  inherited Create(AOwner);
end;

destructor TLldbDebuggerCommandLocals.Destroy;
begin
  if FLocalsInstr <> nil then begin
    FLocalsInstr.OnFinish := nil;
    ReleaseRefAndNil(FLocalsInstr);
  end;
  if FLocals <> nil then
    FLocals.RemoveFreeNotification(@DoLocalsFreed);
  inherited Destroy;
end;

  {%endregion   ^^^^^  Register  ^^^^^   }

{%region
  *****
  *****     Threads
  ***** }

{ TLldbDebuggerCommandThreads }

procedure TLldbDebuggerCommandThreads.ThreadInstructionSucceeded(Sender: TObject);
begin
  TLldbThreads(Debugger.Threads).ReadFromThreadInstruction(TLldbInstructionThreadList(Sender));
  Finished;
end;

procedure TLldbDebuggerCommandThreads.DoExecute;
var
  Instr: TLldbInstructionThreadList;
begin
  Instr := TLldbInstructionThreadList.Create();
  Instr.OnFinish := @ThreadInstructionSucceeded;
  QueueInstruction(Instr);
  Instr.ReleaseReference;
end;

{ TLldbThreads }

function TLldbThreads.GetDebugger: TLldbDebugger;
begin
  Result := TLldbDebugger(inherited Debugger);
end;

procedure TLldbThreads.DoStateEnterPause;
begin
  inherited DoStateEnterPause;
  Changed;
end;

procedure TLldbThreads.ReadFromThreadInstruction(
  Instr: TLldbInstructionThreadList);
var
  i, j, line: Integer;
  s, func, filename, name, d, fullfile: String;
  found, foundFunc, foundArg: TStringArray;
  TId, CurThrId: LongInt;
  CurThr: Boolean;
  Arguments: TStringList;
  addr, stack, frame: TDBGPtr;
  te: TThreadEntry;
begin
  CurrentThreads.Clear;
  for i := 0 to Length(Instr.Res) - 1 do begin
    s := Instr.Res[i];
    ParseNewThreadLocation(s, TId, CurThr, name, addr, stack, frame, func, Arguments, filename, fullfile, line, d);
    if CurThr then
      CurThrId := TId;

    te := CurrentThreads.CreateEntry(
      addr,
      Arguments,
      func,
      filename, fullfile,
      line,
      TId, name, ''
    );
    CurrentThreads.Add(te);
    te.Free;

    Arguments.Free;
  end;

  CurrentThreads.CurrentThreadId := CurThrId;
  CurrentThreads.SetValidity(ddsValid);
end;

procedure TLldbThreads.RequestMasterData;
var
  Cmd: TLldbDebuggerCommandThreads;
  RunCmd: TLldbDebuggerCommand;
  Instr: TLldbInstructionThreadList;
begin
  if not (Debugger.State in [dsPause, dsInternalPause]) then
    exit;

  RunCmd := Debugger.CommandQueue.RunningCommand;
  if (RunCmd <> nil) and (RunCmd is TLldbDebuggerCommandRun) then begin
    Instr := TLldbDebuggerCommandRun(RunCmd).FThreadInstr;
    if (Instr <> nil) and Instr.IsSuccess then begin
      ReadFromThreadInstruction(TLldbInstructionThreadList(Instr));
      exit;
    end;
  end;

  Cmd := TLldbDebuggerCommandThreads.Create(Debugger);
  Debugger.QueueCommand(Cmd);
  Cmd.ReleaseReference;
end;

procedure TLldbThreads.ChangeCurrentThread(ANewId: Integer);
begin
  if Debugger = nil then Exit;
  if not(Debugger.State in [dsPause, dsInternalPause]) then exit;

  Debugger.FCurrentThreadId := ANewId;

  if CurrentThreads <> nil
  then CurrentThreads.CurrentThreadId := ANewId;
end;

{%endregion   ^^^^^  Threads  ^^^^^   }

{%region
  *****
  *****     CallStack
  ***** }

{ TLldbDebuggerCommandCallStack }

procedure TLldbDebuggerCommandCallStack.StackInstructionFinished(Sender: TObject
  );
var
  Instr: TLldbInstructionStackTrace absolute Sender;
  i, FId, line: Integer;
  e: TCallStackEntry;
  found, foundArg: TStringArray;
  Arguments: TStringList;
  It: TMapIterator;
  s, func, filename, d, fullfile: String;
  IsCur: Boolean;
  addr, stack, frame: TDBGPtr;
begin
  if FCurrentCallStack = nil then begin
    Finished;
    exit;
  end;

  It := TMapIterator.Create(FCurrentCallStack.RawEntries);

  for i := 0 to Length(Instr.Res) - 1 do begin
    s := Instr.Res[i];
    ParseNewFrameLocation(s, FId, IsCur, addr, stack, frame, func, Arguments, filename, fullfile, line, d);
    if It.Locate(FId) then begin
      e := TCallStackEntry(It.DataPtr^);
      e.Init(addr, Arguments, func, filename, fullfile, line);
    end;
    Arguments.Free;
  end;
  It.Free;

  TLldbCallStack(Debugger.CallStack).ParentRequestEntries(FCurrentCallStack);

  Finished;
end;

procedure TLldbDebuggerCommandCallStack.DoCallstackFreed(Sender: TObject);
begin
  FCurrentCallStack := nil;
  //TODO cancel
end;

procedure TLldbDebuggerCommandCallStack.DoExecute;
var
  StartIdx, EndIdx: Integer;
  Instr: TLldbInstructionStackTrace;
begin
  if FCurrentCallStack = nil then begin
    Finished;
    exit;
  end;

  StartIdx := Max(FCurrentCallStack.LowestUnknown, 0);
  EndIdx   := FCurrentCallStack.HighestUnknown;
  if EndIdx < StartIdx then begin
    Finished;
    exit;
  end;

  Instr := TLldbInstructionStackTrace.Create(EndIdx+1, FCurrentCallStack.ThreadId);
  Instr.OnFinish := @StackInstructionFinished;
  QueueInstruction(Instr);
  Instr.ReleaseReference;
end;

constructor TLldbDebuggerCommandCallStack.Create(AOwner: TLldbDebugger;
  ACurrentCallStack: TCallStackBase);
begin
  inherited Create(AOwner);
  FCurrentCallStack := ACurrentCallStack;
  FCurrentCallStack.AddFreeNotification(@DoCallstackFreed);
end;

destructor TLldbDebuggerCommandCallStack.Destroy;
begin
  if FCurrentCallStack <> nil then
    FCurrentCallStack.RemoveFreeNotification(@DoCallstackFreed);
  inherited Destroy;
end;

{ TLldbCallStack }

procedure TLldbCallStack.ParentRequestEntries(ACallstack: TCallStackBase);
begin
  inherited RequestEntries(ACallstack);
end;

procedure TLldbCallStack.RequestAtLeastCount(ACallstack: TCallStackBase;
  ARequiredMinCount: Integer);
begin
  if (Debugger = nil) or not(Debugger.State in [dsPause, dsInternalPause]) then begin
    ACallstack.SetCurrentValidity(ddsInvalid);
    Exit;
  end;

  ACallstack.Count := ARequiredMinCount + 1; // TODO: get data, and return correct result
  ACallstack.SetCountValidity(ddsValid);
end;

procedure TLldbCallStack.UpdateCurrentIndex;
var
  tid, idx: Integer;
  cs: TCallStackBase;
begin
  if (Debugger = nil) or not(Debugger.State in [dsPause, dsInternalPause]) then begin
    exit;
  end;

  tid := Debugger.Threads.CurrentThreads.CurrentThreadId; // FCurrentThreadId ?
  cs := TCallStackBase(CurrentCallStackList.EntriesForThreads[tid]);
  idx := cs.NewCurrentIndex;  // NEW-CURRENT

  if TLldbDebugger(Debugger).FCurrentStackFrame = idx then Exit;

  TLldbDebugger(Debugger).FCurrentStackFrame := idx;

  if cs <> nil then begin
    cs.CurrentIndex := idx;
    cs.SetCurrentValidity(ddsValid);
  end;
end;

procedure TLldbCallStack.RequestCurrent(ACallstack: TCallStackBase);
begin
  if (Debugger = nil) or not(Debugger.State in [dsPause, dsInternalPause]) then begin
    ACallstack.SetCurrentValidity(ddsInvalid);
    Exit;
  end;

  ACallstack.CurrentIndex := 0; // will be used, if thread is changed
  ACallstack.SetCurrentValidity(ddsValid);
end;

procedure TLldbCallStack.RequestEntries(ACallstack: TCallStackBase);
var
  Cmd: TLldbDebuggerCommandCallStack;
begin
  if not (Debugger.State in [dsPause, dsInternalPause]) then
    exit;

  Cmd := TLldbDebuggerCommandCallStack.Create(TLldbDebugger(Debugger), ACallstack);
  TLldbDebugger(Debugger).QueueCommand(Cmd);
  Cmd.ReleaseReference;
end;

{%endregion   ^^^^^  CallStack  ^^^^^   }

{ TLldbLocals }

procedure TLldbLocals.RequestData(ALocals: TLocals);
var
  Cmd: TLldbDebuggerCommandLocals;
begin
  if (Debugger = nil) or not(Debugger.State in [dsPause, dsInternalPause]) then Exit;

  Cmd := TLldbDebuggerCommandLocals.Create(TLldbDebugger(Debugger), ALocals);
  TLldbDebugger(Debugger).QueueCommand(Cmd);
  Cmd.ReleaseReference;
end;

{ TLldbWatches }

procedure TLldbWatches.InternalRequestData(AWatchValue: TWatchValue);
var
  Cmd: TLldbDebuggerCommandEvaluate;
begin
  if (Debugger = nil) or not(Debugger.State in [dsPause, dsInternalPause]) then Exit;

  Cmd := TLldbDebuggerCommandEvaluate.Create(TLldbDebugger(Debugger), AWatchValue);
  TLldbDebugger(Debugger).QueueCommand(Cmd);
  Cmd.ReleaseReference;
end;

{ TLldbBreakPoint }

procedure TLldbBreakPoint.SetBreakPoint;
var
  i: Integer;
  s: String;
  Instr: TLldbInstruction;
  en: Boolean;
begin
  debugln(['TLldbBreakPoint.SetBreakPoint ']);

  if FCurrentInstruction <> nil then begin
    if (FBreakID <> 0) or (not FCurrentInstruction.IsRunning) then begin
      // Can be a queued SetBreak => replace
      // Or an Update => don't care, ReleaseBreakpoint will be called
      CancelCurrentInstruction;
    end
    else begin
      // already running a SetBreakPoint
      FNeededChanges := FNeededChanges + [ciLocation]; // wait for instruction to finish // need ID to del
      exit;
    end;
  end;

  if (FBreakID <> 0) then
    ReleaseBreakPoint;

  en := Enabled;
  if TLldbDebugger(Debugger).FLldbMissingBreakSetDisable and (not en) and (Kind <> bpkData) then begin
    en := True;
    FNeededChanges := FNeededChanges + [ciEnabled];
  end;

  case Kind of
    bpkSource: begin
      i := LastPos(PathDelim, Source);
      if i > 0 then
        s := Copy(Source, i+1, Length(Source))
      else
        s := Source;
      Instr := TLldbInstructionBreakSet.Create(s, Line, not en, Expression);
    end;
    bpkAddress: begin
      Instr := TLldbInstructionBreakSet.Create(Address, not en, Expression);
    end;
    bpkData: begin
      if not Enabled then // do not set, if not enabled
        exit;
      // TODO: scope
      // TODO: apply , Expression, not Enabled
      Instr := TLldbInstructionWatchSet.Create(WatchData, WatchKind);
      if Expression <> '' then
        FNeededChanges := FNeededChanges + [ciCondition];
    end;
  end;

  Instr.OnFinish := @InstructionSetBreakFinished;
  TLldbDebugger(Debugger).FDebugInstructionQueue.QueueInstruction(Instr);
  FCurrentInstruction := Instr;
end;

procedure TLldbBreakPoint.InstructionSetBreakFinished(Sender: TObject);
var
  nc: TDbgBpChangeIndicators;
begin
  DoCurrentInstructionFinished;

  if TLldbInstructionBreakOrWatchSet(Sender).LldbNoDisableError then begin
    TLldbDebugger(Debugger).FLldbMissingBreakSetDisable := True;
    FNeededChanges := FNeededChanges + [ciLocation]
  end;

  if TLldbInstructionBreakOrWatchSet(Sender).IsSuccess then begin
    FBreakID := TLldbInstructionBreakOrWatchSet(Sender).BreakId;
    if FNeededChanges * [ciDestroy, ciLocation] = [] then
      SetValid(TLldbInstructionBreakOrWatchSet(Sender).State);
  end
  else
    SetValid(vsInvalid);

  nc := FNeededChanges;
  FNeededChanges := [];
  MarkPropertiesChanged(nc);
end;

procedure TLldbBreakPoint.InstructionUpdateBreakFinished(Sender: TObject);
var
  nc: TDbgBpChangeIndicators;
begin
  DoCurrentInstructionFinished;

  nc := FNeededChanges;
  FNeededChanges := [];
  MarkPropertiesChanged(nc);
end;

procedure TLldbBreakPoint.ReleaseBreakPoint;
var
  Instr: TLldbInstruction;
begin
  CancelCurrentInstruction;

  if FBreakID <= 0 then exit;
  SetHitCount(0);

  case Kind of
  	bpkSource, bpkAddress:
      Instr := TLldbInstructionBreakDelete.Create(FBreakID);
    bpkData:
      Instr := TLldbInstructionWatchDelete.Create(FBreakID);
  end;
  FBreakID := 0; // Allow a new location to be set immediately

  //Instr.OwningCommand := Self;  // if it needs to be cancelled
  TLldbDebugger(Debugger).FDebugInstructionQueue.QueueInstruction(Instr);
  Instr.ReleaseReference;
end;

procedure TLldbBreakPoint.UpdateProperties(AChanged: TDbgBpChangeIndicators);
var
  Instr: TLldbInstruction;
begin
  assert(AChanged * [ciEnabled, ciCondition] <> [], 'break.UpdateProperties() AChanged * [ciEnabled, ciCondition] <> []');

  if (FCurrentInstruction <> nil) then begin
    FNeededChanges := FNeededChanges + AChanged;
    exit;
  end;

  if FBreakID = 0 then // SetBreakPoint may have failed / nothing to do
    exit;

  case Kind of
  	bpkSource, bpkAddress:
      if ciCondition in AChanged
      then Instr := TLldbInstructionBreakModify.Create(FBreakID, not Enabled, Expression)
      else Instr := TLldbInstructionBreakModify.Create(FBreakID, not Enabled);
    bpkData:
    begin
      if Enabled <> (FBreakID <> 0) then begin
        if Enabled
        then SetBreakPoint // will
        else ReleaseBreakPoint;
        exit;
      end;
      if ciCondition in AChanged then
        Instr := TLldbInstructionWatchModify.Create(FBreakID, Expression);
    end;
  end;

  TLldbDebugger(Debugger).FDebugInstructionQueue.QueueInstruction(Instr);
  Instr.OnFinish := @InstructionUpdateBreakFinished;
  FCurrentInstruction := Instr;
end;

procedure TLldbBreakPoint.DoCurrentInstructionFinished;
begin
  if FCurrentInstruction <> nil then begin
    FCurrentInstruction.OnFinish := nil;
    ReleaseRefAndNil(FCurrentInstruction);
  end;
end;

procedure TLldbBreakPoint.CancelCurrentInstruction;
begin
  if FCurrentInstruction <> nil then begin
    FCurrentInstruction.OnFinish := nil;
    FCurrentInstruction.Cancel;
    ReleaseRefAndNil(FCurrentInstruction);
  end;
end;

procedure TLldbBreakPoint.DoStateChange(const AOldState: TDBGState);
begin
  inherited DoStateChange(AOldState);
  case DebuggerState of
    dsRun: if AOldState = dsInit then begin
      // Disabled data breakpoints: wait until enabled
      // Disabled other breakpoints: Give to LLDB to see if they are valid
      SetBreakPoint
    end;
    dsStop: begin
      if FBreakID > 0
      then ReleaseBreakpoint;
    end;
  end;
end;

procedure TLldbBreakPoint.DoPropertiesChanged(AChanged: TDbgBpChangeIndicators);
begin
  FNeededChanges := [];
  if not (DebuggerState in [dsPause, dsInternalPause, dsRun]) then
    exit;

  if ciDestroy in AChanged then begin
    ReleaseBreakPoint;
    DoCurrentInstructionFinished;
    exit;
  end;

  if AChanged * [ciLocation, ciCreated] <> [] then
    SetBreakPoint
  else
    UpdateProperties(AChanged);
end;

destructor TLldbBreakPoint.Destroy;
begin
  DoCurrentInstructionFinished;
  inherited Destroy;
end;

{ TLldbBreakPoints }

function TLldbBreakPoints.FindById(AnId: Integer): TLldbBreakPoint;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do begin
    Result := TLldbBreakPoint(Items[i]);
    if Result.FBreakID = AnId then
      exit;
  end;
  Result := nil;
end;

  {%region
    *****
    *****     Register
    ***** }

{ TLldbDebuggerCommandRegister }

procedure TLldbDebuggerCommandRegister.RegisterInstructionFinished(
  Sender: TObject);
var
  Instr: TLldbInstructionRegister absolute Sender;
  RegVal: TRegisterValue;
  n: String;
  i: Integer;
begin
  if not Instr.IsSuccess then begin
    if FRegisters.DataValidity in [ddsRequested, ddsEvaluating] then
      FRegisters.DataValidity := ddsInvalid;
    exit;
  end;

  FRegisters.DataValidity := ddsEvaluating;

  for i := 0 to Instr.Res.Count - 1 do begin
    n := Instr.Res.Names[i];
    RegVal := FRegisters.EntriesByName[n];
    RegVal.Value := Instr.Res.Values[n];
    RegVal.DataValidity := ddsValid;
  end;

  FRegisters.DataValidity := ddsValid;
  Finished;
end;

procedure TLldbDebuggerCommandRegister.DoExecute;
var
  Instr: TLldbInstructionRegister;
begin
  // TODO: store thread/frame when command is created
  Instr := TLldbInstructionRegister.Create(Debugger.FCurrentThreadId, Debugger.FCurrentStackFrame);
  Instr.OnFinish := @RegisterInstructionFinished;
  QueueInstruction(Instr);
  Instr.ReleaseReference;
end;

constructor TLldbDebuggerCommandRegister.Create(AOwner: TLldbDebugger;
  ARegisters: TRegisters);
begin
  FRegisters := ARegisters;
  FRegisters.AddReference;
  inherited Create(AOwner);
end;

destructor TLldbDebuggerCommandRegister.Destroy;
begin
  ReleaseRefAndNil(FRegisters);
  inherited Destroy;
end;

{ TLldbRegisterSupplier }

procedure TLldbRegisterSupplier.Changed;
begin
  if CurrentRegistersList <> nil
  then CurrentRegistersList.Clear;
end;

procedure TLldbRegisterSupplier.RequestData(ARegisters: TRegisters);
var
  Cmd: TLldbDebuggerCommandRegister;
begin
  if (Debugger = nil) or not(Debugger.State in [dsPause, dsStop]) then
    exit;

  Cmd := TLldbDebuggerCommandRegister.Create(TLldbDebugger(Debugger), ARegisters);
  TLldbDebugger(Debugger).QueueCommand(Cmd);
  Cmd.ReleaseReference;
end;

  {%endregion   ^^^^^  Register  ^^^^^   }

{ TLldbDebuggerCommandQueue }

function TLldbDebuggerCommandQueue.Get(Index: Integer): TLldbDebuggerCommand;
begin
  Result := TLldbDebuggerCommand(inherited Get(Index));
end;

procedure TLldbDebuggerCommandQueue.Put(Index: Integer;
  const AValue: TLldbDebuggerCommand);
begin
  inherited Put(Index, AValue);
end;

procedure TLldbDebuggerCommandQueue.QueueCommand(AValue: TLldbDebuggerCommand);
begin
debugln(['CommandQueue.QueueCommand ', AValue.ClassName]);
  Insert(Count, AValue);
  Run;
end;

procedure TLldbDebuggerCommandQueue.DoLineDataReceived(var ALine: String);
begin
  if FRunningCommand <> nil then
    FRunningCommand.DoLineDataReceived(ALine);
end;

procedure TLldbDebuggerCommandQueue.Run;
begin
  if (FRunningCommand <> nil) or (FLockQueueRun > 0) then
    exit;
  if Count = 0 then
    exit;

  FRunningCommand := Items[0];
  FRunningCommand.AddReference;
  Delete(0);
DebugLnEnter(['||||||||>>> CommandQueue.Run ', FRunningCommand.ClassName, ', ', dbgs(fDebugger.State), ' Cnt:',Count]);
  FRunningCommand.Execute;
  // debugger and queue may get destroyed at the end of execute
end;

procedure TLldbDebuggerCommandQueue.CommandFinished(
  ACommand: TLldbDebuggerCommand);
begin
  if FRunningCommand = ACommand then begin
DebugLnExit(['||||||||<<< CommandQueue.Run ', FRunningCommand.ClassName, ', ', dbgs(fDebugger.State), ' Cnt:',Count]);
    ReleaseRefAndNil(FRunningCommand);
  end//;
else DebugLn(['|||||||| TLldbDebuggerCommandQueue.CommandFinished >> unknown ???', ', ', dbgs(fDebugger.State), ' Cnt:',Count]);
  if not(FDebugger.State in [dsError, dsDestroying, dsNone]) then
    Run;
end;

constructor TLldbDebuggerCommandQueue.Create(ADebugger: TLldbDebugger);
begin
  FDebugger := ADebugger;
  inherited Create;
end;

destructor TLldbDebuggerCommandQueue.Destroy;
begin
  while Count > 0 do
    Delete(0);
  if FRunningCommand <> nil then begin
DebugLnExit(['<<< CommandQueue.Run (Destroy)', FRunningCommand.ClassName, ', ', fDebugger.State]);
    ReleaseRefAndNil(FRunningCommand);
  end;
  inherited Destroy;
end;

procedure TLldbDebuggerCommandQueue.LockQueueRun;
begin
  inc(FLockQueueRun);
  debugln(['TLldbDebuggerCommandQueue.LockQueueRun ',FLockQueueRun]);
end;

procedure TLldbDebuggerCommandQueue.UnLockQueueRun;
begin
  debugln(['TLldbDebuggerCommandQueue.UnLockQueueRun ',FLockQueueRun]);
  dec(FLockQueueRun);
  if FLockQueueRun = 0 then Run;
end;

{ TLldbDebuggerCommand }

function TLldbDebuggerCommand.GetDebuggerState: TDBGState;
begin
  Result := Debugger.State;
end;

procedure TLldbDebuggerCommand.InstructionSucceeded(AnInstruction: TObject);
begin
  Finished;
end;

procedure TLldbDebuggerCommand.InstructionFailed(AnInstruction: TObject);
begin
  SetDebuggerState(dsError);
  Finished;
end;

procedure TLldbDebuggerCommand.Finished;
begin
  InstructionQueue.CancelAllForCommand(Self); // in case there still are any
  CommandQueue.CommandFinished(Self);
end;

function TLldbDebuggerCommand.GetCommandQueue: TLldbDebuggerCommandQueue;
begin
  Result := Debugger.FCommandQueue;
end;

function TLldbDebuggerCommand.GetInstructionQueue: TLldbInstructionQueue;
begin
  Result := Debugger.FDebugInstructionQueue;
end;

procedure TLldbDebuggerCommand.QueueInstruction(AnInstruction: TLldbInstruction);
begin
  AnInstruction.OwningCommand := Self;
  InstructionQueue.QueueInstruction(AnInstruction);
end;

procedure TLldbDebuggerCommand.SetDebuggerState(const AValue: TDBGState);
begin
  Debugger.SetState(AValue);
end;

constructor TLldbDebuggerCommand.Create(AOwner: TLldbDebugger);
begin
  FOwner := AOwner;
  inherited Create;
  AddReference;
end;

destructor TLldbDebuggerCommand.Destroy;
begin
  if InstructionQueue <> nil then
    InstructionQueue.CancelAllForCommand(Self);
  inherited Destroy;
end;

procedure TLldbDebuggerCommand.Execute;
var
  d: TLldbDebugger;
begin
  d := Debugger;
  try
    d.LockRelease;
    DoExecute;  // may call Finished and Destroy Self
  finally
    d.UnlockRelease;
  end;
end;

procedure TLldbDebuggerCommand.DoLineDataReceived(var ALine: String);
begin
  //
end;

{ TLldbDebuggerCommandInit }

procedure TLldbDebuggerCommandInit.DoExecute;
const
  FRAME_INFO =
    '${frame.pc}, {${frame.sp}}, {${frame.fp}}' +
    ' &&//FULL: {${line.file.fullpath}} &&//SHORT: {${line.file.basename}} &&//LINE: {${line.number}}' +
    ' &&//MOD: {${module.file.basename}} &&//FUNC: {${function.name-with-args}}' +
    ' <<&&//FRAME';
var
  Instr: TLldbInstruction;
begin
  Instr := TLldbInstructionSettingSet.Create('frame-format',
    '"frame #${frame.index}: ' + FRAME_INFO + '\n"'
  );
  QueueInstruction(Instr);
  Instr.ReleaseReference;

  Instr := TLldbInstructionSettingSet.Create('thread-format',
    '"thread #${thread.index}: tid=${thread.id%tid}: ' + FRAME_INFO + '\n"'
  );
  QueueInstruction(Instr);
  Instr.ReleaseReference;

  Instr := TLldbInstructionSettingSet.Create('thread-stop-format',
    '"stopped in thread #${thread.index}: tid = ${thread.id%tid}: ' + FRAME_INFO  +
    //'{, activity = ''${thread.info.activity.name}''}{, ${thread.info.trace_messages} messages}' +
    '{, stop reason = ${thread.stop-reason}}' +
    //'{\nReturn value: ${thread.return-value}}{\nCompleted expression: ${thread.completed-expression}}' +
    '\n"'
  );
  QueueInstruction(Instr);
  Instr.ReleaseReference;

  Instr := TLldbInstructionTargetStopHook.Create('thread list');
  QueueInstruction(Instr);
  Instr.ReleaseReference;

  Instr := TLldbInstructionSettingSet.Create('stop-line-count-after', '0');
  QueueInstruction(Instr);
  Instr.ReleaseReference;

  Instr := TLldbInstructionSettingSet.Create('stop-line-count-before', '0');
  QueueInstruction(Instr);
  Instr.ReleaseReference;

  Instr := TLldbInstructionSettingSet.Create('stop-disassembly-count', '0');
  Instr.OnFinish := @InstructionSucceeded;
  QueueInstruction(Instr);
  Instr.ReleaseReference;
end;

{ TLldbDebuggerCommandRunStep }

procedure TLldbDebuggerCommandRunStep.DoExecute;
var
  Instr: TLldbInstructionProcessStep;
begin
  Instr := TLldbInstructionProcessStep.Create(FStepAction);
  Instr.OnFinish := @RunInstructionSucceeded;
  QueueInstruction(Instr);
  Instr.ReleaseReference;
  SetDebuggerState(dsRun);
end;

constructor TLldbDebuggerCommandRunStep.Create(AOwner: TLldbDebugger;
  AStepAction: TLldbInstructionProcessStepAction);
begin
  FStepAction := AStepAction;
  inherited Create(AOwner);
end;

{ TLldbDebuggerCommandRunLaunch }

procedure TLldbDebuggerCommandRunLaunch.TargetCreated(Sender: TObject);
var
  TargetInstr: TLldbInstructionTargetCreate absolute Sender;
  Instr: TLldbInstruction;
  found: TStringArray;
begin
  if not TargetInstr.IsSuccess then begin
    SetDebuggerState(dsError);
    Finished;
  end;

  If StrMatches(TargetInstr.Res, [''{}, '','('{}, ')',''], found) then begin
    if (found[1] = '(i386)') or (found[1] = '(i686)') then begin
      Debugger.FTargetWidth := 32;
      Debugger.FTargetRegisters[0] := '$eax';
      Debugger.FTargetRegisters[1] := '$edx';
      Debugger.FTargetRegisters[2] := '$ecx';
    end
    else
    if (found[1] = '(x86_64)') then begin
      Debugger.FTargetWidth := 64;
      // target list  gives more detailed result. But until remote debugging is added, use the current system
      {$IFDEF MSWindows}
      Debugger.FTargetRegisters[0] := '$rcx';
      Debugger.FTargetRegisters[1] := '$rdx';
      Debugger.FTargetRegisters[2] := '$r8';
      {$ELSE}
      Debugger.FTargetRegisters[0] := '$rdi';
      Debugger.FTargetRegisters[1] := '$rsi';
      Debugger.FTargetRegisters[2] := '$rdx';
      {$ENDIF}
    end
    else found := nil;
  end
  else found := nil;
  if found = nil then begin
    // use architecture of IDE
    {$IFDEF cpu64}
    Debugger.FTargetWidth := 64;
    {$IFDEF MSWindows}
    Debugger.FTargetRegisters[0] := '$rcx';
    Debugger.FTargetRegisters[1] := '$rdx';
    Debugger.FTargetRegisters[2] := '$r8';
    {$ELSE}
    Debugger.FTargetRegisters[0] := '$rdi';
    Debugger.FTargetRegisters[1] := '$rsi';
    Debugger.FTargetRegisters[2] := '$rdx';
    {$ENDIF}
    {$ELSE}
    Debugger.FTargetWidth := 32;
    Debugger.FTargetRegisters[0] := '$eax';
    Debugger.FTargetRegisters[1] := '$edx';
    Debugger.FTargetRegisters[2] := '$ecx';
    {$ENDIF}
  end;

  Instr := TLldbInstructionBreakSet.Create('fpc_raiseexception');
  Instr.OnFinish := @ExceptBreakInstructionFinished;
  QueueInstruction(Instr);
  Instr.ReleaseReference;
end;

procedure TLldbDebuggerCommandRunLaunch.ExceptBreakInstructionFinished(Sender: TObject
  );
var
  ExceptInstr: TLldbInstructionBreakSet absolute Sender;
  Instr: TLldbInstruction;
begin
  Debugger.FExceptionBreakId := ExceptInstr.BreakId;

  Debugger.FExceptionInfo.FReg0Cmd := 'p/x ' + Debugger.FTargetRegisters[0];
  Debugger.FExceptionInfo.FExceptClassCmd := 'p ((char ***)' + Debugger.FTargetRegisters[0] + ')[0][3]';
  Debugger.FExceptionInfo.FExceptMsgCmd := 'p ((char **)' + Debugger.FTargetRegisters[0] + ')[1]';
                // 'p ((EXCEPTION *)' + Debugger.FTargetRegisters[0] + ')->FMESSAGE'
  if ExceptInstr.BreakId > 0 then begin
    Instr := TLldbInstructionBreakAddCommands.Create(ExceptInstr.BreakId, [
      Debugger.FExceptionInfo.FReg0Cmd, Debugger.FExceptionInfo.FExceptClassCmd, Debugger.FExceptionInfo.FExceptMsgCmd
    ]);
    QueueInstruction(Instr);
    Instr.ReleaseReference;
  end;

  SetDebuggerState(dsRun);
  // the state change allows breakpoints to be set, before the run command is issued.

  FRunInstr := TLldbInstructionProcessLaunch.Create();
  FRunInstr.OnSuccess := @RunInstructionSucceeded;
  FRunInstr.OnFailure := @InstructionFailed;
  QueueInstruction(FRunInstr);
  FRunInstr.ReleaseReference;
end;

procedure TLldbDebuggerCommandRunLaunch.DoExecute;
var
  Instr: TLldbInstruction;
begin
  Instr := TLldbInstructionTargetCreate.Create(Debugger.FileName);
  Instr.OnSuccess := @TargetCreated;
  Instr.OnFailure := @InstructionFailed;
  QueueInstruction(Instr);
  Instr.ReleaseReference;
end;

{ TLldbDebuggerCommandStop }

procedure TLldbDebuggerCommandStop.StopInstructionSucceeded(Sender: TObject);
begin
  if DebuggerState <> dsIdle then
    SetDebuggerState(dsStop);
end;

procedure TLldbDebuggerCommandStop.DoExecute;
var
  Instr: TLldbInstruction;
begin
  Instr := TLldbInstructionProcessKill.Create();
  Instr.OnSuccess := @StopInstructionSucceeded;
  Instr.OnFailure := @InstructionFailed;
  QueueInstruction(Instr);
  Instr.ReleaseReference;

  Instr := TLldbInstructionTargetDelete.Create();
  Instr.OnFailure := @InstructionFailed;
  QueueInstruction(Instr);
  Instr.ReleaseReference;

  Instr := TLldbInstructionTargetDelete.Create();
  Instr.OnSuccess := @InstructionSucceeded;
  Instr.OnFailure := @InstructionFailed;
  QueueInstruction(Instr);
  Instr.ReleaseReference;
end;

{ TLldbDebuggerCommandEvaluate }

procedure TLldbDebuggerCommandEvaluate.EvalInstructionSucceeded(Sender: TObject
  );
begin
  if FWatchValue <> nil then begin
    FWatchValue.Value := FInstr.Res;
    //FWatchValue.TypeInfo := TypeInfo;
    FWatchValue.Validity := ddsValid;
  end
  else
  if FCallback <> nil then
    FCallback(Debugger, True, FInstr.Res, nil);

  FInstr.ReleaseReference;
  Finished;
end;

procedure TLldbDebuggerCommandEvaluate.EvalInstructionFailed(Sender: TObject);
begin
  if FWatchValue <> nil then
    FWatchValue.Validity := ddsError
  else
  if FCallback <> nil then
    FCallback(Debugger, False, '', nil);
  FInstr.ReleaseReference;
  Finished;
end;

procedure TLldbDebuggerCommandEvaluate.DoWatchFreed(Sender: TObject);
begin
  FWatchValue := nil;
end;

procedure TLldbDebuggerCommandEvaluate.DoExecute;
begin
  if FWatchValue <> nil then
    FInstr := TLldbInstructionExpression.Create(FWatchValue.Expression, Debugger.FCurrentThreadId, Debugger.FCurrentStackFrame)
  else
    // todo: only if FCallback ?
    FInstr := TLldbInstructionExpression.Create(FExpr, Debugger.FCurrentThreadId, Debugger.FCurrentStackFrame);
  FInstr.OnSuccess := @EvalInstructionSucceeded;
  FInstr.OnFailure := @EvalInstructionFailed;
  QueueInstruction(FInstr);
end;

constructor TLldbDebuggerCommandEvaluate.Create(AOwner: TLldbDebugger;
  AWatchValue: TWatchValue);
begin
  FWatchValue := AWatchValue;
  FWatchValue.AddFreeNotification(@DoWatchFreed);
  inherited Create(AOwner);
end;

constructor TLldbDebuggerCommandEvaluate.Create(AOwner: TLldbDebugger;
  AnExpr: String; AFlags: TDBGEvaluateFlags;
  ACallback: TDBGEvaluateResultCallback);
begin
  FExpr := AnExpr;
  FFlags := AFlags;
  FCallback := ACallback;
  inherited Create(AOwner);
end;

destructor TLldbDebuggerCommandEvaluate.Destroy;
begin
  if FWatchValue <> nil then
    FWatchValue.RemoveFreeNotification(@DoWatchFreed);
  inherited Destroy;
end;

{ TLldbDebugger }

function TLldbDebugger.LldbRun: Boolean;
var
  Cmd: TLldbDebuggerCommandRunLaunch;
begin
  DebugLn('*** Run');
  Result := True;

  if State in [dsPause, dsInternalPause, dsRun] then begin // dsRun in case of exception
    LldbStep(saContinue);
    exit;
  end;

  if State in [dsNone, dsIdle, dsStop] then
    SetState(dsInit);

  Cmd := TLldbDebuggerCommandRunLaunch.Create(Self);
  QueueCommand(Cmd);
  Cmd.ReleaseReference;
end;

procedure TLldbDebugger.DoAfterLineReceived(var ALine: String);
var
  Instr: TLldbInstruction;
begin
  if ALine = '' then
    exit;

  FCommandQueue.DoLineDataReceived(ALine);
  if ALine = '' then
    exit;


  // Process 8888 exited with status = 0 (0x00000000)
  if (LeftStr(ALine, 8) = 'Process ') and (pos('exited with status = ', ALine) > 0) then begin
// todo: target delete
    if State <> dsIdle then
      SetState(dsStop);
    ALine := '';

    Instr := TLldbInstructionTargetDelete.Create();
    FDebugInstructionQueue.QueueInstruction(Instr);
    Instr.ReleaseReference;
    exit;
  end;

end;

procedure TLldbDebugger.DoBeforeLineReceived(var ALine: String);
begin
  DoDbgOutput(ALine);
end;

procedure TLldbDebugger.DoBeginReceivingLines(Sender: TObject);
begin
  LockRelease;
end;

procedure TLldbDebugger.DoCmdLineDebuggerTerminated(Sender: TObject);
begin
  SetState(dsError);
end;

procedure TLldbDebugger.DoLineSentToDbg(Sender: TObject; ALine: String);
begin
  DoDbgOutput('>> '+ALine);
end;

procedure TLldbDebugger.DoEndReceivingLines(Sender: TObject);
begin
  UnlockRelease;
end;

function TLldbDebugger.LldbStep(AStepAction: TLldbInstructionProcessStepAction
  ): Boolean;
var
  Cmd: TLldbDebuggerCommandRunStep;
begin
  // TODO
  Result := True;
  Cmd := TLldbDebuggerCommandRunStep.Create(Self, AStepAction);
  QueueCommand(Cmd);
  Cmd.ReleaseReference;
end;

function TLldbDebugger.LldbStop: Boolean;
var
  Cmd: TLldbDebuggerCommandStop;
begin
  DebugLn('*** Stop');
  Result := True;

  Cmd := TLldbDebuggerCommandStop.Create(Self);
  QueueCommand(Cmd);
  Cmd.ReleaseReference;
end;

function TLldbDebugger.LldbEvaluate(const AExpression: String;
  EvalFlags: TDBGEvaluateFlags; ACallback: TDBGEvaluateResultCallback): Boolean;
var
  Cmd: TLldbDebuggerCommandEvaluate;
begin
  Cmd := TLldbDebuggerCommandEvaluate.Create(Self, AExpression, EvalFlags, ACallback);
  QueueCommand(Cmd);
  Cmd.ReleaseReference;
  Result := True;
end;

procedure TLldbDebugger.LockRelease;
begin
  inherited LockRelease;
end;

procedure TLldbDebugger.UnlockRelease;
begin
  inherited UnlockRelease;
end;

procedure TLldbDebugger.QueueCommand(const ACommand: TLldbDebuggerCommand);
begin
  FCommandQueue.QueueCommand(ACommand);
end;

procedure TLldbDebugger.SetState(const AValue: TDBGState);
begin
  if AValue = dsRun then
    FExceptionInfo.FAtExcepiton := False;
  inherited;
end;

function TLldbDebugger.DoExceptionHit(AExcClass, AExcMsg: String): Boolean;
begin
  FExceptionInfo.FAtExcepiton := True;

  if Assigned(EventLogHandler) then
    EventLogHandler.LogCustomEvent(ecDebugger, etExceptionRaised,
      Format('Exception class "%s" at $%.' + IntToStr(TargetWidth div 4) + 'x with message "%s"',
      [AExcClass, FCurrentLocation.Address, AExcMsg]));

  if Assigned(OnException) then
    OnException(Self, deInternal, AExcClass, FCurrentLocation, AExcMsg, Result) // TODO: Location
  else
    Result := True; // CanContinue
end;

function TLldbDebugger.DoBreakpointHit(BrkId: Integer): Boolean;
var
  BreakPoint: TLldbBreakPoint;
begin
  if (BrkId >= 0) then
    BreakPoint := TLldbBreakPoints(BreakPoints).FindById(BrkId)
  else
    BreakPoint := nil;

  if Assigned(EventLogHandler) then
    EventLogHandler.LogEventBreakPointHit(Breakpoint, FCurrentLocation);

  if BreakPoint <> nil then begin
    if (BreakPoint.Valid = vsPending) then
      BreakPoint.SetPendingToValid(vsValid);

    try
      BreakPoint.AddReference;

      // Important: The Queue must be unlocked
      //   BreakPoint.Hit may evaluate stack and expressions
      //   SetDebuggerState may evaluate data for Snapshot
      Result := False; // Result;
      BreakPoint.Hit(Result);
    finally
      BreakPoint.ReleaseReference;
    end;

  end
  else
  if (State = dsRun)
  then begin
    debugln(['********** WARNING: breakpoint hit, but nothing known about it ABreakId=', BrkId]);
  end;
end;

function TLldbDebugger.CreateBreakPoints: TDBGBreakPoints;
begin
  Result := TLldbBreakPoints.Create(Self, TLldbBreakPoint);
end;

function TLldbDebugger.CreateLocals: TLocalsSupplier;
begin
  Result := TLldbLocals.Create(Self);
end;

function TLldbDebugger.CreateRegisters: TRegisterSupplier;
begin
  Result := TLldbRegisterSupplier.Create(Self);
end;

function TLldbDebugger.CreateCallStack: TCallStackSupplier;
begin
  Result := TLldbCallStack.Create(Self);
end;

function TLldbDebugger.CreateWatches: TWatchesSupplier;
begin
  Result := TLldbWatches.Create(Self);
end;

function TLldbDebugger.CreateThreads: TThreadsSupplier;
begin
  Result := TLldbThreads.Create(Self);
end;

function TLldbDebugger.GetTargetWidth: Byte;
begin
  Result := FTargetWidth;
end;

function TLldbDebugger.GetSupportedCommands: TDBGCommands;
begin
  Result := [dcRun, dcStop, dcStepOver, dcStepInto, dcStepOut, dcEvaluate];
//  Result := [dcPause, dcStepOverInstr, dcStepIntoInstr, dcRunTo, dcAttach, dcDetach, dcJumpto,
//             dcBreak, dcWatch, dcLocal, dcEvaluate, dcModify, dcEnvironment,
//             dcSetStackFrame, dcDisassemble
//            ];
end;

function TLldbDebugger.RequestCommand(const ACommand: TDBGCommand;
  const AParams: array of const; const ACallback: TMethod): Boolean;
var
  EvalFlags: TDBGEvaluateFlags;
begin
  LockRelease;
  try
    case ACommand of
      dcRun:         Result := LldbRun;
      //dcPause:       Result := ;
      dcStop:        Result := LldbStop;
      dcStepOver:    Result := LldbStep(saOver);
      dcStepInto:    Result := LldbStep(saInto);
      dcStepOut:     Result := LldbStep(saOut);
      dcEvaluate:    begin
                       EvalFlags := [];
                       if high(AParams) >= 1 then
                         EvalFlags := TDBGEvaluateFlags(AParams[1].VInteger);
                       Result := LldbEvaluate(String(AParams[0].VAnsiString),
                         EvalFlags, TDBGEvaluateResultCallback(ACallback));
                     end;
//      dcRunTo:       Result := GDBRunTo(String(AParams[0].VAnsiString), AParams[1].VInteger);
//      dcJumpto:      Result := GDBJumpTo(String(AParams[0].VAnsiString), AParams[1].VInteger);
//      dcAttach:      Result := GDBAttach(String(AParams[0].VAnsiString));
//      dcDetach:      Result := GDBDetach;
//      dcModify:      Result := GDBModify(String(AParams[0].VAnsiString), String(AParams[1].VAnsiString));
//      dcEnvironment: Result := GDBEnvironment(String(AParams[0].VAnsiString), AParams[1].VBoolean);
//      dcDisassemble: Result := GDBDisassemble(AParams[0].VQWord^, AParams[1].VBoolean, TDbgPtr(AParams[2].VPointer^),
//                                              String(AParams[3].VPointer^), String(AParams[4].VPointer^),
//                                              String(AParams[5].VPointer^), Integer(AParams[6].VPointer^))
//                                              {%H-};
//      dcStepOverInstr: Result := GDBStepOverInstr;
//      dcStepIntoInstr: Result := GDBStepIntoInstr;
    end;
  finally
    UnlockRelease;
  end;
end;

class function TLldbDebugger.Caption: String;
begin
  Result := 'LLDB Debugger (Alpha)';
end;

constructor TLldbDebugger.Create(const AExternalDebugger: String);
begin
  inherited Create(AExternalDebugger);
  FDebugProcess := TDebugProcess.Create(AExternalDebugger);
  FDebugProcess.OnLineSent := @DoLineSentToDbg;

  FDebugInstructionQueue := TLldbInstructionQueue.Create(FDebugProcess);
  FDebugInstructionQueue.OnBeginLinesReceived := @DoBeginReceivingLines;
  FDebugInstructionQueue.OnEndLinesReceived := @DoEndReceivingLines;
  FDebugInstructionQueue.OnBeforeHandleLineReceived := @DoBeforeLineReceived;
  FDebugInstructionQueue.OnAfterHandleLineReceived := @DoAfterLineReceived;
  FDebugInstructionQueue.OnDebuggerTerminated := @DoCmdLineDebuggerTerminated;

  FCommandQueue := TLldbDebuggerCommandQueue.Create(Self);
end;

destructor TLldbDebugger.Destroy;
begin
debugln(['!!!!!!!!!!!!!!! TLldbDebugger.Destroy ']);
  FDebugInstructionQueue.LockQueueRun;
  inherited Destroy;
  FCommandQueue.Destroy;
  FDebugInstructionQueue.Destroy;
  FDebugProcess.Destroy;
end;

procedure TLldbDebugger.Init;
var
  Cmd: TLldbDebuggerCommandInit;
begin
  FDebugProcess.CreateDebugProcess('', Environment);
  inherited Init;

  Cmd := TLldbDebuggerCommandInit.Create(Self);
  QueueCommand(Cmd);
  Cmd.ReleaseReference;
end;

procedure TLldbDebugger.Done;
begin
  DebugLnEnter('!!! TLldbDebugger.Done;');
  // TODO: cancel all commands
  if FDebugProcess.DebugProcessRunning then begin
    FDebugProcess.SendCmdLn('process kill');
    FDebugProcess.SendCmdLn('quit');
  end;

  FDebugInstructionQueue.OnDebuggerTerminated := nil;  // TODO: use a flag to prevent this
  FDebugProcess.StopDebugProcess;
  FDebugInstructionQueue.OnDebuggerTerminated := @DoCmdLineDebuggerTerminated;
  inherited Done;
  DebugLnExit('!!! TLldbDebugger.Done;');
end;

class function TLldbDebugger.RequiredCompilerOpts(ATargetCPU, ATargetOS: String
  ): TDebugCompilerRequirements;
begin
  Result:=[dcrDwarfOnly];
end;

function TLldbDebugger.GetLocation: TDBGLocationRec;
begin
  Result := FCurrentLocation;
end;

procedure TLldbDebugger.TestCmd(const ACommand: String);
begin
  FDebugProcess.SendCmdLn(ACommand);
end;

procedure Register;
begin
  RegisterDebugger(TLldbDebugger);
end;

end.

