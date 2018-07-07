{
 /***************************************************************************
                    CocoaCaret.pas  -  Cocoa Caret Emulation
                    ------------------------------------------

 copyright (c) Andreas Hausladen

 adopted for Lazarus and Cocoa by Lazarus Team

 ***************************************************************************/

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

unit CocoaCaret;
{$mode objfpc}{$H+}
{$modeswitch objectivec1}

interface

uses
  // Bindings
  CocoaAll,
  // Free Pascal
  Classes, SysUtils, Types,
  // Widgetset
  CocoaGDIObjects, CocoaPrivate;

type

  { TEmulatedCaret }

  TEmulatedCaret = class(TObject)
  private
    FTimerTarget: NSObject;
    FTimer: NSTimer;
    FOldRect: TRect;
    FView: NSView;
    FBitmap: TCocoaBitmap;
    FWidth, FHeight: Integer;
    FPos: TPoint;
    FVisible: Boolean;
    FVisibleRealized: Boolean;
    FVisibleState: Boolean;
    FRespondToFocus: Boolean;
    FCaretCS: System.PRTLCriticalSection;
    FWidgetSetReleased: Boolean;
    procedure SetPos(const Value: TPoint);
    procedure UpdateCall(Data: PtrInt);
  protected
    procedure DoTimer(Sender: TObject);
    procedure DrawCaret; virtual;
    procedure SetView(AView: NSView);
    procedure UpdateCaret;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Lock;
    procedure UnLock;

    function CreateCaret(AView: NSView; Bitmap: PtrUInt; Width, Height: Integer): Boolean;
    function DestroyCaret: Boolean;

    function IsValid: Boolean;

    function Show(AView: NSView): Boolean;
    function Hide: Boolean;

    property Pos: TPoint read FPos write SetPos;
    property RespondToFocus: Boolean read FRespondToFocus write FRespondToFocus;
  end;

function CreateCaret(View: NSView; Bitmap: PtrUInt; Width, Height: Integer): Boolean; overload;
function HideCaret(View: NSView): Boolean;
function ShowCaret(View: NSView): Boolean;
function SetCaretPos(X, Y: Integer): Boolean;
function GetCaretPos(var P: TPoint): Boolean;
function GetCocoaCaretRespondToFocus: Boolean;
procedure SetCocoaCaretRespondToFocus(Value: Boolean);
function DestroyCaret: Boolean;
procedure DrawCaret;
procedure DestroyGlobalCaret;
//todo: make a better solution for the Viewset released before GlobalCaret
procedure CaretViewSetReleased;

implementation

type
  { TCaretTimerTarget }

  TCaretTimerTarget = objcclass(NSObject)
    fCaret: TEmulatedCaret;
    procedure CaretEvent(sender: id); message 'CaretEvent:';
  end;

var
  GlobalCaret: TEmulatedCaret = nil;

procedure GlobalCaretNeeded;
begin
  if GlobalCaret = nil then GlobalCaret := TEmulatedCaret.Create;
end;

procedure DrawCaret;
begin
  GlobalCaretNeeded;
  if Assigned(GlobalCaret) then
  begin
    GlobalCaret.Lock;
    try
      GlobalCaret.DrawCaret;
    finally
      GlobalCaret.UnLock;
    end;
  end;
end;

procedure DestroyGlobalCaret;
begin
  FreeAndNil(GlobalCaret);
end;

function CreateCaret(View: NSView; Bitmap: PtrUInt; Width, Height: Integer): Boolean;
begin
  GlobalCaretNeeded;

  if Assigned(GlobalCaret) then
  begin
    GlobalCaret.Lock;
    try
      Result := GlobalCaret.CreateCaret(View, Bitmap, Width, Height);
    finally
      GlobalCaret.UnLock;
    end;
  end;
end;

function GetCaretBlinkTime: Cardinal;
begin
  // TODO: use MacOSAll.GetCaretTime
  Result := 600; // our default value
end;

function HideCaret(View: NSView): Boolean;
begin
  Result := False;
  GlobalCaretNeeded;
  
  if Assigned(GlobalCaret) then
  begin
    GlobalCaret.Lock;
    try
      Result := GlobalCaret.Hide;
    finally
      GlobalCaret.UnLock;
    end;
  end;
end;

function ShowCaret(View: NSView): Boolean;
begin
  Result := False;
  GlobalCaretNeeded;

  if Assigned(GlobalCaret) then
  begin
    GlobalCaret.Lock;
    try
      Result := GlobalCaret.Show(View);
    finally
      GlobalCaret.UnLock;
    end;
  end;
end;

function SetCaretPos(X, Y: Integer): Boolean;
begin
  Result := True;
  GlobalCaretNeeded;

  if Assigned(GlobalCaret) then
  begin
    GlobalCaret.Lock;
    try
      GlobalCaret.Pos := Classes.Point(X, Y);
    finally
      GlobalCaret.UnLock;
    end;
  end;
end;

function GetCaretPos(var P: TPoint): Boolean;
begin
  Result := True;
  GlobalCaretNeeded;
  
  if Assigned(GlobalCaret) then
  begin
    GlobalCaret.Lock;
    try
      with GlobalCaret.Pos do
      begin
        P.x := X;
        P.y := Y;
      end;
    finally
      GlobalCaret.UnLock;
    end;
  end;
end;

function GetCocoaCaretRespondToFocus: Boolean;
begin
  Result := GlobalCaret.RespondToFocus;
end;

procedure SetCocoaCaretRespondToFocus(Value: Boolean);
begin
  GlobalCaret.RespondToFocus := Value;
end;

function DestroyCaret: Boolean;
begin
  Result := False;
   
  if Assigned(GlobalCaret) then
  begin
    GlobalCaret.Lock;
    try
      Result := GlobalCaret.DestroyCaret;
    finally
      GlobalCaret.UnLock;
    end;
  end;
end;

procedure CocoaDisableTimer(var ATimer: NSTimer);
begin
  if not Assigned(ATimer) then Exit;
  ATimer.invalidate;
  ATimer := nil;
end;

function CocoaEnableTimer(trg: id): NSTimer;
begin
  Result:=NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats(
    GetCaretBlinkTime / 1000, trg, ObjCSelector('CaretEvent:'), nil, true);
end;

{ TCaretTimerTarget }

procedure TCaretTimerTarget.CaretEvent(sender: id);
begin
  if not Assigned(fCaret) then Exit;
  fCaret.DoTimer(nil);
end;

{ TEmulatedCaret }

constructor TEmulatedCaret.Create;
begin
  inherited Create;

  FOldRect := Rect(0, 0, 1, 1);

  FTimerTarget := TCaretTimerTarget.alloc.init;
  TCaretTimerTarget(FTimerTarget).fCaret := Self;

  FVisibleRealized := True;
  
  FRespondToFocus := False;
  
  New(FCaretCS);
  System.InitCriticalSection(FCaretCS^);
end;

destructor TEmulatedCaret.Destroy;
begin
  DestroyCaret;
  
  System.DoneCriticalsection(FCaretCS^);
  Dispose(FCaretCS);
  FTimerTarget.release;

  inherited Destroy;
end;

procedure TEmulatedCaret.Lock;
begin
  System.EnterCriticalsection(FCaretCS^);
end;

procedure TEmulatedCaret.UnLock;
begin
  System.LeaveCriticalsection(FCaretCS^);
end;

function TEmulatedCaret.CreateCaret(AView: NSView; Bitmap: PtrUInt;
  Width, Height: Integer): Boolean;
begin
  DestroyCaret;
  SetView(AView);
  
  FWidth := Width;
  FHeight := Height;
  if Bitmap > 1 then
    FBitmap := TCocoaBitmap.Create(TCocoaBitmap(Bitmap))
  else
    FBitmap := nil;

  Result := IsValid;
end;

function TEmulatedCaret.DestroyCaret: Boolean;
begin
  if FTimer<>nil then begin
    CocoaDisableTimer(FTimer);
  end;
  FVisible := False;
  FVisibleRealized := False;
  FVisibleState := False;
  UpdateCaret;
  
  FreeAndNil(FBitmap);
  FView := nil;
  FWidth := 0;
  FHeight := 0;
  Result := not IsValid;
end;

procedure TEmulatedCaret.DrawCaret;
begin
  //DebugLn('DrawCaret ' + DbgSName(FView.LCLObject) + ' ' + DbgS(FPos) + ' ' + DbgS(FVisible) + ' ' + DbgS(FVisibleState));
  if IsValid and FVisible and FVisibleState and FView.lclIsPainting then
  begin
    if FBitmap = nil then
      FView.lclGetCallback.GetContext.InvertRectangle(FPos.X, FPos.Y,
        FPos.X + FWidth, FPos.Y + FHeight)
    else
      FView.lclGetCallback.GetContext.DrawBitmap(FPos.X, FPos.Y,
        FBitmap);
  end;
end;

function TEmulatedCaret.Show(AView: NSView): Boolean;
begin
  Result := False;
  if AView = nil then Exit;

  //DebugLn('ShowCaret ' + DbgSName(AView.LCLObject));
  
  if FView <> AView then
  begin
    Hide;
    SetView(AView);
    
    UpdateCaret;
  end;
  
  Result := IsValid;
  
  if Result then
  begin
    if FVisible then Exit;
    
    FVisible := True;
    CocoaDisableTimer(FTimer);
    FTimer:=CocoaEnableTimer(FTimerTarget);
    if FVisibleRealized then
    begin
      FVisibleState := True;
      FVisibleRealized := True;
    end;

    UpdateCaret;
  end;
end;

function TEmulatedCaret.Hide: Boolean;
begin
  Result := IsValid;
  
  if FVisible then
  begin
    CocoaDisableTimer(FTimer);
    FVisible := False;
    UpdateCaret;
    FVisibleRealized := (FView = nil) or not FView.lclIsPainting;
  end;
end;

procedure TEmulatedCaret.SetPos(const Value: TPoint);
begin
  //DebugLn('SetCaretPos ' + DbgSName(FView.LCLObject));
  if FView = nil then
  begin
    FPos.X := 0;
    FPos.Y := 0;
    Exit;
  end;
  
  if ((FPos.x <> Value.x) or (FPos.y <> Value.y)) then
  begin
    FPos := Value;
    CocoaDisableTimer(FTimer);
    FTimer:=CocoaEnableTimer(FTimerTarget);
    if not FView.lclIsPainting then FVisibleState := True;
    UpdateCaret;
  end;
end;

procedure TEmulatedCaret.DoTimer(Sender: TObject);
begin
  FVisibleState := not FVisibleState;
  if FVisible then UpdateCaret;
end;

function TEmulatedCaret.IsValid: Boolean;
begin
  Result := (FWidth > 0) and (FHeight > 0) and (FView <> nil) and FView.lclIsVisible
    and Assigned(FView.lclGetTarget);
end;

procedure TEmulatedCaret.SetView(AView: NSView);
begin
  if FView <> nil then FView.lclGetCallback.HasCaret := False;

  FView := AView;
  if FView <> nil then FView.lclGetCallback.HasCaret := True;
  CocoaDisableTimer(FTimer);
  if Assigned(FView) then
    FTimer:=CocoaEnableTimer(FTimerTarget);
end;

procedure TEmulatedCaret.UpdateCaret;
var
  R: TRect;
begin
  if (FView = nil) or FWidgetSetReleased then Exit;
  if FView.lclIsPainting then Exit;
  if not IsValid then Exit;

  //DebugLn('UpdateCaret ' + DbgSName(FView.LCLObject) + ' ' + DbgS(FPos) + ' ' + DbgS(FVisible) + ' ' + DbgS(FVisibleState));
  R.Left := FPos.x;
  R.Top := FPos.y;
  R.Right := R.Left + FWidth + 2;
  R.Bottom := R.Top + FHeight + 2;
  
  if not EqualRect(FOldRect, R) then FView.lclInvalidateRect(FOldRect);
  FView.lclInvalidateRect(R);
  FView.lclUpdate;
    
  FOldRect := R;
end;

procedure TEmulatedCaret.UpdateCall(Data: PtrInt);
begin
  UpdateCaret;
end;

procedure CaretViewSetReleased;
begin
  if Assigned(GlobalCaret) then
  begin
    CocoaDisableTimer(GlobalCaret.fTimer);
    GlobalCaret.FWidgetSetReleased:=True;
  end;
end;

finalization
  DestroyGlobalCaret;

end.
