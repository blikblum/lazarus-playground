unit FppkgHelper;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  {$IFNDEF VER3_0}
  pkgFppkg,
  {$ENDIF VER3_0}
  fprepos;

type

  TFppkgPackageVariantArray = array of TStringArray;

  { TFppkgHelper }

  TFppkgHelper = class
  private
    {$IFNDEF VER3_0}
    FFPpkg: TpkgFPpkg;
    {$ENDIF}
  public
    constructor Create;
    destructor Destroy; override;
    class function Instance: TFppkgHelper;
    function HasPackage(const PackageName: string): Boolean;
    procedure ListPackages(AList: TStringList);
    function GetPackageUnitPath(const PackageName: string): string;
    // Temporary solution, because fpc 3.2.0 does not has support for package-variants
    // in TFPPackage
    function GetPackageVariantArray(const PackageName: string): TFppkgPackageVariantArray;
  end;

implementation

var
  GFppkgHelper: TFppkgHelper = nil;

{ TFppkgHelper }

constructor TFppkgHelper.Create;
{$IFNDEF VER3_0}
var
  FPpkg: TpkgFPpkg;
begin
  FPpkg := TpkgFPpkg.Create(nil);
  try
    FPpkg.InitializeGlobalOptions('');
    FPpkg.InitializeCompilerOptions;

    FPpkg.CompilerOptions.CheckCompilerValues;
    FPpkg.FpmakeCompilerOptions.CheckCompilerValues;

    FPpkg.LoadLocalAvailableMirrors;

    FPpkg.ScanPackages;

    FFPpkg := FPpkg;
    FPpkg := nil;
  finally
    FPpkg.Free;
  end;
end;
{$ELSE}
begin

end;
{$ENDIF VER3_0}

destructor TFppkgHelper.Destroy;
begin
{$IFNDEF VER3_0}
  FFPpkg.Free;
{$ENDIF VER3_0}
  inherited Destroy;
end;

class function TFppkgHelper.Instance: TFppkgHelper;
begin
  if not Assigned(GFppkgHelper) then
    GFppkgHelper := TFppkgHelper.Create;
  Result := GFppkgHelper;
end;

function TFppkgHelper.HasPackage(const PackageName: string): Boolean;
begin
{$IFNDEF VER3_0}
  Result :=
    Assigned(FFPpkg.FindPackage(PackageName,pkgpkInstalled)) or
    Assigned(FFPpkg.FindPackage(PackageName,pkgpkAvailable)) or
    Assigned(FFPpkg.FindPackage(PackageName,pkgpkBoth));

  if not Result then
    begin
    // rescan and try again
    FFppkg.LoadLocalAvailableMirrors;
    FFppkg.ScanPackages;

    Result :=
      Assigned(FFPpkg.FindPackage(PackageName,pkgpkInstalled)) or
      Assigned(FFPpkg.FindPackage(PackageName,pkgpkAvailable)) or
      Assigned(FFPpkg.FindPackage(PackageName,pkgpkBoth));
    end;
{$ELSE }
  Result := True;
{$ENDIF VER3_0}
end;

procedure TFppkgHelper.ListPackages(AList: TStringList);
{$IFNDEF VER3_0}
var
  I, J: Integer;
  Repository: TFPRepository;
{$ENDIF VER3_0}
begin
{$IFNDEF VER3_0}
  for I := 0 to FFPpkg.RepositoryList.Count -1 do
    begin
    Repository := FFPpkg.RepositoryList.Items[I] as TFPRepository;
    for J := 0 to Repository.PackageCount -1 do
      begin
      AList.AddObject(Repository.Packages[J].Name, Repository.Packages[J]);
      end;
    end;
{$ENDIF VER3_0}
end;

function TFppkgHelper.GetPackageUnitPath(const PackageName: string): string;
{$IFNDEF VER3_0}
var
  FppkgPackage: TFPPackage;
{$IF not (FPC_FULLVERSION>30300)}
  PackageVariantsArray: TFppkgPackageVariantArray;
{$ENDIF}
  i: Integer;
{$ENDIF VER3_0}
begin
{$IFNDEF VER3_0}
  FppkgPackage := FFPpkg.FindPackage(PackageName, pkgpkInstalled);
  if Assigned(FppkgPackage) then
    begin
    Result := FppkgPackage.PackagesStructure.GetUnitDirectory(FppkgPackage);

    {$IF FPC_FULLVERSION>30300}
    for i := 0 to FppkgPackage.PackageVariants.Count -1 do
      begin
      Result := ConcatPaths([Result, FppkgPackage.PackageVariants.Items[i].Options[0]]);
      end;
    {$ELSE}
    PackageVariantsArray := GetPackageVariantArray(PackageName);
    for i := 0 to High(PackageVariantsArray) do
      begin
      Result := ConcatPaths([Result, PackageVariantsArray[i][1]]);
      end;
    {$ENDIF FPC_FULLVERSION>30300}
    end
  else
    begin
    // The package has not been installed, so there is no unit-path yet.
    // ToDo: if this leads to problems, we could 'guess' the repository it will
    // be installed into, and use the corresponding packagestructure.
    Result := '';
    end;
{$ELSE }
  Result := '';
{$ENDIF VER3_0}
end;

function TFppkgHelper.GetPackageVariantArray(const PackageName: string): TFppkgPackageVariantArray;
{$IF FPC_FULLVERSION>30100}
var
  FppkgPackage: TFPPackage;
  UnitConfigFile: TStringList;
  PackageVariantStr, PackageVariant, UnitConfigFilename: String;
  PackageVariantOptions: TStringArray;
  i: Integer;
{$ENDIF FPC_FULLVERSION>30100}
begin
  {$IF FPC_FULLVERSION>30100}
  Result := [];
  {$ELSE}
  SetLength(Result, 0);
  {$ENDIF FPC_FULLVERSION>30100}

  {$IF FPC_FULLVERSION>30100}
  FppkgPackage := FFPpkg.FindPackage(PackageName, pkgpkInstalled);
  if Assigned(FppkgPackage) then
    begin
    UnitConfigFilename := FppkgPackage.PackagesStructure.GetConfigFileForPackage(FppkgPackage);
    if FileExists(UnitConfigFilename) then
      begin
      UnitConfigFile := TStringList.Create;
      try
        UnitConfigFile.LoadFromFile(UnitConfigFilename);
        i := 1;
        repeat
        PackageVariantStr := UnitConfigFile.Values['PackageVariant_'+IntToStr(i)];
        if PackageVariantStr<>'' then
          begin
          PackageVariant := Copy(PackageVariantStr, 1, pos(':', PackageVariantStr) -1);
          if RightStr(PackageVariant, 1) = '*' then
            PackageVariant := Copy(PackageVariant, 1, Length(PackageVariant) -1);
          PackageVariantOptions := Copy(PackageVariantStr, pos(':', PackageVariantStr) +1).Split(',');
          Insert(PackageVariant, PackageVariantOptions, -1);
          Insert(PackageVariantOptions, Result, 100);
          end;
        inc(i);
        until PackageVariantStr='';
      finally
        UnitConfigFile.Free;
      end;
      end
    end
  {$ENDIF FPC_FULLVERSION>30100}
end;

finalization
  GFppkgHelper.Free;
end.
