unit PageAddressFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Edit, FMX.Controls.Presentation, FMX.Objects, FMX.Layouts;

type
  TPageAddressFrm = class(TFrame)
    Background: TRectangle;
    Layout: TLayout;
    WebAddressLabel: TLabel;
    WebAddressEdit: TEdit;
    DownloadRectangle: TRectangle;
    DownloadButton: TSpeedButton;
    procedure WebAddressEditKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

implementation

{$R *.fmx}

procedure TPageAddressFrm.WebAddressEditKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
begin
  if (Key = vkReturn) and Assigned(DownloadButton.OnClick) then DownloadButton.OnClick(nil);
end;

end.

