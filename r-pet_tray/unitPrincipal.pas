unit unitPrincipal;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, Menus, Windows, WinSock, ShellApi;

type

  { TFormPrincipal }

  TFormPrincipal = class(TForm)
    MenuItemSair: TMenuItem;
    Popup: TPopupMenu;
    Timer: TTimer;
    TrayIcon: TTrayIcon;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure MenuItemSairClick(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure EnviarComandos(const Cmd: String);
  end;

  TDwmGetWindowAttribute = function(hwnd: HWND; dwAttribute: DWORD; pvAttribute: Pointer; cbAttribute: DWORD): HRESULT; stdcall;

const
  DWMWA_EXTENDED_FRAME_BOUNDS = 9;

var
  FormPrincipal: TFormPrincipal;
  MonitorPrincipal: TRect;
  DwmGetWindowAttributeFunc: TDwmGetWindowAttribute;

function EnumWindowsProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;

implementation  {$R *.lfm}

//================================================== FORM CREATE =====================================================\\
procedure TFormPrincipal.FormCreate(Sender: TObject);
var
  WSAData: TWSAData;
  User32: HMODULE;
  SetDPIAware: function: BOOL; stdcall;
  PetWnd: HWND;
  ExStyle: LONG;
  ExePath: String;
begin
  //Comandos para Mandar posição das janelas via UDP na porta 4242
  User32 := LoadLibrary('user32.dll');

  if User32 <> 0 then
  begin
    Pointer(SetDPIAware) := GetProcAddress(User32, 'SetProcessDPIAware');
    if Assigned(SetDPIAware) then
      SetDPIAware();
    FreeLibrary(User32);
  end;

  MonitorPrincipal := Screen.PrimaryMonitor.WorkareaRect;
  WSAStartup(MAKEWORD(2, 2), WSAData{%H-});

  //Inicia o Pet
  ExePath := ExtractFilePath(Application.ExeName) + 'RPet.exe';

  if not FileExists(ExePath) then
  begin
    ShowMessage('RPet.exe não encontrado em ' + ExePath);
    Application.Terminate;
    Exit;
  end;

  ShellExecute(0, 'open', PChar(ExePath), nil, PChar(ExtractFilePath(ExePath)), SW_SHOW);

  //Comandos para ocultar o pet da barra de tarefas
  PetWnd := 0;
  repeat
    PetWnd := FindWindow(nil, 'RPet (DEBUG)');
    if PetWnd = 0 then Sleep(200);
  until PetWnd <> 0;

  ExStyle := GetWindowLong(PetWnd, GWL_EXSTYLE);
  ExStyle := (ExStyle or WS_EX_TOOLWINDOW) and not WS_EX_APPWINDOW;
  SetWindowLong(PetWnd, GWL_EXSTYLE, ExStyle);
  ShowWindow(PetWnd, SW_HIDE);
  ShowWindow(PetWnd, SW_SHOW);

  Timer.Enabled := True;
end;

//=================================================== FORM DESTROY ===================================================\\
procedure TFormPrincipal.FormDestroy(Sender: TObject);
begin
  WSACleanup;
end;

//===================================================== TIMER ========================================================\\
procedure TFormPrincipal.TimerTimer(Sender: TObject);
var
  Payload: string;
  Sock: TSocket;
  Addr: TSockAddrIn;
begin
  Payload := EmptyStr;
  // Dispara a leitura do Windows, passando o endereço de memória da string Payload
  EnumWindows(@EnumWindowsProc, {%H-}LPARAM(@Payload));

  if Payload <> '' then
  begin
    // Remove o último separador "|" para facilitar o split na Godot
    SetLength(Payload, Length(Payload) - 1);

    Sock := socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if Sock <> INVALID_SOCKET then
    begin
      Addr.sin_family := AF_INET;
      Addr.sin_port := htons(4242);
      Addr.sin_addr.S_addr := inet_addr('127.0.0.1');

      // Envia a string como um array de caracteres
      sendto(Sock, Payload[1], Length(Payload), 0, Addr, SizeOf(Addr));

      // Fecha o socket
      closesocket(Sock);
    end;
  end;
end;

//================================================ ENUM WINDOWS PROC =================================================\\
function EnumWindowsProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  R: TRect;
  RClamp: TRect;
  WindowData: PString;
  WinStyle: longint;
  Owner: HWND;
begin
  Result := True;

  //Deve estar visível e não minimizado
  if not IsWindowVisible(Wnd) then Exit;
  if IsIconic(Wnd) then Exit;

  WinStyle := GetWindowLong(Wnd, GWL_EXSTYLE);
  Owner := GetWindow(Wnd, GW_OWNER);

  //WS_EX_APPWINDOW força a janela a aparecer na barra de tarefas mesmo que tenha owner
  if (WinStyle and WS_EX_APPWINDOW) = 0 then
  begin
    //ToolWindow sem APPWINDOW
    if (WinStyle and WS_EX_TOOLWINDOW) <> 0 then Exit;

    //Tem owner
    if Owner <> 0 then Exit;
  end;

  //Deve ter título
  if GetWindowTextLength(Wnd) = 0 then Exit;

  // GetWindowRect direto — sem DWM, sem offset de monitor
  if not GetWindowRect(Wnd, R{%H-}) then Exit;

  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then Exit;

  // Filtra somente o monitor principal
  if not IntersectRect(RClamp{%H-}, R, MonitorPrincipal) then Exit;
  R := RClamp;

  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then Exit;

  // Adiciona à payload
  WindowData  := {%H-}PString(LParam);
  WindowData^ := WindowData^ + Format('%d,%d,%d,%d|', [R.Left, R.Top, R.Right, R.Bottom]);
end;

//================================================= ENVIAR COMANDOS ==================================================\\
procedure TFormPrincipal.EnviarComandos(const Cmd: String);
var
  Sock: TSocket;
  Addr: TSockAddrIn;
begin
  Sock := socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if Sock = INVALID_SOCKET then Exit;

  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(4243);
  Addr.sin_addr.S_addr := inet_addr('127.0.0.1');

  sendto(Sock, Cmd[1], Length(Cmd), 0, Addr, SizeOf(Addr));
  closesocket(Sock);
end;

//=================================================== MENU CLICK =====================================================\\
procedure TFormPrincipal.MenuItemSairClick(Sender: TObject);
begin
  EnviarComandos('CMD:fechar');
  Application.Terminate;
end;

//====================================================================================================================\\
end.
