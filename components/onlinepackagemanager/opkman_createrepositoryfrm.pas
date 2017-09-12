{
 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 51 Franklin Street - Fifth Floor, Boston, MA 02110-1335, USA.   *
 *                                                                         *
 ***************************************************************************

 Author: Balázs Székely
}

unit opkman_createrepositoryfrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, fpjson,
  // LCL
  Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Buttons,
  // LazUtils
  LazFileUtils, LazUTF8,
  // OpkMan
  opkman_VirtualTrees, opkman_serializablepackages;

type

  PRepository = ^TRepository;
  TRepository = record
    FName: String;
    FPath: String;
    FAddress: String;
    FDescription: String;
  end;


  { TCreateRepositoryFrm }

  TCreateRepositoryFrm = class(TForm)
    bCancel: TButton;
    bAdd: TBitBtn;
    bDelete: TBitBtn;
    bOpen: TButton;
    bCreate: TButton;
    imTree: TImageList;
    OD: TOpenDialog;
    pnButtons: TPanel;
    pnMessage: TPanel;
    pnPackages: TPanel;
    pnDetails: TPanel;
    SD: TSaveDialog;
    spMain: TSplitter;
    procedure bCreateClick(Sender: TObject);
    procedure bOpenClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure pnButtonsResize(Sender: TObject);
  private
    FVSTPackages: TVirtualStringTree;
    FVSTDetails: TVirtualStringTree;
    FRepository: TRepository;
    FSerializablePackages: TSerializablePackages;
    procedure EnableDisableButtons(const AEnable: Boolean);
    procedure ShowHideControls(const AType: Integer);
    function LoadRepository(const AFileName: String): Boolean;
    function SaveRepository(const AFileName: String): Boolean;
    procedure PopulatePackageTree;
    function GetDisplayString(const AStr: String): String;
    procedure VSTPackagesGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      {%H-}Column: TColumnIndex; {%H-}TextType: TVSTTextType; var CellText: String);
    procedure VSTPackagesGetImageIndex(Sender: TBaseVirtualTree; Node: PVirtualNode;
      {%H-}Kind: TVTImageKind; {%H-}Column: TColumnIndex; var {%H-}Ghosted: Boolean;
      var ImageIndex: Integer);
    procedure VSTPackagesHeaderClick(Sender: TVTHeader; {%H-}Column: TColumnIndex;
      Button: TMouseButton; {%H-}Shift: TShiftState; {%H-}X, {%H-}Y: Integer);
    procedure VSTPackagesCompareNodes(Sender: TBaseVirtualTree; Node1,
      Node2: PVirtualNode; Column: TColumnIndex; var Result: Integer);
    procedure VSTPackagesFocusChanged(Sender: TBaseVirtualTree; Node: PVirtualNode;
      {%H-}Column: TColumnIndex);
    procedure VSTPackagesFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);

    procedure VSTDetailsGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      {%H-}Column: TColumnIndex; {%H-}TextType: TVSTTextType; var CellText: String);
    procedure VSTDetailsGetImageIndex(Sender: TBaseVirtualTree; Node: PVirtualNode;
      {%H-}Kind: TVTImageKind; {%H-}Column: TColumnIndex; var {%H-}Ghosted: Boolean;
      var ImageIndex: Integer);
    procedure VSTDetailsFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
  public

  end;

var
  CreateRepositoryFrm: TCreateRepositoryFrm;

implementation

uses opkman_common, opkman_const, opkman_options, opkman_repositorydetailsfrm;

{$R *.lfm}

{ TCreateRepositoryFrm }

type
  PData = ^TData;
  TData = record
    FRepository: TRepository;
    FPackageRelativePath: String;
    FPackageBaseDir: String;
    FFullPath: String;
    FDataType: Integer;
    FName: String;
    FDisplayName: String;
    FPackageType: TPackageType;
    FRepositoryFileName: String;
    FRepositoryFileSize: Int64;
    FRepositoryFileHash: String;
    FRepositoryDate: TDate;
    FAuthor: String;
    FDescription: String;
    FLicense: String;
    FVersionAsString: String;
    FDependenciesAsString: String;
    FCategory: String;
    FLazCompatibility: String;
    FFPCCompatibility: String;
    FSupportedWidgetSet: String;
    FHomePageURL: String;
    FDownloadURL: String;
    FSVNURL: String;
  end;

procedure TCreateRepositoryFrm.FormCreate(Sender: TObject);
begin
  Caption := rsCreateRepositoryFrm_Caption;
  bCreate.Caption := rsCreateRepositoryFrm_bCreate_Caption;
  bCreate.Hint := rsCreateRepositoryFrm_bCreate_Hint;
  bOpen.Caption := rsCreateRepositoryFrm_bOpen_Caption;
  bOpen.Hint := rsCreateRepositoryFrm_bOpen_Hint;
  bAdd.Caption := rsCreateRepositoryFrm_bAdd_Caption;
  bAdd.Hint := rsCreateRepositoryFrm_bAdd_Hint;
  bDelete.Caption := rsCreateRepositoryFrm_bDelete_Caption;
  bDelete.Hint := rsCreateRepositoryFrm_bDelete_Hint;
  bCancel.Caption := rsCreateRepositoryFrm_bCancel_Caption;
  bCancel.Hint := rsCreateRepositoryFrm_bCancel_Hint;
  EnableDisableButtons(True);
  ShowHideControls(0);

  FSerializablePackages := TSerializablePackages.Create;
  FVSTPackages := TVirtualStringTree.Create(nil);
  with FVSTPackages do
  begin
    NodeDataSize := SizeOf(TData);
    Parent := pnPackages;
    Align := alClient;
    Images := imTree;
    if not Options.UseDefaultTheme then
      Color := clBtnFace;
    DefaultNodeHeight := 25;
    Indent := 15;
    TabOrder := 1;
    DefaultText := '';
    Header.AutoSizeIndex := 0;
    Header.Height := 25;
    Colors.BorderColor := clBlack;
    with Header.Columns.Add do begin
      Position := 0;
      Width := 250;
      Text := rsCreateRepositoryFrm_VSTPackages_Column0;
    end;
    Header.Options := [hoAutoResize, hoColumnResize, hoRestrictDrag, hoVisible, hoAutoSpring];
    Header.SortColumn := 0;
    TabOrder := 0;
    TreeOptions.MiscOptions := [toCheckSupport, toFullRepaintOnResize, toInitOnSave, toToggleOnDblClick, toWheelPanning];
    TreeOptions.PaintOptions := [toHideFocusRect, toPopupMode, toShowButtons, toShowDropmark, toShowRoot, toThemeAware, toUseBlendedImages];
    TreeOptions.SelectionOptions := [toRightClickSelect];
    TreeOptions.AutoOptions := [toAutoTristateTracking];
    OnGetText := @VSTPackagesGetText;
    OnGetImageIndex := @VSTPackagesGetImageIndex;
    OnHeaderClick := @VSTPackagesHeaderClick;
    OnCompareNodes := @VSTPackagesCompareNodes;
    OnFocusChanged := @VSTPackagesFocusChanged;
    OnFreeNode := @VSTPackagesFreeNode;
  end;

  FVSTDetails := TVirtualStringTree.Create(nil);
  with FVSTDetails do
  begin
    NodeDataSize := SizeOf(TData);
    Parent := pnDetails;
    Align := alClient;
    Images := imTree;
    if not Options.UseDefaultTheme then
      Color := clBtnFace;
    DefaultNodeHeight := 25;
    Indent := 15;
    TabOrder := 0;
    DefaultText := '';
    Header.AutoSizeIndex := 1;
    Header.Height := 25;
    Colors.BorderColor := clBlack;
    with Header.Columns.Add do begin
      Position := 0;
      Width := 150;
      Text := rsCreateRepositoryFrm_VSTDetails_Column0;
    end;
    with Header.Columns.Add do begin
      Position := 1;
      Width := 250;
      Text := rsCreateRepositoryFrm_VSTDetails_Column1;
    end;
    Header.Options := [hoAutoResize, hoColumnResize, hoRestrictDrag, hoVisible, hoAutoSpring];
    Header.SortColumn := 0;
    TreeOptions.MiscOptions := [toCheckSupport, toFullRepaintOnResize, toInitOnSave, toToggleOnDblClick, toWheelPanning];
    TreeOptions.PaintOptions := [toHideFocusRect, toPopupMode, toShowButtons, toShowDropmark, toThemeAware, toUseBlendedImages];
    TreeOptions.SelectionOptions := [toRightClickSelect, toFullRowSelect];
    TreeOptions.AutoOptions := [toAutoTristateTracking];
    OnGetText := @VSTDetailsGetText;
    OnGetImageIndex := @VSTDetailsGetImageIndex;
    OnFreeNode := @VSTDetailsFreeNode;
  end;
end;

procedure TCreateRepositoryFrm.bCreateClick(Sender: TObject);
label
  ShowFormAgain;
var
  RepositoryDetailsFrm: TRepositoryDetailsFrm;
begin
  RepositoryDetailsFrm := TRepositoryDetailsFrm.Create(Self);
  try
    ShowFormAgain:
    RepositoryDetailsFrm.ShowModal;
    if RepositoryDetailsFrm.ModalResult = mrOk then
    begin
      FRepository.FName := RepositoryDetailsFrm.edName.Text;
      FRepository.FAddress := RepositoryDetailsFrm.edAddress.Text;
      FRepository.FDescription := RepositoryDetailsFrm.mDescription.Text;
      if SD.Execute then
      begin
        if SaveRepository(SD.FileName) then
        begin
          if RepositoryDetailsFrm.Address <> '' then
            Options.RemoteRepository.Add(RepositoryDetailsFrm.Address);
          if LoadRepository(SD.FileName) then
          begin
            PopulatePackageTree;
            ShowHideControls(2);
            EnableDisableButtons(True);
          end;
        end
        else
          GoTo ShowFormAgain;
      end;
    end;
  finally
    RepositoryDetailsFrm.Free;
  end;
end;

procedure TCreateRepositoryFrm.bOpenClick(Sender: TObject);
begin
  if OD.Execute then
  begin
    if LoadRepository(OD.FileName) then
    begin
      PopulatePackageTree;
      ShowHideControls(2);
      EnableDisableButtons(True);
    end
  end
end;

procedure TCreateRepositoryFrm.FormDestroy(Sender: TObject);
begin
  FVSTPackages.Free;
  FVSTDetails.Free;
  FSerializablePackages.Free
end;

procedure TCreateRepositoryFrm.pnButtonsResize(Sender: TObject);
begin
  bAdd.Left := (pnButtons.Width - (bAdd.Width + bDelete.Width)) div 2;
  bDelete.Left := bAdd.Left + bAdd.Width + 1;
end;

procedure TCreateRepositoryFrm.EnableDisableButtons(const AEnable: Boolean);
var
  Node: PVirtualNode;
  Data: PData;
begin
  bOpen.Enabled := AEnable;
  bCreate.Enabled := AEnable;
  bAdd.Enabled := AEnable and FileExists(Trim(FRepository.FPath));
  bCancel.Enabled := AEnable;
  bDelete.Enabled := False;
  if Assigned(FVSTPackages) then
  begin
    Node := FVSTPackages.GetFirstSelected;
    if Node <> nil then
    begin
      Data := FVSTPackages.GetNodeData(Node);
      bDelete.Enabled := AEnable and FileExists(Trim(FRepository.FPath)) and (Data^.FDataType = 1);
    end
  end;
end;

procedure TCreateRepositoryFrm.ShowHideControls(const AType: Integer);
begin
  case AType of
    0: begin
         pnPackages.Visible := False;
         pnDetails.Visible := False;
         pnMessage.Visible := False;
       end;
    1: begin
         pnPackages.Visible := False;
         pnDetails.Visible := False;
         pnMessage.Visible := True;
       end;
    2: begin
         pnPackages.Visible := True;
         pnDetails.Visible := True;
         pnMessage.Visible := False;
       end;
  end;
end;

function TCreateRepositoryFrm.LoadRepository(const AFileName: String): Boolean;
var
  FS: TFileStream;
  procedure ReadString(out AString: String);
  var
    Len: Integer;
  begin
    Len := 0;
    FS.Read(Len, SizeOf(Integer));
    SetLength(AString, Len div SizeOf(Char));
    FS.Read(Pointer(AString)^, Len);
  end;
begin
  Result := False;
  FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    try
      ReadString(FRepository.FName);
      ReadString(FRepository.FAddress);
      ReadString(FRepository.FDescription);
      FRepository.FPath := AFileName;
      Result := FileExists(AppendPathDelim(ExtractFilePath(AFileName)) + cRemoteJSONFile);
      if not Result then
        MessageDlgEx(Format(rsCreateRepositoryFrm_Error1, [rsCreateRepositoryFrm_Error2]), mtError, [mbOk], Self);
    except
      on E: Exception do
        MessageDlgEx(Format(rsCreateRepositoryFrm_Error1, [E.Message]), mtError, [mbOk], Self);
    end;
  finally
    FS.Free;
  end;
end;

function TCreateRepositoryFrm.SaveRepository(const AFileName: String): Boolean;
var
  FS: TFileStream;
  FHandle: THandle;
  procedure WriteString(const AString: String);
  var
    Len: Integer;
  begin
    Len := Length(AString)*SizeOf(Char);
    FS.Write(Len, SizeOf(Integer));
    FS.Write(Pointer(AString)^, Len);
  end;
begin
  Result := False;
  if not IsDirectoryEmpty(ExtractFilePath(AFileName)) then
  begin
    if MessageDlgEx(Format(rsCreateRepositoryFrm_Info1, [ExtractFilePath(AFileName)]), mtConfirmation, [mbYes, mbNo], Self) = mrNo then
    begin
      Result := False;
      Exit;
    end;
  end;

  if not DirectoryIsWritable(ExtractFilePath(AFileName)) then
  begin
    MessageDlgEx(Format(rsCreateRepositoryFrm_Info1, [ExtractFilePath(AFileName)]), mtConfirmation, [mbOk], Self);
    Result := False;
    Exit;
  end;

  FS := TFileStream.Create(AFileName, fmCreate or fmOpenWrite or fmShareDenyWrite);
  try
    try
      WriteString(FRepository.FName);
      WriteString(FRepository.FAddress);
      WriteString(FRepository.FDescription);
      FHandle := FileCreate(ExtractFilePath(AFileName) + cRemoteJSONFile);
      if fHandle <> THandle(-1) then
      begin
        Result := True;
        FileClose(FHandle);
      end;
    except
      on E: Exception do
        MessageDlgEx(Format(rsCreateRepositoryFrm_Error3, [E.Message]), mtError, [mbOk], Self);
    end;
  finally
    FS.Free;
  end;
end;

procedure TCreateRepositoryFrm.PopulatePackageTree;
var
  RootNode, Node, ChildNode: PVirtualNode;
  RootData, Data, ChildData: PData;
  JSON: TJSONStringType;
  Ms: TMemoryStream;
  i, j: Integer;
  MetaPackage: TMetaPackage;
  LazarusPackage: TLazarusPackage;
begin

  FVSTPackages.Clear;

  //add repository(DataType = 0)
  RootNode := FVSTPackages.AddChild(nil);
  RootData := FVSTPackages.GetNodeData(RootNode);
  RootData^.FName := FRepository.FName;
  RootData^.FDataType := 0;

  if FileExists(ExtractFilePath(FRepository.FPath) + cRemoteJSONFile) then
  begin
    Ms := TMemoryStream.Create;
    try
      Ms.LoadFromFile(ExtractFilePath(FRepository.FPath) + cRemoteJSONFile);
      if Ms.Size > 0 then
      begin
        Ms.Position := 0;
        SetLength(JSON, MS.Size);
        MS.Read(Pointer(JSON)^, Length(JSON));
        FSerializablePackages.JSONToPackages(JSON);
        for I := 0 to FSerializablePackages.Count - 1 do
        begin
          MetaPackage := TMetaPackage(FSerializablePackages.Items[I]);
          Node := FVSTPackages.AddChild(RootNode);
          Data := FVSTPackages.GetNodeData(Node);
          if Trim(MetaPackage.DisplayName) <> '' then
            Data^.FName := MetaPackage.DisplayName
          else
            Data^.FName := MetaPackage.Name;
          Data^.FCategory := MetaPackage.Category;
          Data^.FRepositoryFileName := MetaPackage.RepositoryFileName;
          Data^.FRepositoryFileSize := MetaPackage.RepositoryFileSize;
          Data^.FRepositoryFileHash := MetaPackage.RepositoryFileHash;
          Data^.FRepositoryDate := MetaPackage.RepositoryDate;
          Data^.FHomePageURL := MetaPackage.HomePageURL;
          Data^.FDownloadURL := MetaPackage.DownloadURL;
          Data^.FDataType := 1;
          for J := 0 to MetaPackage.LazarusPackages.Count - 1 do
          begin
            LazarusPackage := TLazarusPackage(MetaPackage.LazarusPackages.Items[J]);
            ChildNode := FVSTPackages.AddChild(Node);
            ChildData := FVSTPackages.GetNodeData(ChildNode);
            ChildData^.FName := LazarusPackage.Name;
            ChildData^.FVersionAsString := LazarusPackage.VersionAsString;
            ChildData^.FDescription := LazarusPackage.Description;
            ChildData^.FAuthor := LazarusPackage.Author;
            ChildData^.FLazCompatibility := LazarusPackage.LazCompatibility;
            ChildData^.FFPCCompatibility := LazarusPackage.FPCCompatibility;
            ChildData^.FSupportedWidgetSet := LazarusPackage.SupportedWidgetSet;
            ChildData^.FPackageType := LazarusPackage.PackageType;
            ChildData^.FLicense := LazarusPackage.License;
            ChildData^.FDependenciesAsString := LazarusPackage.DependenciesAsString;
            ChildData^.FDataType := 2;
          end;
        end;
      end;
    finally
      Ms.Free;
    end;
  end;
  if RootNode <> nil then
  begin
    FVSTPackages.Selected[RootNode] := True;
    FVSTPackages.FocusedNode := RootNode;
    FVSTPackages.Expanded[RootNode] := True;
  end;
end;

function TCreateRepositoryFrm.GetDisplayString(const AStr: String): String;
var
  SL: TStringList;
  I: Integer;
begin
  Result := '';
  SL := TStringList.Create;
  try
    SL.Text := AStr;
    for I := 0 to SL.Count - 1 do
      if Result = '' then
        Result := SL.Strings[I]
      else
        Result := Result + ' ' + SL.Strings[I];
  finally
    SL.Free;
  end;
end;

procedure TCreateRepositoryFrm.VSTPackagesGetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: String);
var
  Data: PData;
begin
  Data := FVSTPackages.GetNodeData(Node);
  case Data^.FDataType of
    0: CellText := FRepository.FName;
    1: CellText := Data^.FName;
    2: CellText := Data^.FName;
  end;
end;

procedure TCreateRepositoryFrm.VSTPackagesGetImageIndex(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex;
  var Ghosted: Boolean; var ImageIndex: Integer);
var
  Data: PData;
begin
  Data := FVSTPackages.GetNodeData(Node);
  ImageIndex := Data^.FDataType;
end;

procedure TCreateRepositoryFrm.VSTPackagesHeaderClick(Sender: TVTHeader;
  Column: TColumnIndex; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    with Sender, Treeview do
    begin
      if (SortColumn = NoColumn) or (SortColumn <> Column) then
      begin
        SortColumn    := Column;
        SortDirection := opkman_VirtualTrees.sdAscending;
      end
      else
      begin
        if SortDirection = opkman_VirtualTrees.sdAscending then
          SortDirection := opkman_VirtualTrees.sdDescending
        else
          SortDirection := opkman_VirtualTrees.sdAscending;
      end;
      SortTree(SortColumn, SortDirection, False);
    end;
  end;
end;

procedure TCreateRepositoryFrm.VSTPackagesCompareNodes(Sender: TBaseVirtualTree; Node1,
  Node2: PVirtualNode; Column: TColumnIndex; var Result: Integer);
var
  Data1: PData;
  Data2: PData;
begin
  Data1 := Sender.GetNodeData(Node1);
  Data2 := Sender.GetNodeData(Node2);
  case Column of
    0: begin
         if (Data1^.FDataType < Data2^.FDataType) then
           Result := 0
         else
           Result := CompareText(Data1^.FName, Data2^.FName)
       end;
  end;
end;

procedure TCreateRepositoryFrm.VSTPackagesFocusChanged(
  Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex);
var
  Data: PData;
  DetailNode: PVirtualNode;
  DetailData: PData;
begin
  if Node = nil then
    Exit;

  FVSTDetails.Clear;
  Data := FVSTPackages.GetNodeData(Node);
  case Data^.FDataType of
    0: begin
         //address
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FDataType := 0;
         DetailData^.FRepository.FAddress := FRepository.FAddress;
         //description
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FDataType := 1;
         DetailData^.FRepository.FDescription := FRepository.FDescription;
       end;
    1: begin
         //add category(DataType = 12)
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FCategory := Data^.FCategory;
         DetailData^.FDataType := 12;
         //add Repository Filename(DataType = 13)
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FRepositoryFileName := Data^.FRepositoryFileName;
         DetailData^.FDataType := 13;
         //add Repository Filesize(DataType = 14)
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FRepositoryFileSize := Data^.FRepositoryFileSize;
         DetailData^.FDataType := 14;
         //add Repository Hash(DataType = 15)
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FRepositoryFileHash := Data^.FRepositoryFileHash;
         DetailData^.FDataType := 15;
         //add Repository Date(DataType = 16)
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FRepositoryDate := Data^.FRepositoryDate;
         DetailData^.FDataType := 16;
         FVSTDetails.Expanded[DetailNode] := True;
         //add HomePageURL(DataType = 17)
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FHomePageURL := Data^.FHomePageURL;
         DetailData^.FDataType := 17;
         //add DownloadURL(DataType = 18)
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FDownloadURL := Data^.FDownloadURL;
         DetailData^.FDataType := 18;
       end;
    2: begin
         //add description(DataType = 2)
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FVersionAsString := Data^.FVersionAsString;
         DetailData^.FDataType := 2;
         //add description(DataType = 3)
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FDescription := Data^.FDescription;
         DetailData^.FDataType := 3;
         //add author(DataType = 4)
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FAuthor := Data^.FAuthor;
         DetailData^.FDataType := 4;
         //add lazcompatibility(DataType = 5)
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FLazCompatibility := Data^.FLazCompatibility;
         DetailData^.FDataType := 5;
         //add fpccompatibility(DataType = 6)
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FFPCCompatibility := Data^.FFPCCompatibility;
         DetailData^.FDataType := 6;
         //add widgetset(DataType = 7)
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FSupportedWidgetSet := Data^.FSupportedWidgetSet;
         DetailData^.FDataType := 7;
         //add packagetype(DataType = 8)
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FPackageType := Data^.FPackageType;
         DetailData^.FDataType := 8;
         //add license(DataType = 9)
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FLicense := Data^.FLicense;
         DetailData^.FDataType := 9;
         //add dependencies(DataType = 10)
         DetailNode := FVSTDetails.AddChild(nil);
         DetailData := FVSTDetails.GetNodeData(DetailNode);
         DetailData^.FDependenciesAsString := Data^.FDependenciesAsString;
         DetailData^.FDataType := 10;
       end;
  end;
  EnableDisableButtons(True);
end;

procedure TCreateRepositoryFrm.VSTPackagesFreeNode(Sender: TBaseVirtualTree;
  Node: PVirtualNode);
var
  Data: PData;
begin
  Data := FVSTPackages.GetNodeData(Node);
  Finalize(Data^);
end;

procedure TCreateRepositoryFrm.VSTDetailsGetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: String);
var
  PackageNode: PVirtualNode;
  PackageData: PData;
  DetailData: PData;
begin
  if TextType <> ttNormal then
    Exit;
  PackageNode := FVSTPackages.GetFirstSelected;
  if PackageNode = nil then
    Exit;

  PackageData := FVSTPackages.GetNodeData(PackageNode);
  case PackageData^.FDataType of
    0: begin
         DetailData := FVSTDetails.GetNodeData(Node);
         case DetailData^.FDataType of
           0: if Column = 0 then
                CellText := rsCreateRepositoryFrm_RepositoryAddress
              else
                CellText := DetailData^.FRepository.FAddress;
           1: if Column = 0 then
                CellText := rsCreateRepositoryFrm_RepositoryDescription
              else
                CellText := DetailData^.FRepository.FDescription;
         end;
       end;
    1: begin
         DetailData := FVSTDetails.GetNodeData(Node);
         case DetailData^.FDataType of
           12: if Column = 0 then
                 CellText := rsCreateRepositoryFrm_VSTText_Category
               else
                 CellText := DetailData^.FCategory;
           13: if Column = 0 then
                 CellText := rsCreateRepositoryFrm_VSTText_RepositoryFilename
               else
                 CellText := DetailData^.FRepositoryFileName;
           14: if Column = 0 then
                 CellText := rsCreateRepositoryFrm_VSTText_RepositoryFileSize
               else
                 CellText := FormatSize(DetailData^.FRepositoryFileSize);
           15: if Column = 0 then
                 CellText := rsCreateRepositoryFrm_VSTText_RepositoryFileHash
               else
                 CellText := DetailData^.FRepositoryFileHash;
           16: if Column = 0 then
                 CellText := rsCreateRepositoryFrm_VSTText_RepositoryFileDate
               else
                 CellText := FormatDateTime('YYYY.MM.DD', DetailData^.FRepositoryDate);
           17: if Column = 0 then
                 CellText := rsCreateRepositoryFrm_VSTText_HomePageURL
               else
                 CellText := DetailData^.FHomePageURL;
          18:  if Column = 0 then
                 CellText := rsCreateRepositoryFrm_VSTText_DownloadURL
               else
                 CellText := DetailData^.FDownloadURL;
         end;
       end;
    2: begin
         DetailData := FVSTDetails.GetNodeData(Node);
         case DetailData^.FDataType of
           2: if Column = 0 then
                CellText := rsCreateRepositoryFrm_VSTText_Version
              else
                CellText := DetailData^.FVersionAsString;
           3: if Column = 0 then
                CellText := rsCreateRepositoryFrm_VSTText_Description
              else
                CellText := GetDisplayString(DetailData^.FDescription);
           4: if Column = 0 then
                CellText := rsCreateRepositoryFrm_VSTText_Author
              else
                CellText := DetailData^.FAuthor;
           5: if Column = 0 then
                CellText := rsCreateRepositoryFrm_VSTText_LazCompatibility
              else
                CellText := DetailData^.FLazCompatibility;
           6: if Column = 0 then
                CellText := rsCreateRepositoryFrm_VSTText_FPCCompatibility
              else
                CellText := DetailData^.FFPCCompatibility;
           7: if Column = 0 then
                CellText := rsCreateRepositoryFrm_VSTText_SupportedWidgetsets
              else
                CellText := DetailData^.FSupportedWidgetSet;
           8: if Column = 0 then
                CellText := rsCreateRepositoryFrm_VSTText_Packagetype
              else
                case DetailData^.FPackageType of
                   ptRunAndDesignTime: CellText := rsMainFrm_VSTText_PackageType0;
                   ptDesignTime:       CellText := rsMainFrm_VSTText_PackageType1;
                   ptRunTime:          CellText := rsMainFrm_VSTText_PackageType2;
                   ptRunTimeOnly:      CellText := rsMainFrm_VSTText_PackageType3;
                end;
           9: if Column = 0 then
                CellText := rsCreateRepositoryFrm_VSTText_License
              else
                CellText := GetDisplayString(DetailData^.FLicense);
          10: if Column = 0 then
                CellText := rsCreateRepositoryFrm_VSTText_Dependecies
              else
                CellText := DetailData^.FDependenciesAsString;

         end;
       end;
  end;
end;

procedure TCreateRepositoryFrm.VSTDetailsGetImageIndex(
  Sender: TBaseVirtualTree; Node: PVirtualNode; Kind: TVTImageKind;
  Column: TColumnIndex; var Ghosted: Boolean; var ImageIndex: Integer);
var
  Data: PData;
begin
  if Column = 0 then
  begin
    Data := FVSTDetails.GetNodeData(Node);
    ImageIndex := Data^.FDataType;
  end;
end;

procedure TCreateRepositoryFrm.VSTDetailsFreeNode(Sender: TBaseVirtualTree;
  Node: PVirtualNode);
var
  Data: PData;
begin
  Data := FVSTPackages.GetNodeData(Node);
  Finalize(Data^);
end;

end.

