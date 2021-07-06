{
 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

  Author: Mattias Gaertner

  Abstract:
    This units defines the property editors used by the object inspector.
    A Property Editor is the interface between a row of the object inspector
    and a property in the RTTI.
    For more information see the big comment part below.
}
unit PropEdits;

{$mode objfpc}{$H+}

// This unit contains a lot of base type conversions. Disable range checking.
{$R-}

interface

uses
  // RTL / FCL
  Classes, TypInfo, SysUtils, types, RtlConsts, variants, Contnrs, strutils, FGL,
  // LCL
  LCLType, LCLIntf, LCLProc, Forms, Controls, ButtonPanel, Graphics,
  StdCtrls, Buttons, Menus, ExtCtrls, ComCtrls, Dialogs, EditBtn, Grids, ValEdit,
  FileCtrl, PropertyStorage, Themes,
  // LazControls
  {$IFnDEF UseOINormalCheckBox} CheckBoxThemed, {$ENDIF}
  // LazUtils
  FileUtil, StringHashList, LazMethodList, LazLoggerBase, LazUtilities, LazStringUtils,
  GraphType, UITypes, FPCAdds, // for StrToQWord in older fpc versions
  // IdeIntf
  ObjInspStrConsts, PropEditUtils,
  // Forms with .lfm files
  FrmSelectProps, StringsPropEditDlg, KeyValPropEditDlg, CollectionPropEditForm,
  FileFilterPropEditor, PagesPropEditDlg, IDEWindowIntf;

const
  MaxIdentLength: Byte = 63;
  CheckBoxThemedLeftOffs = 3;

  {$IFDEF LCLCarbon}
  // LineFeed symbol (UTF8) to maintain linefeeds in multiline text for Carbon TEdit.
  // In Carbon, linefeeds get stripped from TEdit text, so we replace it temporary with
  // this symbol which displays correctly a LF symbol in the Object Inspector as well.
  LineFeedSymbolUTF8 = #226#144#138;
  {$ENDIF}

type

  TPersistentSelectionList = PropEditUtils.TPersistentSelectionList;
  // For backwards compatibility only. Use TGetStrProc directly.
  TGetStringProc = Classes.TGetStrProc;

{ TPropertyEditor
  Edits a property of a component, or list of components, selected into the
  Object Inspector. The property editor is created based on the type of the
  property being edited as determined by the types registered by
  RegisterPropertyEditor. The Object Inspector uses a TPropertyEditor
  for all modification to a property. GetName and GetValue are called to
  display the name and value of the property. SetValue is called whenever the
  user requests to change the value. Edit is called when the user
  double-clicks the property in the Object Inspector. GetValues is called when
  the drop-down list of a property is displayed. GetProperties is called when
  the property is expanded to show sub-properties. AllEqual is called to decide
  whether or not to display the value of the property when more than one
  component is selected.

  The following are methods that can be overridden to change the behavior of
  the property editor:

    Activate
      Called whenever the property becomes selected in the object inspector.
      This is potentially useful to allow certain property attributes to
      to only be determined whenever the property is selected in the object
      inspector. Only paSubProperties and paMultiSelect,returned from
      GetAttributes,need to be accurate before this method is called.
    Deactivate
      Called whenevr the property becomes unselected in the object inspector.
    AllEqual
      Called whenever there is more than one component selected. If this
      method returns true,GetValue is called,otherwise blank is displayed
      in the Object Inspector. This is called only when GetAttributes
      returns paMultiSelect.
    AutoFill
      Called to determine whether the values returned by GetValues can be
      selected incrementally in the Object Inspector. This is called only when
      GetAttributes returns paValueList.
    Edit
      Called when the '...' button is pressed or the property is double-clicked.
      This can,for example,bring up a dialog to allow the editing the
      component in some more meaningful fashion than by text (e.g. the Font
      property).
    GetAttributes
      Returns the information for use in the Object Inspector to be able to
      show the appropriate tools. GetAttributes returns a set of type
      TPropertyAttributes:
        paValueList:    The property editor can return an enumerated list of
                        values for the property. If GetValues calls Proc
                        with values then this attribute should be set. This
                        will cause the drop-down button to appear to the right
                        of the property in the Object Inspector.
        paSortList:     Object Inspector to sort the list returned by
                        GetValues.
        paPickList:     Usable together with paValueList. The text field is
                        readonly. The user can still select values from drop
                        list. Unless paReadOnly.
        paSubProperties:The property editor has sub-properties that will be
                        displayed indented and below the current property in
                        standard outline format. If GetProperties will
                        generate property objects then this attribute should
                        be set.
        paDynamicSubProps:The sub properties can change. All designer tools
                        (e.g. property editors, component editors) that change
                        the list should call UpdateListPropertyEditors, so that
                        the object inspector will reread the subproperties.
        paDialog:       Indicates that the Edit method will bring up a
                        dialog. This will cause the '...' button to be
                        displayed to the right of the property in the Object
                        Inspector.
        paMultiSelect:  Allows the property to be displayed when more than
                        one component is selected. Some properties are not
                        appropriate for multi-selection (e.g. the Name
                        property).
        paAutoUpdate:   Causes the SetValue method to be called on each
                        change made to the editor instead of after the change
                        has been approved (e.g. the Caption property).
        paReadOnly:     Value is not allowed to change. But if paDialog is set
                        a Dialog can change the value. This disables only the
                        edit and combobox in the object inspector.
        paRevertable:   Allows the property to be reverted to the original
                        value. Things that shouldn't be reverted are nested
                        properties (e.g. Fonts) and elements of a composite
                        property such as set element values.
        paFullWidthName:Tells the object inspector that the value does not
                        need to be rendered and as such the name should be
                        rendered the full width of the inspector.
        paVolatileSubProperties: Any change of property value causes any shown
                        subproperties to be recollected.
        paDisableSubProperties: All subproperties are readonly
                        (not even via Dialog).
        paReference:    property contains a reference to something else. When
                        used in conjunction with paSubProperties the referenced
                        object should be displayed as sub properties to this
                        property.
        paNotNestable:  Indicates that the property is not safe to show when
                        showing the properties of an expanded reference.

    GetComponent
      Returns the Index'th component being edited by this property editor. This
      is used to retrieve the components. A property editor can only refer to
      multiple components when paMultiSelect is returned from GetAttributes.
    GetEditLimit
      Returns the number of character the user is allowed to enter for the
      value. The inplace editor of the object inspector will be have its
      text limited set to the return value. By default this limit is 255.
    GetName
      Returns the name of the property. By default the value is retrieved
      from the type information with all underbars replaced by spaces. This
      should only be overridden if the name of the property is not the name
      that should appear in the Object Inspector.
    GetProperties
      Should be overridden to call PropertyProc for every sub-property (or
      nested property) of the property begin edited and passing a new
      TPropertyEditor for each sub-property. By default, PropertyProc is not
      called and no sub-properties are assumed. TClassPropertyEditor will pass a
      new property editor for each published property in a class.
      TSetPropertyEditor passes a new editor for each element in the set.
    GetPropType
      Returns the type information pointer for the property(s) being edited.
    GetValue
      Returns the string value of the property. By default this returns
      '(unknown)'. This should be overridden to return the appropriate value.
    GetValues
      Called when paValueList is returned in GetAttributes. Should call Proc
      for every value that is acceptable for this property. TEnumPropertyEditor
      will pass every element in the enumeration.
    Initialize
      Called after the property editor has been created but before it is used.
      Many times property editors are created and because they are not a common
      property across the entire selection they are thrown away. Initialize is
      called after it is determined the property editor is going to be used by
      the object inspector and not just thrown away.
    SetValue(Value)
      Called to set the value of the property. The property editor should be
      able to translate the string and call one of the SetXxxValue methods. If
      the string is not in the correct format or not an allowed value,the
      property editor should generate an exception describing the problem. Set
      value can ignore all changes and allow all editing of the property be
      accomplished through the Edit method (e.g. the Picture property).
    ListMeasureWidth(Value,Canvas,AWidth)
      This is called during the width calculation phase of the drop down list
      preparation.
    ListMeasureHeight(Value,Canvas,AHeight)
      This is called during the item/value height calculation phase of the drop
      down list's render. This is very similar to TListBox's OnMeasureItem,
      just slightly different parameters.
    ListDrawValue(Value,Canvas,Rect,Selected)
      This is called during the item/value render phase of the drop down list's
      render. This is very similar to TListBox's OnDrawItem, just slightly
      different parameters.
    PropMeasureHeight(Value,Canvas,AHeight)
      This is called during the item/property height calculation phase of the
      object inspectors rows render. This is very similar to TListBox's
      OnMeasureItem, just slightly different parameters.
    PropDrawName(Canvas,Rect,Selected)
      Called during the render of the name column of the property list. Its
      functionality is very similar to TListBox's OnDrawItem,but once again
      it has slightly different parameters.
    PropDrawValue(Canvas,Rect,Selected)
      Called during the render of the value column of the property list. Its
      functionality is similar to PropDrawName. If multiple items are selected
      and their values don't match this procedure will be passed an empty
      value.

  Properties and methods useful in creating new TPropertyEditor classes:

    Name property
      Returns the name of the property returned by GetName
    PrivateEditory property
      This is the configuration directory of lazarus.
      If the property editor needs auxiliary or state files (templates,
      examples, etc) they should be stored in this editory.
    Value property
      The current value,as a string,of the property as returned by GetValue.
    Modified
      Called to indicate the value of the property has been modified. Called
      automatically by the SetXxxValue methods. If you call a TProperty
      SetXxxValue method directly,you *must* call Modified as well.
    GetXxxValue
      Gets the value of the first property in the Properties property. Calls
      the appropriate TProperty GetXxxValue method to retrieve the value.
    SetXxxValue
      Sets the value of all the properties in the Properties property. Calls
      the approprate TProperty SetXxxxValue methods to set the value.
    GetVisualValue
      This function will return the displayable value of the property. If
      only one item is selected or all the multi-selected items have the same
      property value then this function will return the actual property value.
      Otherwise this function will return an empty string.}

  TPropertyAttribute=(
    paValueList,
    paPickList,
    paSubProperties,
    paDynamicSubProps,
    paDialog,
    paMultiSelect,
    paAutoUpdate,
    paSortList,
    paReadOnly,
    paRevertable,
    paFullWidthName,
    paVolatileSubProperties,
    paDisableSubProperties,
    paReference,
    paNotNestable,
    paCustomDrawn
    );
  TPropertyAttributes = set of TPropertyAttribute;

  TPropertyEditor = class;

  TInstProp = record
    Instance: TPersistent;
    PropInfo: PPropInfo;
    // ToDo: add list of parent instances, e.g. Label1.Font.Color: Font needs Label1
  end;
  PInstProp = ^TInstProp;

  TInstPropList = array[0..999999] of TInstProp;
  PInstPropList = ^TInstPropList;

  TGetPropEditProc = procedure(Prop: TPropertyEditor) of object;

  TPropEditDrawStateType = (pedsSelected, pedsFocused, pedsInEdit, pedsInComboList);
  TPropEditDrawState = set of TPropEditDrawStateType;
  
  TPropEditHint = (
    pehNone,
    pehTree,
    pehName,
    pehValue,
    pehEditButton
    );

  TPropertyEditorHook = class;

  { TPropertyEditor }

  TPropertyEditor = class
  private
    FOnSubPropertiesChanged: TNotifyEvent;
    FPropertyHook: TPropertyEditorHook;
    FOwnerComponent: TComponent;
    FPropCount: Integer;
    FPropList: PInstPropList;
  protected
    // Draw Checkbox for Boolean and Set element editors.
    function DrawCheckbox(ACanvas: TCanvas; const ARect: TRect; IsTrue: Boolean): TRect;
    function DrawCheckValue(ACanvas: TCanvas; const ARect: TRect;
      {%H-}AState: TPropEditDrawState; {%H-}IsTrue: Boolean): TRect;
    procedure DrawValue(const AValue: string; ACanvas:TCanvas; const ARect:TRect;
      {%H-}AState:TPropEditDrawState);
    function GetPrivateDirectory: ansistring;
  public
    constructor Create(Hook:TPropertyEditorHook; APropCount:Integer); virtual;
    destructor Destroy; override;
    procedure Activate; virtual;
    procedure Deactivate; virtual;
    function AllEqual: Boolean; virtual;
    function AutoFill: Boolean; virtual;
    // Called when clicking on OI property button or double clicking on value.
    procedure Edit; virtual;
    // Needed for method Contraints.OnChange etc.
    procedure Edit(AOwnerComponent: TComponent);
    procedure ShowValue; virtual; // called when Ctrl-Click on value
    function GetAttributes: TPropertyAttributes; virtual;
    function IsReadOnly: boolean; virtual;
    // For Delphi compatibility it is called GetComponent instead of GetPersistent
    function GetComponent(Index: Integer): TPersistent;
    function GetUnitName(Index: Integer = 0): string;
    function GetPropTypeUnitName(Index: Integer = 0): string;
    function GetPropertyPath(Index: integer = 0): string;// e.g. 'TForm1.Color'
    function GetEditLimit: Integer; virtual;
    function GetName: shortstring; virtual;
    procedure GetProperties({%H-}Proc: TGetPropEditProc); virtual;
    function GetPropType: PTypeInfo;
    function GetPropInfo: PPropInfo;
    function GetInstProp: PInstProp;
    function GetFloatValue: Extended;
    function GetFloatValueAt(Index: Integer): Extended;
    function GetInt64Value: Int64;
    function GetInt64ValueAt(Index: Integer): Int64;
    function GetIntfValue: IInterface;
    function GetIntfValueAt(Index: Integer): IInterface;
    function GetMethodValue: TMethod;
    function GetMethodValueAt(Index: Integer): TMethod;
    function GetOrdValue: Longint;
    function GetOrdValueAt(Index: Integer): Longint;
    function GetObjectValue: TObject;
    function GetObjectValue(MinClass: TClass): TObject;
    function GetObjectValueAt(Index: Integer): TObject;
    function GetObjectValueAt(Index: Integer; MinClass: TClass): TObject;
    function GetDefaultOrdValue: Longint;
    function GetSetValue(Brackets: boolean): AnsiString;
    function GetSetValueAt(Index: Integer; Brackets: boolean): AnsiString;
    function GetStrValue: AnsiString;
    function GetStrValueAt(Index: Integer): AnsiString;
    function GetVarValue: Variant;
    function GetVarValueAt(Index: Integer):Variant;
    function GetWideStrValue: WideString;
    function GetWideStrValueAt(Index: Integer): WideString;
    function GetUnicodeStrValue: UnicodeString;
    function GetUnicodeStrValueAt(Index: Integer): UnicodeString;
    function GetValue: ansistring; virtual;
    function GetHint({%H-}HintType: TPropEditHint; {%H-}x, {%H-}y: integer): string; virtual;
    function HasDefaultValue: Boolean;
    function HasStoredFunction: Boolean;
    function GetDefaultValue: ansistring; virtual;
    function CallStoredFunction: Boolean; virtual;
    function GetVisualValue: ansistring; virtual;
    procedure GetValues({%H-}Proc: TGetStrProc); virtual;
    procedure Initialize; virtual;
    procedure Revert; virtual;
    procedure RevertToInherited; virtual;
    procedure SetValue(const {%H-}NewValue: ansistring); virtual;
    procedure SetPropEntry(Index: Integer; AnInstance: TPersistent;
                           APropInfo: PPropInfo);
    procedure SetFloatValue(const NewValue: Extended);
    procedure SetMethodValue(const NewValue: TMethod);
    procedure SetInt64Value(const NewValue: Int64);
    procedure SetIntfValue(const NewValue: IInterface);
    procedure SetOrdValue(const NewValue: Longint);
    procedure SetPtrValue(const NewValue: Pointer);
    procedure SetStrValue(const NewValue: AnsiString);
    procedure SetWideStrValue(const NewValue: WideString);
    procedure SetUnicodeStrValue(const NewValue: UnicodeString);
    procedure SetVarValue(const NewValue: Variant);
    procedure Modified(PropName: ShortString = '');
    function ValueAvailable: Boolean;
    procedure ListMeasureWidth(const {%H-}AValue: ansistring; {%H-}Index: Integer;
                               {%H-}ACanvas: TCanvas; var {%H-}AWidth: Integer); virtual;
    procedure ListMeasureHeight(const AValue: ansistring; {%H-}Index: Integer;
                                ACanvas: TCanvas; var AHeight: Integer); virtual;
    procedure ListDrawValue(const AValue: ansistring; {%H-}Index: Integer;
                            ACanvas: TCanvas; const ARect: TRect;
                            {%H-}AState: TPropEditDrawState); virtual;
    procedure PropMeasureHeight(const {%H-}NewValue: ansistring;  {%H-}ACanvas: TCanvas;
                                var {%H-}AHeight: Integer); virtual;
    procedure PropDrawName(ACanvas: TCanvas; const ARect: TRect;
                           {%H-}AState: TPropEditDrawState); virtual;
    procedure PropDrawValue(ACanvas: TCanvas; const ARect: TRect;
                            {%H-}AState: TPropEditDrawState); virtual;
    procedure UpdateSubProperties; virtual;
    function SubPropertiesNeedsUpdate: boolean; virtual;
    function ValueIsStreamed: boolean; virtual;
    function IsRevertableToInherited: boolean; virtual;
    // These are used for the popup menu in OI
    function GetVerbCount: Integer; virtual;
    function GetVerb(Index: Integer): string; virtual;
    procedure PrepareItem({%H-}Index: Integer; const {%H-}AnItem: TMenuItem); virtual;
    procedure ExecuteVerb({%H-}Index: Integer); virtual;
  public
    property PropertyHook: TPropertyEditorHook read FPropertyHook;
    property PrivateDirectory: ansistring read GetPrivateDirectory;
    property PropCount: Integer read FPropCount;
    property FirstValue: ansistring read GetValue write SetValue;
    property OnSubPropertiesChanged: TNotifyEvent
                     read FOnSubPropertiesChanged write FOnSubPropertiesChanged;
  end;

  TPropertyEditorClass = class of TPropertyEditor;
  TPropertyEditorList = specialize TFPGObjectList<TPropertyEditor>;

{ THiddenPropertyEditor
  A property editor to hide a published property. If you can't unpublish it, hide it. }
  
  THiddenPropertyEditor = class(TPropertyEditor)
  end;

{ TOrdinalPropertyEditor
  The base class of all ordinal property editors. It establishes that ordinal
  properties are all equal if the GetOrdValue all return the same value and
  provide methods to retrieve the default value. }

  TOrdinalPropertyEditor = class(TPropertyEditor)
  public
    function AllEqual: Boolean; override;
    function GetEditLimit: Integer; override;
    function GetValue: ansistring; override;
    function GetDefaultValue: ansistring; override;
    function OrdValueToVisualValue(OrdValue: longint): string; virtual;
  end;

{ TIntegerPropertyEditor
  Default editor for all Longint properties and all subtypes of the Longint
  type (i.e. Integer, Word, 1..10, etc.). Restricts the value entered into
  the property to the range of the sub-type. }

  TIntegerPropertyEditor = class(TOrdinalPropertyEditor)
  public
    function OrdValueToVisualValue(OrdValue: longint): string; override;
    procedure SetValue(const NewValue: ansistring);  override;
  end;

{ TCharPropertyEditor
  Default editor for all Char properties and sub-types of Char (i.e. Char,
  'A'..'Z', etc.). }

  TCharPropertyEditor = class(TOrdinalPropertyEditor)
  public
    function OrdValueToVisualValue(OrdValue: longint): string; override;
    procedure SetValue(const NewValue: ansistring); override;
  end;

{ TEnumPropertyEditor
  The default property editor for all enumerated properties (e.g. TShape =
  (sCircle, sTriangle, sSquare), etc.). }

  TEnumPropertyEditor = class(TOrdinalPropertyEditor)
  private
    FInvalid: Boolean;
  public
    function GetAttributes: TPropertyAttributes; override;
    function OrdValueToVisualValue(OrdValue: longint): string; override;
    function GetVisualValue: ansistring; override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure SetValue(const NewValue: ansistring); override;
  end;

type
  { TBoolPropertyEditor
    Default property editor for all boolean properties }

  TBoolPropertyEditor = class(TEnumPropertyEditor)
  public
    function OrdValueToVisualValue(OrdValue: longint): string; override;
    function GetVisualValue: ansistring; override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure SetValue(const NewValue: ansistring); override;
    procedure PropDrawValue(ACanvas: TCanvas; const ARect: TRect;
                            AState: TPropEditDrawState); override;
  end;

{ TInt64PropertyEditor
  Default editor for all Int64 properties and all subtypes of Int64. }

  TInt64PropertyEditor = class(TPropertyEditor)
  public
    function AllEqual: Boolean; override;
    function GetEditLimit: Integer; override;
    function GetValue: ansistring; override;
    procedure SetValue(const NewValue: ansistring); override;
  end;

{ TQWordPropertyEditor
  Default editor for all QWord properties }

  TQWordPropertyEditor = class(TInt64PropertyEditor)
  public
    function GetValue: ansistring; override;
    procedure SetValue(const NewValue: ansistring); override;
  end;

{ TFloatPropertyEditor
  The default property editor for all floating point types (e.g. Float,
  Single, Double, etc.) }

  TFloatPropertyEditor = class(TPropertyEditor)
  public
    function AllEqual: Boolean; override;
    function FormatValue(const AValue: Extended): ansistring;
    function GetDefaultValue: ansistring; override;
    function GetValue: ansistring; override;
    procedure SetValue(const NewValue: ansistring); override;
  end;

{ TStringPropertyEditor
  The default property editor for all strings and sub types (e.g. string,
  string[20], etc.). }

  TStringPropertyEditor = class(TPropertyEditor)
  public
    function AllEqual: Boolean; override;
    function GetEditLimit: Integer; override;
    function GetValue: ansistring; override;
    procedure SetValue(const NewValue: ansistring); override;
  end;

{ TPasswordStringPropertyEditor
  The default property editor for string passwords}

  TPasswordStringPropertyEditor = class(TStringPropertyEditor)
  public
    function GetPassword: string; virtual;
    procedure PropDrawValue(ACanvas: TCanvas; const ARect: TRect;
      AState: TPropEditDrawState); override;
  end;

{ TWideStringPropertyEditor
  The default property editor for widestrings}

  TWideStringPropertyEditor = class(TPropertyEditor)
  public
    function AllEqual: Boolean; override;
    function GetValue: ansistring; override;
    procedure SetValue(const NewValue: ansistring); override;
  end;

{ TPasswordWideStringPropertyEditor
  The default property editor for widestring passwords}

  TPasswordWideStringPropertyEditor = class(TWideStringPropertyEditor)
  public
    function GetPassword: WideString; virtual;
    procedure PropDrawValue(ACanvas: TCanvas; const ARect: TRect;
      AState: TPropEditDrawState); override;
  end;

{ TUnicodeStringPropertyEditor
  The default property editor for unicodestrings}

  TUnicodeStringPropertyEditor = class(TPropertyEditor)
  public
    function AllEqual: Boolean; override;
    function GetValue: ansistring; override;
    procedure SetValue(const NewValue: ansistring); override;
  end;

{ TNestedPropertyEditor
  A property editor that uses the PropertyHook, PropList and PropCount.
  The constructor and destructor do not call inherited, but all derived classes
  should. This is useful for properties like the TSetElementPropertyEditor. }

  TNestedPropertyEditor = class(TPropertyEditor)
  private
    FParentEditor: TPropertyEditor;
  public
    constructor Create(Parent: TPropertyEditor); overload;
    destructor Destroy; override;
    property ParentEditor: TPropertyEditor read FParentEditor;
  end;

{ TSetElementPropertyEditor
  A property editor that edits an individual set element. GetName is
  changed to display the set element name instead of the property name and
  Get/SetValue is changed to reflect the individual element state. This
  editor is created by the TSetPropertyEditor editor. }

  TSetElementPropertyEditor = class(TNestedPropertyEditor)
  private
    FElement: Integer;
  public
    constructor Create(Parent: TPropertyEditor; AElement: Integer); overload;
    function AllEqual: Boolean; override;
    function GetAttributes: TPropertyAttributes; override;
    function GetName: shortstring; override;
    function GetValue: ansistring; override;
    function GetVerbCount: Integer; override;
    function GetVisualValue: ansistring; override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure SetValue(const NewValue: ansistring); override;
    function ValueIsStreamed: boolean; override;
    procedure PropDrawValue(ACanvas: TCanvas; const ARect: TRect;
                            AState: TPropEditDrawState); override;
   end;

{ TSetPropertyEditor
  Default property editor for all set properties. This editor does not edit
  the set directly but will display sub-properties for each element of the
  set. GetValue displays the value of the set in standard set syntax. }

  TSetPropertyEditor = class(TOrdinalPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
    function GetEditLimit: Integer; override;
    procedure GetProperties(Proc: TGetPropEditProc); override;
    procedure SetValue(const NewValue: ansistring); override;
    function OrdValueToVisualValue(OrdValue: longint): string; override;
  end;

{ TClassPropertyEditor
  Default property editor for all objects. Does not allow modifying the
  property but does display the class name of the object and will allow the
  editing of the object's properties as sub-properties of the property. }

  TClassPropertyEditor = class(TPropertyEditor)
  private
    FSubPropsTypeFilter: TTypeKinds;
    FSubPropsNameFilter: String;
    FHideClassName: Boolean;
    FSubProps: TObjectList;
    procedure ListSubProps(Prop: TPropertyEditor);
    procedure SetSubPropsTypeFilter(const AValue: TTypeKinds);
    function EditorFilter(const AEditor: TPropertyEditor): Boolean;
  protected
    function GetSelections: TPersistentSelectionList; virtual;
  public
    constructor Create(Hook: TPropertyEditorHook; APropCount: Integer); override;
    destructor Destroy; override;

    function ValueIsStreamed: boolean; override;
    function AllEqual: Boolean; override;
    function GetAttributes: TPropertyAttributes; override;
    procedure GetProperties(Proc: TGetPropEditProc); override;
    function GetValue: ansistring; override;

    property SubPropsTypeFilter: TTypeKinds
      read FSubPropsTypeFilter write SetSubPropsTypeFilter default tkAny;
    property SubPropsNameFilter: String
      read FSubPropsNameFilter write FSubPropsNameFilter;
    property HideClassName: Boolean read FHideClassName write FHideClassName;
  end;

{ TMethodPropertyEditor
  Property editor for all method properties. }

  TMethodPropertyEditor = class(TPropertyEditor)
  private
    function GetTrimmedEventName: shortstring;
  public
    function AllEqual: Boolean; override;
    procedure Edit; override;
    procedure ShowValue; override;
    function GetAttributes: TPropertyAttributes; override;
    function GetEditLimit: Integer; override;
    function GetValue: ansistring; override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure SetValue(const NewValue: ansistring); override;
    function GetFormMethodName: shortstring;
    class function GetDefaultMethodName(Root, Component: TComponent;
        const RootClassName, ComponentName, PropName: shortstring): shortstring;
  end;
  
{ TPersistentPropertyEditor
  A base editor for TPersistent. It does allow editing of the properties.
  It allows the user to set the value of this property to point to a component
  in any form or datamodule that is type compatible with the property being
  edited (e.g. the DataSource property). }

  TPersistentPropertyEditor = class(TClassPropertyEditor)
  private
    // Used in AllEqual of TComponentOneFormPropertyEditor and TComponentPropertyEditor.
    function ComponentsAllEqual: Boolean;
  protected
    function FilterFunc(const ATestEditor: TPropertyEditor): Boolean;
    function GetPersistentReference: TPersistent; virtual;
    function GetSelections: TPersistentSelectionList; override;
    function CheckNewValue({%H-}APersistent: TPersistent): boolean; virtual;
  public
    function AllEqual: Boolean; override;
    procedure Edit; override;
    function GetAttributes: TPropertyAttributes; override;
    function GetEditLimit: Integer; override;
    function GetValue: AnsiString; override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure SetValue(const NewValue: ansistring); override;
  end;

{ TComponentOneFormPropertyEditor
  An editor for TComponents. It allows the user to set the value of this
  property to point to a component in the same form that is type compatible
  with the property being edited (e.g. the ActiveControl property). }

  TComponentOneFormPropertyEditor = class(TPersistentPropertyEditor)
  protected
    fIgnoreClass: TControlClass;
  public
    function AllEqual: Boolean; override;
    procedure GetValues(Proc: TGetStrProc); override;
  end;

{ TCoolBarControlPropertyEditor -
  An editor for TComponents. It allows the user to set the value of this
  property to point to a component in the same form that is type compatible
  with the property being edited and is not a TCustomCoolBar
  (e.g. the TCoolBand.Control property).}

  TCoolBarControlPropertyEditor = class(TComponentOneFormPropertyEditor)
  public
    constructor Create(Hook: TPropertyEditorHook; APropCount: Integer); override;
  end;

{ TComponentPropertyEditor
  The default editor for TComponents. It allows the user to set the value of
  this property to point to a component in any form in the project that is
  type compatible with the property being edited. }

  TComponentPropertyEditor = class(TPersistentPropertyEditor)
  protected
    function GetComponentReference: TComponent; virtual;
  public
    function AllEqual: Boolean; override;
  end;

{ TInterfacePropertyEditor
  The default editor for interface references. It allows the user to set
  the value of this property to refer to an interface implemented by
  a component on the form (or via form linking) that is type compatible
  with the property being edited. }

  TInterfacePropertyEditor = class(TComponentPropertyEditor)
  private
  protected
    function GetComponent(const AInterface: IInterface): TComponent;
    function GetComponentReference: TComponent; override;
    function GetSelections: TPersistentSelectionList; override;
  public
    function AllEqual: Boolean; override;
    procedure Edit; override;
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure SetValue(const NewValue: string); override;
    function GetValue: AnsiString; override;
  end;

  { TNoteBookActiveControlPropertyEditor }

  TNoteBookActiveControlPropertyEditor = class(TComponentPropertyEditor)
  protected
    function CheckNewValue(APersistent: TPersistent): boolean; override;
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
  end;

  { TPagesPropertyEditor
    PropertyEditor editor for the TNoteBook.Pages properties.
    Brings up a dialog with a Memo for entering pages. }

  TPagesPropEditorDlg = class;

  TPagesPropertyEditor = class(TClassPropertyEditor)
  public
    procedure AssignItems(OldItmes, NewItems: TStrings);
    procedure Edit; override;
    function CreateDlg(s: TStrings): TPagesPropEditorDlg; virtual;
    function GetAttributes: TPropertyAttributes; override;
  end;

{ TComponentNamePropertyEditor
  Property editor for the Name property. It restricts the name property
  from being displayed when more than one component is selected. }

  TComponentNamePropertyEditor = class(TStringPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
    function GetEditLimit: Integer; override;
    function GetValue: ansistring; override;
    procedure SetValue(const NewValue: ansistring); override;
  end;

{ TDatePropertyEditor
  Property editor for date portion of TDateTime type. }

  TDatePropertyEditor = class(TPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
    function GetValue: string; override;
    procedure SetValue(const Value: string); override;
  end;

{ TTimePropertyEditor
  Property editor for time portion of TDateTime type. }

  TTimePropertyEditor = class(TPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
    function GetValue: string; override;
    procedure SetValue(const Value: string); override;
  end;

{ TDateTimePropertyEditor
  Edits both date and time data simultaneously  }

  TDateTimePropertyEditor = class(TPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
    function GetValue: string; override;
    procedure SetValue(const Value: string); override;
  end;

{ TVariantPropertyEditor }

  TVariantPropertyEditor = class(TPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
    function GetValue: string; override;
    procedure SetValue(const {%H-}Value: string); override;
    procedure GetProperties({%H-}Proc:TGetPropEditProc); override;
  end;

{ TModalResultPropertyEditor }

  TModalResultPropertyEditor = class(TIntegerPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
    function OrdValueToVisualValue(OrdValue: longint): string; override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure SetValue(const NewValue:ansistring); override;
  end;

{ TShortCutPropertyEditor
  Property editor the ShortCut property. Allows both typing in a short
  cut value or picking a short-cut value from a list. }

  TShortCutPropertyEditor = class(TOrdinalPropertyEditor)
  public
    procedure Edit; override;
    function GetAttributes: TPropertyAttributes; override;
    function OrdValueToVisualValue(OrdValue: longint): string; override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure SetValue(const Value: string); override;
  end;

{ TTabOrderPropertyEditor
  Property editor for the TabOrder property. Prevents the property from being
  displayed when more than one component is selected. }

  TTabOrderPropertyEditor = class(TIntegerPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
  end;
  

{ TCaptionPropertyEditor
  Property editor for the Caption and Text properties. Updates the value of
  the property for each change instead on when the property is approved. }

  TCaptionPropertyEditor = class(TStringPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
  end;


{ TMenuItemCaptionEditor
  MenuItem's Caption gets its own editor.
  It updates the MenuItem's name when it is turned into a separator. }

  TMenuItemCaptionEditor = class(TStringPropertyEditor)
  public
    procedure SetValue(const NewValue: ansistring); override;
  end;


{ TStringMultilinePropertyEditor
  PropertyEditor editor for a string property when the string can be
  multiline (e.g. TLabel.Caption, TControl.Hint).
  Brings up the dialog for entering text. }

  TStringMultilinePropertyEditor = class(TCaptionPropertyEditor)
  public
    procedure Edit; override;
    function GetAttributes: TPropertyAttributes; override;
  end;


{ TStringsPropertyEditor
  PropertyEditor editor for the TStrings properties.
  Brings up a dialog with a Memo for entering text. }
  
  TStringsPropEditorDlg = class;

  TStringsPropertyEditor = class(TClassPropertyEditor)
  public
    procedure Edit; override;
    function CreateDlg(s: TStrings): TStringsPropEditorDlg; virtual;
    function GetAttributes: TPropertyAttributes; override;
  end;


{ TValueListPropertyEditor
  PropertyEditor editor for the TStrings property of TValueListEditor.
  Brings up a dialog with a ValueListEditor for entering keys and values. }

  TKeyValPropEditorDlg = class;

  TValueListPropertyEditor = class(TClassPropertyEditor)
  public
    procedure Edit; override;
    function CreateDlg(s: TStrings): TKeyValPropEditorDlg; virtual;
    function GetAttributes: TPropertyAttributes; override;
  end;


{ TCursorPropertyEditor
  PropertyEditor editor for the TCursor properties.
  Displays cursor as constant name if exists, otherwise an integer. }

  TCursorPropertyEditor = class(TIntegerPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
    function OrdValueToVisualValue(OrdValue: longint): string; override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure SetValue(const NewValue: ansistring); override;
  end;
  
  
{ TFileNamePropertyEditor
  PropertyEditor editor for filename properties.
  Show an TOpenDialog on Edit. }

  TFileNamePropertyEditor = class(TStringPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure Edit; override;
    function GetFilter: String; virtual;
    function GetDialogOptions: TOpenOptions; virtual;
    function GetDialogTitle: string; virtual;
    function GetInitialDirectory: string; virtual;
    procedure SetFilename(const Filename: string); virtual;
    function CreateFileDialog: TOpenDialog; virtual;
  end;


{ TDirectoryPropertyEditor
  PropertyEditor editor for directory properties.
  Show an TSelectDirectoryDialog on Edit. }

  TDirectoryPropertyEditor = class(TFileNamePropertyEditor)
  public
    function CreateFileDialog: TOpenDialog; override;
  end;


{ TURLPropertyEditor
  PropertyEditor editor for URL properties.
  Show an TOpenDialog on Edit. }

  TURLPropertyEditor = class(TFileNamePropertyEditor)
  public
    procedure SetFilename(const Filename: string); override;
  end;


{ TURLDirectoryPropertyEditor
  PropertyEditor editor for URL properties.
  Show an TOpenDialog on Edit. }

  TURLDirectoryPropertyEditor = class(TURLPropertyEditor)
  public
    function CreateFileDialog: TOpenDialog; override;
  end;
  

{ TFileDlgFilterProperty
  PropertyEditor editor for TFileDialog filter properties.
  Show a dialog on Edit. }

  TFileDlgFilterProperty = class(TStringPropertyEditor)
  public
    function  GetAttributes: TPropertyAttributes; override;
    procedure Edit; override;
  end;


{ TSessionPropertiesPropertyEditor
  PropertyEditor editor for TControl.SessionProperties properties.
  Show a dialog on Edit. }

  TSessionPropertiesPropertyEditor = class(TStringPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure Edit; override;
  end;

  
{ TConstraintsPropertyEditor
  PropertyEditor editor for TControl.Constraints properties.
  Lets a user set the current size as constraints. }

  TConstraintsPropertyEditor = class(TClassPropertyEditor)
  public
    // These are used for the popup menu in OI
    function GetVerbCount: Integer; override;
    function GetVerb(Index: Integer): string; override;
    procedure PrepareItem(Index: Integer; const AnItem: TMenuItem); override;
    procedure ExecuteVerb(Index: Integer); override;
  end;


{ TListElementPropertyEditor
  A property editor for a single element of a TListPropertyEditor
  This editor simply redirects all methods to the TListPropertyEditor }
  TListPropertyEditor = class;

  TListElementPropertyEditor = class(TNestedPropertyEditor)
  private
    FIndex: integer;
    FList: TListPropertyEditor;
  public
    constructor Create(Parent: TListPropertyEditor; AnIndex: integer); overload;
    destructor Destroy; override;
    function GetAttributes: TPropertyAttributes; override;
    function GetName:shortstring; override;
    procedure GetProperties(Proc: TGetPropEditProc); override;
    function GetValue: ansistring; override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure SetValue(const NewValue: ansistring); override;
    property List: TListPropertyEditor read FList;
    property TheIndex: integer read FIndex;
  end;

{ TListPropertyEditor
  A property editor with dynamic sub properties representing a list of objects.
  The items are shown embedded in the OI and if the user presses the Edit button
  as extra window to select items, which are then shown in the OI.
  UNDER CONSTRUCTION by Mattias
  The problem with all properties is, that we don't get notified, when something
  changes. In this case, the list can change, which means the property editors
  for the list elements must be deleted or created.
  }

  TListPropertyEditor = class(TPropertyEditor)
  private
    FSaveElementLock: integer;
    FSubPropertiesChanged: boolean;
  protected
    procedure BeginSaveElement;
    procedure EndSaveElement;
    function IsSaving: boolean;
    property SaveElementLock: integer read FSaveElementLock;
  protected
    // methods and variables usable for descendent property editors:
    // MWE: hmm... don't like "public" objects
    // TODO: change this ?
    SavedList: TObject;
    SavedElements: TList;
    SavedPropertyEditors: TList;
    function ReadElementCount: integer; virtual;
    function ReadElement(Index: integer): TPersistent; virtual;
    function CreateElementPropEditor(
      Index: integer): TListElementPropertyEditor; virtual;
    procedure DoSaveElements; virtual;
    procedure FreeElementPropertyEditors; virtual;
    function GetElementAttributes(
      {%H-}Element: TListElementPropertyEditor): TPropertyAttributes; virtual;
    function GetElementName(
      {%H-}Element: TListElementPropertyEditor):shortstring; virtual;
    procedure GetElementProperties({%H-}Element: TListElementPropertyEditor;
      {%H-}Proc: TGetPropEditProc); virtual;
    function GetElementValue(
      {%H-}Element: TListElementPropertyEditor): ansistring; virtual;
    procedure GetElementValues({%H-}Element: TListElementPropertyEditor;
      {%H-}Proc: TGetStrProc); virtual;
    procedure SetElementValue({%H-}Element: TListElementPropertyEditor;
      {%H-}NewValue: ansistring); virtual;
  public
    constructor Create(Hook:TPropertyEditorHook; APropCount:Integer); override;
    destructor Destroy; override;
    function GetAttributes: TPropertyAttributes; override;
    function GetElementCount: integer;
    function GetElement(Index: integer): TPersistent;
    function GetElement(Element: TListElementPropertyEditor): TPersistent;
    function GetElementPropEditor(Index: integer): TListElementPropertyEditor;
    procedure GetProperties(Proc: TGetPropEditProc); override;
    function GetValue: AnsiString; override;
    procedure Initialize; override;
    procedure SaveElements;
    function SubPropertiesNeedsUpdate: boolean; override;
  end;

{ TCollectionPropertyEditor
  Default property editor for all TCollections, embedded in the OI
  UNDER CONSTRUCTION by Mattias}

  TCollectionPropertyEditor = class(TListPropertyEditor)
  private
  protected
    function ReadElementCount: integer; override;
    function ReadElement(Index: integer): TPersistent; override;
    function GetElementAttributes(
      {%H-}Element: TListElementPropertyEditor): TPropertyAttributes; override;
    function GetElementName(
      Element: TListElementPropertyEditor):shortstring; override;
    procedure GetElementProperties(Element: TListElementPropertyEditor;
      Proc: TGetPropEditProc); override;
    function GetElementValue(
      Element: TListElementPropertyEditor): ansistring; override;
    procedure GetElementValues(Element: TListElementPropertyEditor;
      Proc: TGetStrProc); override;
    procedure SetElementValue(Element: TListElementPropertyEditor;
      NewValue: ansistring); override;
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure Edit; override;
    class function ShowCollectionEditor(ACollection: TCollection; 
      OwnerPersistent: TPersistent; const PropName: String): TCustomForm; virtual;
  end;

  { TDisabledCollectionPropertyEditor }

  TDisabledCollectionPropertyEditor = class(TCollectionPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
  end;

  { TNoAddDeleteCollectionPropertyEditor }

  TNoAddDeleteCollectionPropertyEditor = class(TCollectionPropertyEditor)
  public
    class function ShowCollectionEditor(ACollection: TCollection;
      OwnerPersistent: TPersistent; const PropName: String): TCustomForm; override;
  end;

//==============================================================================
// Delphi Compatible Property Editor Classnames

type
  TOrdinalProperty =        TOrdinalPropertyEditor;
  TIntegerProperty =        TIntegerPropertyEditor;
  TCharProperty =           TCharPropertyEditor;
  TEnumProperty =           TEnumPropertyEditor;
  TBoolProperty =           TBoolPropertyEditor;
  TInt64Property =          TInt64PropertyEditor;
  TFloatProperty =          TFloatPropertyEditor;
  TStringProperty =         TStringPropertyEditor;
  TNestedProperty =         TNestedPropertyEditor;
  TSetElementProperty =     TSetElementPropertyEditor;
  TSetProperty =            TSetPropertyEditor;
  TClassProperty =          TClassPropertyEditor;
  TMethodProperty =         TMethodPropertyEditor;
  TComponentProperty =      TPersistentPropertyEditor;
  TComponentNameProperty =  TComponentNamePropertyEditor;
//  TImeNameProperty =        TImeNamePropertyEditor;
  TCursorProperty =         TCursorPropertyEditor;
  TModalResultProperty =    TModalResultPropertyEditor;
  TShortCutProperty =       TShortCutPropertyEditor;
//  TMPFilenameProperty =     TMPFilenamePropertyEditor;
  TTabOrderProperty =       TTabOrderPropertyEditor;
  TCaptionProperty =        TCaptionPropertyEditor;
  TDateProperty =           TDatePropertyEditor;
  TTimeProperty =           TTimePropertyEditor;
  TDateTimeProperty =       TDateTimePropertyEditor;


type
  TSelectionEditorAttribute = (
    seaFilterProperties
  );
  TSelectionEditorAttributes = set of TSelectionEditorAttribute;

  { TBaseSelectionEditor }

  TBaseSelectionEditor = class
    constructor Create({%H-}ADesigner: TIDesigner; {%H-}AHook: TPropertyEditorHook); virtual;
    function GetAttributes: TSelectionEditorAttributes; virtual; abstract;
    procedure FilterProperties(ASelection: TPersistentSelectionList; AProperties: TPropertyEditorList); virtual; abstract;
  end;

  TSelectionEditorClass = class of TBaseSelectionEditor;

  TSelectionEditorClassList = specialize TFPGList<TSelectionEditorClass>;

  { TSelectionEditor }

  TSelectionEditor = class(TBaseSelectionEditor)
  private
    FDesigner: TIDesigner;
    FHook: TPropertyEditorHook;
  public
    constructor Create(ADesigner: TIDesigner; AHook: TPropertyEditorHook); override;
    function GetAttributes: TSelectionEditorAttributes; override;
    procedure FilterProperties({%H-}ASelection: TPersistentSelectionList; {%H-}AProperties: TPropertyEditorList); override;
    property Designer: TIDesigner read FDesigner;
    property Hook: TPropertyEditorHook read FHook;
  end;


//==============================================================================

{ RegisterPropertyEditor
  Registers a new property editor for the given type.
  When a component is selected the Object Inspector will create a property
  editor for each of the component's properties. The property editor is created
  based on the type of the property. If, for example, the property type is an
  Integer, the property editor for Integer will be created (by default
  that would be TIntegerPropertyEditor). Most properties do not need specialized
  property editors.
  For example, if the property is an ordinal type the default property editor
  will restrict the range to the ordinal subtype range (e.g. a property of type
  TMyRange=1..10 will only allow values between 1 and 10 to be entered into the
  property). Enumerated types will display a drop-down list of all the
  enumerated values (e.g. TShapes = (sCircle,sSquare,sTriangle) will be edited
  by a drop-down list containing only sCircle,sSquare and sTriangle).
  A property editor needs only be created if default property editor or none of
  the existing property editors are sufficient to edit the property. This is
  typically because the property is an object.
  The registered types are looked up newest to oldest.
  This allows an existing property editor replaced by a custom property editor.

    PropertyEditorType
      The type information pointer returned by the TypeInfo built-in function
      (e.g. TypeInfo(TMyRange) or TypeInfo(TShapes)).

    PersistentClass
      Type of the persistent object to which to restrict this type editor. This
      parameter can be left nil which will mean this type editor applies to all
      properties of PropertyEditorType.

    PropertyEditorName
      The name of the property to which to restrict this type editor. This
      parameter is ignored if PersistentClass is nil. This parameter can be
      an empty string ('') which will mean that this editor applies to all
      properties of PropertyEditorType in PersistentClass.

    editorClass
      The class of the editor to be created whenever a property of the type
      passed in PropertyEditorTypeInfo is displayed in the Object Inspector.
      The class will be created by calling EditorClass.Create. }

procedure RegisterPropertyEditor(PropertyType: PTypeInfo;
  PersistentClass: TClass;  const PropertyName: shortstring;
  EditorClass: TPropertyEditorClass);

type
  TPropertyEditorMapperFunc=function(Obj: TPersistent;
    PropInfo: PPropInfo): TPropertyEditorClass;
const
  AllTypeKinds = [tkInteger..High(TTypeKind)];

procedure RegisterPropertyEditorMapper(Mapper:TPropertyEditorMapperFunc);

type
  TPropertyEditorFilterFunc =
    function(const ATestEditor: TPropertyEditor): Boolean of object;
  TPropInfoFilterFunc =
    function(const APropInfo: PPropInfo): Boolean of object;

procedure GetPersistentProperties(ASelection: TPersistentSelectionList;
  AFilter: TTypeKinds; AHook: TPropertyEditorHook; AProc: TGetPropEditProc;
  APropInfoFilterFunc: TPropInfoFilterFunc;
  AEditorFilterFunc: TPropertyEditorFilterFunc);

procedure GetPersistentProperties(ASelection: TPersistentSelectionList;
  AFilter: TTypeKinds; AHook: TPropertyEditorHook; AProc: TGetPropEditProc;
  AEditorFilterFunc: TPropertyEditorFilterFunc);

procedure GetPersistentProperties(AItem: TPersistent;
  AFilter: TTypeKinds; AHook: TPropertyEditorHook; AProc: TGetPropEditProc;
  AEditorFilterFunc: TPropertyEditorFilterFunc);

function GetEditorClass(PropInfo:PPropInfo; Obj: TPersistent): TPropertyEditorClass;

//==============================================================================

procedure RegisterSelectionEditor(AComponentClass: TComponentClass; AEditorClass: TSelectionEditorClass);
procedure GetSelectionEditorClasses(AComponent: TComponent; AEditorList: TSelectionEditorClassList);
procedure GetSelectionEditorClasses(ASelection: TPersistentSelectionList; AEditorList: TSelectionEditorClassList);

//==============================================================================

procedure RegisterListPropertyEditor(AnEditor: TListPropertyEditor);
procedure UnregisterListPropertyEditor(AnEditor: TListPropertyEditor);
procedure UpdateListPropertyEditors(AnObject: TObject);

type
  TSelectableComponentFlag = (
    scfWithoutRoot,
    scfWithoutInlineChilds
  );
  TSelectableComponentFlags = set of TSelectableComponentFlag;

procedure GetSelectableComponents(Root: TComponent;
  Flags: TSelectableComponentFlags; var ComponentList: TFPList);

//==============================================================================
{
  TPropertyEditorHook

  This is the interface for methods, components and objects handling of all
  property editors. Just create such thing and give it the object inspector.
}
type
  // lookup root
  TPropHookChangeLookupRoot = procedure of object;
  // methods
  TPropHookCreateMethod = function(const Name: ShortString; ATypeInfo: PTypeInfo;
      APersistent: TPersistent; const APropertyPath: string): TMethod of object;
  TPropHookGetMethodName = function(const Method: TMethod; CheckOwner: TObject;
      OrigLookupRoot: TPersistent): String of object;
  TPropHookGetCompatibleMethods = procedure(InstProp: PInstProp; const Proc: TGetStrProc) of object;
  TPropHookGetMethods = procedure(TypeData: PTypeData; Proc: TGetStrProc) of object;
  TPropHookCompatibleMethodExists = function(const Name: String; InstProp: PInstProp;
                 var MethodIsCompatible,MethodIsPublished,IdentIsMethod: boolean
                 ):boolean of object;
  TPropHookMethodExists = function(const Name: String; TypeData: PTypeData;
                 var MethodIsCompatible,MethodIsPublished,IdentIsMethod: boolean
                 ):boolean of object;
  TPropHookRenameMethod = procedure(const CurName, NewName: String) of object;
  TPropHookShowMethod = procedure(const Name: String) of object;
  TPropHookMethodFromAncestor = function(const Method:TMethod):boolean of object;
  TPropHookMethodFromLookupRoot = function(const Method:TMethod):boolean of object;
  TPropHookChainCall = procedure(const AMethodName, InstanceName,
                      InstanceMethod:ShortString; TypeData:PTypeData) of object;
  // components
  TPropHookGetComponent = function(const ComponentPath: String):TComponent of object;
  TPropHookGetComponentName = function(AComponent: TComponent):String of object;
  TPropHookGetComponentNames = procedure(TypeData: PTypeData;
                                         Proc: TGetStrProc) of object;
  TPropHookGetRootClassName = function:ShortString of object;
  TPropHookGetAncestorInstProp = function(const InstProp: TInstProp;
                            out AncestorInstProp: TInstProp): boolean of object;
  TPropHookAddClicked = function(ADesigner: TIDesigner;
                            MouseDownComponent: TComponent; Button: TMouseButton;
                            Shift: TShiftState; X, Y: Integer;
                            var AComponentClass: TComponentClass;
                            var NewParent: TComponent): boolean of object;
  TPropHookBeforeAddPersistent = function(Sender: TObject;
                                         APersistentClass: TPersistentClass;
                                         Parent: TPersistent): boolean of object;
  TPropHookComponentRenamed = procedure(AComponent: TComponent) of object;
  TPropHookPersistentAdded = procedure(APersistent: TPersistent; Select: boolean
                                      ) of object;
  TPropHookPersistentDel = procedure(APersistent: TPersistent) of object;
  TPropHookDeletePersistent = procedure(var APersistent: TPersistent) of object;
  TPropHookGetSelection = procedure(const ASelection: TPersistentSelectionList
                                             ) of object;
  TPropHookSetSelection = procedure(const ASelection: TPersistentSelectionList
                                             ) of object;
  TPropHookAddDependency = procedure(const AClass: TClass;
                                     const AnUnitName: shortstring) of object;
  // persistent objects
  TPropHookGetObject = function(const Name:ShortString):TPersistent of object;
  TPropHookGetObjectName = function(Instance:TPersistent):ShortString of object;
  TPropHookGetObjectNames = procedure(TypeData:PTypeData;
                                      Proc: TGetStrProc) of object;
  TPropHookObjectPropertyChanged = procedure(Sender: TObject;
                                             NewObject: TPersistent) of object;
  // modifing
  TPropHookModified = procedure(Sender: TObject) of object;
  TPropHookModifiedWithName = procedure(Sender: TObject; PropName: ShortString) of object;
  TPropHookRevert = procedure(Instance:TPersistent; PropInfo:PPropInfo) of object;
  TPropHookRefreshPropertyValues = procedure of object;
  // other
  TPropHookGetCheckboxForBoolean = procedure(var Value: Boolean) of object;

  TPropHookType = (
    // lookup root
    htChangeLookupRoot,
    // methods
    htCreateMethod,
    htGetMethodName,
    htGetCompatibleMethods,
    htGetMethods,
    htCompatibleMethodExists,
    htMethodExists,
    htRenameMethod,
    htShowMethod,
    htMethodFromAncestor,
    htMethodFromLookupRoot,
    htChainCall,
    // components
    htGetComponent,
    htGetComponentName,
    htGetComponentNames,
    htGetRootClassName,
    htGetAncestorInstProp,
    htAddClicked, // user selected a component class and clicked on a form to add a component
    htComponentRenamed,
    // persistent selection
    htBeforeAddPersistent,
    htPersistentAdded,
    htPersistentDeleting,
    htPersistentDeleted,
    htDeletePersistent,
    htGetSelectedPersistents,
    htSetSelectedPersistents,
    // persistent objects
    htGetObject,
    htGetObjectName,
    htGetObjectNames,
    htObjectPropertyChanged,
    // modifing
    htModified,
    htModifiedWithName,
    htRevert,
    htRefreshPropertyValues,
    // dependencies
    htAddDependency,
    // designer
    htDesignerMouseDown,
    htDesignerMouseUp,
    // other
    htGetCheckboxForBoolean
    );

  { TPropertyEditorHook }

  TPropertyEditorHook = class(TComponent)
  private
    FComponentPropertyOnlyDesign: boolean;
    FHandlers: array[TPropHookType] of TMethodList;
    // lookup root
    FLookupRoot: TPersistent;

    procedure SetLookupRoot(APersistent: TPersistent);
    procedure AddHandler(HookType: TPropHookType; const Handler: TMethod);
    procedure RemoveHandler(HookType: TPropHookType; const Handler: TMethod);
    function GetHandlerCount(HookType: TPropHookType): integer;
    function GetNextHandlerIndex(HookType: TPropHookType;
                                 var i: integer): boolean;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    GetPrivateDirectory: AnsiString;
    constructor Create; overload; deprecated 'Use Create(TComponent) instead';
    destructor Destroy; override;

    // lookup root
    property LookupRoot: TPersistent read FLookupRoot write SetLookupRoot;
    // methods
    function CreateMethod(const aName: ShortString; ATypeInfo:PTypeInfo;
                          APersistent: TPersistent;
                          const APropertyPath: string): TMethod;
    function GetMethodName(const Method: TMethod; PropOwner: TObject): String;
    procedure GetMethods(TypeData: PTypeData; const Proc: TGetStrProc);
    procedure GetCompatibleMethods(InstProp: PInstProp; const Proc: TGetStrProc);
    function MethodExists(const aName: String; TypeData: PTypeData;
      var MethodIsCompatible,MethodIsPublished,IdentIsMethod: boolean):boolean;
    function CompatibleMethodExists(const aName: String; InstProp: PInstProp;
      out MethodIsCompatible,MethodIsPublished,IdentIsMethod: boolean):boolean;
    procedure RenameMethod(const CurName, NewName: String);
    procedure ShowMethod(const aName: String);
    function MethodFromAncestor(const Method: TMethod): boolean;
    function MethodFromLookupRoot(const Method: TMethod): boolean;
    procedure ChainCall(const AMethodName, InstanceName,
                        InstanceMethod: ShortString;  TypeData: PTypeData);
    // components
    function GetComponent(const ComponentPath: string): TComponent;
    function GetComponentName(AComponent: TComponent): String;
    procedure GetComponentNames(TypeData: PTypeData; const Proc: TGetStrProc);
    function GetRootClassName: ShortString;
    function GetAncestorInstance(const InstProp: TInstProp;
                                 out AncestorInstProp: TInstProp): boolean;
    function AddClicked(ADesigner: TIDesigner;
                        MouseDownComponent: TComponent; Button: TMouseButton;
                        Shift: TShiftState; X, Y: Integer;
                        var AComponentClass: TComponentClass;
                        var NewParent: TComponent): boolean;
    function BeforeAddPersistent(Sender: TObject;
                                 APersistentClass: TPersistentClass;
                                 Parent: TPersistent): boolean;
    procedure ComponentRenamed(AComponent: TComponent);
    procedure PersistentAdded(APersistent: TPersistent; Select: boolean);
    procedure PersistentDeleting(APersistent: TPersistent);
    procedure PersistentDeleted(APersistent: TPersistent);
    procedure DeletePersistent(var APersistent: TPersistent);
    procedure GetSelection(const ASelection: TPersistentSelectionList);
    procedure SetSelection(const ASelection: TPersistentSelectionList);
    procedure Unselect(const APersistent: TPersistent);
    function IsSelected(const APersistent: TPersistent): boolean;
    procedure SelectOnlyThis(const APersistent: TPersistent);
    procedure DesignerMouseDown(Sender: TObject; Button: TMouseButton;
                        Shift: TShiftState; X, Y: Integer);
    procedure DesignerMouseUp(Sender: TObject; Button: TMouseButton;
                        Shift: TShiftState; X, Y: Integer);
    // persistent objects
    function GetObject(const aName: ShortString): TPersistent;
    function GetObjectName(Instance: TPersistent; AOwnerComp: TComponent): String;
    procedure GetObjectNames(TypeData: PTypeData; const Proc: TGetStrProc);
    procedure ObjectReferenceChanged(Sender: TObject; NewObject: TPersistent);
    // modifing
    procedure Modified(Sender: TObject; PropName: ShortString = '');
    procedure Revert(Instance: TPersistent; PropInfo: PPropInfo);
    procedure RefreshPropertyValues;
    property ComponentPropertyOnlyDesign: boolean read FComponentPropertyOnlyDesign write FComponentPropertyOnlyDesign;
    // dependencies
    procedure AddDependency(const AClass: TClass; const AnUnitname: shortstring);
    // other
    function GetCheckboxForBoolean: Boolean;
  public
    // Handlers
    procedure RemoveAllHandlersForObject(const HandlerObject: TObject);

    // lookup root
    procedure AddHandlerChangeLookupRoot(
                           const OnChangeLookupRoot: TPropHookChangeLookupRoot);
    procedure RemoveHandlerChangeLookupRoot(
                           const OnChangeLookupRoot: TPropHookChangeLookupRoot);
    // method events
    procedure AddHandlerCreateMethod(const OnCreateMethod: TPropHookCreateMethod);
    procedure RemoveHandlerCreateMethod(const OnCreateMethod: TPropHookCreateMethod);
    procedure AddHandlerGetMethodName(const OnGetMethodName: TPropHookGetMethodName);
    procedure RemoveHandlerGetMethodName(const OnGetMethodName: TPropHookGetMethodName);
    procedure AddHandlerGetCompatibleMethods(
                             const OnGetMethods: TPropHookGetCompatibleMethods);
    procedure RemoveHandlerGetCompatibleMethods(
                             const OnGetMethods: TPropHookGetCompatibleMethods);
    procedure AddHandlerGetMethods(const OnGetMethods: TPropHookGetMethods);
    procedure RemoveHandlerGetMethods(const OnGetMethods: TPropHookGetMethods);
    procedure AddHandlerCompatibleMethodExists(
                         const OnMethodExists: TPropHookCompatibleMethodExists);
    procedure RemoveHandlerCompatibleMethodExists(
                         const OnMethodExists: TPropHookCompatibleMethodExists);
    procedure AddHandlerMethodExists(const OnMethodExists: TPropHookMethodExists);
    procedure RemoveHandlerMethodExists(const OnMethodExists: TPropHookMethodExists);
    procedure AddHandlerRenameMethod(const OnRenameMethod: TPropHookRenameMethod);
    procedure RemoveHandlerRenameMethod(const OnRenameMethod: TPropHookRenameMethod);
    procedure AddHandlerShowMethod(const OnShowMethod: TPropHookShowMethod);
    procedure RemoveHandlerShowMethod(const OnShowMethod: TPropHookShowMethod);
    procedure AddHandlerMethodFromAncestor(
                       const OnMethodFromAncestor: TPropHookMethodFromAncestor);
    procedure RemoveHandlerMethodFromAncestor(
                       const OnMethodFromAncestor: TPropHookMethodFromAncestor);
    procedure AddHandlerMethodFromLookupRoot(
                       const OnMethodFromLookupRoot: TPropHookMethodFromLookupRoot);
    procedure RemoveHandlerMethodFromLookupRoot(
                       const OnMethodFromLookupRoot: TPropHookMethodFromLookupRoot);
    procedure AddHandlerChainCall(const OnChainCall: TPropHookChainCall);
    procedure RemoveHandlerChainCall(const OnChainCall: TPropHookChainCall);
    // component event
    procedure AddHandlerGetComponent(const OnGetComponent: TPropHookGetComponent);
    procedure RemoveHandlerGetComponent(const OnGetComponent: TPropHookGetComponent);
    procedure AddHandlerGetComponentName(
                           const OnGetComponentName: TPropHookGetComponentName);
    procedure RemoveHandlerGetComponentName(
                           const OnGetComponentName: TPropHookGetComponentName);
    procedure AddHandlerGetComponentNames(
                         const OnGetComponentNames: TPropHookGetComponentNames);
    procedure RemoveHandlerGetComponentNames(
                         const OnGetComponentNames: TPropHookGetComponentNames);
    procedure AddHandlerAddClicked(const Handler: TPropHookAddClicked);
    procedure RemoveHandlerAddClicked(const Handler: TPropHookAddClicked);
    procedure AddHandlerGetRootClassName(
                           const OnGetRootClassName: TPropHookGetRootClassName);
    procedure RemoveHandlerGetRootClassName(
                           const OnGetRootClassName: TPropHookGetRootClassName);
    procedure AddHandlerGetAncestorInstProp(
                     const OnGetAncestorInstProp: TPropHookGetAncestorInstProp);
    procedure RemoveHandlerGetAncestorInstProp(
                     const OnGetAncestorInstProp: TPropHookGetAncestorInstProp);
    procedure AddHandlerDesignerMouseDown(const OnMouseDown: TMouseEvent);
    procedure RemoveHandlerDesignerMouseDown(const OnMouseDown: TMouseEvent);
    procedure AddHandlerDesignerMouseUp(const OnMouseUp: TMouseEvent);
    procedure RemoveHandlerDesignerMouseUp(const OnMouseUp: TMouseEvent);
    // component create, delete, rename
    procedure AddHandlerComponentRenamed(
                           const OnComponentRenamed: TPropHookComponentRenamed);
    procedure RemoveHandlerComponentRenamed(
                           const OnComponentRenamed: TPropHookComponentRenamed);
    procedure AddHandlerBeforeAddPersistent(
                     const OnBeforeAddPersistent: TPropHookBeforeAddPersistent);
    procedure RemoveHandlerBeforeAddPersistent(
                     const OnBeforeAddPersistent: TPropHookBeforeAddPersistent);
    procedure AddHandlerPersistentAdded(
                             const OnPersistentAdded: TPropHookPersistentAdded);
    procedure RemoveHandlerPersistentAdded(
                             const OnPersistentAdded: TPropHookPersistentAdded);
    procedure AddHandlerPersistentDeleting(
                       const OnPersistentDeleting: TPropHookPersistentDel);
    procedure RemoveHandlerPersistentDeleting(
                       const OnPersistentDeleting: TPropHookPersistentDel);
    procedure AddHandlerPersistentDeleted(
                       const OnPersistentDeleted: TPropHookPersistentDel);
    procedure RemoveHandlerPersistentDeleted(
                       const OnPersistentDeleted: TPropHookPersistentDel);
    procedure AddHandlerDeletePersistent(
                           const OnDeletePersistent: TPropHookDeletePersistent);
    procedure RemoveHandlerDeletePersistent(
                           const OnDeletePersistent: TPropHookDeletePersistent);
    // persistent selection
    procedure AddHandlerGetSelection(const OnGetSelection: TPropHookGetSelection);
    procedure RemoveHandlerGetSelection(const OnGetSelection: TPropHookGetSelection);
    procedure AddHandlerSetSelection(const OnSetSelection: TPropHookSetSelection);
    procedure RemoveHandlerSetSelection(const OnSetSelection: TPropHookSetSelection);
    // persistent object events
    procedure AddHandlerGetObject(const OnGetObject: TPropHookGetObject);
    procedure RemoveHandlerGetObject(const OnGetObject: TPropHookGetObject);
    procedure AddHandlerGetObjectName(const OnGetObjectName: TPropHookGetObjectName);
    procedure RemoveHandlerGetObjectName(const OnGetObjectName: TPropHookGetObjectName);
    procedure AddHandlerGetObjectNames(const OnGetObjectNames: TPropHookGetObjectNames);
    procedure RemoveHandlerGetObjectNames(const OnGetObjectNames: TPropHookGetObjectNames);
    procedure AddHandlerObjectPropertyChanged(
                 const OnObjectPropertyChanged: TPropHookObjectPropertyChanged);
    procedure RemoveHandlerObjectPropertyChanged(
                 const OnObjectPropertyChanged: TPropHookObjectPropertyChanged);
    // modifing events
    procedure AddHandlerModified(const OnModified: TPropHookModified);
    procedure RemoveHandlerModified(const OnModified: TPropHookModified);
    procedure AddHandlerModifiedWithName(const OnModified: TPropHookModifiedWithName);
    procedure RemoveHandlerModifiedWithName(const OnModified: TPropHookModifiedWithName);
    procedure AddHandlerRevert(const OnRevert: TPropHookRevert);
    procedure RemoveHandlerRevert(const OnRevert: TPropHookRevert);
    procedure AddHandlerRefreshPropertyValues(
                 const OnRefreshPropertyValues: TPropHookRefreshPropertyValues);
    procedure RemoveHandlerRefreshPropertyValues(
                 const OnRefreshPropertyValues: TPropHookRefreshPropertyValues);
    procedure AddHandlerAddDependency(const OnAddDependency: TPropHookAddDependency);
    procedure RemoveHandlerAddDependency(const OnAddDependency: TPropHookAddDependency);
    procedure AddHandlerGetCheckboxForBoolean(
                 const OnGetCheckboxForBoolean: TPropHookGetCheckboxForBoolean);
  end;

//==============================================================================

{ TPropInfoList }

type
  TPropInfoList = class
  private
    FList: PPropList;
    FCount: Integer;
    FSize: Integer;
    function Get(Index: Integer): PPropInfo;
  public
    constructor Create(Instance: TPersistent; Filter: TTypeKinds);
    destructor Destroy; override;
    function Contains(P: PPropInfo): Boolean;
    procedure Delete(Index: Integer);
    procedure Intersect(List: TPropInfoList);
    procedure Sort;
    property Count: Integer read FCount;
    property Items[Index: Integer]: PPropInfo read Get; default;
  end;

//==============================================================================

type
  TStringsPropEditorDlg = class(TStringsPropEditorFrm)
  public
    Editor: TPropertyEditor;
  end;

  TKeyValPropEditorDlg = class(TKeyValPropEditorFrm)
  public
    Editor: TPropertyEditor;
  end;

  TPagesPropEditorDlg = class(TPagesPropEditorFrm)
  public
    Editor: TPropertyEditor;
  end;

  { TCustomShortCutGrabBox }

  TCustomShortCutGrabBox = class(TCustomPanel)
  private
    FAllowedShifts: TShiftState;
    FGrabButton: TButton;
    FMainOkButton: TCustomButton;
    FKey: Word;
    FKeyComboBox: TComboBox;
    FShiftButtons: TShiftState;
    FShiftState: TShiftState;
    FCheckBoxes: array[TShiftStateEnum] of TCheckBox;
    FGrabForm: TForm;
    function GetKey: Word;
    function GetShiftCheckBox(Shift: TShiftStateEnum): TCheckBox;
    procedure SetAllowedShifts(const AValue: TShiftState);
    procedure SetKey(const AValue: Word);
    procedure SetShiftButtons(const AValue: TShiftState);
    procedure SetShiftState(const AValue: TShiftState);
    procedure OnGrabButtonClick(Sender: TObject);
    procedure OnShiftCheckBoxClick(Sender: TObject);
    procedure OnGrabFormKeyDown(Sender: TObject; var AKey: Word; AShift: TShiftState);
    procedure OnKeyComboboxEditingDone(Sender: TObject);
  protected
    procedure Loaded; override;
    procedure RealSetText(const {%H-}Value: TCaption); override;
    procedure UpdateShiftButtons;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    function ShiftToStr(s: TShiftStateEnum): string;
  public
    constructor Create(TheOwner: TComponent); override;
    function GetDefaultShiftButtons: TShiftState;
    property ShiftState: TShiftState read FShiftState write SetShiftState;
    property Key: Word read GetKey write SetKey;
    property ShiftButtons: TShiftState read FShiftButtons write SetShiftButtons;
    property AllowedShifts: TShiftState read FAllowedShifts write SetAllowedShifts;
    property KeyComboBox: TComboBox read FKeyComboBox;
    property GrabButton: TButton read FGrabButton;
    property MainOkButton: TCustomButton read FMainOkButton write FMainOkButton;
    property ShiftCheckBox[Shift: TShiftStateEnum]: TCheckBox read GetShiftCheckBox;
  end;


  { TShortCutGrabBox }

  TShortCutGrabBox = class(TCustomShortCutGrabBox)
  published
    property Align;
    property Alignment;
    property AllowedShifts;
    property Anchors;
    property AutoSize;
    property BevelInner;
    property BevelOuter;
    property BevelWidth;
    property BorderSpacing;
    property BorderStyle;
    property BorderWidth;
    property Caption;
    property ChildSizing;
    property ClientHeight;
    property ClientWidth;
    property Color;
    property Constraints;
    property DockSite;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property FullRepaint;
    property Key;
    property OnClick;
    property OnDblClick;
    property OnDockDrop;
    property OnDockOver;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDock;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnGetDockCaption;
    property OnGetSiteInfo;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property OnStartDock;
    property OnStartDrag;
    property OnUnDock;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShiftButtons;
    property ShiftState;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property UseDockManager default True;
    property Visible;
  end;

//==============================================================================


// Global flags:
var
  GReferenceExpandable: Boolean = true;
  GShowReadOnlyProps: Boolean = true;

// default Hook - set by IDE
var
  GlobalDesignHook: TPropertyEditorHook;

function ClassTypeInfo(Value: TClass): PTypeInfo;
function GetClassUnitName(Value: TClass): string;
procedure CreateComponentEvent(AComponent: TComponent; const EventName: string);
function ClassNameToComponentName(const AClassName: string): string;
function ControlAcceptsStreamableChildComponent(aControl: TWinControl;
  aComponentClass: TComponentClass; aLookupRoot: TPersistent): boolean;

procedure LazSetMethodProp(Instance : TObject;PropInfo : PPropInfo; Value : TMethod);
procedure WritePublishedProperties(Instance: TPersistent);
procedure EditCollection(AComponent: TComponent; ACollection: TCollection; APropName: String);
procedure EditCollectionNoAddDel(AComponent: TComponent; ACollection: TCollection; APropName: String);

// Returns true if given property should be displayed on the property list
// filtered by AFilter and APropNameFilter.
function IsInteresting(AEditor: TPropertyEditor;
  const AFilter: TTypeKinds; const APropNameFilter: String): Boolean;

function dbgs(peh: TPropEditHint): string; overload;

const
  NoDefaultValue = Longint($80000000); // magic number for properties with nodefault modifier

implementation

var
  ListPropertyEditors: TList = nil;
  VirtualKeyStrings: TStringHashList = nil;

procedure RegisterListPropertyEditor(AnEditor: TListPropertyEditor);
begin
  if ListPropertyEditors=nil then
    ListPropertyEditors:=TList.Create;
  ListPropertyEditors.Add(AnEditor);
end;

procedure UnregisterListPropertyEditor(AnEditor: TListPropertyEditor);
begin
  if ListPropertyEditors=nil then exit;
  ListPropertyEditors.Remove(AnEditor);
end;

procedure UpdateListPropertyEditors(AnObject: TObject);
var
  i: integer;
  Editor: TListPropertyEditor;
begin
  if ListPropertyEditors=nil then exit;
  for i:=0 to ListPropertyEditors.Count-1 do begin
    Editor:=TListPropertyEditor(ListPropertyEditors[i]);
    if (Editor.GetComponent(0)=AnObject)
    and (Editor.OnSubPropertiesChanged<>nil) then
      Editor.UpdateSubProperties;
  end;
end;

type

  { TSelectableComponentEnumerator }

  TSelectableComponentEnumerator = class(TComponent)
  public
    List: TFPList;
    Flags: TSelectableComponentFlags;
    Root: TComponent;
    procedure GetSelectableComponents(ARoot: TComponent);
    procedure Gather(Child: TComponent);
  end;

{ TSelectionEditor }

constructor TSelectionEditor.Create(ADesigner: TIDesigner;
  AHook: TPropertyEditorHook);
begin
  inherited Create(ADesigner, AHook);
  FDesigner := ADesigner;
  FHook := AHook;
end;

function TSelectionEditor.GetAttributes: TSelectionEditorAttributes;
begin
  Result := [];
end;

procedure TSelectionEditor.FilterProperties(
  ASelection: TPersistentSelectionList; AProperties: TPropertyEditorList);
begin

end;

{ TBaseSelectionEditor }

constructor TBaseSelectionEditor.Create(ADesigner: TIDesigner;
  AHook: TPropertyEditorHook);
begin

end;

{ TPagesPropertyEditor }

procedure TPagesPropertyEditor.AssignItems(OldItmes, NewItems: TStrings);
var
  Unchanged, Index, PageIndex: Integer;
  DummyNotebook: TNotebook;
  APage: TPage;
  PageComponent: TPersistent;
  NoteBook: TNoteBook;
begin
  // search for unchanged pages
  Unchanged := 0;
  while (Unchanged < NewItems.Count) and (Unchanged < OldItmes.Count)
  and (NewItems.Objects[Unchanged] = OldItmes.Objects[Unchanged])
  and (NewItems[Unchanged] = TPage(OldItmes.Objects[Unchanged]).Name) do
    Inc(Unchanged);
  if (Unchanged = OldItmes.Count) and (Unchanged = NewItems.Count) then Exit;

  NoteBook := TNotebook(FOwnerComponent);
  DummyNotebook := TNotebook.Create(nil);
  try
    // move all unused/changed pages to dummy
    for Index := OldItmes.Count - 1 downto Unchanged do
    begin
      APage := TPage(OldItmes.Objects[Index]);
      APage.Parent := DummyNotebook;
    end;

    // add NewItems or changed pages to notebook
    for Index := Unchanged to NewItems.Count - 1 do
    begin
      if Assigned(NewItems.Objects[Index]) then begin
        APage := TPage(NewItems.Objects[Index]);
      end else begin
        PageIndex := NoteBook.Pages.Add(NewItems[Index]);
        APage := TPage(NoteBook.Pages.Objects[PageIndex]);
      end;
      APage.Parent := NoteBook;
      if IsValidIdent(NewItems[Index]) then APage.Name := NewItems[Index];
      APage.Caption := NewItems[Index];
      PropertyHook.PersistentAdded(APage, False);
    end;

    // delete all unused OldItmes pages
    for Index := DummyNotebook.PageCount - 1 downto 0 do
    begin
      APage := TPage(DummyNotebook.Pages.Objects[Index]);
      APage.Parent := nil;;
      DummyNotebook.Pages.Delete(Index);
      PageComponent := TPersistent(APage);
      PropertyHook.DeletePersistent(PageComponent);
    end;
  finally
    DummyNotebook.Free;
  end;
end;

procedure TPagesPropertyEditor.Edit;
var
  TheDialog: TPagesPropEditorDlg;
  Old, New: TStrings;
begin
  Old := TStrings(GetObjectValue);
  TheDialog := CreateDlg(Old);
  try
    if (TheDialog.ShowModal = mrOK) then begin
      New := TheDialog.ListBox.Items;
      AssignItems(Old, TheDialog.ListBox.Items);
      SetPtrValue(New);
    end;
  finally
    TheDialog.Free;
  end;
end;

function TPagesPropertyEditor.CreateDlg(s: TStrings): TPagesPropEditorDlg;
begin
  Result := TPagesPropEditorDlg.Create(Application);
  Result.Editor := Self;
  Result.ListBox.Items.Assign(s);
end;

function TPagesPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paDialog, paRevertable, paReadOnly];
end;

{ TSelectableComponentEnumerator }

procedure TSelectableComponentEnumerator.GetSelectableComponents(
  ARoot: TComponent);
begin
  Root:=ARoot;
  if List=nil then
    List:=TFPList.Create;
  if Root=nil then exit;
  if not (scfWithoutRoot in Flags) then List.Add(Root);
  TSelectableComponentEnumerator(Root).GetChildren(@Gather,Root);
end;

procedure TSelectableComponentEnumerator.Gather(Child: TComponent);
var
  OldRoot: TComponent;
begin
  if not ((Child is TControl)
          and (csNoDesignSelectable in TControl(Child).ControlStyle))
  then
    List.Add(Child);
  OldRoot:=Root;
  try
    if csInline in Child.ComponentState then begin
      if scfWithoutInlineChilds in Flags then exit;
      if (Child is TControl)
      and (csOwnedChildrenNotSelectable in TControl(Child).ControlStyle) then
        exit;
      Root:=Child;
    end;
    TSelectableComponentEnumerator(Child).GetChildren(@Gather,Root);
  finally
    Root:=OldRoot;
  end;
end;

procedure GetSelectableComponents(Root: TComponent;
  Flags: TSelectableComponentFlags; var ComponentList: TFPList);
var
  e: TSelectableComponentEnumerator;
begin
  e:=TSelectableComponentEnumerator.Create(nil);
  try
    e.List:=ComponentList;
    e.Flags:=Flags;
    e.GetSelectableComponents(Root);
    ComponentList:=e.List;
  finally
    e.Free;
  end;
end;

procedure LazSetMethodProp(Instance: TObject; PropInfo: PPropInfo;
  Value: TMethod);
type
  PMethod = ^TMethod;
  TSetMethodProcIndex=procedure(index:longint;p:TMethod) of object;
  TSetMethodProc=procedure(p:TMethod) of object;
var
  AMethod : TMethod;
begin
  case (PropInfo^.PropProcs shr 2) and 3 of
    ptfield:
      PMethod(Pointer(Instance)+{%H-}PtrUInt(PropInfo^.SetProc))^ := Value;
    ptstatic,
    ptvirtual :
      begin
        if ((PropInfo^.PropProcs shr 2) and 3)=ptStatic then
          AMethod.Code:=PropInfo^.SetProc
        else
          AMethod.Code:=PPointer(Pointer(Instance.ClassType)+{%H-}PtrUInt(PropInfo^.SetProc))^;
        AMethod.Data:=Instance;
        if (Value.Code=nil) and (Value.Data<>nil) then begin
          // this is a fake method
          // Comparing fake methods with OldValue=NewValue results always in
          // true. Therefore this will fail:
          //   if FMethod=NewValue then exit;
          //   FMethod:=NewValue;
          // Change the method two times
          try
            Value.Code:=Pointer(1);
            if ((PropInfo^.PropProcs shr 6) and 1)<>0 then
              TSetMethodProcIndex(AMethod)(PropInfo^.Index,Value)
            else
              TSetMethodProc(AMethod)(Value);
          except
          end;
          Value.Code:=nil;
        end;
        if ((PropInfo^.PropProcs shr 6) and 1)<>0 then
          TSetMethodProcIndex(AMethod)(PropInfo^.Index,Value)
        else
          TSetMethodProc(AMethod)(Value);
      end;
  end;
end;

// -----------------------------------------------------------

procedure WritePublishedProperties(Instance: TPersistent);
var
  TypeInfo: PTypeInfo;
  TypeData: PTypeData;
  PropInfo: PPropInfo;
  PropData: ^TPropData;
  CurCount: integer;
begin
  TypeInfo:=Instance.ClassInfo;
  TypeData:=GetTypeData(TypeInfo);
  debugln('WritePublishedProperties Instance=',DbgS(Instance),' ',Instance.ClassName,' TypeData^.PropCount=',dbgs(TypeData^.PropCount));
  if Instance is TComponent then
    debugln('  TComponent(Instance).Name=',TComponent(Instance).Name);

  // read all properties and remove doubles
  TypeInfo:=Instance.ClassInfo;
  repeat
    // read all property infos of current class
    TypeData:=GetTypeData(TypeInfo);
    // skip unitname
    PropData:=AlignToPtr(PByte(@TypeData^.UnitName)+Length(TypeData^.UnitName)+1);
    // read property count
    CurCount:=PWord(PropData)^;
    PropInfo:=PPropInfo(@PropData^.PropList);
    debugln('    UnitName=',TypeData^.UnitName,' Type=',TypeInfo^.Name,' CurPropCount=',dbgs(CurCount));

    {writeln('TPropInfoList.Create D ',CurCount,' TypeData^.ClassType=',DbgS(TypeData^.ClassType));
    writeln('TPropInfoList.Create E ClassName="',TypeData^.ClassType.ClassName,'"',
    ' TypeInfo=',DbgS(TypeInfo),
    ' TypeData^.ClassType.ClassInfo=',DbgS(TypeData^.ClassType.ClassInfo),
    ' TypeData^.ClassType.ClassParent=',DbgS(TypeData^.ClassType.ClassParent),
    ' TypeData^.ParentInfo=',DbgS(TypeData^.ParentInfo),
    '');
    CurParent:=TypeData^.ClassType.ClassParent;
    if CurParent<>nil then begin
      writeln('TPropInfoList.Create F CurParent.ClassName=',CurParent.ClassName,
        ' CurParent.ClassInfo=',DbgS(CurParent.ClassInfo),
        '');
    end;}

    // read properties
    while CurCount>0 do begin
      // point PropInfo to next propinfo record.
      // Located at Name[Length(Name)+1] !
      debugln('      Property ',PropInfo^.Name,' Type=',PropInfo^.PropType^.Name);
      PropInfo:=PPropInfo(AlignToPtr(pointer(@PropInfo^.Name)+PByte(@PropInfo^.Name)^+1));
      dec(CurCount);
    end;
    TypeInfo:=TypeData^.ParentInfo;
    if TypeInfo=nil then break;
  until false;
end;


//------------------------------------------------------------------------------

const
{ TypeKinds  see typinfo.pp
       TTypeKind = (tkUnknown,tkInteger,tkChar,tkEnumeration,tkFloat,
                   tkSet,tkMethod,tkSString,tkLString,tkAString,
                   tkWString,tkVariant,tkArray,tkRecord,tkInterface,
                   tkClass,tkObject,tkWChar,tkBool,tkInt64,tkQWord,
                   tkDynArray,tkInterfaceRaw,tkProcVar,tkUString,tkUChar,
                   tkHelper);
}

  PropClassMap:array[TypInfo.TTypeKind] of TPropertyEditorClass=(
    nil,                       // tkUnknown
    TIntegerPropertyEditor,    // tkInteger
    TCharpropertyEditor,       // tkChar
    TEnumPropertyEditor,       // tkEnumeration
    TFloatPropertyEditor,      // tkFloat
    TSetPropertyEditor,        // tkSet
    TMethodPropertyEditor,     // tkMethod
    TStringPropertyEditor,     // tkSString
    TStringPropertyEditor,     // tkLString
    TStringPropertyEditor,     // tkAString
    TWideStringPropertyEditor, // tkWString
    TPropertyEditor,           // tkVariant
    nil,                       // tkArray
    nil,                       // tkRecord
    TInterfacePropertyEditor,  // tkInterface
    TClassPropertyEditor,      // tkClass
    nil,                       // tkObject
    TPropertyEditor,           // tkWChar
    TBoolPropertyEditor,       // tkBool
    TInt64PropertyEditor,      // tkInt64
    TQWordPropertyEditor,      // tkQWord
    nil,                       // tkDynArray
    nil,                       // tkInterfaceRaw,
    nil,                       // tkProcVar
    TUnicodeStringPropertyEditor,// tkUString
    nil                        // tkUChar
{$IF declared(tkHelper)}
    ,nil                       // tkHelper
{$ENDIF}
{$IF declared(tkFile)}
    ,nil                       // tkFile
{$ENDIF}
{$IF declared(tkClassRef)}
    ,nil                       // tkClassRef
{$ENDIF}
{$IF declared(tkPointer)}
    ,nil                       // tkPointer
{$ENDIF}
    );

var
  PropertyEditorMapperList:TFPList;
  PropertyClassList:TFPList;
  SelectionEditorClassList:TFPList;

type
  PPropertyClassRec=^TPropertyClassRec;
  TPropertyClassRec=record
    PropertyType:PTypeInfo;
    PropertyName:shortstring;
    PersistentClass:TClass;
    EditorClass:TPropertyEditorClass;
  end;

  PPropertyEditorMapperRec=^TPropertyEditorMapperRec;
  TPropertyEditorMapperRec=record
    Mapper:TPropertyEditorMapperFunc;
  end;

  PSelectionEditorClassRec=^TSelectionEditorClassRec;
  TSelectionEditorClassRec=record
    ComponentClass:TComponentClass;
    EditorClass:TSelectionEditorClass;
  end;

{ TPropInfoList }

constructor TPropInfoList.Create(Instance:TPersistent; Filter:TTypeKinds);
var
  BigList: PPropList;
  TypeInfo: PTypeInfo;
  TypeData: PTypeData;
  PropInfo: PPropInfo;
  PropData: ^TPropData;
  CurCount, i: integer;
  //CurParent: TClass;
begin
  TypeInfo:=Instance.ClassInfo;
  TypeData:=GetTypeData(TypeInfo);
  GetMem(BigList,TypeData^.PropCount * SizeOf(Pointer));

  // read all properties and remove doubles
  TypeInfo:=Instance.ClassInfo;
  FCount:=0;
  repeat
    // read all property infos of current class
    TypeData:=GetTypeData(TypeInfo);
    // skip unitname
    PropData:=AlignToPtr(Pointer(@TypeData^.UnitName)+Length(TypeData^.UnitName)+1);
    // read property count
    CurCount:=PropData^.PropCount;
    PropInfo:=PPropInfo(@PropData^.PropList);

    {writeln('TPropInfoList.Create D ',CurCount,' TypeData^.ClassType=',DbgS(TypeData^.ClassType));
    writeln('TPropInfoList.Create E ClassName="',TypeData^.ClassType.ClassName,'"',
    ' TypeInfo=',DbgS(TypeInfo),
    ' TypeData^.ClassType.ClassInfo=',DbgS(TypeData^.ClassType.ClassInfo),
    ' TypeData^.ClassType.ClassParent=',DbgS(TypeData^.ClassType.ClassParent),
    ' TypeData^.ParentInfo=',DbgS(TypeData^.ParentInfo),
    '');
    CurParent:=TypeData^.ClassType.ClassParent;
    if CurParent<>nil then begin
      writeln('TPropInfoList.Create F CurParent.ClassName=',CurParent.ClassName,
        ' CurParent.ClassInfo=',DbgS(CurParent.ClassInfo),
        '');
    end;}

    // read properties
    while CurCount>0 do begin
      if PropInfo^.PropType^.Kind in Filter then begin
        // check if name already exists in list
        i:=FCount-1;
        while (i>=0) and (CompareText(BigList^[i]^.Name,PropInfo^.Name)<>0) do
          dec(i);
        if (i<0) then begin
          // add property info to BigList
          BigList^[FCount]:=PropInfo;
          inc(FCount);
        end;
      end;
      // point PropInfo to next propinfo record.
      // Located at Name[Length(Name)+1] !
      PropInfo:=PPropInfo(AlignToPtr(pointer(@PropInfo^.Name)+PByte(@PropInfo^.Name)^+1));
      dec(CurCount);
    end;
    TypeInfo:=TypeData^.ParentInfo;
    if TypeInfo=nil then break;
  until false;

  // create FList
  FSize:=FCount * SizeOf(Pointer);
  GetMem(FList,FSize);
  Move(BigList^,FList^,FSize);
  FreeMem(BigList);
  Sort;
end;

destructor TPropInfoList.Destroy;
begin
  if FList<>nil then FreeMem(FList,FSize);
end;

function TPropInfoList.Contains(P:PPropInfo):Boolean;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
  begin
    with FList^[I]^ do
    begin
      if (PropType^.Kind=P^.PropType^.Kind) and (CompareText(Name,P^.Name)=0) then
      begin
        Result := True;
        Exit;
      end;
    end;
  end;
  Result := False;
end;

procedure TPropInfoList.Delete(Index:Integer);
begin
  Dec(FCount);
  if Index < FCount then
    Move(FList^[Index+1],FList^[Index],
      (FCount-Index) * SizeOf(Pointer));
end;

function TPropInfoList.Get(Index:Integer):PPropInfo;
begin
  Result:=FList^[Index];
end;

procedure TPropInfoList.Intersect(List:TPropInfoList);
var
  I:Integer;
begin
  for I:=FCount-1 downto 0 do
    if not List.Contains(FList^[I]) then Delete(I);
end;

procedure TPropInfoList.Sort;
  procedure QuickSort(L, R: Integer);
  var
    I, J: Longint;
    P, Q: PPropInfo;
  begin
    repeat
      I := L;
      J := R;
      P := FList^[(L + R) div 2];
      repeat
        while CompareText(P^.Name, FList^[i]^.Name) > 0 do
          inc(I);
        while CompareText(P^.Name, FList^[J]^.Name) < 0 do
          dec(J);
        if I <= J then
        begin
          Q := FList^[I];
          Flist^[I] := FList^[J];
          FList^[J] := Q;
          inc(I);
          dec(J);
        end;
      until I > J;
      if L < J then
        QuickSort(L, J);
      L := I;
    until I >= R;
  end;
begin
  if Count > 0 then
    QuickSort(0, Count - 1);
end;

//------------------------------------------------------------------------------

procedure RegisterSelectionEditor(AComponentClass: TComponentClass; AEditorClass: TSelectionEditorClass);
var
  p:PSelectionEditorClassRec;
begin
  if not Assigned(AComponentClass) or not Assigned(AEditorClass) then
    Exit;
  if not Assigned(SelectionEditorClassList) then
    SelectionEditorClassList:=TFPList.Create;
  New(p);
  p^.ComponentClass:=AComponentClass;
  p^.EditorClass:=AEditorClass;
  SelectionEditorClassList.Add(p);
end;

procedure GetSelectionEditorClasses(AComponent: TComponent; AEditorList: TSelectionEditorClassList);
var
  i:LongInt;
begin
  if not Assigned(AComponent) or not Assigned(AEditorList) then
    Exit;
  if not Assigned(SelectionEditorClassList) then
    Exit;
  for i:=0 to SelectionEditorClassList.Count-1 do begin
    with PSelectionEditorClassRec(SelectionEditorClassList[i])^ do begin
      if AComponent.InheritsFrom(ComponentClass) then
        AEditorList.Add(EditorClass);
    end;
  end;
end;

procedure GetSelectionEditorClasses(ASelection: TPersistentSelectionList;
  AEditorList: TSelectionEditorClassList);
var
  tmp:TSelectionEditorClassList;
  i,j:LongInt;
  sel:TPersistent;
begin
  if not Assigned(ASelection) or (ASelection.Count=0) or not Assigned(AEditorList) then
    Exit;

  tmp:=TSelectionEditorClassList.Create;
  try
    for i:=0 to ASelection.Count-1 do begin
      sel:=ASelection[i];
      if not (sel is TComponent) then
        Continue;
      GetSelectionEditorClasses(TComponent(sel),tmp);
      { if there are no classes yet, we pick them as is, otherwise we remove all
        those from the existing list that are not part of the new list }
      if AEditorList.Count=0 then
        AEditorList.Assign(tmp)
      else begin
        for j:=AEditorList.Count-1 downto 0 do begin
          if tmp.IndexOf(AEditorList[j])<0 then
            AEditorList.Delete(j);
        end;
      end;
      tmp.Clear;
    end;
  finally
    tmp.Free;
  end;
end;

{ GetComponentProperties }

procedure RegisterPropertyEditor(PropertyType:PTypeInfo;
  PersistentClass: TClass;  const PropertyName:shortstring;
  EditorClass:TPropertyEditorClass);
var
  P:PPropertyClassRec;
begin
  if PropertyType=nil then exit;
  if PropertyClassList=nil then
    PropertyClassList:=TFPList.Create;
  New(P);
  P^.PropertyType:=PropertyType;
  P^.PersistentClass:=PersistentClass;
  P^.PropertyName:=PropertyName;
  P^.EditorClass:=EditorClass;
  PropertyClassList.Insert(0,P);
end;

procedure RegisterPropertyEditorMapper(Mapper:TPropertyEditorMapperFunc);
var
  P:PPropertyEditorMapperRec;
begin
  if PropertyEditorMapperList=nil then
    PropertyEditorMapperList:=TFPList.Create;
  New(P);
  P^.Mapper:=Mapper;
  PropertyEditorMapperList.Insert(0,P);
end;

function GetEditorClass(PropInfo:PPropInfo; Obj:TPersistent): TPropertyEditorClass;
var
  PropType:PTypeInfo;
  P,C:PPropertyClassRec;
  I:Integer;
begin
  Result := nil;
  if PropertyEditorMapperList<>nil then begin
    for I:=0 to PropertyEditorMapperList.Count-1 do begin
      with PPropertyEditorMapperRec(PropertyEditorMapperList[I])^ do begin
        Result:=Mapper(Obj,PropInfo);
        if Result<>nil then break;
      end;
    end;
  end;
  if Result=nil then begin
    PropType:=PropInfo^.PropType;
    I:=0;
    C:=nil;
    while I < PropertyClassList.Count do begin
      P:=PropertyClassList[I];

      if ((P^.PropertyType=PropType) or
           ((P^.PropertyType^.Kind=PropType^.Kind) and
            (P^.PropertyType^.Name=PropType^.Name)
           )
         ) or
         ( (PropType^.Kind=tkClass) and
           (P^.PropertyType^.Kind=tkClass) and
           GetTypeData(PropType)^.ClassType.InheritsFrom(
             GetTypeData(P^.PropertyType)^.ClassType)
         )
      then
        if ((P^.PersistentClass=nil) or (Obj.InheritsFrom(P^.PersistentClass))) and
           ((P^.PropertyName='')
           or (CompareText(PropInfo^.Name,P^.PropertyName)=0))
        then
          if (C=nil) or   // see if P is better match than C
             ((C^.PersistentClass=nil) and (P^.PersistentClass<>nil)) or
             ((C^.PropertyName='') and (P^.PropertyName<>''))
             or  // P's proptype match is exact,but C's does not
             ((C^.PropertyType<>PropType) and (P^.PropertyType=PropType))
             or  // P's proptype is more specific than C's proptype
             ((P^.PropertyType<>C^.PropertyType) and
              (P^.PropertyType^.Kind=tkClass) and
              (C^.PropertyType^.Kind=tkClass) and
              GetTypeData(P^.PropertyType)^.ClassType.InheritsFrom(
                GetTypeData(C^.PropertyType)^.ClassType))
             or // P's component class is more specific than C's component class
             ((P^.PersistentClass<>nil) and (C^.PersistentClass<>nil) and
              (P^.PersistentClass<>C^.PersistentClass) and
              (P^.PersistentClass.InheritsFrom(C^.PersistentClass)))
          then
            C:=P;
      Inc(I);
    end;
    if C<>nil then
      Result:=C^.EditorClass
    else begin
      if (PropType^.Kind<>tkClass)
      or (GetTypeData(PropType)^.ClassType.InheritsFrom(TPersistent))
      or (GetTypeData(PropType)^.PropCount > 0) then
        Result:=PropClassMap[PropType^.Kind]
      else
        Result:=nil;
    end;
  end;
  if (Result<>nil) and Result.InheritsFrom(THiddenPropertyEditor) then
    Result:=nil;
end;

procedure GetPersistentProperties(ASelection: TPersistentSelectionList;
  AFilter: TTypeKinds; AHook: TPropertyEditorHook; AProc: TGetPropEditProc;
  APropInfoFilterFunc: TPropInfoFilterFunc;
  AEditorFilterFunc: TPropertyEditorFilterFunc);
var
  I, J, SelCount: Integer;
  ClassTyp: TClass;
  Candidates: TPropInfoList;
  PropLists: TFPList;
  PropEditor: TPropertyEditor;
  PropEditorList: TPropertyEditorList;
  SelEditor: TBaseSelectionEditor;
  SelEditorList: TSelectionEditorClassList;
  EdClass: TPropertyEditorClass;
  PropInfo: PPropInfo;
  AddEditor: Boolean;
  Instance: TPersistent;
  Designer: TIDesigner;
begin
  if (ASelection = nil) or (ASelection.Count = 0) then Exit;
  SelCount := ASelection.Count;
  Instance := ASelection[0];
  ClassTyp := Instance.ClassType;
  // Create a property candidate list of all properties that can be found in
  // every component in the list and in the Filter
  Candidates := TPropInfoList.Create(Instance, AFilter);
  try
    // check each property candidate
    for I := Candidates.Count - 1 downto 0 do
    begin
      PropInfo := Candidates[I];
      // check if property is readable
      if (PropInfo^.GetProc=nil)
      or ((not GShowReadOnlyProps) and (PropInfo^.PropType^.Kind <> tkClass)
          and (PropInfo^.SetProc = nil))
      or (Assigned(APropInfoFilterFunc) and (not APropInfoFilterFunc(PropInfo)))
      then begin
        Candidates.Delete(I);
        Continue;
      end;

      EdClass := GetEditorClass(PropInfo, Instance);
      if EdClass = nil
      then begin
        Candidates.Delete(I);
        Continue;
      end;

      // create a test property editor for the property
      PropEditor := EdClass.Create(AHook,1);
      PropEditor.SetPropEntry(0, Instance, PropInfo);
      PropEditor.Initialize;
      // check for multiselection, ValueAvailable and customfilter
      if ((SelCount > 1) and not (paMultiSelect in PropEditor.GetAttributes))
      or not PropEditor.ValueAvailable
      or (Assigned(AEditorFilterFunc) and not AEditorFilterFunc(PropEditor))
      then
        Candidates.Delete(I);
      PropEditor.Free;
    end;

    PropEditorList := TPropertyEditorList.Create(True);
    try
      PropLists := TFPList.Create;
      try
        PropLists.Count := SelCount;
        // Create a property info list for each component in the selection
        for I := 0 to SelCount - 1 do
          PropLists[i] := TPropInfoList.Create(ASelection[I], AFilter);

        // Eliminate each property in Candidates that is not in all property lists
        for I := 0 to SelCount - 1 do
          Candidates.Intersect(TPropInfoList(PropLists[I]));

        // Eliminate each property in the property list that are not in Candidates
        for I := 0 to SelCount - 1 do
          TPropInfoList(PropLists[I]).Intersect(Candidates);

        // PropList now has a matrix of PropInfo's.
        // -> create a property editor for each property
        for I := 0 to Candidates.Count - 1 do
        begin
          EdClass := GetEditorClass(Candidates[I], Instance);
          if EdClass = nil then Continue;
          PropEditor := EdClass.Create(AHook, SelCount);
          AddEditor := True;
          for J := 0 to SelCount - 1 do
          begin
            if (ASelection[J].ClassType <> ClassTyp) and
              (GetEditorClass(TPropInfoList(PropLists[J])[I], ASelection[J])<>EdClass) then
            begin
              AddEditor := False;
              Break;
            end;
            PropEditor.SetPropEntry(J, ASelection[J], TPropInfoList(PropLists[J])[I]);
          end;
          if AddEditor then
          begin
            PropEditor.Initialize;
            if not PropEditor.ValueAvailable then AddEditor:=false;
          end;
          if AddEditor then
            PropEditorList.Add(PropEditor)
          else
            PropEditor.Free;
        end;
      finally
        for I := 0 to PropLists.Count - 1 do
          TPropInfoList(PropLists[I]).Free;
        PropLists.Free;
      end;

      SelEditorList := TSelectionEditorClassList.Create;
      try
        GetSelectionEditorClasses(ASelection, SelEditorList);
        { is it safe to assume that the whole selection has the same designer? }
        Designer := FindRootDesigner(ASelection[0]);
        for I := 0 to SelEditorList.Count - 1 do begin
          SelEditor := SelEditorList[I].Create(Designer, AHook);
          try
            if seaFilterProperties in SelEditor.GetAttributes then
              SelEditor.FilterProperties(ASelection, PropEditorList);
          finally
            SelEditor.Free;
          end;
        end;
      finally
        SelEditorList.Free;
      end;

      { no longer free the editors }
      PropEditorList.FreeObjects := False;
      for I := 0 to PropEditorList.Count - 1 do
        AProc(PropEditorList[I]);
    finally
      PropEditorList.Free;
    end;
  finally
    Candidates.Free;
  end;
end;

procedure GetPersistentProperties(ASelection: TPersistentSelectionList;
  AFilter: TTypeKinds; AHook: TPropertyEditorHook; AProc: TGetPropEditProc;
  AEditorFilterFunc: TPropertyEditorFilterFunc);
begin
  GetPersistentProperties(ASelection,AFilter,AHook,AProc,nil,AEditorFilterFunc);
end;

procedure GetPersistentProperties(AItem: TPersistent;
  AFilter: TTypeKinds; AHook: TPropertyEditorHook; AProc: TGetPropEditProc;
  AEditorFilterFunc: TPropertyEditorFilterFunc);
var
  Selection: TPersistentSelectionList;
begin
  if AItem = nil then Exit;
  Selection := TPersistentSelectionList.Create;
  try
    Selection.Add(AItem);
    GetPersistentProperties(Selection,AFilter,AHook,AProc,AEditorFilterFunc);
  finally
    Selection.Free;
  end;
end;


{ TPropertyEditor }

constructor TPropertyEditor.Create(Hook: TPropertyEditorHook; APropCount:Integer);
var
  PropListSize: Integer;
begin
  FPropertyHook:=Hook;
  PropListSize:=APropCount * SizeOf(TInstProp);
  GetMem(FPropList,PropListSize);
  FillChar(FPropList^,PropListSize,0);
  FPropCount:=APropCount;
end;

destructor TPropertyEditor.Destroy;
begin
  if FPropList<>nil then
    FreeMem(FPropList,FPropCount * SizeOf(TInstProp));
end;

procedure TPropertyEditor.Activate;
begin
  //
end;

procedure TPropertyEditor.Deactivate;
begin
  //
end;

function TPropertyEditor.AllEqual:Boolean;
begin
  Result:=FPropCount=1;
end;

procedure TPropertyEditor.Edit;
type
  TGetStrFunc = function(const StrValue:ansistring):Integer of object;
var
  I:Integer;
  Values: TStringList;
  AddValue: TGetStrFunc;
begin
  if not AutoFill then Exit;
  Values:=TStringList.Create;
  {$IF FPC_FULLVERSION>=30200}Values.UseLocale := False;{$ENDIF}
  Values.Sorted:=paSortList in GetAttributes;
  try
    AddValue := @Values.Add;
    GetValues(TGetStrProc((@AddValue)^));
    if Values.Count > 0 then begin
      I:=Values.IndexOf(FirstValue)+1;
      if I=Values.Count then I:=0;
      FirstValue:=Values[I];
    end;
  finally
    Values.Free;
  end;
end;

procedure TPropertyEditor.Edit(AOwnerComponent: TComponent);
begin
  FOwnerComponent := AOwnerComponent;
  Edit;
  FOwnerComponent := Nil;
end;

procedure TPropertyEditor.ShowValue;
begin

end;

function TPropertyEditor.AutoFill:Boolean;
begin
  Result:=True;
end;

type
  TBoolFunc = function: Boolean of object;
  TBoolIndexFunc = function(const Index: Integer): Boolean of object;
function TPropertyEditor.CallStoredFunction: Boolean;
var
  Met: TMethod;
  Func: TBoolFunc;
  IndexFunc: TBoolIndexFunc;
  APropInfo: PPropInfo;
  StoredProcType: Byte;
begin
  APropInfo:=FPropList^[0].PropInfo;
  StoredProcType := ((APropInfo^.PropProcs shr 4) and 3);
  if StoredProcType in [ptStatic, ptVirtual] then
  begin
    case StoredProcType of
      ptStatic: Met.Code := APropInfo^.StoredProc;
      ptVirtual: Met.Code := PPointer(Pointer(FPropList^[0].Instance.ClassType))[{%H-}PtrInt(APropInfo^.StoredProc) div SizeOf(Pointer)];
    end;
    if Met.Code = nil then
      raise EPropertyError.Create('No property stored method available');
    Met.Data := FPropList^[0].Instance;
    if ((APropInfo^.PropProcs shr 6) and 1) <> 0 then // has index property
    begin
      IndexFunc := TBoolIndexFunc(Met);
      Result := IndexFunc(APropInfo^.Index);
    end else
    begin
      Func := TBoolFunc(Met);
      Result := Func();
    end;
  end else
  if StoredProcType = ptConst then
    Result := APropInfo^.StoredProc<>nil
  else
    raise EPropertyError.Create('No property stored method/const available');
end;

function TPropertyEditor.DrawCheckbox(ACanvas: TCanvas; const ARect: TRect;
  IsTrue: Boolean): TRect;
// Draws a Checkbox using theme services for editing booleans.
// Returns the output rectangle adjusted for new text location.
var
  Details: TThemedElementDetails;
  Check: TThemedButton;
  BRect: TRect;
  Sz: TSize;
  TopMargin: Integer;
  VisVal: String;
begin
  VisVal := GetVisualValue;
  // Draw the box using theme services.
  if (VisVal = '') or (VisVal = oisMixed) then
    Check := tbCheckBoxMixedNormal
  else if IsTrue then
    Check := tbCheckBoxCheckedNormal
  else
    Check := tbCheckBoxUncheckedNormal;
  Details := ThemeServices.GetElementDetails(Check);
  Sz := ThemeServices.GetDetailSize(Details);
  TopMargin := (ARect.Bottom - ARect.Top - Sz.cy) div 2;
  BRect := ARect;
  // Left varies by widgetset and theme etc. Real Checkbox itself has a left margin.
  Inc(BRect.Left, 3);                // ToDo: How to find out the real margin?
  Result := BRect;                   // Result Rect will be used for text.
  Inc(BRect.Top, TopMargin);
  BRect.Right := BRect.Left + Sz.cx;
  BRect.Bottom := BRect.Top + Sz.cy;
  ThemeServices.DrawElement(ACanvas.Handle, Details, BRect, nil);
  // Text will be written after the box.
  Inc(Result.Left, Sz.cx + 4);
end;

function TPropertyEditor.DrawCheckValue(ACanvas: TCanvas; const ARect: TRect;
                           AState: TPropEditDrawState; IsTrue: Boolean): TRect;
// Draws Boolean value as text or Checkbox depending on user setting from PropertyHook.
// Uses either theme services (func DrawCheckbox) or TCheckBoxThemed depending
//  on UseOINormalCheckBox define.
// Returns Rect for textual part if it must be drawn, otherwise Result.Top = -100.
{$IFnDEF UseOINormalCheckBox}
var
  BRect: TRect;
  VisVal: string;
  stat: TCheckBoxState;
{$ENDIF}
begin
  Result.Top := 0;
  if FPropertyHook.GetCheckboxForBoolean then
  begin                         // Checkbox for Booleans.
  {$IFnDEF UseOINormalCheckBox}
    Result.Top := -100;         // No need to call PropDrawValue further.
    BRect := ARect;
    Inc(BRect.Left, CheckBoxThemedLeftOffs);
    VisVal := GetVisualValue;
    if (VisVal = '') or (VisVal = oisMixed) then
      stat := cbGrayed
    else if VisVal = '(True)' then
      stat := cbChecked
    else
      stat := cbUnchecked;
    TCheckBoxThemed.PaintSelf(ACanvas, VisVal, BRect, stat, False, False, False,
                              False, taRightJustify);
  {$ELSE}
    Result := DrawCheckbox(ACanvas, ARect, IsTrue);
  {$ENDIF}
  end
  else
    Result := ARect;           // Classic Combobox for Booleans.
end;

function TPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result:=[paMultiSelect,paRevertable];
end;

function TPropertyEditor.IsReadOnly: boolean;
begin
  Result:=paReadOnly in GetAttributes;
end;

function TPropertyEditor.GetComponent(Index: Integer): TPersistent;
begin
  Result:=FPropList^[Index].Instance;
end;

function TPropertyEditor.GetUnitName(Index: Integer): string;
begin
  Result:=GetClassUnitName(GetComponent(Index).ClassType);
end;

function TPropertyEditor.GetPropTypeUnitName(Index: Integer): string;
type
  PPropData = ^TPropData;
var
  aPersistent: TPersistent;
  CurPropInfo: PPropInfo;
  hp: PTypeData;
  pd: PPropData;
  i: Integer;
  UpperName: ShortString;
  ATypeInfo: PTypeInfo;
  NameFound: Boolean;
  ThePropType: PTypeInfo;
begin
  Result:='';
  aPersistent:=GetComponent(Index);
  UpperName:=UpCase(GetName);
  ThePropType:=GetPropType;
  ATypeInfo:=PTypeInfo(aPersistent.ClassInfo);
  while Assigned(ATypeInfo) do begin
    // skip the name
    hp:=GetTypeData(ATypeInfo);
    // the class info rtti the property rtti follows immediatly
    pd:=AlignToPtr(Pointer(Pointer(@hp^.UnitName)+Length(hp^.UnitName)+1));
    CurPropInfo:=PPropInfo(@pd^.PropList);
    NameFound:=false;
    for i:=1 to pd^.PropCount do begin
      // found a property of that name ?
      if Upcase(CurPropInfo^.Name)=UpperName then begin
        DebugLn(['TPropertyEditor.GetPropTypeUnitName ',hp^.UnitName,' IsSamePropInfo=',CurPropInfo^.PropType=ThePropType]);
        NameFound:=true;
        if CurPropInfo^.PropType=ThePropType then
          Result:=hp^.UnitName;
      end;
      // skip to next property
      CurPropInfo:=PPropInfo(AlignToPtr(Pointer(@CurPropInfo^.Name)+Byte(CurPropInfo^.Name[0])+1));
    end;
    if not NameFound then break;
    // parent class
    ATypeInfo:=hp^.ParentInfo;
  end;
end;

function TPropertyEditor.GetPropertyPath(Index: integer): string;
begin
  Result:=GetComponent(Index).ClassName+'.'+GetName;
end;

function TPropertyEditor.GetFloatValue:Extended;
begin
  Result:=GetFloatValueAt(0);
end;

procedure SetIndexValues(P: PPRopInfo; var Index, IValue : Longint);
begin
  Index:=((P^.PropProcs shr 6) and 1);
  if Index<>0 then
    IValue:=P^.Index
  else
    IValue:=0;
end;

function TPropertyEditor.GetFloatValueAt(Index:Integer):Extended;
begin
  with FPropList^[Index] do Result:=GetFloatProp(Instance,PropInfo);
end;

function TPropertyEditor.GetMethodValue:TMethod;
begin
  Result:=GetMethodValueAt(0);
end;

// workaround for buggy rtl function
function LazGetMethodProp(Instance: TObject; PropInfo: PPropInfo): TMethod;
type
  TGetMethodProcIndex=function(Index: Longint): TMethod of object;
  TGetMethodProc=function(): TMethod of object;
  PMethod = ^TMethod;
var
  value: PMethod;
  AMethod : TMethod;
begin
  Result.Code:=nil;
  Result.Data:=nil;
  case (PropInfo^.PropProcs) and 3 of
    ptfield:
      begin
        Value:=PMethod(Pointer(Instance)+{%H-}PtrUInt(PropInfo^.GetProc));
        if Value<>nil then
          Result:=Value^;
      end;
    ptstatic,
    ptvirtual :
      begin
        if (PropInfo^.PropProcs and 3)=ptStatic then
          AMethod.Code:=PropInfo^.GetProc
        else
          AMethod.Code:=PPointer(Pointer(Instance.ClassType)
                        +{%H-}PtrUInt(PropInfo^.GetProc))^;
        AMethod.Data:=Instance;
        if ((PropInfo^.PropProcs shr 6) and 1)<>0 then
          Result:=TGetMethodProcIndex(AMethod)(PropInfo^.Index)
        else
          Result:=TGetMethodProc(AMethod)();
      end;
  end;
end;

function TPropertyEditor.GetMethodValueAt(Index:Integer):TMethod;
begin
  with FPropList^[Index] do Result:=LazGetMethodProp(Instance,PropInfo);
end;

function TPropertyEditor.GetEditLimit: Integer;
begin
  Result := 255;
end;

function TPropertyEditor.GetName:shortstring;
begin
  Result:=FPropList^[0].PropInfo^.Name;
end;

function TPropertyEditor.GetOrdValue:Longint;
begin
  Result:=GetOrdValueAt(0);
end;

function TPropertyEditor.GetOrdValueAt(Index:Integer):Longint;
begin
  with FPropList^[Index] do Result:=GetOrdProp(Instance,PropInfo);
end;

function TPropertyEditor.GetObjectValue: TObject;
begin
  Result:=GetObjectValueAt(0);
end;

function TPropertyEditor.GetObjectValue(MinClass: TClass): TObject;
begin
  Result:=GetObjectValueAt(0, MinClass);
end;

function TPropertyEditor.GetObjectValueAt(Index: Integer): TObject;
begin
  with FPropList^[Index] do
    Result:=GetObjectProp(Instance,PropInfo,nil); // nil for fpc 1.0.x
end;

function TPropertyEditor.GetObjectValueAt(Index: Integer; MinClass: TClass): TObject;
begin
  with FPropList^[Index] do
    Result:=GetObjectProp(Instance,PropInfo,MinClass);
end;

function TPropertyEditor.GetDefaultOrdValue: Longint;
var
  APropInfo: PPropInfo;
begin
  APropInfo:=FPropList^[0].PropInfo;
  Result:=APropInfo^.Default;
end;

function TPropertyEditor.GetSetValue(Brackets: boolean): AnsiString;
begin
  with FPropList^[0] do
    Result:=GetSetProp(Instance,PropInfo,Brackets);
end;

function TPropertyEditor.GetSetValueAt(Index: Integer; Brackets: boolean): AnsiString;
begin
  with FPropList^[Index] do
    Result:=GetSetProp(Instance,PropInfo,Brackets);
end;

function TPropertyEditor.GetPrivateDirectory:ansistring;
begin
  Result:='';
  if PropertyHook<>nil then
    Result:=PropertyHook.GetPrivateDirectory;
end;

procedure TPropertyEditor.DrawValue(const AValue: string; ACanvas: TCanvas;
  const ARect: TRect; AState: TPropEditDrawState);
var
  Style : TTextStyle;
begin
  FillChar(Style{%H-},SizeOf(Style),0);
  With Style do begin
    Alignment := taLeftJustify;
    Layout := tlCenter;
    Opaque := False;
    Clipping := True;
    ShowPrefix := False;
    WordBreak := False;
    SingleLine := True;
    ExpandTabs := True;
    SystemFont := False;
  end;
  ACanvas.TextRect(ARect,ARect.Left+3,ARect.Top,AValue, Style);
end;

procedure TPropertyEditor.GetProperties(Proc:TGetPropEditProc);
begin
end;

function TPropertyEditor.GetPropInfo:PPropInfo;
begin
  Result:=FPropList^[0].PropInfo;
end;

function TPropertyEditor.GetInstProp: PInstProp;
begin
  Result:=@FPropList^[0];
end;

function TPropertyEditor.GetPropType:PTypeInfo;
begin
  Result:=FPropList^[0].PropInfo^.PropType;
end;

function TPropertyEditor.GetStrValue:AnsiString;
begin
  Result:=GetStrValueAt(0);
end;

function TPropertyEditor.GetStrValueAt(Index:Integer):AnsiString;
begin
  with FPropList^[Index] do Result:=GetStrProp(Instance,PropInfo);
end;

function TPropertyEditor.GetVarValue:Variant;
begin
  Result:=GetVarValueAt(0);
end;

function TPropertyEditor.GetVarValueAt(Index:Integer):Variant;
begin
  with FPropList^[Index] do Result:=GetVariantProp(Instance,PropInfo);
end;

function TPropertyEditor.GetWideStrValue: WideString;
begin
  Result:=GetWideStrValueAt(0);
end;

function TPropertyEditor.GetWideStrValueAt(Index: Integer): WideString;
begin
  with FPropList^[Index] do Result:=GetWideStrProp(Instance,PropInfo);
end;

function TPropertyEditor.HasDefaultValue: Boolean;
var
  APropInfo: PPropInfo;
begin
  APropInfo:=FPropList^[0].PropInfo;
  Result := APropInfo^.Default<>NoDefaultValue;
end;

function TPropertyEditor.HasStoredFunction: Boolean;
var
  APropInfo: PPropInfo;
  StoredProcType: Byte;
begin
  APropInfo:=FPropList^[0].PropInfo;
  StoredProcType := ((APropInfo^.PropProcs shr 4) and 3);
  Result := StoredProcType in [ptConst, ptStatic, ptVirtual];
end;

function TPropertyEditor.GetUnicodeStrValue: UnicodeString;
begin
  Result:=GetUnicodeStrValueAt(0);
end;

function TPropertyEditor.GetUnicodeStrValueAt(Index: Integer): UnicodeString;
begin
  with FPropList^[Index] do Result:=GetUnicodeStrProp(Instance,PropInfo);
end;

function TPropertyEditor.GetValue:ansistring;
begin
  Result:=oisUnknown;
end;

function TPropertyEditor.GetHint(HintType: TPropEditHint; x, y: integer): string;
var
  TypeHint: String;
begin
  Result := GetName + LineEnding + oisValue + ' ' + GetVisualValue;
  case GetPropType^.Kind of
   tkInteger : TypeHint:=oisInteger;
   tkInt64 : TypeHint:=oisInt64;
   tkBool : TypeHint:=oisBoolean;
   tkEnumeration : TypeHint:=oisEnumeration;
   tkChar, tkWChar : TypeHint:=oisChar;
   tkUnknown : TypeHint:=oisUnknown;
   tkObject : TypeHint:=oisObject;
   tkClass : TypeHint:=oisClass;
   tkQWord : TypeHint:=oisWord;
   tkString, tkLString, tkAString, tkWString : TypeHint:=oisString;
   tkFloat : TypeHint:=oisFloat;
   tkSet : TypeHint:=oisSet;
   tkMethod : TypeHint:=oisMethod;
   tkVariant : TypeHint:=oisVariant;
   tkArray : TypeHint:=oisArray;
   tkRecord : TypeHint:=oisRecord;
   tkInterface : TypeHint:=oisInterface;
  else
    TypeHint:='';
  end;
  if TypeHint<>'' then
    Result:=Result+LineEnding+TypeHint;
end;

function TPropertyEditor.GetDefaultValue: ansistring;
begin
  if not HasDefaultValue then
    raise EPropertyError.Create('No property default available');
  Result:='';
end;

function TPropertyEditor.GetVisualValue: ansistring;
begin
  if AllEqual then
  begin
    Result:=GetValue;
    {$IFDEF LCLCarbon}
    Result:=StringReplace(Result,LineEnding,LineFeedSymbolUTF8,[rfReplaceAll])
    {$ENDIF}
  end
  else
    Result:='';
end;

procedure TPropertyEditor.GetValues(Proc:TGetStrProc);
begin
end;

procedure TPropertyEditor.Initialize;

  procedure RaiseNoInstance;
  begin
    raise Exception.Create('TPropertyEditor.Initialize '+dbgsName(Self));
  end;

begin
  if FPropList^[0].Instance=nil then
    RaiseNoInstance;
end;

procedure TPropertyEditor.Modified(PropName: ShortString);
begin
  if PropertyHook <> nil then
    PropertyHook.Modified(Self, PropName);
end;

procedure TPropertyEditor.SetPropEntry(Index:Integer;
  AnInstance:TPersistent; APropInfo:PPropInfo);
begin
  with FPropList^[Index] do begin
    Instance:=AnInstance;
    PropInfo:=APropInfo;
  end;
end;

procedure TPropertyEditor.SetFloatValue(const NewValue: Extended);
var
  I: Integer;
begin
  for I:=0 to FPropCount-1 do
    with FPropList^[I] do begin
      SetFloatProp(Instance,PropInfo,NewValue);
      Modified(PropInfo^.Name);
    end;
end;

procedure TPropertyEditor.SetMethodValue(const NewValue: TMethod);
var
  I: Integer;
begin
  for I:=0 to FPropCount-1 do
    with FPropList^[I] do begin
      LazSetMethodProp(Instance,PropInfo,NewValue);
      Modified(PropInfo^.Name);
    end;
end;

procedure TPropertyEditor.SetInt64Value(const NewValue: Int64);
var
  I: Integer;
begin
  for I:=0 to FPropCount-1 do
    with FPropList^[I] do begin
      SetInt64Prop(Instance,PropInfo,NewValue);
      Modified(PropInfo^.Name);
    end;
end;

procedure TPropertyEditor.SetIntfValue(const NewValue: IInterface);
var
  I: Integer;
begin
  for I := 0 to FPropCount - 1 do
    with FPropList^[I] do begin
      SetInterfaceProp(Instance, PropInfo, NewValue);
      Modified(PropInfo^.Name);
    end;
end;

procedure TPropertyEditor.SetOrdValue(const NewValue: Longint);
var
  I: Integer;
begin
  for I := 0 to FPropCount - 1 do
    with FPropList^[I] do begin
      SetOrdProp(Instance, PropInfo, NewValue);
      Modified(PropInfo^.Name);
    end;
end;

procedure TPropertyEditor.SetPtrValue(const NewValue: Pointer);
var
  I: Integer;
begin
  for I := 0 to FPropCount - 1 do
    with FPropList^[I] do begin
      SetOrdProp(Instance, PropInfo, PtrInt({%H-}PtrUInt(NewValue)));
      Modified(PropInfo^.Name);
    end;
end;

procedure TPropertyEditor.SetStrValue(const NewValue: AnsiString);
var
  I: Integer;
begin
  for I:=0 to FPropCount-1 do
    with FPropList^[I] do begin
      SetStrProp(Instance,PropInfo,NewValue);
      Modified(PropInfo^.Name);
    end;
end;

procedure TPropertyEditor.SetWideStrValue(const NewValue: WideString);
var
  I: Integer;
begin
  for I:=0 to FPropCount-1 do
    with FPropList^[I] do begin
      SetWideStrProp(Instance,PropInfo,NewValue);
      Modified(PropInfo^.Name);
    end;
end;

procedure TPropertyEditor.SetUnicodeStrValue(const NewValue: UnicodeString);
var
  I: Integer;
begin
  for I:=0 to FPropCount-1 do
    with FPropList^[I] do begin
      SetUnicodeStrProp(Instance,PropInfo,NewValue);
      Modified(PropInfo^.Name);
    end;
end;

procedure TPropertyEditor.SetVarValue(const NewValue: Variant);
var
  I: Integer;
begin
  for I:=0 to FPropCount-1 do
    with FPropList^[I] do begin
      SetVariantProp(Instance,PropInfo,NewValue);
      Modified(PropInfo^.Name);
    end;
end;

procedure TPropertyEditor.Revert;
var
  I: Integer;
begin
  if PropertyHook<>nil then
    for I:=0 to FPropCount-1 do
      with FPropList^[I] do PropertyHook.Revert(Instance,PropInfo);
end;

procedure TPropertyEditor.RevertToInherited;
var
  i: Integer;
  AncestorInstProp: TInstProp;
  Changed: Boolean;
  InstProp: TInstProp;
  NewOrdValue, OldOrdValue: Int64;
  OldStr, NewStr: String;
  OldWideStr, NewWideStr: WideString;
  OldUString, NewUString: UnicodeString;
  OldFloat, NewFloat: Extended;
  OldObj, NewObj: TObject;
  OldMethod, NewMethod: TMethod;
  OldInterface, NewInterface: IInterface;
begin
  if PropertyHook=nil then exit;
  Changed:=false;
  try
    for i:=0 to FPropCount-1 do
    begin
      InstProp:=FPropList^[i];
      if not PropertyHook.GetAncestorInstance(InstProp,AncestorInstProp) then
        continue;

      case InstProp.PropInfo^.PropType^.Kind of
      tkInteger,tkChar,tkEnumeration,tkBool,tkInt64,tkQWord:
        begin
          OldOrdValue:=GetOrdProp(InstProp.Instance,InstProp.PropInfo);
          NewOrdValue:=GetOrdProp(AncestorInstProp.Instance,AncestorInstProp.PropInfo);
          if OldOrdValue=NewOrdValue then continue;
          Changed:=true;
          SetOrdProp(InstProp.Instance,InstProp.PropInfo,NewOrdValue);
        end;
      tkSet:
        begin
          OldStr:=GetSetProp(InstProp.Instance,InstProp.PropInfo,false);
          NewStr:=GetSetProp(AncestorInstProp.Instance,AncestorInstProp.PropInfo,false);
          if OldStr=NewStr then continue;
          Changed:=true;
          SetSetProp(InstProp.Instance,InstProp.PropInfo,NewStr);
        end;
      tkString,tkLString,tkAString:
        begin
          OldStr:=GetStrProp(InstProp.Instance,InstProp.PropInfo);
          NewStr:=GetStrProp(AncestorInstProp.Instance,AncestorInstProp.PropInfo);
          if OldStr=NewStr then continue;
          Changed:=true;
          SetStrProp(InstProp.Instance,InstProp.PropInfo,NewStr);
        end;
      tkWString:
        begin
          OldWideStr:=GetWideStrProp(InstProp.Instance,InstProp.PropInfo);
          NewWideStr:=GetWideStrProp(AncestorInstProp.Instance,AncestorInstProp.PropInfo);
          if OldWideStr=NewWideStr then continue;
          Changed:=true;
          SetWideStrProp(InstProp.Instance,InstProp.PropInfo,NewWideStr);
        end;
      tkUString:
        begin
          OldUString:=GetUnicodeStrProp(InstProp.Instance,InstProp.PropInfo);
          NewUString:=GetUnicodeStrProp(AncestorInstProp.Instance,AncestorInstProp.PropInfo);
          if OldUString=NewUString then continue;
          Changed:=true;
          SetUnicodeStrProp(InstProp.Instance,InstProp.PropInfo,NewUString);
        end;
      tkFloat:
        begin
          OldFloat:=GetFloatProp(InstProp.Instance,InstProp.PropInfo);
          NewFloat:=GetFloatProp(AncestorInstProp.Instance,AncestorInstProp.PropInfo);
          if OldFloat=NewFloat then continue;
          Changed:=true;
          SetFloatProp(InstProp.Instance,InstProp.PropInfo,NewFloat);
        end;
      tkClass:
        begin
          OldObj:=GetObjectProp(InstProp.Instance,InstProp.PropInfo);
          NewObj:=GetObjectProp(AncestorInstProp.Instance,AncestorInstProp.PropInfo);
          if OldObj=NewObj then continue;
          Changed:=true;
          SetObjectProp(InstProp.Instance,InstProp.PropInfo,NewObj);
        end;
      tkMethod:
        begin
          OldMethod:=GetMethodProp(InstProp.Instance,InstProp.PropInfo);
          NewMethod:=GetMethodProp(AncestorInstProp.Instance,AncestorInstProp.PropInfo);
          if CompareMethods(OldMethod,NewMethod) then continue;
          Changed:=true;
          SetMethodProp(InstProp.Instance,InstProp.PropInfo,NewMethod);
        end;
      tkInterface:
        begin
          OldInterface:=GetInterfaceProp(InstProp.Instance,InstProp.PropInfo);
          NewInterface:=GetInterfaceProp(AncestorInstProp.Instance,AncestorInstProp.PropInfo);
          if OldInterface=NewInterface then continue;
          Changed:=true;
          SetInterfaceProp(InstProp.Instance,InstProp.PropInfo,NewInterface);
        end;
      end;
    end;
  finally
    if Changed then
      Modified;
  end;
end;

procedure TPropertyEditor.SetValue(const NewValue:ansistring);
begin
end;

function TPropertyEditor.ValueAvailable:Boolean;
var
  I:Integer;
begin
  Result:=True;
  for I:=0 to FPropCount-1 do
  begin
    if (FPropList^[I].Instance is TComponent)
    and (csCheckPropAvail in TComponent(FPropList^[I].Instance).ComponentStyle)
    then begin
      try
        GetValue;
        AllEqual;
      except
        Result:=False;
      end;
      Exit;
    end;
  end;
end;

function TPropertyEditor.GetInt64Value:Int64;
begin
  Result:=GetInt64ValueAt(0);
end;

function TPropertyEditor.GetInt64ValueAt(Index:Integer):Int64;
begin
  with FPropList^[Index] do Result:=GetInt64Prop(Instance,PropInfo);
end;

function TPropertyEditor.GetIntfValue: IInterface;
begin
  Result := GetIntfValueAt(0);
end;

function TPropertyEditor.GetIntfValueAt(Index: Integer): IInterface;
begin
  with FPropList^[Index] do Result := GetInterfaceProp(Instance, PropInfo);
end;

{ these three procedures implement the default render behavior of the
  object inspector's drop down list editor. You don't need to
  override the two measure procedures if the default width or height don't
  need to be changed. }
procedure TPropertyEditor.ListMeasureHeight(const AValue: ansistring;
  Index: Integer; ACanvas: TCanvas; var AHeight: Integer);
begin
  AHeight := ACanvas.TextHeight(AValue);
end;

procedure TPropertyEditor.ListMeasureWidth(const AValue: ansistring;
  Index: Integer; ACanvas: TCanvas; var AWidth: Integer);
begin
  //
end;

procedure TPropertyEditor.ListDrawValue(const AValue: ansistring; Index: Integer;
  ACanvas: TCanvas; const ARect: TRect; AState: TPropEditDrawState);
var
  Style : TTextStyle;
begin
  FillChar(Style{%H-},SizeOf(Style),0);
  With Style do begin
    Alignment := taLeftJustify;
    Layout := tlCenter;
    Opaque := False;
    Clipping := True;
    ShowPrefix := True;
    WordBreak := False;
    SingleLine := True;
    SystemFont := False;
  end;
  ACanvas.TextRect(ARect, ARect.Left+2,ARect.Top,AValue, Style);
end;

{ these three procedures implement the default render behavior of the
  object inspector's property row. You don't need to override the measure
  procedure if the default height don't need to be changed. }
procedure TPropertyEditor.PropMeasureHeight(const NewValue: ansistring;
  ACanvas: TCanvas; var AHeight: Integer);
begin
  //
end;

procedure TPropertyEditor.PropDrawName(ACanvas: TCanvas; const ARect: TRect;
  AState: TPropEditDrawState);
var
  Style : TTextStyle;
begin
  FillChar(Style{%H-},SizeOf(Style),0);
  With Style do begin
    Alignment := taLeftJustify;
    Layout := tlCenter;
    Opaque := False;
    Clipping := True;
    ShowPrefix := False;
    WordBreak := False;
    SingleLine := True;
    ExpandTabs := True;
    SystemFont := False;
  end;
  ACanvas.TextRect(ARect,ARect.Left+2,ARect.Top,GetName,Style);
end;

procedure TPropertyEditor.PropDrawValue(ACanvas: TCanvas; const ARect: TRect;
  AState: TPropEditDrawState);
begin
  DrawValue(GetVisualValue,ACanvas,ARect,AState);
end;

procedure TPropertyEditor.UpdateSubProperties;
begin
  if (OnSubPropertiesChanged<>nil) and SubPropertiesNeedsUpdate then
    OnSubPropertiesChanged(Self);
end;

function TPropertyEditor.SubPropertiesNeedsUpdate: boolean;
begin
  Result:=false;
end;

function TPropertyEditor.ValueIsStreamed: boolean;
begin
  if HasStoredFunction then
    Result := CallStoredFunction
  else
    Result := True;
  if Result and HasDefaultValue then
    Result := GetDefaultValue<>GetVisualValue;
end;

function TPropertyEditor.IsRevertableToInherited: boolean;
begin
  Result:=(paRevertable in GetAttributes) and (GetComponent(0) is TComponent)
    and (csAncestor in TComponent(GetComponent(0)).ComponentState)
    and (PropertyHook<>nil)
    and (FPropList^[0].PropInfo^.PropType^.Kind in
      [tkInteger,tkChar,tkEnumeration,tkBool,tkInt64,tkQWord,
       tkSet,
       tkString,tkLString,tkAString,
       tkWString,
       tkUString,
       tkFloat,
       tkClass,
       tkMethod,
       tkInterface]);
end;

function TPropertyEditor.GetVerbCount: Integer;
begin
  Result:=0;
  if HasDefaultValue then
    inc(Result); // show a menu item for default value only if there is default value
  if IsRevertableToInherited then
    inc(Result); // show a menu item for 'Revert to inherited'
end;

function TPropertyEditor.GetVerb(Index: Integer): string;
var
  i: Integer;
begin
  Result := '';
  i:=-1;
  if HasDefaultValue then begin
    inc(i);
    if i=Index then begin
      Result := Format(oisSetToDefault, [GetDefaultValue]);
      exit;
    end;
  end;
  if IsRevertableToInherited then begin
    inc(i);
    if i=Index then begin
      Result := oisRevertToInherited;
      exit;
    end;
  end;
end;

procedure TPropertyEditor.PrepareItem(Index: Integer; const AnItem: TMenuItem);
begin
  // overridden by descendants
end;

procedure TPropertyEditor.ExecuteVerb(Index: Integer);
var
  i: Integer;
begin
  i:=-1;
  if HasDefaultValue then begin
    inc(i);
    if i=Index then begin
      SetValue(GetDefaultValue);
      exit;
    end;
  end;
  if IsRevertableToInherited then begin
    inc(i);
    if i=Index then begin
      RevertToInherited;
      exit;
    end;
  end;
end;

{ TOrdinalPropertyEditor }

function TOrdinalPropertyEditor.AllEqual: Boolean;
var
  I: Integer;
  V: Longint;
begin
  Result := False;
  if PropCount > 1 then
  begin
    V := GetOrdValue;
    for I := 1 to PropCount - 1 do
      if GetOrdValueAt(I) <> V then Exit;
  end;
  Result := True;
end;

function TOrdinalPropertyEditor.GetEditLimit: Integer;
begin
  Result := 63;
end;

function TOrdinalPropertyEditor.GetValue: ansistring;
begin
  Result:=OrdValueToVisualValue(GetOrdValue);
end;

function TOrdinalPropertyEditor.GetDefaultValue: ansistring;
begin
  Result:=OrdValueToVisualValue(GetDefaultOrdValue);
end;

function TOrdinalPropertyEditor.OrdValueToVisualValue(OrdValue: longint): string;
begin
  Result:=IntToStr(OrdValue);
end;

{ TIntegerPropertyEditor }

function TIntegerPropertyEditor.OrdValueToVisualValue(OrdValue: longint): string;
begin
  with GetTypeData(GetPropType)^ do begin
    {debugln('TIntegerPropertyEditor.OrdValueToVisualValue ',GetName,' ',dbgs(ord(OrdType)),' ',dbgs(OrdValue));
    case OrdType of
      otSByte : debugln('TIntegerPropertyEditor.OrdValueToVisualValue otSByte ',dbgs(ShortInt(OrdValue)));
      otUByte : debugln('TIntegerPropertyEditor.OrdValueToVisualValue otUByte ',dbgs(Byte(OrdValue)));
      otSWord : debugln('TIntegerPropertyEditor.OrdValueToVisualValue otSWord ',dbgs(SmallInt(OrdValue)));
      otUWord : debugln('TIntegerPropertyEditor.OrdValueToVisualValue otUWord ',dbgs(Word(OrdValue)));
      otULong : debugln('TIntegerPropertyEditor.OrdValueToVisualValue otULong ',dbgs(Cardinal(OrdValue)));
      else debugln('TIntegerPropertyEditor.OrdValueToVisualValue ??? ',dbgs(OrdValue));
    end;}

    case OrdType of
      otSByte : Result:= IntToStr(ShortInt(OrdValue));
      otUByte : Result:= IntToStr(Byte(OrdValue));
      otSWord : Result:= IntToStr(Integer(SmallInt(OrdValue)));// double conversion needed due to compiler bug 3534
      otUWord : Result:= IntToStr(Word(OrdValue));
      otULong : Result:= IntToStr(Cardinal(OrdValue));
      else Result := IntToStr(OrdValue);
    end;
    //debugln('TIntegerPropertyEditor.OrdValueToVisualValue ',Result);
  end;
end;

procedure TIntegerPropertyEditor.SetValue(const NewValue: AnsiString);

  procedure Error(const Args: array of const);
  begin
    raise EPropertyError.CreateResFmt(@SOutOfRange, Args);
  end;

var
  L: Int64;
begin
  L := StrToInt64(NewValue);
  with GetTypeData(GetPropType)^ do
    if OrdType = otULong then
    begin   // unsigned compare and reporting needed
      if (L < Cardinal(MinValue)) or (L > Cardinal(MaxValue)) then begin
        // bump up to Int64 to get past the %d in the format string
        Error([Int64(Cardinal(MinValue)), Int64(Cardinal(MaxValue))]);
        exit;
      end
    end
    else if (L < MinValue) or (L > MaxValue) then begin
      Error([MinValue, MaxValue]);
      exit;
    end;
  SetOrdValue(integer(L));
end;

{ TCharPropertyEditor }

function TCharPropertyEditor.OrdValueToVisualValue(OrdValue: longint): string;
var
  Ch: Char;
begin
  Ch := Chr(OrdValue);
  if Ch in [#33..#127] then
    Result := Ch
  else
    Result:='#'+IntToStr(Ord(Ch));
end;

procedure TCharPropertyEditor.SetValue(const NewValue: ansistring);
var
  L: Longint;
begin
  if Length(NewValue) = 0 then L := 0 else
    if Length(NewValue) = 1 then L := Ord(NewValue[1]) else
      if NewValue[1] = '#' then L := StrToInt(Copy(NewValue, 2, Maxint)) else
      begin
        {raise EPropertyError.CreateRes(@SInvalidPropertyValue)};
        exit;
      end;
  with GetTypeData(GetPropType)^ do
    //Only Chars < #$80 are valid single-byte UTF-8 codepoints,
    //so use this instead of MaxValue (255 for tkChar), since LCL is UTF-8
    if (L < MinValue) or (L > $7F) then begin
      {raise EPropertyError.CreateResFmt(@SOutOfRange, [MinValue, MaxValue])};
      exit;
    end;
  SetOrdValue(L);
end;

{ TEnumPropertyEditor }

function TEnumPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paValueList, paSortList, paRevertable];
end;

function TEnumPropertyEditor.OrdValueToVisualValue(OrdValue: longint): string;
var
  L: Longint;
  TypeData: PTypeData;
begin
  L := OrdValue;
  TypeData := GetTypeData(GetPropType);
  with TypeData^ do
    if (L < MinValue) or (L > MaxValue) then L := MaxValue;
  Result := GetEnumName(GetPropType, L);
end;

function TEnumPropertyEditor.GetVisualValue: ansistring;
begin
  if FInvalid then
    Result := oisInvalid
  else
    Result := inherited GetVisualValue;
end;

procedure TEnumPropertyEditor.GetValues(Proc: TGetStrProc);
var
  I: Integer;
  EnumType: PTypeInfo;
  s: ShortString;
begin
  EnumType := GetPropType;
  with GetTypeData(EnumType)^ do
    for I := MinValue to MaxValue do begin
      s := GetEnumName(EnumType, I);
      Proc(s);
    end;
end;

procedure TEnumPropertyEditor.SetValue(const NewValue: ansistring);
var
  I: Integer;
begin
  I := GetEnumValue(GetPropType, NewValue);
  FInvalid := I < 0;
  if not FInvalid then
    SetOrdValue(I);
end;

{ TBoolPropertyEditor  }

function TBoolPropertyEditor.OrdValueToVisualValue(OrdValue: longint): string;
begin
  if OrdValue = 0 then
    Result := 'False'
  else
    Result := 'True';
  if FPropertyHook.GetCheckboxForBoolean then
    Result := '(' + Result + ')';
end;

function TBoolPropertyEditor.GetVisualValue: ansistring;
begin
  Result := inherited GetVisualValue;
  if Result = '' then
    Result := oisMixed;
end;

procedure TBoolPropertyEditor.GetValues(Proc: TGetStrProc);
begin
  Proc('False');
  Proc('True');
end;

procedure TBoolPropertyEditor.SetValue(const NewValue: ansistring);
var
  I: Integer;
begin
  if (CompareText(NewValue, 'False') = 0)
  or (CompareText(NewValue, '(False)') = 0)
  or (CompareText(NewValue, 'F') = 0) then
    I := 0
  else 
  if (CompareText(NewValue, 'True') = 0)
  or (CompareText(NewValue, '(True)') = 0)
  or (CompareText(NewValue, 'T') = 0) then
    I := 1
  else
    I := StrToInt(NewValue);
  SetOrdValue(I);
end;

procedure TBoolPropertyEditor.PropDrawValue(ACanvas: TCanvas; const ARect: TRect;
                                            AState: TPropEditDrawState);
var
  TxtRect: TRect;
begin
  TxtRect := DrawCheckValue(ACanvas, ARect, AState, GetOrdValue<>0);
  if TxtRect.Top <> -100 then
    inherited PropDrawValue(ACanvas, TxtRect, AState);
end;

{ TInt64PropertyEditor }

function TInt64PropertyEditor.AllEqual: Boolean;
var
  I: Integer;
  V: Int64;
begin
  Result := False;
  if PropCount > 1 then
  begin
    V := GetInt64Value;
    for I := 1 to PropCount - 1 do
      if GetInt64ValueAt(I) <> V then Exit;
  end;
  Result := True;
end;

function TInt64PropertyEditor.GetEditLimit: Integer;
begin
  Result := 63;
end;

function TInt64PropertyEditor.GetValue: ansistring;
begin
  Result := IntToStr(GetInt64Value);
end;

procedure TInt64PropertyEditor.SetValue(const NewValue: ansistring);
begin
  SetInt64Value(StrToInt64(NewValue));
end;


{ TQWordPropertyEditor }

function TQWordPropertyEditor.GetValue: ansistring;
begin
  Result := IntToStr(QWord(GetInt64Value));
end;

procedure TQWordPropertyEditor.SetValue(const NewValue: ansistring);
begin
  SetInt64Value(Int64(StrToQWord(NewValue)));
end;

{ TFloatPropertyEditor }

function TFloatPropertyEditor.AllEqual: Boolean;
var
  I: Integer;
  V: Extended;
begin
  Result := False;
  if PropCount > 1 then
  begin
    V := GetFloatValue;
    for I := 1 to PropCount - 1 do
      if GetFloatValueAt(I) <> V then Exit;
  end;
  Result := True;
end;

function TFloatPropertyEditor.FormatValue(const AValue: Extended): ansistring;
const
  Precisions: array[TFloatType] of Integer = (7, 15, 19, 19, 19);
var
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.'; //It's Pascal sourcecode representation of a float, not a textual (i18n) one
  Result := FloatToStrF(AValue, ffGeneral,
    Precisions[GetTypeData(GetPropType)^.FloatType], 0, FS);
end;

function TFloatPropertyEditor.GetDefaultValue: ansistring;
begin
  if not HasDefaultValue then
    raise EPropertyError.Create('No property default available');
  Result:=FormatValue(0);
end;

function TFloatPropertyEditor.GetValue: ansistring;
begin
  Result := FormatValue(GetFloatValue);
end;

procedure TFloatPropertyEditor.SetValue(const NewValue: ansistring);
var
  FS: TFormatSettings;
  NewFloat: Extended;
begin
  //writeln('TFloatPropertyEditor.SetValue A ',NewValue,'  ',StrToFloat(NewValue));
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.'; //after all, this is Pascal, so we expect a period
  if not TryStrToFloat(NewValue, NewFloat, FS) then
    //if this failed, assume the user entered DS from his current locale
    NewFloat := StrToFloat(NewValue, DefaultFormatSettings);
  SetFloatValue(NewFloat);
  //writeln('TFloatPropertyEditor.SetValue B ',GetValue);
end;

{ TStringPropertyEditor }

function TStringPropertyEditor.AllEqual: Boolean;
var
  I: Integer;
  V: ansistring;
begin
  Result := False;
  if PropCount > 1 then begin
    V := GetStrValue;
    for I := 1 to PropCount - 1 do
      if GetStrValueAt(I) <> V then Exit;
  end;
  Result := True;
end;

function TStringPropertyEditor.GetEditLimit: Integer;
begin
  if GetPropType^.Kind = tkSString then
    Result := GetTypeData(GetPropType)^.MaxLength
  else
    Result := $0FFF;
end;

function TStringPropertyEditor.GetValue: ansistring;
begin
  Result := GetStrValue;
end;

procedure TStringPropertyEditor.SetValue(const NewValue: ansistring);
begin
  SetStrValue(NewValue);
end;

{ TPasswordStringPropertyEditor }

function TPasswordStringPropertyEditor.GetPassword: string;
begin
  if GetVisualValue<>'' then
    Result:='*****'
  else
    Result:='';
end;

procedure TPasswordStringPropertyEditor.PropDrawValue(ACanvas: TCanvas;
  const ARect: TRect; AState: TPropEditDrawState);
begin
  DrawValue(GetPassword,ACanvas,ARect,AState);
end;

{ TWideStringPropertyEditor }

function TWideStringPropertyEditor.AllEqual: Boolean;
var
  I: Integer;
  V: widestring;
begin
  Result := False;
  if PropCount > 1 then begin
    V := GetWideStrValue;
    for I := 1 to PropCount - 1 do
      if GetWideStrValueAt(I) <> V then Exit;
  end;
  Result := True;
end;

function TWideStringPropertyEditor.GetValue: ansistring;
begin
  Result:=UTF8Encode(GetWideStrValue);
end;

procedure TWideStringPropertyEditor.SetValue(const NewValue: ansistring);
begin
  SetWideStrValue(UTF8Decode(NewValue));
end;

{ TPasswordWideStringPropertyEditor }

function TPasswordWideStringPropertyEditor.GetPassword: WideString;
begin
  if GetVisualValue<>'' then
    Result:='*****'
  else
    Result:='';
end;

procedure TPasswordWideStringPropertyEditor.PropDrawValue(ACanvas: TCanvas;
  const ARect: TRect; AState: TPropEditDrawState);
begin
  DrawValue(UTF8Encode(GetPassword),ACanvas,ARect,AState);
end;

{ TUnicodeStringPropertyEditor }

function TUnicodeStringPropertyEditor.AllEqual: Boolean;
var
  I: Integer;
  V: UnicodeString;
begin
  Result := False;
  if PropCount > 1 then begin
    V := GetUnicodeStrValue;
    for I := 1 to PropCount - 1 do
      if GetUnicodeStrValueAt(I) <> V then Exit;
  end;
  Result := True;
end;

function TUnicodeStringPropertyEditor.GetValue: ansistring;
begin
  Result:=UTF8Encode(GetUnicodeStrValue);
end;

procedure TUnicodeStringPropertyEditor.SetValue(const NewValue: ansistring);
begin
  SetUnicodeStrValue(UTF8Decode(NewValue));
end;

{ TNestedPropertyEditor }

constructor TNestedPropertyEditor.Create(Parent: TPropertyEditor);
begin
  FParentEditor:=Parent;
  FPropertyHook:=Parent.PropertyHook;
  FPropList:=Parent.FPropList;
  FPropCount:=Parent.PropCount;
end;

destructor TNestedPropertyEditor.Destroy;
begin
end;

{ TSetElementPropertyEditor }

constructor TSetElementPropertyEditor.Create(Parent: TPropertyEditor;
 AElement: Integer);
begin
  inherited Create(Parent);
  FElement := AElement;
end;

// The IntegerSet (a set of size of an integer)
// don't know if this is always valid
type
  TIntegerSet = set of 0..SizeOf(Integer) * 8 - 1;

function TSetElementPropertyEditor.AllEqual: Boolean;
var
  I: Integer;
  S: TIntegerSet;
  V: Boolean;
begin
  Result := False;
  if PropCount > 1 then begin
    Integer(S) := GetOrdValue;
    V := FElement in S;
    for I := 1 to PropCount - 1 do begin
      Integer(S) := GetOrdValueAt(I);
      if (FElement in S) <> V then Exit;
    end;
  end;
  Result := True;
end;

function TSetElementPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paValueList, paSortList];
end;

function TSetElementPropertyEditor.GetName: shortstring;
begin
  Result := GetEnumName(GetTypeData(GetPropType)^.CompType, FElement);
end;

function TSetElementPropertyEditor.GetValue: ansistring;
var
  S: TIntegerSet;
begin
  Integer(S) := GetOrdValue;
  Result := BooleanIdents[FElement in S];
  if FPropertyHook.GetCheckboxForBoolean then
    Result := '(' + Result + ')';
end;

function TSetElementPropertyEditor.GetVerbCount: Integer;
begin
  Result:=0;
end;

function TSetElementPropertyEditor.GetVisualValue: ansistring;
begin
  Result := inherited GetVisualValue;
  if Result = '' then
    Result := oisMixed;
end;

procedure TSetElementPropertyEditor.GetValues(Proc: TGetStrProc);
begin
  Proc(BooleanIdents[False]);
  Proc(BooleanIdents[True]);
end;

procedure TSetElementPropertyEditor.SetValue(const NewValue: ansistring);
var
  S: TIntegerSet;
begin
  Integer(S) := GetOrdValue;
  if (CompareText(NewValue, 'True') = 0)
  or (CompareText(NewValue, '(True)') = 0) then
    Include(S, FElement)
  else
    Exclude(S, FElement);
  SetOrdValue(Integer(S));
end;

function TSetElementPropertyEditor.ValueIsStreamed: boolean;
var
  S1, S2: TIntegerSet;
begin
  if HasStoredFunction then
    Result := CallStoredFunction
  else
    Result := True;
  if Result and HasDefaultValue then
  begin
    Integer(S1) := GetOrdValue;
    Integer(S2) := GetDefaultOrdValue;
    Result := (FElement in S1) <> (FElement in S2);
  end;
end;

procedure TSetElementPropertyEditor.PropDrawValue(ACanvas: TCanvas; const ARect: TRect;
                                                  AState: TPropEditDrawState);
var
  S: TIntegerSet;
  TxtRect: TRect;
begin
  Integer(S) := GetOrdValue;
  TxtRect := DrawCheckValue(ACanvas, ARect, AState, FElement in S);
  if TxtRect.Top <> -100 then
    inherited PropDrawValue(ACanvas, TxtRect, AState);
end;

{ TSetPropertyEditor }

function TSetPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paSubProperties, paReadOnly, paRevertable];
end;

function TSetPropertyEditor.GetEditLimit: Integer;
begin
  Result := 0;
end;

procedure TSetPropertyEditor.GetProperties(Proc: TGetPropEditProc);
var
  I: Integer;
begin
  with GetTypeData(GetTypeData(GetPropType)^.CompType)^ do
    for I := MinValue to MaxValue do
      Proc(TSetElementPropertyEditor.Create(Self, I));
end;

procedure TSetPropertyEditor.SetValue(const NewValue: ansistring);
var
  S: TIntegerSet;
  TypeInfo: PTypeInfo;
  I: Integer;
begin
  S := [];
  TypeInfo := GetTypeData(GetPropType)^.CompType;
  for I := 0 to SizeOf(Integer) * 8 - 1 do
    if Pos(GetEnumName(TypeInfo, I), NewValue) > 0 then
      Include(S, I);
  SetOrdValue(Integer(S));
end;

function TSetPropertyEditor.OrdValueToVisualValue(OrdValue: longint): string;
var
  S: TIntegerSet;
  TypeInfo: PTypeInfo;
  I: Integer;
begin
  Integer(S) := OrdValue;
  TypeInfo := GetTypeData(GetPropType)^.CompType;
  Result := '[';
  for I := 0 to SizeOf(Integer) * 8 - 1 do
    if I in S then
    begin
      if Length(Result) <> 1 then Result := Result + ',';
      Result := Result + GetEnumName(TypeInfo, I);
    end;
  Result := Result + ']';
end;

{ TListElementPropertyEditor }

constructor TListElementPropertyEditor.Create(Parent: TListPropertyEditor;
  AnIndex: integer);
begin
  inherited Create(Parent);
  FList:=Parent;
  FIndex:=AnIndex;
end;

destructor TListElementPropertyEditor.Destroy;
begin
  inherited Destroy;
end;

function TListElementPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result:=List.GetElementAttributes(Self);
end;

function TListElementPropertyEditor.GetName: shortstring;
begin
  Result:=List.GetElementName(Self);
end;

procedure TListElementPropertyEditor.GetProperties(Proc: TGetPropEditProc);
begin
  List.GetElementProperties(Self,Proc);
end;

function TListElementPropertyEditor.GetValue: ansistring;
begin
  Result:=List.GetElementValue(Self);
end;

procedure TListElementPropertyEditor.GetValues(Proc: TGetStrProc);
begin
  List.GetElementValues(Self,Proc);
end;

procedure TListElementPropertyEditor.SetValue(const NewValue: ansistring);
begin
  List.SetElementValue(Self,NewValue);
end;

{ TListPropertyEditor }

function TListPropertyEditor.GetElementCount: integer;
begin
  if not IsSaving then
    Result:=SavedElements.Count
  else
    Result:=ReadElementCount;
end;

function TListPropertyEditor.GetElement(Index: integer): TPersistent;
var
  ElementCount: integer;
begin
  // do some checks
  if (Index<0) then
    raise Exception('TListPropertyEditor.GetElement Index='+IntToStr(Index));
  ElementCount:=GetElementCount;
  if Index>=ElementCount then
    raise Exception('TListPropertyEditor.GetElement Index='+IntToStr(Index)
      +' Count='+IntToStr(ElementCount));
  // get element
  if not IsSaving then
    Result:=TPersistent(SavedElements[Index])
  else
    Result:=ReadElement(Index);
end;

function TListPropertyEditor.GetElement(Element: TListElementPropertyEditor
  ): TPersistent;
begin
  Result:=GetElement(Element.TheIndex);
end;

function TListPropertyEditor.GetElementPropEditor(Index: integer
  ): TListElementPropertyEditor;
// called by GetProperties to get the element property editors
begin
  if not IsSaving then
    Result:=TListElementPropertyEditor(SavedPropertyEditors[Index])
  else
    Result:=CreateElementPropEditor(Index);
end;

procedure TListPropertyEditor.SaveElements;
begin
  if IsSaving then exit;
  BeginSaveElement;
  FreeElementPropertyEditors;
  DoSaveElements;
  FSubPropertiesChanged:=false;
  EndSaveElement;
end;

function TListPropertyEditor.SubPropertiesNeedsUpdate: boolean;
var i: integer;
begin
  Result:=true;
  if FSubPropertiesChanged then exit;
  FSubPropertiesChanged:=true;
  if SavedList<>GetComponent(0) then exit;
  if ReadElementCount<>SavedElements.Count then exit;
  for i:=0 to SavedElements.Count-1 do
    if TPersistent(SavedElements[i])<>ReadElement(i) then exit;
  Result:=false;
  FSubPropertiesChanged:=false;
end;

function TListPropertyEditor.ReadElementCount: integer;
var
  TheList: TObject;
begin
  TheList := GetObjectValue;
  if TheList is TList then
    Result := TList(TheList).Count
  else
    Result := 0;
end;

function TListPropertyEditor.ReadElement(Index: integer): TPersistent;
var
  obj: TObject;
begin
  obj := TObject(TList(GetObjectValue).Items[Index]);
  if obj is TPersistent then
    Result:=TPersistent(obj)
  else
    raise EInvalidOperation.CreateFmt('List element %d is not a TPersistent descendant', [Index]);
end;

function TListPropertyEditor.CreateElementPropEditor(Index: integer
  ): TListElementPropertyEditor;
begin
  Result:=TListElementPropertyEditor.Create(Self,Index);
end;

procedure TListPropertyEditor.BeginSaveElement;
begin
  inc(FSaveElementLock);
end;

procedure TListPropertyEditor.EndSaveElement;
begin
  dec(FSaveElementLock);
  if FSaveElementLock<0 then
    DebugLn('TListPropertyEditor.EndSaveElement ERROR: FSaveElementLock=',
      IntToStr(FSaveElementLock));
end;

procedure TListPropertyEditor.DoSaveElements;
var
  i, ElementCount: integer;
begin
  SavedList:=GetComponent(0);
  ElementCount:=GetElementCount;
  SavedElements.Count:=ElementCount;
  for i:=0 to ElementCount-1 do
    SavedElements[i]:=GetElement(i);
  SavedPropertyEditors.Count:=ElementCount;
  for i:=0 to ElementCount-1 do
    SavedPropertyEditors[i]:=GetElementPropEditor(i);
end;

procedure TListPropertyEditor.FreeElementPropertyEditors;
var
  i: integer;
begin
  for i:=0 to SavedPropertyEditors.Count-1 do
    TObject(SavedPropertyEditors[i]).Free;
  SavedPropertyEditors.Clear;
end;

function TListPropertyEditor.GetElementAttributes(
  Element: TListElementPropertyEditor
  ): TPropertyAttributes;
begin
  Result:= [paReadOnly];
end;

function TListPropertyEditor.GetElementName(Element: TListElementPropertyEditor
  ): shortstring;
begin
  Result:='';
end;

procedure TListPropertyEditor.GetElementProperties(
  Element: TListElementPropertyEditor; Proc: TGetPropEditProc);
begin

end;

function TListPropertyEditor.GetElementValue(Element: TListElementPropertyEditor
  ): ansistring;
begin
  Result:='';
end;

procedure TListPropertyEditor.GetElementValues(
  Element: TListElementPropertyEditor; Proc: TGetStrProc);
begin

end;

procedure TListPropertyEditor.SetElementValue(
  Element: TListElementPropertyEditor; NewValue: ansistring);
begin

end;

function TListPropertyEditor.IsSaving: boolean;
begin
  Result:=SaveElementLock>0;
end;

constructor TListPropertyEditor.Create(Hook: TPropertyEditorHook;
  APropCount: Integer);
begin
  inherited Create(Hook, APropCount);
  SavedElements:=TList.Create;
  SavedPropertyEditors:=TList.Create;
end;

destructor TListPropertyEditor.Destroy;
begin
  UnregisterListPropertyEditor(Self);
  FreeElementPropertyEditors;
  FreeAndNil(SavedPropertyEditors);
  FreeAndNil(SavedElements);
  inherited Destroy;
end;

function TListPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result:= [paSubProperties, paDynamicSubProps, paReadOnly, paDialog];
end;

procedure TListPropertyEditor.GetProperties(Proc: TGetPropEditProc);
var
  i, ElementCount: integer;
begin
  SaveElements;
  ElementCount:=GetElementCount;
  for i:=0 to ElementCount-1 do
    Proc(GetElementPropEditor(i));
end;

function TListPropertyEditor.GetValue: AnsiString;
var
  ElementCount: integer;
begin
  ElementCount:=GetElementCount;
  if ElementCount<>1 then
    Result:=IntToStr(GetElementCount)+' items'
  else
    Result:='1 item';
end;

procedure TListPropertyEditor.Initialize;
begin
  inherited Initialize;
  RegisterListPropertyEditor(Self);
  SaveElements;
end;


const
  CollectionForm: TCollectionPropertyEditorForm = nil;

//  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

function TCollectionPropertyEditor.ReadElement(Index: integer): TPersistent;
var
  Collection: TCollection;
begin
  Collection:=TCollection(GetObjectValue);
  Result:=Collection.Items[Index];
end;

function TCollectionPropertyEditor.GetElementAttributes(
  Element: TListElementPropertyEditor): TPropertyAttributes;
begin
  Result := [paSubProperties, paReadOnly];
end;

function TCollectionPropertyEditor.GetElementName(
  Element: TListElementPropertyEditor): shortstring;
begin
  Result:=inherited GetElementName(Element);
end;

procedure TCollectionPropertyEditor.GetElementProperties(
  Element: TListElementPropertyEditor; Proc: TGetPropEditProc);
begin
  GetPersistentProperties(GetElement(Element),tkProperties,PropertyHook,Proc,nil);
end;

function TCollectionPropertyEditor.GetElementValue(
  Element: TListElementPropertyEditor): ansistring;
begin
  Result:=IntToStr(TCollectionItem(GetElement(Element)).ID);
end;

procedure TCollectionPropertyEditor.GetElementValues(
  Element: TListElementPropertyEditor; Proc: TGetStrProc);
begin
  inherited GetElementValues(Element, Proc);
end;

procedure TCollectionPropertyEditor.SetElementValue(
  Element: TListElementPropertyEditor; NewValue: ansistring);
begin
  inherited SetElementValue(Element, NewValue);
end;

function TCollectionPropertyEditor.ReadElementCount: integer;
var
  Collection: TObject;
begin
  Collection := GetObjectValue;
  if Collection is TCollection then
    Result := TCollection(Collection).Count
  else
    Result := 0;
end;

function TCollectionPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paDialog, paReadOnly];
end;

class function TCollectionPropertyEditor.ShowCollectionEditor(
  ACollection: TCollection; 
  OwnerPersistent: TPersistent; 
  const PropName: String): TCustomForm;
begin
  if CollectionForm = nil then
    CollectionForm := TCollectionPropertyEditorForm.Create(Application);
  CollectionForm.SetCollection(ACollection, OwnerPersistent, PropName);
  CollectionForm.actAdd.Visible := true;
  CollectionForm.actDel.Visible := true;
  CollectionForm.AddButton.Left := 0;
  CollectionForm.DeleteButton.Left := 1;
  CollectionForm.DividerToolButton.Show;
  CollectionForm.DividerToolButton.Left := CollectionForm.DeleteButton.Left + 1;
  SetPopupModeParentForPropertyEditor(CollectionForm);
  CollectionForm.EnsureVisible;
  CollectionForm.UpdateButtons;
  Result:=CollectionForm;
end;

procedure TCollectionPropertyEditor.Edit;
var
  TheCollection: TCollection;
begin
  TheCollection := TCollection(GetObjectValue);
  if TheCollection = nil then
    raise Exception.Create('Collection=nil');
  ShowCollectionEditor(TheCollection, GetComponent(0), GetName);
end;

{ TDisabledCollectionPropertyEditor }

function TDisabledCollectionPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paDialog, paReadOnly, paDisableSubProperties];
end;


{ TNoAddDeleteCollectionPropertyEditor }

class function TNoAddDeleteCollectionPropertyEditor.ShowCollectionEditor(
  ACollection: TCollection; OwnerPersistent: TPersistent;
  const PropName: String): TCustomForm;
begin
  if CollectionForm = nil then
    CollectionForm := TCollectionPropertyEditorForm.Create(Application);
  CollectionForm.SetCollection(ACollection, OwnerPersistent, PropName);
  CollectionForm.actAdd.Visible := false;
  CollectionForm.actDel.Visible := false;
  CollectionForm.DividerToolButton.Hide;
  SetPopupModeParentForPropertyEditor(CollectionForm);
  CollectionForm.EnsureVisible;
  CollectionForm.UpdateButtons;
  Result := CollectionForm;
end;


{ TClassPropertyEditor }

constructor TClassPropertyEditor.Create(Hook: TPropertyEditorHook; APropCount: Integer);
begin
  inherited Create(Hook, APropCount);
  FSubPropsTypeFilter := tkAny;
end;

function TClassPropertyEditor.AllEqual: Boolean;
begin
  Result:=True; // ToDo: Maybe all sub-properties should be compared for equality.
end;

destructor TClassPropertyEditor.Destroy;
begin
  FSubProps.Free;
  inherited Destroy;
end;

function TClassPropertyEditor.EditorFilter(const AEditor: TPropertyEditor): Boolean;
begin
  Result := IsInteresting(AEditor, SubPropsTypeFilter, SubPropsNameFilter);
end;

function TClassPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paSubProperties, paReadOnly];
end;

procedure TClassPropertyEditor.GetProperties(Proc: TGetPropEditProc);
var
  selection: TPersistentSelectionList;
begin
  selection := GetSelections;
  if selection = nil then exit;
  GetPersistentProperties(
    selection, SubPropsTypeFilter + [tkClass], PropertyHook, Proc, @EditorFilter);
  selection.Free;
end;

function TClassPropertyEditor.GetSelections: TPersistentSelectionList;
var
  i: Integer;
  subItem: TPersistent;
begin
  Result := TPersistentSelectionList.Create;
  try
    for i := 0 to PropCount - 1 do begin
      subItem := TPersistent(GetObjectValueAt(i));
      if subItem <> nil then
        Result.Add(subItem);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TClassPropertyEditor.GetValue: ansistring;
begin
  if FHideClassName then
    Result:=''
  else
    Result:='(' + GetPropType^.Name + ')';
end;

function TClassPropertyEditor.ValueIsStreamed: boolean;
var
  I: Integer;
begin
  Result := inherited ValueIsStreamed;
  if not Result then
    Exit;

  if FSubProps=nil then
  begin
    FSubProps := TObjectList.Create(True);
    GetProperties(@ListSubProps);
  end;

  for I := 0 to FSubProps.Count-1 do
    if TPropertyEditor(FSubProps[I]).ValueIsStreamed then
      Exit(True);
  Result := False;
end;

procedure TClassPropertyEditor.ListSubProps(Prop: TPropertyEditor);
begin
  FSubProps.Add(Prop);
end;

procedure TClassPropertyEditor.SetSubPropsTypeFilter(const AValue: TTypeKinds);
begin
  if FSubPropsTypeFilter = AValue then exit;
  FSubPropsTypeFilter := AValue;
end;

{ TMethodPropertyEditor }

function TMethodPropertyEditor.AllEqual: Boolean;
var
  I: Integer;
  CurFirstValue, AnotherValue: TMethod;
begin
  Result := False;
  if PropCount > 1 then begin
    CurFirstValue := GetMethodValue;
    for I := 1 to PropCount - 1 do begin
      AnotherValue := GetMethodValueAt(I);
      // Note: compare Code and Data
      if (AnotherValue.Code <> CurFirstValue.Code)
      or (AnotherValue.Data <> CurFirstValue.Data) then
        Exit;
    end;
  end;
  Result := True;
end;

procedure TMethodPropertyEditor.Edit;
{ If the method does not exist in current lookuproot: create it
  Then jump to the source.
  
  For inherited methods this means: A new method is created and a call of
  the ancestor value is added. Then the IDE jumps to the new method body.
}
var
  NewMethodName: String;
  r: TModalResult;
begin
  NewMethodName := GetValue;
  {$IFDEF VerboseMethodPropEdit}
  debugln(['TMethodPropertyEditor.Edit OldValue="',NewMethodName,'" FromLookupRoot=',(LazIsValidIdent(NewMethodName, True, True) and PropertyHook.MethodFromLookupRoot(GetMethodValue))]);
  DumpStack;
  {$ENDIF}
  if IsValidIdent(NewMethodName)
  and PropertyHook.MethodFromLookupRoot(GetMethodValue) then
  begin
    {$IFDEF VerboseMethodPropEdit}
    debugln(['TMethodPropertyEditor.Edit Show']);
    {$ENDIF}
    PropertyHook.ShowMethod(NewMethodName);
  end else begin
    // the current method is from the another class (e.g. ancestor or frame)
    if IsValidIdent(NewMethodName) then
      r:=QuestionDlg('Override or jump',
        'The event "'+GetName+'" currently points to an inherited method.',
        mtConfirmation,[mrYes,'Create Override',mrOk,'Jump to inherited method',mrCancel],
        0)
    else
      r:=mrYes;
    case r of
    mrYes:
      begin
        // -> add an override with the default name
        NewMethodName := GetFormMethodName;
        {$IFDEF VerboseMethodPropEdit}
        debugln(['TMethodPropertyEditor.Edit NewValue="',NewMethodName,'"']);
        {$ENDIF}
        Assert(IsValidIdent(NewMethodName),'Method name "'+NewMethodName+'" must be an identifier');
        NewMethodName:=PropertyHook.LookupRoot.ClassName+'.'+NewMethodName;
        {$IFDEF VerboseMethodPropEdit}
        debugln(['TMethodPropertyEditor.Edit CreateMethod "',NewMethodName,'"...']);
        {$ENDIF}
        SetMethodValue(PropertyHook.CreateMethod(NewMethodName, GetPropType,
                                                 GetComponent(0), GetPropertyPath(0)));
        {$IFDEF VerboseMethodPropEdit}
        debugln(['TMethodPropertyEditor.Edit CHANGED new method=',GetValue]);
        {$ENDIF}
        PropertyHook.RefreshPropertyValues;
        ShowValue;
      end;
    mrOk:
      begin
        // -> jump to ancestor method
        {$IFDEF VerboseMethodPropEdit}
        debugln(['TMethodPropertyEditor.Edit Jump to ancestor method ',NewMethodName]);
        {$ENDIF}
        PropertyHook.ShowMethod(NewMethodName);
      end;
    end;
  end;
end;

procedure TMethodPropertyEditor.ShowValue;
var
  CurMethodName: String;
begin
  CurMethodName:=GetValue;
  PropertyHook.ShowMethod(CurMethodName);
end;

function TMethodPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paDialog, paValueList, paSortList, paRevertable];
end;

function TMethodPropertyEditor.GetEditLimit: Integer;
begin
  Result := 2*MaxIdentLength+1; // clasname.methodname
end;

function TrimNonAscii(const Txt: String): String;
// ToDo: Find a similar function from FPC libs and use it instead.
var
  I: Integer;
begin
  Result := Txt;
  for I := Length(Result) downto 1 do
    if not (
            (Result[I] in ['a'..'z', 'A'..'Z', '_']) or
            (I > 1) and (Result[I] in ['0'..'9'])
           )
    then
      Delete(Result, I, 1);
end;

function TrimDotsAndBrackets(const Txt: String): String;
var
  I: Integer;
begin
  Result := Txt;
  for I := Length(Result) downto 1 do
    if Result[I] in ['.','[',']'] then
      Delete(Result, I, 1);
end;

function TrimEventName(const aName: shortstring): shortstring;
begin
  Result := aName;
  if (Length(Result) >= 2)
  and (Result[1] in ['O','o']) and (Result[2] in ['N','n'])
  then
    Delete(Result, 1, 2);
end;

function TMethodPropertyEditor.GetTrimmedEventName: shortstring;
begin
  Result := TrimEventName(GetName);
end;

function MethodNameSub(Root: TPersistent): shortstring;
begin
  if Root is TCustomForm then
    Result := 'Form'
  else
  if Root is TDataModule then
    Result := 'DataModule'
  else
  if Root is TFrame then
    Result := 'Frame'
  else
    Result := '';
end;

function TMethodPropertyEditor.GetFormMethodName: shortstring;
// returns the default name for a new method
begin
  Result := '';
  if PropertyHook.LookupRoot=nil then exit;
  if GetComponent(0) = PropertyHook.LookupRoot then begin
    Result := MethodNameSub(PropertyHook.LookupRoot);
    if Result = '' then
      Result := ClassNameToComponentName(PropertyHook.GetRootClassName);
  end
  else
    Result := TrimNonAscii(PropertyHook.GetObjectName(GetComponent(0), FOwnerComponent));
  if Result = '' then
    exit;
  Result := Result + GetTrimmedEventName;
end;

class function TMethodPropertyEditor.GetDefaultMethodName(Root, Component: TComponent;
  const RootClassName, ComponentName, PropName: shortstring): shortstring;
// returns the default name for a new method
begin
  Result := '';
  if Root=nil then exit;
  if Component = Root then begin
    Result := MethodNameSub(Root);
    if Result = '' then
      Result := ClassNameToComponentName(RootClassName);
  end
  else
    Result := TrimDotsAndBrackets(ComponentName);
  if Result <> '' then
    Result := Result + TrimEventName(PropName)
  else
    DebugLn(['TMethodPropertyEditor.GetDefaultMethodName cannot create name - should never happen']);
end;

function TMethodPropertyEditor.GetValue: ansistring;
begin
  if Assigned(PropertyHook) then
    Result:=PropertyHook.GetMethodName(GetMethodValue,GetComponent(0))
  else begin
    Result:='';
    debugln(['TMethodPropertyEditor.GetValue : PropertyHook=Nil Name=',GetName,' Data=',dbgs(GetMethodValue.Data)]);
  end;
end;

procedure TMethodPropertyEditor.GetValues(Proc: TGetStrProc);
begin
  //DebugLn('### TMethodPropertyEditor.GetValues');
  Proc(oisNone);
  PropertyHook.GetCompatibleMethods(GetInstProp, Proc);
end;

procedure TMethodPropertyEditor.SetValue(const NewValue: ansistring);
var
  CreateNewMethodSrc: Boolean;
  CurValue: string;
  NewMethodExists, NewMethodIsCompatible, NewMethodIsPublished,
  NewIdentIsMethod: boolean;
  IsNil: Boolean;
  NewMethod: TMethod;
begin
  CurValue := GetValue;
  if CurValue = NewValue then exit;
  {$IFDEF VerboseMethodPropEdit}
  debugln(['TMethodPropertyEditor.SetValue CurValue="',CurValue,'" NewValue="',NewValue,'"']);
  {$ENDIF}
  IsNil := (NewValue='') or (NewValue=oisNone);
  
  if (not IsNil) and (not IsValidIdent(NewValue)) then
  begin
    MessageDlg(oisIncompatibleIdentifier,
      Format(oisIsNotAValidMethodName,[NewValue]),
      mtError, [mbCancel, mbIgnore], 0);
    exit;
  end;

  NewMethodExists := (not IsNil) and
    PropertyHook.CompatibleMethodExists(NewValue, GetInstProp,
                   NewMethodIsCompatible, NewMethodIsPublished, NewIdentIsMethod);
  {$IFDEF VerboseMethodPropEdit}
  debugln(['TMethodPropertyEditor.SetValue NewValue="',NewValue,'" IsCompatible=',NewMethodIsCompatible,' IsPublished=',NewMethodIsPublished,' IsMethod=',NewIdentIsMethod]);
  {$ENDIF}
  if NewMethodExists then
  begin
    if not NewIdentIsMethod then
    begin
      if MessageDlg(oisIncompatibleIdentifier,
        Format(oisTheIdentifierIsNotAMethodPressCancelToUndoPressIgn,
               [NewValue, LineEnding, LineEnding]),
        mtWarning, [mbCancel, mbIgnore], 0)<>mrIgnore
      then
        exit;
    end;
    if not NewMethodIsPublished then
    begin
      if MessageDlg(oisIncompatibleMethod,
        Format(oisTheMethodIsNotPublishedPressCancelToUndoPressIgnor,
               [NewValue, LineEnding, LineEnding]),
        mtWarning, [mbCancel, mbIgnore], 0)<>mrIgnore
      then
        exit;
    end;
    if not NewMethodIsCompatible then
    begin
      if MessageDlg(oisIncompatibleMethod,
        Format(oisTheMethodIsIncompatibleToThisEventPressCancelToUnd,
               [NewValue, GetName, LineEnding, LineEnding]),
          mtWarning, [mbCancel, mbIgnore], 0)<>mrIgnore
      then
        exit;
    end;
  end;

  if IsNil then
  begin
    // clear
    NewMethod.Data := nil;
    NewMethod.Code := nil;
    {$IFDEF VerboseMethodPropEdit}
    debugln(['TMethodPropertyEditor.SetValue SET to NIL']);
    {$ENDIF}
    SetMethodValue(NewMethod);
  end
  else
  if IsValidIdent(CurValue) and
     not NewMethodExists and
     PropertyHook.MethodFromLookupRoot(GetMethodValue) then
  begin
    // rename the method
    // Note:
    //   All other not selected properties that use this method, contain just
    //   the TMethod record. So, changing the name in the jitform will change
    //   all other event names in all other components automatically.
    {$IFDEF VerboseMethodPropEdit}
    debugln(['TMethodPropertyEditor.SetValue RENAME']);
    {$ENDIF}
    PropertyHook.RenameMethod(CurValue, NewValue)
  end else
  begin
    // change value and create method src if needed
    CreateNewMethodSrc := not NewMethodExists;
    {$IFDEF VerboseMethodPropEdit}
    debugln(['TMethodPropertyEditor.SetValue CHANGE new method=',CreateNewMethodSrc]);
    {$ENDIF}
    SetMethodValue(
       PropertyHook.CreateMethod(NewValue, GetPropType,
                                 GetComponent(0), GetPropertyPath(0)));
    {$IFDEF VerboseMethodPropEdit}
    debugln(['TMethodPropertyEditor.SetValue CHANGED new method=',CreateNewMethodSrc]);
    {$ENDIF}
    if CreateNewMethodSrc then
    begin
      {$IFDEF VerboseMethodPropEdit}
      debugln(['TMethodPropertyEditor.SetValue SHOW "',NewValue,'"']);
      {$ENDIF}
      PropertyHook.ShowMethod(NewValue);
    end;
  end;
  {$IFDEF VerboseMethodPropEdit}
  DebugLn('### TMethodPropertyEditor.SetValue END  NewValue=',GetValue);
  {$ENDIF}
end;

{ TPersistentPropertyEditor }

function TPersistentPropertyEditor.FilterFunc(
  const ATestEditor: TPropertyEditor): Boolean;
begin
  Result := not (paNotNestable in ATestEditor.GetAttributes);
end;

function TPersistentPropertyEditor.GetPersistentReference: TPersistent;
begin
  Result := TPersistent(GetObjectValue);
end;

function TPersistentPropertyEditor.GetSelections: TPersistentSelectionList;
begin
  if (GetPersistentReference <> nil) and AllEqual then
    Result := inherited GetSelections
  else
    Result := nil;
end;

function TPersistentPropertyEditor.CheckNewValue(APersistent: TPersistent): boolean;
begin
  Result:=true;
end;

function TPersistentPropertyEditor.ComponentsAllEqual: Boolean;
// Called from AllEqual of TComponentOneFormPropertyEditor and TComponentPropertyEditor.
var
  I: Integer;
  AComponent: TComponent;
begin
  Result:=False;
  AComponent:=TComponent(GetObjectValue);
  if PropCount > 1 then
    for I := 1 to PropCount - 1 do
      if TComponent(GetObjectValueAt(I)) <> AComponent then
        Exit;
  if (PropertyHook<>nil) and PropertyHook.ComponentPropertyOnlyDesign then
    Result:=(AComponent=nil) or (csDesigning in AComponent.ComponentState)
  else
    Result:=true;
end;

function TPersistentPropertyEditor.AllEqual: Boolean;
var
  I: Integer;
  LInstance: TPersistent;
begin
  Result := False;
  LInstance := TPersistent(GetObjectValue);
  if PropCount > 1 then
    for I := 1 to PropCount - 1 do
      if TPersistent(GetObjectValueAt(I)) <> LInstance then
        Exit;
  Result := True;
end;

procedure TPersistentPropertyEditor.Edit;
var
  Temp: TPersistent;
  Designer: TIDesigner;
  AComponent: TComponent;
begin
  Temp := GetPersistentReference;
  if Temp is TComponent then begin
    AComponent:=TComponent(Temp);
    Designer:=FindRootDesigner(AComponent);
    if (Designer<>nil)
    and (Designer.GetShiftState * [ssCtrl, ssLeft] = [ssCtrl, ssLeft]) then
      Designer.SelectOnlyThisComponent(AComponent)
    else
      inherited Edit;
  end else
    inherited Edit;
end;

function TPersistentPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect];
  if Assigned(GetPropInfo^.SetProc) then
    Result := Result + [paValueList, paSortList, paRevertable, paVolatileSubProperties]
  else
    Result := Result + [paReadOnly];
  if GReferenceExpandable and (GetPersistentReference <> nil) and AllEqual then
    Result := Result + [paSubProperties];
end;

function TPersistentPropertyEditor.GetEditLimit: Integer;
begin
  Result := MaxIdentLength;
end;

function TPersistentPropertyEditor.GetValue: AnsiString;
var
  Component: TComponent;
  APersistent: TPersistent;
begin
  Result := '';
  APersistent := GetPersistentReference;
  if APersistent is TComponent then begin
    Component := TComponent(APersistent);
    if Assigned(PropertyHook) then
      Result := PropertyHook.GetComponentName(Component)
    else begin
      if Assigned(Component) then
        Result := Component.Name;
    end;
  end else if APersistent <> nil then
    Result := inherited GetValue;
end;

procedure TPersistentPropertyEditor.GetValues(Proc: TGetStrProc);
begin
  Proc(oisNone);
  if Assigned(PropertyHook) then
    PropertyHook.GetComponentNames(GetTypeData(GetPropType), Proc);
end;

procedure TPersistentPropertyEditor.SetValue(const NewValue: ansistring);
var
  Persistent: TPersistent;
begin
  if NewValue=GetValue then exit;
  Persistent := nil;
  if (NewValue <> '') and (NewValue<>oisNone) then begin
    if Assigned(PropertyHook) then begin
      Persistent := PropertyHook.GetComponent(NewValue);
      if not (Persistent is GetTypeData(GetPropType)^.ClassType) then begin
        raise EPropertyError.Create(oisInvalidPropertyValue);
      end;
    end;
  end;
  if GetPersistentReference=Persistent then exit;
  if not CheckNewValue(Persistent) then exit;
  SetPtrValue(Persistent);
  if Assigned(PropertyHook) then begin
    PropertyHook.ObjectReferenceChanged(Self,Persistent);
  end;
end;

{ TComponentOneFormPropertyEditor }

function TComponentOneFormPropertyEditor.AllEqual: Boolean;
begin
  Result:=ComponentsAllEqual;
end;

procedure TComponentOneFormPropertyEditor.GetValues(Proc: TGetStrProc);

  procedure TraverseComponents(Root: TComponent);
  var
    i: integer;
  begin
    for i := 0 to Root.ComponentCount - 1 do
      if (fIgnoreClass=nil) or not (Root.Components[i] is fIgnoreClass) then
        Proc(Root.Components[i].Name);
  end;

begin
  Proc(oisNone);
  if Assigned(PropertyHook) and (PropertyHook.FLookupRoot is TComponent) then
    TraverseComponents(TComponent(PropertyHook.FLookupRoot));
end;

{ TCoolBarControlPropertyEditor }

constructor TCoolBarControlPropertyEditor.Create(Hook: TPropertyEditorHook; APropCount: Integer);
begin
  inherited Create(Hook, APropCount);
  fIgnoreClass := TCustomCoolBar;
end;

{ TComponentPropertyEditor }

function TComponentPropertyEditor.GetComponentReference: TComponent;
begin
  Result := TComponent(GetObjectValue);
end;

function TComponentPropertyEditor.AllEqual: Boolean;
begin
  Result:=ComponentsAllEqual;
end;

{ TInterfacePropertyEditor }

function TInterfacePropertyEditor.AllEqual: Boolean;
var
  I: Integer;
  Component: TComponent;
begin
  Result := False;
  Component := GetComponentReference;
  if PropCount > 1 then
    for I := 1 to PropCount - 1 do
      if GetComponent(GetIntfValueAt(I)) <> Component then
        Exit;
  if (PropertyHook<>nil) and PropertyHook.ComponentPropertyOnlyDesign then
    Result:=(Component=nil) or (csDesigning in Component.ComponentState)
  else
    Result := True;
end;

procedure TInterfacePropertyEditor.Edit;
var
  Temp: TPersistent;
  Designer: TIDesigner;
  AComponent: TComponent;
begin
  Temp := GetComponentReference;
  if Temp is TComponent then begin
    AComponent:=TComponent(Temp);
    Designer:=FindRootDesigner(AComponent);
    if (Designer<>nil)
    and (Designer.GetShiftState * [ssCtrl, ssLeft] = [ssCtrl, ssLeft]) then
      Designer.SelectOnlyThisComponent(AComponent)
    else
      inherited Edit;
  end else
    inherited Edit;
end;

function TInterfacePropertyEditor.GetAttributes: TPropertyAttributes;
begin
 Result := [paMultiSelect];
  if Assigned(GetPropInfo^.SetProc) then
    Result := Result + [paValueList, paSortList, paRevertable, paVolatileSubProperties]
  else
    Result := Result + [paReadOnly];
  if GReferenceExpandable and (GetComponentReference <> nil) and AllEqual then
    Result := Result + [paSubProperties];
end;

function TInterfacePropertyEditor.GetComponent(const AInterface: IInterface): TComponent;
var
  ComponentRef: IInterfaceComponentReference;
begin
  Result := nil;
  if not Assigned(AInterface) then
    Exit;
  if not Supports(AInterface, IInterfaceComponentReference, ComponentRef) then
    Exit;
  Result := ComponentRef.GetComponent;
end;

function TInterfacePropertyEditor.GetComponentReference: TComponent;
begin
  Result := GetComponent(GetIntfValue);
end;

function TInterfacePropertyEditor.GetSelections: TPersistentSelectionList;
var
  I: Integer;
  SubItem: TPersistent;
begin
  if AllEqual then
  begin
    Result := TPersistentSelectionList.Create;
    try
      for I := 0 to PropCount - 1 do
      begin
        SubItem := GetComponent(GetIntfValueAt(I));
        if Assigned(SubItem) then
          Result.Add(SubItem);
      end;
    except
      Result.Free;
      raise;
    end;
  end
  else
    Result := nil;
end;

procedure TInterfacePropertyEditor.GetValues(Proc: TGetStrProc);

var
  ID: TGUID;

  procedure TraverseComponents(Root: TComponent);
  var
    i: integer;
  begin
    for i := 0 to Root.ComponentCount - 1 do
      if Supports(Root.Components[i], ID) then
        Proc(Root.Components[i].Name);
  end;

begin
  ID := GetTypeData(GetPropType)^.GUID;
  Proc(oisNone);
  if Assigned(PropertyHook) and (PropertyHook.FLookupRoot is TComponent) then
    TraverseComponents(TComponent(PropertyHook.FLookupRoot));
end;

procedure TInterfacePropertyEditor.SetValue(const NewValue: string);
var
  Intf: IInterface;
  Component: TComponent;
begin
  if NewValue = GetValue then
    Exit;
  if (NewValue = '') or (NewValue = oisNone) then
    Intf := nil
  else
  begin
    if Assigned(PropertyHook) then
    begin
      Component := PropertyHook.GetComponent(NewValue);
      if not Assigned(Component) or not Supports(Component, GetTypeData(GetPropType)^.GUID) then
        raise EPropertyError.Create(oisInvalidPropertyValue);
      Intf := Component;
    end
    else
      Intf := nil;
  end;
  SetIntfValue(Intf);
end;

function TInterfacePropertyEditor.GetValue: AnsiString;
var
  Component: TComponent;
begin
  Result := '';
  Component := GetComponentReference;
  if Assigned(Component) then begin
    if Assigned(PropertyHook) then
      Result := PropertyHook.GetComponentName(Component)
    else
      Result := Component.Name;
  end;
end;

{ TComponentNamePropertyEditor }

function TComponentNamePropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [];
end;

function TComponentNamePropertyEditor.GetEditLimit: Integer;
begin
  Result := MaxIdentLength;
end;

function TComponentNamePropertyEditor.GetValue: ansistring;
begin
  Result:=inherited GetValue;
end;

procedure TComponentNamePropertyEditor.SetValue(const NewValue: ansistring);
begin
  if not IsValidIdent(NewValue) then
    raise Exception.Create(Format(oisComponentNameIsNotAValidIdentifier, [NewValue]));
  inherited SetValue(NewValue);
  PropertyHook.ComponentRenamed(TComponent(GetComponent(0)));
end;

{ TDatePropertyEditor }

function TDatePropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paRevertable];
end;

function TDatePropertyEditor.GetValue: string;
var
  DT: TDateTime;
begin
  DT := TDateTime(GetFloatValue);
  if DT = 0.0 then
    Result := ''
  else
    Result := DateToStr(DT);
end;

procedure TDatePropertyEditor.SetValue(const Value: string);
var
  DT: TDateTime;
begin
  if Value = '' then
    DT := 0.0
  else
    DT := StrToDate(Value);
  SetFloatValue(DT);
end;

{ TTimePropertyEditor }

function TTimePropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paRevertable];
end;

function TTimePropertyEditor.GetValue: string;
var
  DT: TDateTime;
begin
  DT := TDateTime(GetFloatValue);
  if DT = 0.0 then Result := '' else
  Result := TimeToStr(DT);
end;

procedure TTimePropertyEditor.SetValue(const Value: string);
var
  DT: TDateTime;
begin
  if Value = '' then DT := 0.0
  else DT := StrToTime(Value);
  SetFloatValue(DT);
end;

{ TDateTimePropertyEditor }

function TDateTimePropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paRevertable];
end;

function TDateTimePropertyEditor.GetValue: string;
var
  DT: TDateTime;
begin
  DT := TDateTime(GetFloatValue);
  if DT = 0.0 then Result := '' else
  Result := DateTimeToStr(DT);
end;

procedure TDateTimePropertyEditor.SetValue(const Value: string);
var
  DT: TDateTime;
  ok: Boolean;
begin
  if Value = '' then DT := 0.0
  else begin
    ok:=false;
    // first try date+time
    try
      DT := StrToDateTime(Value);
      ok:=true;
    except
    end;
    // then try date without time
    if not ok then
      try
        DT := StrToDate(Value);
        ok:=true;
      except
      end;
    // then try time without date
    if not ok then
      try
        DT := StrToTime(Value);
        ok:=true;
      except
      end;
    // if all fails then raise exception
    if not ok then
      StrToDateTime(Value);
  end;
  SetFloatValue(DT);
end;

const
  VarTypeStr: array[0..16] of record
    VarType: Word;
    Name: String;
  end = (
    (VarType: varempty; Name: 'Unassigned'),
    (VarType: varnull; Name: 'Null'),
    (VarType: varsmallint; Name: 'SmallInt'),
    (VarType: varinteger; Name: 'Integer'),
    (VarType: varsingle; Name: 'Single'),
    (VarType: vardouble; Name: 'Double'),
    (VarType: varcurrency; Name: 'Currency'),
    (VarType: vardate; Name: 'Date'),
    (VarType: varolestr; Name: 'OleStr'),
    (VarType: varboolean; Name: 'Boolean'),
    (VarType: varshortint; Name: 'ShortInt'),
    (VarType: varbyte; Name: 'Byte'),
    (VarType: varword; Name: 'Word'),
    (VarType: varlongword; Name: 'LongWord'),
    (VarType: varint64; Name: 'Int64'),
    (VarType: varqword; Name: 'QWord'),
    (VarType: varstring; Name: 'String')
  );

function GetVarTypeName(AVarType: tvartype): String;
var
  I: Integer;
begin
  Result := '';
  for I := Low(VarTypeStr) to High(VarTypeStr) do
    if VarTypeStr[I].VarType = AVarType then
      Exit(VarTypeStr[I].Name);
end;

function GetVarTypeByName(AName: String): tvartype;
var
  I: Integer;
begin
  Result := varempty;
  for I := Low(VarTypeStr) to High(VarTypeStr) do
    if CompareText(VarTypeStr[I].Name, AName) = 0 then
      Exit(VarTypeStr[I].VarType);
end;

type

  { TVarTypeProperty }

  TVarTypeProperty = class(TNestedProperty)
    function GetName: shortstring; override;
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
    function GetValue: ansistring; override;
    procedure SetValue(const NewValue: ansistring); override;
  end;

{ TVarTypeProperty }

function TVarTypeProperty.GetName: shortstring;
begin
  Result := 'Type';
end;

function TVarTypeProperty.GetAttributes: TPropertyAttributes;
begin
  Result := [paValueList];
end;

procedure TVarTypeProperty.GetValues(Proc: TGetStrProc);
var
  I: Integer;
begin
  for I := Low(VarTypeStr) to High(VarTypeStr) do
    Proc(VarTypeStr[I].Name);
end;

function TVarTypeProperty.GetValue: ansistring;
begin
  Result := GetVarTypeName(VarType(GetVarValue));
  if Result = '' then
    Result := 'Unknown'; // Is there resourcestring for that?
end;

procedure TVarTypeProperty.SetValue(const NewValue: ansistring);
var
  V: Variant;
  VT: tvartype;
begin
  V := GetVarValue;
  VT := GetVarTypeByName(NewValue);
  case VT of
    varempty:
      VarClear(V);
    varnull:
      V := Null;
    else
      try
        VarCast(V, V, VT);
      except
        VarClear(V);
      end;
  end;
  SetVarValue(V);
end;

{ TVariantPropertyEditor }

function TVariantPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paSubProperties];
end;

procedure TVariantPropertyEditor.GetProperties(Proc:TGetPropEditProc);
begin
  Proc(TVarTypeProperty.Create(Self));
end;

function TVariantPropertyEditor.GetValue: string;
begin
  if VarType(GetVarValue) <> varnull then
    Result := VarToStrDef(GetVarValue, 'Unknown') // Is there resourcestring for that?
  else
    Result := '(Null)';
end;

procedure TVariantPropertyEditor.SetValue(const Value: string);
var
  V: Variant;
begin
  try
    V := Value;
  except
    V := 0; // Some backup value.
  end;
  SetVarValue(V);
end;


{ TModalResultPropertyEditor }

function TModalResultPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paValueList, paRevertable];
end;

function TModalResultPropertyEditor.OrdValueToVisualValue(OrdValue: longint): string;
var
  CurValue: Longint;
begin
  CurValue := OrdValue;
  case CurValue of
    Low(ModalResultStr)..High(ModalResultStr):
      Result := ModalResultStr[CurValue];
  else
    Result := IntToStr(CurValue);
  end;
end;

procedure TModalResultPropertyEditor.GetValues(Proc: TGetStrProc);
var
  I: Integer;
begin
  for I := Low(ModalResultStr) to High(ModalResultStr) do Proc(ModalResultStr[I]);
end;

procedure TModalResultPropertyEditor.SetValue(const NewValue: ansistring);
var
  I: Integer;
begin
  if NewValue = '' then begin
    SetOrdValue(0);
    Exit;
  end;
  for I := Low(ModalResultStr) to High(ModalResultStr) do
    if CompareText(ModalResultStr[I], NewValue) = 0 then
    begin
      SetOrdValue(I);
      Exit;
    end;
  inherited SetValue(NewValue);
end;

{ TShortCutPropertyEditor }

const
  ShortCuts: array[0..135] of TShortCut = (
    scNone,
    Byte('A') or scCtrl,
    Byte('B') or scCtrl,
    Byte('C') or scCtrl,
    Byte('D') or scCtrl,
    Byte('E') or scCtrl,
    Byte('F') or scCtrl,
    Byte('G') or scCtrl,
    Byte('H') or scCtrl,
    Byte('I') or scCtrl,
    Byte('J') or scCtrl,
    Byte('K') or scCtrl,
    Byte('L') or scCtrl,
    Byte('M') or scCtrl,
    Byte('N') or scCtrl,
    Byte('O') or scCtrl,
    Byte('P') or scCtrl,
    Byte('Q') or scCtrl,
    Byte('R') or scCtrl,
    Byte('S') or scCtrl,
    Byte('T') or scCtrl,
    Byte('U') or scCtrl,
    Byte('V') or scCtrl,
    Byte('W') or scCtrl,
    Byte('X') or scCtrl,
    Byte('Y') or scCtrl,
    Byte('Z') or scCtrl,
    Byte('A') or scMeta,
    Byte('B') or scMeta,
    Byte('C') or scMeta,
    Byte('D') or scMeta,
    Byte('E') or scMeta,
    Byte('F') or scMeta,
    Byte('G') or scMeta,
    Byte('H') or scMeta,
    Byte('I') or scMeta,
    Byte('J') or scMeta,
    Byte('K') or scMeta,
    Byte('L') or scMeta,
    Byte('M') or scMeta,
    Byte('N') or scMeta,
    Byte('O') or scMeta,
    Byte('P') or scMeta,
    Byte('Q') or scMeta,
    Byte('R') or scMeta,
    Byte('S') or scMeta,
    Byte('T') or scMeta,
    Byte('U') or scMeta,
    Byte('V') or scMeta,
    Byte('W') or scMeta,
    Byte('X') or scMeta,
    Byte('Y') or scMeta,
    Byte('Z') or scMeta,
    Byte('A') or scCtrl or scAlt,
    Byte('B') or scCtrl or scAlt,
    Byte('C') or scCtrl or scAlt,
    Byte('D') or scCtrl or scAlt,
    Byte('E') or scCtrl or scAlt,
    Byte('F') or scCtrl or scAlt,
    Byte('G') or scCtrl or scAlt,
    Byte('H') or scCtrl or scAlt,
    Byte('I') or scCtrl or scAlt,
    Byte('J') or scCtrl or scAlt,
    Byte('K') or scCtrl or scAlt,
    Byte('L') or scCtrl or scAlt,
    Byte('M') or scCtrl or scAlt,
    Byte('N') or scCtrl or scAlt,
    Byte('O') or scCtrl or scAlt,
    Byte('P') or scCtrl or scAlt,
    Byte('Q') or scCtrl or scAlt,
    Byte('R') or scCtrl or scAlt,
    Byte('S') or scCtrl or scAlt,
    Byte('T') or scCtrl or scAlt,
    Byte('U') or scCtrl or scAlt,
    Byte('V') or scCtrl or scAlt,
    Byte('W') or scCtrl or scAlt,
    Byte('X') or scCtrl or scAlt,
    Byte('Y') or scCtrl or scAlt,
    Byte('Z') or scCtrl or scAlt,
    VK_F1,
    VK_F2,
    VK_F3,
    VK_F4,
    VK_F5,
    VK_F6,
    VK_F7,
    VK_F8,
    VK_F9,
    VK_F10,
    VK_F11,
    VK_F12,
    VK_F1 or scCtrl,
    VK_F2 or scCtrl,
    VK_F3 or scCtrl,
    VK_F4 or scCtrl,
    VK_F5 or scCtrl,
    VK_F6 or scCtrl,
    VK_F7 or scCtrl,
    VK_F8 or scCtrl,
    VK_F9 or scCtrl,
    VK_F10 or scCtrl,
    VK_F11 or scCtrl,
    VK_F12 or scCtrl,
    VK_F1 or scShift,
    VK_F2 or scShift,
    VK_F3 or scShift,
    VK_F4 or scShift,
    VK_F5 or scShift,
    VK_F6 or scShift,
    VK_F7 or scShift,
    VK_F8 or scShift,
    VK_F9 or scShift,
    VK_F10 or scShift,
    VK_F11 or scShift,
    VK_F12 or scShift,
    VK_F1 or scShift or scCtrl,
    VK_F2 or scShift or scCtrl,
    VK_F3 or scShift or scCtrl,
    VK_F4 or scShift or scCtrl,
    VK_F5 or scShift or scCtrl,
    VK_F6 or scShift or scCtrl,
    VK_F7 or scShift or scCtrl,
    VK_F8 or scShift or scCtrl,
    VK_F9 or scShift or scCtrl,
    VK_F10 or scShift or scCtrl,
    VK_F11 or scShift or scCtrl,
    VK_F12 or scShift or scCtrl,
    VK_INSERT,
    VK_INSERT or scShift,
    VK_INSERT or scCtrl,
    VK_DELETE,
    VK_DELETE or scShift,
    VK_DELETE or scCtrl,
    VK_BACK or scAlt,
    VK_BACK or scShift or scAlt,
    VK_ESCAPE);

procedure TShortCutPropertyEditor.Edit;
var
  Box: TShortCutGrabBox;
  OldValue, NewValue: TShortCut;
  OldKey: Word;
  OldShift: TShiftState;
  Dlg: TForm;
  BtnPanel: TButtonPanel;
begin
  Dlg:=TForm.Create(Application);
  try
    Dlg.BorderIcons:=[biSystemMenu];
    Dlg.Caption:=oisSelectShortCut;
    Dlg.Position:=poScreenCenter;
    Dlg.Constraints.MinWidth:=350;
    Dlg.Constraints.MinHeight:=30;
    Dlg.Width:=350;
    Dlg.Height:=120;

    Box:=TShortCutGrabBox.Create(Dlg);
    Box.BorderSpacing.Around:=6;
    Box.Parent:=Dlg;
    Box.Align:=alClient;
    OldValue := TShortCut(GetOrdValue);
    ShortCutToKey(OldValue,OldKey,OldShift);
    Box.ShiftState:=OldShift;
    Box.Key:=OldKey;

    BtnPanel:=TButtonPanel.Create(Dlg);
    BtnPanel.Parent:=Dlg;
    BtnPanel.Align:=alBottom;
    BtnPanel.ShowButtons:=[pbOk,pbCancel];

    Dlg.AutoSize:=true;
    if Dlg.ShowModal=mrOk then begin
      NewValue:=Menus.ShortCut(Box.Key,Box.ShiftState);
      if OldValue<>NewValue then
        SetOrdValue(NewValue);
    end;
  finally
    Dlg.Free;
  end;
end;

function TShortCutPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paValueList, paRevertable, paDialog];
end;

function TShortCutPropertyEditor.OrdValueToVisualValue(OrdValue: longint): string;
var
  CurValue: TShortCut;
begin
  CurValue := TShortCut(OrdValue);
  if CurValue = scNone then
    Result := oisNone
  else
    Result := ShortCutToText(CurValue);
end;

procedure TShortCutPropertyEditor.GetValues(Proc: TGetStrProc);
var
  I: Integer;
begin
  Proc(oisNone);
  {$IFDEF Darwin}
    for I := 1 to High(ShortCuts) do Proc(ShortCutToText(ShortCuts[I]));
  {$ELSE}
    for I := 1 to 26 do Proc(ShortCutToText(ShortCuts[I]));
    for I := 53 to High(ShortCuts) do Proc(ShortCutToText(ShortCuts[I]));
  {$ENDIF}
end;

procedure TShortCutPropertyEditor.SetValue(const Value: string);
var
  NewValue: TShortCut;
begin
  NewValue := 0;
  if (Value <> '') and (AnsiCompareText(Value, oisNone) <> 0) then
  begin
    NewValue := TextToShortCut(Value);
    if NewValue = 0 then
      raise EPropertyError.Create(oisInvalidPropertyValue);
  end;
  SetOrdValue(NewValue);
end;

{ TTabOrderPropertyEditor }

function TTabOrderPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [];
end;

{ TCaptionPropertyEditor }

function TCaptionPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paAutoUpdate, paRevertable];
end;

{ TMenuItemCaptionEditor }

procedure TMenuItemCaptionEditor.SetValue(const NewValue: ansistring);
var
  Designer: TIDesigner;
  MI: TMenuItem;
  Inst: TPersistent;
begin
  Inst := GetComponent(0);
  if (NewValue = cLineCaption) and (Inst is TMenuItem) then
  begin
    MI := TMenuItem(Inst);
    if AnsiStartsStr('MenuItem', MI.Name) then
    begin
      Designer:=FindRootDesigner(MI);
      if Designer<>nil then
        MI.Name:=Designer.UniqueName('N');
    end;
  end;
  SetStrValue(NewValue);
end;

{ TStringsPropertyEditor }

procedure TStringsPropertyEditor.Edit;
var
  TheDialog: TStringsPropEditorDlg;
begin
  TheDialog := CreateDlg(TStrings(GetObjectValue));
  try
    if (TheDialog.ShowModal = mrOK) then 
      SetPtrValue(TheDialog.Memo.Lines);
  finally
    TheDialog.Free;
  end;
end;

function TStringsPropertyEditor.CreateDlg(s: TStrings): TStringsPropEditorDlg;
begin
  Result := TStringsPropEditorDlg.Create(Application);
  Result.Editor := Self;
  Result.Memo.Text := s.Text;
  Result.MemoChange(nil); // force call OnChange event
end;

function TStringsPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paDialog, paRevertable, paReadOnly];
end;

{ TValueListPropertyEditor }

procedure TValueListPropertyEditor.Edit;
var
  TheDialog: TKeyValPropEditorDlg;
begin
  TheDialog := CreateDlg(TStrings(GetObjectValue));
  try
    if (TheDialog.ShowModal = mrOK) then
      SetPtrValue(TheDialog.ValueListEdit.Strings);
  finally
    TheDialog.Free;
  end;
end;

function TValueListPropertyEditor.CreateDlg(s: TStrings): TKeyValPropEditorDlg;
begin
  Result := TKeyValPropEditorDlg.Create(Application);
  Result.Editor := Self;
  Result.ValueListEdit.Strings.Assign(s);
  Result.ValueListEdit.Invalidate;
end;

function TValueListPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paDialog, paRevertable, paReadOnly];
end;

{ TStringMultilinePropertyEditor }

procedure TStringMultilinePropertyEditor.Edit;
var
  TheDialog : TStringsPropEditorDlg;
  AString : string;
  LineEndPos: Integer;
begin
  AString := GetStrValue;
  TheDialog := TStringsPropEditorDlg.Create(nil);
  try
    TheDialog.Editor := Self;
    TheDialog.Memo.Text := AString;
    TheDialog.MemoChange(nil);
    if (TheDialog.ShowModal = mrOK) then
    begin
      AString := TheDialog.Memo.Text;
      LineEndPos := Length(AString) - Length(LineEnding) + 1;
      //erase the last lineending if any
      if Copy(AString, LineEndPos, Length(LineEnding)) = LineEnding then
        Delete(AString, LineEndPos, Length(LineEnding));
      SetStrValue(AString);
    end;
  finally
    TheDialog.Free;
  end;
end;

function TStringMultilinePropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paDialog, paRevertable, paAutoUpdate];
end;

{ TCursorPropertyEditor }

function TCursorPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paMultiSelect, paSortList, paValueList, paRevertable];
end;

function TCursorPropertyEditor.OrdValueToVisualValue(OrdValue: longint): string;
begin
  Result := CursorToString(TCursor(OrdValue));
end;

procedure TCursorPropertyEditor.GetValues(Proc: TGetStrProc);
begin
  GetCursorValues(Proc);
end;

procedure TCursorPropertyEditor.SetValue(const NewValue: ansistring);
var
  CValue: Longint;
begin
  CValue:=0;
  if IdentToCursor(NewValue, CValue) then
    SetOrdValue(CValue)
  else
    inherited SetValue(NewValue);
end;

{ TFileNamePropertyEditor }

function TFileNamePropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result:=[paDialog,paRevertable];
end;

procedure TFileNamePropertyEditor.Edit;
begin
  With CreateFileDialog do
    Try
      Filter:=GetFilter;
      Options:=GetDialogOptions;
      FileName:=GetStrValue;
      InitialDir:=GetInitialDirectory;
      Title:=GetDialogTitle;
      If Execute then
        SetFilename(Filename);
    Finally
      Free;
    end;
end;

function TFileNamePropertyEditor.GetFilter: String;
begin
  Result:=oisAllFiles+' ('+GetAllFilesMask+')|'+GetAllFilesMask;
end;

function TFileNamePropertyEditor.GetDialogOptions: TOpenOptions;
begin
  Result:=DefaultOpenDialogOptions;
end;

function TFileNamePropertyEditor.GetDialogTitle: string;
begin
  Result:=oisSelectAFile;
end;

function TFileNamePropertyEditor.GetInitialDirectory: string;
begin
  Result:='';
end;

procedure TFileNamePropertyEditor.SetFilename(const Filename: string);
begin
  SetStrValue(Filename);
end;

function TFileNamePropertyEditor.CreateFileDialog: TOpenDialog;
begin
  Result:=TOpenDialog.Create(nil);
end;

{ TDirectoryPropertyEditor }

function TDirectoryPropertyEditor.CreateFileDialog: TOpenDialog;
begin
  Result:=TSelectDirectoryDialog.Create(nil);
  Result.Options:=Result.Options+[ofFileMustExist];
end;

{ TURLPropertyEditor }

procedure TURLPropertyEditor.SetFilename(const Filename: string);

  function FilenameToURL(const Filename: string): string;
  var
    i: Integer;
  begin
    Result:=Filename;
    {$push}
    {$warnings off}
    if PathDelim<>'/' then
      for i:=1 to length(Result) do
        if Result[i]=PathDelim then
          Result[i]:='/';
    {$pop}
    if Result<>'' then
      Result:='file://'+Result;
  end;

begin
  inherited SetFilename(FilenameToURL(Filename));
end;

{ TURLDirectoryPropertyEditor }

function TURLDirectoryPropertyEditor.CreateFileDialog: TOpenDialog;
begin
  Result:=TSelectDirectoryDialog.Create(nil);
  Result.Options:=Result.Options+[ofFileMustExist];
end;

{ TFileDlgFilterProperty }

function TFileDlgFilterProperty.GetAttributes: TPropertyAttributes;
begin
  Result:=inherited GetAttributes + [paDialog];
end;

procedure TFileDlgFilterProperty.Edit;
begin
  with TFileFilterPropEditForm.Create(Application) do
  try
    Filter:=GetStrProp(GetComponent(0), 'Filter');
    if ShowModal=mrOk then begin
      SetStrValue(Filter);
      Modified('Filter');
    end;
  finally
    Free;
  end;
end;

{ TSessionPropertiesPropertyEditor }

function TSessionPropertiesPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result:=[paDialog,paRevertable,paReadOnly];
end;

procedure TSessionPropertiesPropertyEditor.Edit;
begin
  With TSelectPropertiesForm.Create(Application) do
    Try
      PropertyComponent:=GetComponent(0) as TComponent;
      SelectedProperties:=GetStrValue;
      Caption:=Format(oisPropertiesOf, [TComponent(GetComponent(0)).Name]);
      If (ShowModal=mrOK) then
        SetStrValue(SelectedProperties);
    Finally
      Free;
    end;
end;

{ TConstraintsPropertyEditor }

function TConstraintsPropertyEditor.GetVerbCount: Integer;
begin
  Result:=2;
end;

function TConstraintsPropertyEditor.GetVerb(Index: Integer): string;
var
  s: String;
  c: TControl;
begin
  case Index of
    0: s := oisSetMaxConstraints;
    1: s := oisSetMinConstraints;
    else s := '';
  end;
  c := GetComponent(0) as TControl;
  Result := Format(s, [c.Height, c.Width]);
end;

procedure TConstraintsPropertyEditor.PrepareItem(Index: Integer;
  const AnItem: TMenuItem);
var
  c: TControl;
begin
  c := GetComponent(0) as TControl;
  case Index of
  0:
    begin
      // set max constraints
      AnItem.Enabled := (c.Constraints.MaxHeight<>c.Height)
                     or (c.Constraints.MaxWidth<>c.Width);
      AnItem.Hint := oisSetMaxConstraintsHint;
    end;
  1:
    begin
      // set min constraints
      AnItem.Enabled := (c.Constraints.MinHeight<>c.Height)
                      or (c.Constraints.MinWidth<>c.Width);
      AnItem.Hint := oisSetMinConstraintsHint;
    end;
  end;
end;

procedure TConstraintsPropertyEditor.ExecuteVerb(Index: Integer);
var
  c: TControl;
begin
  c := GetComponent(0) as TControl;
  case Index of
    0: begin
      c.Constraints.MaxHeight := c.Height;
      c.Constraints.MaxWidth := c.Width;
    end;
    1: begin
      c.Constraints.MinHeight := c.Height;
      c.Constraints.MinWidth := c.Width;
    end;
  end;
end;


//==============================================================================


{ TPropertyEditorHook }

function TPropertyEditorHook.CreateMethod(const aName: ShortString;
  ATypeInfo: PTypeInfo; APersistent: TPersistent; const APropertyPath: string
  ): TMethod;
var
  i: Integer;
  Handler: TPropHookCreateMethod;
begin
  Result.Code := nil;
  Result.Data := nil;
  if LazIsValidIdent(aName,true,true) and Assigned(ATypeInfo) then
  begin
    i := GetHandlerCount(htCreateMethod);
    while GetNextHandlerIndex(htCreateMethod, i) do
    begin
      Handler := TPropHookCreateMethod(FHandlers[htCreateMethod][i]);
      Result := Handler(aName, ATypeInfo, APersistent, APropertyPath);
      if Assigned(Result.Data) or Assigned(Result.Code) then exit;
    end;
  end;
end;

function TPropertyEditorHook.GetMethodName(const Method: TMethod;
  PropOwner: TObject): String;
var
  i: Integer;
begin
  i:=GetHandlerCount(htGetMethodName);
  if GetNextHandlerIndex(htGetMethodName,i) then begin
    Result:=TPropHookGetMethodName(FHandlers[htGetMethodName][i])(Method,PropOwner,LookupRoot);
  end else begin
    // search the method name with the given code pointer
    if Assigned(Method.Code) then begin
      if Method.Data<>nil then begin
        Result:=TObject(Method.Data).MethodName(Method.Code);
        if Result='' then
          Result:='<Unpublished>';
      end else
        Result:='<No LookupRoot>';
    end else
      Result:='';
  end;
end;

procedure TPropertyEditorHook.GetMethods(TypeData: PTypeData;
  const Proc: TGetStrProc);
var
  i: Integer;
begin
  i:=GetHandlerCount(htGetMethods);
  while GetNextHandlerIndex(htGetMethods,i) do
    TPropHookGetMethods(FHandlers[htGetMethods][i])(TypeData,Proc);
end;

procedure TPropertyEditorHook.GetCompatibleMethods(InstProp: PInstProp;
  const Proc: TGetStrProc);
var
  i: Integer;
begin
  i:=GetHandlerCount(htGetCompatibleMethods);
  while GetNextHandlerIndex(htGetCompatibleMethods,i) do
    TPropHookGetCompatibleMethods(FHandlers[htGetCompatibleMethods][i])(InstProp,Proc);
end;

function TPropertyEditorHook.MethodExists(const aName: String;
  TypeData: PTypeData;
  var MethodIsCompatible, MethodIsPublished, IdentIsMethod: boolean):boolean;
var
  i: Integer;
  Handler: TPropHookMethodExists;
begin
  // check if a published method with given aName exists in LookupRoot
  Result:=IsValidIdent(aName) and Assigned(FLookupRoot);
  if not Result then exit;
  i:=GetHandlerCount(htMethodExists);
  if i>=0 then begin
    while GetNextHandlerIndex(htMethodExists,i) do begin
      Handler:=TPropHookMethodExists(FHandlers[htMethodExists][i]);
      Result:=Handler(aName,TypeData,
                            MethodIsCompatible,MethodIsPublished,IdentIsMethod);
    end;
  end else begin
    Result:=(LookupRoot.MethodAddress(aName)<>nil);
    MethodIsCompatible:=Result;
    MethodIsPublished:=Result;
    IdentIsMethod:=Result;
  end;
end;

function TPropertyEditorHook.CompatibleMethodExists(const aName: String;
  InstProp: PInstProp; out MethodIsCompatible, MethodIsPublished,
  IdentIsMethod: boolean): boolean;
var
  i: Integer;
  Handler: TPropHookCompatibleMethodExists;
begin
  MethodIsCompatible:=false;
  MethodIsPublished:=false;
  IdentIsMethod:=false;
  // check if a published method with given aName exists in LookupRoot
  Result:=IsValidIdent(aName) and Assigned(FLookupRoot);
  if not Result then exit;
  i:=GetHandlerCount(htCompatibleMethodExists);
  if i>=0 then begin
    while GetNextHandlerIndex(htCompatibleMethodExists,i) do begin
      Handler:=TPropHookCompatibleMethodExists(FHandlers[htCompatibleMethodExists][i]);
      Result:=Handler(aName,InstProp,
                            MethodIsCompatible,MethodIsPublished,IdentIsMethod);
    end;
  end else begin
    Result:=(LookupRoot.MethodAddress(aName)<>nil);
    MethodIsCompatible:=Result;
    MethodIsPublished:=Result;
    IdentIsMethod:=Result;
  end;
end;

procedure TPropertyEditorHook.RenameMethod(const CurName, NewName: String);
// rename published method in LookupRoot object and source
var
  i: Integer;
begin
  i:=GetHandlerCount(htRenameMethod);
  while GetNextHandlerIndex(htRenameMethod,i) do
    TPropHookRenameMethod(FHandlers[htRenameMethod][i])(CurName,NewName);
end;

procedure TPropertyEditorHook.ShowMethod(const aName: String);
// jump cursor to published method body
var
  i: Integer;
begin
  i:=GetHandlerCount(htShowMethod);
  while GetNextHandlerIndex(htShowMethod,i) do
    TPropHookShowMethod(FHandlers[htShowMethod][i])(aName);
end;

function TPropertyEditorHook.MethodFromAncestor(const Method: TMethod): boolean;
var
  AncestorClass: TClass;
  i: Integer;
  Handler: TPropHookMethodFromAncestor;
begin
  // check if given Method is not in LookupRoot source,
  // but in one of its ancestors
  i := GetHandlerCount(htMethodFromAncestor);
  if GetNextHandlerIndex(htMethodFromAncestor, i) then
  begin
    Handler := TPropHookMethodFromAncestor(FHandlers[htMethodFromAncestor][i]);
    Result := Handler(Method);
  end
  else
  begin
    Result := Assigned(Method.Data) and Assigned(Method.Code);
    if Result then
    begin
      AncestorClass := TObject(Method.Data).ClassParent;
      Result := Assigned(AncestorClass) and (AncestorClass.MethodName(Method.Code)<>'');
    end;
  end;
end;

function TPropertyEditorHook.MethodFromLookupRoot(const Method: TMethod
  ): boolean;
var
  Root: TPersistent;
  i: Integer;
  Handler: TPropHookMethodFromLookupRoot;
begin
  // check if given Method is in LookupRoot source,
  Root:=LookupRoot;
  if Root=nil then exit(false);
  i := GetHandlerCount(htMethodFromLookupRoot);
  if GetNextHandlerIndex(htMethodFromLookupRoot, i) then
  begin
    Handler := TPropHookMethodFromLookupRoot(FHandlers[htMethodFromLookupRoot][i]);
    Result := Handler(Method);
  end
  else
  begin
    Result := (TObject(Method.Data)=Root) and Assigned(Method.Code)
      and (Root.MethodName(Method.Code)<>'');
  end;
end;

procedure TPropertyEditorHook.ChainCall(const AMethodName, InstanceName,
  InstanceMethod: ShortString; TypeData: PTypeData);
var
  i: Integer;
  Handler: TPropHookChainCall;
begin
  i:=GetHandlerCount(htChainCall);
  while GetNextHandlerIndex(htChainCall,i) do begin
    Handler:=TPropHookChainCall(FHandlers[htChainCall][i]);
    Handler(AMethodName,InstanceName,InstanceMethod,TypeData);
  end;
end;

function TPropertyEditorHook.GetComponent(const ComponentPath: string): TComponent;
var
  i: Integer;
begin
  Result := nil;
  if not Assigned(LookupRoot) then
    Exit;
  i := GetHandlerCount(htGetComponent);
  while GetNextHandlerIndex(htGetComponent, i) and (Result = nil) do
    Result := TPropHookGetComponent(FHandlers[htGetComponent][i])(ComponentPath);
  // Note: TWriter only allows pascal identifiers for names, but in general
  // there is no restriction.
  if (Result = nil) and (LookupRoot is TComponent) then
    Result := TComponent(LookupRoot).FindComponent(ComponentPath);
end;

function TPropertyEditorHook.GetComponentName(AComponent: TComponent): String;
var
  i: Integer;
  CompName, OwnerName: String;
  Handler: TPropHookGetComponentName;
begin
  Result := '';
  if AComponent = nil then
    Exit;
  i := GetHandlerCount(htGetComponentName);
  while GetNextHandlerIndex(htGetComponentName, i) and (Result = '') do
  begin
    Handler := TPropHookGetComponentName(FHandlers[htGetComponentName][i]);
    Result := Handler(AComponent);
  end;
  if Result = '' then
  begin
    CompName := AComponent.Name;
    if (AComponent.Owner<>LookupRoot) and (AComponent.Owner<>nil) then
      OwnerName := AComponent.Owner.Name;
{    if CompName='' then
      DebugLn('TPropertyEditorHook.GetComponentName: AComponent.Name is empty, '+
              'AComponent.Owner.Name="' + OwnerName+'".');
    if OwnerName='' then
      DebugLn('TPropertyEditorHook.GetComponentName: AComponent.Owner.Name is empty.');
}
    Result := CompName;
    if OwnerName<>'' then
    begin
      Result := OwnerName;
      if CompName<>'' then
        Result := Result+'.'+CompName;
    end;
  end;
end;

procedure TPropertyEditorHook.GetComponentNames(TypeData: PTypeData;
  const Proc: TGetStrProc);

  procedure TraverseComponents(Root: TComponent);
  var
    i: integer;
  begin
    for i := 0 to Root.ComponentCount - 1 do
      if (Root.Components[i] is TypeData^.ClassType) then
        Proc(Root.Components[i].Name);
  end;

var
  i: integer;
  Handler: TPropHookGetComponentNames;
begin
  if not Assigned(LookupRoot) then
    Exit;
  i := GetHandlerCount(htGetComponentNames);
  if i > 0 then
  begin
    while GetNextHandlerIndex(htGetComponentNames, i) do
    begin
      Handler := TPropHookGetComponentNames(FHandlers[htGetComponentNames][i]);
      Handler(TypeData, Proc);
    end;
  end
  else if LookupRoot is TComponent then
    // No handler -> only traverse local form/datamodule components
    TraverseComponents(TComponent(LookupRoot));
end;

function TPropertyEditorHook.GetRootClassName: ShortString;
var
  i: Integer;
  Handler: TPropHookGetRootClassName;
begin
  Result := '';
  i := GetHandlerCount(htGetRootClassName);
  while GetNextHandlerIndex(htGetRootClassName, i) and (Result = '') do
  begin
    Handler := TPropHookGetRootClassName(FHandlers[htGetRootClassName][i]);
    Result := Handler();
  end;
  if (Result='') and Assigned(LookupRoot) then
    Result := LookupRoot.ClassName;
end;

function TPropertyEditorHook.GetAncestorInstance(const InstProp: TInstProp; out
  AncestorInstProp: TInstProp): boolean;
var
  i: Integer;
  Handler: TPropHookGetAncestorInstProp;
begin
  Result:=false;
  if (InstProp.Instance=nil) or (InstProp.PropInfo=nil) then exit;
  i := GetHandlerCount(htGetAncestorInstProp);
  while GetNextHandlerIndex(htGetAncestorInstProp, i) and (not Result) do
  begin
    Handler := TPropHookGetAncestorInstProp(FHandlers[htGetAncestorInstProp][i]);
    Result := Handler(InstProp,AncestorInstProp);
  end;
end;

function TPropertyEditorHook.AddClicked(ADesigner: TIDesigner;
  MouseDownComponent: TComponent; Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer; var AComponentClass: TComponentClass; var NewParent: TComponent
  ): boolean;
var
  i: Integer;
  Handler: TPropHookAddClicked;
begin
  i := GetHandlerCount(htAddClicked);
  while GetNextHandlerIndex(htAddClicked, i) do
  begin
    Handler := TPropHookAddClicked(FHandlers[htAddClicked][i]);
    Result := Handler(ADesigner,MouseDownComponent,Button,Shift,X,Y,
                      AComponentClass,NewParent);
    if not Result then exit;
    if AComponentClass=nil then
      exit(false);
  end;
  Result := True;
end;

function TPropertyEditorHook.BeforeAddPersistent(Sender: TObject;
  APersistentClass: TPersistentClass; Parent: TPersistent): boolean;
var
  i: Integer;
  Handler: TPropHookBeforeAddPersistent;
begin
  i := GetHandlerCount(htBeforeAddPersistent);
  while GetNextHandlerIndex(htBeforeAddPersistent, i) do
  begin
    Handler := TPropHookBeforeAddPersistent(FHandlers[htBeforeAddPersistent][i]);
    Result := Handler(Sender,APersistentClass,Parent);
    if not Result then exit;
  end;
  Result := True;
end;

procedure TPropertyEditorHook.ComponentRenamed(AComponent: TComponent);
var
  i: Integer;
begin
  i := GetHandlerCount(htComponentRenamed);
  while GetNextHandlerIndex(htComponentRenamed, i) do
    TPropHookComponentRenamed(FHandlers[htComponentRenamed][i])(AComponent);
end;

procedure TPropertyEditorHook.PersistentAdded(APersistent: TPersistent; Select: boolean);
var
  i: Integer;
begin
  i := GetHandlerCount(htPersistentAdded);
  while GetNextHandlerIndex(htPersistentAdded, i) do
    TPropHookPersistentAdded(FHandlers[htPersistentAdded][i])(APersistent, Select);
end;

procedure TPropertyEditorHook.PersistentDeleting(APersistent: TPersistent);
// call this to tell all IDE parts to remove all references from the APersistent
var
  i: Integer;
begin
  i:=GetHandlerCount(htPersistentDeleting);
  while GetNextHandlerIndex(htPersistentDeleting,i) do
    TPropHookPersistentDel(FHandlers[htPersistentDeleting][i])(APersistent);
end;

procedure TPropertyEditorHook.PersistentDeleted(APersistent: TPersistent);
var
  i: Integer;
begin
  i:=GetHandlerCount(htPersistentDeleted);
  while GetNextHandlerIndex(htPersistentDeleted,i) do
    TPropHookPersistentDel(FHandlers[htPersistentDeleted][i])(APersistent);
end;

procedure TPropertyEditorHook.DeletePersistent(var APersistent: TPersistent);
// Call this to actually free APersistent
// One of the hooks will free it.
var
  i: Integer;
begin
  if APersistent=nil then exit;
  i:=GetHandlerCount(htDeletePersistent);
  if i>0 then begin
    while (APersistent<>nil) and GetNextHandlerIndex(htDeletePersistent,i) do
      TPropHookDeletePersistent(FHandlers[htDeletePersistent][i])(APersistent);
  end else
    FreeThenNil(APersistent);
end;

procedure TPropertyEditorHook.GetSelection(const ASelection: TPersistentSelectionList);
var
  i: Integer;
  Handler: TPropHookGetSelection;
begin
  if ASelection=nil then exit;
  ASelection.Clear;
  i:=GetHandlerCount(htGetSelectedPersistents);
  while GetNextHandlerIndex(htGetSelectedPersistents,i) do begin
    Handler:=TPropHookGetSelection(FHandlers[htGetSelectedPersistents][i]);
    Handler(ASelection);
  end;
end;

procedure TPropertyEditorHook.SetSelection(
  const ASelection: TPersistentSelectionList);
var
  i: Integer;
  Handler: TPropHookSetSelection;
  APersistent: TPersistent;
  NewLookupRoot: TPersistent;
begin
  // update LookupRoot
  NewLookupRoot:=LookupRoot;
  if (ASelection<>nil) and (ASelection.Count>0) then begin
    APersistent:=ASelection[0];
    if APersistent<>nil then
      NewLookupRoot:=GetLookupRootForComponent(APersistent);
  end;
  LookupRoot:=NewLookupRoot;
  // set selection
  if ASelection=nil then exit;
  //debulgn(['TPropertyEditorHook.SetSelection A ASelection.Count=',ASelection.Count]);
  i:=GetHandlerCount(htSetSelectedPersistents);
  while GetNextHandlerIndex(htSetSelectedPersistents,i) do begin
    Handler:=TPropHookSetSelection(FHandlers[htSetSelectedPersistents][i]);
    Handler(ASelection);
  end;
  //debugln(['TPropertyEditorHook.SetSelection END ASelection.Count=',ASelection.Count]);
end;

procedure TPropertyEditorHook.Unselect(const APersistent: TPersistent);
var
  Selection: TPersistentSelectionList;
begin
  Selection := TPersistentSelectionList.Create;
  try
    GetSelection(Selection);
    if Selection.IndexOf(APersistent)>=0 then begin
      Selection.Remove(APersistent);
      SetSelection(Selection);
    end;
  finally
    Selection.Free;
  end;
end;

function TPropertyEditorHook.IsSelected(const APersistent: TPersistent): boolean;
var
  Selection: TPersistentSelectionList;
begin
  Selection := TPersistentSelectionList.Create;
  try
    GetSelection(Selection);
    Result:=Selection.IndexOf(APersistent)>=0;
  finally
    Selection.Free;
  end;
end;

procedure TPropertyEditorHook.SelectOnlyThis(const APersistent: TPersistent);
var
  NewSelection: TPersistentSelectionList;
begin
  NewSelection := TPersistentSelectionList.Create;
  try
    if APersistent<>nil then
      NewSelection.Add(APersistent);
    SetSelection(NewSelection);
  finally
    NewSelection.Free;
  end;
end;

procedure TPropertyEditorHook.AddDependency(const AClass: TClass;
  const AnUnitname: shortstring);
var
  i: Integer;
begin
  i:=GetHandlerCount(htAddDependency);
  while GetNextHandlerIndex(htAddDependency,i) do
    TPropHookAddDependency(FHandlers[htAddDependency][i])(AClass,AnUnitName);
end;

function TPropertyEditorHook.GetObject(const aName: ShortString): TPersistent;
var
  i: Integer;
begin
  Result:=nil;
  i:=GetHandlerCount(htGetObject);
  while GetNextHandlerIndex(htGetObject,i) and (Result=nil) do
    Result:=TPropHookGetObject(FHandlers[htGetObject][i])(aName);
end;

function TPropertyEditorHook.GetObjectName(Instance: TPersistent;
  AOwnerComp: TComponent): String;
var
  i: Integer;
begin
  Result:='';
  i:=GetHandlerCount(htGetObjectName);
  if i>0 then begin
    while GetNextHandlerIndex(htGetObjectName,i) and (Result='') do
      Result:=TPropHookGetObjectName(FHandlers[htGetObject][i])(Instance);
  end else
    if Instance is TComponent then
      Result:=TComponent(Instance).Name
    else if instance is TCollectionItem then 
      Result:=TCollectionItem(Instance).GetNamePath
    else begin
      Assert(Assigned(AOwnerComp),'TPropertyEditorHook.GetObjectName: AOwnerComp not assigned.');
      Result:=AOwnerComp.Name + ClassNameToComponentName(Instance.ClassName);
    end;
end;

procedure TPropertyEditorHook.GetObjectNames(TypeData: PTypeData;
  const Proc: TGetStrProc);
var
  i: Integer;
begin
  i:=GetHandlerCount(htGetObjectNames);
  while GetNextHandlerIndex(htGetObjectNames,i) do
    TPropHookGetObjectNames(FHandlers[htGetObjectNames][i])(TypeData,Proc);
end;

procedure TPropertyEditorHook.ObjectReferenceChanged(Sender: TObject;
  NewObject: TPersistent);
var
  i: Integer;
begin
  i:=GetHandlerCount(htObjectPropertyChanged);
  while GetNextHandlerIndex(htObjectPropertyChanged,i) do
    TPropHookObjectPropertyChanged(FHandlers[htObjectPropertyChanged][i])(
                  Sender,NewObject);
end;

procedure TPropertyEditorHook.Modified(Sender: TObject; PropName: ShortString);
var
  i: Integer;
  AForm: TCustomForm;
  Editor: TPropertyEditor;
  List: TFPList;
  APersistent: TPersistent;
  ARoot: TPersistent;
begin
  i := GetHandlerCount(htModified);
  while GetNextHandlerIndex(htModified,i) do
    TPropHookModified(FHandlers[htModified][i])(Sender);

  i := GetHandlerCount(htModifiedWithName);
  while GetNextHandlerIndex(htModifiedWithName,i) do
    TPropHookModifiedWithName(FHandlers[htModifiedWithName][i])(Sender, PropName);

  if Sender is TPropertyEditor then
  begin
    // mark the designer form of every selected persistent
    // ToDo: Use PropName here somehow.
    Editor := TPropertyEditor(Sender);
    List := TFPList.Create;
    try
      for i := 0 to Editor.PropCount - 1 do 
      begin
        // for every selected persistent ...
        APersistent := Editor.GetComponent(i);
        if APersistent = nil then Continue;
        if List.IndexOf(APersistent) >= 0 then Continue;
        List.Add(APersistent);
        // ... get the lookuproot ...
        ARoot := GetLookupRootForComponent(APersistent);
        if ARoot = nil then Continue;
        if (ARoot <> APersistent) and (List.IndexOf(ARoot) >= 0) then Continue;
        List.Add(ARoot);
        // ... get the designer ...
        AForm := GetDesignerForm(ARoot);
        if Assigned(AForm) and Assigned(AForm.Designer) then
          AForm.Designer.Modified; // ... and mark it modified
      end;
    finally
      List.Free;
    end;
  end
  else 
  if Assigned(FLookupRoot) then
  begin
    AForm := GetDesignerForm(FLookupRoot);
    if Assigned(AForm) and Assigned(AForm.Designer) then
      AForm.Designer.Modified;
  end;
end;

procedure TPropertyEditorHook.DesignerMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  i: Integer;
  Handler: TMouseEvent;
begin
  i := GetHandlerCount(htDesignerMouseDown);
  while GetNextHandlerIndex(htDesignerMouseDown, i) do
  begin
    Handler := TMouseEvent(FHandlers[htDesignerMouseDown][i]);
    Handler(Sender, Button,  Shift, X, Y);
  end;
end;

procedure TPropertyEditorHook.DesignerMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  i: Integer;
  Handler: TMouseEvent;
begin
  i := GetHandlerCount(htDesignerMouseUp);
  while GetNextHandlerIndex(htDesignerMouseUp, i) do
  begin
    Handler := TMouseEvent(FHandlers[htDesignerMouseUp][i]);
    Handler(Sender, Button,  Shift, X, Y);
  end;
end;

procedure TPropertyEditorHook.Revert(Instance:TPersistent; PropInfo:PPropInfo);
var
  i: Integer;
begin
  i:=GetHandlerCount(htRevert);
  while GetNextHandlerIndex(htRevert,i) do
    TPropHookRevert(FHandlers[htRevert][i])(Instance,PropInfo);
end;

procedure TPropertyEditorHook.RefreshPropertyValues;
var
  i: Integer;
begin
  i:=GetHandlerCount(htRefreshPropertyValues);
  while GetNextHandlerIndex(htRefreshPropertyValues,i) do
    TPropHookRefreshPropertyValues(FHandlers[htRefreshPropertyValues][i])();
end;

function TPropertyEditorHook.GetCheckboxForBoolean: Boolean;
var
  i: Integer;
begin
  Result:=False;
  i:=GetHandlerCount(htGetCheckboxForBoolean);
  if i > 0 then
    TPropHookGetCheckboxForBoolean(FHandlers[htGetCheckboxForBoolean][0])(Result);
end;

procedure TPropertyEditorHook.RemoveAllHandlersForObject(const HandlerObject: TObject);
var
  HookType: TPropHookType;
begin
  for HookType:=Low(FHandlers) to High(FHandlers) do
    if FHandlers[HookType]<>nil then
      FHandlers[HookType].RemoveAllMethodsOfObject(HandlerObject);
end;

procedure TPropertyEditorHook.AddHandlerChangeLookupRoot(
  const OnChangeLookupRoot: TPropHookChangeLookupRoot);
begin
  AddHandler(htChangeLookupRoot,TMethod(OnChangeLookupRoot));
end;

procedure TPropertyEditorHook.RemoveHandlerChangeLookupRoot(
  const OnChangeLookupRoot: TPropHookChangeLookupRoot);
begin
  RemoveHandler(htChangeLookupRoot,TMethod(OnChangeLookupRoot));
end;

procedure TPropertyEditorHook.AddHandlerCreateMethod(
  const OnCreateMethod: TPropHookCreateMethod);
begin
  AddHandler(htCreateMethod,TMethod(OnCreateMethod));
end;

procedure TPropertyEditorHook.RemoveHandlerCreateMethod(
  const OnCreateMethod: TPropHookCreateMethod);
begin
  RemoveHandler(htCreateMethod,TMethod(OnCreateMethod));
end;

procedure TPropertyEditorHook.AddHandlerGetMethodName(
  const OnGetMethodName: TPropHookGetMethodName);
begin
  AddHandler(htGetMethodName,TMethod(OnGetMethodName));
end;

procedure TPropertyEditorHook.RemoveHandlerGetMethodName(
  const OnGetMethodName: TPropHookGetMethodName);
begin
  RemoveHandler(htGetMethodName,TMethod(OnGetMethodName));
end;

procedure TPropertyEditorHook.AddHandlerGetMethods(
  const OnGetMethods: TPropHookGetMethods);
begin
  AddHandler(htGetMethods,TMethod(OnGetMethods));
end;

procedure TPropertyEditorHook.RemoveHandlerGetMethods(
  const OnGetMethods: TPropHookGetMethods);
begin
  RemoveHandler(htGetMethods,TMethod(OnGetMethods));
end;

procedure TPropertyEditorHook.AddHandlerCompatibleMethodExists(
  const OnMethodExists: TPropHookCompatibleMethodExists);
begin
  AddHandler(htCompatibleMethodExists,TMethod(OnMethodExists));
end;

procedure TPropertyEditorHook.RemoveHandlerCompatibleMethodExists(
  const OnMethodExists: TPropHookCompatibleMethodExists);
begin
  RemoveHandler(htCompatibleMethodExists,TMethod(OnMethodExists));
end;

procedure TPropertyEditorHook.AddHandlerGetCompatibleMethods(
  const OnGetMethods: TPropHookGetCompatibleMethods);
begin
  AddHandler(htGetCompatibleMethods,TMethod(OnGetMethods));
end;

procedure TPropertyEditorHook.RemoveHandlerGetCompatibleMethods(
  const OnGetMethods: TPropHookGetCompatibleMethods);
begin
  RemoveHandler(htGetCompatibleMethods,TMethod(OnGetMethods));
end;

procedure TPropertyEditorHook.AddHandlerMethodExists(
  const OnMethodExists: TPropHookMethodExists);
begin
  AddHandler(htMethodExists,TMethod(OnMethodExists));
end;

procedure TPropertyEditorHook.RemoveHandlerMethodExists(
  const OnMethodExists: TPropHookMethodExists);
begin
  RemoveHandler(htMethodExists,TMethod(OnMethodExists));
end;

procedure TPropertyEditorHook.AddHandlerRenameMethod(
  const OnRenameMethod: TPropHookRenameMethod);
begin
  AddHandler(htRenameMethod,TMethod(OnRenameMethod));
end;

procedure TPropertyEditorHook.RemoveHandlerRenameMethod(
  const OnRenameMethod: TPropHookRenameMethod);
begin
  RemoveHandler(htRenameMethod,TMethod(OnRenameMethod));
end;

procedure TPropertyEditorHook.AddHandlerShowMethod(
  const OnShowMethod: TPropHookShowMethod);
begin
  AddHandler(htShowMethod,TMethod(OnShowMethod));
end;

procedure TPropertyEditorHook.RemoveHandlerShowMethod(
  const OnShowMethod: TPropHookShowMethod);
begin
  RemoveHandler(htShowMethod,TMethod(OnShowMethod));
end;

procedure TPropertyEditorHook.AddHandlerMethodFromAncestor(
  const OnMethodFromAncestor: TPropHookMethodFromAncestor);
begin
  AddHandler(htMethodFromAncestor,TMethod(OnMethodFromAncestor));
end;

procedure TPropertyEditorHook.RemoveHandlerMethodFromAncestor(
  const OnMethodFromAncestor: TPropHookMethodFromAncestor);
begin
  RemoveHandler(htMethodFromAncestor,TMethod(OnMethodFromAncestor));
end;

procedure TPropertyEditorHook.AddHandlerMethodFromLookupRoot(
  const OnMethodFromLookupRoot: TPropHookMethodFromLookupRoot);
begin
  AddHandler(htMethodFromLookupRoot,TMethod(OnMethodFromLookupRoot));
end;

procedure TPropertyEditorHook.RemoveHandlerMethodFromLookupRoot(
  const OnMethodFromLookupRoot: TPropHookMethodFromLookupRoot);
begin
  RemoveHandler(htMethodFromLookupRoot,TMethod(OnMethodFromLookupRoot));
end;

procedure TPropertyEditorHook.AddHandlerChainCall(
  const OnChainCall: TPropHookChainCall);
begin
  AddHandler(htChainCall,TMethod(OnChainCall));
end;

procedure TPropertyEditorHook.RemoveHandlerChainCall(
  const OnChainCall: TPropHookChainCall);
begin
  RemoveHandler(htChainCall,TMethod(OnChainCall));
end;

procedure TPropertyEditorHook.AddHandlerGetComponent(
  const OnGetComponent: TPropHookGetComponent);
begin
  AddHandler(htGetComponent,TMethod(OnGetComponent));
end;

procedure TPropertyEditorHook.RemoveHandlerGetComponent(
  const OnGetComponent: TPropHookGetComponent);
begin
  RemoveHandler(htGetComponent,TMethod(OnGetComponent));
end;

procedure TPropertyEditorHook.AddHandlerGetComponentName(
  const OnGetComponentName: TPropHookGetComponentName);
begin
  AddHandler(htGetComponentName,TMethod(OnGetComponentName));
end;

procedure TPropertyEditorHook.RemoveHandlerGetComponentName(
  const OnGetComponentName: TPropHookGetComponentName);
begin
  RemoveHandler(htGetComponentName,TMethod(OnGetComponentName));
end;

procedure TPropertyEditorHook.AddHandlerGetComponentNames(
  const OnGetComponentNames: TPropHookGetComponentNames);
begin
  AddHandler(htGetComponentNames,TMethod(OnGetComponentNames));
end;

procedure TPropertyEditorHook.RemoveHandlerGetComponentNames(
  const OnGetComponentNames: TPropHookGetComponentNames);
begin
  RemoveHandler(htGetComponentNames,TMethod(OnGetComponentNames));
end;

procedure TPropertyEditorHook.AddHandlerAddClicked(
  const Handler: TPropHookAddClicked);
begin
  AddHandler(htAddClicked,TMethod(Handler));
end;

procedure TPropertyEditorHook.RemoveHandlerAddClicked(
  const Handler: TPropHookAddClicked);
begin
  RemoveHandler(htAddClicked,TMethod(Handler));
end;

procedure TPropertyEditorHook.AddHandlerGetRootClassName(
  const OnGetRootClassName: TPropHookGetRootClassName);
begin
  AddHandler(htGetRootClassName,TMethod(OnGetRootClassName));
end;

procedure TPropertyEditorHook.RemoveHandlerGetRootClassName(
  const OnGetRootClassName: TPropHookGetRootClassName);
begin
  RemoveHandler(htGetRootClassName,TMethod(OnGetRootClassName));
end;

procedure TPropertyEditorHook.AddHandlerGetAncestorInstProp(
  const OnGetAncestorInstProp: TPropHookGetAncestorInstProp);
begin
  AddHandler(htGetAncestorInstProp,TMethod(OnGetAncestorInstProp));
end;

procedure TPropertyEditorHook.RemoveHandlerGetAncestorInstProp(
  const OnGetAncestorInstProp: TPropHookGetAncestorInstProp);
begin
  RemoveHandler(htGetAncestorInstProp,TMethod(OnGetAncestorInstProp));
end;

procedure TPropertyEditorHook.AddHandlerBeforeAddPersistent(
  const OnBeforeAddPersistent: TPropHookBeforeAddPersistent);
begin
  AddHandler(htBeforeAddPersistent,TMethod(OnBeforeAddPersistent));
end;

procedure TPropertyEditorHook.RemoveHandlerBeforeAddPersistent(
  const OnBeforeAddPersistent: TPropHookBeforeAddPersistent);
begin
  RemoveHandler(htBeforeAddPersistent,TMethod(OnBeforeAddPersistent));
end;

procedure TPropertyEditorHook.AddHandlerComponentRenamed(
  const OnComponentRenamed: TPropHookComponentRenamed);
begin
  AddHandler(htComponentRenamed,TMethod(OnComponentRenamed));
end;

procedure TPropertyEditorHook.RemoveHandlerComponentRenamed(
  const OnComponentRenamed: TPropHookComponentRenamed);
begin
  RemoveHandler(htComponentRenamed,TMethod(OnComponentRenamed));
end;

procedure TPropertyEditorHook.AddHandlerPersistentAdded(
  const OnPersistentAdded: TPropHookPersistentAdded);
begin
  AddHandler(htPersistentAdded,TMethod(OnPersistentAdded));
end;

procedure TPropertyEditorHook.RemoveHandlerPersistentAdded(
  const OnPersistentAdded: TPropHookPersistentAdded);
begin
  RemoveHandler(htPersistentAdded,TMethod(OnPersistentAdded));
end;

procedure TPropertyEditorHook.AddHandlerPersistentDeleting(
  const OnPersistentDeleting: TPropHookPersistentDel);
begin
  AddHandler(htPersistentDeleting,TMethod(OnPersistentDeleting));
end;

procedure TPropertyEditorHook.RemoveHandlerPersistentDeleting(
  const OnPersistentDeleting: TPropHookPersistentDel);
begin
  RemoveHandler(htPersistentDeleting,TMethod(OnPersistentDeleting));
end;

procedure TPropertyEditorHook.AddHandlerPersistentDeleted(
  const OnPersistentDeleted: TPropHookPersistentDel);
begin
  AddHandler(htPersistentDeleted,TMethod(OnPersistentDeleted));
end;

procedure TPropertyEditorHook.RemoveHandlerPersistentDeleted(
  const OnPersistentDeleted: TPropHookPersistentDel);
begin
  RemoveHandler(htPersistentDeleted,TMethod(OnPersistentDeleted));
end;

procedure TPropertyEditorHook.AddHandlerDeletePersistent(
  const OnDeletePersistent: TPropHookDeletePersistent);
begin
  AddHandler(htDeletePersistent,TMethod(OnDeletePersistent));
end;

procedure TPropertyEditorHook.RemoveHandlerDeletePersistent(
  const OnDeletePersistent: TPropHookDeletePersistent);
begin
  RemoveHandler(htDeletePersistent,TMethod(OnDeletePersistent));
end;

procedure TPropertyEditorHook.AddHandlerGetSelection(
  const OnGetSelection: TPropHookGetSelection);
begin
  AddHandler(htGetSelectedPersistents,TMethod(OnGetSelection));
end;

procedure TPropertyEditorHook.RemoveHandlerGetSelection(
  const OnGetSelection: TPropHookGetSelection);
begin
  RemoveHandler(htGetSelectedPersistents,TMethod(OnGetSelection));
end;

procedure TPropertyEditorHook.AddHandlerSetSelection(
  const OnSetSelection: TPropHookSetSelection);
begin
  AddHandler(htSetSelectedPersistents,TMethod(OnSetSelection));
end;

procedure TPropertyEditorHook.RemoveHandlerSetSelection(
  const OnSetSelection: TPropHookSetSelection);
begin
  RemoveHandler(htSetSelectedPersistents,TMethod(OnSetSelection));
end;

procedure TPropertyEditorHook.AddHandlerGetObject(const OnGetObject: TPropHookGetObject);
begin
  AddHandler(htGetObject,TMethod(OnGetObject));
end;

procedure TPropertyEditorHook.RemoveHandlerGetObject(
  const OnGetObject: TPropHookGetObject);
begin
  RemoveHandler(htGetObject,TMethod(OnGetObject));
end;

procedure TPropertyEditorHook.AddHandlerGetObjectName(
  const OnGetObjectName: TPropHookGetObjectName);
begin
  AddHandler(htGetObjectName,TMethod(OnGetObjectName));
end;

procedure TPropertyEditorHook.RemoveHandlerGetObjectName(
  const OnGetObjectName: TPropHookGetObjectName);
begin
  RemoveHandler(htGetObjectName,TMethod(OnGetObjectName));
end;

procedure TPropertyEditorHook.AddHandlerGetObjectNames(
  const OnGetObjectNames: TPropHookGetObjectNames);
begin
  AddHandler(htGetObjectNames,TMethod(OnGetObjectNames));
end;

procedure TPropertyEditorHook.RemoveHandlerGetObjectNames(
  const OnGetObjectNames: TPropHookGetObjectNames);
begin
  RemoveHandler(htGetObjectNames,TMethod(OnGetObjectNames));
end;

procedure TPropertyEditorHook.AddHandlerObjectPropertyChanged(
  const OnObjectPropertyChanged: TPropHookObjectPropertyChanged);
begin
  AddHandler(htObjectPropertyChanged,TMethod(OnObjectPropertyChanged));
end;

procedure TPropertyEditorHook.RemoveHandlerObjectPropertyChanged(
  const OnObjectPropertyChanged: TPropHookObjectPropertyChanged);
begin
  RemoveHandler(htObjectPropertyChanged,TMethod(OnObjectPropertyChanged));
end;

procedure TPropertyEditorHook.AddHandlerModified(const OnModified: TPropHookModified);
begin
  AddHandler(htModified,TMethod(OnModified));
end;

procedure TPropertyEditorHook.RemoveHandlerModified(const OnModified: TPropHookModified);
begin
  RemoveHandler(htModified,TMethod(OnModified));
end;

procedure TPropertyEditorHook.AddHandlerModifiedWithName(
  const OnModified: TPropHookModifiedWithName);
begin
  AddHandler(htModifiedWithName,TMethod(OnModified));
end;

procedure TPropertyEditorHook.RemoveHandlerModifiedWithName(
  const OnModified: TPropHookModifiedWithName);
begin
  RemoveHandler(htModifiedWithName,TMethod(OnModified));
end;

procedure TPropertyEditorHook.AddHandlerDesignerMouseDown(
  const OnMouseDown: TMouseEvent);
begin
  AddHandler(htDesignerMouseDown,TMethod(OnMouseDown));
end;

procedure TPropertyEditorHook.AddHandlerDesignerMouseUp(
  const OnMouseUp: TMouseEvent);
begin
  AddHandler(htDesignerMouseUp,TMethod(OnMouseUp));
end;

procedure TPropertyEditorHook.RemoveHandlerDesignerMouseDown(
  const OnMouseDown: TMouseEvent);
begin
  RemoveHandler(htDesignerMouseDown,TMethod(OnMouseDown));
end;

procedure TPropertyEditorHook.RemoveHandlerDesignerMouseUp(
  const OnMouseUp: TMouseEvent);
begin
  RemoveHandler(htDesignerMouseUp,TMethod(OnMouseUp));
end;

procedure TPropertyEditorHook.AddHandlerRevert(const OnRevert: TPropHookRevert);
begin
  AddHandler(htRevert,TMethod(OnRevert));
end;

procedure TPropertyEditorHook.RemoveHandlerRevert(const OnRevert: TPropHookRevert);
begin
  RemoveHandler(htRevert,TMethod(OnRevert));
end;

procedure TPropertyEditorHook.AddHandlerRefreshPropertyValues(
  const OnRefreshPropertyValues: TPropHookRefreshPropertyValues);
begin
  AddHandler(htRefreshPropertyValues,TMethod(OnRefreshPropertyValues));
end;

procedure TPropertyEditorHook.RemoveHandlerRefreshPropertyValues(
  const OnRefreshPropertyValues: TPropHookRefreshPropertyValues);
begin
  RemoveHandler(htRefreshPropertyValues,TMethod(OnRefreshPropertyValues));
end;

procedure TPropertyEditorHook.AddHandlerAddDependency(
  const OnAddDependency: TPropHookAddDependency);
begin
  AddHandler(htAddDependency,TMethod(OnAddDependency));
end;

procedure TPropertyEditorHook.RemoveHandlerAddDependency(
  const OnAddDependency: TPropHookAddDependency);
begin
  RemoveHandler(htAddDependency,TMethod(OnAddDependency));
end;

procedure TPropertyEditorHook.AddHandlerGetCheckboxForBoolean(
  const OnGetCheckboxForBoolean: TPropHookGetCheckboxForBoolean);
begin
  AddHandler(htGetCheckboxForBoolean,TMethod(OnGetCheckboxForBoolean));
end;

procedure TPropertyEditorHook.SetLookupRoot(APersistent: TPersistent);
var
  i: Integer;
begin
  if FLookupRoot=APersistent then exit;
  if FLookupRoot is TComponent then
    RemoveFreeNotification(TComponent(FLookupRoot));
  FLookupRoot:=APersistent;
  if FLookupRoot is TComponent then
    FreeNotification(TComponent(FLookupRoot));
  i:=GetHandlerCount(htChangeLookupRoot);
  while GetNextHandlerIndex(htChangeLookupRoot,i) do
    TPropHookChangeLookupRoot(FHandlers[htChangeLookupRoot][i])();
end;

procedure TPropertyEditorHook.AddHandler(HookType: TPropHookType;
  const Handler: TMethod);
begin
  if Handler.Code=nil then
    RaiseGDBException('TPropertyEditorHook.AddHandler');
  if FHandlers[HookType]=nil then
    FHandlers[HookType]:=TMethodList.Create;
  FHandlers[HookType].Add(Handler);
end;

procedure TPropertyEditorHook.RemoveHandler(HookType: TPropHookType;
  const Handler: TMethod);
begin
  if FHandlers[HookType]<>nil then
    FHandlers[HookType].Remove(Handler);
end;

function TPropertyEditorHook.GetHandlerCount(HookType: TPropHookType): integer;
begin
  if FHandlers[HookType]<>nil then
    Result:=FHandlers[HookType].Count
  else
    Result:=0;
end;

function TPropertyEditorHook.GetNextHandlerIndex(HookType: TPropHookType;
  var i: integer): boolean;
begin
  if FHandlers[HookType]<>nil then
    Result:=FHandlers[HookType].NextDownIndex(i)
  else begin
    i:=-1;
    Result:=false;
  end;
end;

procedure TPropertyEditorHook.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation=opRemove) and (AComponent=FLookupRoot) then
    LookupRoot:=nil;
end;

constructor TPropertyEditorHook.Create;
begin
  Create(nil);
end;

destructor TPropertyEditorHook.Destroy;
var
  HookType: TPropHookType;
begin
  for HookType:=Low(FHandlers) to high(FHandlers) do
    FreeThenNil(FHandlers[HookType]);
  inherited Destroy;
end;

function KeyStringToVKCode(const s: string): word;
var
  i: PtrInt;
  Data: Pointer;
begin
  Result:=VK_UNKNOWN;
  if KeyStringIsIrregular(s) then begin
    Result:=word(StrToIntDef(copy(s,7,length(s)-8),VK_UNKNOWN));
    exit;
  end;
  if (s<>'none') and (s<>'') then begin
    if VirtualKeyStrings=nil then begin
      VirtualKeyStrings:=TStringHashList.Create(true);
      for i:=1 to 255 do
        VirtualKeyStrings.Add(KeyAndShiftStateToKeyString(word(i),[]), {%H-}Pointer(i));
    end;
  end else
    exit;
  Data:=VirtualKeyStrings.Data[s];
  if Data<>nil then
    Result:=word({%H-}PtrUInt(Data));
end;

function GetClassUnitName(Value: TClass): string;
begin
  if Value=nil then
    Result:=''
  else
    Result:=Value.UnitName;
end;

procedure CreateComponentEvent(AComponent: TComponent; const EventName: string);
var
  CurDesigner: TIDesigner;
  PropInfo: PPropInfo;
  Hook: TPropertyEditorHook;
  PersistentList: TPersistentSelectionList;
  MethodPropEditor: TMethodPropertyEditor;
begin
  CurDesigner:=FindRootDesigner(AComponent);
  if CurDesigner=nil then exit;
  // search method
  PropInfo:=GetPropInfo(AComponent,EventName);
  //writeln('CreateComponentEvent B ',PropInfo<>nil,' ',PropInfo^.PropType<>nil,' ',PropInfo^.PropType^.Kind=tkMethod,' ',(PropInfo^.GetProc<>nil),' ',(PropInfo^.SetProc<>nil));
  if (PropInfo=nil)
  or (PropInfo^.PropType=nil)
  or (PropInfo^.PropType^.Kind<>tkMethod)
  or (PropInfo^.GetProc=nil)
  or (PropInfo^.SetProc=nil) then
    exit;
  
  MethodPropEditor:=nil;
  PersistentList:=nil;
  try
    PersistentList := TPersistentSelectionList.Create;
    PersistentList.Add(AComponent);
    Hook:=GlobalDesignHook;
    MethodPropEditor := TMethodPropertyEditor.Create(Hook,1);
    MethodPropEditor.SetPropEntry(0, AComponent, PropInfo);
    MethodPropEditor.Initialize;
    MethodPropEditor.Edit;
  finally
    MethodPropEditor.Free;
    PersistentList.Free;
  end;
end;

function ClassNameToComponentName(const AClassName: string): string;
begin
  Result:=AClassName;
  if (length(Result)>2) and (Result[1] in ['T','t'])
  and (not (Result[2] in ['0'..'9'])) then
    System.Delete(Result,1,1);
end;

function ControlAcceptsStreamableChildComponent(aControl: TWinControl;
  aComponentClass: TComponentClass; aLookupRoot: TPersistent): boolean;
{off $DEFINE VerboseAddDesigner}
var
  Parent: TWinControl;
begin
  Result:=false;
  if not (csAcceptsControls in aControl.ControlStyle) then
  begin
    {$IFDEF VerboseAddDesigner}
    debugln(['ControlAcceptsStreamableChildComponent missing csAcceptsControls in ',DbgSName(aControl)]);
    {$ENDIF}
    exit;
  end;

  if aComponentClass.InheritsFrom(TControl)
  and not aControl.CheckChildClassAllowed(aComponentClass, False) then
  begin
    {$IFDEF VerboseAddDesigner}
    debugln(['ControlAcceptsStreamableChildComponent aControl=',DbgSName(aControl),' CheckChildClassAllowed forbids ',DbgSName(aComponentClass)]);
    {$ENDIF}
    exit;
  end;

  // the LookupRoot allows children
  if aControl=aLookupRoot then
    exit(true);

  // TWriter only supports children of LookupRoot and LookupRoot.Components
  if (aControl.Owner <> aLookupRoot) and (aControl <> aLookupRoot) then
  begin
    {$IFDEF VerboseAddDesigner}
    debugln(['ControlAcceptsStreamableChildComponent wrong lookuproot aControl=',DbgSName(aControl),' aLookupRoot=',DbgSName(aLookupRoot),' aControl.Owner=',DbgSName(aControl.Owner)]);
    {$ENDIF}
    exit;
  end;

  // TWriter does not support children on nested components
  // (i.e. csInline , e.g. on a frame) nor any of its components
  Parent:=aControl;
  while (Parent<>nil) and (Parent<>aLookupRoot) do begin
    if csInline in Parent.ComponentState then begin
      {$IFDEF VerboseAddDesigner}
      debugln(['ControlAcceptsStreamableChildComponent aControl=',DbgSName(aControl),' Parent=',DbgSName(Parent),' csInline']);
      {$ENDIF}
      exit;
    end;
    Parent:=Parent.Parent;
  end;

  Result:=true;
end;

function ClassTypeInfo(Value: TClass): PTypeInfo;
begin
  Result := PTypeInfo(Value.ClassInfo);
end;

procedure EditCollection(AComponent: TComponent; ACollection: TCollection; APropName: String);
begin
  TCollectionPropertyEditor.ShowCollectionEditor(ACollection, AComponent, APropName);
end;

procedure EditCollectionNoAddDel(AComponent: TComponent; ACollection: TCollection; APropName: String);
begin
  TNoAddDeleteCollectionPropertyEditor.ShowCollectionEditor(ACollection, AComponent, APropName);
end;

function IsInteresting(AEditor: TPropertyEditor; const AFilter: TTypeKinds;
  const APropNameFilter: String): Boolean;

var
  visited: TFPList;

  // check set element names against AFilter
  function IsPropInSet( const ATypeInfo: PTypeInfo ) : Boolean;
  var
    TypeInfo: PTypeInfo;
    TypeData: PTypeData;
    i: Integer;
  begin
    Result := False;
    TypeInfo := ATypeInfo;

    if (TypeInfo^.Kind <> tkSet) then exit;

    TypeData := GetTypeData(TypeInfo);
    // Get TypeInfo of set type.
    TypeInfo := TypeData^.CompType;
    TypeData := GetTypeData(TypeInfo);

    for i:= TypeData^.MinValue to TypeData^.MaxValue do
    begin
      Result := PosI(APropNameFilter, GetEnumName(TypeInfo,i)) > 0;
      if Result then
        Break;
    end;
  end;

  //check if class has property name
  function IsPropInClass( const ATypeInfo: PTypeInfo ) : Boolean;
  var
    propInfo: PPropInfo;
    propList: PPropList;
    i, propCount: Integer;
    quSubclass: TFPList;
    icurClass: Integer = 0;
  begin
    Result := False;
    quSubclass := TFPList.Create;
    quSubclass.Add(ATypeInfo);

    while icurClass < quSubclass.Count do
    begin
      propCount := GetPropList(quSubclass.Items[icurClass], propList);

      for i := 0 to propCount - 1 do
      begin
        propInfo := propList^[i];

        Result := PosI(APropNameFilter, propInfo^.Name) > 0;
        if Result then break;
        //if encounter a Set check its elements name.
        if (propInfo^.PropType^.Kind = tkSet) then
        begin
          Result := IsPropInSet(propInfo^.PropType);
          if Result then break;
        end;
        //queue subclasses(only once) to check later.
        if (propInfo^.PropType^.Kind = tkClass) then
          if quSubclass.IndexOf(propInfo^.PropType) >= 0 then Continue
          else  quSubclass.Add(propInfo^.PropType);
      end;
      if Assigned(propList) then FreeMem(propList);
      //no need to check subclasses if result is already true.
      if Result then break;
      inc(icurClass);
    end;
    quSubclass.Free;
  end;

  // Add AForceShow to display T****PropertyEditor when subproperties found.
  // and name of class is not the same as filter
  procedure Rec(A: TPropertyEditor; AForceShow: Boolean = False);
  var
    propList: PPropList;
    i: Integer;
    ti: PTypeInfo;
    edClass: TPropertyEditorClass;
    ed: TPropertyEditor;
    obj: TPersistent;
    PropCnt: LongInt;
  begin
    ti := A.GetPropInfo^.PropType;
    //DebugLn('IsInteresting: ', ti^.Name);
    Result := ti^.Kind <> tkClass;
    if Result then
    begin
      if (APropNameFilter = '') or AForceShow then
        exit;
      Result := PosI(APropNameFilter, A.GetName) > 0; // Check single Props
      // Check if check Set has element.
      if (ti^.Kind = tkSet) and (A.ClassType <> TSetElementPropertyEditor) then
        Result := Result or IsPropInSet(A.GetPropType);

      exit;
    end;

    // Subroperties can change if user selects another object =>
    // we must show the property, even if it is not interesting currently.
    Result := paVolatileSubProperties in A.GetAttributes;
    if Result then exit;

    if tkClass in AFilter then
    begin
      // We want classes => any non-trivial editor is immediately interesting.
      Result := A.ClassType <> TClassPropertyEditor;
      if Result then
      begin
        // if no SubProperties check against filter name
        if (APropNameFilter = '') then
          exit;
        Result := PosI(APropNameFilter, A.GetName) > 0;
        if (paSubProperties in A.GetAttributes) then
          Result := Result or IsPropInClass(A.GetPropType);

        exit;
      end;
    end
    else if A.GetAttributes * [paSubProperties, paVolatileSubProperties] = [] then
      exit;

    obj := TPersistent(A.GetObjectValue);
    // At this stage, there is nothing interesting left in empty objects.
    if obj = nil then exit;

    // Class properties may directly or indirectly refer to the same class,
    // so we must avoid infinite recursion.
    if visited.IndexOf(ti) >= 0 then exit;
    visited.Add(ti);
    // actual published properties can be different since the instance can be inherited
    // so update type info from the instance
    ti := obj.ClassInfo;
    PropCnt := GetPropList(ti, propList);
    try
      for i := 0 to PropCnt - 1 do begin
        if not (propList^[i]^.PropType^.Kind in AFilter + [tkClass]) then continue;
        edClass := GetEditorClass(propList^[i], obj);
        if edClass = nil then continue;
        ed := edClass.Create(AEditor.FPropertyHook, 1);
        try
          ed.SetPropEntry(0, obj, propList^[i]);
          ed.Initialize;
          // filter TClassPropertyEditor name recursively
          Rec(ed, PosI(APropNameFilter, A.GetName) > 0 );
        finally
          ed.Free;
        end;
        if Result then break;
      end;
    finally
      FreeMem(propList);
    end;
    visited.Delete(visited.Count - 1);
  end;

begin
  visited := TFPList.Create;
  try
    //DebugLn('IsInteresting -> ', AEditor.GetPropInfo^.Name, ': ', AEditor.GetPropInfo^.PropType^.Name);
    Rec(AEditor);
    //DebugLn('IsInteresting <- ', BoolToStr(Result, true));
  finally
    visited.Free;
  end;
end;

function dbgs(peh: TPropEditHint): string;
begin
  writestr(Result,peh);
end;

{ TNoteBookActiveControlPropertyEditor }

function TNoteBookActiveControlPropertyEditor.CheckNewValue(APersistent: TPersistent): boolean;
var
  AComponent: TPersistent;
  Notebook: TCustomTabControl;
begin
  Result:=true;
  if APersistent=nil then exit;
  AComponent:=GetComponent(0);
  if not (AComponent is TCustomTabControl) then
    raise Exception.Create('invalid instance for this property editor');
  Notebook:=TCustomTabControl(AComponent);
  if Notebook.IndexOf(APersistent)<0 then
    raise Exception.Create('only children are allowed for this property');
end;

function TNoteBookActiveControlPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result:=(inherited GetAttributes)-[paMultiSelect];
end;

procedure TNoteBookActiveControlPropertyEditor.GetValues(Proc: TGetStrProc);
var
  AComponent: TPersistent;
  Notebook: TCustomTabControl;
  i: Integer;
begin
  Proc(oisNone);
  AComponent:=GetComponent(0);
  if not (AComponent is TCustomTabControl) then exit;
  Notebook:=TCustomTabControl(AComponent);
  for i:=0 to Notebook.PageCount-1 do
    Proc(Notebook.Page[i].Name);
end;

{ TCustomShortCutGrabBox }

procedure TCustomShortCutGrabBox.SetKey(const AValue: Word);
var
  s: String;
  i: LongInt;
begin
  if FKey=AValue then exit;
  FKey:=AValue;
  s:=KeyAndShiftStateToKeyString(FKey,[]);
  {$IFDEF VerboseKeyboard}
  debugln(['TCustomShortCutGrabBox.SetKey ',Key,' "',s,'"']);
  {$ENDIF}
  i:=KeyComboBox.Items.IndexOf(s);
  if i>=0 then
    KeyComboBox.ItemIndex:=i
  else if KeyStringIsIrregular(s) then begin
    KeyComboBox.Items.Add(s);
    KeyComboBox.ItemIndex:=KeyComboBox.Items.IndexOf(s);
  end else
    KeyComboBox.ItemIndex:=0;
end;

procedure TCustomShortCutGrabBox.OnGrabButtonClick(Sender: TObject);
begin
  FGrabForm:=TForm.Create(Self);
  FGrabForm.BorderStyle:=bsDialog;
  FGrabForm.KeyPreview:=true;
  FGrabForm.Position:=poScreenCenter;
  FGrabForm.OnKeyDown:=@OnGrabFormKeyDown;
  FGrabForm.Caption:=oisPressAKey;
  with TLabel.Create(Self) do begin
    Caption:=oisPressAKeyEGCtrlP;
    BorderSpacing.Around:=50;
    Parent:=FGrabForm;
  end;
  FGrabForm.Width:=200;
  FGrabForm.Height:=50;
  FGrabForm.AutoSize:=true;
  FGrabForm.ShowModal;
  // After getting a key, focus the main form's OK button. User can just click Enter.
  if (Key <> VK_UNKNOWN) and Assigned(MainOkButton) then
    MainOkButton.SetFocus;
  FreeAndNil(FGrabForm);
end;

procedure TCustomShortCutGrabBox.OnShiftCheckBoxClick(Sender: TObject);
var
  s: TShiftStateEnum;
begin
  for s:=Low(TShiftStateEnum) to High(TShiftStateEnum) do
    if FCheckBoxes[s]=Sender then
      if FCheckBoxes[s].Checked then
        Include(FShiftState,s)
      else
        Exclude(FShiftState,s);
end;

procedure TCustomShortCutGrabBox.OnGrabFormKeyDown(Sender: TObject;
  var AKey: Word; AShift: TShiftState);
begin
  {$IFDEF VerboseKeyboard}
  DebugLn(['TCustomShortCutGrabBox.OnGrabFormKeyDown ',AKey,' ',dbgs(AShift)]);
  DumpStack;
  {$ENDIF}
  if not (AKey in [VK_CONTROL, VK_LCONTROL, VK_RCONTROL,
             VK_SHIFT, VK_LSHIFT, VK_RSHIFT,
             VK_MENU, VK_LMENU, VK_RMENU,
             VK_LWIN, VK_RWIN,
             VK_PROCESSKEY,
             VK_MODECHANGE,
             VK_UNKNOWN, VK_UNDEFINED])
  then begin
    if (AKey=VK_ESCAPE) and (AShift=[]) then begin
      Key:=VK_UNKNOWN;
      ShiftState:=[];
    end else begin
      Key:=AKey;
      ShiftState:=AShift;
    end;
    FGrabForm.ModalResult:=mrOk;
  end;
end;

procedure TCustomShortCutGrabBox.OnKeyComboboxEditingDone(Sender: TObject);
begin
  Key:=KeyStringToVKCode(KeyComboBox.Text);
end;

function TCustomShortCutGrabBox.GetShiftCheckBox(Shift: TShiftStateEnum): TCheckBox;
begin
  Result:=FCheckBoxes[Shift];
end;

function TCustomShortCutGrabBox.GetKey: Word;
begin
  Result:=FKey;
  if (FKey = 0) then
    FShiftState:=[];
end;

procedure TCustomShortCutGrabBox.SetAllowedShifts(const AValue: TShiftState);
begin
  if FAllowedShifts=AValue then exit;
  FAllowedShifts:=AValue;
  ShiftState:=ShiftState*FAllowedShifts;
end;

procedure TCustomShortCutGrabBox.SetShiftButtons(const AValue: TShiftState);
begin
  if FShiftButtons=AValue then exit;
  FShiftButtons:=AValue;
  UpdateShiftButtons;
end;

procedure TCustomShortCutGrabBox.SetShiftState(const AValue: TShiftState);
var
  s: TShiftStateEnum;
begin
  if FShiftState=AValue then exit;
  FShiftState:=AValue;
  for s:=low(TShiftStateEnum) to High(TShiftStateEnum) do
    if FCheckBoxes[s]<>nil then
      FCheckBoxes[s].Checked:=s in FShiftState;
end;

procedure TCustomShortCutGrabBox.Loaded;
begin
  inherited Loaded;
  UpdateShiftButtons;
end;

procedure TCustomShortCutGrabBox.RealSetText(const Value: TCaption);
begin
  // do not allow to set caption
end;

procedure TCustomShortCutGrabBox.UpdateShiftButtons;
var
  s: TShiftStateEnum;
  LastCheckBox: TCheckBox;
begin
  if [csLoading,csDestroying]*ComponentState<>[] then exit;
  LastCheckBox:=nil;
  DisableAlign;
  try
    for s:=low(TShiftStateEnum) to High(TShiftStateEnum) do begin
      if s in FShiftButtons then begin
        if FCheckBoxes[s]=nil then begin
          FCheckBoxes[s]:=TCheckBox.Create(Self);
          with FCheckBoxes[s] do begin
            Name:='CheckBox'+ShiftToStr(s);
            Caption:=ShiftToStr(s);
            AutoSize:=true;
            Checked:=s in FShiftState;
            if LastCheckBox<>nil then
              AnchorToNeighbour(akLeft,6,LastCheckBox)
            else
              AnchorParallel(akLeft,0,Self);
            AnchorParallel(akTop,0,Self);
            AnchorParallel(akBottom,0,Self);
            Parent:=Self;
            OnClick:=@OnShiftCheckBoxClick;
          end;
        end;
        LastCheckBox:=FCheckBoxes[s];
      end else begin
        FreeAndNil(FCheckBoxes[s]);
      end;
    end;
    if LastCheckBox<>nil then
      FKeyComboBox.AnchorToNeighbour(akLeft,6,LastCheckBox)
    else
      FKeyComboBox.AnchorParallel(akLeft,0,Self);
  finally
    EnableAlign;
  end;
end;

procedure TCustomShortCutGrabBox.Notification(AComponent: TComponent;
  Operation: TOperation);
var
  s: TShiftStateEnum;
begin
  inherited Notification(AComponent, Operation);
  if Operation=opRemove then begin
    if AComponent=FGrabButton then
      FGrabButton:=nil;
    if AComponent=FKeyComboBox then
      FKeyComboBox:=nil;
    if AComponent=FGrabForm then
      FGrabForm:=nil;
    for s:=Low(TShiftStateEnum) to High(TShiftStateEnum) do
      if FCheckBoxes[s]=AComponent then begin
        FCheckBoxes[s]:=nil;
        Exclude(FShiftButtons,s);
      end;
  end;
end;

function TCustomShortCutGrabBox.ShiftToStr(s: TShiftStateEnum): string;
begin
  case s of
  ssShift: Result:='Shift';
  ssAlt: Result:='Alt';
  ssCtrl: Result:='Ctrl';
  ssMeta: Result:='Meta';
  ssSuper: Result:='Super';
  ssHyper: {$IFDEF Darwin}
           Result:='Cmd';
           {$ELSE}
           Result:='Hyper';
           {$ENDIF}
  ssAltGr: Result:='AltGr';
  ssCaps: Result:='Caps';
  ssNum: Result:='Numlock';
  ssScroll: Result:='Scroll';
  else Result:='Modifier'+IntToStr(ord(s));
  end;
end;

constructor TCustomShortCutGrabBox.Create(TheOwner: TComponent);

  procedure AddKeyToCombobox(i: integer);
  var
    s: String;
  begin
    s := KeyAndShiftStateToKeyString(i, []);
    if not KeyStringIsIrregular(s) then
      FKeyComboBox.Items.Add(s);
  end;

var
  i: Integer;
  ShSt: TShiftStateEnum;
begin
  inherited Create(TheOwner);

  FAllowedShifts:=[ssShift, ssAlt, ssCtrl,
    ssMeta, ssSuper, ssHyper, ssAltGr,
    ssCaps, ssNum, ssScroll];

  FGrabButton:=TButton.Create(Self);
  with FGrabButton do begin
    Name:='GrabButton';
    Caption:=srGrabKey;
    Align:=alRight;
    AutoSize:=true;
    Parent:=Self;
    OnClick:=@OnGrabButtonClick;
  end;

  FKeyComboBox:=TComboBox.Create(Self);
  with FKeyComboBox do begin
    Name:='FKeyComboBox';
    AutoSize:=true;
    Items.BeginUpdate;
    AddKeyToCombobox(0);
    for i:=VK_BACK to VK_SCROLL do
      AddKeyToCombobox(i);
    for i:=VK_BROWSER_BACK to VK_OEM_CLEAR do
      AddKeyToCombobox(i);
    Items.EndUpdate;
    OnEditingDone:=@OnKeyComboboxEditingDone;
    Parent:=Self;
    AnchorToNeighbour(akRight,6,FGrabButton);
    AnchorVerticalCenterTo(FGrabButton);
    Constraints.MinWidth:=130;
  end;

  BevelOuter:=bvNone;
  ShiftButtons:=GetDefaultShiftButtons;
  ShiftState:=[];
  Key:=VK_UNKNOWN;
  KeyComboBox.Text:=KeyAndShiftStateToKeyString(Key,[]);

  // Fix TabOrders. The controls were created in "wrong" order.
  i:=FGrabButton.TabOrder;                 // GrabButton was created first.
  for ShSt:=Low(FCheckBoxes) to High(FCheckBoxes) do begin
    if Assigned(FCheckBoxes[ShSt]) then begin
      FCheckBoxes[ShSt].TabOrder:=i;
      Inc(i);
    end;
  end;
  FKeyComboBox.TabOrder:=i;
  FGrabButton.TabOrder:=i+1;
end;

function TCustomShortCutGrabBox.GetDefaultShiftButtons: TShiftState;
begin
  {$IFDEF Darwin}
  Result:=[ssCtrl,ssShift,ssAlt,ssMeta];
  {$ELSE}
  Result:=[ssCtrl,ssShift,ssAlt];
  {$ENDIF}
end;

procedure InitPropEdits;
begin
  // Don't create PropertyClassList and PropertyEditorMapperList lists here.
  // RegisterPropertyEditor and RegisterPropertyEditorMapper create them,
  //  and they are called from many initialization sections in unpredictable order.

  // register the standard property editors
  RegisterPropertyEditor(TypeInfo(AnsiString), TComponent, 'Name', TComponentNamePropertyEditor);
  RegisterPropertyEditor(TypeInfo(TTranslateString), TCustomLabel, 'Caption', TStringMultilinePropertyEditor);
  RegisterPropertyEditor(TypeInfo(TTranslateString), TCustomStaticText, 'Caption', TStringMultilinePropertyEditor);
  RegisterPropertyEditor(TypeInfo(TTranslateString), TCustomCheckBox, 'Caption', TStringMultilinePropertyEditor);
  RegisterPropertyEditor(TypeInfo(TTranslateString), TMenuItem, 'Caption', TMenuItemCaptionEditor);
  RegisterPropertyEditor(TypeInfo(TTranslateString), TComponent, 'Hint', TStringMultilinePropertyEditor);
  RegisterPropertyEditor(TypeInfo(TCaption), TGridColumnTitle, 'Caption', TStringMultilinePropertyEditor);
  RegisterPropertyEditor(TypeInfo(TTabOrder), TControl, 'TabOrder', TTabOrderPropertyEditor);
  RegisterPropertyEditor(TypeInfo(ShortString), nil, '', TCaptionPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TStrings), nil, '', TStringsPropertyEditor);
  {$IF FPC_FULLVERSION > 30101}
  RegisterPropertyEditor(TypeInfo(TFileName), nil, '', TFileNamePropertyEditor);
  {$ENDIF}
  RegisterPropertyEditor(TypeInfo(AnsiString), nil, 'SessionProperties', TSessionPropertiesPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TModalResult), nil, 'ModalResult', TModalResultPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TShortCut), nil, '', TShortCutPropertyEditor);
  //RegisterPropertyEditor(DummyClassForPropTypes.PTypeInfos('TDate'), nil,'',TDatePropertyEditor);
  //RegisterPropertyEditor(DummyClassForPropTypes.PTypeInfos('TTime'), nil,'',TTimePropertyEditor);
  RegisterPropertyEditor(TypeInfo(TDateTime), nil, '', TDateTimePropertyEditor);
  RegisterPropertyEditor(TypeInfo(TCursor), nil, '', TCursorPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TComponent), nil, '', TComponentPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TComponent), nil, 'ActiveControl', TComponentOneFormPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TControl), TCoolBand, 'Control', TCoolBarControlPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TCollection), nil, '', TCollectionPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TFlowPanelControlList), TFlowPanel, 'ControlList', TNoAddDeleteCollectionPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TControl), TFlowPanelControl, 'Control', THiddenPropertyEditor);
  RegisterPropertyEditor(TypeInfo(AnsiString), TFileDialog, 'Filter', TFileDlgFilterProperty);
  RegisterPropertyEditor(TypeInfo(AnsiString), TFilterComboBox, 'Filter', TFileDlgFilterProperty);
  RegisterPropertyEditor(TypeInfo(AnsiString), TFileNameEdit, 'Filter', TFileDlgFilterProperty);
  RegisterPropertyEditor(TypeInfo(AnsiString), TCustomPropertyStorage, 'Filename', TFileNamePropertyEditor);
  RegisterPropertyEditor(TypeInfo(TStrings), TValueListEditor, 'Strings', TValueListPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TCustomPage), TCustomTabControl, 'ActivePage', TNoteBookActiveControlPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TSizeConstraints), TControl, 'Constraints', TConstraintsPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TStrings), TNoteBook, 'Pages', TPagesPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TTranslateString), TCustomTaskDialog, 'Text', TStringMultilinePropertyEditor);
  RegisterPropertyEditor(TypeInfo(TTranslateString), TCustomTaskDialog, 'ExpandedText', TStringMultilinePropertyEditor);
  RegisterPropertyEditor(TypeInfo(TTranslateString), TCustomTaskDialog, 'FooterText', TStringMultilinePropertyEditor);

  // Property is hidden and editing disabled by HiddenPropertyEditor :
  RegisterPropertyEditor(TypeInfo(TAnchorSide), TControl, 'AnchorSideLeft', THiddenPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TAnchorSide), TControl, 'AnchorSideTop', THiddenPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TAnchorSide), TControl, 'AnchorSideRight', THiddenPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TAnchorSide), TControl, 'AnchorSideBottom', THiddenPropertyEditor);
  RegisterPropertyEditor(TypeInfo(LongInt), TControl, 'ClientWidth', THiddenPropertyEditor);
  RegisterPropertyEditor(TypeInfo(LongInt), TControl, 'ClientHeight', THiddenPropertyEditor);
  RegisterPropertyEditor(TypeInfo(AnsiString), TCustomForm, 'LCLVersion', THiddenPropertyEditor);
  RegisterPropertyEditor(TypeInfo(AnsiString), TCustomFrame, 'LCLVersion', THiddenPropertyEditor);

  // since fpc 2.6.0 WordBool, LongBool and QWordBool only allow 0 and 1
  RegisterPropertyEditor(TypeInfo(WordBool), nil, '', TBoolPropertyEditor);
  RegisterPropertyEditor(TypeInfo(LongBool), nil, '', TBoolPropertyEditor);
  RegisterPropertyEditor(TypeInfo(QWordBool), nil, '', TBoolPropertyEditor);

  RegisterPropertyEditor(TypeInfo(IInterface), nil, '', TInterfacePropertyEditor);
  RegisterPropertyEditor(TypeInfo(Variant), nil, '', TVariantPropertyEditor);
end;

procedure FinalPropEdits;
var
  i: integer;
  pm: PPropertyEditorMapperRec;
  pc: PPropertyClassRec;
  sec: PSelectionEditorClassRec;
begin
  if PropertyEditorMapperList<>nil then begin
    for i:=0 to PropertyEditorMapperList.Count-1 do begin
      pm:=PPropertyEditorMapperRec(PropertyEditorMapperList.Items[i]);
      Dispose(pm);
    end;
    FreeAndNil(PropertyEditorMapperList);
  end;

  if PropertyClassList<>nil then begin
    for i:=0 to PropertyClassList.Count-1 do begin
      pc:=PPropertyClassRec(PropertyClassList[i]);
      Dispose(pc);
    end;
    FreeAndNil(PropertyClassList);
  end;

  if Assigned(SelectionEditorClassList) then begin
    for i:=0 to SelectionEditorClassList.Count-1 do begin
      sec:=PSelectionEditorClassRec(SelectionEditorClassList[i]);
      Dispose(sec);
    end;
    FreeAndNil(SelectionEditorClassList);
  end;

  FreeAndNil(ListPropertyEditors);
  FreeAndNil(VirtualKeyStrings);
end;

initialization
  InitPropEdits;

finalization
  FinalPropEdits;

end.

