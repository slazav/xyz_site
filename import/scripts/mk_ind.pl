#!/usr/bin/perl
use strict;
use warnings;
use MongoDB;
use common;

# drop a collection, reset counter

my $database='test';

my $db = MongoDB->connect()->get_database($database);

$db->get_collection('comm')->indexes->drop_all();
$db->get_collection('news')->indexes->drop_all();

$db->get_collection('news')->indexes->create_one ([title=>'text', text=>'text']);
$db->get_collection('comm')->indexes->create_one ([object_id=>1, coll=>1]);

