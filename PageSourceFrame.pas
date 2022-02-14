unit PageSourceFrame;

interface

uses
  System.Threading,
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo, FMX.Ani, FMX.Objects,
  FMX.Layouts;

type
  TPageSourceFrm = class(TFrame)
    WebAddressLabel: TLabel;
    ResponseMemo: TMemo;
    ProgressCircle: TCircle;
    ProgressXFloatAnimation: TFloatAnimation;
    ProgressEllipse: TEllipse;
    Background: TRectangle;
    Layout: TLayout;
    ProgressLayout: TLayout;
    ProgressBackground: TEllipse;
    procedure ProgressXFloatAnimationFinish(Sender: TObject);
    procedure ProgressXFloatAnimationProcess(Sender: TObject);
    procedure LayoutResize(Sender: TObject);
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
  ProgressLayout.Visible := Running;
end;

procedure TPageSourceFrm.LayoutResize(Sender: TObject);
begin
  with ProgressLayout do SetBounds(Position.X, Position.Y, Self.Width/3, Self.Height/12);
  with ProgressBackground do SetBounds(-10, -5, ProgressLayout.Width+20, ProgressLayout.Height+10);
  ProgressXFloatAnimation.StopValue := ProgressLayout.Width - ProgressCircle.Width;
  a := 0;
end;

procedure TPageSourceFrm.ProgressContinue(Running: Boolean);
begin
  if not Running then Exit;
  if not ProgressXFloatAnimation.Running then ProgressXFloatAnimation.Start;
  ProgressXFloatAnimation.Pause := FALSE;
  ProgressLayout.Visible := TRUE;
end;

procedure TPageSourceFrm.ProgressXFloatAnimationFinish(Sender: TObject);
begin
  ProgressXFloatAnimation.Inverse := not ProgressXFloatAnimation.Inverse;
  if ProgressXFloatAnimation.Inverse then begin
    ProgressCircle.SendToBack;
    ProgressBackground.SendToBack;
    with ProgressCircle do SetBounds(Position.X, Position.Y, Width-CircleBackDelta, Height-CircleBackDelta);
  end else begin
    ProgressCircle.BringToFront;
    with ProgressCircle do SetBounds(Position.X, Position.Y, Width+CircleBackDelta, Height+CircleBackDelta);
  end;
  ProgressContinue(ProgressLayout.Visible);
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

