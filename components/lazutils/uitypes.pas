unit UITypes deprecated 'Use System.UITypes instead (available since FPC 3.2.0)';

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

