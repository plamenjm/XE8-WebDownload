program WebDownload;

uses
  System.StartUpCopy,
  FMX.Forms,
  MainForm in 'MainForm.pas' {MainFrm},
  IntroFrame in 'IntroFrame.pas' {IntroFrm: TFrame},
  PageAddressFrame in 'PageAddressFrame.pas' {PageAddressFrm: TFrame},
  PageSourceFrame in 'PageSourceFrame.pas' {PageSourceFrm: TFrame};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainFrm, MainFrm);
  Application.Run;
end.

