  {      LDAPAdmin - ADPassdlg.pas
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

unit ADPassDlg;

interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls, StdCtrls, Buttons,
     LdapClasses;

type
  TADPassDlg = class(TForm)
    Label1: TLabel;
    Password: TEdit;
    OKBtn: TButton;
    CancelBtn: TButton;
    Password2: TEdit;
    Label2: TLabel;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    fLdapPath: WideString;
    fUsername: wideString;
    fPassword: WideString;
  public
    constructor Create(AOwner: TComponent; Entry: TLdapEntry); reintroduce;
  end;

var
  PasswordDlg: TADPassDlg;

implementation

{$R *.DFM}

uses ActiveDs_TLB, adsie, Constant;

constructor TADPassDlg.Create(AOwner: TComponent; Entry: TLdapEntry);
begin
  inherited Create(AOwner);
  with Entry.Session do
  begin
    fLdapPath := 'LDAP://' + Server + '/' + Entry.dn;
    fUserName := User;
    fPassword := Password;
  end;
end;

procedure TADPassDlg.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  User: IADSUser;
begin
  if (ModalResult = mrOk) then
  begin
    if Password.Text <> Password2.Text then
      raise Exception.Create(stPassDiff);
    try
      ADOpenObject(fLdapPath, fUserName, fPassword, IID_IADsUser, User);
      User.setpassword(Password.Text);
    finally
      User := nil;
    end;
  end;
end;

end.

