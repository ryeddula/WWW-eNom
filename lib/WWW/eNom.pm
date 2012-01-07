package WWW::eNom;

use strict;
use warnings;
use utf8;
use English -no_match_vars;
use Any::Moose;
use Any::Moose "::Util::TypeConstraints";
use Carp qw(croak);
use ParseUtil::Domain qw(parse_domain);
use URI;

# VERSION
# ABSTRACT: Interact with eNom, Inc.'s reseller API

with "WWW::eNom::Role::Commands";

# Supported response types:
my @response_types = qw(xml_simple xml html text);
subtype "eNomResponseType"
	=> as "Str",
	=> where {
		my $type = $ARG;
		{ $type eq $ARG and return 1 for @response_types; 0 } },
	=> message {
		 "response_type must be one of: " . join ", ", @response_types };

has username => (
	isa      => "Str",
	is       => "ro",
	required => 1 );
has password => (
	isa      => "Str",
	is       => "ro",
	required => 1 );
has test => (
	isa     => "Bool",
	is      => "ro",
	default => 0 );
has response_type => (
	isa     => "eNomResponseType",
	is      => "ro",
	default => "xml_simple" );
has _uri => (
	isa     => "URI",
	is      => "ro",
	lazy    => 1,
	default => \&_default__uri );

sub _make_query_string {
	my ( $self, $command, %opts ) = @_;
	my $uri = $self->_uri;
	if ( $command ne "CertGetApproverEmail"
	     and my $domain = delete $opts{Domain} ) {
		my $test_domain = $domain;

		# Look for an eNom wildcard TLD:
		my $wildcard_tld = qr{\.([*12@]+$)}x;
		my ($subbed_tld) = $test_domain =~ $wildcard_tld;
		$test_domain =~ s/$wildcard_tld/.com/x if $subbed_tld;
		my $parsed = eval { parse_domain($test_domain) };
		croak qq[Domain name, "$parsed", does not look like a domain.] if $@;

		# Done testing; substitute TLD back in if necessary:
		$parsed->{zone} = $subbed_tld if $subbed_tld;

		# Finally, add in the neccesary API arguments:
		@opts{qw(SLD TLD)} = @{$parsed}{qw(domain zone)} }
	my $response_type = $self->response_type;
	$response_type = "xml" if $response_type eq "xml_simple";
	$uri->query_form(
		command      => $command,
		uid          => $self->username,
		pw           => $self->password,
		responseType => $response_type,
		%opts );
	return $uri; }

sub _default__uri {
	my ($self) = @ARG;
	my $test = "http://resellertest.enom.com/interface.asp";
	my $live = "http://reseller.enom.com/interface.asp";
	return URI->new( $self->test ? $test : $live ) }

__PACKAGE__->meta->make_immutable;

1;

__END__

=encoding utf8

=head1 NAME

Net::eNom - Interact with eNom, Inc.'s reseller API

=head1 SYNOPSIS

	use strict;
	use warnings;
	use WWW::eNom;

	my $enom = WWW::eNom->new(
		username      => "resellid",
		password      => "resellpw",
		response_type => "xml_simple",
		test          => 1
	);
	$enom->AddToCart(
		EndUserIP => "1.2.3.4",
		ProductType => "Register",
		SLD => "myspiffynewdomain",
		TLD => "com"
	);
	...

=head1 METHODS

=head2 new

Constructs a new object for interacting with the eNom API. If the
"test" parameter is given, then the API calls will be made to the test
server instead of the live one.

As of v0.3.1, an optional "response_type" parameter is supported. For the sake
of backward compatibility, the default is "xml_simple"; see below for an
explanation of this response type. Use of any other valid option will lead to
the return of string responses straight from the eNom API. These options are:

=over

=item * xml

=item * html

=item * text

=back

=head2 AddBulkDomains (and many others)

	my $response = $enom->AddBulkDomains(
		ProductType => "register",
		ListCount   => 1,
		SLD1        => "myspiffynewdomain",
		TLD1        => "com",
		UseCart     => 1
	);

Performs the specified command - see the eNom API users guide
(https://www.enom.com/resellers/APICommandCatalogEnom.pdf) for the commands
and their arguments.

For convenience, if you pass the "Domain" argument, it will be split
into "SLD" and "TLD"; that is, you can say

	my $response = $enom->Check( SLD => "myspiffynewdomain", TLD => "com" );

or

	my $response = $enom->Check( Domain => "myspiffynewdomain.com" );

The default return value is a Perl hash (via L<XML::Simple>) representing the
response XML from the eNom API; the only differences are

=over 3

=item *

The "errors" key returns an array instead of a hash

=item *

"responses" returns an array of hashes

=item *

Keys which end with a number are transformed into an array

=back

So for instance, a command C<Check( Domain => "enom.@" )> (the "@" means
"com, net, org") might return:

	{
		Domain  => [ qw(enom.com enom.net enom.org) ],
		Command => "CHECK",
		RRPCode => [ qw(211 211 211) ],
		RRPText => [
			"Domain not available",
			"Domain not available",
			"Domain not available"
		]
	};

You will need to read the API guide to check whether to expect responses
in "RRPText" or "responses"; it's not exactly consistent.

=head1 RELEASE NOTE

As of v1.0.0, this module has been renamed to WWW::eNom. Net::eNom is now a thin
wrapper to preserve backward compatibility.

=head1 AUTHORS

Richard Simões, C<< <rsimoes AT cpan DOT org> >>
Simon Cozens, C<< <simon AT simon-cozens DOT org> >>

=head1 ACKNOWLEDGEMENTS

Thanks to the UK Free Software Network (http://www.ukfsn.org/) for their
support of this module's development. For free-software-friendly hosting
and other Internet services, try UKFSN.

=head1 COPYRIGHT & LICENSE

Copyright 2011 Simon Cozens and Richard Simões.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU Lesser General Public License as
published by the Free Software Foundation; or any compatible license.

See http://dev.perl.org/licenses/ for more information.
