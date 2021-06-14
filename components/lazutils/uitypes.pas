unit UITypes
{$IF FPC_FULLVERSION >= 30200}
deprecated 'Use System.UITypes instead (available since FPC 3.2.0)';

{$mode objfpc}{$H+}

interface

uses
  System.UITypes;

const
  mtWarning      = System.UITypes.TMsgDlgType.mtWarning;
  mtError        = System.UITypes.TMsgDlgType.mtError;
  mtInformation  = System.UITypes.TMsgDlgType.mtInformation;
  mtConfirmation = System.UITypes.TMsgDlgType.mtConfirmation;
  mtCustom       = System.UITypes.TMsgDlgType.mtCustom;

  mbYes      = System.UITypes.TMsgDlgBtn.mbYes;
  mbNo       = System.UITypes.TMsgDlgBtn.mbNo;
  mbOK       = System.UITypes.TMsgDlgBtn.mbOK;
  mbCancel   = System.UITypes.TMsgDlgBtn.mbCancel;
  mbAbort    = System.UITypes.TMsgDlgBtn.mbAbort;
  mbRetry    = System.UITypes.TMsgDlgBtn.mbRetry;
  mbIgnore   = System.UITypes.TMsgDlgBtn.mbIgnore;
  mbAll      = System.UITypes.TMsgDlgBtn.mbAll;
  mbNoToAll  = System.UITypes.TMsgDlgBtn.mbNoToAll;
  mbYesToAll = System.UITypes.TMsgDlgBtn.mbYesToAll;
  mbHelp     = System.UITypes.TMsgDlgBtn.mbHelp;
  mbClose    = System.UITypes.TMsgDlgBtn.mbClose;

type
  // Message dialog related
  TMsgDlgType    = System.UITypes.TMsgDlgType;
  TMsgDlgBtn     = System.UITypes.TMsgDlgBtn;
  TMsgDlgButtons = set of System.UITypes.TMsgDlgBtn;

  // ModalResult
  TModalResult = System.UITypes.TModalResult;
  PModalResult = System.UITypes.PModalResult;

const
  // Used for ModalResult
  mrNone = System.UITypes.mrNone;
  mrOK = System.UITypes.mrOK;
  mrCancel = System.UITypes.mrCancel;
  mrAbort = System.UITypes.mrAbort;
  mrRetry = System.UITypes.mrRetry;
  mrIgnore = System.UITypes.mrIgnore;
  mrYes = System.UITypes.mrYes;
  mrNo = System.UITypes.mrNo;
  mrAll = System.UITypes.mrAll;
  mrNoToAll = System.UITypes.mrNoToAll;
  mrYesToAll = System.UITypes.mrYesToAll;
  mrClose = System.UITypes.mrClose;
  mrLast = System.UITypes.mrLast;
{$ELSE}
;

{$mode objfpc}{$H+}

interface

type
  // Message dialog related
  TMsgDlgType    = (mtWarning, mtError, mtInformation, mtConfirmation, mtCustom);
  TMsgDlgBtn     = (mbYes, mbNo, mbOK, mbCancel, mbAbort, mbRetry, mbIgnore,
                    mbAll, mbNoToAll, mbYesToAll, mbHelp, mbClose);
  TMsgDlgButtons = set of TMsgDlgBtn;

  // ModalResult
  TModalResult = low(Integer)..high(Integer);
  PModalResult = ^TModalResult;

const
  // Used for ModalResult
  mrNone = 0;
  mrOK = mrNone + 1;
  mrCancel = mrNone + 2;
  mrAbort = mrNone + 3;
  mrRetry = mrNone + 4;
  mrIgnore = mrNone + 5;
  mrYes = mrNone + 6;
  mrNo = mrNone + 7;
  mrAll = mrNone + 8;
  mrNoToAll = mrNone + 9;
  mrYesToAll = mrNone + 10;
  mrClose = mrNone + 11;
  mrLast = mrClose;
{$ENDIF}

  // String representation of ModalResult values
  ModalResultStr: array[mrNone..mrLast] of shortstring = (
    'mrNone',
    'mrOk',
    'mrCancel',
    'mrAbort',
    'mrRetry',
    'mrIgnore',
    'mrYes',
    'mrNo',
    'mrAll',
    'mrNoToAll',
    'mrYesToAll',
    'mrClose');


implementation

end.

