{------------------------------------------------------------------------------}

{$Define bUnicode}       { Ansi-������ ���������� Unicode-������ }

{$Define bThumbnail}     { ���������� Explorer Thumbnail }

{$ifdef bUnicodeFar}
 {$Define bSynchroCall}  { ����� ����� ����� ProcessSynchroEventW }
{$endif bUnicodeFar}

{$ifdef bTrace}
 {$define bTrace1}
{$endif bTrace}

{------------------------------------------------------------------------------}
