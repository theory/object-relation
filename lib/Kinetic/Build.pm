package Kinetic::Build;

# $Id$

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or derivatives to
# this work, or any other work intended for use with the Kinetic framework, to
# Kineticode, Inc., you confirm that you are the copyright holder for those
# contributions and you grant Kineticode, Inc.  a nonexclusive, worldwide,
# irrevocable, royalty-free, perpetual license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute those
# contributions and any derivatives thereof.

use strict;
use 5.008003;
use base 'Module::Build';
use DBI;
use File::Spec;
use File::Path ();
use File::Copy ();

my %CONFIG = (
    pg => {
        version  => '7.4.5',
        store    => 'Kinetic::Store::DB::Pg',
        app_info => 'App::Info::RDBMS::PostgreSQL',
        rules    => 'Kinetic::Build::Rules::Pg',
        dsn      => {
            dbd        => 'Pg',
            methods => {
                dbname => 'db_name',
                host   => 'db_host',
                port   => 'db_port',
            },
        },
    },
    sqlite => {
        version  => '3.0.8',
        store    => 'Kinetic::Store::DB::SQLite',
        app_info => 'App::Info::RDBMS::SQLite',
        rules    => 'Kinetic::Build::Rules::SQLite',
        dsn      => {
            dbd        => 'SQLite',
            methods => {
                dbname => 'db_name',
            },
        },
    },
);

=head1 Name

Kinetic::Build - Kinetic application installer

=head1 Synopsis

In F<Build.PL>:

  use strict;
  use Kinetic::Build;

  my $build = Kinetic::Build->new(
      module_name => 'MyApp',
  );

  $build->create_build_script;

=head1 Description

This module subclasses L<Module::Build|Module::Build> to provide added
functionality for installing Kinetic and Kinetic applications. The added
functionality includes configuration file management, configuation file setup
for tests, data store schema generation, and database building.

=cut

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $cm = Kinetic::Build->new(%init);

Overrides Module::Build's constructor to add Kinetic-specific build elements.

=cut

sub new {
    my $self = shift->SUPER::new(@_);
    # Add elements we need here.
    $self->add_build_element('db');
    $self->add_build_element('conf');
    return $self;
}

##############################################################################

=head1 Instance Interface

=head2 Attributes

Module::Build calls these "properties". They can either be specified in
F<Build.PL> by passing them to C<new()>, or they can be specified on the
command line.

=head3 accept_defaults

  my $accept = $build->accept_defaults;
  $build->accept_defaults($accept);

Returns true if all default values for prompts are simply to be accepted, and
false if they are not.

=cut

__PACKAGE__->add_property(accept_defaults => 0);

##############################################################################

=head3 store

  my $store = $build->store;
  $build->store($store);

The type of data store to be used for the application. Possible values are
"pg" and "sqlite" Defaults to "sqlite".

=cut

__PACKAGE__->add_property(store => 'sqlite');

##############################################################################

=head3 db_name

  my $db_name = $build->db_name;
  $build->db_name($db_name);

The name of the Kinetic database. Defaults to "kinetic". Not used by the
SQLite data store.

=cut

__PACKAGE__->add_property(db_name => 'kinetic');

##############################################################################

=head3 db_user

  my $db_user = $build->db_user;
  $build->db_user($db_user);

The database user to use to connect to the Kinetic database. Defaults to
"kinetic". Not used by the SQLite data store.

=cut

__PACKAGE__->add_property(db_user => 'kinetic');

##############################################################################

=head3 db_pass

  my $db_pass = $build->db_pass;
  $build->db_pass($db_pass);

The password for the database user specified by the C<db_user> attribute.
Defaults to "kinetic". Not used by the SQLite data store.

=cut

__PACKAGE__->add_property(db_pass => 'kinetic');

##############################################################################

=head3 db_root_user

  my $db_root_user = $build->db_root_user;
  $build->db_root_user($db_root_user);

The root or admin database user, which will be used to create the Kinetic
database and user if they don't already exist. The default is the typical root
user name for the seleted data store. Not used by the SQLite data store.

=cut

__PACKAGE__->add_property('db_root_user');

##############################################################################

=head3 db_root_pass

  my $db_root_pass = $build->db_root_pass;
  $build->db_root_pass($db_root_pass);

The password for the root or admin database user. An empty string by
default. Not used by the SQLite data store.

=cut

__PACKAGE__->add_property(db_root_pass => '');

##############################################################################

=head3 db_host

  my $db_host = $build->db_host;
  $build->db_host($db_host);

The host name of the Kinetic database server. Undefind by default, which
generally means that the connection will be made to localhost via Unix
sockets. Not used by the SQLite data store.

=cut

__PACKAGE__->add_property('db_host');

##############################################################################

=head3 db_port

  my $db_port = $build->db_port;
  $build->db_port($db_port);

The port number of the Kinetic database server. Undefind by default, which
generally means that the connection will be made to the default port for the
database. Not used by the SQLite data store.

=cut

__PACKAGE__->add_property('db_port');

##############################################################################

=head3 db_file

  my $db_file = $build->db_file;
  $build->db_file($db_file);

The name of the database file. Defaults to F<kinetic.db>. Used by the SQLite
data store.

=cut

__PACKAGE__->add_property(db_file => 'kinetic.db');

##############################################################################

=head3 conf_file

  my $conf_file = $build->conf_file;
  $build->conf_file($conf_file);

The name of the configuration file. Defaults to F<kinetic.conf>.

=cut

__PACKAGE__->add_property(conf_file => 'kinetic.conf');

##############################################################################

=head2 Actions

=head3 check_store

=begin comment

=head3 ACTION_check_store

=end comment

This action checks for the presence of the data store using the C<check_*_>
methods, and prompts for relevant information unless the C<accept_defaults>
attribute has been set to a true value.

=cut

sub ACTION_check_store {
    my $self = shift;
    return $self if $self->notes('got_store');

    # Check the specific store.
    my $rules_class = $CONFIG{$self->store}{rules};
    eval "use $rules_class";
    $self->_fatal_error("Cannot use class ($rules_class): $@") if $@;
    my $rules = $rules_class->new($self);
    $self->_rules($rules); # cached as a test hook
    $rules->validate; 

    $self->notes(got_store => 1);
    return $self;
}

sub _required_version {
    my $self = shift;
    return $CONFIG{$self->store}{version};
}

sub _app_info_params {
    my $self = shift;
    require App::Info::Handler::Carp;
    require App::Info::Handler::Print;
    # XXX Maybe on_fatal should call _fatal_error() instead of Carp::Croak.
    my @params = ( 
        on_info  => 'stdout', 
        on_error => 'croak',
    );

    unless ($self->accept_defaults) {
        require App::Info::Handler::Prompt;
        push @params,
          on_unknown => 'prompt',
          on_confirm => 'prompt';
    }
    return @params;
}

##############################################################################

=head3 config

=begin comment

=head3 ACTION_config

=end comment

This action modifies the contents of Kinetic::Util::Config to default to the
location of F<kinetic.conf> specified by the build process. You won't normally
call this action directly, as the C<build> and C<test> actions depend on it.

=cut

sub ACTION_config {
    my $self = shift;
    $self->depends_on('code');

    # Find Kinetic::Util::Config and hard-code the path to the
    # configuration file.
    my $old = File::Spec->catfile($self->blib,
                                  qw(lib Kinetic Util Config.pm));
    my $new = File::Spec->catfile($self->blib,
                                  qw(lib Kinetic Util Config.pm.new));
    # Figure out where we're going to install this beast.
    my $base = $self->install_base
      || File::Spec->catdir($self->config->{installprefix}, 'kinetic');
    my $default = '/usr/local/kinetic/conf/kinetic.conf';
    my $config = File::Spec->catfile($base, qw(conf kinetic.conf));

    # Just return if the default is legit.
    return if $base eq $default;

    # Update the file.
    open my $orig, '<', $old or die "Cannot open '$old': $!\n";
    open my $temp, '>', $new or die "Cannot open '$new': $!\n";
    while (<$orig>) {
        s/$default/$config/g;
        print $temp $_;
    }
    close $orig;
    close $temp;

    # Make the switch.
    rename $new, $old or die "Cannot rename '$old' to '$new': $!\n";
}

##############################################################################

=head3 build

=begin comment

=head3 ACTION_build

=end comment

Overrides Module::Build's C<build> action to add the C<config> action as a
dependency.

=cut

sub ACTION_build {
    my $self = shift;
    $self->depends_on('check_store');
#    $self->depends_on('config');
    $self->SUPER::ACTION_build(@_);
}

##############################################################################

=head3 test

=begin comment

=head3 ACTION_test

=end comment

Overrides Module::Build's C<test> action to add the C<config> action as a
dependency.

=cut

sub ACTION_test {
    my $self = shift;
    $self->depends_on('check_store');
#    $self->depends_on('config');
    $self->SUPER::ACTION_test(@_);
}

##############################################################################

=head2 Methods

=head3 process_conf_files

This method is called during the C<build> action to copy the configuration
files to F<blib/conf> and F<t/conf>. Their contents are also modified to
reflect the contents of the attributes (such as the data store, database
metadata, etc.).

=cut

sub process_conf_files {
    my $self = shift;
    $self->add_to_cleanup('t/conf');
    my $files = $self->find_conf_files;
    return unless %$files;
    $self->_copy_to($files, $self->blib, 't');

    for my $dir ('t/conf/', 'blib/conf/') {
        my $conf_file = $self->localize_file_path($dir . $self->conf_file);
        open CONF, '<', $conf_file or die "cannot open $conf_file: $!";
        my @conf;
        while (<CONF>) {
            push @conf, $_;
            # Do we have the start of a section?
            next unless /^'?(\w+)'?\s?=>\s?{/;
            # Is there a method for this section?
            my $method = $self->can($1 . '_config') or next;
            # Dump the default contents of the section.
            while (<CONF>) { last if /^},?$/; }
            if (my @section = $self->$method) {
                # Insert the section contents using the *_config method.
                push @conf, @section, "},\n\n";
            } else {
                # Comment out this section.
                $conf[-1] = "# $conf[-1]";
                push @conf, "# }\n";
            }
            next;
        }
        close CONF;
        my $tmp = "$conf_file.tmp";
        open TMP, '>', $tmp or die "cannot open $tmp: $!";
        print TMP @conf;
        close TMP;
        File::Copy::move($tmp, $conf_file);
    }
    return $self;
}

##############################################################################

=head3 store_config

This method is called by C<process_conf_files()> to populate the store
section of the configuration files. It returns a list of lines to be included
in the section, configuring the "class" directive.

=cut

sub store_config {
    my $self = shift;
    return "    class => '" . $self->_fetch_store_class . "',\n";
}

##############################################################################

=head3 sqlite_config

This method is called by C<process_conf_files()> to populate the SQLite
section of the configuration files. It returns a list of lines to be included
in the section, configuring the "file" directive.

=cut

sub sqlite_config {
    my $self = shift;
    return unless $self->store eq 'sqlite';
    return "    file => '" . $self->db_file . "',\n";
}

##############################################################################

=head3 pg_config

This method is called by C<process_conf_files()> to populate the PostgreSQL
section of the configuration files. It returns a list of lines to be included
in the section, configuring the "db_name", "db_user", "db_pass", "host", and
"port" directives.

=cut

sub pg_config {
    my $self = shift;
    return unless $self->store eq 'pg';
    return (
        "    db_name => '" . $self->db_name . "',\n",
        "    db_user => '" . $self->db_user . "',\n",
        "    db_pass => '" . $self->db_pass . "',\n",
        "    host    => " . (defined $self->db_host ? "'" . $self->db_host . "'" : 'undef'), ",\n",
        "    port    => " . (defined $self->db_port ? "'" . $self->db_port . "'" : 'undef'), ",\n",
    );
}

##############################################################################

=head3 find_conf_files

Called by C<process_conf_files()>, this method returns a hash reference of
configuration file names for processing and copying.

=cut

sub find_conf_files  { shift->_find_files_in_dir('conf') }

##############################################################################

=head3 process_db_files

This method creates the database files used by the SQLite data store. Two will
be created: One in F<blib/store> for installation, and one in F<t/store> for
testing.

=cut

sub process_db_files {
    my $self = shift;
    # Do nothing unless the data store is SQLite.
    return $self unless lc $self->store eq 'sqlite';
    $self->add_to_cleanup('t/store');
    for my $dir ($self->blib, 't') {
        my $path = $self->localize_file_path($dir . '/store');
        File::Path::mkpath($path, 0, 0777);
        my $file = $self->localize_file_path($path . '/' . $self->db_file);
        open F, '>', $file or die "Cannot open '$file': $!\n";
        close F;
    }
    return $self;
}

##############################################################################

=head3 prompt

This method overrides Module::Build's C<prompt()> method to simply return the
default if the C<accept_defaults> property is set to a true value.

=cut

sub prompt {
    my $self = shift;
    # Let Module::Build do it's thing unless --accept_defaults
    return $self->SUPER::prompt(@_) unless $self->accept_defaults;
    my ($prompt, $default) = @_;
    # Output the prompt and the value so that they know what's what.
    local $| = 1;
    print "$prompt: ", (defined $default ? $default : '[undefined]'), "\n";
    return $default;
}

##############################################################################

=head3 check_pg

  $build->check_pg;

This method checks that the necessary PostgreSQL client libraries and
programs are present to build the database. It uses
L<App::Info::RDBMS::PostgreSQL|App::Info::RDBMS::PostgreSQL> to do this.

=cut

sub check_pg {
    my ($self, $pg) = @_;

    # Check for database accessibility. Rules:
    $pg->createlang
        or $self->_fatal_error("createlang must be available for plpgsql support");

    my $template1 = 'template1';
    my $user      = $self->db_user;
    my $pass      = $self->db_pass;

    unless ($self->db_root_user) {
        # We should be able to connect to template1 as db_user
        my $dbh = $self->_connect_as_user($template1)
          or $self->_fatal_error("Can't connect as $user to $template1: $DBI::errstr");

        $self->_dbh($dbh);
        # If db_name does not exist, db_user should have permission to create it.
        unless ($self->_db_exists) {
            $self->_can_create_db($user)
              or $self->_fatal_error("User $user does not have permission to create databases");
        }
    } else {
        $self->db_root_user('postgres') unless defined $self->db_root_user;
        my $root = $self->db_root_user;
        # We should be able to connect to template1 as db_root_user
        my $dbh = $self->_connect_as_root($template1)
          or $self->_fatal_error("Can't connect as $root to $template1: $DBI::errstr");

        $self->_dbh($dbh);

        # root user should really be root user
        unless ($self->_is_root_user($root)) {
            $self->_fatal_error("We thought $root was root, but it is not.");
        }

        # if db_name does not exist, db_root_user should have permission to create it.
        unless ($self->_db_exists) {
            $self->_can_create_db($root)
              or $self->_fatal_error("User $root does not have permission to create databases");
        }

        # if db_user does not exist, make a note so the build process can know
        unless ($self->_user_exists($user)) {
            $self->notes(default_user => "$user does not exist");
        }
    }

    # We're good to go. Collect the configuration data.
    my %info = (
        createlang => $pg->createlang,
        psql       => $pg->executable,
        version    => version->new($pg->version),
    );

    $self->notes(pg_info => $pg);
    return $self;
}

##############################################################################

=head3 check_sqlite

  $build->check_sqlite;

This method checks that SQLite is installed so that the database can be
built. uses L<App::Info::RDBMS::SQLite|App::Info::RDBMS::SQLite> to do this.

=cut

sub check_sqlite {
    my ($self, $sqlite) = @_;

    my $rules_class = $CONFIG{$self->store}{rules};
    eval "use $rules_class";
    $self->_fatal_error("Cannot use class ($rules_class): $@") if $@;
    my $rules = $rules_class->new($self);
    $rules->validate; 
    return $self;
}

##############################################################################

=begin private

=head1 Private Methods

=head2 Class Methods

=head3 _fatal_error

  Kinetic::Build->_fatal_error(@messages)

This method is a standard way of reporting fatal errors.  At the current time,
all we do is croak().

=cut

sub _fatal_error {
    my ($package, @messages) = @_;
    require Carp;
    Carp::croak @messages;
}

##############################################################################

=head2 Instance Methods

=head3 _copy_to

  $build->_copy_to($files, @dirs);

This method copies the files in the C<$files> hash reference to each of the
directories specified in C<@dirs>.

=cut

sub _copy_to {
    my $self = shift;
    my $files = shift;
    return unless %$files;
    while (my ($file, $dest) = each %$files) {
        for my $dir (@_) {
            $self->copy_if_modified(from => $file,
                                    to   => File::Spec->catfile($dir, $dest) );
        }
    }
}

##############################################################################

=head3 _rules

  my $rules = $build->_rules;

Debugging hook.  This returns a copy of the Kinetic::Build::Rules object;

=cut

__PACKAGE__->add_property('_rules');

##############################################################################

=head3 _dbh

  $build->_dbh([$dbh]);

Use this method to store and retrieve the database handle.

=cut

__PACKAGE__->add_property('_dbh');

##############################################################################

=head3 _dsn

  $build->_dsn;

This method returns the dsn for the current build

=cut

sub _dsn {
    my $self = shift;
    $self->_fatal_error("Cannot create dsn without a db_name")
      unless defined $self->db_name;
    $self->_fatal_error("The database port must be a numeric value")
      if defined $self->db_port and $self->db_port !~ /^[[:digit:]]+$/;
    my $dsn  = $CONFIG{$self->store}{dsn};
    my $dbd  = "dbi:$dsn->{dbd}";
    my $properties = join ';' =>
        map  { join '=' => @$_ }
        grep { defined $_->[1] }
        map  {
            my $method = $dsn->{methods}{$_}; 
            [ $_, $self->$method ]
        } sort keys %{ $dsn->{methods} };
    return "$dbd:$properties";
}

##############################################################################

=head3 _fetch_store_class

This method is called by C<store_config()>  determine the class that handles a
given store.

=cut

sub _fetch_store_class {
    my ($self) = @_;
    return $CONFIG{$self->store}{store}
      or $self->_fatal_error("Class not found for " . $self->store);
}

##############################################################################

=head3 _find_files_in_dir

  $build->_find_files_in_dir($dir);

Returns a hash reference of of all of the files in a directory, excluding any
with F<.svn> in their paths. Code borrowed from Module::Buld's
C<_find_file_by_type()> method.

=cut

sub _find_files_in_dir {
    my ($self, $dir) = @_;
    return { map {$_, $_}
             map $self->localize_file_path($_),
             @{ $self->rscan_dir($dir, sub { -f && !/\.svn/ }) } };
}

1;
__END__

##############################################################################

=end private

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc. <info@kineticode.com>

This work is made available under the terms of Version 2 of the GNU General
Public License. You should have received a copy of the GNU General Public
License along with this program; if not, download it from
L<http://www.gnu.org/licenses/gpl.txt> or write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

This work is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License Version 2 for more
details.

=cut
