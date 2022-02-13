unit PageSourceFrame;

interface

uses
  System.Threading,
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo, FMX.Ani, FMX.Objects;

type
  TPageSourceFrm = class(TFrame)
    Panel1: TPanel;
    WebAddressLabel: TLabel;
    ResponseMemo: TMemo;
    ProgressPanel: TPanel;
    ProgressCircle: TCircle;
    ProgressXFloatAnimation: TFloatAnimation;
    ProgressEllipse: TEllipse;
    procedure ProgressXFloatAnimationFinish(Sender: TObject);
    procedure ProgressXFloatAnimationProcess(Sender: TObject);
  private
    { Private declarations }
    a, b, ba, aa: Double; // ellipse animation
  public
    { Public declarations }
    procedure ProgressPause(Running: Boolean);
    procedure ProgressContinue(Running: Boolean);
  end;

implementation

uses
  Math;

const
  CircleBackDelta = 2;

{$R *.fmx}

procedure TPageSourceFrm.ProgressPause(Running: Boolean);
begin
  ProgressXFloatAnimation.Pause := TRUE;
  ProgressPanel.Visible := Running;
end;

procedure TPageSourceFrm.ProgressContinue(Running: Boolean);
begin
  if not Running then Exit;
  if not ProgressXFloatAnimation.Running then ProgressXFloatAnimation.Start;
  ProgressXFloatAnimation.Pause := FALSE;
  ProgressPanel.Visible := TRUE;
end;

procedure TPageSourceFrm.ProgressXFloatAnimationFinish(Sender: TObject);
begin
  ProgressXFloatAnimation.Inverse := not ProgressXFloatAnimation.Inverse;
  if ProgressXFloatAnimation.Inverse then begin
    ProgressCircle.SendToBack;
    with ProgressCircle do SetBounds(Position.X, Position.Y, Width-CircleBackDelta, Height-CircleBackDelta);
  end else begin
    ProgressCircle.BringToFront;
    with ProgressCircle do SetBounds(Position.X, Position.Y, Width+CircleBackDelta, Height+CircleBackDelta);
  end;
  ProgressContinue(ProgressPanel.Visible);
end;

procedure TPageSourceFrm.ProgressXFloatAnimationProcess(Sender: TObject);
var x, y: Double;
begin
  if a = 0 then begin
    a := ProgressXFloatAnimation.StopValue / 2;
    b := ProgressEllipse.Height / 2;
    aa := a * a; ba := b / a;
  end;
  x := ProgressCircle.Position.X - a;
  y := ba * sqrt(aa - x * x);

  if ProgressXFloatAnimation.Inverse then
    ProgressCircle.Position.Y := b + CircleBackDelta*2 - y
  else
    ProgressCircle.Position.Y := b + y;
end;

end.

