unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.ImgList,
  Winapi.ShellAPI, TlHelp32, PsAPI, ShlObj, System.ImageList, Vcl.StdCtrls, System.Generics.Collections,
  Vcl.ExtCtrls;

type
  TIsHungAppWindow = function(hWnd: HWND): BOOL; stdcall;
  TForm1 = class(TForm)
    ListView1: TListView;
    ImageList1: TImageList;
    Timer1: TTimer;
    RadioGroup1: TRadioGroup;
    ButtonSetHotkey: TButton;
    Button2: TButton;
    CheckBox1: TCheckBox;
    EditHotkey: TEdit;
    ResetKey: TButton;
    Button1: TButton;
    Label1: TLabel;
    Label2: TLabel;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ListView1SelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure Timer1Timer(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure ListView1CustomDrawItem(Sender: TCustomListView; Item: TListItem;
      State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure EditHotkeyKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure ButtonSetHotkeyClick(Sender: TObject);
    procedure ResetKeyClick(Sender: TObject);
    procedure Label2MouseEnter(Sender: TObject);
    procedure Label2MouseLeave(Sender: TObject);
    procedure Label2Click(Sender: TObject);
    procedure Button1MouseEnter(Sender: TObject);
    procedure Button1MouseLeave(Sender: TObject);
    procedure CheckBox1MouseEnter(Sender: TObject);
    procedure CheckBox1MouseLeave(Sender: TObject);
    procedure Button1Enter(Sender: TObject);
    procedure Button1Exit(Sender: TObject);
    procedure CheckBox1Enter(Sender: TObject);
    procedure CheckBox1Exit(Sender: TObject);
    procedure Button2Enter(Sender: TObject);
    procedure Button2Exit(Sender: TObject);
    procedure Button2MouseEnter(Sender: TObject);
    procedure Button2MouseLeave(Sender: TObject);
    procedure ResetKeyMouseEnter(Sender: TObject);
    procedure ResetKeyMouseLeave(Sender: TObject);
    procedure ResetKeyEnter(Sender: TObject);
    procedure ResetKeyExit(Sender: TObject);
    procedure EditHotkeyEnter(Sender: TObject);
    procedure EditHotkeyExit(Sender: TObject);
    procedure EditHotkeyMouseEnter(Sender: TObject);
    procedure EditHotkeyMouseLeave(Sender: TObject);
    procedure ButtonSetHotkeyMouseEnter(Sender: TObject);
    procedure ButtonSetHotkeyMouseLeave(Sender: TObject);
    procedure ButtonSetHotkeyEnter(Sender: TObject);
    procedure ButtonSetHotkeyExit(Sender: TObject);
  private
    { Private declarations }
    HotkeyModifier: UINT;
    HotkeyKey: UINT;
    LastWindowCount: Integer; // ������ ���������� ���� � ������� ���
    procedure WMHotKey(var Msg: TWMHotKey); message WM_HOTKEY;
    procedure UpdateListViewColors;
    procedure GetRunningWindows;
    procedure UpdateFullScreenButton;
    procedure ProcessCommandLineArgs;
    procedure CloseExistingProcess(ProcessID: DWORD);
    function GetProcessPath(ProcessID: DWORD): string;
    function GetAppIcon(const FileName: string): Integer;
    function IsTaskbarWindow(Wnd: HWND): Boolean;
    function GetSelectedWindowHandle: HWND;
    function FindExistingProcessID: DWORD;
  public
    { Public declarations }
    WindowPositions: TDictionary<HWND, TRect>; // ������ ������������ ������� ����
    WindowResizable: TDictionary<HWND, Boolean>; // ������ ����������� ��������� ������� ����
    procedure UpdateHotkeyDisplay;
    procedure SetHotkey(NewModifier: UINT; NewKey: UINT);
  end;

var
  Form1: TForm1;
  IsHungAppWindow: TIsHungAppWindow;

  const
  clFullScreenText = clRed;  // ������� ���� ������ ��� ������������� ����
  clNormalText = clWindowText; // ������� ���� ������
  HOTKEY_FULLSCREEN_ID = 1; // ID ������� �������
  HOTKEY_MODIFIER = MOD_ALT; // ����������� (��������, ALT)
  HOTKEY_KEY = VK_RETURN; // ������� Enter

implementation

{$R *.dfm}

function GetShellWindow: HWND; stdcall; external 'user32.dll';

procedure TForm1.WMHotKey(var Msg: TWMHotKey);
begin
  if Msg.HotKey = HOTKEY_FULLSCREEN_ID then
  begin
    Button2Click(Button2);
  end;
end;

procedure TForm1.SetHotkey(NewModifier: UINT; NewKey: UINT);
begin
  // �������������� ������� ������
  UnregisterHotKey(Handle, 1);

  // ���������� ����� ��������
  HotkeyModifier := NewModifier;
  HotkeyKey := NewKey;

  // ����������� ������ ������
  if not RegisterHotKey(Handle, 1, HotkeyModifier, HotkeyKey) then
    ShowMessage('�� ������� ���������������� ������� �������!');

  // ���������� ����������� ������
  UpdateHotkeyDisplay;
end;

function CountTaskbarWindows: Integer;
var
  Count: Integer;
  function EnumWindowsCallback(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
  begin
    if Form1.IsTaskbarWindow(Wnd) then
      Inc(PInteger(LParam)^);
    Result := True;
  end;
begin
  Count := 0;
  EnumWindows(@EnumWindowsCallback, LPARAM(@Count));
  Result := Count;
end;

function TForm1.FindExistingProcessID: DWORD;
var
  Snapshot: THandle;
  ProcessEntry: TProcessEntry32;
  CurrentProcessID: DWORD;
  CurrentProcessName, FoundProcessName: string;
begin
  Result := 0;
  CurrentProcessID := GetCurrentProcessId;
  CurrentProcessName := ExtractFileName(ParamStr(0)); // ��� �������� ������������ �����

  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snapshot = INVALID_HANDLE_VALUE then
  begin
    CloseHandle(Snapshot);
    Exit;

  end;
  ProcessEntry.dwSize := SizeOf(ProcessEntry);
  if Process32First(Snapshot, ProcessEntry) then
  begin
    repeat
      FoundProcessName := ExtractFileName(ProcessEntry.szExeFile);
      if (SameText(FoundProcessName, CurrentProcessName)) and
         (ProcessEntry.th32ProcessID <> CurrentProcessID) then
      begin
        Result := ProcessEntry.th32ProcessID;
        Break;
      end;
    until not Process32Next(Snapshot, ProcessEntry);
  end;
  CloseHandle(Snapshot);
end;

procedure TForm1.CloseExistingProcess(ProcessID: DWORD);
var
  ProcessHandle: THandle;
begin
  if ProcessID = 0 then Exit;

  ProcessHandle := OpenProcess(PROCESS_TERMINATE, False, ProcessID);
  if ProcessHandle <> 0 then
  begin
    TerminateProcess(ProcessHandle, 0);
    CloseHandle(ProcessHandle);
  end;
end;

procedure TForm1.ProcessCommandLineArgs;
var
  I, Attempts: Integer;
  Param, TargetProgram, ProgramName: string;
  AutoStart: Boolean;
  ProcessHandle: THandle;
begin
  TargetProgram := '';
  AutoStart := False;

  // ���������� ��������� ��������� ������
  for I := 1 to ParamCount do
  begin
    Param := ParamStr(I);

    if SameText(Param, '-program') and (I < ParamCount) then
      TargetProgram := ParamStr(I + 1)
    else if SameText(Param, '-autostart') then
      AutoStart := True;
  end;

  if TargetProgram <> '' then
  begin
    // ������� ����, �������� ������ ��� �����
    ProgramName := ExtractFileName(TargetProgram);

    // ���� ��������� � ������ � ������������� �
    for I := 0 to ListView1.Items.Count - 1 do
    begin
      if SameText(ListView1.Items[I].SubItems[0], ProgramName) or
         SameText(ListView1.Items[I].Caption, ProgramName) then
      begin
        ListView1.ItemIndex := I;
        Button2Click(Button2);
        Exit;
      end;
    end;

    // ���� ��������� �� �������, ��������� AutoStart
    if AutoStart then
    begin
      if FileExists(TargetProgram) then
      begin
        ProcessHandle := ShellExecute(0, 'open', PChar(TargetProgram), nil, nil, SW_SHOWNORMAL);

        if ProcessHandle <= 32 then
        begin
          ShowMessage('������ ������� ���������: ' + TargetProgram);
          Exit;
        end;

        // ���� ��������� ����� ����������� (��������� 10 ��� � �������)
        Attempts := 0;
        while Attempts < 10 do
        begin
          Sleep(500); // ��� 0.5 �������
          GetRunningWindows;

          for I := 0 to ListView1.Items.Count - 1 do
          begin
            if SameText(ListView1.Items[I].SubItems[0], ProgramName) or
               SameText(ListView1.Items[I].Caption, ProgramName) then
            begin
              ListView1.ItemIndex := I;
              Button2Click(Button2);
              Exit;
            end;
          end;

          Inc(Attempts);
        end;

        ShowMessage('��������� ��������, �� � ���� �� �������.');
      end
      else
        ShowMessage('���� ��������� �� ������: ' + TargetProgram);
    end;
  end;
end;

procedure TForm1.UpdateListViewColors;
var
  I: Integer;
  Wnd: HWND;
  Style: LongInt;
  WindowPlacement: TWindowPlacement;
begin
  for I := 0 to ListView1.Items.Count - 1 do
  begin
    Wnd := HWND(ListView1.Items[I].Data);

    if not IsWindow(Wnd) then
      Continue;

    // ��������� ������� ��������� ����
    WindowPlacement.length := SizeOf(WindowPlacement);
    GetWindowPlacement(Wnd, @WindowPlacement);

    Style := GetWindowLong(Wnd, GWL_STYLE);

  end;
end;

procedure TForm1.Label2Click(Sender: TObject);
const
  URL = 'https://github.com/Heavenanvil/WinOverSizer';  // ������� ����� ���� ������
begin
  Label2.Font.Color := clRed;  // ������ ���� ������ �� �������
  ShellExecute(0, 'open', PChar(URL), nil, nil, SW_SHOWNORMAL); // ��������� ������ � ��������
  Sleep(100);
  Label2.Font.Color := clBlue;  // ������ ���� ������ �� �����
end;

procedure TForm1.Label2MouseEnter(Sender: TObject);
begin
Label2.Font.Style := [fsUnderline];
Label2.Cursor := crHandPoint;
Label1.Caption := '��������� ������������ ������ � ����������� "-program" � "-autostart", ��������: -program "fullpath/app.exe" -autostart'+sLineBreak+'����� �������� ������� ���� �� ������.';
end;

procedure TForm1.Label2MouseLeave(Sender: TObject);
begin

Label2.Font.Style := [];
 Label2.Cursor := crDefault;
 Label1.Caption := '';
end;

procedure TForm1.ListView1CustomDrawItem(Sender: TCustomListView; Item: TListItem;
  State: TCustomDrawState; var DefaultDraw: Boolean);
var
  WindowPlacement: TWindowPlacement;
  TargetWnd: HWND;
begin
  if Item.Data = nil then Exit;

  TargetWnd := HWND(Item.Data);
  if TargetWnd = 0 then Exit;

  // ���������, �������� �� ���� �������������
  WindowPlacement.length := SizeOf(WindowPlacement);
  GetWindowPlacement(TargetWnd, @WindowPlacement);

  if (WindowPlacement.showCmd = SW_MAXIMIZE) and
     ((GetWindowLong(TargetWnd, GWL_STYLE) and WS_CAPTION) = 0) then
  begin
    Sender.Canvas.Font.Color := clRed;  // ������� ����� ��� ������������� ����
  end
  else
  begin
    Sender.Canvas.Font.Color := clWindowText; // ������� �����
  end;
end;

// ������� ��� ��������� ���� � ������������ ����� ��������
function TForm1.GetProcessPath(ProcessID: DWORD): string;
var
  hProcess: THandle;
  FileName: array[0..MAX_PATH] of Char;
begin
  Result := '';
  hProcess := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, ProcessID);
  if hProcess <> 0 then
  begin
    if GetModuleFileNameEx(hProcess, 0, FileName, MAX_PATH) > 0 then
      Result := FileName;
    CloseHandle(hProcess);
  end;
end;

// ������� ��� ��������� hWnd ����������� ��������
function TForm1.GetSelectedWindowHandle: HWND;
var
  SelectedIndex: Integer;
begin
  Result := 0;
  SelectedIndex := ListView1.ItemIndex;
  if SelectedIndex <> -1 then
    Result := HWND(ListView1.Items[SelectedIndex].Data); // Data ������ hWnd
end;

// ������� ��� �������� ������ � ���������� ������������
function TForm1.GetAppIcon(const FileName: string): Integer;
var
  Icon: TIcon;
  SHFileInfo: TSHFileInfo;
begin
  Result := -1;
  if FileExists(FileName) then
  begin
    if SHGetFileInfo(PChar(FileName), 0, SHFileInfo, SizeOf(SHFileInfo),
      SHGFI_ICON or SHGFI_LARGEICON or SHGFI_SHELLICONSIZE) <> 0 then
    begin
      Icon := TIcon.Create;
      try
        Icon.Handle := SHFileInfo.hIcon;
        Result := ImageList1.AddIcon(Icon);
      finally
        Icon.Free;
        DestroyIcon(SHFileInfo.hIcon);
      end;
    end;
  end;
end;

// ������� ��� ��������, ������������ �� ���� �� ������ �����
function TForm1.IsTaskbarWindow(Wnd: HWND): Boolean;
var
  WindowStyle, ExStyle: LONG;
  WindowPlacement: TWindowPlacement;
  Title: array[0..255] of Char;
  ClassName: array[0..255] of Char;
begin
  // **���� ������� ������� � ���������� ��� ��������**
  if CheckBox1.Checked then
    Exit(True);

  // ����������� ��������, ���� ������� ��������

  Result := False;
  if not IsWindow(Wnd) then Exit;
  if Wnd = GetShellWindow then Exit;
  if GetParent(Wnd) <> 0 then Exit;
  if GetWindow(Wnd, GW_OWNER) <> 0 then Exit;

  WindowStyle := GetWindowLong(Wnd, GWL_STYLE);
  ExStyle := GetWindowLong(Wnd, GWL_EXSTYLE);

  if (ExStyle and WS_EX_TOOLWINDOW) <> 0 then Exit;
  if (ExStyle and WS_EX_NOACTIVATE) <> 0 then Exit;

  GetWindowText(Wnd, Title, SizeOf(Title));
  if (Title[0] = #0) and ((ExStyle and WS_EX_APPWINDOW) = 0) then Exit;

  GetClassName(Wnd, ClassName, SizeOf(ClassName));
  if SameText(ClassName, 'ApplicationFrameWindow') then Exit;

  if (GetForegroundWindow <> Wnd) and not IsWindowVisible(Wnd) then Exit;
  if (not IsWindowVisible(Wnd)) and IsIconic(Wnd) then Exit;

  WindowPlacement.length := SizeOf(WindowPlacement);
  GetWindowPlacement(Wnd, @WindowPlacement);

  if (WindowPlacement.showCmd = SW_MAXIMIZE) or (WindowPlacement.showCmd = SW_SHOWMINIMIZED) then
  begin
    Result := True;
    Exit;
  end;

  if (ExStyle and WS_EX_APPWINDOW) = 0 then
  begin
    if ((WindowStyle and WS_CAPTION) = 0) or ((WindowStyle and WS_SYSMENU) = 0) then Exit;
  end;

  Result := True;
end;

procedure TForm1.UpdateFullScreenButton;
var
  TargetWnd: HWND;
  Style: LongInt;
  WindowPlacement: TWindowPlacement;
begin
  TargetWnd := GetSelectedWindowHandle;
  if TargetWnd = 0 then
  begin
    Button2.Caption := 'Set FullScreen';
    Exit;
  end;

  // ���������, ���������� �� ���� (���� ���� ��� ������� � ����)
  if not IsWindow(TargetWnd) then
  begin
    Button2.Caption := 'Set FullScreen';
    Exit;
  end;

  // �������� ������� ����� ����
  Style := GetWindowLong(TargetWnd, GWL_STYLE);

  // �������� ������� ��������� ����
  WindowPlacement.length := SizeOf(WindowPlacement);
  GetWindowPlacement(TargetWnd, @WindowPlacement);

  // ���� ���� ��������� � �� ����� ������ � ��� FullScreen
  if (WindowPlacement.showCmd = SW_MAXIMIZE) and ((Style and WS_CAPTION) = 0) then
    Button2.Caption := 'Unset FullScreen'
  else
    Button2.Caption := 'Set FullScreen';
end;

procedure TForm1.ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if Selected then
    UpdateFullScreenButton; // �������� ���������� ������
end;

procedure TForm1.ResetKeyClick(Sender: TObject);
begin
    SetHotkey(MOD_ALT, VK_RETURN); // ����� �� ALT + Enter
end;

procedure TForm1.ResetKeyEnter(Sender: TObject);
begin
Label1.Caption := '�������� ��������������� ��������� ������ �� ALT+Enter';
end;

procedure TForm1.ResetKeyExit(Sender: TObject);
begin
Label1.Caption := '';
end;

procedure TForm1.ResetKeyMouseEnter(Sender: TObject);
begin
Label1.Caption := '�������� ��������������� ��������� ������ �� ALT+Enter';
end;

procedure TForm1.ResetKeyMouseLeave(Sender: TObject);
begin
Label1.Caption := '';
end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
  ForegroundWnd: HWND;
  I, CurrentWindowCount: Integer;
begin
  UpdateFullScreenButton;

  // **���������� �������� ���� � �������� ��� � ������**
  ForegroundWnd := GetForegroundWindow;
  if (ForegroundWnd <> 0) and (ForegroundWnd <> Self.Handle) then
  begin
    for I := 0 to ListView1.Items.Count - 1 do
    begin
      if HWND(ListView1.Items[I].Data) = ForegroundWnd then
      begin
        ListView1.ItemIndex := I;
        ListView1.Selected := ListView1.Items[I];
        ListView1.Selected.Focused := True;
        Break;
      end;
    end;
  end;

  // **��������� ��������� ���������� ����**
  CurrentWindowCount := CountTaskbarWindows;
  if CurrentWindowCount <> LastWindowCount then
  begin
    GetRunningWindows; // ��������� ������
    LastWindowCount := CurrentWindowCount; // ��������� ����� ����������
  end;
end;

// ������� ��������� ����
function EnumWindowsProc(Wnd: HWND; lParam: LPARAM): BOOL; stdcall;
var
  Title: array[0..255] of Char;
  ProcessID: DWORD;
  ListView: TListView;
  ListItem: TListItem;
  ProcessPath, ProcessName: string;
  IconIndex: Integer;
begin
  ListView := TListView(lParam);

  GetWindowText(Wnd, Title, SizeOf(Title));
  GetWindowThreadProcessId(Wnd, @ProcessID);

  if Form1.IsTaskbarWindow(Wnd) and (Title[0] <> #0) then
  begin
    ProcessPath := Form1.GetProcessPath(ProcessID);
    ProcessName := ExtractFileName(ProcessPath);

    IconIndex := -1;
    if ProcessPath <> '' then
      IconIndex := Form1.GetAppIcon(ProcessPath);

    ListItem := ListView.Items.Add;
    ListItem.Caption := Title;
    ListItem.SubItems.Add(ProcessName);
    ListItem.Data := Pointer(Wnd); // ��������� hWnd � Data

    if IconIndex <> -1 then
      ListItem.ImageIndex := IconIndex
    else
      ListItem.ImageIndex := -1;
  end;

  Result := True;
end;

// ����� ��������� ������ ����
procedure TForm1.GetRunningWindows;
var
  SelectedWnd: HWND;
  I: Integer;
begin
  // ���������� hWnd ����������� ��������, ���� �� ����
  SelectedWnd := GetSelectedWindowHandle;

  // ������� ������ ����� �����������
  ListView1.Items.BeginUpdate;
  try
    ListView1.Clear;
    ImageList1.Clear;
    ImageList1.BkColor := clNone;
    ImageList1.ColorDepth := cd32Bit;
    EnumWindows(@EnumWindowsProc, LPARAM(ListView1));
  finally
    ListView1.Items.EndUpdate;
  end;

  // **��������������� ���������, ���� ���� �� ��� � ������**
  if SelectedWnd <> 0 then
  begin
    for I := 0 to ListView1.Items.Count - 1 do
    begin
      if HWND(ListView1.Items[I].Data) = SelectedWnd then
      begin
        ListView1.ItemIndex := I;
        Break;
      end;
    end;
  end;
  UpdateListViewColors;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  GetRunningWindows;
  UpdateListViewColors;
end;

// ���������� ������ "FullScreen" / "Unset FullScreen" (Button2)
procedure TForm1.Button1Enter(Sender: TObject);
begin
  Label1.Caption := '�������� ������ ���������� ��������';
end;

procedure TForm1.Button1Exit(Sender: TObject);
begin
Label1.Caption := '';
end;

procedure TForm1.Button1MouseEnter(Sender: TObject);
begin
Label1.Caption := '�������� ������ ���������� ��������';
end;

procedure TForm1.Button1MouseLeave(Sender: TObject);
begin
  Label1.Caption := '';
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  TargetWnd: HWND;
  Style: LongInt;
  MonitorRect, WindowRect: TRect;
  PID: DWORD;
  ProcessHandle: THandle;
  WindowPlacement: TWindowPlacement;
begin
  TargetWnd := GetSelectedWindowHandle;
  if TargetWnd = 0 then Exit;

  // **���������, ���������� �� ����**
  GetWindowThreadProcessId(TargetWnd, @PID);
  ProcessHandle := OpenProcess(PROCESS_QUERY_INFORMATION, False, PID);

  if (ProcessHandle = 0) or (not IsWindow(TargetWnd)) then
  begin
    ShowMessage('���������� ������ �� �������� ��� �� ����� ��������� ����.');
    GetRunningWindows;
    Exit;
  end
  else
    CloseHandle(ProcessHandle);

  WindowPlacement.length := SizeOf(WindowPlacement);
  GetWindowPlacement(TargetWnd, @WindowPlacement);

  if Button2.Caption = 'Set FullScreen' then
  begin
    // **��������� ������� ��������� � ������ ����**
    GetWindowRect(TargetWnd, WindowRect);
    WindowPositions.AddOrSetValue(TargetWnd, WindowRect);

    // **��������� ����������� ��������� �������**
    WindowResizable.AddOrSetValue(TargetWnd, (GetWindowLong(TargetWnd, GWL_STYLE) and WS_SIZEBOX) <> 0);

    // ������� ��������� � �����
    Style := GetWindowLong(TargetWnd, GWL_STYLE);
    Style := Style and not (WS_CAPTION or WS_THICKFRAME);
    SetWindowLong(TargetWnd, GWL_STYLE, Style);

    // ������������� ���� �� ���� �����
    SystemParametersInfo(SPI_GETWORKAREA, 0, @MonitorRect, 0);
    SetWindowPos(TargetWnd, HWND_TOP, MonitorRect.Left, MonitorRect.Top,
                 MonitorRect.Right - MonitorRect.Left,
                 MonitorRect.Bottom - MonitorRect.Top,
                 SWP_NOZORDER or SWP_FRAMECHANGED);

    if WindowPlacement.showCmd <> SW_MAXIMIZE then
      ShowWindow(TargetWnd, SW_MAXIMIZE);

     AttachThreadInput(GetCurrentThreadId, GetWindowThreadProcessId(TargetWnd, nil), TRUE);
     SetForegroundWindow(TargetWnd);
     BringWindowToTop(TargetWnd);
     SetActiveWindow(TargetWnd);
     AttachThreadInput(GetCurrentThreadId, GetWindowThreadProcessId(TargetWnd, nil), FALSE);
  end
  else
  begin
    // **��������������� ������� ����, ���� ��� ���� ���������**
    if WindowPositions.TryGetValue(TargetWnd, WindowRect) then
	begin
	  // ��������������� ���������� ��������� ����
	  WindowPlacement.length := SizeOf(WindowPlacement);
	  GetWindowPlacement(TargetWnd, @WindowPlacement);
	  WindowPlacement.showCmd := SW_RESTORE;
	  SetWindowPlacement(TargetWnd, @WindowPlacement);
	  Sleep(50);

	  // ��������������� ����� ����
	  Style := GetWindowLong(TargetWnd, GWL_STYLE);
	  Style := Style or WS_CAPTION or WS_THICKFRAME;

	  // ���� ���� ���������� �� ����� �������� ������ � ������� WS_THICKFRAME
	  if WindowResizable.ContainsKey(TargetWnd) and (not WindowResizable[TargetWnd]) then
		Style := Style and not WS_THICKFRAME;

	  SetWindowLong(TargetWnd, GWL_STYLE, Style);

	  // ��������� ���������
	  SetWindowPos(TargetWnd, HWND_TOP,
				   WindowRect.Left, WindowRect.Top,
				   WindowRect.Right - WindowRect.Left,
				   WindowRect.Bottom - WindowRect.Top,
				   SWP_NOZORDER or SWP_FRAMECHANGED or SWP_NOSENDCHANGING);

	  // �������������� ���������� ��������� � �����
	  RedrawWindow(TargetWnd, nil, 0, RDW_INVALIDATE or RDW_FRAME or RDW_UPDATENOW or RDW_ALLCHILDREN);

	  // ������� ���������� ���������
	  WindowPositions.Remove(TargetWnd);
	  WindowResizable.Remove(TargetWnd);
	end;

  end;

  // **��������� ������ ����� ��������� ��������� ����**
  UpdateFullScreenButton;
  GetRunningWindows;
  UpdateListViewColors;
end;

procedure TForm1.Button2Enter(Sender: TObject);
begin
Label1.Caption := '���������� �� ���� ����� ���������� � ������ ���������';
end;

procedure TForm1.Button2Exit(Sender: TObject);
begin
Label1.Caption := '';
end;

procedure TForm1.Button2MouseEnter(Sender: TObject);
begin
Label1.Caption := '���������� �� ���� ����� ���������� � ������ ���������';
end;

procedure TForm1.Button2MouseLeave(Sender: TObject);
begin
Label1.Caption := '';
end;

procedure TForm1.ButtonSetHotkeyClick(Sender: TObject);
begin
    // �������� ������ ������� �������
  UnregisterHotKey(Handle, HOTKEY_FULLSCREEN_ID);

  // ������������ ����� ������� �������
  if not RegisterHotKey(Handle, HOTKEY_FULLSCREEN_ID, HotkeyModifier, HotkeyKey) then
    ShowMessage('�� ������� ���������������� ��������� ������!');

  UpdateHotkeyDisplay;
end;

procedure TForm1.ButtonSetHotkeyEnter(Sender: TObject);
begin
Label1.Caption := '��������� ��������� ��������� ������';
end;

procedure TForm1.ButtonSetHotkeyExit(Sender: TObject);
begin
Label1.Caption := '';
end;

procedure TForm1.ButtonSetHotkeyMouseEnter(Sender: TObject);
begin
Label1.Caption := '��������� ��������� ��������� ������';
end;

procedure TForm1.ButtonSetHotkeyMouseLeave(Sender: TObject);
begin
Label1.Caption := '';
end;

// ���������� �������� �����
procedure TForm1.CheckBox1Click(Sender: TObject);
begin
 GetRunningWindows;
end;

procedure TForm1.CheckBox1Enter(Sender: TObject);
begin
 Label1.Caption := '�������� ��� ������� ��������';
end;

procedure TForm1.CheckBox1Exit(Sender: TObject);
begin
Label1.Caption := '�������� ��� ������� ��������';
end;

procedure TForm1.CheckBox1MouseEnter(Sender: TObject);
begin
Label1.Caption := '�������� ��� ������� ��������';
end;

procedure TForm1.CheckBox1MouseLeave(Sender: TObject);
begin
Label1.Caption := '';
end;

procedure TForm1.EditHotkeyEnter(Sender: TObject);
begin
Label1.Caption := '��������� ��������� ������ ��� "������������" �� ���� �����';
end;

procedure TForm1.EditHotkeyExit(Sender: TObject);
begin
Label1.Caption := '';
end;

procedure TForm1.EditHotkeyKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Modifier: UINT;
begin
  Modifier := 0;

  // ���������� ������� ������������
  if ssShift in Shift then
    Modifier := Modifier or MOD_SHIFT;
  if ssCtrl in Shift then
    Modifier := Modifier or MOD_CONTROL;
  if ssAlt in Shift then
    Modifier := Modifier or MOD_ALT;

  // ���� ������ ������ ���� ��������������� ������� - �� ��������� ������ ������
  if (Modifier <> 0) and (Key in [VK_SHIFT, VK_CONTROL, VK_MENU]) then
    Key := 0;

  // ��������� ����������
  HotkeyModifier := Modifier;
  HotkeyKey := Key;

  // ��������� ����
  UpdateHotkeyDisplay;
end;

procedure TForm1.EditHotkeyMouseEnter(Sender: TObject);
begin
Label1.Caption := '��������� ��������� ������ ��� "������������" �� ���� �����';
end;

procedure TForm1.EditHotkeyMouseLeave(Sender: TObject);
begin
Label1.Caption := '';
end;

procedure TForm1.UpdateHotkeyDisplay;
var
  HotkeyText: string;
begin
  HotkeyText := '';

  // ����������, ���� �� ������������
  if (HotkeyModifier and MOD_CONTROL) <> 0 then
    HotkeyText := 'Ctrl';
  if (HotkeyModifier and MOD_SHIFT) <> 0 then
  begin
    if HotkeyText <> '' then
      HotkeyText := HotkeyText + ' + ';
    HotkeyText := HotkeyText + 'Shift';
  end;
  if (HotkeyModifier and MOD_ALT) <> 0 then
  begin
    if HotkeyText <> '' then
      HotkeyText := HotkeyText + ' + ';
    HotkeyText := HotkeyText + 'Alt';
  end;

  // ���� ������ ������ ������������ � �� ��������� ������ `+`
  if (HotkeyKey = 0) or (HotkeyKey in [VK_SHIFT, VK_CONTROL, VK_MENU]) then
  begin
    EditHotkey.Text := HotkeyText;
    Exit;
  end;

  // ���� ���� ������������, ��������� `+` ����� �������� ��������
  if HotkeyText <> '' then
    HotkeyText := HotkeyText + ' + ';

  // ����������� ����������� �������� �������
  case HotkeyKey of
    VK_F1..VK_F12: HotkeyText := HotkeyText + 'F' + IntToStr(HotkeyKey - VK_F1 + 1);
    VK_LEFT: HotkeyText := HotkeyText + 'Left';
    VK_RIGHT: HotkeyText := HotkeyText + 'Right';
    VK_UP: HotkeyText := HotkeyText + 'Up';
    VK_DOWN: HotkeyText := HotkeyText + 'Down';
    VK_RETURN: HotkeyText := HotkeyText + 'Enter';
    VK_ESCAPE: HotkeyText := HotkeyText + 'Escape';
    VK_SPACE: HotkeyText := HotkeyText + 'Space';
    VK_TAB: HotkeyText := HotkeyText + 'Tab';
    VK_BACK: HotkeyText := HotkeyText + 'Backspace';
    VK_DELETE: HotkeyText := HotkeyText + 'Delete';
    VK_INSERT: HotkeyText := HotkeyText + 'Insert';
    VK_HOME: HotkeyText := HotkeyText + 'Home';
    VK_END: HotkeyText := HotkeyText + 'End';
    VK_PRIOR: HotkeyText := HotkeyText + 'Page Up';
    VK_NEXT: HotkeyText := HotkeyText + 'Page Down';
    VK_NUMPAD0..VK_NUMPAD9: HotkeyText := HotkeyText + 'Num ' + IntToStr(HotkeyKey - VK_NUMPAD0);
    VK_MULTIPLY: HotkeyText := HotkeyText + 'Num *';
    VK_ADD: HotkeyText := HotkeyText + 'Num +';
    VK_SUBTRACT: HotkeyText := HotkeyText + 'Num -';
    VK_DIVIDE: HotkeyText := HotkeyText + 'Num /';
    VK_DECIMAL: HotkeyText := HotkeyText + 'Num .';
    VK_CAPITAL: HotkeyText := HotkeyText + 'CapsLock';
    VK_NUMLOCK: HotkeyText := HotkeyText + 'NumLock';
    VK_PAUSE: HotkeyText := HotkeyText + 'Pause';
    VK_SCROLL: HotkeyText := HotkeyText + 'ScrollLock';
    VK_SNAPSHOT: HotkeyText := HotkeyText + 'PrintScreen';
    else
      // ��� ������� ��������
      if HotkeyKey > 31 then
        HotkeyText := HotkeyText + Chr(HotkeyKey)
      else
        HotkeyText := HotkeyText + '[Unknown Key]';
  end;

  EditHotkey.Text := HotkeyText;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  ExistingProcessID: DWORD;
begin
  ExistingProcessID := FindExistingProcessID;
  if ExistingProcessID <> 0 then
  begin
    CloseExistingProcess(ExistingProcessID);
    Sleep(1000); // ��� ����� �����������
  end;

  // ������ ����������� �������������
  WindowPositions := TDictionary<HWND, TRect>.Create;
  WindowResizable := TDictionary<HWND, Boolean>.Create;

  HotkeyModifier := MOD_ALT;
  HotkeyKey := VK_RETURN;

  RegisterHotKey(Handle, HOTKEY_FULLSCREEN_ID, HotkeyModifier, HotkeyKey);

  UpdateHotkeyDisplay;
  GetRunningWindows;
  ProcessCommandLineArgs;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
// �������� ����������� ������� ������� ����� �������
  UnregisterHotKey(Handle, HOTKEY_FULLSCREEN_ID);

  WindowPositions.Clear;
  WindowResizable.Clear;

  WindowPositions.Free;
  WindowResizable.Free;
end;

initialization
  @IsHungAppWindow := GetProcAddress(GetModuleHandle('user32.dll'), 'IsHungAppWindow');
  if @IsHungAppWindow = nil then
    IsHungAppWindow := nil;
end.
