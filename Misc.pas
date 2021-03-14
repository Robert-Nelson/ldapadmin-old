  {      LDAPAdmin - Misc.pas
  *      Copyright (C) 2003-2016 Tihomir Karlovic
  *
  *      Author: Tihomir Karlovic & Alexander Sokoloff
  *
  *
  * This file is free software; you can redistribute it and/or modify
  * it under the terms of the GNU General Public License as published by
  * the Free Software Foundation; either version 2 of the License, or
  * (at your option) any later version.
  *
  * This file is distributed in the hope that it will be useful,
  * but WITHOUT ANY WARRANTY; without even the implied warranty of
  * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  * GNU General Public License for more details.
  *
  * You should have received a copy of the GNU General Public License
  * along with this program; if not, write to the Free Software
  * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
  }

unit Misc;

interface

uses LdapClasses, Classes, SysUtils, Windows, Forms, Dialogs, Controls,
     ExtCtrls, ComCtrls;

type
  TStreamProcedure = procedure(Stream: TStream) of object;

{ String conversion routines }
function  UTF8ToStringLen(const src: PAnsiChar; const Len: Integer): widestring;
function  StringToUTF8Len(const src: PChar; const Len: Integer): AnsiString;
function  WideStringToUtf8Len(const src: PWideChar; const Len: Integer): AnsiString;
function  StringToWide(const S: AnsiString): WideString;
function  CStrToString(cstr: String): String;
function  GetValueAsText(Value: TLdapAttributeData): string;
{ Time conversion routines }
function  DateTimeToUnixTime(const AValue: TDateTime): Int64;
function  UnixTimeToDateTime(const AValue: Int64): TDateTime;
function  GTZToDateTime(const Value: string): TDateTime;
function  LocalDateTimeToUTC(DateTime: TDateTime): TDateTime;
{ String handling routines }
function  IsNumber(const S: string): Boolean;
procedure Split(Source: string; Result: TStrings; Separator: Char);
function  FormatMemoInput(const Text: string): string;
function  FormatMemoOutput(const Text: string): string;
function  FileReadString(const FileName: TFileName): String;
procedure FileWriteString(const FileName: TFileName; const Value: string);
function  Matches(Wildcard, Text: string; CaseSensitive: boolean = false): Boolean;
{ URL handling routines }
procedure ParseURL(const URL: string; var proto, user, password, host, path: string; var port, version: integer; var auth: TLdapAuthMethod);
{ Some handy dialogs }
function  CheckedMessageDlg(const Msg: string; DlgType: TMsgDlgType; Buttons: TMsgDlgButtons; CbCaption: string; var CbChecked: Boolean): TModalResult;
function  ComboMessageDlg(const Msg: string; const csItems: string; var Text: string): TModalResult;
function  MessageDlgEx(const Msg: string; DlgType: TMsgDlgType; Buttons: TMsgDlgButtons; Captions: array of string; Events: array of TNotifyEvent): TModalResult;
{ Tree sort procedure }
function TreeSortProc(Node1, Node2: TTreeNode; Data: Integer): Integer; stdcall;
{ everything else :-) }
function  HexMem(P: Pointer; Count: Integer; Ellipsis: Boolean): string;
procedure StreamCopy(pf, pt: TStreamProcedure);
procedure LockControl(c: TWinControl; bLock: Boolean);
function  PeekKey: Integer;
procedure RevealWindow(Form: TForm; MoveLeft, MoveTop: Boolean);
function  CreateComponent(const ClassName: string; Owner: TComponent): TComponent;
procedure OnScrollTimer(ScrollTimer: TTimer; TreeView: TTreeView; ScrollAccMargin: Integer);
function LoadBase64(const FileName: string): AnsiString;

const
  mrCustom   = 1000;

implementation

{$I LdapAdmin.inc}

uses StdCtrls, Messages, Constant, Config {$IFDEF VARIANTS} ,variants {$ENDIF},
     Base64;

function TreeSortProc(Node1, Node2: TTreeNode; Data: Integer): Integer; stdcall;
var
  n1, n2: Integer;
begin
  n1 := Node1.ImageIndex;
  n2 := Node2.ImageIndex;
  if ((n1 = bmOu) and (n2 <> bmOu)) then
    Result := -1
  else
  if ((n2 = bmOu) and (n1 <> bmOu))then
    Result := 1
  else
    Result := CompareText(Node1.Text, Node2.Text);
end;

{ String conversion routines }

{ Note: these functions ignore conversion errors }
function StringToWide(const S: AnsiString): WideString;
var
  DestLen: Integer;
begin
  DestLen := MultiByteToWideChar(0, 0, PAnsiChar(S), Length(S), nil, 0);
  SetLength(Result, DestLen);
  MultiByteToWideChar(0, 0, PAnsiChar(S), Length(S), PWideChar(Result), DestLen);
end;

function UTF8ToStringLen(const src: PAnsiChar; const Len: Integer): widestring;
var
  l: Integer;
begin
  SetLength(Result, Len);
  if Len > 0 then
  begin
    l := MultiByteToWideChar( CP_UTF8, 0, src, Len, PWChar(Result), Len*SizeOf(WideChar));
    if l <> Len then
      SetLength(Result, l);
  end;
end;

function StringToUTF8Len(const src: PChar; const Len: Integer): AnsiString;
var
  bsiz: Integer;
  {$IFNDEF UNICODE}
  Temp: string;
  {$ENDIF}
begin
  if Len > 0 then
  begin
    bsiz := Len * 3;
    SetLength(Result, bsiz);
    {$IFNDEF UNICODE}
    SetLength(Temp, bsiz);
    StringToWideChar(src, PWideChar(Temp), bsiz);
    bsiz := WideCharToMultiByte(CP_UTF8, 0, PWideChar(Temp), -1, PAnsiChar(Result), bsiz, nil, nil);
    {$ELSE}
    bsiz := WideCharToMultiByte(CP_UTF8, 0, PChar(src), -1, PAnsiChar(Result), bsiz, nil, nil);
    {$ENDIF}
    if bsiz > 0 then dec(bsiz);
    SetLength(Result, bsiz);
  end
  else
    Result := '';
end;

function WideStringToUtf8Len(const src: PWideChar; const Len: Integer): AnsiString;
var
  bsiz: Integer;
begin
  bsiz := Len * 3;
  SetLength(Result, bsiz);
  bsiz := WideCharToMultiByte(CP_UTF8, 0, src, Len, PAnsiChar(Result), bsiz, nil, nil);
  SetLength(Result, bsiz);
end;

function CStrToString(cstr: String): String;
var  lpesc:      Array [0..2] of Byte;
     cbytes:     Integer;
     cesc:       Integer;
     l:          Integer;
     i:          Integer;
begin

  // Set the length of result, this will keep us from having to append. Result could never be longer than input
  SetLength(result, Length(cstr));

  // Set starting defaults
  cbytes:=0;
  l:=Length(cstr)+1;
  i:=1;

  // Iterate the c style string
  while (i < l) do
  begin
     // Check for escape sequence
     if (cstr[i] = '\') then
     begin
        // Get next byte
        Inc(i);
        if (i = l) then break;
        // Set next write pos
        Inc(cbytes);
        case cstr[i] of
           'a'   :  result[cbytes]:=#7;
           'b'   :  result[cbytes]:=#8;
           'f'   :  result[cbytes]:=#12;
           'n'   :  result[cbytes]:=#10;
           'r'   :  result[cbytes]:=#13;
           't'   :  result[cbytes]:=#9;
           'v'   :  result[cbytes]:=#11;
           '\'   :  result[cbytes]:=#92;
           ''''  :  result[cbytes]:=#39;
           '"'   :  result[cbytes]:=#34;
           '?'   :  result[cbytes]:=#63;
        else
           // Going to be either octal or hex
           cesc:=-1;
           // Loop to get the next 3 bytes
           while (i < l) do
           begin
              Inc(cesc);
              case cstr[i] of
                 '0'..'9' :  lpesc[cesc]:=Ord(cstr[i])-48;
                 'A'..'F' :  lpesc[cesc]:=Ord(cstr[i])-55;
                 'X'      :  lpesc[cesc]:=255;
                 'a'..'f' :  lpesc[cesc]:=Ord(cstr[i])-87;
                 'x'      :  lpesc[cesc]:=255;
              else
                 break;
              end;
              if (cesc = 2) then break;
              Inc(i);
           end;
           // Make sure we got 3 bytes
           if (cesc < 2) then
           begin
              // Raise an error if you wish
              Dec(cbytes);
              break;
           end;
           // Check for hex or octal
           if (lpesc[0] = 255) then
              result[cbytes]:=Chr(lpesc[1] * 16 + lpesc[2])
           else
              result[cbytes]:=Chr(lpesc[0] * 64 + lpesc[1] * 8 + lpesc[2]);
        end;
        // Increment the next byte from the input
        Inc(i);
     end
     else
     begin
        // Increment the write buffer pos
        Inc(cbytes);
        result[cbytes]:=cstr[i];
        Inc(i);
     end;
  end;

  // Set the final length on the result
  SetLength(result, cbytes);

end;

function GetValueAsText(Value: TLdapAttributeData): string;
begin
  if Value.DataType = dtText then
    Result := Value.AsString
  else
    Result := Base64Encode(Pointer(Value.Data)^, Value.DataSize)
end;

{ Time conversion routines }

function DateTimeToUnixTime(const AValue: TDateTime): Int64;
begin
  Result := Round((AValue - 25569.0) * 86400)
end;

function UnixTimeToDateTime(const AValue: Int64): TDateTime;
begin
  Result := AValue / 86400 + 25569.0;
end;

function GTZToDateTime(const Value: string): TDateTime;
var
  AValue: string;
begin
  if (Length(Value) < 15) or (Uppercase(Value[Length(Value)]) <> 'Z') then
        raise EConvertError.Create(stInvalidTimeFmt);
  AValue := Copy(Value, 1, 14); // not interested in ms
  Insert(':', AValue, 13);
  Insert(':', AValue, 11);
  Insert(' ', AValue, 9);
  Insert('-', AValue, 7);
  Insert('-', AValue, 5);
  Result := VarToDateTime(AValue);
end;

function LocalDateTimeToUTC(DateTime: TDateTime): TDateTime;
var
  tzi: TTimeZoneInformation;
  err: DWORD;
  Bias: Integer;
begin
  fillchar(tzi, 0, SizeOf(tzi));
  err := GetTimeZoneInformation(tzi);
  if (err = TIME_ZONE_ID_UNKNOWN) or (err = TIME_ZONE_ID_INVALID) then
    //raise Exception.Create(stInvalidTimeZone);
    Result := DateTime
  else begin
    Bias := tzi.Bias;
    if err = TIME_ZONE_ID_DAYLIGHT then
      inc(Bias, tzi.DayLightBias);
    Result := DateTime + Bias * 60 / 86400;
  end;
end;

{ URL handling routines }

procedure ParseLAURL(const URL: string; var proto, user, password, host, path: string; var port: integer);
var
  n1, n2: integer;
  AUrl: string;
begin
  //URL format <proto>://<user>:<password>@<host>:<port>/<path>
  AUrl:=Url;
  n1:=pos('://',AURL);
  if n1>0 then begin
    proto:=copy(AURL,1,n1-1);
    Delete(AURL,1,n1+2);
  end;

  n1:=pos('@',AURL);
  if n1>0 then begin
    n2:=pos(':',copy(AURL,1,n1-1));
    if n2>0 then begin
      user:=copy(AURL,1,n2-1);
      password:=copy(AURL,n2+1,n1-n2-1);
    end
    else user:=copy(AURL,1,n1-1);
    Delete(AURL,1,n1);
  end;

  n1:=pos('/',AURL);
  if n1=0 then n1:=length(AURL)+1;
  n2:=pos(':',copy(AURL,1,n1-1));
  if n2>0 then begin
    host:=copy(AURL,1,n2-1);
    port:=StrToIntDef(copy(AURL,n2+1,n1-n2-1),-1);
  end
  else begin
    host:=copy(AURL,1,n1-1);
    if (proto='ldaps') or (proto='ldapsg') then
      port := 636;
  end;

  Delete(AURL,1,n1);

  path:=AURL;
end;

procedure ParseRFCURL(const URL: string; var proto, user, password, host, path: string; var port, version: integer; var auth: TLdapAuthMethod);
var
  n1, n2: integer;
  AUrl: string;
  p: PChar;
  Extensions: TStringList;

  function DecodeURL(const Src: string): string;
  var
    p, p1: PChar;
    rg: string;
  begin
    Result := '';
    p := PChar(Src);
    while p^ <> #0 do begin
      p1 := CharNext(p);
      if (p^ = '%') then
      begin
        p := CharNext(p);
        p1 := CharNext(p);
        p1 := CharNext(p1);
        SetString(rg, p, p1 - p);
        Result := Result + Char(StrToInt('$' + rg));
      end
      else
        Result := Result + p^;
      p := p1;
    end;
  end;

  procedure ParseExtensions(const ExtStr: string);
  var
    val: string;
  begin
    if ExtStr = '' then Exit;
    try
      Extensions := TStringList.Create;
      with Extensions do begin
        CommaText := ExtStr;
        user := DecodeURL(Values['bindname']);
        password := DecodeURL(Values['password']);
        val := Values['auth'];
        if (val='') or (val='simple') then
          auth := AUTH_SIMPLE
        else
        if val = 'gss' then
          auth := AUTH_GSS
        else
        if val = 'sasl' then
        begin
          if proto = 'ldaps' then
            raise Exception.Create(stSaslSSL);
          auth := AUTH_GSS_SASL;
        end
        else
          raise Exception.Create(Format(stUnsupportedAuth, [val]));
        val := Values['version'];
        if val <> '' then
        try
          version := StrToInt(val);
        except
          on E: EConvertError do
            raise Exception.CreateFmt(stInvalidCmdVer, [val]);
          else
            raise;
        end;
      end;
    finally
      Extensions.Free;
    end;
  end;

begin
  //URL format <proto>://[host[:port]]/<dn>?[bindname=[username]][,password=[password]][,auth=[plain|gss|sasl]][,version=n]

  AUrl:=Url;
  n1:=pos('://',AURL);
  if n1>0 then begin
    proto:=copy(AURL,1,n1-1);
    Delete(AURL,1,n1+2);
  end;

  n1:=pos('/',AURL);
  if n1=0 then
    raise Exception.Create(stInvalidURL);
  n2:=pos(':',copy(AURL,1,n1-1));
  if n2>0 then begin
    host:=copy(AURL,1,n2-1);
    port:=StrToIntDef(copy(AURL,n2+1,n1-n2-1),-1);
  end
  else begin
    if n1=1 then
      host := 'localhost'
    else
      host:=copy(AURL,1,n1-1);
    if proto='ldaps' then
      port := 636;
  end;
  Delete(AURL,1,n1);
  n1:=pos('?',AURL);
  if n1=0 then
    path:=DecodeURL(AURL)
  else begin
    path := DecodeURL(Copy(AURL,1,n1-1));
    p := StrRScan(@AURL[n1], '?');
    p := CharNext(p);
    ParseExtensions(p);
  end;
end;

procedure ParseURL(const URL: string; var proto, user, password, host, path: string; var port, version: integer; var auth: TLdapAuthMethod);
begin
  if Pos('@',URL) > 0 then // old LdapAdmin style
    ParseLAURL(URL, proto, user, password, host, path, port)
  else
    ParseRFCURL(URL, proto, user, password, host, path, port, version, auth);
end;

function HexMem(P: Pointer; Count: Integer; Ellipsis: Boolean): string;
var
  i, cnt: Integer;
begin
  Result := '';
  if Count > 64 then
    cnt := 64
  else begin
    cnt := Count;
    Ellipsis := false;
  end;
  for i := 0 to cnt - 1 do
    Result := Result + IntToHex(PByteArray(P)[i], 2) + ' ';
  if Ellipsis and (Result <> '') then
    Result := Result + '...';
end;

{ String handling routines }

function IsNumber(const S: string): Boolean;
var
  P: PChar;
begin
  P  := PChar(S);
  Result := False;
  while P^ <> #0 do
  begin
    if not (P^ in ['0'..'9']) then Exit;
    Inc(P);
  end;
  Result := True;
end;

procedure Split(Source: string; Result: TStrings; Separator: Char);
var
  p0, p: PChar;
  s: string;
begin
  p0 := PChar(Source);
  p := p0;
  repeat
    while (p^<> #0) and (p^ <> Separator) do
      p := CharNext(p);
    SetString(s, p0, p - p0);
    Result.Add(s);
    if p^ = #0 then
      exit;
    p := CharNext(p);
    p0 := p;
  until false;
end;

{ Address fields take $ sign as newline tag so we have to convert this to LF/CR }

function FormatMemoInput(const Text: string): string;
var
  p: PChar;
begin
  Result := '';
  p := PChar(Text);
  while p^ <> #0 do begin
    if p^ = '$' then
      Result := Result + #$D#$A
    else
      Result := Result + p^;
    p := CharNext(p);
  end;
end;

function FormatMemoOutput(const Text: string): string;
var
  p, p1: PChar;
begin
  Result := '';
  p := PChar(Text);
  while p^ <> #0 do begin
    p1 := CharNext(p);
    if (p^ = #$D) and (p1^ = #$A) then
    begin
      Result := Result + '$';
      p1 := CharNext(p1);
    end
    else
      Result := Result + p^;
    p := p1;
  end;
end;

function FileReadString(const FileName: TFileName): String;
var
  sl: TStringList;
begin
    sl := TStringList.Create;
    try
      sl.LoadFromFile(FileName);
      Result := sl.text;
    finally
      sl.Free;
    end;
end;

procedure FileWriteString(const FileName: TFileName; const Value: string);
var
  sl: TStringList;
begin
    sl := TStringList.Create;
    try
      sl.SaveToFile(FileName);
    finally
      sl.Free;
    end;
end;

{ Check if Wildcard matches Text. Wildcard may contain multiple wildcards '*' }
function Matches(Wildcard, Text: string; CaseSensitive: boolean = false): Boolean;
var
  pw, pt, pa: PChar;
  c: Char;
begin
  if not CaseSensitive then
  begin
    pw := PChar(lowercase(Wildcard));
    pt := PChar(lowercase(Text));
  end
  else begin
    pw := PChar(Wildcard);
    pt := PChar(Text);
  end;

  while pw^ <> #0 do
  begin
    if pw^ = '*' then
    begin
      inc(pw);
      if pw^ = #0 then // ends with wildcard, the rest of Text doesn't matter
      begin
        Result := true;
        exit;
      end;
      pa := pw;
      while (pw^ <> #0) and (pw^ <> '*') do
        inc(pw);
      c := pw^;
      pw^:= #0;
      if AnsiStrPos(pt, pa)= nil then
      begin
        Result := false;
        exit;
      end;
      pw^ := c;
      pt := pw;
      continue;
    end;

    if pw^ = '\' then
    begin
      inc(pw);
      if pw^= #0 then
      begin
        Result := false;
        exit;
      end;
    end;

    if pw^ <> pt^ then
    begin
      Result := false;
      exit;
    end;
    inc(pw);
    inc(pt);
  end;
  Result := pt^ = pw^;
end;

procedure StreamCopy(pf, pt: TStreamProcedure);
var
  Stream: TMemoryStream;
begin
  Stream := TMemoryStream.Create;
  try
    pf(Stream);
    Stream.Position := 0;
    pt(Stream);
  finally
    Stream.Free;
  end;
end;

procedure LockControl(c: TWinControl; bLock: Boolean);
begin
  if (c = nil) or (c.Parent = nil) or (c.Handle = 0) then Exit;
  if bLock then
    SendMessage(c.Handle, WM_SETREDRAW, 0, 0)
  else
  begin
    SendMessage(c.Handle, WM_SETREDRAW, 1, 0);
    RedrawWindow(c.Handle, nil, 0,
      RDW_ERASE or RDW_FRAME or RDW_INVALIDATE or RDW_ALLCHILDREN);
  end;
end;

function PeekKey: Integer;
var
  msg: TMsg;
begin
  PeekMessage(msg, 0, WM_KEYFIRST, WM_KEYLAST, PM_REMOVE);
  if msg.Message = WM_KEYDOWN then
    Result := msg.WParam
  else
    Result := 0;
end;

function CheckedMessageDlg(const Msg: string; DlgType: TMsgDlgType; Buttons: TMsgDlgButtons; CbCaption: string; var CbChecked: Boolean): TModalResult;
var
  Form: TForm;
  i: integer;
  CheckCbx: TCheckBox;
begin
  Form:=CreateMessageDialog(Msg, DlgType, Buttons);
  with Form do
  try
      CheckCbx:=TCheckBox.Create(Form);
      CheckCbx.Parent:=Form;
      CheckCbx.Caption:=Caption;
      CheckCbx.Width:=Width - CheckCbx.Left;
      CheckCbx.Caption := CbCaption;
      CheckCbx.Checked := CbChecked;

      for i:=0 to ComponentCount-1 do begin
        if Components[i] is TLabel then begin
          TLabel(Components[i]).Top:=16;
          CheckCbx.Top:=TLabel(Components[i]).Top+TLabel(Components[i]).Height+16;
          CheckCbx.Left:=TLabel(Components[i]).Left;
        end;
      end;

      for i:=0 to ComponentCount-1 do begin
        if Components[i] is TButton then begin
          TButton(Components[i]).Top:=CheckCbx.Top+CheckCbx.Height+24;
          ClientHeight:=TButton(Components[i]).Top+TButton(Components[i]).Height+16;
        end;
      end;
      Result := ShowModal;
      CbChecked := CheckCbx.Checked;
  finally
    Form.Free;
  end;
end;

function ComboMessageDlg(const Msg: string; const csItems: string; var Text: string): TModalResult;
var
  Form: TForm;
  i: integer;
  Combo: TComboBox;
begin
  Form:=CreateMessageDialog(Msg, mtCustom, mbOkCancel);
  with Form do
  try
    Combo := TComboBox.Create(Form);
    Combo.Parent:=Form;
    Combo.Items.CommaText := csItems;
    Combo.Style := csDropDown;
    for i:=0 to ComponentCount-1 do begin
      if Components[i] is TLabel then begin
        TLabel(Components[i]).Top:=16;
        Width := TLabel(Components[i]).Width + 32;
        Combo.Top:=TLabel(Components[i]).Top+TLabel(Components[i]).Height+4;
        Combo.Left:=TLabel(Components[i]).Left;
      end;
    end;
    if Combo.Width > Width - 32 then
      Width := Combo.Width + 32;

    for i:=0 to ComponentCount-1 do begin
      if Components[i] is TButton then begin
        TButton(Components[i]).Top:=Combo.Top+Combo.Height+24;
        ClientHeight:=TButton(Components[i]).Top+TButton(Components[i]).Height+16;
      end;
    end;
    ActiveControl := Combo;
    Result := ShowModal;
    Text := Combo.Text;
  finally
    Form.Free;
  end;
end;

{ Uses Caption array to replace captions and Events array to assign OnClick event to buttons}
function MessageDlgEx(const Msg: string; DlgType: TMsgDlgType; Buttons: TMsgDlgButtons;
         Captions: array of string; Events: array of TNotifyEvent): TModalResult;
const
  cbBtnSpacing = 4;
  cbDlgMargin  = 8;
var
  Form: TForm;
  i, ci, ce, w, btnWidth, btnCount, leftPos: Integer;
  TextRect: TRect;
begin
  Form:=CreateMessageDialog(Msg, DlgType, Buttons);
  with Form do
  try
    ci := 0;
    ce := 0;
    btnWidth := 0;
    btnCount := 0;
    for i:=0 to ComponentCount - 1 do
    begin
      if (Components[i] is TButton) then with TButton(Components[i]) do
      begin
        inc(btnCount);
        if ci <= High(Captions) then
        begin
          if Captions[ci] <> '' then
          begin
            Caption := Captions[ci];
            TextRect := Rect(0,0,0,0);
            Windows.DrawText( canvas.handle, PChar(Captions[ci]), -1, TextRect,
                              DT_CALCRECT or DT_LEFT or DT_SINGLELINE or
                              DrawTextBiDiModeFlagsReadingOnly);
            //with TextRect do Width := Right - Left + cbBtnSpacing + cbDlgMargin;
            with TextRect do w := Right - Left + cbBtnSpacing + cbDlgMargin;
            if w > Width then
              Width := w;
          end;
          inc(ci);
        end;
        inc(btnWidth, Width);
        if ce <= High(Events) then
        begin
          if Assigned(Events[ce]) then
            OnClick := Events[ce];
          inc(ce);
        end;
      end;
    end;

    // Adjust button positions
    btnWidth := btnWidth + cbBtnSpacing * (btnCount - 1);
    if Width < (btnWidth + 2 * cbDlgMargin) then
      Width := btnWidth + 2 * cbDlgMargin;

    leftPos := (Width - btnWidth) div 2;
    for i:=0 to ComponentCount - 1 do
    if (Components[i] is TButton) then with TButton(Components[i]) do
    begin
      Left := leftPos;
      inc(leftPos, Width + cbBtnSpacing);
    end;

    Result := ShowModal;
  finally
    Form.Free;
  end;
end;

procedure RevealWindow(Form: TForm; MoveLeft, MoveTop: Boolean);
var
  R1, R2: TRect;
  o1, o2: Integer;

  procedure ToLeft;
  begin
    if R2.Left - o1 > 0 then
      Form.Left := R2.Left - o1
    else
      Form.Left := Form.Left + R2.Right - R1.Right + o1;
  end;

  procedure ToRight;
  begin
    if R2.Right + o1 > Screen.Width then
    begin
      Form.Left := R2.Left - o1;
      if Form.Left < 0 then Form.Left := 0;
    end
    else
      Form.Left := Form.Left + R2.Right - R1.Right + o1;
  end;

  procedure ToTop;
  begin
    if R2.Top - o2 > 0 then
      Form.Top := R2.Top - o2
    else
      Form.Top := Form.Top + R2.Bottom - R1.Bottom + o2;
  end;

  procedure ToBottom;
  begin
    if R2.Bottom + o2 > Screen.Height then
    begin
      Form.Top := R2.Top - o2;
      if Form.Top < 0 then Form.Top := 0;
    end
    else
      Form.Top := Form.Top + R2.Bottom - R1.Bottom + o2;
  end;

begin
  if fsShowing in Form.FormState then Exit;
  //if Application.MainForm.WindowState = wsMaximized then Exit;
  o1 := 48 + Random(32);
  o2 := 48 + Random(32);
  GetWindowRect(Form.Handle, R1);
  GetWindowRect(Application.MainForm.Handle, R2);
  if (R1.Top < R2.Top) or (R1.Bottom > R2.Bottom) or
     (R1.Left < R2.Left) or (R1.Right > R2.Right) then Exit;
  if MoveLeft then
    ToLeft
  else
    ToRight;
  if MoveTop then
    ToTop
  else
    ToBottom;
end;

function CreateComponent(const ClassName: string; Owner: TComponent): TComponent;
const
  CONTROLS_CLASSES: array[0..37] of TComponentClass = (TLabel,
                                                       TEdit,
                                                       TMemo,
                                                       TButton,
                                                       TCheckbox,
                                                       TRadioButton,
                                                       TListBox,
                                                       TComboBox,
                                                       TScrollBar,
                                                       TGroupBox,
                                                       TRadioGroup,
                                                       TPanel,
                                                       //TBitBtn,
                                                       //TSpeedButton,
                                                       //TMaskEdit,
                                                       //TStringGrid,
                                                       //TDrawGrid,
                                                       TImage,
                                                       TShape,
                                                       TBevel,
                                                       TScrollBox,
                                                       //TCheckListBox,
                                                       TSplitter,
                                                       TStaticText,
                                                       TControlBar,
                                                       //TApplicationEvents,
                                                       //TChart,
                                                       TTabControl,
                                                       //TPageControl,
                                                       //TTabSheet,
                                                       TImageList,
                                                       TRichEdit,
                                                       TTrackBar,
                                                       TProgressBar,
                                                       TUpDown,
                                                       THotkey,
                                                       TAnimate,
                                                       TDateTimePicker,
                                                       TMonthCalendar,
                                                       TTreeView,
                                                       TListView,
                                                       THeaderControl,
                                                       TStatusBar,
                                                       TToolBar,
                                                       TCoolBar,
                                                       TPageScroller,
                                                       TTimer,
                                                       //TMediaPlayer,
                                                       TPaintBox);

  function ClassByName(const ClassName: string): TComponentClass;
  var
    i: Integer;
  begin
    Result := nil;
    for i := 0 to High(CONTROLS_CLASSES) do
      if CONTROLs_CLASSES[i].ClassName = ClassName then
        Result := CONTROLS_CLASSES[i];
    if not Assigned(Result) then
      raise EClassNotFound.CreateFmt(stClassNotFound, [ClassName]);
  end;

begin
  Result := TComponentClass(ClassByName(ClassName)).Create(Owner);
end;

procedure OnScrollTimer(ScrollTimer: TTimer; TreeView: TTreeView; ScrollAccMargin: Integer);
var
  ct, pt: TPoint;
  Param: LParam;
begin
  GetCursorPos(ct);
  pt := TreeView.ScreenToClient(ct);
  if (pt.y < -ScrollAccMargin) or (pt.y > TreeView.ClientHeight + ScrollAccMargin) then
  begin
    if ScrollTimer.Interval <> 10 then
      ScrollTimer.Interval := 10 // accelerate
  end
  else begin
    if ScrollTimer.Interval <> 100 then
      ScrollTimer.Interval := 100 // deccelerate
  end;
  if pt.y < 0 then
  begin
    if ct.y = 0 then
      Param := SB_PAGEUP
    else
      Param := SB_LINEUP;
    SendMessage(TreeView.Handle, WM_VSCROLL, Param, 0);
  end
  else
  if pt.y > TreeView.ClientHeight then
  begin
    if ct.y = Screen.Height - 2 then
      Param := SB_PAGEDOWN
    else
      Param := SB_LINEDOWN;
    SendMessage(TreeView.Handle, WM_VSCROLL, Param, 0);
  end;
end;

function LoadBase64(const FileName: string): AnsiString;
var
  ms: TMemoryStream;
begin
  ms := TMemoryStream.Create;
  try
    ms.LoadFromFile(FileName);
    ms.Position := 0;
    Result := Base64Encode(ms.Memory^, ms.Size);
  finally
    ms.free;
  end;
end;

end.
