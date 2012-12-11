{$I Defines.inc}

{$APPTYPE CONSOLE}
{$ifdef Debug}
 {$ImageBase $40500000}
{$endif Debug}

{******************************************************************************}
{* (c) 2008-2012 Max Rusov                                                    *}
{*                                                                            *}
{* PlugMenu Far Plugin                                                        *}
{******************************************************************************}

library PlugMenu;

{$I Defines1.inc}

uses
  MixErrors,
 {$ifdef bTrace}
  MixCheck,
 {$endif bTrace}
  FarPlug,
  PlugMenuMain;

exports
 {$ifdef Far3}
  GetGlobalInfoW,
 {$endif Far3}
  SetStartupInfoW,
  GetPluginInfoW,
 {$ifdef Far3}
  OpenW,
 {$else}
  OpenPluginW,
 {$endif Far3}
  ConfigureW,
  ProcessSynchroEventW,
  ExitFARW;

 {$ifdef bUnicode}
  {$R PlugMenuW.res}
 {$else}
  {$R PlugMenuA.res}
 {$endif bUnicode}

begin
  Plug := TPlugMenuPlug.Create;
end.
