# Copyright (c) 2013 David Caldwell.
# Copyright (c) 2014 Marcel Greter.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

use 5.008000;
use Getopt::Long;
use ExtUtils::CppGuess;
use ExtUtils::MakeMaker;

# TIP: use `dmake -P#jobs` on windows

use strict;
use warnings;

# command line options
my $optimize = '-O3';
my $debug_mode = 0;
my $compiler = undef;
my $profiling = 0;
my $skip_manifest = 0;
my $skip_version = 0;
my $update_deps = 0;
my $checkout_deps = 0;
my $skip_git = 0;

# arrays for various switches
my (@libs, @flags, @defs, @incs);

# start by adding the main incs
push @incs, '.', 'libsass/include';

# query version of libsass dep
my $libsass_version = '[na]';

sub help
{
	print "CSS::Sass Makefile.PL options (developers only):\n\n";
	print "  --debug              Build libsass in debug mode\n";
	print "  --compiler           Skips compiler autodetection\n";
	print "  --profiling          Enable gcov profiling switches\n";
	print "  --skip-manifest      Skips manifest generation (needs git repo)\n";
	print "  --skip-version       Skips generating libsass/VERSION (needs git repo)\n";
	print "  --update-deps        Update libsass and specs to latest master (needs git repo)\n";
	print "  --checkout-deps      Checkout submodules at linked commit (needs git repo)\n";
	print "  --get-versions       Show versions of all perl package (.pm) files\n";
	print "  --get-versions       Show versions of all perl package (.pm) files\n";
	print "  --set-versions       Set versions of all perl package (.pm) files\n";
	print "  --skip-git           Do not try to use anything git related\n";
	print "  --help               This help screen\n";
	exit 1;
}

my $re_version = qr/our\s+\$VERSION\s*=\s*[\"\']
                    v?([0-9]+\.[0-9]+\.[0-9]+(?:[\-_].+?)?)
                   [\"\']\s*\;/x;

# needs File::Slurp
# no hard dependency!
sub versions
{
	my @files;
	my ($v) = @_;
	require File::Slurp;
	my $tag = $v;
	my $ma = File::Slurp::read_file('MANIFEST', { 'binmode' => ':raw' });
	@files = grep { m/.pm$/i } split /\s*\r?\n/, $ma;
	# this optional step need git repo
	# when nothing is explicitly passed
	unless ($tag) {
		$tag = `git describe --abbrev=0 --always --tag`;
		$tag =~ s/(?:\A\s+|\Av|\s+\z)//g;
		unless ( $tag =~ m/(\d+\.\d+\.)(\d+)(?:[\-_]|\z)/ )
		{ die "Tag <$tag> invalid (\\d+.\\d+.\\d+)\n"; }
		# increment the patch level
		else { $tag = $1 . ($2 + 1); }
	}
	$tag =~ s/(?:\A\s+|\Av|\s+\z)//g;
	if (scalar(@_)) {
		print "Update *.pm with new version <$tag>\n";
		unless ( $tag =~ m/(\d+\.\d+\.)(\d+)(?:[\-_]|\z)/ )
		{ die "Tag <$tag> invalid (\\d+.\\d+.\\d+)\n"; }
		foreach my $filename (@files) {
			my $data = File::Slurp::read_file($filename, { 'binmode' => ':raw' });
			if ($data =~ s/$re_version/our \$VERSION = \"$tag\";/i) {
				next if $tag eq $1;
				print "  update version $filename (was $1)\n";
				File::Slurp::write_file($filename, { 'binmode' => ':raw' }, $data);
			}
		}
	} else {
		foreach my $filename (@files) {
			my $data = File::Slurp::read_file($filename, { 'binmode' => ':raw' });
			print "  $filename (", ($data =~ m/$re_version/i ? $1 : "[NA]"), ")\n";
		}
	}
}

GetOptions(
	'--help' => \&help,
	'--debug' => \$debug_mode,
	'--compiler:s' => \$compiler,
	'--profiling' => \$profiling,
	'--skip-git' => \$skip_git,
	'--skip-version' => \$skip_version,
	'--skip-manifest' => \$skip_manifest,
	# options for git submodules
	'--update-deps' => \$update_deps,
	'--checkout-deps' => \$checkout_deps,
	# manipulate versions of all perl packages
	'--get-versions' => sub { versions(); exit 1; },
	'--set-versions:s' => sub { versions($_[1]); exit 1; },
);

# declare git submodules that are used
my @submodules = qw(libsass t/sass-spec);

# print some debug messages to console
print "You enabled debug build\n" if $debug_mode;
print "You enabled code profiling\n" if $profiling;

# Are we in our development tree?
# If so, create the MANIFEST file.
if (-d ".git" && !$skip_git)
{
	require Cwd;
	require File::Spec;
	my @modules = ('.');
	my $base = Cwd::getcwd;
	my ($dir, $manifest);
	# init and update git submodules
	foreach my $submodule (@submodules)
	{
		if (!-e "$submodule/.git" || $checkout_deps)
		{
			print "Checkout git submodule: $submodule\n";
			system "git submodule init \"$submodule\"";
			system "git submodule update \"$submodule\"";
			system "git -C \"$submodule\" fetch --tags";
		}
	}
	# create manifest file via git
	# also add files that we generate
	unless ($skip_manifest) {
		open $manifest, ">", "MANIFEST" or die "MANIFEST: $!";
		print $manifest "MANIFEST\n";
		print $manifest "libsass/VERSION\n";
		while (my $module = shift @modules)
		{
			my $cwd = Cwd::getcwd;
			chdir ($module) or die "pushd: $!";
			my $files = `git ls-files` or die "Couldn't run git: $!";
			my @items = split(/\n+/, $files);
			my @files = grep { ! -d } @items;
			print $manifest
				map { tr/\\/\//; $_ . "\n" }
				map { File::Spec->abs2rel($_, $base) } @files;
			push @modules,
				map { File::Spec->catfile($module, $_) }
				grep { -d } @items;
			chdir ($cwd) or die "popd: $!";
		}
	}
	if ($update_deps)
	{
		foreach my $submodule (@submodules)
		{
			print "Update git submodule $submodule\n";
			system "git -C \"$submodule\" fetch";
			system "git -C \"$submodule\" fetch --tags";
			system "git -C \"$submodule\" pull --ff origin master";
		}
	}
	# create version file in libsass submodule root
	foreach my $submodule (@submodules)
	{
		if (-e "$submodule/.git" && !$skip_version) {
			next unless $submodule eq "libsass"; # skip all others for now
			system "git -C \"$submodule\" describe --abbrev=4 --dirty --always --tags > \"$submodule/VERSION\"";
		}
	}
}

# read version from version file
if (-f "libsass/VERSION") {
	open (my $fh, "<", "libsass/VERSION");
	$libsass_version = <$fh> if (defined $fh);
	chomp($libsass_version);
	print "Detected libsass $libsass_version\n";
} else {
	# give a warning if the version could not be determined (probably not generated yet)
	warn "Could not get version for libsass (", $libsass_version, ")\n";
}

my $guess = ExtUtils::CppGuess->new(
	(defined($compiler) ? (cc => $compiler) : ()),
);

if ($guess->is_gcc) { print "Detected gcc compiler...\n"; }
elsif ($guess->is_msvc) { print "Detected MSVC compiler...\n"; }
else { print "Unknown compiler, trying anyway...\n"; }

no warnings 'redefine';
my $orig = \&ExtUtils::MM_Unix::c_o;
*ExtUtils::MM_Unix::c_o = sub {
	my @rv = &{$orig};
	foreach (@rv) {
		# add c++0x flag only for cpp files
		# otherwise XS perl handshake fails
		s/\$\*\.c(pp|xx)(?=\n|\Z)/-xc++ -std=c++0x \$\*\.c$1/g
	}
	return @rv;
};
use warnings 'redefine';

# enable all warnings (disable only specific ones)
push @flags, '-Wall -Wextra -Wno-unused-parameter';

# enable optional debug mode
$optimize = '-O1' if $debug_mode;
push @defs, 'DEBUG' if $debug_mode;

# not sure why this does not work otherwise
push @flags, '-o $*.o' if ($guess->is_gcc);

# create compile flags to include the libsass version
push @defs, qq( LIBSASS_VERSION=\\"$libsass_version\\");

# enable code profiling via gcov
$optimize = '-O1' if $profiling;
push @libs, '-lgcov' if $profiling;
push @libs, '-fprofile-arcs' if $profiling;
push @libs, '-ftest-coverage' if $profiling;
push @flags, '-fprofile-arcs' if $profiling;
push @flags, '-ftest-coverage' if $profiling;

# now add our custom flags
$guess->add_extra_linker_flags(join(' ', @libs));
$guess->add_extra_compiler_flags(join(' ', @flags));

# fetch the original compiler flags
my %compiler_flags = $guess->makemaker_options();

# remove c++ flag (only needed for cpp files)
$compiler_flags{'CCFLAGS'} =~ s/\-xc\+\+//g;

# cleanup some unnecessary whitespace
$compiler_flags{'CCFLAGS'} =~ s/^\s+//g;
$compiler_flags{'CCFLAGS'} =~ s/\s+$//g;
$compiler_flags{'CCFLAGS'} =~ s/\s+/ /g;

# disable all optimizations when doing code profiling
$compiler_flags{'CCFLAGS'} =~ s/\s*\-O[1-9]//g if $profiling;

# See lib/ExtUtils/MakeMaker.pm for details of how to
# influence content of the Makefile that is written.
WriteMakefile(
	NAME               => 'CSS::Sass',
	VERSION_FROM       => 'lib/CSS/Sass.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
	# runtime dependencies
	PREREQ_PM          => {
		'perl'                 => 5.008000,
		'Carp'                 => 1.01, # core as of 5.008
		'version'              => 0,
		'warnings'             => 0, # core as of 5.008
		'strict'               => 0 # core as of 5.008
	},
	# test dependencies
	TEST_REQUIRES      => {
		'File::chdir'          => 0.01,
		'Test::Differences'    => 0.01,
	},
	# build dependencies
	BUILD_REQUIRES     => {
		'Getopt::Long'         => 0.01,
		'ExtUtils::CppGuess'   => 0.09,
		'ExtUtils::MakeMaker'  => 6.52,
	},
	# build dependencies
	CONFIGURE_REQUIRES => {
		'Getopt::Long'         => 0.01,
		'ExtUtils::CppGuess'   => 0.09,
		'ExtUtils::MakeMaker'  => 6.52,
	},
	# additional information
	META_MERGE => {
		resources => {
			license     => 'http://opensource.org/licenses/MIT',
			homepage    => 'https://metacpan.org/release/CSS-Sass',
			bugtracker  => 'https://github.com/sass/perl-libsass/issues',
			repository  => 'https://github.com/sass/perl-libsass',
		},
	},
	ABSTRACT_FROM      => 'lib/CSS/Sass.pm', # retrieve abstract from module
	AUTHOR             => q{David Caldwell <david@porkrind.org>},
	AUTHOR             => q{Marcel Greter <perl-libsass@ocbnet.ch>},
	LICENSE            => 'MIT',
	# options are set by CppGuess
	# LIBS               => [''],
	# CCFLAGS            => '',
	# LDDLFLAGS          => '',
	INC                => join(" ", map { sprintf "-I%s", $_ } @incs),
	DEFINE             => join(" ", map { sprintf "-D%s", $_ } @defs),
	%compiler_flags,
	OPTIMIZE           => $optimize,
	TYPEMAPS           => [ 'perlobject.map' ],
	OBJECT             => join(" ", (sort grep { s/\.c(?:pp)?$/\.o/ } map { join '/', 'libsass', 'src', $_ } qw(
		ast.cpp sass2scss.cpp node.cpp sass_util.cpp remove_placeholders.cpp json.cpp
		base64vlq.cpp bind.cpp constants.cpp context.cpp plugins.cpp color_maps.cpp
		error_handling.cpp eval.cpp expand.cpp cencode.c functions.cpp inspect.cpp
		extend.cpp file.cpp output.cpp parser.cpp prelexer.cpp emitter.cpp position.cpp
		sass.cpp sass_interface.cpp sass_functions.cpp sass_values.cpp sass_context.cpp
		source_map.cpp to_c.cpp to_string.cpp units.cpp utf8_string.cpp util.cpp cssize.cpp
		listize.cpp lexer.cpp memory_manager.cpp environment.cpp to_value.cpp values.cpp
	)), '$(O_FILES)'),
	EXE_FILES          => [ 'bin/psass' ],
);