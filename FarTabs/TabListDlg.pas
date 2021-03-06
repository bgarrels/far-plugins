{******************************************************************************}
{* (c) 2009-2013 Max Rusov                                                    *}
{*                                                                            *}
{* PanelTabs Far plugin                                                       *}
{******************************************************************************}

{$I Defines.inc}

unit TabListDlg;

interface

  uses
    Windows,
    MixTypes,
    MixUtils,
    MixStrings,

    Far_API,
    FarCtrl,
    FarDlg,
    FarGrid,
    FarListDlg,
    PanelTabsCtrl,
    PanelTabsClasses,
    EditTabDlg;


  type
    TTabsList = class(TFarListDlg)
    public
      constructor Create; override;

    protected
      procedure Prepare; override;
      procedure InitDialog; override;
      function CloseDialog(ItemID :Integer) :Boolean; override;

      function KeyDown(AID :Integer; AKey :Integer) :Boolean; override;

      procedure SelectItem(ACode :Integer); virtual;
      procedure ReInitGrid; virtual;

      procedure GridCellClick(ASender :TFarGrid; ACol, ARow :Integer; AButton :Integer; ADouble :Boolean); virtual;
      function GridGetDlgText(ASender :TFarGrid; ACol, ARow :Integer) :TString; virtual;
      procedure GridPaintCell(ASender :TFarGrid; X, Y, AWidth :Integer; ACol, ARow :Integer; AColor :TFarColor); virtual;

    protected
      FTabs           :TPanelTabs;
      FHotkeyColor1   :TFarColor;
      FHotkeyColor2   :TFarColor;
      FResInd         :Integer;
      FResCmd         :Integer;
      FNeedStore      :Boolean;

      procedure EditCurrent;
    end;


  function ListTabDlg(ATabs :TPanelTabs; var AIndex :Integer) :Boolean;


{******************************************************************************}
{******************************} implementation {******************************}
{******************************************************************************}

  uses
    MixDebug;


 {-----------------------------------------------------------------------------}
 { TTabsList                                                                   }
 {-----------------------------------------------------------------------------}

  constructor TTabsList.Create; {override;}
  begin
    inherited Create;
    FHotkeyColor1 := FarGetColor(COL_MENUHIGHLIGHT);
    FHotkeyColor2 := FarGetColor(COL_MENUSELECTEDHIGHLIGHT);
  end;


  procedure TTabsList.Prepare; {override;}
  begin
    inherited Prepare;
    FHelpTopic := 'List';

    FGrid.OnCellClick := GridCellClick;
    FGrid.OnGetCellText := GridGetDlgText;
    FGrid.OnPaintCell := GridPaintCell;
    FGrid.Options := [goRowSelect, goWrapMode, goFollowMouse];
    FGrid.Columns.Clear;
    FGrid.Columns.Add( TColumnFormat.CreateEx('', '', 0, taLeftJustify, [coOwnerDraw, coColMargin], 1) );
    FGrid.Columns.Add( TColumnFormat.CreateEx('', '', 0, taLeftJustify, [coColMargin], 2) );
  end;


  procedure TTabsList.InitDialog; {override;}
  begin
    SendMsg(DM_SETMOUSEEVENTNOTIFY, 1, 0);
    SetText(IdFrame, GetMsg(strTabs));
    ReInitGrid;
    if FResInd <> -1 then
      SetCurrent(FResInd);
  end;


  function TTabsList.CloseDialog(ItemID :Integer) :Boolean; {override;}
  begin
    Result := inherited CloseDialog(ItemID);
    if FNeedStore then
      FTabs.StoreReg('');
  end;


  procedure TTabsList.ReInitGrid; {virtual;}
  var
    I, vMaxLen1, vMaxLen2 :Integer;
    vTab :TPanelTab;
  begin
    vMaxLen1 := 0; vMaxLen2 := 0;
    for I := 0 to FTabs.Count - 1 do begin
      vTab := FTabs[I];
      vMaxLen1 := IntMax(vMaxLen1, Length(vTab.GetTabCaption));
      vMaxLen2 := IntMax(vMaxLen2, Length(vTab.Folder));
    end;

    Inc(vMaxLen1, Length(Int2Str(FTabs.Count)) + 1);

    FGrid.Column[0].Width := vMaxLen1 + 2;
    FGrid.Column[1].Width := vMaxLen2 + 2;

    FMenuMaxWidth := vMaxLen1 + 2 + vMaxLen2 + 2 + 1;

    FGrid.ResetSize;
    FGrid.RowCount := FTabs.Count;
    SetCurrent(FGrid.CurRow);

    ResizeDialog;
  end;


  procedure TTabsList.GridCellClick(ASender :TFarGrid; ACol, ARow :Integer; AButton :Integer; ADouble :Boolean); {virtual;}
  begin
    if (AButton = 1) {and ADouble} then
      SelectItem(1)
    else
    if (AButton = 2) then
      EditCurrent;
  end;


  function TTabsList.GridGetDlgText(ASender :TFarGrid; ACol, ARow :Integer) :TString; {virtual;}
  var
    vTab :TPanelTab;
  begin
    Result := '';
    if ARow < FTabs.Count then begin
      vTab := FTabs[ARow];
      case ACol of
        0: {Result := Format('%d %s', [ARow + 1, vTab.Caption])};
        1: Result := vTab.Folder;
      end;
    end;
  end;


  procedure TTabsList.GridPaintCell(ASender :TFarGrid; X, Y, AWidth :Integer; ACol, ARow :Integer; AColor :TFarColor); {virtual;}
  var
    vTab :TPanelTab;
    vStr :TString;
    vColor :TFarColor;
  begin
    if ARow < FTabs.Count then begin
      vTab := FTabs[ARow];
      vStr := Format('%s %s', [IndexToChar(ARow), vTab.GetTabCaption]);

      if FGrid.CurRow = ARow then
        vColor := FHotkeyColor2
      else
        vColor := FHotkeyColor1;
      FGrid.DrawChrEx(X, Y, PTChar(vStr), AWidth, 0, 1, AColor, vColor);
    end;
  end;


  procedure TTabsList.SelectItem(ACode :Integer);  {virtual;}
  begin
    if FGrid.CurRow < FGrid.RowCount then begin
      FResInd := FGrid.CurRow;
      FResCmd := ACode;
      SendMsg(DM_CLOSE, -1, 0);
    end else
      Beep;
  end;


  procedure TTabsList.EditCurrent;
  begin
    if FGrid.CurRow < FGrid.RowCount then begin
      if EditTab(FTabs, FGrid.CurRow) then begin
//      FTabs.StoreReg('');
        FNeedStore := True;
        ReInitGrid;
      end;
    end else
      Beep;
  end;


  function TTabsList.KeyDown(AID :Integer; AKey :Integer) :Boolean; {override;}

    procedure LocInsert;
    var
      vIndex :Integer;
    begin
      vIndex := FGrid.CurRow;
      if vIndex < FGrid.RowCount then
        Inc(vIndex);
      if NewTab(FTabs, vIndex) then begin
//      FTabs.StoreReg('');
        FNeedStore := True;
        ReInitGrid;
        SetCurrent(vIndex);
      end;
    end;

    procedure LocDelete;
    begin
      if FGrid.CurRow < FGrid.RowCount then begin
        FTabs.Delete( FGrid.CurRow );
//      FTabs.StoreReg('');
        FNeedStore := True;
        ReInitGrid;
      end else
        Beep;
    end;

    procedure LocMove(ADelta :Integer);
    begin
      if (FGrid.CurRow < FGrid.RowCount) and (FGrid.CurRow + ADelta >= 0) and (FGrid.CurRow + ADelta < FGrid.RowCount) then begin
        FTabs.Move(FGrid.CurRow, FGrid.CurRow + ADelta);
//      FTabs.StoreReg('');
        FNeedStore := True;
        ReInitGrid;
        SetCurrent(FGrid.CurRow + ADelta);
      end else
        Beep;
    end;

    procedure LocHotkey(AIndex :Integer);
    begin
      if AIndex < FGrid.RowCount then begin
        SetCurrent(AIndex);
        SelectItem(1);
      end else
        Beep;
    end;

  var
    vIndex :Integer;
  begin
    Result := True;
    case AKey of
      KEY_ENTER:
        SelectItem(1);

      KEY_F4:
        EditCurrent;
      KEY_INS:
        LocInsert;
      KEY_DEL:
        LocDelete;

      KEY_CTRLUP:
        LocMove(-1);
      KEY_CTRLDOWN:
        LocMove(+1);

    else
      vIndex := VKeyToIndex(AKey);
      if vIndex <> -1 then
        LocHotkey(vIndex)
      else
        Result := inherited KeyDown(AID, AKey);
    end;
  end;


 {-----------------------------------------------------------------------------}
 {                                                                             }
 {-----------------------------------------------------------------------------}

  function ListTabDlg(ATabs :TPanelTabs; var AIndex :Integer) :Boolean;
  var
    vDlg :TTabsList;
  begin
    Result := False;
    vDlg := TTabsList.Create;
    try
      vDlg.FTabs := ATabs;
      vDlg.FResInd := AIndex;

      if vDlg.Run = -1 then
        Exit;

      case vDlg.FResCmd of
        1: AIndex := vDlg.FResInd;
      end;
      Result := True;

    finally
      FreeObj(vDlg);
    end;
  end;


end.

