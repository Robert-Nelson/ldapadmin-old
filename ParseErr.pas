  {      LDAPAdmin - ParseErr.pas
  *      Copyright (C) 2012 Tihomir Karlovic
  *
  *      Author: Tihomir Karlovic
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

unit ParseErr;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls;

type
  TParseErrDlg = class(TForm)
    Bevel1: TBevel;
    btnClose: TButton;
    Label2: TLabel;
    SrcMemo: TMemo;
    Image1: TImage;
    Label1: TLabel;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormActivate(Sender: TObject);
  private
    fLine: Integer;
    fPosition: Integer;
    fIdentifier: string;
    procedure HighlightText;
  end;

procedure ParseError(AType: TMsgDlgType; AOwner: TComponent; const FileName, Err1, Err2, Code, Identifier: string; LineNr, Pos: Integer);

implementation

uses Misc, MMSystem, Constant;

{$R *.DFM}

function CountVisibleLines(const Memo: TMemo): Integer;
Var
  OldFont: HFont;
  DC: THandle;
  TextMetric: TTextMetric;
begin
  try
    DC := GetDC(Memo.Handle);
    try
      OldFont := SelectObject(DC, Memo.Font.Handle);
      try
        GetTextMetrics(DC, TextMetric);
        Result := (Memo.ClientRect.Bottom - Memo.ClientRect.Top) div
                  (TextMetric.tmHeight + TextMetric.tmExternalLeading);
      finally
        SelectObject(DC, OldFont);
      end;
    finally
      ReleaseDC(Memo.Handle, DC);
    end;
  except
    Result := 1;
  end;
end;

procedure TParseErrDlg.HighlightText;
var
  i: Integer;

  function SelectIdentifier: Boolean;
  begin
    Result := false;
    if fIdentifier <> '' then with SrcMemo do
    begin
      i := Pos(fIdentifier, Lines[fLine]);
      if i > 0 then
      begin
        SelStart := Perform(EM_LINEINDEX, fLine, 0) + i - 1;
        Result := true;
      end;
    end;
  end;
begin
  with SrcMemo do
  begin
    if not SelectIdentifier then
      SelStart := Perform(EM_LINEINDEX, fLine, 0) + fPosition;
    SendMessage(Handle, EM_SCROLLCARET, 0,0);
    i := CountVisibleLines(SrcMemo) - 3;
    if CaretPos.Y < i then
      Exit;
    try
      LockControl(SrcMemo, true);
      while i > 0 do
      begin
        Perform(EM_SCROLL, SB_LINEDOWN, 0);
        dec(i);
      end;
    finally
      LockControl(SrcMemo, false);
    end;
  end;
end;


procedure ParseError(AType: TMsgDlgType; AOwner: TComponent; const FileName, Err1, Err2, Code, Identifier: string; LineNr, Pos: Integer);
var
  typeMsg: string;
begin
  with TParseErrDlg.Create(AOwner) do
  try
    with Image1.Picture.Icon do
    case AType of
      mtError: begin
                 typeMsg := cError;
                 Handle := LoadIcon(0, IDI_ERROR);
               end;
      mtWarning: begin
                   typeMsg := cWarning;
                   Handle := LoadIcon(0, IDI_WARNING);
                 end;
      mtInformation: begin
                       typeMsg := cInformation;
                       Handle := LoadIcon(0, IDI_INFORMATION);
                     end;
    else
      typeMsg := '';
    end;

    Label1.Caption := Format('(%s) %2s (Line %d): %3:s', [typeMsg, FileName, LineNr + 1, Err1]);
    if Err2 = '' then
    begin
      Label1.Top := Bevel1.Top + (Bevel1.Height - Label1.Height) div 2;
    end
    else
      Label2.Caption := Err2;
    SrcMemo.Text := Code;
    fLine := LineNr;
    fPosition := Pos;
    fIdentifier := Identifier;
    ShowModal;
  except
    Free;
    raise;
  end;
end;

procedure TParseErrDlg.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
end;

procedure TParseErrDlg.FormActivate(Sender: TObject);
begin
  PlaySound(PChar('SYSTEMHAND'), 0, SND_ASYNC);
  //PlaySound(PChar(SND_ALIAS_SYSTEMHAND), 0, SND_ALIAS_ID + SND_ASYNC);
  SrcMemo.SetFocus;
  HighlightText;
end;

end.
