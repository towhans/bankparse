#!/usr/bin/env perl
use strict;
use warnings;
use lib qw(sorter/lib);
use lib qw(common/lib);

Maildir::Split::Test->runtests;

##############################################################################

package Maildir::Split::Test;

use base qw(Test::Class);
use Test::More;
use Data::Dumper;
use Test::Exception;
use Maildir::Split qw(Split);
use FindBin qw($Bin);
use File::Tempdir;

#----------------------------------------------------------------------

sub __1_Basic : Test(1) {

	my $dir = File::Tempdir->new();
	my $source = $dir->name;

	`cp -r $Bin/../Test/Maildir $source`;

	my $udir = File::Tempdir->new();
	my $userdir = $udir->name;

	Maildir::Split::Split("$source/Maildir", $userdir, undef);
	my $tree = `tree $userdir`;
	ok($tree =~ /8 directories, 40 files/, 'basic split');
}

#----------------------------------------------------------------------

sub __1_Wait : Test(1) {

	my $dir = File::Tempdir->new();
	my $source = $dir->name;

	my $udir = File::Tempdir->new();
	my $userdir = $udir->name;

	#diag "cp -r $Bin/../Test/Maildir $source";
	#diag "tree $userdir";

	`cp -r $Bin/../Test/Maildir $source`;

	eval { Maildir::Split::Watch("$source/Maildir", $userdir, undef, 40) };
	my $tree = `tree $userdir`;
	ok($tree =~ /8 directories, 40 files/, 'watch split');
}


##############################################################################

__END__

