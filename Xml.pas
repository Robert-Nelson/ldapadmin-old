  {      LDAPAdmin - Xml.pas
  *      Copyright (C) 2005 Alexander Sokoloff
  *
  *      Author: Alexander Sokoloff
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

    @Version 2006/03/18  v1.0.0. Initial revision.
    @Version 2006/09/13  v1.1.0. Added TXmlNode.CopyTo function
    @Version 2007/06/29  v1.2.0. Added Utf8 write support, T.Karlovic
    @Version 2007/07/02  v1.2.1. Added callback write support, T.Karlovic
    @Version 2012/02/08  v1.2.2. Added EXmlException,
                                 Added script tag support, T.Karlovic
    @Version 2012/02/08  v1.2.3. Added Utf8 read support, T.Karlovic
                                 Added Markups property, T.Karlovic
                                 Read performance improvement
                                 TFileStream->TMemoryStream, T.Karlovic
  }

unit Xml;

interface

uses windows, sysutils, Classes, Contnrs;

type
  TTagType=(tt_Open, tt_Close, tt_Single);

  EXmlException = class(Exception)
  private
    FPosition: Integer;
    FLine: Integer;
    FTagName: string;
    FMessage: string;
    FMessage2: string;
    FText: string;
  public
    constructor Create(Stream: TStream; const TagName, ErrMsg: string);
    property Line: Integer read FLine;
    property Position: Integer read FPosition;
    property Tag: string read FTagName;
    property Message: string read FMessage;
    property Message2: string read FMessage2;
    property XmlText: string read FText;
  end;


  TXmlNode=class
  private
    FName:      string;
    FAttrs:     TStringList;
    FNodes:     TObjectList;
    FParent:    TXmlNode;
    FContent:   string;
    FCaseSens:  boolean;
    function    GetNodes(Index: integer): TXmlNode;
    function    GetCount: integer;
    procedure   SetParent(const Value: TXmlNode);
    function    GetCaseSens: boolean;
  public
    constructor Create(AParent: TXmlNode); reintroduce;
    destructor  Destroy; override;
    property    Attributes: TStringList read FAttrs;
    property    Nodes[Index: integer]: TXmlNode read GetNodes; default;
    property    Count: integer read GetCount;
    property    Name: string read FName write FName;
    property    Parent: TXmlNode read FParent write SetParent;
    property    Content: string read FContent write FContent;
    function    Add(const AName: string=''; const AContent: string=''; const AAttributes: TstringList=nil): TXmlNode;
    function    Clone(const Recurse: boolean): TxmlNode;
    procedure   Delete(Index: integer);
    function    NodeByName(AName: string; CaseSensitive: boolean=true; Lang: string=''): TXmlNode;
    property    CaseSensitive: boolean read GetCaseSens;
  end;

  TStreamCallback = procedure (Node: TXmlNode) of object;

  TXmlTree=class
  private
    FRoot:      TXmlNode;
    FUtf8:      Boolean;
    FMarkups:   Boolean;
    function    GetNextTag(Stream: TStream; var PrevContent, TagName, Attrs: string; var TagType: TTagType): boolean;
    procedure   ParseAttributes(S: string; Attributes: TStringList);
    function    ClearContent(S: string): string;
    procedure   ParsePath(const Path: string; Result: TStrings);
    function    DoGetNode(var Path: TStrings): TXmlNode;
    procedure   SetCaseSens(const Value: boolean);
    function    GetCaseSens: boolean;
  public
    constructor Create; reintroduce;
    destructor  Destroy; override;
    property    Root: TXmlNode read FRoot;
    procedure   LoadFromStream(const Stream: TStream); virtual;
    procedure   SaveToStream(const Stream: TStream; StreamCallback: TStreamCallback = nil); virtual;
    procedure   LoadFromFile(const FileName: string);
    procedure   SaveToFile(const FileName: string; StreamCallback: TStreamCallback = nil);
    function    ByPath(const APath: string): TXmlNode;
    function    Exist(const Path: string): boolean;
    property    CaseSensitive: boolean read GetCaseSens write SetCaseSens;
    property    Utf8: Boolean read fUtf8 write fUtf8;
    property    Markups: Boolean read FMarkups write FMarkups;
  end;


implementation

uses Misc, Constant;

const
  TAB  = '  ';//#9;
  CRLF = #13#10;

{ EXmlException }

constructor EXmlException.Create(Stream: TStream; const TagName, ErrMsg: string);
  procedure CountLines(var Lines, Pos: Integer);
  var
    i, il, iend: Integer;
  begin
    SetLength(FText, Stream.Size);
    iend := Stream.Position;
    Stream.Position := 0;
    Stream.Read(FText[1], Stream.Size);
    i := 1;
    il := 1;
    Lines := 0;
    while i < iEnd do
    begin
      if FText[i] = #13 then
      begin
        inc(Lines);
        il := i;
      end;
      inc(i);
    end;
    while FText[il] in [#13,#10] do inc(il);
    Pos := iend - il - Length(Tag);
  end;
begin
  inherited Create(ErrMsg);
  FTagName := TagName;
  FMessage := BAD_XML_DOCUMENT;
  FMessage2 := ErrMsg;
  CountLines(FLine, FPosition);
end;

{ TXmlNode }

constructor TXmlNode.Create(AParent: TXmlNode);
begin
  inherited Create;
  FAttrs:=TStringList.Create;
  FNodes:=TObjectList.Create;
  FParent:=AParent;
  if FParent<>nil then FParent.FNodes.Add(self);
end;

destructor TXmlNode.Destroy;
begin
  FAttrs.Free;
  FNodes.Free;
  inherited;
end;

function TXmlNode.GetNodes(Index: integer): TXmlNode;
begin
  result:=TXmlNode(FNodes[Index]);
end;

function TXmlNode.GetCount: integer;
begin
  result:=FNodes.Count;
end;

function TXmlNode.Add(const AName, AContent: string; const AAttributes: TstringList): TXmlNode;
begin
  result:=TXmlNode.Create(self);
  result.Name:=AName;
  result.Content:=AContent;
  if AAttributes<>nil then Attributes.Assign(AAttributes);
end;

function TXmlNode.NodeByName(AName: string; CaseSensitive: boolean=true; Lang: string=''): TXmlNode;
type
  TCompareProc=function(const AText, AOther: string): Boolean;
var
  i: integer;
  proc: TCompareProc;
  l: string;
begin
  result:=nil;
  if CaseSensitive then proc:=AnsiSameStr
  else proc:=AnsiSameText;

  for i:=0 to Count-1 do begin
    if Lang <> '' then
    begin
      l := Nodes[i].Attributes.Values['lang'];
      if (l <> '') and not AnsiSameText(Lang, l) then
        continue;
    end;
    if proc(Nodes[i].Name, AName) then begin
      result:=Nodes[i];
      exit;
    end;
  end;
end;

procedure TXmlNode.Delete(Index: integer);
begin
  FNodes.Delete(Index);
end;

procedure TXmlNode.SetParent(const Value: TXmlNode);
begin
  if FParent<>nil then FParent.FNodes.Extract(self);
  FParent := Value;
  if FParent<>nil then FParent.FNodes.Add(self);
end;

function TXmlNode.GetCaseSens: boolean;
begin
  if FParent=nil then result:=FCaseSens
  else result:=FParent.CaseSensitive;
end;

function TXmlNode.Clone(const Recurse: boolean): TxmlNode;
  function DoAdd(Src, Dest: TXmlNode): TXmlNode;
  var
    i: integer;
  begin
    result:=TXmlNode.Create(Dest);
    result.Name:=Src.Name;
    result.Content:=Src.Content;
    result.Attributes.Assign(Src.Attributes);
    if Recurse then
      for i:=0 to Src.Count-1 do DoAdd(Src.Nodes[i], result);
  end;

begin
  result:=DoAdd(self, nil);
end;


{ TXmlTree }

constructor TXmlTree.Create;
begin
  inherited;
  FRoot:=TXmlNode.Create(nil);
end;

destructor TXmlTree.Destroy;
begin
  FRoot.Free;
  inherited;
end;

function TXmlTree.GetNextTag(Stream: TStream; var PrevContent, TagName, Attrs: string; var TagType: TTagType): boolean;
type
  TState=(tsContent, tsScriptContent, tsTag, tsScriptTag, tsAttrs, tsEnd, tsSkip, tsComment, tsMarkup);
var
  c: AnsiChar;
  State: TState;
  quota: boolean;
  CommentState: byte;
  Markup: string;

  function DecodeMarkup(const s: string): string;
  begin
    try
      if (s <> '') and (s[1] = '#') then Result := Chr(StrToInt(Copy(S, 2, MaxInt))) else
      if s = 'quot' then Result := '"'  else
      if s = 'amp'  then Result := '&'  else
      if s = 'apos' then Result := '''' else
      if s = 'lt'   then Result := '<'  else
      if s = 'gt'   then Result := '>'
      else raise Exception.CreateFmt('Unknown reference: %s', [s]);
    except
       on E: Exception do
        raise EXmlException.Create(Stream, TagName, E.Message);
    end;
  end;
  
begin
  result:=false;
  PrevContent:='';
  if (TagType = tt_Open) and (TagName='script') then
    State := tsScriptContent
  else
    State:=tsContent;

  TagName:='';
  attrs:='';
  TagType:=tt_Open;
  quota:=false;
  CommentState:=0;
  while (Stream.Position<Stream.Size) do begin
    Stream.ReadBuffer(c, sizeof(c));
    case State of
      //////////////////////////////////////////////////////////////////////////
      tsContent:  case c of
                    '<':  State:=tsTag;
                    '&':  if FMarkups then begin
                            State := tsMarkup;
                            Markup := '';
                          end
                          else
                            PrevContent:=PrevContent+c;
                    else  PrevContent:=PrevContent+c;
                  end;
      //////////////////////////////////////////////////////////////////////////
      tsTag:      case c of
                    '''',
                    '"': if TagName='' then quota:=true
                         else State:=tsAttrs;
                    '/':  if TagName='' then TagType:=tt_Close
                          else TagType:=tt_Single;
                    '>':  begin
                            result:=true;
                            break;
                          end;
                    ' ':  if quota then TagName:=TagName+c
                          else State:=tsAttrs;
                    '?':  if TagName='' then State:=tsSkip;
                    '-':  if TagName='!-' then begin
                            CommentState:=0;
                            TagName:='';
                            State:=tsComment;
                          end
                          else TagName:=TagName+c;
                    else  TagName:=TagName+c;
                  end;
     //////////////////////////////////////////////////////////////////////////
     tsAttrs:     case c of
                    '>':  begin
                            result:=true;
                            break;
                          end;
                    else  attrs:=attrs+c;
                  end;
     //////////////////////////////////////////////////////////////////////////
     tsMarkup:    case c of
                    ';':  begin
                            PrevContent := PrevContent + DecodeMarkup(Markup);
                            State := tsContent;
                          end;
                    '<':  raise EXmlException.Create(Stream, TagName, Format('Invalid (unclosed) reference: %s', [Markup]));                          
                    else  Markup := Markup + c;
                  end;
    ////////////////////////////////////////////////////////////////////////////
     tsSkip:      case c of
                    '>':  State:=tsContent;
                  end;
     //////////////////////////////////////////////////////////////////////////
     tsComment:   case c of
                    '-':  inc(CommentState);
                    '>':  if CommentState=2 then State:=tsContent;
                    else  CommentState:=0;
                  end;
    ////////////////////////////////////////////////////////////////////////////
      tsScriptContent:
                  case c of
                    '<':  State:=tsScriptTag;
                    else  PrevContent:=PrevContent+c;
                  end;
    ////////////////////////////////////////////////////////////////////////////                  
      tsScriptTag:
                  case c of
                    '/': begin
                           if TagName='' then TagType:=tt_Close
                           else TagType:=tt_Single;
                           State:=tsTag;
                         end;
                    else begin
                      PrevContent:=PrevContent+'<'+c;
                      State := tsScriptContent;
                    end;
                  end;
      //////////////////////////////////////////////////////////////////////////
    end;
  end;

  Attrs:=Trim(attrs);
  if (length(Attrs)>0) and (attrs[length(Attrs)]='/') then begin
    TagType:=tt_Single;
    setlength(Attrs, length(Attrs)-1);
  end;
end;

procedure TXmlTree.LoadFromStream(const Stream: TStream);
var
  PrevContent, TagName: string;
  TagType: TTagType;
  Node:   TXmlNode;
  Attrs:  string;

  procedure CheckEncoding;
  var
    s: TStringList;
  begin
    if not GetNextTag(Stream, PrevContent, TagName, Attrs, TagType) then
     raise EXmlException.Create(Stream, TagName, '');

    if TagName = '?xml' then
    begin
      s := TStringList.Create;
      try
        ParseAttributes(attrs, s);
         if s.Values['encoding'] = 'utf-8' then
           utf8 := true;
      finally
        s.Free;
      end;
      GetNextTag(Stream, PrevContent, TagName, Attrs, TagType);
    end
    else
    if (Length(PrevContent) >= 3) and ((PInteger(@PrevContent[1])^ and $FFFFFF) = $BFBBEF) then // UTF8 BOF
      utf8 := true;
  end;

  function EncodedString(const s: string): string;
  begin
    if utf8 then
      Result := UTF8ToStringLen(PChar(s), Length(s))
    else
      Result := s;
  end;

begin
  if FRoot<>nil then FRoot.Free;
  FRoot:=nil;
  Node:=nil;
  try
    CheckEncoding;
    repeat
      case TagType of
        //////////////////////////////////////////////////////////////////////////
        tt_Single,
        tt_Open:  begin
                    Node:=TXmlNode.Create(Node);
                    if FRoot=nil then FRoot:=Node;

                    Node.FName:=EncodedString(TagName);
                    ParseAttributes(EncodedString(attrs), Node.Attributes);

                    if Node.Parent<>nil then Node.Parent.Content:=EncodedString(ClearContent(Node.Parent.Content+PrevContent));
                    if TagType=tt_Single then Node:=Node.Parent;
                  end;
        //////////////////////////////////////////////////////////////////////////
        tt_Close: begin
                    if Node=nil then raise EXmlException.Create(Stream, TagName, format(XML_UNEXPECTED_CLOSE_TAG,[TagName]));
                    if Node.Name<>TagName then raise EXmlException.Create(Stream, TagName, format(XML_BAD_CLOSE_TAG, [Node.Name, TagName]));

                    Node.Content:=EncodedString(ClearContent(Node.Content+PrevContent));
                    Node:=Node.Parent;
                  end;
        //////////////////////////////////////////////////////////////////////////
       end;
    until not GetNextTag(Stream, PrevContent, TagName, Attrs, TagType);
  finally
    if FRoot=nil then FRoot:=TXmlNode.Create(nil);
  end;
end;

procedure TXmlTree.ParseAttributes(S: string; Attributes: TStringList);
type
  TState=(s_name, s_value);
var
  i: integer;
  State: TState;
  name, value: string;
begin
  name:=''; value:='';
  State:=s_name;

  for i:=1 to length(S) do begin
    case State of
      //////////////////////////////////////////////////////////////////////////
      s_name:
              case S[i] of
                #0..' ':  ;
                '=':    State:=s_Value;
                else    name:=name+S[i];
              end;
      //////////////////////////////////////////////////////////////////////////
      s_value:
              case S[i] of
                #0..' ': ;
                '''',
                '"':  if value<>'' then begin
                        state:=s_name;
                        Attributes.Add(name+'='+value);
                        name:='';
                        value:='';
                      end;
                else  value:=value+S[i];
              end;
      //////////////////////////////////////////////////////////////////////////
    end;
  end;
end;

function TXmlTree.ClearContent(S: string):string;
var
  b, e: integer;
begin
  if S='' then begin
    result:='';
    exit;
  end;

  b:=1;
  while (ord(S[b])>0) and (ord(S[b])<=32) do inc(b);

  e:=length(S);
  while (e>0) and (ord(S[e])<=32) do dec(e);

  result:=copy(S, b, e-b+1);
end;

procedure TXmlTree.SaveToStream(const Stream: TStream; StreamCallback: TStreamCallback = nil);

  function EncodeMarkups(const s: string): string;
  var
    i: Integer;
  begin
    Result := '';
    for i := 1 to Length(s) do
      case s[i] of
        '"':  Result := Result + '&quot;';
        '&':  Result := Result + '&amp;';
        '''': Result := Result + '&apos;';
        '<':  Result := Result + '&lt;';
        '>':  Result := Result + '&gt;';
      else
        Result := Result + s[i]
      end;
  end;

  procedure WriteString(Value: string);
  var
    s: string;
  begin
    if fMarkups then
      Value := EncodeMarkups(Value);

    if fUtf8 then
    begin
      s := StringToUTF8Len(PChar(Value), length(Value));
      Stream.WriteBuffer(s[1], Length(s));
    end
    else
      Stream.WriteBuffer(Value[1], length(Value));
  end;

  procedure WriteNode(Node: TXmlNode; Indent: string; IsFirst: boolean=false);
  var
    i: integer;
  begin
    if not IsFirst then WriteString(CRLF);
    if pos(' ', Node.Name)>0 then WriteString(Indent+'<"'+Node.Name+'"')
    else WriteString(Indent+'<'+Node.Name);

    for i:=0 to Node.Attributes.Count-1 do
      WriteString(' '+Node.Attributes.Names[i]+'='''+Node.Attributes.Values[Node.Attributes.Names[i]]+'''');

    if (Node.Count=0) and (Node.Content='') then begin
      WriteString('/>');
      if Assigned(StreamCallback) then StreamCallback(Node);
      exit;
    end;

    WriteString('>');
    WriteString(Node.Content);
    for i:=0 to Node.Count-1 do WriteNode(Node[i], Indent+TAB);

    if Node.Count>0 then WriteString(CRLF+Indent);
    if pos(' ', Node.Name)>0 then WriteString('</"'+Node.Name+'">')
    else WriteString('</'+Node.Name+'>');
    if Assigned(StreamCallback) then StreamCallback(Node);
  end;

begin
  WriteNode(Root, '', True);
end;


procedure TXmlTree.LoadFromFile(const FileName: string);
var
  FStream: TMemoryStream;
begin
  FStream:=TMemoryStream.Create;
  try
    FStream.LoadFromFile(FileName);
    LoadFromStream(FStream);
  finally
    FStream.Free;
  end;
end;

procedure TXmlTree.SaveToFile(const FileName: string; StreamCallback: TStreamCallback = nil);
var
  FStream: TFileStream;
begin
  FStream:=TFileStream.Create(FileName, fmCreate);
  try
    SaveToStream(FStream, StreamCallback);
  finally
    FStream.Free;
  end;
end;

procedure TXmlTree.ParsePath(const Path: string; Result: TStrings);
var
  i, n: integer;
begin
  Result.Clear;
  if Path='' then exit;
  n:=0;
  for i:=1 to length(Path)+1 do begin
    case Path[i] of
      #0,
      '/',
      '\':  begin
              if n>0 then Result.Add(copy(Path, i-n, n));
              n:=0;
            end;
      else  inc(n);
    end;
  end;
end;

function TXmlTree.DoGetNode(var Path: TStrings): TXmlNode;
var
  Node: TXmlNode;
begin
  Node:=Root;
  result:=Root;
  while Path.Count>0 do begin
    Node:=Node.NodeByName(Path[0], CaseSensitive);
    if Node=nil then exit;
    result:=Node;
    Path.Delete(0);
  end;
end;

function TXmlTree.Exist(const Path: string): boolean;
var
  strs: TStrings;
begin
  strs:=TStringList.Create;
  ParsePath(Path, strs);
  DoGetNode(strs);
  result:=strs.Count=0;
  strs.Free;
end;

function TXmlTree.ByPath(const APath: string): TXmlNode;
var
  strs: TStrings;
  i: integer;
begin
  strs:=TStringList.Create;
  ParsePath(APath, strs);
  result:=DoGetNode(strs);
  for i:=0 to strs.Count-1 do result:=result.Add(strs[i]);
  strs.Free;
end;

procedure TXmlTree.SetCaseSens(const Value: boolean);
begin
  FRoot.FCaseSens := Value;
end;

function TXmlTree.GetCaseSens: boolean;
begin
  result:=Froot.CaseSensitive;
end;

end.
