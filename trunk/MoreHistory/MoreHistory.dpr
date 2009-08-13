{$I Defines.inc}

{$APPTYPE CONSOLE}
{$ifdef bDelphi}
 {$ImageBase $40800000}
{$endif bDelphi}

library MoreHistory;

uses
  MixErrors,
 {$ifdef bTrace}
  MixCheck,
 {$endif bTrace}
  MoreHistoryMain;

exports
 {$ifdef bUnicodeFar}
  GetMinFarVersionW,
  SetStartupInfoW,
  GetPluginInfoW,
  OpenPluginW,
  ExitFARW;
 {$else}
  SetStartupInfo,
  GetPluginInfo,
  OpenPlugin,
  ExitFAR;
 {$endif bUnicodeFar}


{$ifdef bUnicodeFar}
 {$R MoreHistoryW.res}
{$else}
 {$R MoreHistoryA.res}
{$endif bUnicodeFar}

end.
