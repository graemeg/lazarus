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

 Author: Balázs Székely
 Abstract:
   Constants, resource strings for the online package manager.
}
unit opkman_const;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

const
  cRemoteRepository = 'http://packages.lazarus-ide.org/';
  cRemoteRepositoryTitle = 'Lazarus Central Repository';
  cRemoteJSONFile = 'packagelist.json';
  cLocalRepository =  'onlinepackagemanager';
  cLocalRepositoryPackages = 'packages';
  cLocalRepositoryArchive = 'archive';
  cLocalRepositoryUpdate = 'update';
  cLocalRepositoryConfig = 'config';
  cLocalRepositoryConfigFile = 'options.xml';
  cLocalRepositoryUpdatesFile = 'updates_%s.xml';
  cExcludedFilesDef = '*.,*.a,*.o,*.ppu,*.compiled,*.bak,*.or,*.rsj,*.~,*.exe,*.dbg,*.zip,*.so,*.dll,*.dylib';
  cExcludedFoldersDef = 'lib,backup,updates,compiled,.git,.svn,units';
  cHelpPage = 'http://wiki.freepascal.org/Online_Package_Manager';
  cHelpPage_CreateRepositoryPackage = 'http://wiki.freepascal.org/Online_Package_Manager#Create_repository_package';
  cHelpPage_CreateExternalJSON = 'http://wiki.freepascal.org/Online_Package_Manager#Create_JSON_for_updates';
  {$ifdef win64}
  cOpenSSLURL = 'http://packages.lazarus-ide.org/openssl-1.0.2j-x64_86-win64.zip';
  {$endif}
  {$ifdef win32}
  cOpenSSLURL = 'http://packages.lazarus-ide.org/openssl-1.0.2j-i386-win32.zip';
  {$endif}
  cExtractDir = 'ExtractDir';
  cSubmitURL_Zip =  'aHR0cDovL2xhemFydXNvcG0ub3JnL3ppcC5waHA=';
  cSubmitURL_JSON = 'aHR0cDovL2xhemFydXNvcG0ub3JnL2pzb24ucGhw';
  cSep = '#@$%^';

resourcestring
  //package manager
  rsLazarusPackageManager = 'Online Package Manager';
  rsMenuLazarusPackageManager = 'Online Package Manager ...';

  //main form
  rsPackagesFound = '(%s repository packages found, containing %s lpk files, total size %s)';
  rsMainFrm_VSTHeaderColumn_PackageName = 'Packages';
  rsMainFrm_VSTHeaderColumn_LazarusPackage = 'Lazarus Package (.lpk)';
  rsMainFrm_VSTHeaderColumn_Repository = 'OPM repository';
  rsMainFrm_VSTHeaderColumn_Repository_Hint = 'Packages available in the OPM repository (https://packages.lazarus-ide.org/)';
  rsMainFrm_VSTHeaderColumn_Installed = 'Installed';
  rsMainFrm_VSTHeaderColumn_Update = 'External repository';
  rsMainFrm_VSTHeaderColumn_Update_Hint = 'Packages available at the developer''s webpage (see node "External link (JSON)" for more details)';
  rsMainFrm_VSTHeaderColumn_Data = 'Status/Data';
  rsMainFrm_VSTHeaderColumn_Button = '';
  rsMainFrm_VSTHeaderColumn_Rating = 'Rating';
  rsMainFrm_VSTText_PackageCategory = 'Package category';
  rsMainFrm_VSTText_PackageStatus = 'Package status';
  rsMainFrm_VSTText_Version = 'Version';
  rsMainFrm_VSTText_Description = 'Description';
  rsMainFrm_VSTText_Author = 'Author';
  rsMainFrm_VSTText_LazCompatibility = 'Lazarus compatibility';
  rsMainFrm_VSTText_FPCCompatibility = 'FPC compatibility';
  rsMainFrm_VSTText_SupportedWidgetsets = 'Supported widgetsets';
  rsMainFrm_VSTText_Packagetype = 'Package type';
  rsMainFrm_VSTText_Dependecies = 'Dependencies';
  rsMainFrm_VSTText_License = 'License';
  rsMainFrm_VSTText_PackageInfo = 'Package info';
  rsMainFrm_VSTText_Category = 'Category';
  rsMainFrm_VSTText_CommunityDescription = 'Community description';
  rsMainFrm_VSTText_ExternalDeps = 'External dependencies';
  rsMainFrm_VSTText_OrphanedPackage1 = 'Orphaned package';
  rsMainFrm_VSTText_OrphanedPackage2 = 'currently has no active maintainer';
  rsMainFrm_VSTText_RepositoryFilename = 'Repository filename';
  rsMainFrm_VSTText_RepositoryFileSize = 'Repository filesize';
  rsMainFrm_VSTText_RepositoryFileHash = 'Repository filehash';
  rsMainFrm_VSTText_RepositoryFileDate = 'Available since';
  rsMainFrm_VSTText_HomePageURL = 'Home page';
  rsMainFrm_VSTText_DownloadURL = 'External link (JSON)';
  rsMainFrm_VSTText_SVNURL = 'SVN';
  rsMainFrm_VSTText_Install0 = 'No';
  rsMainFrm_VSTText_Install1 = 'Yes';
  rsMainFrm_VSTText_Install2 = 'Partially';
  rsMainFrm_VSTText_PackageType0 = 'Designtime and runtime';
  rsMainFrm_VSTText_PackageType1 = 'Designtime';
  rsMainFrm_VSTText_PackageType2 = 'Runtime';
  rsMainFrm_VSTText_PackageType3 = 'Runtime only, cannot be installed in IDE';
  rsMainFrm_VSTText_PackageState0 = 'Repository';
  rsMainFrm_VSTText_PackageState1 = 'Downloaded';
  rsMainFrm_VSTText_PackageState2 = 'Extracted';
  rsMainFrm_VSTText_PackageState3 = 'Installed';
  rsMainFrm_VSTText_PackageState4 = 'Up to date';
  rsMainFrm_VSTText_PackageState6 = 'New version available';
  rsMainFrm_VSTText_PackageState7 = 'Ahead of OPM';
  rsMainFrm_VSTText_PackageCategory0  = 'Charts and Graphs';
  rsMainFrm_VSTText_PackageCategory1  = 'Cryptography';
  rsMainFrm_VSTText_PackageCategory2  = 'DataControls';
  rsMainFrm_VSTText_PackageCategory3  = 'Date and Time';
  rsMainFrm_VSTText_PackageCategory4  = 'Dialogs';
  rsMainFrm_VSTText_PackageCategory5  = 'Edit and Memos';
  rsMainFrm_VSTText_PackageCategory6  = 'Files and Drives';
  rsMainFrm_VSTText_PackageCategory7  = 'GUIContainers';
  rsMainFrm_VSTText_PackageCategory8  = 'Graphics';
  rsMainFrm_VSTText_PackageCategory9  = 'Grids';
  rsMainFrm_VSTText_PackageCategory10 = 'Indicators and Gauges';
  rsMainFrm_VSTText_PackageCategory11 = 'Labels';
  rsMainFrm_VSTText_PackageCategory12 = 'LazIDEPlugins';
  rsMainFrm_VSTText_PackageCategory13 = 'List and Combo Boxes';
  rsMainFrm_VSTText_PackageCategory14 = 'ListViews and TreeViews';
  rsMainFrm_VSTText_PackageCategory15 = 'Menus';
  rsMainFrm_VSTText_PackageCategory16 = 'Multimedia';
  rsMainFrm_VSTText_PackageCategory17 = 'Networking';
  rsMainFrm_VSTText_PackageCategory18 = 'Panels';
  rsMainFrm_VSTText_PackageCategory19 = 'Reporting';
  rsMainFrm_VSTText_PackageCategory20 = 'Science';
  rsMainFrm_VSTText_PackageCategory21 = 'Security';
  rsMainFrm_VSTText_PackageCategory22 = 'Shapes';
  rsMainFrm_VSTText_PackageCategory23 = 'Sizers and Scrollers';
  rsMainFrm_VSTText_PackageCategory24 = 'System';
  rsMainFrm_VSTText_PackageCategory25 = 'Tabbed Components';
  rsMainFrm_VSTText_PackageCategory26 = 'Other';
  rsMainFrm_VSTText_PackageCategory27 = 'Games and Game Engines';
  rsMainFrm_VSTText_Desc = 'Description for package';
  rsMainFrm_VSTText_Lic = 'License info for package';
  rsMainFrm_VSTText_Open = 'Open';
  rsMainFrm_VSTText_Open_Notfound = 'Package file not found.';
  rsMainFrm_VSTText_Open_Error = 'Cannot open package file.';
  rsMainFrm_VSTText_ComDesc = 'Community description for metapackage';
  rsMainFrm_VSTText_ExternalMetaPackageDeps = 'External dependencies for metapackage';
  rsMainFrm_cbAll_Caption = 'All/None';
  rsMainFrm_cbAll_Hint = 'Check/Uncheck packages';
  rsMainFrm_lbFilter_Caption = 'Filter by:';
  rsMainFrm_cbFilterBy_Hint = 'Filter package list by:';
  rsMainFrm_bReturn_Caption = 'Return';
  rsMainFrm_edFilter_Hint = 'Type filter text';
  rsMainFrm_spClear_Hint = 'Clear filter text';
  rsMainFrm_spExpand_Hint = 'Expand package tree';
  rsMainFrm_spCollapse_Hint = 'Collapse package tree';
  rsMainFrm_TBRefresh_Caption = 'Refresh';
  rsMainFrm_TBRefresh_Hint = 'Refresh package list';
  rsMainFrm_TBDownload_Caption = 'Download';
  rsMainFrm_TBDownload_Hint = 'Download packages';
  rsMainFrm_TBInstall_Caption = 'Install';
  rsMainFrm_TBInstall_Hint = 'Install packages';
  rsMainFrm_TBUpdate_Caption = 'Update';
  rsMainFrm_TBUpdate_Hint = 'Update packages from external URL';
  rsMainFrm_TBUnInstall_Caption = 'Uninstall';
  rsMainFrm_TBUnInstall_Hint = 'Uninstall packages';
  rsMainFrm_TBOpenRepo_Caption = 'Local repo';
  rsMainFrm_TBOpenRepo_Hint = 'Open local repository';
  rsMainFrm_TBCleanUp_Caption = 'Cleanup';
  rsMainFrm_TBCleanUp_Hint = 'Cleanup local repository';
  rsMainFrm_TBRepository_Caption = 'Create';
  rsMainFrm_TBRepository_Hint = 'Create package or repository';
  rsMainFrm_TBOptions_Caption = 'Options';
  rsMainFrm_TBOptions_Hint = 'Show options dialog';
  rsMainFrm_TBHelp_Caption = 'Help';
  rsMainFrm_TBHelp_Hint = 'Help (' + cHelpPage + ')';
  rsMainFrm_miFromRepository = 'From official repository';
  rsMainFrm_miFromExternalSource = 'From third party repository';
  rsMainFrm_miCreateRepositoryPackage = 'Create repository package';
  rsMainFrm_miCreateJSONForUpdates = 'Create JSON for updates';
  rsMainFrm_miCreateRepository = 'Create private repository';
  rsMainFrm_miJSONShow =  'Show JSON';
  rsMainFrm_miJSONHide = 'Hide JSON';
  rsMainFrm_miJSONSort = 'Sort';
  rsMainFrm_miByName = 'By name';
  rsMainFrm_miByDate = 'By date';
  rsMainFrm_miAscendent = 'Ascendent';
  rsMainFrm_miDescendent = 'Descendent';
  rsMainFrm_miSaveToFile = 'Save to file';
  rsMainFrm_miCopyToClpBrd = 'Copy to clipboard';
  rsMainFrm_miResetRating = 'Reset rating';
  rsMainFrm_miSave = 'Save packages';
  rsMainFrm_miSaveChecked = 'Checked';
  rsMainFrm_miLoadInstalled = 'Installed';
  rsMainFrm_miLoad = 'Load packages';
  rsMainFrm_PackagenameAlreadyExists = 'A package with the same name already exists!';
  rsMainFrm_PackageAlreadyInstalled = 'The following packages are already installed. Continue anyway?';
  rsMainFrm_PackageIncompatible = 'The following packages are not tested and the install might fail. Continue anyway?';
  rsMainFrm_PackageAlreadyDownloaded = 'The following repository packages already exist in the target folder. Continue?';
  rsMainFrm_PackageUpdateWarning = 'Installing packages from external link is not without a risk!' + sLineBreak + 'Only install if you trust the package maintainer. Continue?';
  rsMainFrm_PackageUpdate0 = 'The following repository packages are not available externally. The packages will be skipped. Continue?';
  rsMainFrm_PackageUpdate1 = 'None of the checked repository packages are available externally. Please make sure that package updates are enabled by default:' + sLineBreak + 'Options->General->Check for package updates.';
  rsMainFrm_rsMessageNoPackage = 'No packages to show.';
  rsMainFrm_rsMessageParsingJSON = 'Parsing JSON. Please wait...';
  rsMainFrm_rsMessageDownload = 'Downloading package list. Please wait...';
  rsMainFrm_rsMessageChangingRepository = 'Changing repository. Please wait...';
  rsMainFrm_rsMessageNoRepository0 = 'Remote package repository not configured.' + sLineBreak + 'Do you wish to configure it now?';
  rsMainFrm_rsMessageNothingChacked = 'Please check at least one package!';
  rsMainFrm_rsMessageNothingInstalled = 'No packages are installed. Please install at least one package first.';
  rsMainFrm_resMessageChecksSaved = '%s packages successfully saved to file!';
  rsMainFrm_resMessageChecksLoaded = '%s packages successfully loaded from file!';
  rsMainFrm_rsMessageError0 = 'Cannot download package list. Error message:';
  rsMainFrm_rsMessageError1 = 'Invalid JSON file.';
  rsMainFrm_rsMessageError2 = 'Remote server unreachable.';
  rsMainFrm_rsNoPackageToDownload = 'Please check one or more packages!';
  rsMainFrm_rsRepositoryCleanup0 = 'This will delete all non-installed packages from local repository. Continue?';
  rsMainFrm_rsRepositoryCleanup1 = '%s packages deleted!';
  rsMainFrm_rsPackageDependency0 = 'Package "%s" depends on package "%s". '
    +'Resolve dependency?';
  rsMainFrm_rsPackageDependency1 = 'Not resolving dependencies might lead to install failure! Continue?';
  rsMainFrm_rsPackageRating = 'Your vote for package "%s" is: %s. Thank you for voting!';
  rsMainFrm_rsUninstall = '%sAre you sure you wish to uninstall the checked packages?' + sLineBreak +
                          'Please note: in order for the changes to take effect you must rebuid the IDE.';
  rsMainFrm_rsUninstall_Nothing = 'None of the checked packages are installed. Nothing to uninstall.';
  rsMainFrm_rsUninstall_Error = 'Cannot uninstall package "%s"!';
  rsMainFrm_rsDestDirError = 'Cannot create directory "%s". Operation aborted.';
  rsMainFrm_rsPackageInformation = 'Quick package information for "%s"';

  //progress form
  rsProgressFrm_Caption0 = 'Downloading packages';
  rsProgressFrm_Caption1 = 'Extracting packages';
  rsProgressFrm_Caption2 = 'Installing packages';
  rsProgressFrm_Caption3 = 'Updating packages';
  rsProgressFrm_Caption4 = '. Please wait...';
  rsProgressFrm_Caption5 = 'Unknown';
  rsProgressFrm_lbPackage_Caption = 'Package:';
  rsProgressFrm_lbSpeed_Caption = 'Speed:';
  rsProgressFrm_lbSpeedCalc_Caption = 'Estimating. Please wait...';
  rsProgressFrm_lbElapsed_Caption = 'Elapsed:';
  rsProgressFrm_lbRemaining_Caption = 'Remaining:';
  rsProgressFrm_lbReceived_Caption0 = 'Received:';
  rsProgressFrm_lbReceived_Caption1 = 'Unzipped:';
  rsProgressFrm_lbReceivedTotal_Caption0 = 'Received (total):';
  rsProgressFrm_lbReceivedTotal_Caption1 = 'Unzipped (total):';
  rsProgressFrm_cbExtractOpen_Caption0 = 'Extract after download';
  rsProgressFrm_cbExtractOpen_Caption1 = 'Open containing folder';
  rsProgressFrm_Error0 = 'Cannot download package:';
  rsProgressFrm_Error1 = 'Error message:';
  rsProgressFrm_Error2 = 'Cannot extract package:';
  rsProgressFrm_Error3 = 'Cannot install package:';
  rsProgressFrm_Error4 = 'Dependency "%s" not found!';
  rsProgressFrm_Error5 = 'Cannot contact download site';
  rsProgressFrm_Error6 = 'No valid download link found.';
  rsProgressFrm_Error7 = 'Cannot open package file.';
  rsProgressFrm_Error8 = 'Cannot compile package.';
  rsProgressFrm_Error9 = 'Cannot install package.';
  rsProgressFrm_Conf0 = 'Continue with next one?';
  rsProgressFrm_Info0 = 'Installing package:';
  rsProgressFrm_Info1 = 'Success.';
  rsProgressFrm_Info2 = 'Contacting download site for "%s" (%s)';
  rsProgressFrm_Info3 = 'Preparing to download. Please wait...';
  rsProgressFrm_Info4 = 'Canceling. Please wait...';
  rsProgressFrm_Info5 = 'Opening package:';
  rsProgressFrm_Info6 = 'Compiling package:';

  //options form
  rsOptions_FrmCaption = 'Options';
  rsOptions_tsGeneral_Caption = 'General';
  rsOptions_tsProxy_Caption = 'Proxy';
  rsOptions_tsFolders_Caption = 'Folders';
  rsOptions_tsProfiles_Caption = 'Profiles';
  rsOptions_lbRemoteRepository_Caption = 'Remote repository';
  rsOptions_cbLoadJsonLocally_Caption = 'If available, parse the JSON from local source';
  rsOptions_cbLoadJsonLocally_Hint = 'If this option is checked the JSON is parsed from a local source (useful if the internet connection is slow). After 25 local parses, OPM will attempt a live update.';
  rsOptions_cbForceDownloadExtract_Caption = 'Always force download and extract';
  rsOptions_cbForceDownloadExtract_Hint = 'If this option is checked the packages are always re-downloaded/extracted before install';
  rsOptions_lbConTimeOut_Caption = 'Connection timeout (seconds):';
  rsOptions_lbConTimeOut_Hint = 'The number of seconds after which package manager drops connection';
  rsOptions_lbSelectProfile_Caption = 'Select profile';
  rsOptions_cbSelectProfile_Item0 = 'Regular user';
  rsOptions_cbSelectProfile_Item1 = 'Package maintainer';
  rsOptions_cbSelectProfile_Hint = 'Choose a profile that best fits you';
  rsOptions_cbDelete_Caption = 'Delete downloaded zip files after installation/update';
  rsOptions_cbDelete_Hint = 'If this option is checked the downloaded zip file is always deleted after installation';
  rsOption_cbIncompatiblePackage_Caption = 'Warn me about incompatible/untested packages';
  rsOption_cbIncompatiblePackage_Hint = 'If a package is not compatible with the current widgetset or Lazarus/FPC version, OPM will show a warning message';
  rsOption_cbcbAlreadyInstalledPackages_Caption = 'Warn me about already installed packages';
  rsOption_cbcbAlreadyInstalledPackages_Hint = 'If a package is already installed, OPM will show a warning message';
  rsOptions_cbProxy_Caption = 'Use proxy';
  rsOptions_gbProxySettings_Caption = 'Proxy settings';
  rsOptions_lbServer_Caption = 'Server';
  rsOptions_lbPort_Caption = 'Port';
  rsOptions_lbUsername_Caption = 'Username';
  rsOptions_lbPassword_Caption = 'Password';
  rsOptions_lbLocalRepositoryPackages_Caption = 'Local repository';
  rsOptions_edLocalRepositoryPackages_Hint = 'The folder where the repository packages are extracted/installed';
  rsOptions_lbLocalRepositoryArchive_Caption = 'Archive directory';
  rsOptions_edLocalRepositoryArchive_Hint = 'The folder where the zip files are downloaded from the remote repository';
  rsOptions_lbLocalRepositoryUpdate_Caption = 'Update directory';
  rsOptions_edLocalRepositoryUpdate_Hint = 'The folder where the zip files are downloaded from the package maintainer webpage';
  rsOptions_RemoteRepository_Information = 'Please enter the remote repository address!';
  rsOptions_ProxyServer_Info = 'Please enter the proxy server address!';
  rsOptions_ProxyPort_Info = 'Please enter the proxy server port!';
  rsOptions_InvalidDirectory_Info = 'Please enter a valid directory!';
  rsOptions_RestoreDefaults_Conf = 'This will restore the default settings. Continue?';
  rsOptions_lbCheckForUpdates_Caption = 'Check external repositories for package updates';
  rsOptions_cbCheckForUpdates_Item0 = 'Every few minutes';
  rsOptions_cbCheckForUpdates_Item1 = 'Every hour';
  rsOptions_cbCheckForUpdates_Item2 = 'Once per day';
  rsOptions_cbCheckForUpdates_Item3 = 'Weekly';
  rsOptions_cbCheckForUpdates_Item4 = 'Montly';
  rsOptions_cbCheckForUpdates_Item5 = 'Never';
  rsOptions_lbLastUpdate_Caption = 'Last update: ';
  rsOptions_LastUpdate_Never = 'never';
  rsOptions_lbDaysToShowNewPackages_Caption = 'Show different icon for newly added packages for (days):';
  rsOptions_cbRegular_Caption = 'Show regular icon for newly added packages after install';
  rsOptions_cbUseDefaultTheme_Caption = 'Use default theme manager';
  rsOptions_rbHintFormOptions_Caption = 'Quick info for repository packages';
  rsOptions_rbHintFormOptions_Item0 = 'Behaves like a regular hint window';
  rsOptions_rbHintFormOptions_Item1 = 'It''s triggered by SHIFT, moves with the mouse';
  rsOptions_rbHintFormOptions_Item2 = 'Off';
  rsOptions_lbFilterFiles_Caption = 'Excluded files (packages)';
  rsOptions_lbFilterDirs_Caption = 'Excluded folders (packages)';
  rsOptions_bColors_Caption = 'Colors';
  rsOptions_bpOptions_bHelp = 'Restore defaults';
  rsOptions_bAdd_Caption = 'Add';
  rsOptions_bEdit_Caption = 'Edit';
  rsOptions_bDelete_Caption = 'Delete';
  rsOptions_lbExcludeFiles_Hint = 'These files will be excluded from repository packages (see: "Create repository package")';
  rsOptions_lbExcludeFolders_Hint = 'These folders will be excluded from repository packages (see: "Create repository package")';
  rsOptions_InputBox_Caption = 'Add new exclusion';
  rsOptions_InputBox_Text0 = 'Type the extension name:';
  rsOptions_InputBox_Text1 = 'Type the folder name:';
  rsOptions_InputBox_Info0 = 'Please select a file extension!';
  rsOptions_InputBox_Info1 = 'Please select a folder!';
  rsOptions_InputBox_Conf0 = 'Delete selected extension ("%s")?';
  rsOptions_InputBox_Conf1 = 'Delete selected folder ("%s")?';
  rsOptions_rbOpenSSL_Item0 = 'Automatically download files from "https://packages.lazarus-ide.org/"';
  rsOptions_rbOpenSSL_Item1 = 'Show confirmation dialog before download';
  rsOptions_rbOpenSSL_Item2 = 'Never download files';

  //packagelist form
  rsPackageListFrm_Caption0 = 'Installed package list';
  rsPackageListFrm_Caption1 = 'Downloaded package list';
  rsPackageListFrm_Caption2 = 'Update package list';
  rsPackageListFrm_Caption3 = 'Incompatible package list';
  rsPackageListFrm_SupLazVers = 'Supported Lazarus versions: ';
  rsPackageListFrm_CurLazVer = 'Current Lazarus version: ';
  rsPackageListFrm_SupFPCVers = 'Supported FPC versions: ';
  rsPackageListFrm_CurFPCVer = 'Current FPC version: ';
  rsPackageListFrm_SupWSs = 'Supported widgetsets: ';
  rsPackageListFrm_CurWS = 'Current widgetset: ';
  rsPackageListFrm_Incompatible = 'Not tested';
  rsPackageListFrm_bYes_Caption = 'Yes';
  rsPackageListFrm_bNo_Caption = 'No';
  rsPackageListFrm_bOk_Caption = 'OK';
  rsPackageListFrm_lbHint_Caption = 'Hint: for more details move the mouse over the problematic column.';

  //createrepositorypackage form
  rsCreateRepositoryPackageFrm_Caption = 'Create repository package';
  rsCreateRepositoryPackageFrm_pnMessage_Caption = 'Please wait...';
  rsCreateRepositoryPackageFrm_lbPackageDir_Caption = 'Package directory:';
  rsCreateRepositoryPackageFrm_pnCaption_Caption0 = 'Available packages';
  rsCreateRepositoryPackageFrm_pnCaption_Caption1 = 'Description';
  rsCreateRepositoryPackageFrm_pnCaption_Caption2 = 'Data';
  rsCreateRepositoryPackageFrm_NoPackage = 'No packages found!';
  rsCreateRepositoryPackageFrm_lbCategory_Caption = 'Category:';
  rsCreateRepositoryPackageFrm_lbDisplayName_Caption = 'Display name:';
  rsCreateRepositoryPackageFrm_lbLazCompatibility_Caption = 'Lazarus compatibility:';
  rsCreateRepositoryPackageFrm_lbFPCCompatibility_Caption = 'FPC compatibility:';
  rsCreateRepositoryPackageFrm_lbSupportedWidgetset_Caption = 'Supported widgetsets:';
  rsCreateRepositoryPackageFrm_lbHomePageURL_Caption = 'Home page:';
  rsCreateRepositoryPackageFrm_lbDownloadURL_Caption = 'Update link (JSON):';
  rsCreateRepositoryPackageFrm_lbSVNURL_Caption = 'SVN:';
  rsCreateRepositoryPackageFrm_SDDTitleSrc = 'Select package directory';
  rsCreateRepositoryPackageFrm_SDDTitleDst = 'Save repository package to...';
  rsCreateRepositoryPackageFrm_Error0 = 'Error reading package';
  rsCreateRepositoryPackageFrm_Error1 = 'Cannot create zip file:';
  rsCreateRepositoryPackageFrm_Error2 = 'Cannot create JSON file:';
  rsCreateRepositoryPackageFrm_Error3  = 'Cannot send file: "%s"';
  rsCreateRepositoryPackageFrm_Message0 = 'Please select a category for package:';
  rsCreateRepositoryPackageFrm_Message1 = 'Please enter supported Lazarus versions for package:';
  rsCreateRepositoryPackageFrm_Message2 = 'Please enter supported FPC versions for package:';
  rsCreateRepositoryPackageFrm_Message3 = 'Please enter supported widgetsets for package:';
  rsCreateRepositoryPackageFrm_Message4 = 'Compressing package. Please wait...';
  rsCreateRepositoryPackageFrm_Message5 = 'Creating JSON. Please wait...';
  rsCreateRepositoryPackageFrm_Message6 = 'Creating JSON for updates. Please wait...';
  rsCreateRepositoryPackageFrm_Message7 = 'Repository package successfully created.';
  rsCreateRepositoryPackageFrm_Message8 = 'Sending files ("%s"). Please wait...';
  rsCreateRepositoryPackageFrm_Message9 = 'Files successfully sent. Thank you for submitting packages!' + sLineBreak + 'Your request will be processed in 24 hours.';
  rsCreateRepositoryPackageFrm_Message10 = 'Cancelling upload. Please wait...';
  rsCreateRepositoryPackageFrm_bHelp_Caption = 'Help';
  rsCreateRepositoryPackageFrm_bHelp_Hint = 'Open help';
  rsCreateRepositoryPackageFrm_bOptions_Caption = 'Options';
  rsCreateRepositoryPackageFrm_bOptions_Hint = 'Open options dialog';
  rsCreateRepositoryPackageFrm_bCreate_Caption = 'Create';
  rsCreateRepositoryPackageFrm_bCreate_Hint = 'Create files locally';
  rsCreateRepositoryPackageFrm_bCreate_Caption1 = 'Add';
  rsCreateRepositoryPackageFrm_bCreate_Hint1 = 'Add package to repository';
  rsCreateRepositoryPackageFrm_bSubmit_Caption = 'Submit';
  rsCreateRepositoryPackageFrm_bSubmit_Hint = 'Submit files to remote server';
  rsCreateRepositoryPackageFrm_bCancel_Caption = 'Cancel';
  rsCreateRepositoryPackageFrm_bCancel_Hint = 'Close this dialog';

  //createupdatejson
  rsCreateJSONForUpdatesFrm_Caption = 'Create update JSON for package:';
  rsCreateJSONForUpdatesFrm_bHelp_Caption = 'Help';
  rsCreateJSONForUpdatesFrm_bCreate_Caption = 'Create';
  rsCreateJSONForUpdatesFrm_bClose_Caption = 'Cancel';
  rsCreateJSONForUpdatesFrm_lbLinkToZip_Caption = 'Link to the package zip file';
  rsCreateJSONForUpdatesFrm_bTest_Caption = 'Test';
  rsCreateJSONForUpdatesFrm_Column0_Text = 'PackageFileName';
  rsCreateJSONForUpdatesFrm_Column1_Text = 'Version';
  rsCreateJSONForUpdatesFrm_Column2_Text = 'Force notify';
  rsCreateJSONForUpdatesFrm_Column3_Text = 'Internal version';
  rsCreateJSONForUpdatesFrm_Message0 = 'Please check a repository package!';
  rsCreateJSONForUpdatesFrm_Message1 = 'Please check only one repository package!';
  rsCreateJSONForUpdatesFrm_Message2 = 'Please enter a valid URL!';
  rsCreateJSONForUpdatesFrm_Message3 = 'Please check at least one package file!';
  rsCreateJSONForUpdatesFrm_Message4 = 'JSON for updates successfully created.';
  rsCreateJSONForUpdatesFrm_Error1 = 'Cannot create JSON for updates! Error message:';

  //categories form
  rsCategoriesFrm_Caption1 = 'List with categories';
  rsCategoriesFrm_Caption2 = 'List with Lazarus versions';
  rsCategoriesFrm_Caption3 = 'List with FPC versions';
  rsCategoriesFrm_Caption4 = 'List with supported widgetsets';
  rsCategoriesFrm_lbMessage_Caption = 'Please select (check) one or more items';
  rsCategoriesFrm_bYes_Caption = 'OK';
  rsCategoriesFrm_bCancel_Caption = 'Cancel';

  //repositories
  rsRepositories_Caption = 'Repositories';
  rsRepositories_VST_HeaderColumn = 'Repository Address';
  rsRepositories_bAdd_Caption = 'Add';
  rsRepositories_bEdit_Caption = 'Edit';
  rsRepositories_bDelete_Caption = 'Delete';
  rsRepositories_bOk_Caption = 'OK';
  rsRepositories_bCancel_Caption = 'Cancel';
  rsRepositories_Confirmation0 = 'Delete selected repository "%s"?';
  rsRepositories_InputBox_Caption0 = 'Add repository';
  rsRepositories_InputBox_Caption1 = 'Edit repository';
  rsRepositories_InputBox_Text = 'Type the repository address:';
  rsRepositories_Info1 = 'The following repository: "%s" is already in the list.';

  //create private repository
  rsCreateRepositoryFrm_Caption = 'Create/Edit private repository';
  rsCreateRepositoryFrm_bOpen_Caption = 'Open';
  rsCreateRepositoryFrm_bOpen_Hint = 'Open private respository';
  rsCreateRepositoryFrm_bCreate_Caption = 'Create';
  rsCreateRepositoryFrm_bCreate_Hint = 'Create private repository';
  rsCreateRepositoryFrm_bAdd_Caption = 'Add';
  rsCreateRepositoryFrm_bAdd_Hint = 'Add package to the current repository';
  rsCreateRepositoryFrm_bDelete_Caption = 'Delete';
  rsCreateRepositoryFrm_bDelete_Hint = 'Delete package from the current repository';
  rsCreateRepositoryFrm_bCancel_Caption = 'Cancel';
  rsCreateRepositoryFrm_bCancel_Hint = 'Close this dialog';
  rsCreateRepositoryFrm_miRepDetails_Caption = 'Edit repository details';
  rsCreateRepositoryFrm_VSTPackages_Column0 = 'Repository/Packages';
  rsCreateRepositoryFrm_VSTDetails_Column0 = 'Description';
  rsCreateRepositoryFrm_VSTDetails_Column1 = 'Data';
  rsCreateRepositoryFrm_RepositoryAddress = 'Address';
  rsCreateRepositoryFrm_RepositoryDescription = 'Description';
  rsCreateRepositoryFrm_VSTText_Category = 'Category';
  rsCreateRepositoryFrm_VSTText_RepositoryFilename = 'Repository filename';
  rsCreateRepositoryFrm_VSTText_RepositoryFileSize = 'Repository filesize';
  rsCreateRepositoryFrm_VSTText_RepositoryFileHash = 'Repository filehash';
  rsCreateRepositoryFrm_VSTText_RepositoryFileDate = 'Available since';
  rsCreateRepositoryFrm_VSTText_HomePageURL = 'Home page';
  rsCreateRepositoryFrm_VSTText_DownloadURL = 'Update link (JSON)';
  rsCreateRepositoryFrm_VSTText_Version = 'Version';
  rsCreateRepositoryFrm_VSTText_Description = 'Description';
  rsCreateRepositoryFrm_VSTText_Author = 'Author';
  rsCreateRepositoryFrm_VSTText_LazCompatibility = 'Lazarus compatibility';
  rsCreateRepositoryFrm_VSTText_FPCCompatibility = 'FPC compatibility';
  rsCreateRepositoryFrm_VSTText_SupportedWidgetsets = 'Supported widgetsets';
  rsCreateRepositoryFrm_VSTText_Packagetype = 'Package type';
  rsCreateRepositoryFrm_VSTText_Dependecies = 'Dependencies';
  rsCreateRepositoryFrm_VSTText_License = 'License';
  rsCreateRepositoryFrm_VSTText_PackageType0 = 'Designtime and runtime';
  rsCreateRepositoryFrm_VSTText_PackageType1 = 'Designtime';
  rsCreateRepositoryFrm_VSTText_PackageType2 = 'Runtime';
  rsCreateRepositoryFrm_VSTText_PackageType3 = 'Runtime only, cannot be installed in IDE';
  rsCreateRepositoryFrm_Error1 = 'Cannot open private repository: "%s". Error message: ' + sLineBreak + '"%s"';
  rsCreateRepositoryFrm_Error3 = 'Cannot save private repository: "%s". Error message: ' + sLineBreak + '"%s"';
  rsCreateRepositoryFrm_Error4 = 'Cannot add package to repository!';
  rsCreateRepositoryFrm_Error5 = 'Cannot delete package: "%s"!';
  rsCreateRepositoryFrm_Info1 = 'The following directory: "%s" is not empty.' + sLineBreak + 'It''s recommended to save the repository to an empty directory. Continue?';
  rsCreateRepositoryFrm_Info3 = 'The following package: "%s" is already in the current repository.' + sLineBreak + 'Each repository and Lazarus package must be unique!';
  rsCreateRepositoryFrm_Info5 = 'The following Lazarus package: "%s" is already in the current repository.' + sLineBreak + 'Each repository and Lazarus package must be unique!';
  rsCreateRepositoryFrm_Info7 = 'Package successfully added to repository.';
  rsCreateRepositoryFrm_Conf1 = 'Are you sure you wish to delete package: "%s"?';
  rsCreateRepositoryFrm_Conf2 = 'The following file: "%s" already exists in the current repository. Overwrite?';

  //repository details
  rsRepositoryDetailsFrm_Caption = 'Repository details';
  rsRepositoryDetailsFrm_lbName_Caption = 'Name';
  rsRepositoryDetailsFrm_edName_Hint = 'Enter the repository name';
  rsRepositoryDetailsFrm_lbAddress_Caption = 'Address';
  rsRepositoryDetailsFrm_edAddress_Hint = 'Enter the repository address (e.g.: "http://localhost/packages/")';
  rsRepositoryDetailsFrm_lbDescription_Caption = 'Description';
  rsRepositoryDetailsFrm_mDescription_Hint = 'Enter the repository description';
  rsRepositoryDetailsFrm_bOk_Caption = 'OK';
  rsRepositoryDetailsFrm_bOk_Hint = 'Save and close the dialog';
  rsRepositoryDetailsFrm_bCancel_Caption = 'Cancel';
  rsRepositoryDetailsFrm_bCancel_Hint = 'Close the dialog without saving';
  rsRepositoryDetailsFrm_Info1 = 'Please enter the repository name.';

  //add package to repository
  rsAddRepositoryPackageFrm_Caption = 'Add repository package';
  rsAddRepositoryPackageFrm_rbCreateNew_Caption = 'Create a new repository package';
  rsAddRepositoryPackageFrm_rbAddExisting_Caption = 'Add existing repository package from file';
  rsAddRepositoryPackageFrm_bOk_Caption = 'OK';
  rsAddRepositoryPackageFrm_bOk_Hint = 'Close the dialog and create the package';
  rsAddRepositoryPackageFrm_bCancel_Caption = 'Cancel';
  rsAddRepositoryPackageFrm_bCancel_Hint = 'Close the dialog';

  //OPMinterface
  rsOPMInterfaceRebuildConf = 'In order for the changes to take effect you must rebuild the IDE. Rebuild now?';

  //OPMIntfPackageList
  rsOPMIntfPackageListFrm_Caption = 'Install online packages';
  rsOPMIntfPackageListFrm_pnInfo = 'Please check before install: Lazarus/FPC compatibility, widgetset support, license and version info';
  rsOPMIntfPackageListFrm_VSTHeaderColumn_LazarusPackage = 'Lazarus Package';
  rsOPMIntfPackageListFrm_VSTHeaderColumn_Data = 'Data';

  //colors form
  rsColors_Caption = 'Colors';
  rsColors_CD_Title = 'Select color';

  //OpenSSL form
  rsOpenSSLFrm_Caption = 'Download OpenSSL libraries';
  rsOpenSSLFrm_Bp_OKButton_Caption = 'Yes';
  rsOpenSSLFrm_Bp_CancelButton_Caption = 'No';
  rsOpenSSLFrm_chPermanent_Caption = 'Do not ask this question again';
  rsOpenSSLFrm_lbMessage1_Caption = 'In order to work properly, OPM needs the OpenSSL libraries: "libeay32.dll" and "ssleay32.dll"';
  rsOpenSSLFrm_lbMessage2_Caption = 'Download these files from "https://packages.lazarus-ide.org/"?';


implementation

end.

































