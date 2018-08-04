{ $Id: $}
{                  --------------------------------------------
                  cocoatables.pas  -  Cocoa internal classes
                  --------------------------------------------

 This unit contains the private classhierarchy for the Cocoa implemetations

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit CocoaTables;

{$mode objfpc}{$H+}
{$modeswitch objectivec1}
{$modeswitch objectivec2}
{$interfaces corba}

{.$DEFINE COCOA_DEBUG_LISTVIEW}

interface

uses
  // rtl+ftl
  Types, Classes, SysUtils,
  CGGeometry,
  // Libs
  MacOSAll, CocoaAll, CocoaUtils, CocoaGDIObjects,
  cocoa_extra, CocoaPrivate,
  // LCL
  LMessages, LCLMessageGlue, ExtCtrls,
  LCLType, LCLProc, Controls, StdCtrls;

type

  { IListBoxCallBack }

  IListBoxCallBack = interface(ICommonCallback)
    procedure SelectionChanged;
  end;

  { IListViewCallBack }

  IListViewCallBack = interface(ICommonCallback)
    procedure delayedSelectionDidChange_OnTimer(ASender: TObject);

    function ItemsCount: Integer;
    function GetItemTextAt(ARow, ACol: Integer; var Text: String): Boolean;
    procedure tableSelectionChange(ARow: Integer);
  end;

  TCocoaListBox = objcclass;

  { TCocoaStringList }

  TCocoaStringList = class(TStringList)
  protected
    procedure Changed; override;
  public
    Owner: TCocoaListBox;
    constructor Create(AOwner: TCocoaListBox);
  end;

  { TCocoaListBox }

  TCocoaListBox = objcclass(NSTableView, NSTableViewDelegateProtocol, NSTableViewDataSourceProtocol)
  public
    callback: IListBoxCallback;
    resultNS: NSString;
    list: TCocoaStringList;
    isCustomDraw: Boolean;
    function acceptsFirstResponder: Boolean; override;
    function becomeFirstResponder: Boolean; override;
    function resignFirstResponder: Boolean; override;
    function lclGetCallback: ICommonCallback; override;
    procedure lclClearCallback; override;
    function numberOfRowsInTableView(aTableView: NSTableView): NSInteger; message 'numberOfRowsInTableView:';

    function tableView_shouldEditTableColumn_row(tableView: NSTableView;
      tableColumn: NSTableColumn; row: NSInteger): Boolean;
      message 'tableView:shouldEditTableColumn:row:';

    function tableView_objectValueForTableColumn_row(tableView: NSTableView;
      objectValueForTableColumn: NSTableColumn; row: NSInteger):id;
      message 'tableView:objectValueForTableColumn:row:';

    procedure tableViewSelectionDidChange(notification: NSNotification); message 'tableViewSelectionDidChange:';

    procedure drawRow_clipRect(row: NSInteger; clipRect: NSRect); override;

    procedure dealloc; override;
    procedure resetCursorRects; override;

    // mouse
    procedure mouseDown(event: NSEvent); override;
    // procedure mouseUp(event: NSEvent); override;   This is eaten by NSTableView - worked around with NSTableViewDelegateProtocol
    procedure rightMouseDown(event: NSEvent); override;
    procedure rightMouseUp(event: NSEvent); override;
    procedure otherMouseDown(event: NSEvent); override;
    procedure otherMouseUp(event: NSEvent); override;
    procedure mouseDragged(event: NSEvent); override;
    procedure mouseEntered(event: NSEvent); override;
    procedure mouseExited(event: NSEvent); override;
    procedure mouseMoved(event: NSEvent); override;
    // key
    procedure keyDown(event: NSEvent); override;
    procedure keyUp(event: NSEvent); override;
    function lclIsHandle: Boolean; override;
  end;

  { TCocoaCheckListBox }

  TCocoaCheckListBox = objcclass(TCocoaListBox)
  private
    chkid : NSString;
    txtid : NSString;
  public
    // LCL functions
    AllowMixedState: Boolean;
    function initWithFrame(ns: NSRect): id; override;
    procedure dealloc; override;
    class function LCLCheckStateToCocoa(ALCLState: TCheckBoxState): NSInteger; message 'LCLCheckStateToCocoa:';
    class function CocoaCheckStateToLCL(ACocoaState: NSInteger): TCheckBoxState; message 'CocoaCheckStateToLCL:';
    function CheckListBoxGetNextState(ACurrent: TCheckBoxState): TCheckBoxState; message 'CheckListBoxGetNextState:';
    function GetCocoaState(const AIndex: integer): NSInteger; message 'GetCocoaState:';
    procedure SetCocoaState(const AIndex: integer; AState: NSInteger); message 'SetCocoaState:AState:';
    function GetState(const AIndex: integer): TCheckBoxState; message 'GetState:';
    procedure SetState(const AIndex: integer; AState: TCheckBoxState); message 'SetState:AState:';
    // Cocoa functions
    function tableView_objectValueForTableColumn_row(tableView: NSTableView;
      objectValueForTableColumn: NSTableColumn; row: NSInteger):id;
      override;
    procedure tableView_setObjectValue_forTableColumn_row(tableView: NSTableView;
      object_: id; tableColumn: NSTableColumn; row: NSInteger);
      message 'tableView:setObjectValue:forTableColumn:row:';
    function tableView_dataCellForTableColumn_row(tableView: NSTableView;
      tableColumn: NSTableColumn; row: NSInteger): NSCell;
      message 'tableView:dataCellForTableColumn:row:';
  end;

  { TListView }

  { TCocoaTableListView }

  TCocoaTableListView = objcclass(NSTableView, NSTableViewDelegateProtocol, NSTableViewDataSourceProtocol)
  public
    callback: IListViewCallback;

    // Owned Pascal classes which need to be released
    //Items: TStringList; // Object are TStringList for sub-items
    Timer: TTimer;
    readOnly: Boolean;

    function acceptsFirstResponder: Boolean; override;
    function becomeFirstResponder: Boolean; override;
    function resignFirstResponder: Boolean; override;
    function lclGetCallback: ICommonCallback; override;
    procedure lclClearCallback; override;

    // Own methods, mostly convenience methods
    //procedure setStringValue_forCol_row(AStr: NSString; col, row: NSInteger); message 'setStringValue:forCol:row:';
    //procedure deleteItemForRow(row: NSInteger); message 'deleteItemForRow:';
    //procedure setListViewStringValue_forCol_row(AStr: NSString; col, row: NSInteger); message 'setListViewStringValue:forCol:row:';
    function getIndexOfColumn(ACol: NSTableColumn): NSInteger; message 'getIndexOfColumn:';
    procedure reloadDataForRow_column(ARow, ACol: NSInteger); message 'reloadDataForRow:column:';
    procedure scheduleSelectionDidChange(); message 'scheduleSelectionDidChange';

    procedure dealloc; override;
    procedure resetCursorRects; override;

    // mouse
    procedure mouseDown(event: NSEvent); override;
    // procedure mouseUp(event: NSEvent); override;   This is eaten by NSTableView - worked around with NSTableViewDelegateProtocol
    procedure rightMouseDown(event: NSEvent); override;
    procedure rightMouseUp(event: NSEvent); override;
    procedure otherMouseDown(event: NSEvent); override;
    procedure otherMouseUp(event: NSEvent); override;
    procedure mouseDragged(event: NSEvent); override;
    procedure mouseEntered(event: NSEvent); override;
    procedure mouseExited(event: NSEvent); override;
    procedure mouseMoved(event: NSEvent); override;
    // key
    procedure keyDown(event: NSEvent); override;
    procedure keyUp(event: NSEvent); override;
    function lclIsHandle: Boolean; override;

    // NSTableViewDataSourceProtocol
    function numberOfRowsInTableView(tableView: NSTableView): NSInteger; message 'numberOfRowsInTableView:';
    function tableView_objectValueForTableColumn_row(tableView: NSTableView; tableColumn: NSTableColumn; row: NSInteger): id; message 'tableView:objectValueForTableColumn:row:';
    procedure tableView_setObjectValue_forTableColumn_row(tableView: NSTableView; object_: id; tableColumn: NSTableColumn; row: NSInteger); message 'tableView:setObjectValue:forTableColumn:row:';
    //procedure tableView_sortDescriptorsDidChange(tableView: NSTableView; oldDescriptors: NSArray); message 'tableView:sortDescriptorsDidChange:';
    //function tableView_writeRowsWithIndexes_toPasteboard(tableView: NSTableView; rowIndexes: NSIndexSet; pboard: NSPasteboard): Boolean; message 'tableView:writeRowsWithIndexes:toPasteboard:';
    //function tableView_validateDrop_proposedRow_proposedDropOperation(tableView: NSTableView; info: NSDraggingInfoProtocol; row: NSInteger; dropOperation: NSTableViewDropOperation): NSDragOperation; message 'tableView:validateDrop:proposedRow:proposedDropOperation:';
    //function tableView_acceptDrop_row_dropOperation(tableView: NSTableView; info: NSDraggingInfoProtocol; row: NSInteger; dropOperation: NSTableViewDropOperation): Boolean; message 'tableView:acceptDrop:row:dropOperation:';
    //function tableView_namesOfPromisedFilesDroppedAtDestination_forDraggedRowsWithIndexes(tableView: NSTableView; dropDestination: NSURL; indexSet: NSIndexSet): NSArray; message 'tableView:namesOfPromisedFilesDroppedAtDestination:forDraggedRowsWithIndexes:';

    // NSTableViewDelegateProtocol
    //procedure tableView_willDisplayCell_forTableColumn_row(tableView: NSTableView; cell: id; tableColumn: NSTableColumn; row: NSInteger); message 'tableView:willDisplayCell:forTableColumn:row:';
    function tableView_shouldEditTableColumn_row(tableView: NSTableView; tableColumn: NSTableColumn; row: NSInteger): Boolean; message 'tableView:shouldEditTableColumn:row:';
    {function selectionShouldChangeInTableView(tableView: NSTableView): Boolean; message 'selectionShouldChangeInTableView:';
    function tableView_shouldSelectRow(tableView: NSTableView; row: NSInteger): Boolean; message 'tableView:shouldSelectRow:';
    function tableView_selectionIndexesForProposedSelection(tableView: NSTableView; proposedSelectionIndexes: NSIndexSet): NSIndexSet; message 'tableView:selectionIndexesForProposedSelection:';
    function tableView_shouldSelectTableColumn(tableView: NSTableView; tableColumn: NSTableColumn): Boolean; message 'tableView:shouldSelectTableColumn:';
    procedure tableView_mouseDownInHeaderOfTableColumn(tableView: NSTableView; tableColumn: NSTableColumn); message 'tableView:mouseDownInHeaderOfTableColumn:';
    procedure tableView_didClickTableColumn(tableView: NSTableView; tableColumn: NSTableColumn); message 'tableView:didClickTableColumn:';
    procedure tableView_didDragTableColumn(tableView: NSTableView; tableColumn: NSTableColumn); message 'tableView:didDragTableColumn:';
    function tableView_toolTipForCell_rect_tableColumn_row_mouseLocation(tableView: NSTableView; cell: NSCell; rect: NSRectPointer; tableColumn: NSTableColumn; row: NSInteger; mouseLocation: NSPoint): NSString; message 'tableView:toolTipForCell:rect:tableColumn:row:mouseLocation:';
    function tableView_heightOfRow(tableView: NSTableView; row: NSInteger): CGFloat; message 'tableView:heightOfRow:';
    function tableView_typeSelectStringForTableColumn_row(tableView: NSTableView; tableColumn: NSTableColumn; row: NSInteger): NSString; message 'tableView:typeSelectStringForTableColumn:row:';
    function tableView_nextTypeSelectMatchFromRow_toRow_forString(tableView: NSTableView; startRow: NSInteger; endRow: NSInteger; searchString: NSString): NSInteger; message 'tableView:nextTypeSelectMatchFromRow:toRow:forString:';
    function tableView_shouldTypeSelectForEvent_withCurrentSearchString(tableView: NSTableView; event: NSEvent; searchString: NSString): Boolean; message 'tableView:shouldTypeSelectForEvent:withCurrentSearchString:';
    function tableView_shouldShowCellExpansionForTableColumn_row(tableView: NSTableView; tableColumn: NSTableColumn; row: NSInteger): Boolean; message 'tableView:shouldShowCellExpansionForTableColumn:row:';
    function tableView_shouldTrackCell_forTableColumn_row(tableView: NSTableView; cell: NSCell; tableColumn: NSTableColumn; row: NSInteger): Boolean; message 'tableView:shouldTrackCell:forTableColumn:row:';
    function tableView_dataCellForTableColumn_row(tableView: NSTableView; tableColumn: NSTableColumn; row: NSInteger): NSCell; message 'tableView:dataCellForTableColumn:row:';
    function tableView_isGroupRow(tableView: NSTableView; row: NSInteger): Boolean; message 'tableView:isGroupRow:';
    function tableView_sizeToFitWidthOfColumn(tableView: NSTableView; column: NSInteger): CGFloat; message 'tableView:sizeToFitWidthOfColumn:';
    function tableView_shouldReorderColumn_toColumn(tableView: NSTableView; columnIndex: NSInteger; newColumnIndex: NSInteger): Boolean; message 'tableView:shouldReorderColumn:toColumn:';}
    procedure tableViewSelectionDidChange(notification: NSNotification); message 'tableViewSelectionDidChange:';
    {procedure tableViewColumnDidMove(notification: NSNotification); message 'tableViewColumnDidMove:';
    procedure tableViewColumnDidResize(notification: NSNotification); message 'tableViewColumnDidResize:';
    procedure tableViewSelectionIsChanging(notification: NSNotification); message 'tableViewSelectionIsChanging:';}
  end;

implementation

{ TCocoaListBox }

function TCocoaListBox.lclIsHandle: Boolean;
begin
  Result:=true;
end;

function TCocoaListBox.acceptsFirstResponder: Boolean;
begin
  Result := True;
end;

function TCocoaListBox.becomeFirstResponder: Boolean;
begin
  Result := inherited becomeFirstResponder;
  callback.BecomeFirstResponder;
end;

function TCocoaListBox.resignFirstResponder: Boolean;
begin
  Result := inherited resignFirstResponder;
  callback.ResignFirstResponder;
end;

function TCocoaListBox.lclGetCallback: ICommonCallback;
begin
  Result := callback;
end;

procedure TCocoaListBox.lclClearCallback;
begin
  callback := nil;
end;

function TCocoaListBox.numberOfRowsInTableView(aTableView:NSTableView): NSInteger;
begin
  if Assigned(list) then
    Result := list.Count
  else
    Result := 0;
end;


function TCocoaListBox.tableView_shouldEditTableColumn_row(tableView: NSTableView; tableColumn: NSTableColumn; row: NSInteger): Boolean;
begin
  Result := False;  // disable cell editing by default
end;

function TCocoaListBox.tableView_objectValueForTableColumn_row(tableView: NSTableView;
  objectValueForTableColumn: NSTableColumn; row: NSInteger):id;
begin
  //WriteLn('TCocoaListBox.tableView_objectValueForTableColumn_row');
  if not Assigned(list) then
    Result:=nil
  else
  begin
    if row>=list.count then
      Result := nil
    else
    begin
      resultNS.release;
      resultNS := NSStringUtf8(list[row]);
      Result := ResultNS;
    end;
  end;
end;

procedure TCocoaListBox.drawRow_clipRect(row: NSInteger; clipRect: NSRect);
var
  DrawStruct: TDrawListItemStruct;
  ctx: TCocoaContext;
  LCLObject: TCustomListBox;
begin
  inherited;
  if not isCustomDraw then Exit;
  ctx := TCocoaContext.Create(NSGraphicsContext.currentContext);
  DrawStruct.Area := NSRectToRect(rectOfRow(row));
  DrawStruct.DC := HDC(ctx);
  DrawStruct.ItemID :=  row;

  LCLObject := TCustomListBox(callback.GetTarget);
  DrawStruct.ItemState := [];
  if isRowSelected(row) then
    Include(DrawStruct.ItemState, odSelected);
  if not LCLObject.Enabled then
    Include(DrawStruct.ItemState, odDisabled);
  if (LCLObject.Focused) and (LCLObject.ItemIndex = row) then
    Include(DrawStruct.ItemState, odFocused);
  LCLSendDrawListItemMsg(TWinControl(callback.GetTarget), @DrawStruct);
end;

procedure TCocoaListBox.dealloc;
begin
  FreeAndNil(list);
  resultNS.release;
  inherited dealloc;
end;

procedure TCocoaListBox.resetCursorRects;
begin
  if not callback.resetCursorRects then
    inherited resetCursorRects;
end;

procedure TCocoaListBox.tableViewSelectionDidChange(notification: NSNotification);
begin
  if Assigned(callback) then
    callback.SelectionChanged;
end;

procedure TCocoaListBox.mouseDown(event: NSEvent);
begin
  if Assigned(callback) and not callback.MouseUpDownEvent(event) then
  begin
    inherited mouseDown(event);

    callback.MouseUpDownEvent(event, true);
  end;
end;

procedure TCocoaListBox.rightMouseDown(event: NSEvent);
begin
  if not Assigned(callback) or not callback.MouseUpDownEvent(event) then
    inherited rightMouseDown(event);
end;

procedure TCocoaListBox.rightMouseUp(event: NSEvent);
begin
  if not Assigned(callback) or not callback.MouseUpDownEvent(event) then
    inherited rightMouseUp(event);
end;

procedure TCocoaListBox.otherMouseDown(event: NSEvent);
begin
  if not Assigned(callback) or not callback.MouseUpDownEvent(event) then
    inherited otherMouseDown(event);
end;

procedure TCocoaListBox.otherMouseUp(event: NSEvent);
begin
  if not Assigned(callback) or not callback.MouseUpDownEvent(event) then
    inherited otherMouseUp(event);
end;

procedure TCocoaListBox.mouseDragged(event: NSEvent);
begin
if not Assigned(callback) or not callback.MouseMove(event) then
  inherited mouseDragged(event);
end;

procedure TCocoaListBox.mouseEntered(event: NSEvent);
begin
  inherited mouseEntered(event);
end;

procedure TCocoaListBox.mouseExited(event: NSEvent);
begin
  inherited mouseExited(event);
end;

procedure TCocoaListBox.mouseMoved(event: NSEvent);
begin
  inherited mouseMoved(event);
end;

procedure TCocoaListBox.keyDown(event: NSEvent);
begin
  if not Assigned(callback) or not callback.KeyEvent(event) then
    inherited keyDown(event);
end;

procedure TCocoaListBox.keyUp(event: NSEvent);
begin
  if not Assigned(callback) or not callback.KeyEvent(event) then
    inherited keyUp(event);
end;

{ TCocoaCheckListBox }

function TCocoaCheckListBox.initWithFrame(ns: NSRect): id;
var
  chklist : TCocoaCheckListBox;
  clm : NSTableColumn;
begin
  Result:=inherited initWithFrame(ns);

  chklist := TCocoaCheckListBox(Result);
  // identifiers for columns
  chklist.chkid:=NSSTR('chk');
  chklist.txtid:=NSSTR('txt');
  // the first column is for the checkbox
  // the second column is for the title of the button
  // the separation is needed, so clicking on the text would not trigger
  // change of the button
  clm:=NSTableColumn.alloc.initWithIdentifier(chkid);
  chklist.addTableColumn(clm);
  // todo: this should be "auto-size" and not hard-coded width to fix the checkbox
  clm.setWidth(18);
  chklist.addTableColumn(NSTableColumn.alloc.initWithIdentifier(txtid));
end;

procedure TCocoaCheckListBox.dealloc;
begin
  chkid.release;
  txtid.release;
  inherited dealloc;
end;

class function TCocoaCheckListBox.LCLCheckStateToCocoa(ALCLState: TCheckBoxState): NSInteger;
begin
  case ALCLState of
  cbChecked: Result := NSOnState;
  cbGrayed:  Result := NSMixedState;
  else // cbUnchecked
    Result := NSOffState;
  end;
end;

class function TCocoaCheckListBox.CocoaCheckStateToLCL(ACocoaState: NSInteger): TCheckBoxState;
begin
  case ACocoaState of
  NSOnState:    Result := cbChecked;
  NSMixedState: Result := cbGrayed;
  else // NSOffState
    Result := cbUnchecked;
  end;
end;

function TCocoaCheckListBox.CheckListBoxGetNextState(ACurrent: TCheckBoxState): TCheckBoxState;
begin
  case ACurrent of
  cbChecked: Result := cbUnchecked;
  cbGrayed:  Result := cbChecked;
  else // cbUnchecked
    if AllowMixedState then
      Result := cbGrayed
    else
      Result := cbChecked;
  end;
end;

function TCocoaCheckListBox.GetCocoaState(const AIndex: integer): NSInteger;
begin
  Result := NSInteger(list.Objects[AIndex]);
end;

procedure TCocoaCheckListBox.SetCocoaState(const AIndex: integer; AState: NSInteger);
begin
  list.Objects[AIndex] := TObject(AState);
end;

function TCocoaCheckListBox.GetState(const AIndex: integer): TCheckBoxState;
var
  lInt: NSInteger;
begin
  lInt := GetCocoaState(AIndex);
  Result := CocoaCheckStateToLCL(lInt);
end;

procedure TCocoaCheckListBox.SetState(const AIndex: integer; AState: TCheckBoxState);
begin
  SetCocoaState(AIndex, LCLCheckStateToCocoa(AState));
end;

function TCocoaCheckListBox.tableView_objectValueForTableColumn_row(tableView: NSTableView;
  objectValueForTableColumn: NSTableColumn; row: NSInteger):id;
var
  lInt: NSInteger;
  lNSString : NSString;
begin
  Result:=nil;

  //WriteLn('[TCocoaCheckListBox.tableView_objectValueForTableColumn_row] row='+IntToStr(row));
  if not Assigned(list) then Exit;

  if row>=list.count then Exit;

  if objectValueForTableColumn.identifier=chkid then
  begin
    // Returns if the state is checked or unchecked
    lInt := GetCocoaState(row);
    Result := NSNumber.numberWithInteger(lInt)
  end
  else if objectValueForTableColumn.identifier=txtid then
  begin
    // Returns caption of the checkbox
    lNSString := NSStringUtf8(list[row]);
    Result:= lNSString;
  end;

end;

procedure TCocoaCheckListBox.tableView_setObjectValue_forTableColumn_row(tableView: NSTableView;
  object_: id; tableColumn: NSTableColumn; row: NSInteger);
begin
  //WriteLn('[TCocoaCheckListBox.tableView_setObjectValue_forTableColumn_row] row='+IntToStr(row));
  SetState(row, CheckListBoxGetNextState(GetState(row)));
end;

function TCocoaCheckListBox.tableView_dataCellForTableColumn_row(tableView: NSTableView;
  tableColumn: NSTableColumn; row: NSInteger): NSCell;
var
  lNSString: NSString;
begin
  Result:=nil;
  if not Assigned(tableColumn) then
  begin
    Exit;
  end;

  if tableColumn.identifier = chkid then
  begin
    Result := NSButtonCell.alloc.init.autorelease;
    Result.setAllowsMixedState(True);
    NSButtonCell(Result).setButtonType(NSSwitchButton);
    NSButtonCell(Result).setTitle(NSSTR(''));
  end
  else
  if tableColumn.identifier = txtid then
  begin
    Result:=NSTextFieldCell.alloc.init.autorelease;
  end
end;

{ TCocoaTableListView }

function TCocoaTableListView.lclIsHandle: Boolean;
begin
  Result:=true;
end;

function TCocoaTableListView.acceptsFirstResponder: Boolean;
begin
  Result := True;
end;

function TCocoaTableListView.becomeFirstResponder: Boolean;
begin
  Result := inherited becomeFirstResponder;
  callback.BecomeFirstResponder;
end;

function TCocoaTableListView.resignFirstResponder: Boolean;
begin
  Result := inherited resignFirstResponder;
  callback.ResignFirstResponder;
end;

function TCocoaTableListView.lclGetCallback: ICommonCallback;
begin
  Result := callback;
end;

procedure TCocoaTableListView.lclClearCallback;
begin
  callback := nil;
end;

procedure TCocoaTableListView.dealloc;
begin
  //if Assigned(Items) then FreeAndNil(Items);
  inherited dealloc;
end;

procedure TCocoaTableListView.resetCursorRects;
begin
  if not callback.resetCursorRects then
    inherited resetCursorRects;
end;
(*
procedure TCocoaTableListView.setStringValue_forCol_row(
  AStr: NSString; col, row: NSInteger);
var
  lStringList: TStringList;
  lStr: string;
begin
  lStr := NSStringToString(AStr);
  {$IFDEF COCOA_DEBUG_TABCONTROL}
  WriteLn(Format('[TCocoaTableListView.setStringValue_forTableColumn_row] AStr=%s col=%d row=%d Items.Count=%d',
    [lStr, col, row, Items.Count]));
  {$ENDIF}

  // make sure we have enough lines
  while (row >= Items.Count) do
  begin
    {$IFDEF COCOA_DEBUG_TABCONTROL}
    WriteLn(Format('[TCocoaTableListView.setStringValue_forTableColumn_row] Adding line', []));
    {$ENDIF}
    Items.AddObject('', TStringList.Create());
  end;

  // Now write it
  if col = 0 then
    Items.Strings[row] := lStr
  else
  begin
    lStringList := TStringList(Items.Objects[row]);
    if lStringList = nil then
    begin
      lStringList := TStringList.Create;
      Items.Objects[row] := lStringList;
    end;

    // make sure we have enough columns
    while (col-1 >= lStringList.Count) do
    begin
      {$IFDEF COCOA_DEBUG_TABCONTROL}
      WriteLn(Format('[TCocoaTableListView.setStringValue_forTableColumn_row] Adding column', []));
      {$ENDIF}
      lStringList.Add('');
    end;

    lStringList.Strings[col-1] := lStr;
  end;
end;

procedure TCocoaTableListView.deleteItemForRow(row: NSInteger);
var
  lStringList: TStringList;
begin
  lStringList := TStringList(Items.Objects[row]);
  if lStringList <> nil then lStringList.Free;
  Items.Delete(row);
end;

procedure TCocoaTableListView.setListViewStringValue_forCol_row(
  AStr: NSString; col, row: NSInteger);
var
  lSubItems: TStrings;
  lItem: TListItem;
  lNewValue: string;
begin
  lNewValue := NSStringToString(AStr);
  if ListView.ReadOnly then Exit;

  if row >= ListView.Items.Count then Exit;
  lItem := ListView.Items.Item[row];

  if col = 0 then
  begin
    lItem.Caption := lNewValue;
  end
  else if col > 0 then
  begin
    lSubItems := lItem.SubItems;
    if col >= lSubItems.Count+1 then Exit;
    lSubItems.Strings[col-1] := lNewValue;
  end;
end;
*)
function TCocoaTableListView.getIndexOfColumn(ACol: NSTableColumn): NSInteger;
begin
  Result := tableColumns.indexOfObject(ACol);
end;

procedure TCocoaTableListView.reloadDataForRow_column(ARow, ACol: NSInteger);
var
  lRowSet, lColSet: NSIndexSet;
begin
  lRowSet := NSIndexSet.indexSetWithIndex(ARow);
  lColSet := NSIndexSet.indexSetWithIndex(ACol);
  reloadDataForRowIndexes_columnIndexes(lRowSet, lColSet);
end;

procedure TCocoaTableListView.scheduleSelectionDidChange;
begin
  if Timer = nil then Timer := TTimer.Create(nil);
  Timer.Interval := 1;
  Timer.Enabled := True;
  Timer.OnTimer := @callback.delayedSelectionDidChange_OnTimer;
end;

procedure TCocoaTableListView.mouseDown(event: NSEvent);
begin
  if not Assigned(callback) or not callback.MouseUpDownEvent(event) then
    inherited mouseDown(event);
end;

procedure TCocoaTableListView.rightMouseDown(event: NSEvent);
begin
  if not Assigned(callback) or not callback.MouseUpDownEvent(event) then
    inherited rightMouseDown(event);
end;

procedure TCocoaTableListView.rightMouseUp(event: NSEvent);
begin
  if not Assigned(callback) or not callback.MouseUpDownEvent(event) then
    inherited rightMouseUp(event);
end;

procedure TCocoaTableListView.otherMouseDown(event: NSEvent);
begin
  if not Assigned(callback) or not callback.MouseUpDownEvent(event) then
    inherited otherMouseDown(event);
end;

procedure TCocoaTableListView.otherMouseUp(event: NSEvent);
begin
  if not Assigned(callback) or not callback.MouseUpDownEvent(event) then
    inherited otherMouseUp(event);
end;

procedure TCocoaTableListView.mouseDragged(event: NSEvent);
begin
  if not Assigned(callback) or not callback.MouseMove(event) then
    inherited mouseDragged(event);
end;

procedure TCocoaTableListView.mouseEntered(event: NSEvent);
begin
  inherited mouseEntered(event);
end;

procedure TCocoaTableListView.mouseExited(event: NSEvent);
begin
  inherited mouseExited(event);
end;

procedure TCocoaTableListView.mouseMoved(event: NSEvent);
begin
  inherited mouseMoved(event);
end;

procedure TCocoaTableListView.keyDown(event: NSEvent);
begin
  if not Assigned(callback) or not callback.KeyEvent(event) then
    inherited keyDown(event);
end;

procedure TCocoaTableListView.keyUp(event: NSEvent);
begin
  if not Assigned(callback) or not callback.KeyEvent(event) then
    inherited keyUp(event);
end;

function TCocoaTableListView.numberOfRowsInTableView(tableView: NSTableView
  ): NSInteger;
begin
  if Assigned(callback) then
    Result := callback.ItemsCount
  else
    Result := 0;
end;

function TCocoaTableListView.tableView_objectValueForTableColumn_row(
  tableView: NSTableView; tableColumn: NSTableColumn; row: NSInteger): id;
var
  lStringList: TStringList;
  col: NSInteger;
  StrResult: NSString;
  txt : string;
begin
  {$IFDEF COCOA_DEBUG_TABCONTROL}
  WriteLn(Format('[TCocoaTableListView.tableView_objectValueForTableColumn_row] col=%d row=%d Items.Count=%d',
    [col, row, Items.Count]));
  {$ENDIF}

  Result := nil;
  if not Assigned(callback) then Exit;
  col := tableColumns.indexOfObject(tableColumn);

  txt := '';
  if callback.GetItemTextAt(row, col, txt) then begin
    if txt = '' then Result := NSString.string_
    else Result := NSString.stringWithUTF8String(@txt[1])
  end;
  (*
  if row > Items.Count-1 then begin
    Result := nil;
    Exit;
  end;
  if col = 0 then
    StrResult := NSStringUTF8(Items.Strings[row])
  else
  begin
    lStringList := TStringList(Items.Objects[row]);
    StrResult := NSStringUTF8(lStringList.Strings[col-1]);
  end;
  Result := StrResult;
  *)
end;

procedure TCocoaTableListView.tableView_setObjectValue_forTableColumn_row(
  tableView: NSTableView; object_: id; tableColumn: NSTableColumn;
  row: NSInteger);
var
  lColumnIndex: NSInteger;
  lNewValue: NSString;
begin
  //WriteLn('[TCocoaTableListView.tableView_setObjectValue_forTableColumn_row]');
  if not NSObject(object_).isKindOfClass(NSString) then Exit;
  lNewValue := NSString(object_);
  //WriteLn('[TCocoaTableListView.tableView_setObjectValue_forTableColumn_row] A');}
  if ReadOnly then Exit;

  lColumnIndex := getIndexOfColumn(tableColumn);
  {
  setListViewStringValue_forCol_row(lNewValue, lColumnIndex, row);
  //setStringValue_forCol_row(lNewValue, lColumnIndex, row);
  }
  reloadDataForRow_column(lColumnIndex, row);
end;

function TCocoaTableListView.tableView_shouldEditTableColumn_row(tableView: NSTableView; tableColumn: NSTableColumn; row: NSInteger): Boolean;
begin
  Result := not readOnly;
end;

procedure TCocoaTableListView.tableViewSelectionDidChange(notification: NSNotification);
var
  NewSel: Integer;
begin
  if Assigned(callback) then
  begin
    NewSel := Self.selectedRow();
    callback.tableSelectionChange(NewSel);
  end;
end;

{ TCocoaStringList }

procedure TCocoaStringList.Changed;
begin
  inherited Changed;
  Owner.reloadData;
end;

constructor TCocoaStringList.Create(AOwner:TCocoaListBox);
begin
  Owner:=AOwner;
  inherited Create;
end;

end.

