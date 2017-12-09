{ Register IDE items
}
unit RegProjectGroup;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ProjectGroupIntf, MenuIntf, IDECommands, ToolBarIntf,
  ProjectGroupStrConst, ProjectGroup, ProjectGroupEditor;

procedure RegisterProjectGroupEditorMenuItems;
procedure Register;

implementation

const
  ProjectGroupEditorMenuRootName = 'ProjectGroupEditorMenu';

procedure RegisterProjectGroupEditorMenuItems;

  procedure RegisterMenuCmd(out MenuCmd: TIDEMenuCommand;
    Section: TIDEMenuSection; const Name, Caption: string);
  begin
    MenuCmd:=RegisterIDEMenuCommand(Section,Name,Caption);
  end;

var
  MnuRoot, MnuSection: TIDEMenuSection;
begin
  MnuRoot:=RegisterIDEMenuRoot(ProjectGroupEditorMenuRootName);
  ProjectGroupEditorMenuRoot:=MnuRoot;

  PGEditMenuSectionFiles:=RegisterIDEMenuSection(MnuRoot,'File');

  MnuSection:=RegisterIDEMenuSection(MnuRoot,'Compile');
  PGEditMenuSectionCompile:=MnuSection;
  RegisterMenuCmd(MnuCmdTargetCompile,MnuSection,'TargetCompile',lisTargetCompile);
  RegisterMenuCmd(MnuCmdTargetCompileClean,MnuSection,'TargetCompileClean',lisTargetCompileClean);
  RegisterMenuCmd(MnuCmdTargetCompileFromHere,MnuSection,'TargetCompileFromHere',lisTargetCompileFromHere);
  // ToDo: clean ... -> clean up dialog
  // ToDo: set build mode of all projects

  MnuSection:=RegisterIDEMenuSection(MnuRoot,'AddRemove');
  PGEditMenuSectionAddRemove:=MnuSection;
  RegisterMenuCmd(MnuCmdTargetAdd,MnuSection,'TargetAdd',lisTargetAdd);
  RegisterMenuCmd(MnuCmdTargetRemove,MnuSection,'TargetRemove',lisTargetRemove);
  // ToDo: undo

  MnuSection:=RegisterIDEMenuSection(MnuRoot,'Use');
  PGEditMenuSectionUse:=MnuSection;
  RegisterMenuCmd(MnuCmdTargetInstall,MnuSection,'TargetInstall',lisTargetInstall);// ToDo
  RegisterMenuCmd(MnuCmdTargetUninstall,MnuSection,'TargetUninstall',lisTargetUninstall);// ToDo
  RegisterMenuCmd(MnuCmdTargetEarlier,MnuSection,'TargetEarlier',lisTargetEarlier);// ToDo: Ctrl+Up
  RegisterMenuCmd(MnuCmdTargetLater,MnuSection,'TargetLater',lisTargetLater);// ToDo: Ctrl+Down
  RegisterMenuCmd(MnuCmdTargetActivate,MnuSection,'TargetActivate',lisTargetActivate);
  RegisterMenuCmd(MnuCmdTargetOpen,MnuSection,'TargetOpen',lisTargetOpen);
  RegisterMenuCmd(MnuCmdTargetRun,MnuSection,'TargetRun',lisTargetRun);
  RegisterMenuCmd(MnuCmdTargetProperties,MnuSection,'TargetProperties',lisTargetProperties);

  MnuSection:=RegisterIDEMenuSection(MnuRoot,'Misc');
  PGEditMenuSectionMisc:=MnuSection;

  RegisterMenuCmd(MnuCmdTargetCopyFilename,MnuSection,'CopyFilename',lisTargetCopyFilename);
  // ToDo: View source (project)

  // ToDo: find in files
  // ToDo: find references in files

  // ToDo: D&D order compile targets
end;

procedure Register;

  procedure RegisterMnuCmd(out Cmd: TIDECommand; out MenuCmd: TIDEMenuCommand;
    Section: TIDEMenuSection; const Name, Caption: string;
    const OnExecuteMethod: TNotifyEvent);
  begin
    Cmd:=RegisterIDECommand(PGCmdCategory,Name,Caption,OnExecuteMethod);
    MenuCmd:=RegisterIDEMenuCommand(Section,Name,Caption,nil,nil,Cmd);
    RegisterIDEButtonCommand(Cmd);
  end;

begin
  IDEProjectGroupManager:=TIDEProjectGroupManager.Create;
  IDEProjectGroupManager.Options.LoadSafe;

  PGCmdCategory:=RegisterIDECommandCategory(nil,ProjectGroupCmdCategoryName,lisProjectGroups);

  RegisterMnuCmd(CmdNewProjectGroup,MnuCmdNewProjectGroup,itmProjectNewSection,
    'New Project Group',lisNewProjectGroupMenuC,@IDEProjectGroupManager.DoNewClick);
  RegisterMnuCmd(CmdOpenProjectGroup,MnuCmdOpenProjectGroup,itmProjectOpenSection,
    'Open Project Group',lisOpenProjectGroup,@IDEProjectGroupManager.DoOpenClick);
  PGOpenRecentSubMenu:=RegisterIDESubMenu(itmProjectOpenSection,
    'Open recent Project Group',lisOpenRecentProjectGroup);
  RegisterMnuCmd(CmdSaveProjectGroup,MnuCmdSaveProjectGroup,itmProjectSaveSection,
    'Save Project Group',lisSaveProjectGroup,@IDEProjectGroupManager.DoSaveClick);
  MnuCmdSaveProjectGroup.Enabled:=false;
  RegisterMnuCmd(CmdSaveProjectGroupAs,MnuCmdSaveProjectGroupAs,itmProjectSaveSection,
    'Save Project Group as',lisSaveProjectGroupAs,@IDEProjectGroupManager.DoSaveAsClick);
  MnuCmdSaveProjectGroupAs.Enabled:=false;

  RegisterProjectGroupEditorMenuItems;

  IDEProjectGroupManager.UpdateRecentProjectGroupMenu;

  ProjectGroupManager:=IDEProjectGroupManager;
  SetProjectGroupEditorCallBack;
end;

finalization
  FreeAndNil(IDEProjectGroupManager);

end.

