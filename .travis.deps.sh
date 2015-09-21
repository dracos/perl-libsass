#!/usr/bin/sh

export PERL_MM_USE_DEFAULT=1
 
if [ "$TRAVIS_PERL_VERSION" == "5.22" ]; then
  PERLBREW_PERL_VERSION=5.22.0
fi
if [ "$TRAVIS_PERL_VERSION" == "5.20" ]; then
  PERLBREW_PERL_VERSION=5.20.3
fi
if [ "$TRAVIS_PERL_VERSION" == "5.18" ]; then
  PERLBREW_PERL_VERSION=5.18.4
fi
if [ "$TRAVIS_PERL_VERSION" == "5.16" ]; then
  PERLBREW_PERL_VERSION=5.16.3
fi
if [ "$TRAVIS_PERL_VERSION" == "5.14" ]; then
  PERLBREW_PERL_VERSION=5.14.4
fi
if [ "$TRAVIS_PERL_VERSION" == "5.12" ]; then
  PERLBREW_PERL_VERSION=5.12.5
fi
if [ "$TRAVIS_PERL_VERSION" == "5.10" ]; then
  PERLBREW_PERL_VERSION=5.10.1
fi
if [ "$TRAVIS_PERL_VERSION" == "5.8" ]; then
  PERLBREW_PERL_VERSION=5.8.9
fi
if [ "$TRAVIS_PERL_VERSION" == "5.6" ]; then
  PERLBREW_PERL_VERSION=5.6.2
fi
  
if [ "$TRAVIS_OS_NAME" == "osx" ]; then
  if [ ! -d "~/perl5/perlbrew/perls" ]; then
    curl -kL http://install.perlbrew.pl | bash
    source ~/perl5/perlbrew/etc/bashrc
    perlbrew init -v
    perlbrew install -v -j 5 perl-$PERLBREW_PERL_VERSION
  fi
  source ~/perl5/perlbrew/etc/bashrc
  perlbrew switch -v perl-$PERLBREW_PERL_VERSION
  perlbrew use -v perl-$PERLBREW_PERL_VERSION
  perlbrew install-cpanm
  source ~/perl5/perlbrew/etc/bashrc
fi

cpanm --installdeps --verbose .
cpanm -n Devel::Cover
cpanm -n Devel::Cover::Report::Coveralls
perl Makefile.PL --profiling

HARNESS_PERL_SWITCHES=-MDevel::Cover make -j5 test
