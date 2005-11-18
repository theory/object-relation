#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;

use File::Path;
use File::Spec::Functions;

rmtree catdir 't', 'data';
