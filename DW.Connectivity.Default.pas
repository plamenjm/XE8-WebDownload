unit DW.Connectivity.Default;

{*******************************************************}
{                                                       }
{                    Kastri Free                        }
{                                                       }
{          DelphiWorlds Cross-Platform Library          }
{                                                       }
{*******************************************************}

// org: {$I DW.GlobalDefines.inc}
interface

uses
  DW.Connectivity;

type
  TPlatformConnectivity = class(TObject)
  public
    class function IsConnectedToInternet: Boolean;
    class function IsWifiInternetConnection: Boolean;
  public
    constructor Create(const AConnectivity: TConnectivity);
  end;

implementation

{ TPlatformConnectivity }

constructor TPlatformConnectivity.Create(const AConnectivity: TConnectivity);
begin
  inherited Create;
  //
end;

class function TPlatformConnectivity.IsConnectedToInternet: Boolean;
begin
  // org: Result := False;
  Result := TRUE;
end;

class function TPlatformConnectivity.IsWifiInternetConnection: Boolean;
begin
  // org: Result := False;
  Result := TRUE;
end;

end.

