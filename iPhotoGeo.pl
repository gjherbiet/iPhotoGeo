#!/usr/bin/env perl -w

##############################################################################
# File   : iPhotoGeo.pl
# Author : Guillaume-Jean Herbiet  <guillaume-jean@herbiet.net>
#
#
# Copyright (c) 2010 Guillaume-Jean Herbiet     (http://www.herbiet.net)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Guillaume-Jean Herbiet
# <guillaume-jean@herbiet.net>
##############################################################################
use strict;
use warnings;
binmode STDOUT, ":utf8";                # Print to STDOUT as UFT-8

#-----------------------------------------------------------------------------
# Load aditional packages
#
use Image::ExifTool qw(:Public);        # Read-write EXIF data
use Mac::PropertyList::XS qw( :all );   # Easily parse Plist like AlbumData.xml
use Data::Dumper;                       # Useful for debugging
use Getopt::Long;

#-----------------------------------------------------------------------------
# Global variables
#

#
# Generic variables
#
my $VERSION = '0.1';
my $DEBUG   = 0;
my $VERBOSE = 0;
my $QUIET   = 0;
my $NUMARGS = scalar(@ARGV);
my @ARGS    = @ARGV;
my $COMMAND = `basename $0`;
chomp($COMMAND);
my %OPTIONS;

#
# Script specific variables
#
my $user = `whoami`;
chomp($user);                                               # User name
my $iPhoto_library = "/Users/$user/Pictures/iPhoto Library";# Default path to iPhoto Library
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# Get passed arguments and check for validity.
#
my $res = GetOptions(
    \%OPTIONS,
    'verbose|v+'        => \$VERBOSE,
    'help|h'            => sub { USAGE( exitval => 0 ); },
    'version'           => sub { VERSION_MESSAGE(); exit(0); },

    'library|l=s'       => \$iPhoto_library,
);

unless ( $res ) {
    print STDERR "Error in arguments.\n";
    USAGE( exitval => 1);
    exit 1;
}

#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# Actual code
#

#
# Set the complete path to the Album data file
#
my $albumdata_path = $iPhoto_library."/AlbumData.xml";

#
# Fetch the data as a big Perl array (sufficient for our needs)
#
verbose("+ Parsing iPhoto Library Album data at $albumdata_path...");
my $albumdata = parse_plist_file($albumdata_path) or
    die ("Error in parsing iPhoto Library Album data at $albumdata_path: $!\n");
$albumdata = $albumdata->as_perl;

#
# Get all the images in Library
#
my $images = $albumdata->{'Master Image List'};

#
# Parse all images in Library
#
foreach my $image (values %{$images}) {
    #
    # Image has geotagging info
    #
    if (exists $image->{'latitude'} && exists $image->{'longitude'}) {
        verbose ("+ Processing file $image->{'ImagePath'}.");
        geotag($image->{'ImagePath'}, $image->{'latitude'}, $image->{'longitude'});
        
        #
        # Repeat if the image has an original file
        #
        if (exists $image->{'OriginalPath'}) {
            verbose ("Processing original file $image->{'OriginalPath'}.");
            geotag($image->{'OriginalPath'}, $image->{'latitude'}, $image->{'longitude'});
        }
    }
    else {
        verbose ("> File $image->{'ImagePath'} has no place information, skipping.");
    }
}

#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# Additional functions
#
sub geotag {
    my ($file, $new_lat, $new_lon) = @_;
    
    if (-f $file && ! -l $file) {
        my $exif = new Image::ExifTool;
        my $info = ImageInfo($file, "GPSLatitude", "GPSLongitude");
        
        #
        # Skip images that are already geotagged
        #
        unless (scalar(keys %{$info}) > 0) {
            verbose("+ Updating GPS info for $file");
            verbose("|- Coordinates set to ($new_lat, $new_lon)");
            $exif->SetNewValue(GPSLatitude => $new_lat);
            $exif->SetNewValue(GPSLongitude => $new_lon);
            $exif->SetNewValue(GPSAltitude => 0);   # Update this...
            $exif->WriteInfo($file);
        }
        else {
            verbose("> $file is already geotagged, skipping.");
        }
    }
    else {
        verbose("!! $file does not exists or is a symbolic link, skipping.");
    }
}

#
# Usage function
#
sub USAGE {
    my %parameters = @_;
    
    my $exitval = exists($parameters{exitval}) ?
        $parameters{exitval} : 0;
    
    print <<EOF;
$COMMAND [-h|--help] [-v|--verbose] [--version] [--library|-l library_path]
    
    --help, -h          : Print this help, then exit
    --version           : Print the script version, then exit
    --verbose, -v       : Enable user information output to STDOUT

    --library, -l       : Path to the iPhoto library to parse.
                          (Default: /Users/<USERNAME>/Pictures/iPhoto Library)
EOF
exit $exitval;
}


#
# Print script version
#
sub VERSION_MESSAGE {
    print <<EOF;
This is $COMMAND v$VERSION.
Copyright (c) 2010 Guillaume-Jean Herbiet  (http://www.herbiet.net)
This is free software; see the source for copying conditions. There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
EOF
}

#
# Verbose output
#
sub verbose {
    print $_[0]."\n" if ($VERBOSE > 0);
}
#-----------------------------------------------------------------------------
