use strict;
use warnings;
use POSIX qw(setlocale LC_ALL);
BEGIN { setlocale(LC_ALL, "C"); }
use Test::More;
use Test::Exception;
use Config;
BEGIN {
    $Config{useithreads}
        and warn "WARNING: Net::NSCAng::Client is not thread safe but your perl has threads enabled!\n";
}
use IO::Socket::INET;
use Net::NSCAng::Client;

use constant TEST_HOSTNAME => 'nsca-ng-test.towiski.de';
use constant TEST_PORT => 5668;

my @cparams = qw/ nsca-ng-test.towiski.de tester hei9Cai4 /;
my $crf;
if(IO::Socket::INET->new(sprintf("%s:%d", TEST_HOSTNAME, TEST_PORT))) {
    warn "Using test server at " . TEST_HOSTNAME . "\n";
    $crf = \&_crf_dummy;
} else {
    warn "Can't reach test server at " . TEST_HOSTNAME . "; suppressing resulting failures\n";
    $crf = \&_crf;
    $cparams[0] = 'localhost';
}

# This is not supposed to be a secure password. The account can't do anything, it's just
# to keep passersby from trying too much
my @nn = (node_name => 'here');
my @sd = (svc_description => 'bogus');
my $n;

lives_ok(sub { $n = Net::NSCAng::Client->new(@cparams) }, 'Simple constructor');
dies_ok(sub { $n->host_result(0, "OK") }, 'host_result() dies w/o node_name');
dies_ok(sub { $n->svc_result(0, "OK") }, 'svc_result() dies w/o node_name');
lives_ok(sub { $crf->(sub { $n->host_result(0, "OK", @nn) })}, 'host_result() with local node_name');
dies_ok(sub { $n->svc_result(0, "OK", @nn) }, 'svc_result() still dies with local node_name');

lives_ok(sub { $n = Net::NSCAng::Client->new(@cparams, @nn) }, 'Constructor with node_name');
lives_ok(sub { $crf->(sub { $n->host_result(0, "OK") })}, 'host_result() with node_name from constructor');
dies_ok(sub { $n->svc_result(0, "OK") }, 'svc_result() dies w/o svc_description');
lives_ok(sub { $crf->(sub { $n->svc_result(0, "OK", @sd) })}, 'svc_result() with local svc_description');

lives_ok(sub { $n = Net::NSCAng::Client->new(@cparams, @nn, @sd) }, 'Constructor with node_name');
lives_ok(sub { $crf->(sub { $n->host_result(0, "OK") })}, 'host_result() OK w/o local params');
lives_ok(sub { $crf->(sub { $n->svc_result(0, "OK") })}, 'svc_result() OK w/o local params');

dies_ok(sub { $n->command() }, 'command() dies w/o argument');
# This only works with a real server
dies_ok(sub { $n->command("BOGUS_COMMAND") }, 'command() dies on forbidden command') if $crf == \&_crf_dummy;
dies_ok(sub { $n->command("WORKING_COMMAND;foo") }, 'command() dies on illegal parameter') if $crf == \&_crf_dummy;
lives_ok(sub { $crf->(sub { $n->command("WORKING_COMMAND") })}, 'command() works');

done_testing;

# Supress exceptions with a "connection refused" error as this is expected
sub _crf {
    my $sub = shift;
    eval { $sub->() };
    if($@) {
        die $@ unless $@ =~ /SSL error:/;
    }
}

# Don't catch anything if we expect to have a working test server
sub _crf_dummy { shift->() }
