  {      LDAPAdmin - Password.pas
  *      Copyright (C) 2005-2016 Tihomir Karlovic
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

unit Password;

interface

uses LdapClasses, Hash, md4, md5, sha1, rmd160, Misc;

type
  THashType = (chText, chCrypt, chMd5Crypt, chMd4, chMd5, chSha1, chSMD5, chSSHA, chSha256, chSha512, chRipemd);

const
  IdStrings: array [chText..chRipemd] of string = (
  '','{CRYPT}','{CRYPT}','{MD4}','{MD5}','{SHA}','{SMD5}','{SSHA}','{CRYPT}','{CRYPT}','{RMD160}');

function GetPasswordString(const HashType: THashType; const Password: string): string;

implementation

uses Sysutils, Unixpass, md5crypt, ShaCrypt, base64;

function GetSalt(Len: Integer): String;
const
  SaltChars: array[0..63] of Char =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789./';
var
  i: Integer;
begin
  Randomize;
  SetLength(Result, Len);
  for i := 1 to Len do
    Result[i] := SaltChars[Random(64)];
end;

function Digest(const HashType: THashType; const Password: AnsiString): String;
var
  md4Digest: TMD5Digest;
  md5Digest: TMD5Digest;
  sha1Digest: TSha1Digest;
  rmd160Digest: TRMD160Digest;
begin
  case HashType of
    chMd4:    begin
                MD4Full(TMD4Digest(md4Digest), @Password[1], Length(Password));
                Result := Base64Encode(md4Digest, SizeOf(md4Digest));
              end;
    chMd5:    begin
                MD5Full(md5Digest, @Password[1], Length(Password));
                Result := Base64Encode(md5Digest, SizeOf(md5Digest));
              end;
    chSha1:   begin
                SHA1Full(sha1Digest, @Password[1], Length(Password));
                Result := Base64Encode(sha1Digest, SizeOf(sha1Digest));
              end;
    chRipemd: begin
                RMD160Full(rmd160Digest, @Password[1], Length(Password));
                Result := Base64Encode(rmd160Digest, SizeOf(rmd160Digest));
              end;
  end;
end;

function SaltedDigest(const HashType: THashType; const Password: string): string;
var
  Salt, SaltedKey, Hash: AnsiString;
  md5Digest: TMD5Digest;
  sha1Digest: TSha1Digest;
begin
  Salt := AnsiString(GetSalt(12));
  SaltedKey := AnsiString(Password) + Salt;
  case HashType of
    chSMD5:    begin
                MD5Full(md5Digest, @SaltedKey[1], Length(SaltedKey));
                SetString(Hash, PAnsiChar(@md5Digest), sizeof(md5Digest));
              end;
    chSSHA:   begin
                SHA1Full(sha1Digest, @SaltedKey[1], Length(SaltedKey));
                SetString(Hash, PAnsiChar(@sha1Digest), sizeof(sha1Digest));
              end;
  end;
  Result := Base64Encode(Hash + Salt);
end;

function GetPasswordString(const HashType: THashType; const Password: string): string;
var
  passwd: string;
begin
  case HashType of
    chText:      passwd := Password;
    chCrypt:     passwd := UnixCrypt(GetSalt(2), Password);
    chMd5Crypt:  passwd := md5_crypt_s(Password, GetSalt(8));
    chSMD5,
    chSSHA:      passwd := SaltedDigest(HashType, Password);
    chSha256:    passwd := Sha256(Password);
    chSha512:    passwd := Sha512(Password);
  else
    passwd := Digest(HashType, Password);
  end;
  Result := IdStrings[HashType] + passwd;
end;

end.
