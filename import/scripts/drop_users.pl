#!/usr/bin/perl
use strict;
use warnings;
use MongoDB;
use common;

# drop a collection, reset counter

my $database='test';
my $coll='users';

# open user collection, get user information
my $client = MongoDB->connect();
my $db = $client->get_database( $database );
my $users = $db->get_collection( $coll );

$users->delete_many( { site => "mailru" } );
$users->delete_many( { site => "lj" } );
$users->delete_many( { site => undef } );


