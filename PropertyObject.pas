  {      LDAPAdmin - PropertyObject.pas
  *      Copyright (C) 2005 Tihomir Karlovic
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

unit PropertyObject;

interface

uses Classes, LdapClasses, SysUtils;

const
  INT_NULL    = 0; //??? TODO

type
  TProperties = integer;

  TPropertyObject = class
  private
    fPropertyNames: Pointer;
    fObjectClass: string;
    function GetAttr(Index: TProperties): TLdapAttribute;
    function IsObjectActive: Boolean;
  protected
    fEntry: TLdapEntry;
    procedure AddObjectClass(Oc: array of string);
    procedure RemoveObjectClass(Oc: array of string);
    procedure SetInt(Index: TProperties; Value: Integer);
    function  GetInt(Index: TProperties): Integer;
    procedure SetString(Index: TProperties; Value: string);
    function  GetString(Index: TProperties): string;
    function  GetMultiString(VIndex, AIndex: TProperties): string;
    function  AddToMultiString(Index: TProperties; Value: string): string;
    function  RemoveFromMultiString(Index: TProperties; Value: string): string;
    function  GetMultiStringCount(Index: TProperties): Integer;
    function  GetFromUnixTime(Index: TProperties): TDateTime;
    procedure SetAsUnixTime(Index: TProperties; AValue: TDateTime);
    function  GetCommaText(Index: Integer): string;
    procedure SetCommaText(Index: Integer; AValue: string);
    procedure SetProperty(Index: TProperties; Value: string); virtual;
    constructor Create(const Entry: TLdapEntry); overload; virtual; abstract;
    constructor Create(const Entry: TLdapEntry; const MyObjectClass: string; Properties: Pointer); overload;
  public
    function IsNull(const Index: TProperties): boolean;
    procedure New; virtual;
    procedure Remove; virtual;
    property Attributes[Index: Tproperties]: TLdapAttribute read GetAttr;
    property ObjectClass: string read fObjectClass;
    property Activated: Boolean read IsObjectActive;
  end;


implementation

uses Misc;

{ TPropertyObject }

function TPropertyObject.GetAttr(Index: TProperties): TLdapAttribute;
begin
  Result := fEntry.AttributesByName[PCharArray(fPropertyNames)[Index]];
end;

function TPropertyObject.IsObjectActive: Boolean;
var
  Attr: TLdapAttribute;
  Value: TLdapAttributeData;
  idx: Integer;
begin
  Result := false;
  Attr := fEntry.AttributesByName['objectclass'];
  idx := Attr.IndexOf(fObjectClass);
  if idx <> -1 then
  begin
    Value := Attr.Values[idx];
    if Assigned(Value) and (Value.ModOp <> LdapOpDelete) and (Value.ModOp <> LdapOpNoop) then
      Result := true;
  end;
end;

procedure TPropertyObject.AddObjectClass(Oc: array of string);
var
  i: Integer;
begin
  for i := Low(Oc) to High(Oc) do
    fEntry.AttributesByName['objectclass'].AddValue(Oc[i]);
end;

procedure TPropertyObject.RemoveObjectClass(Oc: array of string);
var
  i: Integer;
begin
  for i := Low(Oc) to High(Oc) do
    fEntry.AttributesByName['objectclass'].DeleteValue(Oc[i]);
end;

procedure TPropertyObject.SetProperty(Index: TProperties; Value: string);
begin
  fEntry.AttributesByName[PCharArray(fPropertyNames)[Index]].AsString := Value;
end;

procedure TPropertyObject.SetInt(Index: TProperties; Value: Integer);
begin
  SetProperty(Index, IntToStr(Value));
end;

function TPropertyObject.GetInt(Index: TProperties): Integer;
begin
  with fEntry.AttributesByName[PCharArray(fPropertyNames)[Index]] do
    if AsString <> '' then
      Result := StrToInt(AsString)
    else
      Result := INT_NULL;
end;

procedure TPropertyObject.SetString(Index: TProperties; Value: string);
begin
  SetProperty(Index, Value);
end;

function TPropertyObject.GetString(Index: TProperties): string;
begin
  Result := fEntry.AttributesByName[PCharArray(fPropertyNames)[Index]].AsString;
end;

function TPropertyObject.GetMultiString(VIndex, AIndex: TProperties): string;
begin
  Result := fEntry.AttributesByName[PCharArray(fPropertyNames)[AIndex]].Values[VIndex].AsString;
end;

function TPropertyObject.AddToMultiString(Index: TProperties; Value: string): string;
begin
  fEntry.AttributesByName[PCharArray(fPropertyNames)[Index]].AddValue(Value);
end;

function TPropertyObject.RemoveFromMultiString(Index: TProperties; Value: string): string;
begin
  fEntry.AttributesByName[PCharArray(fPropertyNames)[Index]].DeleteValue(Value);
end;

function TPropertyObject.GetMultiStringCount(Index: TProperties): Integer;
begin
  Result := fEntry.AttributesByName[PCharArray(fPropertyNames)[Index]].ValueCount;
end;

function TPropertyObject.GetFromUnixTime(Index: TProperties): TDateTime;
var
  s: string;
begin
  s := GetString(Index);
  if s = '' then
    Result := -1
  else
    //Result := StrToInt(s) / 86400 + 25569.0;
    Result := UnixTimeToDateTime(StrToInt64(s));
end;

procedure TPropertyObject.SetAsUnixTime(Index: TProperties; AValue: TDateTime);
begin
  //SetString(Index, IntToStr(Round((AValue - 25569.0) * 86400)));
  SetString(Index, IntToStr(DateTimeToUnixTime(AValue)));
end;

function TPropertyObject.GetCommaText(Index: Integer): string;
var
  i: Integer;
  Attr: TLdapAttribute;
begin
  Result := '';
  Attr := fEntry.AttributesByName[PCharArray(fPropertyNames)[Index]];
  for i := 0 to Attr.ValueCount - 1 do
    with Attr.Values[i] do
      if (ModOp <> LdapOpNoop) and (ModOp <> LdapOpDelete) then
      begin
        if Result <> '' then
          Result := Result + ',';
         Result := Result + AnsiQuotedStr(AsString, '"');
      end;
end;

procedure TPropertyObject.SetCommaText(Index: Integer; AValue: string);
var
  P, P1: PChar;
  S: string;
  Attr: TLdapAttribute;
begin
  Attr := fEntry.AttributesByName[PCharArray(fPropertyNames)[Index]];
  P := PChar(AValue);
  while P^ in [#1..' '] do Inc(P);//P := CharNext(P);
  while P^ <> #0 do
  begin
    if P^ = '"' then
      S := AnsiExtractQuotedStr(P, '"')
    else
    begin
      P1 := P;
      while (P^ > ' ') and (P^ <> ',') do Inc(P);//P := CharNext(P);
      System.SetString(S, P1, P - P1);
    end;
    Attr.AddValue(S);
    while P^ in [#1..' '] do inc(P); //P := CharNext(P);
      if P^ = ',' then
        repeat
          Inc(P);//P := CharNext(P);
        until not (P^ in [#1..' ']);
    end;
end;

constructor TPropertyObject.Create(const Entry: TLdapEntry; const MyObjectClass: string; Properties: Pointer);
begin
  fEntry := Entry;
  fPropertyNames := Properties;
  fObjectClass := MyObjectClass;
  //Entry.RegisterPropertyObject(Self);
end;

function TPropertyObject.IsNull(const Index: TProperties): boolean;
var
  Value: TLdapAttributeData;
begin
  Value := fEntry.AttributesByName[PCharArray(fPropertyNames)[Index]].Values[0];
  Result := not Assigned(Value) or (Value.DataSize = 0);
end;

procedure TPropertyObject.New;
begin
  AddObjectClass([fObjectClass]);
end;

procedure TPropertyObject.Remove;
begin
  RemoveObjectClass([fObjectClass]);
end;

end.
