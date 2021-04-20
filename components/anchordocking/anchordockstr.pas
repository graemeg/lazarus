{ For license see anchordocking.pas
}
unit AnchorDockStr;

{$mode objfpc}{$H+}

interface

resourcestring
  adrsClose = 'Close';
  adrsMinimize = 'Minimize';
  adrsQuit = 'Quit %s';
  adrsTabPosition = 'Tab position';
  adrsMovePageRight = 'Move page right';
  adrsMovePageRightmost = 'Move page rightmost';
  adrsUndock = 'Undock';
  adrsHeaderPosition = 'Header position';
  adrsEnlargeSide = 'Enlarge %s side';
  adrsMerge = 'Merge';
  adrsEnlarge = 'Enlarge';
  adrsAutomatically = 'Automatically';
  adrsLeft = 'left';
  adrsTop = 'top';
  adrsRight = 'right';
  adrsBottom = 'bottom';
  adrsLocked = 'Locked';
  adrsDockingOptions = 'Docking options';
  adrsMovePageLeft = 'Move page left';
  adrsMovePageLeftmost = 'Move page leftmost';
  adrsRequestedButCreated = '%s requested, but %s created';
  adrsDragAndDockC = 'Use the mouse to drag and dock window "%s"';
  adrsMissingControlName = 'missing control name';
  adrsModalFormsCanNotBeMadeDockable = 'modal forms can not be made dockable';
  adrsControlIsAlreadyADocksite = 'control is already a docksite';
  adrsNotSupportedHasParent = 'Not supported: %s has parent %s';
  adrsAnchorNotFoundNodeAnchors = 'Anchor not found: Node="%s" Anchors[%s]="%s"';
  adrsAnchorIsNotSplitterNodeAnchors = 'Anchor is not splitter: Node="%s" Anchors[%s]="%s"';
  adrsAFreeSideOfASplitterMustNotBeAnchoredNodeTypeAncho = 'A free side of a '
    +'splitter must not be anchored: Node="%s" Type=%s Anchors[%s]="%s"';
  adrsAPageMustNotBeAnchoredNodeParentParentTypeAnchors = 'A page must not be '
    +'anchored: Node="%s" Parent=%s ParentType=%s Anchors[%s]="%s"';
  adrsAnchorToWrongSideOfSplitterNodeAnchors = 'Anchor to wrong side of '
    +'splitter: Node="%s" Anchors[%s]="%s"';
  adrsNoChildrenAllowedForNodeType = 'No children allowed for Node="%s" Type=%s';
  adrsCustomDockSiteCanHaveOnlyOneSite = 'Custom dock site "%s" can have only one site.';
  adrsEmptyName = 'Empty name: ';
  adrsDuplicateName = 'Duplicate name: ';
  adrsDragThreshold = 'Drag threshold';
  adrsGeneralDockingOptions = 'General docking options';
  adrsAmountOfPixelTheMouseHasToDragBeforeDragStarts = 'Amount of pixel the '
    +'mouse has to drag before drag starts';
  adrsHeaderAlignTop = 'Header align top';
  adrsMoveHeaderToTopWhenWidthHeight100HeaderAlignTop = 'Move header to top '
    +'when (Width/Height)*100<=HeaderAlignTop';
  adrsHeaderAlignLeft = 'Header align left';
  adrsMoveHeaderToLeftWhenWidthHeight100HeaderAlignLeft = 'Move header to '
    +'left when (Width/Height)*100>=HeaderAlignLeft';
  adrsSplitterWidth = 'Splitter width';
  adrsSplitterThickness = 'Splitter thickness';
  adrsScaleOnResize = 'Scale on resize';
  adrsScaleSubSitesWhenASiteIsResized ='Scale sub sites when a site is resized';
  adrsShowHeaderCaptions = 'Show header captions';
  adrsShowCaptionsOfDockedControlsInTheHeader = 'Show captions of docked '
    +'controls in the header';
  adrsShowHeaders = 'Show headers';
  adrsEachDockedWindowHasAHeaderThatAllowsDraggingHasACo = 'Each docked window'
    +' has a header that allows dragging, has a context menu with extra layout'
    +' functions and shows the caption of the docked window';
  adrsNoCaptionsForFloatingSites = 'No captions for floating sites';
  adrsHideHeaderCaptionsForSitesWithOnlyOneDockedControl = 'Hide header '
    +'captions for sites with only one docked control, as that is already '
    +'shown in the normal window title';
  adrsToUseAnchordockingYouMustFirstUninstall = 'To use anchordocking you '
    +'must first uninstall %s';
  adrsThereIsAnotherDockMasterInstalledOnlyOneDockingPac = 'There is another '
    +'dock master installed. Only one docking package can be installed at a '
    +'time. Please uninstall the other dock master %s and restart the IDE';
  adrsDockingAnchordocking = 'Docking / Anchordocking';
  adrsHeaderStyle = 'Header Style:';
  adrsFlattenHeaders = 'Flatten headers';
  adrsFlattenHeadersHint = 'Flatten headers of docked controls';
  adrsFilledHeaders = 'Fill headers';
  adrsFilledHeadersHint = 'Fill headers of docked controls';
  adrsHighlightFocused = 'Highlight focused';
  adrsHighlightFocusedHint = 'Highlight header of focused docked control';
  adrsAllowDockSitesToBeMinimized = 'Allow dock sites to be minimized';
  adrsMultiLinePages = 'Multiline Tabs';
  adrsMultiLinePagesHint = 'Tabs of pages can be shown in multiple lines';
  adrsFloatingWindowsOnTop = 'Floating windows on top';
  adrsFloatingWindowsOnTopHint = 'Show floating windows on top of main form';

implementation

end.

