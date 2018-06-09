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
}
unit codetools_identifiercompletion_options;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  // LCL
  Forms, StdCtrls,
  // LazControls
  DividerBevel,
  // IdeIntf
  IDEOptionsIntf, IDEOptEditorIntf,
  // IDE
  CodeToolsOptions, LazarusIDEStrConsts;

type

  { TCodetoolsIndentifierCompletionOptionsFrame }

  TCodetoolsIndentifierCompletionOptionsFrame = class(TAbstractIDEOptionsEditor)
    ICContainsFilterCheckBox: TCheckBox;
    ICAddDoCheckBox: TCheckBox;
    ICAutoAddParameterBracketsCheckBox: TCheckBox;
    ICMiscDividerBevel: TDividerBevel;
    ICOpenDividerBevel: TDividerBevel;
    ICAutoStartAfterPointCheckBox: TCheckBox;
    ICAddAssignOperatorCheckBox: TCheckBox;
    ICAddSemicolonCheckBox: TCheckBox;
    ICAddDividerBevel: TDividerBevel;
    ICReplaceCheckBox: TCheckBox;
    ICJumpToErrorCheckBox: TCheckBox;
    ICShowHelpCheckBox: TCheckBox;
    ICAutoUseSingleIdent: TCheckBox;
    ICSortDividerBevel: TDividerBevel;
    ICAppearanceDividerBevel: TDividerBevel;
    ICSortForHistoryCheckBox: TCheckBox;
    ICSortForScopeCheckBox: TCheckBox;
    ICUseIconsInCompletionBoxCheckBox: TCheckBox;
  private
  public
    function GetTitle: String; override;
    procedure Setup({%H-}ADialog: TAbstractOptionsEditorDialog); override;
    procedure ReadSettings(AOptions: TAbstractIDEOptions); override;
    procedure WriteSettings(AOptions: TAbstractIDEOptions); override;
    class function SupportedOptionsClass: TAbstractIDEOptionsClass; override;
  end;

implementation

{$R *.lfm}

{ TCodetoolsIndentifierCompletionOptionsFrame }

function TCodetoolsIndentifierCompletionOptionsFrame.GetTitle: String;
begin
  Result := dlgIdentifierCompletion;
end;

procedure TCodetoolsIndentifierCompletionOptionsFrame.Setup(
  ADialog: TAbstractOptionsEditorDialog);
begin
  ICOpenDividerBevel.Caption:=lisIdCOpening;
  ICAutoStartAfterPointCheckBox.Caption:=lisAutomaticallyInvokeAfterPoint;
  ICAutoUseSingleIdent.Caption:=lisAutomaticallyUseSinglePossibleIdent;
  ICAutoUseSingleIdent.Hint:=
    lisWhenThereIsOnlyOnePossibleCompletionItemUseItImmed;
  ICShowHelpCheckBox.Caption:=lisShowHelp;
  ICShowHelpCheckBox.Hint:=lisBestViewedByInstallingAHTMLControlLikeTurbopowerip;

  ICAddDividerBevel.Caption:=lisIdCAddition;
  ICAddSemicolonCheckBox.Caption:=dlgAddSemicolon;
  ICAddAssignOperatorCheckBox.Caption:=dlgAddAssignmentOperator;
  ICAddDoCheckBox.Caption:=lisAddKeywordDo;
  ICAutoAddParameterBracketsCheckBox.Caption:=lisAddParameterBrackets;

  ICSortDividerBevel.Caption:=lisSorting;
  ICSortForHistoryCheckBox.Caption:=lisShowRecentlyUsedIdentifiersAtTop;
  ICSortForScopeCheckBox.Caption:=lisSortForScope;
  ICSortForScopeCheckBox.Hint:=lisForExampleShowAtTopTheLocalVariablesThenTheMembers;
  ICContainsFilterCheckBox.Caption := dlgIncludeIdentifiersContainingPrefix;

  ICAppearanceDividerBevel.Caption:=lisAppearance;
  ICUseIconsInCompletionBoxCheckBox.Caption := dlgUseIconsInCompletionBox;

  ICMiscDividerBevel.Caption:=dlgEnvMisc;
  ICReplaceCheckBox.Caption:=lisReplaceWholeIdentifier;
  ICReplaceCheckBox.Hint:=lisEnableReplaceWholeIdentifierDisableReplacePrefix;
  ICJumpToErrorCheckBox.Caption:=lisJumpToError;
  ICJumpToErrorCheckBox.Hint:=lisJumpToErrorAtIdentifierCompletion;
end;

procedure TCodetoolsIndentifierCompletionOptionsFrame.ReadSettings(
  AOptions: TAbstractIDEOptions);
begin
  with AOptions as TCodeToolsOptions do
  begin
    ICAddSemicolonCheckBox.Checked := IdentComplAddSemicolon;
    ICAddAssignOperatorCheckBox.Checked := IdentComplAddAssignOperator;
    ICAddDoCheckBox.Checked := IdentComplAddDo;
    ICAutoStartAfterPointCheckBox.Checked := IdentComplAutoStartAfterPoint;
    ICAutoUseSingleIdent.Checked := IdentComplAutoUseSingleIdent;
    ICAutoAddParameterBracketsCheckBox.Checked:=IdentComplAddParameterBrackets;
    ICReplaceCheckBox.Checked:=IdentComplReplaceIdentifier;
    ICJumpToErrorCheckBox.Checked:=IdentComplJumpToError;
    ICShowHelpCheckBox.Checked:=IdentComplShowHelp;
    ICSortForHistoryCheckBox.Checked:=IdentComplSortForHistory;
    ICSortForScopeCheckBox.Checked:=IdentComplSortForScope;
    ICContainsFilterCheckBox.Checked:=IdentComplUseContainsFilter;
    ICUseIconsInCompletionBoxCheckBox.Checked:=IdentComplShowIcons;
  end;
end;

procedure TCodetoolsIndentifierCompletionOptionsFrame.WriteSettings(
  AOptions: TAbstractIDEOptions);
begin
  with AOptions as TCodeToolsOptions do
  begin
    IdentComplAddSemicolon := ICAddSemicolonCheckBox.Checked;
    IdentComplAddAssignOperator := ICAddAssignOperatorCheckBox.Checked;
    IdentComplAddDo := ICAddDoCheckBox.Checked;
    IdentComplAutoStartAfterPoint := ICAutoStartAfterPointCheckBox.Checked;
    IdentComplAutoUseSingleIdent := ICAutoUseSingleIdent.Checked;
    IdentComplAddParameterBrackets:=ICAutoAddParameterBracketsCheckBox.Checked;
    IdentComplReplaceIdentifier:=ICReplaceCheckBox.Checked;
    IdentComplJumpToError:=ICJumpToErrorCheckBox.Checked;
    IdentComplShowHelp:=ICShowHelpCheckBox.Checked;
    IdentComplSortForHistory:=ICSortForHistoryCheckBox.Checked;
    IdentComplSortForScope:=ICSortForScopeCheckBox.Checked;
    IdentComplUseContainsFilter:=ICContainsFilterCheckBox.Checked;
    IdentComplShowIcons:=ICUseIconsInCompletionBoxCheckBox.Checked;
  end;
end;

class function TCodetoolsIndentifierCompletionOptionsFrame.SupportedOptionsClass: TAbstractIDEOptionsClass;
begin
  Result := TCodeToolsOptions;
end;

initialization
  RegisterIDEOptionsEditor(GroupCodetools, TCodetoolsIndentifierCompletionOptionsFrame, CdtOptionsIdentCompletion);
end.

