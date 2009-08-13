
{$I Defines.inc}

unit MixFormat;

interface

uses
  Windows,
  MixTypes;


type
  TDateTime = Double;

  PDayTable = ^TDayTable;
  TDayTable = array[1..12] of Word;

const
  DateDelta = 693594;  { Days between 1/1/0001 and 12/31/1899 }
  SecsPerDay = 24 * 60 * 60;
  MSecsPerDay = SecsPerDay * 1000;

  MonthDays: array [Boolean] of TDayTable =
    ((31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31),
     (31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31));


function Now :TDateTime;
function IsLeapYear(Year: Word): Boolean;
function EncodeDate(Year, Month, Day: Word): TDateTime;
function EncodeTime(Hour, Min, Sec, MSec: Word) :TDateTime;
procedure DecodeDate(Date: TDateTime; var Year, Month, Day: Word);
procedure DecodeTime(Time: TDateTime; var Hour, Min, Sec, MSec: Word);
function DateTimeToFileDate(DateTime: TDateTime): Integer;
function FileDateToDateTime(FileDate: Integer): TDateTime;

function FormatDate(const Format :TString; DateTime: TDateTime) :TString;
function FormatTime(const Format :TString; DateTime: TDateTime) :TString;
function DateTimeToStr(DateTime: TDateTime) :TString;

type
  { For FloatToText }
  TFloatFormat = (ffGeneral, ffExponent, ffFixed, ffNumber, ffCurrency);
  TFloatValue = (fvExtended, fvCurrency, fvSingle, fvReal, fvDouble, fvComp);

function HexStr(AVal :Int64; ACount :Integer) :TString;

Function Format (Const Fmt :TString; const Args : Array of const) :TString;

Function FloatToStrF(Value: Extended; format: TFloatFormat; Precision, Digits: Integer): String; overload;

{******************************************************************************}
{******************************} implementation {******************************}
{******************************************************************************}

uses
  MixUtils,
  MixConsts,
  MixDebug;

{------------------------------------------------------------------------------}
{ Date/Time functions                                                          }
{------------------------------------------------------------------------------}

procedure ConvertError(ResString :PString);
begin
  raise EConvertError.CreateRes(ResString);
end;


function Now :TDateTime;
var
  SystemTime: TSystemTime;
begin
  GetLocalTime(SystemTime);
  with SystemTime do
    Result := EncodeDate(wYear, wMonth, wDay) + EncodeTime(wHour, wMinute, wSecond, wMilliseconds);
end;


function IsLeapYear(Year: Word): Boolean;
begin
  Result := (Year mod 4 = 0) and ((Year mod 100 <> 0) or (Year mod 400 = 0));
end;


function DoEncodeDate(Year, Month, Day: Word; var Date: TDateTime): Boolean;
var
  I: Integer;
  DayTable: PDayTable;
begin
  Result := False;
  DayTable := @MonthDays[IsLeapYear(Year)];
  if (Year >= 1) and (Year <= 9999) and (Month >= 1) and (Month <= 12) and (Day >= 1) and (Day <= DayTable^[Month]) then begin
    for I := 1 to Month - 1 do
      Inc(Day, DayTable^[I]);
    I := Year - 1;
    Date := I * 365 + I div 4 - I div 100 + I div 400 + Day - DateDelta;
    Result := True;
  end;
end;

function EncodeDate(Year, Month, Day: Word): TDateTime;
begin
  if not DoEncodeDate(Year, Month, Day, Result) then
    ConvertError(@SDateEncodeError);
end;


function DoEncodeTime(Hour, Min, Sec, MSec: Word; var Time: TDateTime): Boolean;
begin
  Result := False;
  if (Hour < 24) and (Min < 60) and (Sec < 60) and (MSec < 1000) then begin
    Time := (cardinal(Hour) * 3600000 + cardinal(Min) * 60000 + cardinal(Sec) * 1000 + MSec) / MSecsPerDay;
    Result := True;
  end;
end;


function EncodeTime(Hour, Min, Sec, MSec: Word): TDateTime;
begin
  if not DoEncodeTime(Hour, Min, Sec, MSec, Result) then
    ConvertError(@STimeEncodeError);
end;


procedure DecodeDate(Date: TDateTime; var Year, Month, Day :word);
var
  ly,ld,lm,j : cardinal;
begin
  if Date <= -DateDelta then begin  // If Date is before 1-1-1 then return 0-0-0
    Year := 0;
    Month := 0;
    Day := 0;
  end else
  begin
    j := pred((Trunc(System.Int(Date)) + 693900) SHL 2);
    ly:= j DIV 146097;
    j:= j - 146097 * cardinal(ly);
    ld := j SHR 2;
    j:=(ld SHL 2 + 3) DIV 1461;
    ld:= (cardinal(ld) SHL 2 + 7 - 1461*j) SHR 2;
    lm:=(5 * ld-3) DIV 153;
    ld:= (5 * ld +2 - 153*lm) DIV 5;
    ly:= 100 * cardinal(ly) + j;
    if lm < 10 then
      inc(lm,3)
    else begin
      dec(lm,9);
      inc(ly);
    end;
    year:=ly;
    month:=lm;
    day:=ld;
  end;
end;


procedure DecodeTime(Time :TDateTime; var Hour, Min, Sec, MSec :word);
Var
  l : cardinal;
begin
  l := Round(abs(Frac(time)) * MSecsPerDay);
  Hour   := l div 3600000;
  l := l mod 3600000;
  Min := l div 60000;
  l := l mod 60000;
  Sec := l div 1000;
  l := l mod 1000;
  MSec := l;
end;


function DateTimeToFileDate(DateTime :TDateTime): Integer;
var
  Year, Month, Day, Hour, Min, Sec, MSec: Word;
begin
  DecodeDate(DateTime, Year, Month, Day);
  if (Year < 1980) or (Year > 2099) then
    Result := 0
  else begin
    DecodeTime(DateTime, Hour, Min, Sec, MSec);
    LongRec(Result).Lo := (Sec shr 1) or (Min shl 5) or (Hour shl 11);
    LongRec(Result).Hi := Day or (Month shl 5) or ((Year - 1980) shl 9);
  end;
end;


function FileDateToDateTime(FileDate :Integer): TDateTime;
begin
  Result :=
    EncodeDate(
      LongRec(FileDate).Hi shr 9 + 1980,
      LongRec(FileDate).Hi shr 5 and 15,
      LongRec(FileDate).Hi and 31) +
    EncodeTime(
      LongRec(FileDate).Lo shr 11,
      LongRec(FileDate).Lo shr 5 and 63,
      LongRec(FileDate).Lo and 31 shl 1, 0);
end;


function FormatDate(const Format :TString; DateTime: TDateTime) :TString;
var
  vFlags :DWORD;
  vFormat :PTChar;
  vTime :SYSTEMTIME;
  vBuf :array[0..256] of TChar;
  vLen :Integer;
begin
  Result := '';
  vFlags := 0;
  vFormat := nil;
  if Format = '' then
    vFlags := DATE_SHORTDATE
  else
    vFormat := PTChar(Format);

  FillChar(vTime, SizeOf(vTime), 0);
  DecodeDate(DateTime, vTime.wYear, vTime.wMonth, vTime.wDay);

  vLen := High(vBuf);
  vLen := GetDateFormat(LOCALE_USER_DEFAULT, vFlags, @vTime, vFormat, @vBuf[0], vLen);
  if vLen > 1 then
    SetString(Result, PTChar(@vBuf), vLen - 1);
end;


function FormatTime(const Format :TString; DateTime: TDateTime) :TString;
var
  vFlags :DWORD;
  vFormat :PTChar;
  vTime :SYSTEMTIME;
  vBuf :array[0..256] of TChar;
  vLen :Integer;
begin
  Result := '';
  vFlags := 0;
  vFormat := nil;
  if Format = '' then
    vFlags := TIME_FORCE24HOURFORMAT
  else
    vFormat := PTChar(Format);

  FillChar(vTime, SizeOf(vTime), 0);
  DecodeTime(DateTime, vTime.wHour, vTime.wMinute, vTime.wSecond, vTime.wMilliseconds);

  vLen := High(vBuf);
  vLen := GetTimeFormat(LOCALE_USER_DEFAULT, vFlags, @vTime, vFormat, @vBuf[0], vLen);
  if vLen > 1 then
    SetString(Result, PTChar(@vBuf), vLen - 1);
end;


function DateTimeToStr(DateTime: TDateTime) :TString;
begin
  Result := FormatDate('', DateTime) + ' ' + FormatTime('', DateTime)
end;


{------------------------------------------------------------------------------}
{                                                                              }
{------------------------------------------------------------------------------}

function CharUpCase(AChr :TChar) :TChar;
begin
  Result := TChar(TUnsPtr({Windows.}CharUpper(Pointer(TUnsPtr(AChr)))));
end;


function Space(ASize :Integer) :TString;
begin
//SetString(Result, nil, ASize);
//FillChar(PTChar(Result), ASize, ' ');
  Result := StringOfChar(' ', ASize);
end;


const
  HexChars :array[0..15] of TChar = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');

function HexStr(AVal :Int64; ACount :Integer) :TString;
var
  i :Integer;
begin
  SetString(Result, nil, ACount);
  for i := ACount downto 1 do begin
    Result[i] := HexChars[AVal and $f];
    AVal := AVal shr 4;
  end;
end;


Const
  feInvalidFormat   = 1;
  feMissingArgument = 2;
  feInvalidArgIndex = 3;


Procedure DoFormatError (ErrCode : Longint);
Var
  S :String;
begin
  S:='';
  Case ErrCode of
   feInvalidFormat : raise EConvertError.Createfmt(SInvalidFormat,[s]);
   feMissingArgument : raise EConvertError.Createfmt(SArgumentMissing,[s]);
   feInvalidArgIndex : raise EConvertError.Createfmt(SInvalidArgIndex,[s]);
 end;
end;


Function Format (Const Fmt :TString; const Args : Array of const) :TString;
var
  ChPos,OldPos,ArgPos,DoArg,Len :Integer;
  Index :Integer;
  Width, Prec : Longint;
  Left : Boolean;


  Function ReadFormat : Char;
  { ReadFormat reads the format string. It returns the type character in
    uppercase, and sets index, Width, Prec to their correct values,
    or -1 if not set. It sets Left to true if left alignment was requested.
    In case of an error, DoFormatError is called. }
  Var
    Value : longint;

      Procedure ReadInteger;
      var
       {$ifdef bFreePascal}
        Code: Word;
       {$else}
        Code: Integer;
       {$endif bFreePascal}
      begin
        If Value<>-1 then exit; // Was already read.
        OldPos:=ChPos;
        While (ChPos<=Len) and
              (Fmt[ChPos]<='9') and (Fmt[ChPos]>='0') do inc(ChPos);
        If ChPos>len then
          DoFormatError(feInvalidFormat);
        If Fmt[ChPos]='*' then
          begin
          If (ChPos>OldPos) or (ArgPos>High(Args)) then
            DoFormatError(feInvalidFormat);
          case Args[ArgPos].Vtype of
            vtInteger: Value := Args[ArgPos].VInteger;
            vtInt64: Value := Args[ArgPos].VInt64^;
           {$ifdef bFreePascal}
            vtQWord: Value := Args[ArgPos].VQWord^;
           {$endif bFreePascal}
          else
            DoFormatError(feInvalidFormat);
          end;
          Inc(ArgPos);
          Inc(ChPos);
          end
        else
          begin
          If (OldPos<ChPos) Then
            begin
            Val (Copy(Fmt,OldPos,ChPos-OldPos),value,code);
            // This should never happen !!
            If Code>0 then DoFormatError (feInvalidFormat);
            end
          else
            Value:=-1;
          end;
      end;

      Procedure ReadIndex;
      begin
        If Fmt[ChPos]<>':' then
          ReadInteger
        else
          value:=0; // Delphi undocumented behaviour, assume 0, #11099
        If Fmt[ChPos]=':' then
          begin
          If Value=-1 then DoFormatError(feMissingArgument);
          Index:=Value;
          Value:=-1;
          Inc(ChPos);
          end;
      end;

      Procedure ReadLeft;
      begin
        If Fmt[ChPos]='-' then
          begin
          left:=True;
          Inc(ChPos);
          end
        else
          Left:=False;
      end;

      Procedure ReadWidth;
      begin
        ReadInteger;
        If Value<>-1 then
          begin
          Width:=Value;
          Value:=-1;
          end;
      end;

      Procedure ReadPrec;
      begin
        If Fmt[ChPos]='.' then
          begin
          inc(ChPos);
            ReadInteger;
          If Value=-1 then
           Value:=0;
          prec:=Value;
          end;
      end;

 {$ifdef bUnicode}
  var
    FormatChar : TChar;
 {$endif bUnicode}
  begin
    Index:=-1;
    Width:=-1;
    Prec:=-1;
    Value:=-1;
    inc(ChPos);
    If Fmt[ChPos]='%' then
      begin
        Result:='%';
        exit;                           // VP fix
      end;
    ReadIndex;
    ReadLeft;
    ReadWidth;
    ReadPrec;

   {$ifdef bUnicode}
    FormatChar := CharUpcase(Fmt[ChPos]);
    if word(FormatChar) > 255 then
      Result := #255
    else
      Result := Char(FormatChar);
   {$else}
    Result := CharUpcase(Fmt[ChPos]);
   {$endif bUnicode}
  end;


  function Checkarg (AT :Integer; err :boolean):boolean;
  { Check if argument INDEX is of correct type (AT)
    If Index=-1, ArgPos is used, and argpos is augmented with 1
    DoArg is set to the argument that must be used. }
  begin
    result:=false;
    if Index=-1 then
      DoArg:=Argpos
    else
      DoArg:=Index;
    ArgPos:=DoArg+1;
    If (Doarg>High(Args)) or (Args[Doarg].Vtype<>AT) then
     begin
       if err then
        DoFormatError(feInvalidArgindex);
       dec(ArgPos);
       exit;
     end;
    result:=true;
  end;

var
  Hs,ToAdd :TString;
  Fchar :char;
  vq : qword;
begin
  Result:='';
  Len:=Length(Fmt);
  ChPos:=1;
  OldPos:=1;
  ArgPos:=0;

  While ChPos<=len do begin
    While (ChPos<=Len) and (Fmt[ChPos]<>'%') do
      inc(ChPos);
    If ChPos>OldPos Then
      Result:=Result+Copy(Fmt,OldPos,ChPos-Oldpos);

    If ChPos<Len then begin
      FChar := ReadFormat;
      Case FChar of
        'D' :begin
               if Checkarg(vtInteger,False) then
                 Str(Args[Doarg].VInteger,ToAdd)
               else
              {$ifdef bFreePascal}
               if CheckArg(vtQWord,False) then
                 Str(int64(Args[DoArg].VQWord^),toadd)
               else
              {$endif bFreePascal}
               if CheckArg(vtInt64,True) then
                 Str(Args[DoArg].VInt64^,toadd);
               Width:=Abs(width);
               Index:=Prec-Length(ToAdd);
               If ToAdd[1]<>'-' then
                 ToAdd:=StringOfChar('0',Index)+ToAdd
               else
                 // + 1 to accomodate for - sign in length !!
                 Insert(StringOfChar('0',Index+1),toadd,2);
             end;

        'U' :begin
               if Checkarg(vtinteger, False) then
                 Str(cardinal(Args[Doarg].VInteger),ToAdd)
               else
              {$ifdef bFreePascal}
               if CheckArg(vtQWord, False) then
                 Str(Args[DoArg].VQWord^,toadd)
               else
              {$endif bFreePascal}
               if CheckArg(vtInt64, True) then
                 Str(Args[DoArg].VInt64^,toadd);
               Width:=Abs(width);
               Index:=Prec-Length(ToAdd);
               ToAdd:=StringOfChar('0',Index)+ToAdd
             end;

        'E' : begin
              if CheckArg(vtCurrency,false) then
                ToAdd:=FloatToStrF(Args[doarg].VCurrency^,ffexponent,Prec,3)
              else if CheckArg(vtExtended,true) then
                ToAdd:=FloatToStrF(Args[doarg].VExtended^,ffexponent,Prec,3);
              end;
        'F' : begin
              if CheckArg(vtCurrency,false) then
                ToAdd:=FloatToStrF(Args[doarg].VCurrency^,ffFixed,9999,Prec)
              else if CheckArg(vtExtended,true) then
                ToAdd:=FloatToStrF(Args[doarg].VExtended^,ffFixed,9999,Prec);
              end;
        'G' : begin
              if CheckArg(vtCurrency,false) then
                ToAdd:=FloatToStrF(Args[doarg].VCurrency^,ffGeneral,Prec,3)
              else if CheckArg(vtExtended,true) then
                ToAdd:=FloatToStrF(Args[doarg].VExtended^,ffGeneral,Prec,3);
              end;
        'N' : begin
              if CheckArg(vtCurrency,false) then
                ToAdd:=FloatToStrF(Args[doarg].VCurrency^,ffNumber,9999,Prec)
              else if CheckArg(vtExtended,true) then
                ToAdd:=FloatToStrF(Args[doarg].VExtended^,ffNumber,9999,Prec);
              end;
        'M' : begin
              if CheckArg(vtExtended,false) then
                ToAdd:=FloatToStrF(Args[doarg].VExtended^,ffCurrency,9999,Prec)
              else if CheckArg(vtCurrency,true) then
                ToAdd:=FloatToStrF(Args[doarg].VCurrency^,ffCurrency,9999,Prec);
              end;

        'S' : begin
                if CheckArg(vtString,false) then
                  hs:=Args[doarg].VString^
                else
                  if CheckArg(vtChar,false) then
                    hs:=Args[doarg].VChar
                else
                  if CheckArg(vtPChar,false) then
                    hs:=Args[doarg].VPChar
                else
                  if CheckArg(vtPWideChar,false) then
                    hs:=WideString(Args[doarg].VPWideChar)
                else
                  if CheckArg(vtWideChar,false) then
                    hs:=WideString(Args[doarg].VWideChar)
                else
                  if CheckArg(vtWidestring,false) then
                    hs:=WideString(Args[doarg].VWideString)
                else
                  if CheckArg(vtAnsiString,true) then
                    hs:=ansistring(Args[doarg].VAnsiString);
                Index:=Length(hs);
                If (Prec<>-1) and (Index>Prec) then
                  Index:=Prec;
                ToAdd:=Copy(hs,1,Index);
              end;

        'P' : Begin
                CheckArg(vtpointer,true);
                ToAdd:=HexStr(TIntPtr(Args[DoArg].VPointer),sizeof(TIntPtr)*2);
              end;

        'X' : begin
                if Checkarg(vtinteger,false) then
                   begin
                     vq := Cardinal(Args[Doarg].VInteger);
                     index := 16;
                   end
                else
               {$ifdef bFreePascal}
                   if CheckArg(vtQWord, false) then
                     begin
                       vq := Args[DoArg].VQWord^;
                       index := 31;
                     end
                else
               {$endif bFreePascal}
                   begin
                     CheckArg(vtInt64,true);
                     vq := Args[DoArg].VInt64^;
                     index := 31;
                   end;

                If Prec>index then
                  ToAdd:=HexStr(int64(vq),index)
                else begin
                  // determine minimum needed number of hex digits.
                  Index:=1;
                  While (qWord(1) shl (Index*4)<=vq) and (index<16) do
                    inc(Index);
                  If Index>Prec then
                    Prec:=Index;
                  ToAdd:=HexStr(int64(vq),Prec);
                end;
              end;

        '%': ToAdd:='%';
      end;

      If Width<>-1 then
        If Length(ToAdd) < Width then
          If not Left then
            ToAdd := Space(Width-Length(ToAdd)) + ToAdd
          else
            ToAdd := ToAdd + Space(Width-Length(ToAdd));

      Result:=Result+ToAdd;

    end; {if}
    inc(ChPos);
    Oldpos:=ChPos;
  end;
end;


Function FloatToStrF(Value: Extended; format: TFloatFormat; Precision, Digits: Integer): String;
begin
  {!!!}
(*Result := FloatToStrF(Value,Format,Precision,Digits,DefaultFormatSettings);*)
  Result := '';
end;



initialization
  FormatFunc := Format;
end.






