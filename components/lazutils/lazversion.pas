{
 /***************************************************************************
                               lazversion.pas
                             -------------------
                         Version numbers for Lazarus

 ***************************************************************************/

 *****************************************************************************
  This file is part of the LazUtils package

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit LazVersion;

{$mode objfpc}{$H+}

interface

const
  laz_major = 2;
  laz_minor = 3;
  laz_release = 0;
  laz_patch = 0;
  laz_fullversion = ((laz_major *  100 + laz_minor) * 100 + laz_release) * 100 + laz_patch;
  laz_version = '2.3.0.0';

implementation

end.

