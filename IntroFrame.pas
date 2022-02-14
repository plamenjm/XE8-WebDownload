unit IntroFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Layouts, FMX.Objects;

type
  TIntroFrm = class(TFrame)
    Background: TRectangle;
    Layout: TLayout;
    WelcomeLabel: TLabel;
    GetStartedRectangle: TRectangle;
    GetStartedButton: TSpeedButton;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

implementation

{$R *.fmx}

end.

