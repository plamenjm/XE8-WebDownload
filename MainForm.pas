unit MainForm;

interface

uses
  System.Threading, IdComponent,
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.TabControl, IntroFrame, PageAddressFrame, PageSourceFrame;

type
  ITaskStoppable = interface
    ['{22733B02-8E29-450C-9DCC-1C10E2153E8B}']
    procedure Stop;
    function CheckStopped(RaiseError: Boolean = FALSE; RemoveEvents: Boolean = TRUE): Boolean;
    function IsComplete: Boolean;
    function StopAndWait(Timeout: LongWord = INFINITE): Boolean;
    //procedure Queue(const AThread: TThread; AMethod: TThreadMethod);
  end;

  TTaskStoppable = class(TTask, ITaskStoppable) // because: Task.IsComplete after Task.Cancel and no Task.Wait
    // https://quality.embarcadero.com/browse/RSP-11267
    // https://stackoverflow.com/questions/44080089/how-to-stop-a-running-ttask-thread-safe
  private
    Stopped: Boolean;
  public
    destructor Destroy; override;
    procedure Stop;
    function CheckStopped(RaiseError: Boolean = FALSE; RemoveEvents: Boolean = TRUE): Boolean;
    function IsComplete: Boolean;
    function StopAndWait(Timeout: LongWord = INFINITE): Boolean;
    //procedure Queue(const AThread: TThread; AMethod: TThreadMethod);
  end;

type
  TMainFrm = class(TForm)
    TabControl: TTabControl;
    IntroTabItem: TTabItem;
    PageAddressTabItem: TTabItem;
    PageSourceTabItem: TTabItem;
    IntroFrm: TIntroFrm;
    PageAddressFrm: TPageAddressFrm;
    PageSourceFrm: TPageSourceFrm;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormActivate(Sender: TObject);
    procedure FormDeactivate(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    procedure TabControlChange(Sender: TObject);
    procedure IntroFrmGetStartedButtonClick(Sender: TObject);
    procedure PageAddressFrmDownloadButtonClick(Sender: TObject);
  private
    { Private declarations }
    BackPressed: Boolean;
  private
    DownloadTask: ITask;
    DownloadStop: ITaskStoppable;
    DownloadURL: String;
    function IsDownloading: Boolean;
    procedure Download(Sender: TObject);
    procedure Download_Progress;
    procedure Download_Status(ASender: TObject; const AStatus: TIdStatus; const AStatusText: string);
    procedure Download_Get(var Data: String);
    procedure Download_Show(Data: String);
    procedure Download_Done;
  public
    { Public declarations }
  end;

var
  MainFrm: TMainFrm;

implementation

uses
  System.TypInfo, IdStack, {$IFDEF MSWINDOWS} Windows, {$ENDIF} // test: Trace, OutputDebugString
  DW.Connectivity, {$IFDEF ANDROID} UI.Toast.Android, {$ENDIF} // from: https://github.com/yangyxd/FMXUI
  System.Net.HttpClientComponent, System.Net.HttpClient,
  StrUtils, IdHTTP;

{$R *.fmx}

var // TEST
  TESTAuto: Boolean = FALSE;
  TESTStoppable: Boolean = FALSE;
  TESTSimulate: Boolean = FALSE;
  TESTFragments: Integer = 10; // =1: no fragments, no delay
  TESTTrace: String = ''; // empty: disable trace
var // SWITCH
  MODECheckConnected: Boolean = FALSE;
  MODENetHTTP: Boolean = FALSE;
const
  TimeoutConnect = 5000;
//------------------------------------------------------------------------------
{$IFNDEF ANDROID}
type
  TToastLength = (LongToast, ShortToast);
{$ENDIF}

procedure ShowToast(const Msg: String; Duration: TToastLength = ShortToast);
begin
  {$IFDEF ANDROID}
    Toast(Msg, ShortToast);
  {$ELSE}
    ShowMessage(Msg);
  {$ENDIF}
end;
//------------------------------------------------------------------------------

{ TTaskStoppable }

destructor TTaskStoppable.Destroy;
begin
  if TThread.Current.ThreadID = MainThreadID then StopAndWait;
  inherited;
end;

procedure TTaskStoppable.Stop;
begin
  if TThread.Current.ThreadID <> MainThreadID then raise EOperationCanceled.Create('NA'); // just in case
  Stopped := TRUE;
end;

function TTaskStoppable.CheckStopped(RaiseError: Boolean = FALSE; RemoveEvents: Boolean = TRUE): Boolean;
begin
  Result := Stopped;
  if not Stopped then Exit;
  if RemoveEvents then
    if TThread.Current.ThreadID <> MainThreadID then // just in case
      TThread.RemoveQueuedEvents(TThread.Current);
  if RaiseError then Abort; //todo: Android crash on handled/hidden exception (Android 8) - Delphi, SDK, Android version?
end;

function TTaskStoppable.IsComplete: Boolean;
begin
  Result := GetIsComplete;
end;

function TTaskStoppable.StopAndWait(Timeout: LongWord = INFINITE): Boolean;
begin
  if TThread.Current.ThreadID <> MainThreadID then raise EOperationCanceled.Create('NA'); // just in case
  Result := TRUE;
  Stop; // because: Task.IsComplete after Task.Cancel and no Task.Wait
  try
    //if (Self as ITask).Status <> TTaskStatus.Running then Exit;
    if IsComplete then Exit;

    {$IFDEF MSWINDOWS} if TESTStoppable then OutputDebugString('WAIT'); {$ENDIF}
    //?CheckSynchronize; // do we need it?
    try
      Result := Wait(Timeout);
    except
    end;
    //?CheckSynchronize; // do we need it?
  finally
    {$IFDEF MSWINDOWS} if TESTStoppable then OutputDebugString('DONE'); {$ENDIF}
  end;
end;

//function TTaskStoppable.Queue(const AThread: TThread; AMethod: TThreadMethod): Boolean;
//begin
//  Result := CheckStopped;
//  if not Result then TThread.Queue(AThread, AMethod);
//end;
//------------------------------------------------------------------------------

{ TMainFrm }

procedure TMainFrm.FormCreate(Sender: TObject);
begin
  TabControl.TabPosition := TTabPosition.None;
  TabControl.ActiveTab := IntroTabItem;
  PageAddressFrm.WebAddressEdit.Text := 'http://www.google.com';
  PageSourceFrm.ProgressPause(IsDownloading);

  if TESTAuto then PageAddressFrmDownloadButtonClick(nil);
end;

procedure TMainFrm.FormDestroy(Sender: TObject);
begin
  DownloadStop := nil;
  DownloadTask := nil;
end;

procedure TMainFrm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if Assigned(DownloadStop) and not DownloadStop.StopAndWait(Trunc(TimeoutConnect * 1.1)) then // 1.1: just in case
    Action := TCloseAction.caNone;
end;

procedure TMainFrm.FormActivate(Sender: TObject);
begin
  PageSourceFrm.ProgressContinue(IsDownloading);
end;

procedure TMainFrm.FormDeactivate(Sender: TObject);
begin
  PageSourceFrm.ProgressPause(IsDownloading);
end;

procedure TMainFrm.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
begin
  {$IFDEF MSWINDOWS} if (Key = vkBack) and (ActiveControl = PageAddressFrm.WebAddressEdit) then Exit; {$ENDIF}
  if Key in [vkHardwareBack {$IFDEF MSWINDOWS} , vkBack {$ENDIF} ] then
    if TabControl.ActiveTab = PageAddressTabItem then begin
      if ActiveControl = PageAddressFrm.WebAddressEdit then
        // default
      else if BackPressed then
        // default (Close)
      else begin
        Key := 0;
        ShowToast('Press "Back" again to Close...');
        BackPressed := TRUE;
        Exit; // BackPressed
      end;
    end else if TabControl.ActiveTab <> PageSourceTabItem then
      // default (Close)
    else if IsDownloading then begin
      Key := 0;
      if TESTStoppable then
        PageAddressFrmDownloadButtonClick(nil)
      else if BackPressed then begin
        DownloadStop.StopAndWait;
        TabControl.SetActiveTabWithTransition(PageAddressTabItem, TTabTransition.Slide);
        BackPressed := TRUE;
        Exit; // BackPressed
      end else begin
        ShowToast('Press "Back" again to Stop...');
        BackPressed := TRUE;
        Exit; // BackPressed
      end;
    end else begin
      Key := 0;
      // or: TabControl.SetActiveTabWithTransition(PageAddressTabItem, TTabTransition.Slide)
      TabControl.ActiveTab := PageAddressTabItem;
    end;
  BackPressed := FALSE;
  {$IFDEF MSWINDOWS} if Key = vkBack then Close; {$ENDIF}
end;

procedure TMainFrm.TabControlChange(Sender: TObject);
begin
  if TabControl.ActiveTab = PageAddressTabItem then ActiveControl := PageAddressFrm.WebAddressEdit
  else if TabControl.ActiveTab = PageSourceTabItem then ActiveControl := PageSourceFrm.ResponseMemo;
  BackPressed := FALSE;
end;

procedure TMainFrm.IntroFrmGetStartedButtonClick(Sender: TObject);
begin
  //todo: Android crash on handled/hidden exception (Android 8) - Delphi, SDK, Android version?
  // https://stackoverflow.com/questions/38243473/exception-handling-broken-in-delphi-xe8-android
  //try
  //  Abort;
  //except
    TabControl.SetActiveTabWithTransition(PageAddressTabItem, TTabTransition.Slide);
  //end;
end;

procedure TMainFrm.PageAddressFrmDownloadButtonClick(Sender: TObject);
begin
  PageSourceFrm.WebAddressLabel.Text := PageAddressFrm.WebAddressEdit.Text;
  TabControl.SetActiveTabWithTransition(PageSourceTabItem, TTabTransition.Slide);
  if Assigned(DownloadStop) then DownloadStop.StopAndWait;
  DownloadURL := PageAddressFrm.WebAddressEdit.Text;

  //DownloadTask := TTask.Create(nil, Download);
  DownloadTask := TTaskStoppable.Create(nil, Download, nil, TThreadPool.Default, nil);
  DownloadStop := DownloadTask as ITaskStoppable;

  DownloadTask.Start;
end;

function TMainFrm.IsDownloading: Boolean;
begin
  //Result := Assigned(DownloadTask) and (DownloadTask.Status = TTaskStatus.Running);
  //Result := Assigned(DownloadTask) and not (DownloadTask.Status in [TTaskStatus.Completed, TTaskStatus.Canceled, TTaskStatus.Exception]);
  Result := Assigned(DownloadStop) and not DownloadStop.IsComplete;
end;

procedure TMainFrm.Download(Sender: TObject);
var Data: String;
begin
  //try
    {$IFDEF MSWINDOWS} if TESTStoppable then OutputDebugString('task'); {$ENDIF}
    Download_Progress;
    try
      Download_Get(Data);
      Download_Show(Data);
    finally
      Download_Done;
      {$IFDEF MSWINDOWS} if TESTStoppable then OutputDebugString('done'); {$ENDIF}
    end;
  //except end; // handle exception: TTaskStatus.Completed vs TTaskStatus.Exception
end;

procedure TMainFrm.Download_Progress;
begin
  TThread.Queue(nil, procedure
    begin
      PageSourceFrm.ProgressContinue(TRUE);
    end);
end;

procedure TMainFrm.Download_Done;
begin
  TThread.Queue(nil, procedure
    begin
      PageSourceFrm.ProgressPause(FALSE);
      BackPressed := FALSE; // double Back
    end);
end;

procedure TMainFrm.Download_Status(ASender: TObject; const AStatus: TIdStatus; const AStatusText: string);

  function Details(const Pref: String; Obj: TObject): String;
  begin
    if Obj = nil then Result := Pref + ': NIL' + sLineBreak
    else Result := Pref + ': ' + Obj.ClassName + sLineBreak;
  end;

var Msg: String;
begin
  if TESTTrace <> '' then begin
    Msg := 'Status: ' + GetEnumName(TypeInfo(TIdStatus), Ord(AStatus)) + ' - ' + AStatusText + sLineBreak;
    Msg := Msg + Details('ASender', ASender);
    if ASender is TidHTTP then Msg := Msg + Details('IOHandler', TidHTTP(ASender).IOHandler);
    Msg := Msg + Details('GStack', GStack);
    TestTRACE := TestTRACE + '---' + sLineBreak + Msg;
  end;

  Msg := '';
  {$IFDEF ANDROID} if TESTTrace = '' then Msg := AStatusText; {$ENDIF}
  if Msg = '' then Exit;

  if DownloadStop.CheckStopped then Exit; // DownloadTask.CheckCanceled;
  TThread.Queue(nil, procedure
    begin
      ShowToast(Msg);
    end);
end;

procedure TMainFrm.Download_Get(var Data: String);
var
  delay, parts: Integer;
  Http: TidHTTP;
  t: TTime;
  Client: TNetHTTPClient;
  Request: TNetHTTPRequest;
  Response: IHTTPResponse;
begin
  delay := 0;

  if DownloadStop.CheckStopped then Exit; // DownloadTask.CheckCanceled;
  if not TESTSimulate then TThread.Queue(nil, procedure
    begin
      if not MODECheckConnected then
        //ShowToast('Before GET')
      else if not TConnectivity.IsConnectedToInternet then begin
        ShowToast('Not Connected');
        Exit;
      end else if not TConnectivity.IsWifiInternetConnection then
        ShowToast('Not Wifi GET')
      else
        ShowToast('Wifi GET');
    end);

  //todo: fix TPlatformConnectivity (DW.Connectivity.Android), JNetwork (Androidapi.JNI.Net), TAndroidHelper
  // or: run second Task - Sleep Timeout, Resolve 'google.com', Connect 1.1.1.1 and Show feedback 'Connection status'
  // Resolve OK - Firewall; Connect OK - ISP/DNS; Both ERR - Not connected

  if TESTSimulate then begin
    Data := '';
    for parts := 1 to TESTFragments do Data := Data + IfThen(Data <> '', sLineBreak) + 'Line ' + IntToStr(parts);
    if TESTFragments > 1 then delay := TimeoutConnect;
  end else if MODENetHTTP then begin
    Client := TNetHTTPClient.Create(nil);
    Request := TNetHTTPRequest.Create(nil);
    try
      Request.Client := Client;
      Request.MethodString := 'GET';
      Request.URL := DownloadURL;
      if DownloadStop.CheckStopped then Exit; // DownloadTask.CheckCanceled;
      // todo: add status
      // {$IFDEF ANDROID} ShowToast('Connecting...'); {$ENDIF}
      // Request.OnReceiveData: {$IFDEF ANDROID} ShowToast('Connected...'); {$ENDIF}
      // Request.OnReceiveData: {$IFDEF ANDROID} ShowToast('Receiving Data...'); {$ENDIF}
      // Request.OnRequestError: {$IFDEF ANDROID} ShowToast('Error!'); {$ENDIF}
      Response := Request.Execute;
      Data := Response.ContentAsString;
      if Data = '' then Data := Format('[%d] %s', [Response.StatusCode, Response.StatusText]);
    finally
      Response := nil;
      Request.Free;
      Client.Free;
    end;
  end else begin
    t := Time;
    Http := TidHTTP.Create;
    try
      Http.ConnectTimeout := TimeoutConnect; // indy calls are blocking/synchronious
      Http.ReadTimeout := TimeoutConnect;
      Http.HTTPOptions := [hoForceEncodeParams, hoKeepOrigProtocol, hoNoProtocolErrorException];
      if DownloadStop.CheckStopped then Exit; // DownloadTask.CheckCanceled;
      Http.OnStatus := Download_Status;
      Data := Http.Get(DownloadURL);
      if Data = '' then Data := Format('[%d] %s', [Http.ResponseCode, Http.ResponseText]);
    finally
      Http.Free;
    end;
    if TESTFragments > 1 then delay := TimeoutConnect - Trunc((Time - t) * 24*60*60*1000);
  end;

  if DownloadStop.CheckStopped then Exit; // DownloadTask.CheckCanceled;
  //if not TESTSimulate then TThread.Queue(nil, procedure
  //  begin
  //    ShowToast('After GET');
  //  end);

  if DownloadStop.CheckStopped then Exit; // DownloadTask.CheckCanceled;
  if delay > 0 then Sleep(delay);
end;

procedure TMainFrm.Download_Show(Data: String);
var parts: Integer;
begin
  if TESTTrace <> '' then Data := TESTTrace;
  if Data = '' then Exit;

  if DownloadStop.CheckStopped then Exit; // DownloadTask.CheckCanceled;
  TThread.Queue(nil, procedure
    begin
      PageSourceFrm.ResponseMemo.Lines.Clear;
      if TESTFragments = 1 then PageSourceFrm.ResponseMemo.Lines.Text := Data;
    end);
  //if DownloadStop.Queue(nil, procedure
  //  begin
  //    PageSourceFrm.ResponseMemo.Lines.Clear;
  //    if TESTFragments = 1 then PageSourceFrm.ResponseMemo.Lines.Text := Data;
  //  end) then Exit;

  if TESTFragments = 1 then Exit;
  for parts := 1 to TESTFragments do begin
    if DownloadStop.CheckStopped then Exit; // DownloadTask.CheckCanceled;
    Sleep(Trunc(TimeoutConnect / TESTFragments));

    if DownloadStop.CheckStopped then Exit; // DownloadTask.CheckCanceled;
    TThread.Queue(nil, procedure
      begin
        PageSourceFrm.ResponseMemo.Lines.Text := Copy(Data, 1, Trunc(Length(Data) * parts / TESTFragments));
        //todo: test ScrollBy with Android
        with PageSourceFrm.ResponseMemo do
          if parts < TESTFragments - 1 then ScrollBy(0, MAXINT) else ScrollBy(0, -MAXINT); // scroll to top for last 2 fragments
      end);
    //if DownloadStop.Queue(nil, procedure
    //  begin
    //    PageSourceFrm.ResponseMemo.Lines.Text := Copy(Data, 1, Trunc(Length(Data) * parts / TESTFragments));
    //    if parts < TESTFragments then with PageSourceFrm.ResponseMemo do ScrollBy(0, ViewportSize.Height);
    //  end) then Exit;
  end;
end;

end.

//todo: CodeSite Logging
//todo: TLayout
//todo: colors, background
//todo: scale and resize progress
//todo: find size and controls
