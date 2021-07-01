{%mainunit testallform.pp}
{
 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 51 Franklin Street - Fifth Floor, Boston, MA 02110-1335, USA.   *
 *                                                                         *
 ***************************************************************************
}

{
  Common types, consts, functions and procedures that are not part of
  the TForm
}
const
  AppTitle = 'Test Many (but not all) Components';
  AboutMsg = 'A little test suite to test many (but not all) components' + LineEnding +
             'of Lazarus.' + LineEnding + LineEnding +
             'This test suite aims neither to be complete, nor to be free of bugs.' + LineEnding +
             LineEnding +
             'Feel free to report bugs and other shortcomings on the Lazarus bugtracker.';
type
  taComponents = (
    tacTarrow,
    tacTbitbtn,
    tacTbutton,
    tacTbuttonpanel,
    tacTcalcedit,
    tacTcalendar,
    tacTcheckbox,
    tacTcheckcombobox,
    tacTcheckgroup,
    tacTchecklistbox,
    tacTcolorbox,
    tacTcolorbutton,
    tacTcolorlistbox,
    tacTcombobox,
    tacTcomboboxex,
    tacTcontrolbar,
    tacTcoolbar,
    tacTdateedit,
    tacTdirectoryedit,
    tacTedit,
    tacTeditbutton,
    tacTfilelistbox,
    tacTfilenameedit,
    tacTfiltercombobox,
    tacTfloatspinedit,
    tacTgroupbox,
    tacTheadercontrol,
    tacTimage,
    tacTlabel,
    tacTlabelededit,
    tacTlistbox,
    tacTlistview,
    tacTmaskedit,
    tacTmemo,
    tacTnotebook,
    tacTpagecontrol,
    tacTpaintbox,
    tacTpanel,
    tacTprogressbar,
    tacTradiobutton,
    tacTradiogroup,
    tacTshape,
    tacTshelllistview,
    tacTshelltreeview,
    tacTspeedbutton,
    tacTspinedit,
    tacTsplitter,
    tacTstacTictext,
    tacTstatusbar,
    tacTstringgrid,
    tacTtabcontrol,
    tacTtimeedit,
    tacTtimer,
    tacTtogglebox,
    tacTtoolbar,
    tacTtrackbar,
    tacTtreeview,
    tacTupdown,
    tacTvaluelisteditor
  );

  taDialogs = (
    tadTcalculatordialog,
    tadTcalendardialog,
    tadTcolordialog,
    tadTfinddialog,
    tadTfontdialog,
    tadTMessageDialog,
    tadTopendialog,
    tadTopenpicturedialog,
    tadTreplacedialog,
    tadTsavedialog,
    tadTsavepicturedialog,
    tadTselectdirectorydialog,
    tadTQuestionDialog
    );

const
  tagCompStart = $1000;
  tagDlgStart  = $10000;

  taCompImplemented: Array[taComponents] of Boolean = (
    True, //tacTarrow,
    True, //tacTbitbtn,
    True, //tacTbutton,
    True, //tacTbuttonpanel,
    False, //tacTcalcedit,
    False, //tacTcalendar,
    False, //tacTcheckbox,
    False, //tacTcheckcombobox,
    False, //tacTcheckgroup,
    False, //tacTchecklistbox,
    False, //tacTcolorbox,
    False, //tacTcolorbutton,
    False, //tacTcolorlistbox,
    False, //tacTcombobox,
    False, //tacTcomboboxex,
    False, //tacTcontrolbar,
    False, //tacTcoolbar,
    False, //tacTdateedit,
    False, //tacTdirectoryedit,
    False, //tacTedit,
    False, //tacTeditbutton,
    False, //tacTfilelistbox,
    False, //tacTfilenameedit,
    False, //tacTfiltercombobox,
    False, //tacTfloatspinedit,
    False, //tacTgroupbox,
    False, //tacTheadercontrol,
    False, //tacTimage,
    False, //tacTlabel,
    False, //tacTlabelededit,
    False, //tacTlistbox,
    False, //tacTlistview,
    False, //tacTmaskedit,
    False, //tacTmemo,
    False, //tacTnotebook,
    False, //tacTpagecontrol,
    False, //tacTpaintbox,
    False, //tacTpanel,
    False, //tacTprogressbar,
    False, //tacTradiobutton,
    False, //tacTradiogroup,
    False, //tacTshape,
    False, //tacTshelllistview,
    False, //tacTshelltreeview,
    False, //tacTspeedbutton,
    False, //tacTspinedit,
    False, //tacTsplitter,
    False, //tacTstacTictext,
    False, //tacTstatusbar,
    False, //tacTstringgrid,
    False, //tacTtabcontrol,
    False, //tacTtimeedit,
    False, //tacTtimer,
    False, //tacTtogglebox,
    False, //tacTtoolbar,
    False, //tacTtrackbar,
    False, //tacTtreeview,
    False, //tacTupdown,
    False  //tacTvaluelisteditor,
    );

  taDlgImplemented: Array[taDialogs] of Boolean = (
    False, //tadTcalculatordialog,
    False, //tadTcalendardialog,
    False, //tadTcolordialog,
    False, //tadTfinddialog,
    False, //tadTfontdialog,
    True, //tadTMessageDialog,
    False, //tadTopendialog,
    False, //tadTopenpicturedialog,
    False, //tadTreplacedialog,
    False, //tadTsavedialog,
    False, //tadTsavepicturedialog,
    True, //tadTselectdirectorydialog,
    True //tadTQuestionDialog
  );

  taCompNames: Array[taComponents] of String = (
    'Tarrow',
    'Tbitbtn',
    'Tbutton',
    'Tbuttonpanel',
    'Tcalcedit',
    'Tcalendar',
    'Tcheckbox',
    'Tcheckcombobox',
    'Tcheckgroup',
    'Tchecklistbox',
    'Tcolorbox',
    'Tcolorbutton',
    'Tcolorlistbox',
    'Tcombobox',
    'Tcomboboxex',
    'Tcontrolbar',
    'Tcoolbar',
    'Tdateedit',
    'Tdirectoryedit',
    'Tedit',
    'Teditbutton',
    'Tfilelistbox',
    'Tfilenameedit',
    'Tfiltercombobox',
    'Tfloatspinedit',
    'Tgroupbox',
    'Theadercontrol',
    'Timage',
    'Tlabel',
    'Tlabelededit',
    'Tlistbox',
    'Tlistview',
    'Tmaskedit',
    'Tmemo',
    'Tnotebook',
    'Tpagecontrol',
    'Tpaintbox',
    'Tpanel',
    'Tprogressbar',
    'Tradiobutton',
    'Tradiogroup',
    'Tshape',
    'Tshelllistview',
    'Tshelltreeview',
    'Tspeedbutton',
    'Tspinedit',
    'Tsplitter',
    'TstacTictext',
    'Tstatusbar',
    'Tstringgrid',
    'Ttabcontrol',
    'Ttimeedit',
    'Ttimer',
    'Ttogglebox',
    'Ttoolbar',
    'Ttrackbar',
    'Ttreeview',
    'Tupdown',
    'Tvaluelisteditor'
    );

    taDlgNames: Array[taDialogs] of String = (
      'CalculatorDialog',
      'CalendarDialog',
      'ColorDialog',
      'FindDialog',
      'FontDialog',
      'MessageDialog',
      'OpenDialog',
      'OpenpictureDialog',
      'ReplaceDialog',
      'SaveDialog',
      'SavepictureDialog',
      'SelectdirectoryDialog',
      'QuestionDialog'
  );

function VkToString(Key: Word): String;
begin
  Result := DbgsVKCode(Key);
  if (Pos('(', Result) > 0) and (Pos(')', Result) > 0) then
    Result := '$' + IntToHex(Key,4);
end;

